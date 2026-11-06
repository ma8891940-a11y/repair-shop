-- المرحلة 5: بدون إنترنت والنسخ الاحتياطي
--
-- 1) مزامنة تغيير الحالة اللي اتعمل بدون نت: "آخر تعديل بالوقت يكسب". لو الجهاز اتعدّل على السيرفر بعد وقت التعديل
--    اللي على الجهاز، التعديل القديم ما بيتطبقش، والتعارض بيتسجل في سجل النشاط.
-- 2) تصدير نسخة كاملة من بيانات المحل (صاحب المحل بس). الملف بيتشفّر على الجهاز بكلمة سر قبل ما يتحفظ.
--    أسرار أقفال الأجهزة (Vault) ما بتطلعش في النسخة أبدًا.
-- 3) نسخة احتياطية يومية تلقائية على السيرفر (آخر 7 أيام) لو pg_cron متاح.

-- ---------- 1) آخر تعديل يكسب ----------
create or replace function public.apply_status_lww(p_device uuid, p_status public.device_status, p_client_ts timestamptz)
returns jsonb
language plpgsql security definer set search_path = public as $$
declare d public.devices;
begin
  if public.current_app_role() is null then raise exception 'E_FORBIDDEN'; end if;
  select * into d from public.devices where id = p_device and shop_id = public.current_shop_id() and deleted_at is null for update;
  if not found then raise exception 'E_NOT_FOUND'; end if;
  if d.status = p_status then
    return jsonb_build_object('applied', true, 'same', true);
  end if;
  if d.updated_at > p_client_ts then
    insert into public.audit_log(shop_id, actor_id, action, entity, entity_id, before, after)
    values (d.shop_id, auth.uid(), 'sync_conflict', 'devices', d.id,
            jsonb_build_object('status', d.status, 'updated_at', d.updated_at),
            jsonb_build_object('status', p_status, 'client_ts', p_client_ts, 'kept', 'server'));
    return jsonb_build_object('applied', false, 'reason', 'newer_on_server', 'server_status', d.status);
  end if;
  begin
    update public.devices set status = p_status where id = d.id;
  exception when others then
    -- التعديل ما ينفعش يتطبق (مثلًا الانتقال مش مسموح دلوقتي): بيتسجل تعارض بسببه
    insert into public.audit_log(shop_id, actor_id, action, entity, entity_id, before, after)
    values (d.shop_id, auth.uid(), 'sync_conflict', 'devices', d.id,
            jsonb_build_object('status', d.status, 'updated_at', d.updated_at),
            jsonb_build_object('status', p_status, 'client_ts', p_client_ts, 'kept', 'server', 'error', sqlerrm));
    return jsonb_build_object('applied', false, 'reason', 'rejected', 'error', sqlerrm, 'server_status', d.status);
  end;
  return jsonb_build_object('applied', true);
end $$;

-- ---------- 2) النسخة الكاملة ----------
create or replace function public.backup_snapshot(p_shop uuid) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare
  res jsonb := jsonb_build_object('format', 'warsha-backup', 'version', 1, 'generated_at', now(), 'shop_id', p_shop);
  t text;
  rows jsonb;
begin
  foreach t in array array['shops', 'profiles', 'customers', 'devices', 'device_costs', 'status_log', 'device_notes', 'device_photos', 'device_checks',
                           'quote_decisions', 'message_templates', 'message_log', 'accounts', 'journal_entries', 'journal_lines', 'payments', 'drawer_closings',
                           'suppliers', 'items', 'stock_moves', 'purchases', 'labor_rates', 'specialties', 'staff_specialties', 'routes', 'repair_steps', 'audit_log'] loop
    execute format('select coalesce(jsonb_agg(to_jsonb(x)), ''[]''::jsonb) from public.%I x where x.shop_id = $1', t) into rows using p_shop;
    -- توقيع العميل صورة كبيرة: بيفضل في النسخة، بس من غير أي أسرار
    res := res || jsonb_build_object(t, rows);
  end loop;
  -- الأقفال: نوعها بس، من غير السر
  select coalesce(jsonb_agg(jsonb_build_object('device_id', device_id, 'kind', kind, 'erased_at', erased_at)), '[]'::jsonb)
    into rows from public.device_passcodes where shop_id = p_shop;
  return res || jsonb_build_object('device_passcodes', rows);
