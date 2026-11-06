-- هوية كل محل على كل حاجة بتتطبع أو بتوصل للعميل (طلب صاحب المشروع)
--
-- - shop_branding: الاسم بالإنجليزي، والشعار القصير، والتليفونات، وواتساب، والسوشيال، واللوجو.
-- - اللوجو الأصلي في Storage (shop-logos) تحت shop_id، والـ bucket بقى خاص: كل محل بيشوف لوجو محله بس.
-- - بيتحفظ كمان نسختين جاهزين للطباعة (ملونة للفاتورة وصفحة التتبع، وأبيض وأسود للطابعة الحرارية) كصورة PNG صغيرة
--   في الجدول نفسه. كده الطباعة شغالة بدون نت، وصفحة التتبع العامة بتعرض اللوجو من غير ما تفتح الـ Storage للزوار.
-- - سطر "بواسطة [اسم التطبيق]" مقفول افتراضيًا.

create table public.shop_branding (
  id uuid primary key,
  shop_id uuid not null unique references public.shops(id),
  name_en text check (name_en is null or length(name_en) <= 120),
  tagline text check (tagline is null or length(tagline) <= 120),
  phones text[] not null default '{}' check (cardinality(phones) <= 4),
  whatsapp text check (whatsapp is null or length(whatsapp) <= 20),
  socials jsonb not null default '{}'::jsonb,
  logo_path text,                                   -- الأصل في Storage
  logo_color text check (logo_color is null or (logo_color like 'data:image/png;base64,%' and length(logo_color) < 700000)),
  logo_thermal text check (logo_thermal is null or (logo_thermal like 'data:image/png;base64,%' and length(logo_thermal) < 400000)),
  thermal_contrast integer not null default 50 check (thermal_contrast between 0 and 100),
  thermal_custom boolean not null default false,   -- صاحب المحل رفع نسخة حرارية بنفسه
  show_powered_by boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);
alter table public.shop_branding enable row level security;
revoke all on public.shop_branding from public, anon, authenticated;
create policy branding_select on public.shop_branding for select to authenticated using (shop_id = public.current_shop_id());
create policy branding_insert on public.shop_branding for insert to authenticated with check (shop_id = public.current_shop_id() and public.current_app_role() = 'owner');
create policy branding_update on public.shop_branding for update to authenticated using (shop_id = public.current_shop_id() and public.current_app_role() = 'owner') with check (shop_id = public.current_shop_id());
grant select, insert, update on public.shop_branding to authenticated;
create trigger set_updated_at before update on public.shop_branding for each row execute function public.tg_set_updated_at();
create trigger block_delete before delete on public.shop_branding for each row execute function public.tg_block_delete();
create trigger a_force_shop_id before insert or update on public.shop_branding for each row execute function public.tg_force_shop_id();
create trigger zz_audit after insert or update on public.shop_branding for each row execute function public.tg_audit();

-- ---------- اللوجو في Storage: خاص بكل محل ----------
update storage.buckets set public = false, file_size_limit = 2097152,
  allowed_mime_types = array['image/png', 'image/jpeg', 'image/svg+xml', 'image/webp'] where id = 'shop-logos';
do $$
begin
  begin
    drop policy if exists shop_logos_read on storage.objects;
  exception when others then null;
  end;
end $$;
create policy shop_logos_read on storage.objects for select to authenticated
  using (bucket_id = 'shop-logos' and (storage.foldername(name))[1] = public.current_shop_id()::text);
create policy shop_logos_update on storage.objects for update to authenticated
  using (bucket_id = 'shop-logos' and (storage.foldername(name))[1] = public.current_shop_id()::text and public.current_app_role() = 'owner');

-- ---------- صفحة التتبع: لوجو المحل الملون من الهوية ----------
create or replace function public.get_tracking(p_order text default null, p_last4 text default null, p_token text default null)
returns table(
  order_no text, status public.device_status, brand text, model text, received_at timestamptz,
  updated_at timestamptz, estimated_cost integer, final_cost integer, technician text,
  shop_name text, shop_phone text, shop_logo text, currency text, warranty_until timestamptz,
  can_decide boolean, decision text, due bigint
)
language plpgsql security definer set search_path = public as $$
declare
  k text := public.tracking_guard(p_order);
  d public.devices;
begin
  d := public.tracking_find(p_order, p_last4, p_token);
  if d.id is null then
    insert into public.tracking_attempts(client_key, order_no, success, guess) values (k, trim(p_order), false, public.tracking_guess(p_order, p_last4));
    return;
  end if;
  insert into public.tracking_attempts(shop_id, client_key, order_no, success) values (d.shop_id, k, d.order_no, true);
  return query
  select d.order_no, d.status, d.brand, d.model, d.received_at,
    coalesce((select max(l.created_at) from public.status_log l where l.device_id = d.id), d.updated_at),
    dc.estimated_cost, dc.final_cost,
    (select split_part(p.full_name, ' ', 1) from public.status_log l join public.profiles p on p.id = l.changed_by
       where l.device_id = d.id and p.role = 'technician' order by l.created_at desc limit 1),
    s.name, s.phone,
    -- لوجو المحل الملون (صورة صغيرة جاهزة)، مش مسار في Storage
    (select b.logo_color from public.shop_branding b where b.shop_id = s.id and b.deleted_at is null),
    s.currency, d.warranty_until,
    d.status = 'awaiting_approval' and not exists (
      select 1 from public.quote_decisions q where q.device_id = d.id and q.created_at > coalesce(
        (select max(l.created_at) from public.status_log l where l.device_id = d.id and l.new_status = 'awaiting_approval'), d.received_at)),
    (select q.decision from public.quote_decisions q where q.device_id = d.id order by q.created_at desc limit 1),
    case when dc.final_cost is not null then greatest(dc.final_cost - public.device_paid(d.id), 0)::bigint end
  from public.shops s
  left join public.device_costs dc on dc.device_id = d.id and dc.deleted_at is null
  where s.id = d.shop_id;
end $$;
revoke execute on function public.get_tracking(text, text, text) from public;
grant execute on function public.get_tracking(text, text, text) to anon, authenticated;

-- ---------- النسخة الاحتياطية بتشمل الهوية ----------
create or replace function public.backup_snapshot(p_shop uuid) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare
  res jsonb := jsonb_build_object('format', 'warsha-backup', 'version', 1, 'generated_at', now(), 'shop_id', p_shop);
  t text;
  rows jsonb;
begin
  foreach t in array array['shops', 'shop_branding', 'profiles', 'customers', 'devices', 'device_costs', 'status_log', 'device_notes', 'device_photos', 'device_checks',
                           'quote_decisions', 'message_templates', 'message_log', 'accounts', 'journal_entries', 'journal_lines', 'payments', 'drawer_closings',
                           'suppliers', 'items', 'stock_moves', 'purchases', 'labor_rates', 'specialties', 'staff_specialties', 'routes', 'repair_steps', 'audit_log'] loop
    execute format('select coalesce(jsonb_agg(to_jsonb(x)), ''[]''::jsonb) from public.%I x where x.shop_id = $1', t) into rows using p_shop;
    res := res || jsonb_build_object(t, rows);
  end loop;
  select coalesce(jsonb_agg(jsonb_build_object('device_id', device_id, 'kind', kind, 'erased_at', erased_at)), '[]'::jsonb)
    into rows from public.device_passcodes where shop_id = p_shop;
  return res || jsonb_build_object('device_passcodes', rows);
end $$;
revoke execute on function public.backup_snapshot(uuid) from public, anon, authenticated;
