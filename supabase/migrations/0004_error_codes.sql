-- =====================================================================
-- المرحلة 1 (تكملة): أكواد أخطاء ثابتة بدل الرسايل العربي
-- التطبيق بيترجم الكود للغة الحالية (errors.db.E_*). نفس الدوال بالظبط، بس الرسالة كود.
-- =====================================================================

create or replace function public.tg_force_shop_id() returns trigger
language plpgsql security definer set search_path = public as $$
declare s uuid := public.current_shop_id();
begin
  if s is null then
    raise exception 'E_NO_SHOP';
  end if;
  if tg_op = 'INSERT' then
    new.shop_id := s;
  elsif new.shop_id is distinct from old.shop_id then
    raise exception 'E_SHOP_CHANGE';
  end if;
  return new;
end $$;

create or replace function public.tg_block_delete() returns trigger
language plpgsql as $$
begin
  raise exception 'E_HARD_DELETE';
end $$;

create or replace function public.tg_audit_immutable() returns trigger
language plpgsql as $$
begin
  raise exception 'E_AUDIT_IMMUTABLE';
end $$;

create or replace function public.tg_device_guard() returns trigger
language plpgsql security definer set search_path = public as $$
declare
  r public.app_role := public.current_app_role();
  fc integer;
begin
  -- حاجات ما بتتغيرش بعد الاستلام
  if new.order_no is distinct from old.order_no
     or new.received_at is distinct from old.received_at
     or new.received_by is distinct from old.received_by then
    raise exception 'E_RECEIPT_IMMUTABLE';
  end if;

  -- الفني يغيّر الحالة بس
  if r = 'technician' and
     (to_jsonb(new) - 'status' - 'updated_at' - 'delivered_at') <> (to_jsonb(old) - 'status' - 'updated_at' - 'delivered_at') then
    raise exception 'E_TECH_STATUS_ONLY';
  end if;

  if new.status is distinct from old.status then
    if not public.is_valid_transition(old.status, new.status) then
      raise exception 'E_BAD_TRANSITION';
    end if;
    if new.status = 'delivered' then
      if r = 'technician' then
        raise exception 'E_TECH_NO_DELIVER';
      end if;
      select final_cost into fc from public.device_costs where device_id = new.id and deleted_at is null;
      if fc is null then
        raise exception 'E_FINAL_COST_REQUIRED';
      end if;
      new.delivered_at := now();
    elsif old.status = 'delivered' then
      new.delivered_at := null;  -- رجع ضمان
    end if;
  elsif new.delivered_at is distinct from old.delivered_at then
    raise exception 'E_DELIVERED_AUTO';
  end if;
  return new;
end $$;

create or replace function public.tg_same_shop_refs() returns trigger
language plpgsql security definer set search_path = public as $$
declare ok boolean;
begin
  if tg_table_name = 'devices' then
    select exists(select 1 from public.customers c where c.id = new.customer_id and c.shop_id = new.shop_id and c.deleted_at is null) into ok;
  else
    select exists(select 1 from public.devices d where d.id = new.device_id and d.shop_id = new.shop_id) into ok;
  end if;
  if not ok then
    raise exception 'E_CROSS_SHOP';
  end if;
  return new;
end $$;

create or replace function public.tg_photo_limit() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  perform pg_advisory_xact_lock(hashtext(new.device_id::text));
  if (select count(*) from public.device_photos where device_id = new.device_id and deleted_at is null) >= 6 then
    raise exception 'E_PHOTO_LIMIT';
  end if;
  if new.storage_path not like new.shop_id::text || '/' || new.device_id::text || '/%' then
    raise exception 'E_PHOTO_PATH';
  end if;
  new.uploaded_by := auth.uid();
  return new;
end $$;

create or replace function public.tg_note_author() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if tg_op = 'INSERT' then
    new.author_id := auth.uid();
  elsif new.body is distinct from old.body or new.author_id is distinct from old.author_id then
    raise exception 'E_NOTE_IMMUTABLE';
  end if;
  return new;
end $$;

create or replace function public.tg_profile_guard() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if new.id = auth.uid() and (new.role is distinct from old.role or new.deleted_at is not null) then
    raise exception 'E_SELF_ROLE';
  end if;
  if new.role = 'owner' and old.role <> 'owner' then
    raise exception 'E_NO_NEW_OWNER';
  end if;
  if new.email is distinct from old.email or new.id is distinct from old.id then
    raise exception 'E_EMAIL_IMMUTABLE';
  end if;
  return new;
end $$;

create or replace function public.bootstrap_account(p_full_name text, p_shop_name text default null)
returns public.profiles
language plpgsql security definer set search_path = public as $$
declare
  uid uuid := auth.uid();
  em text;
  confirmed timestamptz;
  inv public.staff_invites;
  new_shop uuid;
  p public.profiles;
begin
  if uid is null then raise exception 'E_AUTH_REQUIRED'; end if;
  select * into p from public.profiles where id = uid;
  if found then
    if p.deleted_at is not null then raise exception 'E_SUSPENDED'; end if;
    return p;
  end if;

  select lower(u.email), u.email_confirmed_at into em, confirmed from auth.users u where u.id = uid;
  if em is null then raise exception 'E_UNKNOWN_USER'; end if;

  select * into inv from public.staff_invites
   where lower(email) = em and accepted_at is null and deleted_at is null
   order by created_at desc limit 1;

  if found then
    -- الانضمام بدعوة محتاج إيميل متأكَّد منه، عشان محدش ينتحل إيميل موظف
    if confirmed is null then raise exception 'E_EMAIL_UNCONFIRMED'; end if;
    insert into public.profiles(id, shop_id, full_name, email, role)
    values (uid, inv.shop_id, coalesce(nullif(trim(p_full_name), ''), inv.full_name), em, inv.role)
    returning * into p;
    update public.staff_invites set accepted_at = now() where id = inv.id;
    insert into public.audit_log(shop_id, actor_id, action, entity, entity_id, after)
    values (inv.shop_id, uid, 'join', 'profiles', uid, to_jsonb(p));
    return p;
  end if;

  new_shop := gen_random_uuid();
  insert into public.shops(id, shop_id, name)
  values (new_shop, new_shop, coalesce(nullif(trim(p_shop_name), ''), 'محل الصيانة'));
  insert into public.profiles(id, shop_id, full_name, email, role)
  values (uid, new_shop, coalesce(nullif(trim(p_full_name), ''), em), em, 'owner')
  returning * into p;
  insert into public.audit_log(shop_id, actor_id, action, entity, entity_id, after)
  values (new_shop, uid, 'create_shop', 'shops', new_shop, jsonb_build_object('name', p_shop_name));
  return p;
end $$;