end $$;
revoke execute on function public.backup_snapshot(uuid) from public, anon, authenticated;

create or replace function public.export_backup() returns jsonb
language plpgsql security definer set search_path = public as $$
declare s uuid := public.current_shop_id();
begin
  perform public.ledger_require(array['owner']::public.app_role[]);
  insert into public.audit_log(shop_id, actor_id, action, entity, entity_id, after)
  values (s, auth.uid(), 'backup_export', 'shops', s, jsonb_build_object('at', now()));
  return public.backup_snapshot(s);
end $$;
revoke execute on function public.export_backup() from public, anon;
grant execute on function public.export_backup() to authenticated;

-- ---------- 3) النسخة اليومية على السيرفر ----------
create table public.shop_backups (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references public.shops(id),
  data jsonb not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);
create index shop_backups_shop on public.shop_backups(shop_id, created_at desc);
alter table public.shop_backups enable row level security;
revoke all on public.shop_backups from public, anon, authenticated;
-- صاحب المحل بيشوف قايمة النسخ (من غير البيانات نفسها) وبينزّل آخر واحدة بالدالة
create policy backups_none on public.shop_backups for select to authenticated using (false);
create trigger block_delete before delete on public.shop_backups for each row execute function public.tg_block_delete();
create trigger set_updated_at before update on public.shop_backups for each row execute function public.tg_set_updated_at();

create or replace function public.daily_backups() returns integer
language plpgsql security definer set search_path = public as $$
declare s uuid; n int := 0;
begin
  for s in select id from public.shops where deleted_at is null loop
    insert into public.shop_backups(shop_id, data) values (s, public.backup_snapshot(s));
    n := n + 1;
  end loop;
  -- آخر 7 أيام بس: النسخ الأقدم بتتعلّم محذوفة (soft delete) ومحتواها بيتفضّى عشان المساحة. مفيش حذف فعلي
  update public.shop_backups b set deleted_at = now(), data = '{}'::jsonb where b.created_at < now() - interval '7 days' and b.deleted_at is null;
  return n;
end $$;
revoke execute on function public.daily_backups() from public, anon, authenticated;

create or replace function public.list_backups() returns table(id uuid, created_at timestamptz, size_kb integer)
language plpgsql stable security definer set search_path = public as $$
#variable_conflict use_column
begin
  perform public.ledger_require(array['owner']::public.app_role[]);
  return query select b.id, b.created_at, (octet_length(b.data::text) / 1024)::int from public.shop_backups b
    where b.shop_id = public.current_shop_id() and b.deleted_at is null order by b.created_at desc;
end $$;
create or replace function public.get_backup(p_id uuid) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare d jsonb;
begin
  perform public.ledger_require(array['owner']::public.app_role[]);
  select data into d from public.shop_backups where id = p_id and shop_id = public.current_shop_id() and deleted_at is null;
  if d is null then raise exception 'E_NOT_FOUND'; end if;
  return d;
end $$;
do $$
declare f text;
begin
  foreach f in array array['apply_status_lww(uuid, public.device_status, timestamptz)', 'list_backups()', 'get_backup(uuid)'] loop
    execute format('revoke execute on function public.%s from public, anon', f);
    execute format('grant execute on function public.%s to authenticated', f);
  end loop;
end $$;

-- جدولة يومية (3 الفجر بتوقيت القاهرة تقريبًا = 1 UTC) لو pg_cron متاح في المشروع
do $$
begin
  begin
    create extension if not exists pg_cron;
  exception when others then
    raise notice 'pg_cron مش متاح: النسخة اليومية التلقائية مش هتشتغل، والتصدير اليدوي شغال';
    return;
  end;
  begin
    perform cron.schedule('warsha-daily-backup', '0 1 * * *', 'select public.daily_backups()');
  exception when others then
    raise notice 'ما قدرناش نجدول النسخة اليومية: %', sqlerrm;
  end;
end $$;
