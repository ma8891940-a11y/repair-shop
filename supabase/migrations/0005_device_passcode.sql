-- =====================================================================
-- المرحلة 1: كلمة سر / نمط قفل جهاز العميل
-- - القيمة نفسها متخزنة مشفّرة في Supabase Vault (vault.secrets)، مش في جداولنا.
-- - جدولنا فيه نوع القفل ورقم السر في الـ Vault بس.
-- - الحفظ: صاحب المحل والاستقبال (وقت الاستلام).
-- - المشاهدة: صاحب المحل والفني بس، وكل مشاهدة بتتسجل في سجل النشاط.
-- - التسليم بيمسح السر من الـ Vault نهائيًا.
-- =====================================================================

create table public.device_passcodes (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references public.shops(id),
  device_id uuid not null unique references public.devices(id),
  kind text not null check (kind in ('pin', 'pattern')),
  secret_id uuid,             -- رقم السر في vault.secrets (null = اتمسح)
  erased_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

create trigger set_updated_at before update on public.device_passcodes for each row execute function public.tg_set_updated_at();
create trigger block_delete before delete on public.device_passcodes for each row execute function public.tg_block_delete();

alter table public.device_passcodes enable row level security;
-- القراءة المباشرة للجدول (من غير القيمة) لموظفين المحل: عشان يعرفوا إن فيه قفل
create policy passcodes_select on public.device_passcodes for select to authenticated
  using (shop_id = public.current_shop_id());
-- مفيش insert/update/delete مباشر: كله من الدوال تحت
revoke insert, update, delete, truncate on public.device_passcodes from authenticated, anon;
grant select on public.device_passcodes to authenticated;

-- حفظ أو تغيير القفل
create or replace function public.set_device_passcode(p_device_id uuid, p_kind text, p_value text)
returns void
language plpgsql security definer set search_path = public as $$
declare
  shop uuid := public.current_shop_id();
  r public.app_role := public.current_app_role();
  dev public.devices;
  existing public.device_passcodes;
  sid uuid;
begin
  if shop is null then raise exception 'E_NO_SHOP'; end if;
  if r not in ('owner', 'reception') then raise exception 'E_FORBIDDEN'; end if;
  if p_kind not in ('pin', 'pattern') then raise exception 'E_BAD_INPUT'; end if;
  if p_value is null or length(trim(p_value)) = 0 or length(p_value) > 64 then raise exception 'E_BAD_INPUT'; end if;
  select * into dev from public.devices where id = p_device_id and shop_id = shop and deleted_at is null;
  if not found then raise exception 'E_NOT_FOUND'; end if;
  if dev.status = 'delivered' then raise exception 'E_DELIVERED_LOCKED'; end if;

  select * into existing from public.device_passcodes where device_id = p_device_id;
  if found and existing.secret_id is not null then
    perform vault.update_secret(existing.secret_id, p_value);
    update public.device_passcodes set kind = p_kind, erased_at = null where id = existing.id;
  else
    sid := vault.create_secret(p_value, 'device-passcode-' || p_device_id::text, 'device lock');
    if found then
      update public.device_passcodes set kind = p_kind, secret_id = sid, erased_at = null where id = existing.id;
    else
      insert into public.device_passcodes(shop_id, device_id, kind, secret_id) values (shop, p_device_id, p_kind, sid);
    end if;
  end if;
  -- السجل فيه نوع العملية بس، مش القيمة
  insert into public.audit_log(shop_id, actor_id, action, entity, entity_id, after)
  values (shop, auth.uid(), 'passcode_set', 'device_passcodes', p_device_id, jsonb_build_object('kind', p_kind));
end $$;

-- مشاهدة القفل: صاحب المحل والفني بس، وكل مشاهدة بتتسجل
create or replace function public.reveal_device_passcode(p_device_id uuid)
returns table(kind text, value text)
language plpgsql security definer set search_path = public as $$
declare
  shop uuid := public.current_shop_id();
  r public.app_role := public.current_app_role();
  pc public.device_passcodes;
  v text;
begin
  if shop is null then raise exception 'E_NO_SHOP'; end if;
  if r not in ('owner', 'technician') then raise exception 'E_FORBIDDEN'; end if;
  select * into pc from public.device_passcodes where device_id = p_device_id and shop_id = shop and deleted_at is null;
  if not found or pc.secret_id is null then raise exception 'E_NOT_FOUND'; end if;
  select ds.decrypted_secret into v from vault.decrypted_secrets ds where ds.id = pc.secret_id;
  insert into public.audit_log(shop_id, actor_id, action, entity, entity_id, after)
  values (shop, auth.uid(), 'passcode_viewed', 'device_passcodes', p_device_id, jsonb_build_object('kind', pc.kind));
  return query select pc.kind, v;
end $$;

-- عند التسليم: السر بيتمسح من الـ Vault نهائيًا
create or replace function public.tg_erase_passcode_on_delivery() returns trigger
language plpgsql security definer set search_path = public as $$
declare pc public.device_passcodes;
begin
  if new.status = 'delivered' and old.status is distinct from 'delivered' then
    select * into pc from public.device_passcodes where device_id = new.id and secret_id is not null;
    if found then
      delete from vault.secrets where id = pc.secret_id;
      update public.device_passcodes set secret_id = null, erased_at = now() where id = pc.id;
      insert into public.audit_log(shop_id, actor_id, action, entity, entity_id, after)
      values (new.shop_id, auth.uid(), 'passcode_erased', 'device_passcodes', new.id, jsonb_build_object('reason', 'delivered'));
    end if;
  end if;
  return null;
end $$;

create trigger zz_erase_passcode after update on public.devices
  for each row execute function public.tg_erase_passcode_on_delivery();

revoke execute on function public.set_device_passcode(uuid, text, text) from public, anon;
revoke execute on function public.reveal_device_passcode(uuid) from public, anon;
grant execute on function public.set_device_passcode(uuid, text, text) to authenticated;
grant execute on function public.reveal_device_passcode(uuid) to authenticated;
