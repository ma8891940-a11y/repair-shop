-- جوالك / Gawalak: إعداد قاعدة البيانات كاملة في خطوة واحدة.
-- شغّل الملف ده مرة واحدة بس على مشروع Supabase جديد فاضي (SQL Editor ← New query ← الصق ← Run).
-- الملف ده بيتولد تلقائيًا من supabase/migrations. ما تعدّلوش بإيدك: npm run db:setup-file
-- الملفات: 0001_phase1.sql, 0002_storage.sql, 0003_shop_profile_realtime.sql, 0004_error_codes.sql, 0005_device_passcode.sql, 0006_invite_name.sql, 0007_phase2_customer.sql, 0008_ledger.sql, 0009_tracking_guess_limit.sql, 0010_default_cashboxes.sql, 0011_finance_drilldown.sql, 0012_spec_completion.sql, 0013_tracking_ambiguous.sql, 0014_technicians.sql, 0015_offline_backup.sql, 0016_shop_identity.sql, 0017_growth.sql, 0018_account_state.sql, 0019_extras.sql, 0020_admin_paging.sql, 0021_spec_rules.sql, 0022_security_review.sql, 0023_restore.sql, 0024_signout.sql, 0025_integrity.sql, 0026_edit_delete.sql, 0027_inventory.sql, 0028_opening.sql, 0029_partners.sql, 0030_party_links.sql, 0031_partner_capital.sql, 0032_lists.sql, 0033_assistant.sql, 0034_branches.sql, 0035_lists_everywhere.sql, 0036_roles.sql

-- ============================== 0001_phase1.sql ==============================
-- =====================================================================
-- المرحلة 1: الأساس
-- الملف ده بيتشغّل مرة واحدة في Supabase (SQL Editor) على مشروع جديد.
-- القواعد: كل جدول فيه id/shop_id/created_at/updated_at/deleted_at،
-- RLS بتعزل كل محل، الفلوس بالقروش integer، والحذف soft delete بس.
-- =====================================================================

create extension if not exists pgcrypto;

-- ---------- الأنواع ----------
create type public.app_role as enum ('owner', 'reception', 'technician');
create type public.device_status as enum (
  'received', 'inspecting', 'awaiting_approval', 'awaiting_part', 'in_repair',
  'repaired', 'ready', 'delivered', 'warranty_return', 'unrepairable'
);

-- ---------- الجداول ----------
create table public.shops (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null,               -- لنفس المحل = id (عشان القاعدة: كل جدول فيه shop_id)
  name text not null default 'محل الصيانة' check (length(name) between 1 and 120),
  phone text,
  address text,
  receipt_terms text not null default
    'المحل غير مسؤول عن البيانات الموجودة على الجهاز.' || chr(10) ||
    'الأجهزة المتروكة أكثر من 30 يومًا بعد إبلاغ العميل بجاهزيتها لا يتحمل المحل مسؤوليتها.' || chr(10) ||
    'يجب إحضار هذا الإيصال عند الاستلام.',
  warranty_days integer not null default 30 check (warranty_days between 0 and 3650),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  constraint shops_self check (shop_id = id)
);

create table public.profiles (
  id uuid primary key,                 -- = auth.users.id
  shop_id uuid not null references public.shops(id),
  full_name text not null check (length(full_name) between 1 and 120),
  email text not null,
  role public.app_role not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz                -- موظف اتشال = deleted_at فيه قيمة، وبيتمنع من الدخول
);
create unique index profiles_one_shop on public.profiles(id);

-- دعوة موظف: صاحب المحل يكتب الإيميل والدور، والموظف يعمل حساب بنفس الإيميل فيدخل على المحل
create table public.staff_invites (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references public.shops(id),
  email text not null check (email = lower(email) and position('@' in email) > 1),
  full_name text not null check (length(full_name) between 1 and 120),
  role public.app_role not null check (role <> 'owner'),
  accepted_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);
create unique index staff_invites_open on public.staff_invites(lower(email))
  where accepted_at is null and deleted_at is null;

create table public.customers (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references public.shops(id),
  name text not null check (length(name) between 1 and 120),
  phone text not null check (phone ~ '^01[0125][0-9]{8}$'),
  area text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);
create unique index customers_phone_per_shop on public.customers(shop_id, phone) where deleted_at is null;

create table public.order_counters (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references public.shops(id),
  year integer not null,
  last_value integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  unique (shop_id, year)
);

create table public.devices (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references public.shops(id),
  customer_id uuid not null references public.customers(id),
  order_no text not null,
  brand text not null check (length(brand) between 1 and 60),
  model text not null check (length(model) between 1 and 80),
  imei text check (imei ~ '^[0-9]{0,20}$'),
  color text,
  accessories text[] not null default '{}',
  issue text not null check (length(issue) between 1 and 1000),
  cosmetic_condition text,
  status public.device_status not null default 'received',
  received_by uuid references public.profiles(id),
  received_at timestamptz not null default now(),
  delivered_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  unique (shop_id, order_no)
);
create index devices_shop_status on public.devices(shop_id, status) where deleted_at is null;
create index devices_shop_imei on public.devices(shop_id, imei) where deleted_at is null and imei is not null;

-- الأسعار في جدول لوحدها عشان الفني ما يشوفهاش (RLS بتمنعه من الجدول كله)
create table public.device_costs (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references public.shops(id),
  device_id uuid not null unique references public.devices(id),
  estimated_cost integer check (estimated_cost between 0 and 2000000000),  -- بالقروش
  final_cost integer check (final_cost between 0 and 2000000000),          -- بالقروش
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

create table public.device_photos (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references public.shops(id),
  device_id uuid not null references public.devices(id),
  storage_path text not null unique,
  uploaded_by uuid references public.profiles(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

-- ملاحظات داخلية: للفريق بس، ما تظهرش للعميل أبدًا
create table public.device_notes (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references public.shops(id),
  device_id uuid not null references public.devices(id),
  author_id uuid references public.profiles(id),
  body text not null check (length(body) between 1 and 2000),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

create table public.status_log (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references public.shops(id),
  device_id uuid not null references public.devices(id),
  old_status public.device_status,
  new_status public.device_status not null,
  changed_by uuid references public.profiles(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);
create index status_log_device on public.status_log(device_id, created_at);

create table public.audit_log (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references public.shops(id),
  actor_id uuid,
  action text not null,           -- insert / update / status_change / ...
  entity text not null,           -- اسم الجدول
  entity_id uuid,
  before jsonb,
  after jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);
create index audit_log_shop_time on public.audit_log(shop_id, created_at desc);

-- ---------- دوال مساعدة ----------
-- المحل والدور بتوع المستخدم الحالي. security definer عشان تقرا profiles من غير ما RLS تلف حوالين نفسها.
create or replace function public.current_shop_id() returns uuid
language sql stable security definer set search_path = public as $$
  select shop_id from public.profiles where id = auth.uid() and deleted_at is null
$$;

create or replace function public.current_app_role() returns public.app_role
language sql stable security definer set search_path = public as $$
  select role from public.profiles where id = auth.uid() and deleted_at is null
$$;

-- لازم تطابق TRANSITIONS في src/lib/status.ts
create or replace function public.is_valid_transition(old_s public.device_status, new_s public.device_status)
returns boolean language sql immutable as $$
  select case old_s
    when 'received'          then new_s in ('inspecting','unrepairable')
    when 'inspecting'        then new_s in ('awaiting_approval','awaiting_part','in_repair','unrepairable')
    when 'awaiting_approval' then new_s in ('in_repair','awaiting_part','unrepairable')
    when 'awaiting_part'     then new_s in ('in_repair','unrepairable')
    when 'in_repair'         then new_s in ('repaired','awaiting_part','unrepairable')
    when 'repaired'          then new_s in ('ready','in_repair')
    when 'ready'             then new_s in ('delivered')
    when 'delivered'         then new_s in ('warranty_return')
    when 'warranty_return'   then new_s in ('inspecting','in_repair')
    when 'unrepairable'      then new_s in ('delivered')
    else false end
$$;

-- ---------- Triggers عامة ----------
create or replace function public.tg_set_updated_at() returns trigger
language plpgsql as $$
begin
  new.updated_at := now();
  return new;
end $$;

-- أي صف جديد بياخد محل المستخدم الحالي غصب عنه. كده محدش يقدر يكتب في محل تاني.
create or replace function public.tg_force_shop_id() returns trigger
language plpgsql security definer set search_path = public as $$
declare s uuid := public.current_shop_id();
begin
  if s is null then
    raise exception 'المستخدم غير مرتبط بمحل';
  end if;
  if tg_op = 'INSERT' then
    new.shop_id := s;
  elsif new.shop_id is distinct from old.shop_id then
    raise exception 'ممنوع تغيير المحل';
  end if;
  return new;
end $$;

-- الحذف الفعلي ممنوع في كل الجداول (soft delete بس)
create or replace function public.tg_block_delete() returns trigger
language plpgsql as $$
begin
  raise exception 'الحذف الفعلي ممنوع. استخدم deleted_at';
end $$;

-- سجل النشاط: إضافة بس، ممنوع تعديل أو حذف حتى لصاحب المحل
create or replace function public.tg_audit_immutable() returns trigger
language plpgsql as $$
begin
  raise exception 'سجل النشاط لا يمكن تعديله أو حذفه';
end $$;

create or replace function public.tg_audit() returns trigger
language plpgsql security definer set search_path = public as $$
declare
  act text;
  shop uuid;
begin
  if tg_op = 'INSERT' then
    act := 'insert';
  elsif new.deleted_at is not null and old.deleted_at is null then
    act := 'soft_delete';
  else
    act := 'update';
  end if;
  shop := coalesce(new.shop_id, old.shop_id);
  -- تحديث بدون أي تغيير حقيقي (غير updated_at) ما يتسجلش
  if tg_op = 'UPDATE' and (to_jsonb(new) - 'updated_at') = (to_jsonb(old) - 'updated_at') then
    return new;
  end if;
  insert into public.audit_log(shop_id, actor_id, action, entity, entity_id, before, after)
  values (
    shop, auth.uid(), act, tg_table_name, new.id,
    case when tg_op = 'UPDATE' then to_jsonb(old) end,
    to_jsonb(new)
  );
  return new;
end $$;

-- ---------- Triggers خاصة بالأجهزة ----------
-- رقم الطلب التلقائي: سنة-مسلسل (2026-0001) لكل محل، والعداد يبدأ من الأول كل سنة
create or replace function public.tg_device_defaults() returns trigger
language plpgsql security definer set search_path = public as $$
declare
  y integer := extract(year from (now() at time zone 'Africa/Cairo'))::integer;
  n integer;
begin
  insert into public.order_counters(shop_id, year, last_value)
  values (new.shop_id, y, 1)
  on conflict (shop_id, year) do update set last_value = public.order_counters.last_value + 1
  returning last_value into n;
  new.order_no := y::text || '-' || lpad(n::text, 4, '0');
  new.status := 'received';
  new.received_by := auth.uid();
  new.received_at := now();
  new.delivered_at := null;
  return new;
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
    raise exception 'رقم الطلب وبيانات الاستلام ما بتتغيرش';
  end if;

  -- الفني يغيّر الحالة بس
  if r = 'technician' and
     (to_jsonb(new) - 'status' - 'updated_at' - 'delivered_at') <> (to_jsonb(old) - 'status' - 'updated_at' - 'delivered_at') then
    raise exception 'الفني يقدر يغيّر حالة الجهاز بس';
  end if;

  if new.status is distinct from old.status then
    if not public.is_valid_transition(old.status, new.status) then
      raise exception 'انتقال غير مسموح من % إلى %', old.status, new.status;
    end if;
    if new.status = 'delivered' then
      if r = 'technician' then
        raise exception 'الفني لا يسلّم الأجهزة';
      end if;
      select final_cost into fc from public.device_costs where device_id = new.id and deleted_at is null;
      if fc is null then
        raise exception 'لازم تكتب التكلفة النهائية قبل التسليم';
      end if;
      new.delivered_at := now();
    elsif old.status = 'delivered' then
      new.delivered_at := null;  -- رجع ضمان
    end if;
  elsif new.delivered_at is distinct from old.delivered_at then
    raise exception 'تاريخ التسليم بيتحدد تلقائيًا';
  end if;
  return new;
end $$;

-- كل تغيير حالة يتسجل: القديمة والجديدة والموظف والوقت
create or replace function public.tg_device_status_log() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if tg_op = 'INSERT' then
    insert into public.status_log(shop_id, device_id, old_status, new_status, changed_by)
    values (new.shop_id, new.id, null, new.status, auth.uid());
  elsif new.status is distinct from old.status then
    insert into public.status_log(shop_id, device_id, old_status, new_status, changed_by)
    values (new.shop_id, new.id, old.status, new.status, auth.uid());
  end if;
  return null;
end $$;

-- الجهاز والعميل والأسعار لازم يكونوا من نفس المحل
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
    raise exception 'المرجع مش موجود في نفس المحل';
  end if;
  return new;
end $$;

-- حد أقصى 6 صور لكل جهاز
create or replace function public.tg_photo_limit() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  perform pg_advisory_xact_lock(hashtext(new.device_id::text));
  if (select count(*) from public.device_photos where device_id = new.device_id and deleted_at is null) >= 6 then
    raise exception 'الحد الأقصى 6 صور لكل جهاز';
  end if;
  if new.storage_path not like new.shop_id::text || '/' || new.device_id::text || '/%' then
    raise exception 'مسار الصورة غير صالح';
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
    raise exception 'الملاحظة ما بتتعدلش بعد كتابتها';
  end if;
  return new;
end $$;

-- ممنوع حد يغيّر دوره بنفسه أو يشيل نفسه، وممنوع يبقى فيه أكتر من owner بالتعديل
create or replace function public.tg_profile_guard() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if new.id = auth.uid() and (new.role is distinct from old.role or new.deleted_at is not null) then
    raise exception 'ممنوع تغيّر دورك أو تشيل حسابك بنفسك';
  end if;
  if new.role = 'owner' and old.role <> 'owner' then
    raise exception 'ممنوع تعيين صاحب محل جديد من هنا';
  end if;
  if new.email is distinct from old.email or new.id is distinct from old.id then
    raise exception 'الإيميل ما بيتغيرش من هنا';
  end if;
  return new;
end $$;

-- ---------- ربط الـ Triggers ----------
do $$
declare t text;
begin
  foreach t in array array['shops','profiles','staff_invites','customers','order_counters','devices',
                           'device_costs','device_photos','device_notes','status_log','audit_log'] loop
    execute format('create trigger set_updated_at before update on public.%I for each row execute function public.tg_set_updated_at()', t);
    execute format('create trigger block_delete before delete on public.%I for each row execute function public.tg_block_delete()', t);
  end loop;
  foreach t in array array['customers','devices','device_costs','device_photos','device_notes','staff_invites'] loop
    execute format('create trigger a_force_shop_id before insert or update on public.%I for each row execute function public.tg_force_shop_id()', t);
  end loop;
  foreach t in array array['shops','profiles','staff_invites','customers','devices','device_costs','device_photos','device_notes'] loop
    execute format('create trigger zz_audit after insert or update on public.%I for each row execute function public.tg_audit()', t);
  end loop;
end $$;

create trigger audit_immutable before update on public.audit_log
  for each row execute function public.tg_audit_immutable();
create trigger status_log_immutable before update on public.status_log
  for each row execute function public.tg_audit_immutable();

create trigger device_defaults before insert on public.devices
  for each row execute function public.tg_device_defaults();
create trigger device_guard before update on public.devices
  for each row execute function public.tg_device_guard();
create trigger device_status_log after insert or update on public.devices
  for each row execute function public.tg_device_status_log();
create trigger zz_same_shop before insert or update on public.devices
  for each row execute function public.tg_same_shop_refs();
create trigger zz_same_shop before insert or update on public.device_costs
  for each row execute function public.tg_same_shop_refs();
create trigger zz_same_shop before insert on public.device_photos
  for each row execute function public.tg_same_shop_refs();
create trigger zz_same_shop before insert on public.device_notes
  for each row execute function public.tg_same_shop_refs();
create trigger zz_photo_limit before insert on public.device_photos
  for each row execute function public.tg_photo_limit();
create trigger note_author before insert or update on public.device_notes
  for each row execute function public.tg_note_author();
create trigger profile_guard before update on public.profiles
  for each row execute function public.tg_profile_guard();

-- ---------- أول دخول: إنشاء محل أو الانضمام بدعوة ----------
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
  if uid is null then raise exception 'لازم تسجّل دخول الأول'; end if;
  select * into p from public.profiles where id = uid;
  if found then
    if p.deleted_at is not null then raise exception 'الحساب ده موقوف'; end if;
    return p;
  end if;

  select lower(u.email), u.email_confirmed_at into em, confirmed from auth.users u where u.id = uid;
  if em is null then raise exception 'مستخدم غير معروف'; end if;

  select * into inv from public.staff_invites
   where lower(email) = em and accepted_at is null and deleted_at is null
   order by created_at desc limit 1;

  if found then
    -- الانضمام بدعوة محتاج إيميل متأكَّد منه، عشان محدش ينتحل إيميل موظف
    if confirmed is null then raise exception 'لازم تأكّد الإيميل الأول'; end if;
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

-- قبل أول دخول: هل فيه دعوة للإيميل ده؟ (يرجّع اسم المحل والدور بس)
create or replace function public.my_pending_invite()
returns table(shop_name text, role public.app_role)
language sql stable security definer set search_path = public as $$
  select s.name, i.role
  from public.staff_invites i
  join public.shops s on s.id = i.shop_id
  join auth.users u on u.id = auth.uid()
  where lower(i.email) = lower(u.email) and i.accepted_at is null and i.deleted_at is null
  order by i.created_at desc limit 1
$$;

-- ---------- عرض البحث في الأجهزة ----------
-- security_invoker = الصلاحيات بتاعة المستخدم نفسه (RLS بتشتغل). الفني هيشوف اسم العميل فاضي.
create view public.devices_list with (security_invoker = true) as
select d.id, d.shop_id, d.order_no, d.brand, d.model, d.imei, d.color, d.status,
       d.received_at, d.delivered_at, d.customer_id, d.deleted_at,
       c.name as customer_name, c.phone as customer_phone,
       dc.estimated_cost, dc.final_cost
from public.devices d
left join public.customers c on c.id = d.customer_id
left join public.device_costs dc on dc.device_id = d.id and dc.deleted_at is null;

-- ---------- الصلاحيات و RLS ----------
revoke all on all tables in schema public from anon;
revoke all on all functions in schema public from anon;
revoke delete, truncate on all tables in schema public from authenticated;
grant usage on schema public to authenticated;
grant select on all tables in schema public to authenticated;
grant insert, update on public.shops, public.profiles, public.staff_invites, public.customers,
  public.devices, public.device_costs, public.device_photos, public.device_notes to authenticated;
revoke insert, update on public.audit_log, public.status_log, public.order_counters from authenticated;
revoke execute on function public.bootstrap_account(text, text) from public;
grant execute on function public.bootstrap_account(text, text) to authenticated;
revoke execute on function public.my_pending_invite() from public;
grant execute on function public.my_pending_invite() to authenticated;

alter table public.shops enable row level security;
alter table public.profiles enable row level security;
alter table public.staff_invites enable row level security;
alter table public.customers enable row level security;
alter table public.order_counters enable row level security;
alter table public.devices enable row level security;
alter table public.device_costs enable row level security;
alter table public.device_photos enable row level security;
alter table public.device_notes enable row level security;
alter table public.status_log enable row level security;
alter table public.audit_log enable row level security;

-- المحل
create policy shops_select on public.shops for select to authenticated
  using (id = public.current_shop_id());
create policy shops_update on public.shops for update to authenticated
  using (id = public.current_shop_id() and public.current_app_role() = 'owner')
  with check (id = public.current_shop_id());

-- المستخدمين
create policy profiles_select on public.profiles for select to authenticated
  using (shop_id = public.current_shop_id());
create policy profiles_update on public.profiles for update to authenticated
  using (shop_id = public.current_shop_id() and public.current_app_role() = 'owner')
  with check (shop_id = public.current_shop_id());

create policy invites_all on public.staff_invites for select to authenticated
  using (shop_id = public.current_shop_id() and public.current_app_role() = 'owner');
create policy invites_insert on public.staff_invites for insert to authenticated
  with check (shop_id = public.current_shop_id() and public.current_app_role() = 'owner');
create policy invites_update on public.staff_invites for update to authenticated
  using (shop_id = public.current_shop_id() and public.current_app_role() = 'owner')
  with check (shop_id = public.current_shop_id());

-- العملاء: صاحب المحل والاستقبال بس
create policy customers_select on public.customers for select to authenticated
  using (shop_id = public.current_shop_id() and public.current_app_role() in ('owner','reception'));
create policy customers_insert on public.customers for insert to authenticated
  with check (shop_id = public.current_shop_id() and public.current_app_role() in ('owner','reception'));
create policy customers_update on public.customers for update to authenticated
  using (shop_id = public.current_shop_id() and public.current_app_role() in ('owner','reception'))
  with check (shop_id = public.current_shop_id());

create policy counters_select on public.order_counters for select to authenticated
  using (shop_id = public.current_shop_id());

-- الأجهزة: كل موظفين المحل يشوفوها (الفني من غير أسعار ولا بيانات عميل)
create policy devices_select on public.devices for select to authenticated
  using (shop_id = public.current_shop_id());
create policy devices_insert on public.devices for insert to authenticated
  with check (shop_id = public.current_shop_id() and public.current_app_role() in ('owner','reception'));
create policy devices_update on public.devices for update to authenticated
  using (shop_id = public.current_shop_id())
  with check (shop_id = public.current_shop_id());

-- الأسعار: صاحب المحل والاستقبال بس
create policy costs_select on public.device_costs for select to authenticated
  using (shop_id = public.current_shop_id() and public.current_app_role() in ('owner','reception'));
create policy costs_insert on public.device_costs for insert to authenticated
  with check (shop_id = public.current_shop_id() and public.current_app_role() in ('owner','reception'));
create policy costs_update on public.device_costs for update to authenticated
  using (shop_id = public.current_shop_id() and public.current_app_role() in ('owner','reception'))
  with check (shop_id = public.current_shop_id());

create policy photos_select on public.device_photos for select to authenticated
  using (shop_id = public.current_shop_id());
create policy photos_insert on public.device_photos for insert to authenticated
  with check (shop_id = public.current_shop_id() and public.current_app_role() in ('owner','reception'));
create policy photos_update on public.device_photos for update to authenticated
  using (shop_id = public.current_shop_id() and public.current_app_role() in ('owner','reception'))
  with check (shop_id = public.current_shop_id());

create policy notes_select on public.device_notes for select to authenticated
  using (shop_id = public.current_shop_id());
create policy notes_insert on public.device_notes for insert to authenticated
  with check (shop_id = public.current_shop_id());
create policy notes_update on public.device_notes for update to authenticated
  using (shop_id = public.current_shop_id() and (author_id = auth.uid() or public.current_app_role() = 'owner'))
  with check (shop_id = public.current_shop_id());

create policy status_log_select on public.status_log for select to authenticated
  using (shop_id = public.current_shop_id());

-- سجل النشاط: صاحب المحل بس يقرأ، ومحدش يكتب أو يعدّل أو يحذف (الكتابة من الـ triggers بس)
create policy audit_select on public.audit_log for select to authenticated
  using (shop_id = public.current_shop_id() and public.current_app_role() = 'owner');

-- ============================== 0002_storage.sql ==============================
-- =====================================================================
-- المرحلة 1: تخزين صور الأجهزة (Supabase Storage)
-- الصور خاصة (private): محدش يشوفها غير موظفين نفس المحل.
-- مسار كل صورة: {shop_id}/{device_id}/{اسم الملف}
-- =====================================================================

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('device-photos', 'device-photos', false, 5242880, array['image/jpeg','image/png','image/webp'])
on conflict (id) do nothing;

create policy device_photos_read on storage.objects for select to authenticated
  using (
    bucket_id = 'device-photos'
    and (storage.foldername(name))[1] = public.current_shop_id()::text
  );

create policy device_photos_upload on storage.objects for insert to authenticated
  with check (
    bucket_id = 'device-photos'
    and (storage.foldername(name))[1] = public.current_shop_id()::text
    and public.current_app_role() in ('owner','reception')
  );
-- مفيش سياسة تعديل أو حذف: الصورة بتفضل محفوظة، والإخفاء بيحصل بـ deleted_at في جدول device_photos.

-- ============================== 0003_shop_profile_realtime.sql ==============================
-- =====================================================================
-- إعدادات المحل من معالج التسجيل + التحديث اللحظي + شعار المحل
-- =====================================================================

alter table public.shops
  add column if not exists country text not null default 'EG' check (country ~ '^[A-Z]{2}$'),
  add column if not exists currency text not null default 'EGP' check (currency ~ '^[A-Z]{3}$'),
  add column if not exists payment_methods text[] not null default array['cash']::text[],
  add column if not exists logo_path text,
  add column if not exists theme text not null default 'dark' check (theme in ('dark', 'light')),
  add column if not exists locale text not null default 'ar' check (locale in ('ar', 'en')),
  add column if not exists setup_completed_at timestamptz;

-- طرق الدفع المسموحة بس
create or replace function public.valid_payment_methods(m text[]) returns boolean
language sql immutable as $$
  select coalesce(array_length(m, 1), 0) between 1 and 6
     and m <@ array['cash','card','bank_transfer','wallet','instapay','installments']::text[]
$$;
alter table public.shops drop constraint if exists shops_payment_methods_valid;
alter table public.shops add constraint shops_payment_methods_valid check (public.valid_payment_methods(payment_methods));

-- التحديث اللحظي للوحة التحكم (Supabase Realtime بيحترم RLS)
do $$
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    begin
      alter publication supabase_realtime add table public.devices, public.device_costs, public.status_log;
    exception when duplicate_object then null;
    end;
  end if;
end $$;

-- شعار المحل: بيظهر على الإيصال وصفحة التتبع، فالقراءة عامة. الرفع لصاحب المحل بس، جوه فولدر محله.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('shop-logos', 'shop-logos', true, 1048576, array['image/png','image/jpeg','image/webp','image/svg+xml'])
on conflict (id) do nothing;

create policy shop_logos_upload on storage.objects for insert to authenticated
  with check (
    bucket_id = 'shop-logos'
    and (storage.foldername(name))[1] = public.current_shop_id()::text
    and public.current_app_role() = 'owner'
  );

-- ============================== 0004_error_codes.sql ==============================
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

-- ============================== 0005_device_passcode.sql ==============================
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

-- ============================== 0006_invite_name.sql ==============================
-- الدعوة بترجّع كمان الاسم اللي صاحب المحل كتبه، عشان الموظف ينضم بيه
drop function if exists public.my_pending_invite();
create function public.my_pending_invite()
returns table(shop_name text, role public.app_role, full_name text)
language sql stable security definer set search_path = public as $$
  select s.name, i.role, i.full_name
  from public.staff_invites i
  join public.shops s on s.id = i.shop_id
  join auth.users u on u.id = auth.uid()
  where lower(i.email) = lower(u.email) and i.accepted_at is null and i.deleted_at is null
  order by i.created_at desc limit 1
$$;
revoke execute on function public.my_pending_invite() from public, anon;
grant execute on function public.my_pending_invite() to authenticated;

-- ============================== 0007_phase2_customer.sql ==============================
-- =====================================================================
-- المرحلة 2: العميل
-- - التتبع العام (get_tracking) من غير تسجيل دخول، ومن غير أي بيانات شخصية، مع حد للمحاولات الغلط.
-- - رمز سري لكل جهاز (tracking_token) بيتحط في الـ QR.
-- - الموافقة على التكلفة من صفحة التتبع.
-- - قوالب واتساب يعدّلها صاحب المحل، وسجل الرسايل.
-- - تصنيف العملاء، والفحص السريع عند الاستلام والتسليم، والضمان.
-- =====================================================================

-- ---------- الجهاز: رمز التتبع والضمان ----------
alter table public.devices
  add column if not exists tracking_token text,
  add column if not exists warranty_days integer check (warranty_days between 0 and 3650),
  add column if not exists warranty_until timestamptz;
update public.devices set tracking_token = encode(gen_random_bytes(12), 'hex') where tracking_token is null;
alter table public.devices alter column tracking_token set default encode(gen_random_bytes(12), 'hex');
alter table public.devices alter column tracking_token set not null;
create unique index if not exists devices_tracking_token on public.devices(tracking_token);
create index if not exists devices_order_no on public.devices(order_no);

-- عند التسليم: الضمان بيتحسب من مدة الضمان بتاعة المحل وقتها
create or replace function public.tg_device_warranty() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if new.status = 'delivered' and old.status is distinct from 'delivered' then
    if new.warranty_days is null then
      select s.warranty_days into new.warranty_days from public.shops s where s.id = new.shop_id;
    end if;
    new.warranty_until := now() + make_interval(days => coalesce(new.warranty_days, 0));
  end if;
  if new.tracking_token is distinct from old.tracking_token then
    raise exception 'E_RECEIPT_IMMUTABLE';
  end if;
  return new;
end $$;
create trigger device_warranty before update on public.devices for each row execute function public.tg_device_warranty();

-- ---------- العملاء: التصنيف ----------
alter table public.customers
  add column if not exists category text not null default 'new' check (category in ('new', 'regular', 'vip', 'late')),
  add column if not exists marketing_ok boolean not null default false;

-- ---------- محاولات التتبع (للحد من التخمين) ----------
create table public.tracking_attempts (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid references public.shops(id), -- فاضي لو رقم الطلب مش موجود أصلًا
  client_key text not null,                  -- عنوان الجهاز اللي بيحاول (من هيدر الطلب)
  order_no text,
  success boolean not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);
create index tracking_attempts_key_time on public.tracking_attempts(client_key, created_at desc);
create index tracking_attempts_order_time on public.tracking_attempts(order_no, created_at desc);
alter table public.tracking_attempts enable row level security;
revoke all on public.tracking_attempts from anon, authenticated;
create trigger block_delete before delete on public.tracking_attempts for each row execute function public.tg_block_delete();

-- ---------- قرارات العميل على التكلفة ----------
create table public.quote_decisions (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references public.shops(id),
  device_id uuid not null references public.devices(id),
  decision text not null check (decision in ('approved', 'rejected')),
  amount integer check (amount between 0 and 2000000000), -- بالقروش: التكلفة اللي العميل وافق عليها أو رفضها
  client_key text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);
alter table public.quote_decisions enable row level security;
create policy quote_decisions_select on public.quote_decisions for select to authenticated
  using (shop_id = public.current_shop_id());
revoke insert, update, delete, truncate on public.quote_decisions from anon, authenticated;
grant select on public.quote_decisions to authenticated;
create trigger block_delete before delete on public.quote_decisions for each row execute function public.tg_block_delete();
create trigger immutable before update on public.quote_decisions for each row execute function public.tg_audit_immutable();

-- ---------- قوالب واتساب وسجل الرسايل ----------
create table public.message_templates (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references public.shops(id),
  key text not null check (key in ('received', 'status', 'approval', 'ready', 'reminder', 'delivered')),
  body text not null check (length(body) between 1 and 1000),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  unique (shop_id, key)
);
alter table public.message_templates enable row level security;
create policy templates_select on public.message_templates for select to authenticated using (shop_id = public.current_shop_id());
create policy templates_insert on public.message_templates for insert to authenticated
  with check (shop_id = public.current_shop_id() and public.current_app_role() = 'owner');
create policy templates_update on public.message_templates for update to authenticated
  using (shop_id = public.current_shop_id() and public.current_app_role() = 'owner') with check (shop_id = public.current_shop_id());
grant select, insert, update on public.message_templates to authenticated;

create table public.message_log (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references public.shops(id),
  device_id uuid references public.devices(id),
  customer_id uuid references public.customers(id),
  template_key text not null,
  body text not null,
  sent_by uuid references public.profiles(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);
alter table public.message_log enable row level security;
create policy message_log_select on public.message_log for select to authenticated
  using (shop_id = public.current_shop_id() and public.current_app_role() in ('owner', 'reception'));
create policy message_log_insert on public.message_log for insert to authenticated
  with check (shop_id = public.current_shop_id() and public.current_app_role() in ('owner', 'reception'));
grant select, insert on public.message_log to authenticated;

-- ---------- الفحص السريع ----------
create table public.device_checks (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references public.shops(id),
  device_id uuid not null references public.devices(id),
  stage text not null check (stage in ('intake', 'delivery')),
  items jsonb not null check (jsonb_typeof(items) = 'object'),
  checked_by uuid references public.profiles(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);
create unique index device_checks_one_per_stage on public.device_checks(device_id, stage) where deleted_at is null;
alter table public.device_checks enable row level security;
create policy checks_select on public.device_checks for select to authenticated using (shop_id = public.current_shop_id());
create policy checks_insert on public.device_checks for insert to authenticated with check (shop_id = public.current_shop_id());
create policy checks_update on public.device_checks for update to authenticated using (shop_id = public.current_shop_id()) with check (shop_id = public.current_shop_id());
grant select, insert, update on public.device_checks to authenticated;

create or replace function public.tg_check_author() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  new.checked_by := auth.uid();
  return new;
end $$;

-- الـ triggers العامة للجداول الجديدة
do $$
declare t text;
begin
  foreach t in array array['message_templates','message_log','device_checks'] loop
    execute format('create trigger set_updated_at before update on public.%I for each row execute function public.tg_set_updated_at()', t);
    execute format('create trigger block_delete before delete on public.%I for each row execute function public.tg_block_delete()', t);
    execute format('create trigger a_force_shop_id before insert or update on public.%I for each row execute function public.tg_force_shop_id()', t);
    execute format('create trigger zz_audit after insert or update on public.%I for each row execute function public.tg_audit()', t);
  end loop;
end $$;
create trigger zz_same_shop before insert or update on public.device_checks for each row execute function public.tg_same_shop_refs();
create trigger check_author before insert or update on public.device_checks for each row execute function public.tg_check_author();

-- ---------- حماية المحل: تعديل من غير مستخدم (من دوال التتبع بس) ----------
-- العميل من صفحة التتبع ملوش حساب، فالدالة الموثوقة (security definer) هي اللي بتعدّل.
-- الـ anon ملوش أي صلاحية مباشرة على الجداول، فالاستثناء ده بيشتغل من جوه الدوال بس، وبشرط إن المحل ما يتغيرش.
create or replace function public.tg_force_shop_id() returns trigger
language plpgsql security definer set search_path = public as $$
declare s uuid := public.current_shop_id();
begin
  if s is null then
    if tg_op = 'UPDATE' and auth.uid() is null and new.shop_id = old.shop_id then
      return new;
    end if;
    raise exception 'E_NO_SHOP';
  end if;
  if tg_op = 'INSERT' then
    new.shop_id := s;
  elsif new.shop_id is distinct from old.shop_id then
    raise exception 'E_SHOP_CHANGE';
  end if;
  return new;
end $$;

-- ---------- التتبع العام ----------
create or replace function public.tracking_client_key() returns text
language sql stable as $$
  select coalesce(
    nullif(split_part(coalesce(current_setting('request.headers', true)::json ->> 'x-forwarded-for', ''), ',', 1), ''),
    nullif(current_setting('request.headers', true)::json ->> 'x-real-ip', ''),
    'unknown')
$$;

-- يلاقي الجهاز برقم الطلب + (الرمز السري من الـ QR أو آخر 4 أرقام من موبايل العميل)
create or replace function public.tracking_find(p_order text, p_last4 text, p_token text)
returns public.devices
language plpgsql stable security definer set search_path = public as $$
declare d public.devices;
begin
  if p_token is not null and length(p_token) >= 16 then
    select * into d from public.devices where tracking_token = p_token and deleted_at is null;
    if found and (p_order is null or d.order_no = trim(p_order)) then return d; end if;
    return null;
  end if;
  if p_order is null or p_last4 is null or p_last4 !~ '^[0-9]{4}$' then return null; end if;
  select dv.* into d
  from public.devices dv join public.customers c on c.id = dv.customer_id
  where dv.order_no = trim(p_order) and right(c.phone, 4) = p_last4 and dv.deleted_at is null
  order by dv.received_at desc limit 1;
  if found then return d; end if;
  return null;
end $$;

-- حد المحاولات: 10 غلط في 15 دقيقة لنفس الجهاز، أو 5 غلط لنفس رقم الطلب
create or replace function public.tracking_guard(p_order text) returns text
language plpgsql security definer set search_path = public as $$
declare k text := public.tracking_client_key();
begin
  if (select count(*) from public.tracking_attempts where client_key = k and not success and created_at > now() - interval '15 minutes') >= 10
     or (p_order is not null and (select count(*) from public.tracking_attempts where order_no = trim(p_order) and not success and created_at > now() - interval '15 minutes') >= 5) then
    raise exception 'E_RATE_LIMIT';
  end if;
  return k;
end $$;

create or replace function public.get_tracking(p_order text default null, p_last4 text default null, p_token text default null)
returns table(
  order_no text, status public.device_status, brand text, model text, received_at timestamptz,
  updated_at timestamptz, estimated_cost integer, final_cost integer, technician text,
  shop_name text, shop_phone text, shop_logo text, currency text, warranty_until timestamptz,
  can_decide boolean, decision text
)
language plpgsql security definer set search_path = public as $$
declare
  k text := public.tracking_guard(p_order);
  d public.devices;
begin
  d := public.tracking_find(p_order, p_last4, p_token);
  if d.id is null then
    -- مش بنرمي خطأ هنا عشان المحاولة الغلط تفضل متسجلة (الخطأ بيلغي التسجيل). النتيجة الفاضية = مش موجود
    insert into public.tracking_attempts(client_key, order_no, success) values (k, trim(p_order), false);
    return;
  end if;
  insert into public.tracking_attempts(shop_id, client_key, order_no, success) values (d.shop_id, k, d.order_no, true);
  return query
  select d.order_no, d.status, d.brand, d.model, d.received_at,
    coalesce((select max(l.created_at) from public.status_log l where l.device_id = d.id), d.updated_at),
    dc.estimated_cost, dc.final_cost,
    -- اسم الفني: آخر فني غيّر الحالة (الاسم الأول بس)
    (select split_part(p.full_name, ' ', 1) from public.status_log l join public.profiles p on p.id = l.changed_by
       where l.device_id = d.id and p.role = 'technician' order by l.created_at desc limit 1),
    s.name, s.phone, s.logo_path, s.currency, d.warranty_until,
    d.status = 'awaiting_approval' and not exists (
      select 1 from public.quote_decisions q where q.device_id = d.id and q.created_at > coalesce(
        (select max(l.created_at) from public.status_log l where l.device_id = d.id and l.new_status = 'awaiting_approval'), d.received_at)),
    (select q.decision from public.quote_decisions q where q.device_id = d.id order by q.created_at desc limit 1)
  from public.shops s
  left join public.device_costs dc on dc.device_id = d.id and dc.deleted_at is null
  where s.id = d.shop_id;
end $$;

-- موافقة أو رفض العميل على التكلفة (من صفحة التتبع)
create or replace function public.decide_quote(p_decision text, p_order text default null, p_last4 text default null, p_token text default null)
returns public.device_status
language plpgsql security definer set search_path = public as $$
declare
  k text := public.tracking_guard(p_order);
  d public.devices;
  amt integer;
  next_status public.device_status;
begin
  if p_decision not in ('approved', 'rejected') then raise exception 'E_BAD_INPUT'; end if;
  d := public.tracking_find(p_order, p_last4, p_token);
  if d.id is null then
    insert into public.tracking_attempts(client_key, order_no, success) values (k, trim(p_order), false);
    return null;
  end if;
  if d.status <> 'awaiting_approval' then raise exception 'E_BAD_TRANSITION'; end if;
  select coalesce(final_cost, estimated_cost) into amt from public.device_costs where device_id = d.id and deleted_at is null;
  insert into public.quote_decisions(shop_id, device_id, decision, amount, client_key) values (d.shop_id, d.id, p_decision, amt, k);
  next_status := case when p_decision = 'approved' then 'in_repair'::public.device_status else 'unrepairable'::public.device_status end;
  update public.devices set status = next_status where id = d.id;
  insert into public.audit_log(shop_id, actor_id, action, entity, entity_id, after)
  values (d.shop_id, null, 'customer_' || p_decision, 'devices', d.id, jsonb_build_object('amount', amt, 'order_no', d.order_no));
  return next_status;
end $$;

revoke execute on function public.get_tracking(text, text, text) from public;
revoke execute on function public.decide_quote(text, text, text, text) from public;
revoke execute on function public.tracking_find(text, text, text) from public, anon, authenticated;
revoke execute on function public.tracking_guard(text) from public, anon, authenticated;
grant execute on function public.get_tracking(text, text, text) to anon, authenticated;
grant execute on function public.decide_quote(text, text, text, text) to anon, authenticated;

-- العرض محتاج رمز التتبع للـ QR والطباعة (لموظفين المحل بس، الـ RLS على الأجهزة)
create or replace view public.devices_list with (security_invoker = true) as
select d.id, d.shop_id, d.order_no, d.brand, d.model, d.imei, d.color, d.status,
       d.received_at, d.delivered_at, d.customer_id, d.deleted_at,
       c.name as customer_name, c.phone as customer_phone,
       dc.estimated_cost, dc.final_cost, d.warranty_until
from public.devices d
left join public.customers c on c.id = d.customer_id
left join public.device_costs dc on dc.device_id = d.id and dc.deleted_at is null;
grant select on public.devices_list to authenticated;

-- ---------- الزائر (anon) ملوش أي صلاحية مباشرة على أي جدول ----------
-- Supabase بيدّي anon صلاحيات تلقائية على الجداول الجديدة. الـ RLS بتمنع الصفوف، بس إحنا كمان بنشيل الصلاحية نفسها،
-- والوصول الوحيد للزائر هو دوال التتبع (get_tracking / decide_quote).
revoke all on all tables in schema public from anon;
revoke all on all sequences in schema public from anon;
alter default privileges in schema public revoke all on tables from anon;
alter default privileges in schema public revoke all on sequences from anon;
alter default privileges in schema public revoke execute on functions from anon;

-- ============================== 0008_ledger.sql ==============================
-- المرحلة 3: الفلوس بدفتر قيود مزدوج (docs/phase-3-ledger.md)
--
-- القواعد:
-- - كل حركة فلوس = قيد (journal_entries) فيه سطرين أو أكتر (journal_lines)، ومجموع المدين = مجموع الدائن بالظبط.
-- - الأرصدة مش متخزنة في أي مكان: كلها بتتحسب من سطور القيود.
-- - القيد ما بيتعدلش ولا بيتحذف أبدًا (حتى من SQL). الغلط بيتصلح بقيد عكسي مربوط بالأصلي.
-- - كل العمليات بدوال جوه قاعدة البيانات (كل دالة transaction واحدة): يا كله يتسجل يا ولا حاجة.
-- - المبالغ بالقروش أعداد صحيحة (bigint في الجمع).
-- - المخزون: الكمية والقيمة بتتحسب من حركات المخزون، والتكلفة بالمتوسط المرجّح.

-- ============================================================
-- 1) الحسابات
-- ============================================================
create type public.account_type as enum ('asset', 'liability', 'equity', 'revenue', 'expense');

create table public.accounts (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references public.shops(id),
  code text,                       -- للحسابات الأساسية (ar, ap, inventory, ...). الحسابات المضافة code = null
  name text,                       -- اسم مكتوب لحساب مضاف. الأساسية بتتترجم في الواجهة من code
  type public.account_type not null,
  kind text not null check (kind in ('cash', 'receivable', 'advances', 'inventory', 'payable', 'salaries', 'capital', 'drawings', 'revenue', 'cogs', 'expense', 'shortage', 'overage')),
  method text,                     -- للخزن: طريقة الدفع (cash, wallet, instapay, ...)
  holder_id uuid references public.profiles(id), -- للخزن: الموظف المسؤول عن الدرج
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  check (code is not null or nullif(trim(name), '') is not null),
  check ((kind = 'cash') = (method is not null)),
  check (holder_id is null or kind = 'cash')
);
create unique index accounts_code on public.accounts(shop_id, code) where code is not null;
create index accounts_shop on public.accounts(shop_id, kind);

-- الطرف الطبيعي للحساب: الأصول والمصروفات مدينة، والباقي دائن
create or replace function public.account_sign(t public.account_type) returns integer
language sql immutable as $$ select case when t in ('asset', 'expense') then 1 else -1 end $$;

-- ============================================================
-- 2) القيود
-- ============================================================
create table public.journal_entries (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references public.shops(id),
  entry_no bigint generated always as identity,
  occurred_at timestamptz not null default now(),
  source_type text not null check (source_type in ('payment', 'delivery', 'purchase', 'supplier_payment', 'part_use', 'sale', 'expense', 'salary', 'salary_payment', 'advance', 'advance_settle', 'capital', 'drawing', 'transfer', 'drawer_close', 'reversal')),
  source_id uuid,
  device_id uuid references public.devices(id),
  memo text check (length(memo) <= 500),
  idem_key uuid unique,            -- رقم العملية من التطبيق: نفس العملية لو اتبعتت مرتين ما تتسجلش مرتين
  reverses_id uuid unique references public.journal_entries(id),
  created_by uuid references public.profiles(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);
create index journal_entries_shop_time on public.journal_entries(shop_id, occurred_at);
create index journal_entries_source on public.journal_entries(source_type, source_id);

create table public.journal_lines (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references public.shops(id),
  entry_id uuid not null references public.journal_entries(id),
  account_id uuid not null references public.accounts(id),
  party_type text check (party_type in ('customer', 'supplier', 'employee')),
  party_id uuid,
  debit bigint not null default 0 check (debit >= 0 and debit <= 100000000000),
  credit bigint not null default 0 check (credit >= 0 and credit <= 100000000000),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  check ((debit > 0) <> (credit > 0)),
  check ((party_type is null) = (party_id is null))
);
create index journal_lines_entry on public.journal_lines(entry_id);
create index journal_lines_account on public.journal_lines(account_id);
create index journal_lines_party on public.journal_lines(party_type, party_id);

-- ============================================================
-- 3) الموردين والأصناف والمخزون والدفعات والدرج
-- ============================================================
create table public.suppliers (
  id uuid primary key,
  shop_id uuid not null references public.shops(id),
  name text not null check (length(trim(name)) between 1 and 120),
  phone text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

create table public.items (
  id uuid primary key,
  shop_id uuid not null references public.shops(id),
  kind text not null check (kind in ('part', 'accessory')),
  name text not null check (length(trim(name)) between 1 and 160),
  sku text,
  sale_price integer check (sale_price is null or sale_price between 0 and 2000000000),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

create table public.stock_moves (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references public.shops(id),
  item_id uuid not null references public.items(id),
  entry_id uuid not null references public.journal_entries(id),
  qty integer not null check (qty <> 0),
  value bigint not null,           -- القيمة بالقروش (موجبة للداخل وسالبة للخارج)
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);
create index stock_moves_item on public.stock_moves(item_id);

create table public.payments (
  id uuid primary key,
  shop_id uuid not null references public.shops(id),
  customer_id uuid not null references public.customers(id),
  device_id uuid references public.devices(id),
  cashbox_id uuid not null references public.accounts(id),
  method text not null,
  amount bigint not null check (amount > 0),
  entry_id uuid not null unique references public.journal_entries(id),
  created_by uuid references public.profiles(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);
create index payments_device on public.payments(device_id);

create table public.drawer_closings (
  id uuid primary key,
  shop_id uuid not null references public.shops(id),
  cashbox_id uuid not null references public.accounts(id),
  expected bigint not null,
  counted bigint not null check (counted >= 0),
  diff bigint not null,
  entry_id uuid references public.journal_entries(id),
  note text,
  closed_by uuid references public.profiles(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

-- ============================================================
-- 4) الحماية: ما بيتعدلش، وما بيتحذفش، والقيد لازم يتوازن
-- ============================================================
create or replace function public.tg_ledger_immutable() returns trigger
language plpgsql as $$
begin
  raise exception 'E_LEDGER_IMMUTABLE';
end $$;

do $$
declare t text;
begin
  foreach t in array array['journal_entries', 'journal_lines', 'stock_moves', 'payments', 'drawer_closings'] loop
    execute format('create trigger ledger_immutable before update or delete on public.%I for each row execute function public.tg_ledger_immutable()', t);
    execute format('create trigger ledger_no_truncate before truncate on public.%I for each statement execute function public.tg_ledger_immutable()', t);
  end loop;
  foreach t in array array['accounts', 'suppliers', 'items'] loop
    execute format('create trigger set_updated_at before update on public.%I for each row execute function public.tg_set_updated_at()', t);
    execute format('create trigger block_delete before delete on public.%I for each row execute function public.tg_block_delete()', t);
    execute format('create trigger a_force_shop_id before insert or update on public.%I for each row execute function public.tg_force_shop_id()', t);
  end loop;
  foreach t in array array['accounts', 'suppliers', 'items', 'journal_entries', 'payments', 'drawer_closings'] loop
    execute format('create trigger zz_audit after insert or update on public.%I for each row execute function public.tg_audit()', t);
  end loop;
end $$;

-- التوازن بيتراجع في آخر الـ transaction (deferred): أي قيد مش متوازن = الـ transaction كلها بتتلغي
-- security definer: الفحص بيحصل في آخر العملية بصلاحيات المستخدم، والمستخدم (زي الاستقبال) ما بيشوفش السطور
create or replace function public.tg_entry_balanced() returns trigger
language plpgsql security definer set search_path = public as $$
declare d bigint; c bigint; n int;
begin
  select coalesce(sum(debit), 0), coalesce(sum(credit), 0), count(*) into d, c, n from public.journal_lines where entry_id = new.entry_id;
  if n < 2 or d <> c then
    raise exception 'E_UNBALANCED';
  end if;
  return null;
end $$;
create constraint trigger entry_balanced after insert on public.journal_lines
  deferrable initially deferred for each row execute function public.tg_entry_balanced();

-- ============================================================
-- 5) الحسابات الأساسية لكل محل
-- ============================================================
create or replace function public.ensure_ledger_accounts(p_shop uuid) returns void
language plpgsql security definer set search_path = public as $$
declare m text;
begin
  insert into public.accounts(shop_id, code, type, kind)
  select p_shop, v.code, v.type::public.account_type, v.kind from (values
    ('ar', 'asset', 'receivable'), ('advances', 'asset', 'advances'), ('inventory', 'asset', 'inventory'),
    ('ap', 'liability', 'payable'), ('salaries_payable', 'liability', 'salaries'),
    ('capital', 'equity', 'capital'), ('drawings', 'equity', 'drawings'),
    ('rev_repair', 'revenue', 'revenue'), ('rev_parts', 'revenue', 'revenue'), ('rev_accessories', 'revenue', 'revenue'), ('overage', 'revenue', 'overage'),
    ('cogs', 'expense', 'cogs'), ('shortage', 'expense', 'shortage'),
    ('exp_salaries', 'expense', 'expense'), ('exp_rent', 'expense', 'expense'), ('exp_electricity', 'expense', 'expense'),
    ('exp_internet', 'expense', 'expense'), ('exp_purchases', 'expense', 'expense')
  ) as v(code, type, kind)
  on conflict (shop_id, code) where code is not null do nothing;
  -- خزنة لكل طريقة دفع مفعّلة في المحل
  for m in select unnest(payment_methods) from public.shops where id = p_shop loop
    insert into public.accounts(shop_id, code, type, kind, method)
    values (p_shop, 'cash_' || m, 'asset', 'cash', m)
    on conflict (shop_id, code) where code is not null do nothing;
  end loop;
end $$;
revoke execute on function public.ensure_ledger_accounts(uuid) from public, anon, authenticated;

-- إضافة الحسابات بتحصل من غير مستخدم (trigger على المحل)، فبنعدّي force_shop_id بإعداد مؤقت
create or replace function public.tg_force_shop_id() returns trigger
language plpgsql security definer set search_path = public as $$
declare s uuid := public.current_shop_id();
begin
  if current_setting('warsha.system', true) = 'on' then
    return new;
  end if;
  if s is null then
    if tg_op = 'UPDATE' and auth.uid() is null and new.shop_id = old.shop_id then
      return new;
    end if;
    raise exception 'E_NO_SHOP';
  end if;
  if tg_op = 'INSERT' then
    new.shop_id := s;
  elsif new.shop_id is distinct from old.shop_id then
    raise exception 'E_SHOP_CHANGE';
  end if;
  return new;
end $$;

create or replace function public.tg_shop_ledger() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  perform set_config('warsha.system', 'on', true);
  perform public.ensure_ledger_accounts(new.id);
  perform set_config('warsha.system', 'off', true);
  return null;
end $$;
create trigger zz_shop_ledger after insert or update of payment_methods on public.shops
  for each row execute function public.tg_shop_ledger();

-- المحلات الموجودة قبل كده
do $$
declare s uuid;
begin
  perform set_config('warsha.system', 'on', true);
  for s in select id from public.shops loop
    perform public.ensure_ledger_accounts(s);
  end loop;
  perform set_config('warsha.system', 'off', true);
end $$;

-- ============================================================
-- 6) تسجيل قيد (داخلية: الدوال بس هي اللي بتناديها)
-- ============================================================
-- p_lines: [{"account": uuid, "debit": n, "credit": n, "party_type": "...", "party_id": uuid}]
create or replace function public.ledger_post(
  p_source_type text, p_source_id uuid, p_memo text, p_lines jsonb,
  p_device uuid default null, p_idem uuid default null, p_reverses uuid default null
) returns uuid
language plpgsql security definer set search_path = public as $$
declare
  s uuid := public.current_shop_id();
  e uuid := gen_random_uuid();
  l jsonb;
  a public.accounts;
  d bigint := 0;
  c bigint := 0;
  ld bigint;
  lc bigint;
begin
  if s is null then raise exception 'E_NO_SHOP'; end if;
  if jsonb_typeof(p_lines) <> 'array' or jsonb_array_length(p_lines) < 2 then raise exception 'E_UNBALANCED'; end if;
  insert into public.journal_entries(id, shop_id, source_type, source_id, device_id, memo, idem_key, reverses_id, created_by)
  values (e, s, p_source_type, p_source_id, p_device, nullif(trim(p_memo), ''), p_idem, p_reverses, auth.uid());
  for l in select * from jsonb_array_elements(p_lines) loop
    select * into a from public.accounts where id = (l ->> 'account')::uuid and shop_id = s and deleted_at is null;
    if not found then raise exception 'E_BAD_ACCOUNT'; end if;
    ld := coalesce((l ->> 'debit')::bigint, 0);
    lc := coalesce((l ->> 'credit')::bigint, 0);
    if ld < 0 or lc < 0 or (ld > 0) = (lc > 0) then raise exception 'E_BAD_AMOUNT'; end if;
    -- العملاء والموردين والموظفين لازم يبقى معاهم الطرف
    if a.kind in ('receivable', 'payable', 'advances', 'salaries') and (l ->> 'party_id') is null then raise exception 'E_BAD_INPUT'; end if;
    insert into public.journal_lines(shop_id, entry_id, account_id, party_type, party_id, debit, credit)
    values (s, e, a.id, l ->> 'party_type', (l ->> 'party_id')::uuid, ld, lc);
    d := d + ld;
    c := c + lc;
  end loop;
  if d <> c or d = 0 then raise exception 'E_UNBALANCED'; end if;
  return e;
end $$;
revoke execute on function public.ledger_post(text, uuid, text, jsonb, uuid, uuid, uuid) from public, anon, authenticated;

-- أدوات صغيرة للدوال
create or replace function public.ledger_require(p_roles public.app_role[]) returns void
language plpgsql stable security definer set search_path = public as $$
begin
  if public.current_app_role() is null or not (public.current_app_role() = any(p_roles)) then
    raise exception 'E_FORBIDDEN';
  end if;
end $$;

create or replace function public.ledger_acc(p_code text) returns uuid
language sql stable security definer set search_path = public as $$
  select id from public.accounts where shop_id = public.current_shop_id() and code = p_code and deleted_at is null
$$;

create or replace function public.ledger_amount(p bigint) returns bigint
language plpgsql immutable as $$
begin
  if p is null or p <= 0 or p > 100000000000 then raise exception 'E_BAD_AMOUNT'; end if;
  return p;
end $$;

-- خزنة شغالة في المحل
create or replace function public.ledger_cashbox(p uuid) returns public.accounts
language plpgsql stable security definer set search_path = public as $$
declare a public.accounts;
begin
  select * into a from public.accounts where id = p and shop_id = public.current_shop_id() and kind = 'cash' and active and deleted_at is null;
  if not found then raise exception 'E_BAD_ACCOUNT'; end if;
  return a;
end $$;

create or replace function public.ledger_idem(p uuid) returns uuid
language sql stable security definer set search_path = public as $$
  select id from public.journal_entries where idem_key = p and shop_id = public.current_shop_id()
$$;

create or replace function public.ledger_line(p_acc uuid, p_debit bigint, p_credit bigint, p_party_type text default null, p_party uuid default null) returns jsonb
language sql immutable as $$
  select jsonb_strip_nulls(jsonb_build_object('account', p_acc, 'debit', p_debit, 'credit', p_credit, 'party_type', p_party_type, 'party_id', p_party))
$$;

-- رصيد حساب (اختياري: لطرف معيّن، ولحد وقت معيّن)
create or replace function public.ledger_balance(p_acc uuid, p_party uuid default null, p_before timestamptz default null) returns bigint
language sql stable security definer set search_path = public as $$
  select coalesce(sum((l.debit - l.credit) * public.account_sign(a.type)), 0)::bigint
  from public.journal_lines l
  join public.accounts a on a.id = l.account_id
  join public.journal_entries e on e.id = l.entry_id
  where l.account_id = p_acc and (p_party is null or l.party_id = p_party) and (p_before is null or e.occurred_at < p_before)
$$;

do $$
declare f text;
begin
  foreach f in array array['ledger_require(public.app_role[])', 'ledger_acc(text)', 'ledger_cashbox(uuid)', 'ledger_idem(uuid)', 'ledger_balance(uuid, uuid, timestamptz)'] loop
    execute format('revoke execute on function public.%s from public, anon, authenticated', f);
  end loop;
end $$;

-- ============================================================
-- 7) العمليات
-- ============================================================

-- دفعة من عميل (على جهاز أو من غير جهاز): تدخل الخزنة وتقلل دين العميل
create or replace function public.record_payment(p_id uuid, p_customer uuid, p_cashbox uuid, p_amount bigint, p_device uuid default null, p_method text default null, p_note text default null)
returns uuid
language plpgsql security definer set search_path = public as $$
declare
  cb public.accounts;
  e uuid;
  dev public.devices;
begin
  perform public.ledger_require(array['owner', 'reception']::public.app_role[]);
  e := public.ledger_idem(p_id);
  if e is not null then return e; end if;
  perform public.ledger_amount(p_amount);
  cb := public.ledger_cashbox(p_cashbox);
  if not exists (select 1 from public.customers where id = p_customer and shop_id = cb.shop_id and deleted_at is null) then raise exception 'E_NOT_FOUND'; end if;
  if p_device is not null then
    select * into dev from public.devices where id = p_device and shop_id = cb.shop_id and deleted_at is null;
    if not found or dev.customer_id <> p_customer then raise exception 'E_CROSS_SHOP'; end if;
  end if;
  e := public.ledger_post('payment', p_id, p_note, jsonb_build_array(
    public.ledger_line(cb.id, p_amount, 0),
    public.ledger_line(public.ledger_acc('ar'), 0, p_amount, 'customer', p_customer)
  ), p_device, p_id);
  insert into public.payments(id, shop_id, customer_id, device_id, cashbox_id, method, amount, entry_id, created_by)
  values (p_id, cb.shop_id, p_customer, p_device, cb.id, coalesce(p_method, cb.method), p_amount, e, auth.uid());
  return e;
end $$;

-- قيد عكسي: بيعكس كل سطور القيد الأصلي (وحركات المخزون لو فيه)، ومربوط بيه، وبيتسجل في السجل باسم مين وليه
create or replace function public.reverse_entry(p_entry uuid, p_reason text)
returns uuid
language plpgsql security definer set search_path = public as $$
declare
  o public.journal_entries;
  e uuid;
  lines jsonb;
  mv record;
begin
  perform public.ledger_require(array['owner']::public.app_role[]);
  if nullif(trim(p_reason), '') is null then raise exception 'E_BAD_INPUT'; end if;
  select * into o from public.journal_entries where id = p_entry and shop_id = public.current_shop_id() for update;
  if not found then raise exception 'E_NOT_FOUND'; end if;
  if o.source_type = 'reversal' or exists (select 1 from public.journal_entries where reverses_id = o.id) then
    raise exception 'E_ALREADY_REVERSED';
  end if;
  select jsonb_agg(public.ledger_line(account_id, credit, debit, party_type, party_id)) into lines
  from public.journal_lines where entry_id = o.id;
  e := public.ledger_post('reversal', o.source_id, p_reason, lines, o.device_id, null, o.id);
  for mv in select * from public.stock_moves where entry_id = o.id loop
    perform 1 from public.items where id = mv.item_id for update;
    if (select coalesce(sum(qty), 0) from public.stock_moves where item_id = mv.item_id) - mv.qty < 0 then
      raise exception 'E_STOCK';
    end if;
    insert into public.stock_moves(shop_id, item_id, entry_id, qty, value) values (mv.shop_id, mv.item_id, e, -mv.qty, -mv.value);
  end loop;
  insert into public.audit_log(shop_id, actor_id, action, entity, entity_id, before, after)
  values (o.shop_id, auth.uid(), 'reverse_entry', 'journal_entries', o.id, to_jsonb(o), jsonb_build_object('reversal_id', e, 'reason', p_reason));
  return e;
end $$;

-- تحويل بين خزنتين بقيد واحد
create or replace function public.transfer_cash(p_id uuid, p_from uuid, p_to uuid, p_amount bigint, p_note text default null)
returns uuid
language plpgsql security definer set search_path = public as $$
declare a public.accounts; b public.accounts; e uuid;
begin
  perform public.ledger_require(array['owner']::public.app_role[]);
  e := public.ledger_idem(p_id);
  if e is not null then return e; end if;
  perform public.ledger_amount(p_amount);
  a := public.ledger_cashbox(p_from);
  b := public.ledger_cashbox(p_to);
  if a.id = b.id then raise exception 'E_SAME_CASHBOX'; end if;
  if public.ledger_balance(a.id) < p_amount then raise exception 'E_INSUFFICIENT'; end if;
  return public.ledger_post('transfer', p_id, p_note, jsonb_build_array(public.ledger_line(b.id, p_amount, 0), public.ledger_line(a.id, 0, p_amount)), null, p_id);
end $$;

-- مصروف: يخرج من الخزنة المختارة
create or replace function public.record_expense(p_id uuid, p_account uuid, p_cashbox uuid, p_amount bigint, p_note text default null)
returns uuid
language plpgsql security definer set search_path = public as $$
declare cb public.accounts; e uuid;
begin
  perform public.ledger_require(array['owner']::public.app_role[]);
  e := public.ledger_idem(p_id);
  if e is not null then return e; end if;
  perform public.ledger_amount(p_amount);
  cb := public.ledger_cashbox(p_cashbox);
  if not exists (select 1 from public.accounts where id = p_account and shop_id = cb.shop_id and kind = 'expense' and active and deleted_at is null) then raise exception 'E_BAD_ACCOUNT'; end if;
  return public.ledger_post('expense', p_id, p_note, jsonb_build_array(public.ledger_line(p_account, p_amount, 0), public.ledger_line(cb.id, 0, p_amount)), null, p_id);
end $$;

-- رأس مال داخل، أو سحب صاحب المحل (السحب بيقلل رأس المال، مش مصروف)
create or replace function public.owner_capital(p_id uuid, p_cashbox uuid, p_amount bigint, p_note text default null)
returns uuid
language plpgsql security definer set search_path = public as $$
declare cb public.accounts; e uuid;
begin
  perform public.ledger_require(array['owner']::public.app_role[]);
  e := public.ledger_idem(p_id);
  if e is not null then return e; end if;
  perform public.ledger_amount(p_amount);
  cb := public.ledger_cashbox(p_cashbox);
  return public.ledger_post('capital', p_id, p_note, jsonb_build_array(public.ledger_line(cb.id, p_amount, 0), public.ledger_line(public.ledger_acc('capital'), 0, p_amount)), null, p_id);
end $$;

create or replace function public.owner_drawing(p_id uuid, p_cashbox uuid, p_amount bigint, p_note text default null)
returns uuid
language plpgsql security definer set search_path = public as $$
declare cb public.accounts; e uuid;
begin
  perform public.ledger_require(array['owner']::public.app_role[]);
  e := public.ledger_idem(p_id);
  if e is not null then return e; end if;
  perform public.ledger_amount(p_amount);
  cb := public.ledger_cashbox(p_cashbox);
  return public.ledger_post('drawing', p_id, p_note, jsonb_build_array(public.ledger_line(public.ledger_acc('drawings'), p_amount, 0), public.ledger_line(cb.id, 0, p_amount)), null, p_id);
end $$;

-- الموظفين: مرتب مستحق، صرف مرتب، سلفة، خصم سلفة من المرتب
create or replace function public.ledger_employee(p uuid) returns void
language plpgsql stable security definer set search_path = public as $$
begin
  if not exists (select 1 from public.profiles where id = p and shop_id = public.current_shop_id()) then raise exception 'E_NOT_FOUND'; end if;
end $$;
revoke execute on function public.ledger_employee(uuid) from public, anon, authenticated;

create or replace function public.accrue_salary(p_id uuid, p_employee uuid, p_amount bigint, p_note text default null)
returns uuid
language plpgsql security definer set search_path = public as $$
declare e uuid;
begin
  perform public.ledger_require(array['owner']::public.app_role[]);
  e := public.ledger_idem(p_id);
  if e is not null then return e; end if;
  perform public.ledger_amount(p_amount);
  perform public.ledger_employee(p_employee);
  return public.ledger_post('salary', p_id, p_note, jsonb_build_array(
    public.ledger_line(public.ledger_acc('exp_salaries'), p_amount, 0),
    public.ledger_line(public.ledger_acc('salaries_payable'), 0, p_amount, 'employee', p_employee)), null, p_id);
end $$;

create or replace function public.pay_salary(p_id uuid, p_employee uuid, p_cashbox uuid, p_amount bigint, p_note text default null)
returns uuid
language plpgsql security definer set search_path = public as $$
declare cb public.accounts; e uuid;
begin
  perform public.ledger_require(array['owner']::public.app_role[]);
  e := public.ledger_idem(p_id);
  if e is not null then return e; end if;
  perform public.ledger_amount(p_amount);
  perform public.ledger_employee(p_employee);
  cb := public.ledger_cashbox(p_cashbox);
  return public.ledger_post('salary_payment', p_id, p_note, jsonb_build_array(
    public.ledger_line(public.ledger_acc('salaries_payable'), p_amount, 0, 'employee', p_employee),
    public.ledger_line(cb.id, 0, p_amount)), null, p_id);
end $$;

create or replace function public.give_advance(p_id uuid, p_employee uuid, p_cashbox uuid, p_amount bigint, p_note text default null)
returns uuid
language plpgsql security definer set search_path = public as $$
declare cb public.accounts; e uuid;
begin
  perform public.ledger_require(array['owner']::public.app_role[]);
  e := public.ledger_idem(p_id);
  if e is not null then return e; end if;
  perform public.ledger_amount(p_amount);
  perform public.ledger_employee(p_employee);
  cb := public.ledger_cashbox(p_cashbox);
  return public.ledger_post('advance', p_id, p_note, jsonb_build_array(
    public.ledger_line(public.ledger_acc('advances'), p_amount, 0, 'employee', p_employee),
    public.ledger_line(cb.id, 0, p_amount)), null, p_id);
end $$;

create or replace function public.settle_advance(p_id uuid, p_employee uuid, p_amount bigint, p_note text default null)
returns uuid
language plpgsql security definer set search_path = public as $$
declare e uuid;
begin
  perform public.ledger_require(array['owner']::public.app_role[]);
  e := public.ledger_idem(p_id);
  if e is not null then return e; end if;
  perform public.ledger_amount(p_amount);
  perform public.ledger_employee(p_employee);
  return public.ledger_post('advance_settle', p_id, p_note, jsonb_build_array(
    public.ledger_line(public.ledger_acc('salaries_payable'), p_amount, 0, 'employee', p_employee),
    public.ledger_line(public.ledger_acc('advances'), 0, p_amount, 'employee', p_employee)), null, p_id);
end $$;

-- ---------- المخزون ----------
-- الكمية والقيمة الحالية لصنف (من حركاته)
create or replace function public.item_stock(p_item uuid, out qty bigint, out value bigint)
language sql stable security definer set search_path = public as $$
  select coalesce(sum(m.qty), 0)::bigint, coalesce(sum(m.value), 0)::bigint from public.stock_moves m where m.item_id = p_item
$$;
revoke execute on function public.item_stock(uuid) from public, anon, authenticated;

-- تكلفة خروج n من صنف بالمتوسط المرجّح. لو خرج كل الموجود بتطلع القيمة كلها بالظبط (من غير ما يفضل كسور)
create or replace function public.ledger_issue_cost(p_qty bigint, p_value bigint, n bigint) returns bigint
language sql immutable as $$
  select case when n = p_qty then p_value else (p_value * n + p_qty / 2) / p_qty end
$$;

-- شراء قطع أو إكسسوارات من مورد: نقدي (من خزنة) أو آجل (على المورد)
-- p_lines: [{"item": uuid, "qty": n, "unit_cost": n}]
create or replace function public.record_purchase(p_id uuid, p_supplier uuid, p_lines jsonb, p_cashbox uuid default null, p_note text default null)
returns uuid
language plpgsql security definer set search_path = public as $$
declare
  s uuid := public.current_shop_id();
  l jsonb;
  total bigint := 0;
  q bigint;
  u bigint;
  e uuid;
  credit_line jsonb;
begin
  perform public.ledger_require(array['owner']::public.app_role[]);
  e := public.ledger_idem(p_id);
  if e is not null then return e; end if;
  if not exists (select 1 from public.suppliers where id = p_supplier and shop_id = s and deleted_at is null) then raise exception 'E_NOT_FOUND'; end if;
  if jsonb_typeof(p_lines) <> 'array' or jsonb_array_length(p_lines) = 0 then raise exception 'E_BAD_INPUT'; end if;
  for l in select * from jsonb_array_elements(p_lines) loop
    q := (l ->> 'qty')::bigint;
    u := (l ->> 'unit_cost')::bigint;
    if q is null or q <= 0 or q > 100000 or u is null or u < 0 then raise exception 'E_BAD_AMOUNT'; end if;
    if not exists (select 1 from public.items where id = (l ->> 'item')::uuid and shop_id = s and deleted_at is null) then raise exception 'E_NOT_FOUND'; end if;
    total := total + q * u;
  end loop;
  perform public.ledger_amount(total);
  credit_line := case when p_cashbox is null
    then public.ledger_line(public.ledger_acc('ap'), 0, total, 'supplier', p_supplier)
    else public.ledger_line((public.ledger_cashbox(p_cashbox)).id, 0, total) end;
  e := public.ledger_post('purchase', p_id, p_note, jsonb_build_array(public.ledger_line(public.ledger_acc('inventory'), total, 0), credit_line), null, p_id);
  for l in select * from jsonb_array_elements(p_lines) loop
    insert into public.stock_moves(shop_id, item_id, entry_id, qty, value)
    values (s, (l ->> 'item')::uuid, e, (l ->> 'qty')::int, (l ->> 'qty')::bigint * (l ->> 'unit_cost')::bigint);
  end loop;
  return e;
end $$;

create or replace function public.pay_supplier(p_id uuid, p_supplier uuid, p_cashbox uuid, p_amount bigint, p_note text default null)
returns uuid
language plpgsql security definer set search_path = public as $$
declare cb public.accounts; e uuid;
begin
  perform public.ledger_require(array['owner']::public.app_role[]);
  e := public.ledger_idem(p_id);
  if e is not null then return e; end if;
  perform public.ledger_amount(p_amount);
  cb := public.ledger_cashbox(p_cashbox);
  if not exists (select 1 from public.suppliers where id = p_supplier and shop_id = cb.shop_id and deleted_at is null) then raise exception 'E_NOT_FOUND'; end if;
  return public.ledger_post('supplier_payment', p_id, p_note, jsonb_build_array(
    public.ledger_line(public.ledger_acc('ap'), p_amount, 0, 'supplier', p_supplier),
    public.ledger_line(cb.id, 0, p_amount)), null, p_id);
end $$;

-- خروج صنف من المخزون (داخلية): بيرجّع التكلفة
create or replace function public.ledger_issue(p_item uuid, p_qty bigint, p_entry uuid) returns bigint
language plpgsql security definer set search_path = public as $$
declare st record; cost bigint;
begin
  perform 1 from public.items where id = p_item and shop_id = public.current_shop_id() and deleted_at is null for update;
  if not found then raise exception 'E_NOT_FOUND'; end if;
  select * into st from public.item_stock(p_item);
  if p_qty <= 0 or st.qty < p_qty then raise exception 'E_STOCK'; end if;
  cost := public.ledger_issue_cost(st.qty, st.value, p_qty);
  insert into public.stock_moves(shop_id, item_id, entry_id, qty, value) values (public.current_shop_id(), p_item, p_entry, -p_qty, -cost);
  return cost;
end $$;
revoke execute on function public.ledger_issue(uuid, bigint, uuid) from public, anon, authenticated;

-- قطعة اتركبت في جهاز: تخرج من المخزون كتكلفة على الجهاز (الفني يقدر يسجلها من غير ما يشوف السعر)
create or replace function public.use_part(p_id uuid, p_device uuid, p_item uuid, p_qty integer default 1)
returns uuid
language plpgsql security definer set search_path = public as $$
declare
  e uuid;
  cost bigint;
  inv uuid := public.ledger_acc('inventory');
  cg uuid := public.ledger_acc('cogs');
begin
  perform public.ledger_require(array['owner', 'technician']::public.app_role[]);
  e := public.ledger_idem(p_id);
  if e is not null then return e; end if;
  if not exists (select 1 from public.devices where id = p_device and shop_id = public.current_shop_id() and deleted_at is null and status <> 'delivered') then raise exception 'E_NOT_FOUND'; end if;
  -- القيد محتاج يتعمل الأول عشان حركة المخزون تتربط بيه، والتوازن بيتراجع في آخر العملية
  e := gen_random_uuid();
  insert into public.journal_entries(id, shop_id, source_type, source_id, device_id, idem_key, created_by)
  values (e, public.current_shop_id(), 'part_use', p_item, p_device, p_id, auth.uid());
  cost := public.ledger_issue(p_item, p_qty, e);
  if cost > 0 then
    insert into public.journal_lines(shop_id, entry_id, account_id, debit, credit) values
      (public.current_shop_id(), e, cg, cost, 0),
      (public.current_shop_id(), e, inv, 0, cost);
  else
    raise exception 'E_BAD_AMOUNT';  -- صنف من غير تكلفة: لازم يتشتري بسعر الأول
  end if;
  return e;
end $$;

-- بيع قطع أو إكسسوارات على الكاونتر
-- p_lines: [{"item": uuid, "qty": n, "price": n}]
create or replace function public.record_sale(p_id uuid, p_lines jsonb, p_cashbox uuid default null, p_customer uuid default null, p_note text default null)
returns uuid
language plpgsql security definer set search_path = public as $$
declare
  s uuid := public.current_shop_id();
  e uuid := gen_random_uuid();
  l jsonb;
  it public.items;
  q bigint; p bigint; cost bigint;
  rev_parts bigint := 0; rev_acc bigint := 0; total_cost bigint := 0;
  debit_acc uuid; pt text; pid uuid;
begin
  perform public.ledger_require(array['owner', 'reception']::public.app_role[]);
  if public.ledger_idem(p_id) is not null then return public.ledger_idem(p_id); end if;
  -- البيع بالآجل لصاحب المحل بس
  if p_cashbox is null and (p_customer is null or public.current_app_role() <> 'owner') then raise exception 'E_BAD_INPUT'; end if;
  if p_customer is not null and not exists (select 1 from public.customers where id = p_customer and shop_id = s and deleted_at is null) then raise exception 'E_NOT_FOUND'; end if;
  if jsonb_typeof(p_lines) <> 'array' or jsonb_array_length(p_lines) = 0 then raise exception 'E_BAD_INPUT'; end if;
  insert into public.journal_entries(id, shop_id, source_type, source_id, memo, idem_key, created_by)
  values (e, s, 'sale', p_id, nullif(trim(p_note), ''), p_id, auth.uid());
  for l in select * from jsonb_array_elements(p_lines) loop
    select * into it from public.items where id = (l ->> 'item')::uuid and shop_id = s and deleted_at is null;
    if not found then raise exception 'E_NOT_FOUND'; end if;
    q := (l ->> 'qty')::bigint;
    p := (l ->> 'price')::bigint;
    if q is null or q <= 0 or p is null or p < 0 then raise exception 'E_BAD_AMOUNT'; end if;
    cost := public.ledger_issue(it.id, q, e);
    total_cost := total_cost + cost;
    if it.kind = 'part' then rev_parts := rev_parts + q * p; else rev_acc := rev_acc + q * p; end if;
  end loop;
  perform public.ledger_amount(rev_parts + rev_acc);
  if p_cashbox is null then
    debit_acc := public.ledger_acc('ar'); pt := 'customer'; pid := p_customer;
  else
    debit_acc := (public.ledger_cashbox(p_cashbox)).id;
  end if;
  insert into public.journal_lines(shop_id, entry_id, account_id, party_type, party_id, debit, credit)
  values (s, e, debit_acc, pt, pid, rev_parts + rev_acc, 0);
  if rev_parts > 0 then insert into public.journal_lines(shop_id, entry_id, account_id, debit, credit) values (s, e, public.ledger_acc('rev_parts'), 0, rev_parts); end if;
  if rev_acc > 0 then insert into public.journal_lines(shop_id, entry_id, account_id, debit, credit) values (s, e, public.ledger_acc('rev_accessories'), 0, rev_acc); end if;
  if total_cost > 0 then
    insert into public.journal_lines(shop_id, entry_id, account_id, debit, credit) values
      (s, e, public.ledger_acc('cogs'), total_cost, 0), (s, e, public.ledger_acc('inventory'), 0, total_cost);
  end if;
  if p_cashbox is not null and p_customer is not null then
    null; -- البيع النقدي لعميل معروف ما بيأثرش على رصيده
  end if;
  return e;
end $$;

-- ---------- الدرج ----------
-- الخزن اللي أقدر أقفلها، بالمتوقع فيها (الاستقبال: الخزن اللي هو مسؤول عنها بس)
create or replace function public.my_drawers()
returns table(id uuid, code text, name text, method text, expected bigint)
language plpgsql stable security definer set search_path = public as $$
begin
  perform public.ledger_require(array['owner', 'reception']::public.app_role[]);
  return query
  select a.id, a.code, a.name, a.method, public.ledger_balance(a.id)
  from public.accounts a
  where a.shop_id = public.current_shop_id() and a.kind = 'cash' and a.active and a.deleted_at is null
    and (public.current_app_role() = 'owner' or a.holder_id = auth.uid())
  order by a.created_at;
end $$;

-- تقفيل الدرج: المتوقع من النظام والفعلي، والفرق بيتسجل قيد عجز أو زيادة باسم الموظف
create or replace function public.close_drawer(p_id uuid, p_cashbox uuid, p_counted bigint, p_note text default null)
returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  cb public.accounts;
  exp bigint;
  d bigint;
  e uuid;
  r public.drawer_closings;
begin
  perform public.ledger_require(array['owner', 'reception']::public.app_role[]);
  select * into r from public.drawer_closings where id = p_id and shop_id = public.current_shop_id();
  if found then return jsonb_build_object('expected', r.expected, 'counted', r.counted, 'diff', r.diff); end if;
  cb := public.ledger_cashbox(p_cashbox);
  if public.current_app_role() <> 'owner' and cb.holder_id is distinct from auth.uid() then raise exception 'E_FORBIDDEN'; end if;
  if p_counted is null or p_counted < 0 or p_counted > 100000000000 then raise exception 'E_BAD_AMOUNT'; end if;
  perform 1 from public.accounts where id = cb.id for update;  -- ما يحصلش تقفيلين في نفس اللحظة
  exp := public.ledger_balance(cb.id);
  d := p_counted - exp;
  if d < 0 then
    e := public.ledger_post('drawer_close', p_id, p_note, jsonb_build_array(public.ledger_line(public.ledger_acc('shortage'), -d, 0), public.ledger_line(cb.id, 0, -d)), null, p_id);
  elsif d > 0 then
    e := public.ledger_post('drawer_close', p_id, p_note, jsonb_build_array(public.ledger_line(cb.id, d, 0), public.ledger_line(public.ledger_acc('overage'), 0, d)), null, p_id);
  end if;
  insert into public.drawer_closings(id, shop_id, cashbox_id, expected, counted, diff, entry_id, note, closed_by)
  values (p_id, cb.shop_id, cb.id, exp, p_counted, d, e, nullif(trim(p_note), ''), auth.uid());
  return jsonb_build_object('expected', exp, 'counted', p_counted, 'diff', d);
end $$;

-- ---------- الحسابات المضافة ----------
create or replace function public.add_account(p_id uuid, p_kind text, p_name text, p_method text default null, p_holder uuid default null)
returns uuid
language plpgsql security definer set search_path = public as $$
begin
  perform public.ledger_require(array['owner']::public.app_role[]);
  if p_kind not in ('cash', 'expense') or nullif(trim(p_name), '') is null or length(p_name) > 80 then raise exception 'E_BAD_INPUT'; end if;
  if p_kind = 'cash' and (p_method is null or not public.valid_payment_methods(array[p_method])) then raise exception 'E_BAD_INPUT'; end if;
  if p_holder is not null and not exists (select 1 from public.profiles where id = p_holder and shop_id = public.current_shop_id() and deleted_at is null) then raise exception 'E_NOT_FOUND'; end if;
  insert into public.accounts(id, shop_id, name, type, kind, method, holder_id)
  values (p_id, public.current_shop_id(), trim(p_name), case when p_kind = 'cash' then 'asset' else 'expense' end::public.account_type, p_kind,
          case when p_kind = 'cash' then p_method end, case when p_kind = 'cash' then p_holder end);
  return p_id;
end $$;

-- تعديل خزنة أو بند مصروف: الاسم، والمسؤول، والتفعيل. النوع والطريقة ما بيتغيروش
create or replace function public.update_account(p_id uuid, p_name text default null, p_holder uuid default null, p_active boolean default null, p_clear_holder boolean default false)
returns void
language plpgsql security definer set search_path = public as $$
declare a public.accounts;
begin
  perform public.ledger_require(array['owner']::public.app_role[]);
  select * into a from public.accounts where id = p_id and shop_id = public.current_shop_id() and deleted_at is null;
  if not found or a.kind not in ('cash', 'expense') then raise exception 'E_BAD_ACCOUNT'; end if;
  if p_holder is not null and not exists (select 1 from public.profiles where id = p_holder and shop_id = a.shop_id and deleted_at is null) then raise exception 'E_NOT_FOUND'; end if;
  if p_active = false and a.kind = 'cash' and public.ledger_balance(a.id) <> 0 then raise exception 'E_CASHBOX_NOT_EMPTY'; end if;
  update public.accounts set
    name = coalesce(nullif(trim(p_name), ''), name),
    holder_id = case when p_clear_holder then null when a.kind = 'cash' then coalesce(p_holder, holder_id) else null end,
    active = coalesce(p_active, active)
  where id = a.id;
end $$;

-- ============================================================
-- 8) ربط الأجهزة: منع التسليم قبل السداد، وتسجيل الإيراد عند التسليم
-- ============================================================
create or replace function public.device_paid(p_device uuid) returns bigint
language sql stable security definer set search_path = public as $$
  select coalesce(sum(p.amount), 0)::bigint from public.payments p
  where p.device_id = p_device and not exists (select 1 from public.journal_entries r where r.reverses_id = p.entry_id)
$$;
revoke execute on function public.device_paid(uuid) from public, anon, authenticated;

create or replace function public.tg_device_paid_guard() returns trigger
language plpgsql security definer set search_path = public as $$
declare fc integer;
begin
  if new.status = 'delivered' and old.status is distinct from 'delivered' then
    select final_cost into fc from public.device_costs where device_id = new.id and deleted_at is null;
    if coalesce(fc, 0) > public.device_paid(new.id) and coalesce(current_setting('warsha.credit_ok', true), '') <> new.id::text then
      raise exception 'E_UNPAID';
    end if;
  end if;
  return new;
end $$;
create trigger zy_device_paid before update on public.devices for each row execute function public.tg_device_paid_guard();

-- عند التسليم: الإيراد بيتسجل، ودين العميل بالتكلفة (والدفعات اللي قبل كده بتصفّيه). مرة واحدة بس لكل جهاز
create or replace function public.tg_device_revenue() returns trigger
language plpgsql security definer set search_path = public as $$
declare fc integer;
begin
  if new.status = 'delivered' and old.status is distinct from 'delivered'
     and not exists (select 1 from public.journal_entries e where e.source_type = 'delivery' and e.source_id = new.id
                     and not exists (select 1 from public.journal_entries r where r.reverses_id = e.id)) then
    select final_cost into fc from public.device_costs where device_id = new.id and deleted_at is null;
    if coalesce(fc, 0) > 0 then
      perform public.ledger_post('delivery', new.id, new.order_no, jsonb_build_array(
        public.ledger_line(public.ledger_acc('ar'), fc, 0, 'customer', new.customer_id),
        public.ledger_line(public.ledger_acc('rev_repair'), 0, fc)), new.id);
    end if;
  end if;
  return null;
end $$;
create trigger zz_device_revenue after update on public.devices for each row execute function public.tg_device_revenue();

-- بعد ما الإيراد يتسجل، التكلفة النهائية ما بتتغيرش (التصحيح بقيد عكسي)
create or replace function public.tg_cost_locked() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if new.final_cost is distinct from old.final_cost and exists (
    select 1 from public.journal_entries e where e.source_type = 'delivery' and e.source_id = new.device_id
      and not exists (select 1 from public.journal_entries r where r.reverses_id = e.id)) then
    raise exception 'E_COST_LOCKED';
  end if;
  return new;
end $$;
create trigger zy_cost_locked before update on public.device_costs for each row execute function public.tg_cost_locked();

-- التسليم بالآجل (صاحب المحل بس): الباقي بيفضل دين على العميل
create or replace function public.deliver_on_credit(p_device uuid) returns void
language plpgsql security definer set search_path = public as $$
begin
  perform public.ledger_require(array['owner']::public.app_role[]);
  perform set_config('warsha.credit_ok', p_device::text, true);
  update public.devices set status = 'delivered' where id = p_device and shop_id = public.current_shop_id();
  if not found then raise exception 'E_NOT_FOUND'; end if;
  perform set_config('warsha.credit_ok', '', true);
end $$;

-- فلوس الجهاز: التكلفة، والمدفوع، والباقي، والدفعات (لصاحب المحل والاستقبال)
create or replace function public.device_money(p_device uuid) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare fc integer; paid bigint;
begin
  perform public.ledger_require(array['owner', 'reception']::public.app_role[]);
  if not exists (select 1 from public.devices where id = p_device and shop_id = public.current_shop_id()) then raise exception 'E_NOT_FOUND'; end if;
  select final_cost into fc from public.device_costs where device_id = p_device and deleted_at is null;
  paid := public.device_paid(p_device);
  return jsonb_build_object(
    'final', fc, 'paid', paid, 'due', greatest(coalesce(fc, 0) - paid, 0),
    'payments', coalesce((select jsonb_agg(jsonb_build_object(
        'id', p.id, 'amount', p.amount, 'method', p.method, 'created_at', p.created_at, 'entry_id', p.entry_id,
        'by', (select full_name from public.profiles where id = p.created_by),
        'reversed', exists (select 1 from public.journal_entries r where r.reverses_id = p.entry_id)) order by p.created_at)
      from public.payments p where p.device_id = p_device), '[]'::jsonb),
    'parts_cost', case when public.current_app_role() = 'owner' then (
      select coalesce(sum(l.debit), 0) from public.journal_lines l join public.journal_entries e on e.id = l.entry_id
      where e.device_id = p_device and e.source_type in ('part_use', 'reversal') and l.account_id = public.ledger_acc('cogs')) - (
      select coalesce(sum(l.credit), 0) from public.journal_lines l join public.journal_entries e on e.id = l.entry_id
      where e.device_id = p_device and e.source_type = 'reversal' and l.account_id = public.ledger_acc('cogs')) end
  );
end $$;

-- ============================================================
-- 9) التقارير (صاحب المحل بس)
-- ============================================================
-- الوضع المالي للفترة [p_from, p_to)
create or replace function public.financial_position(p_from timestamptz, p_to timestamptz) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare
  s uuid := public.current_shop_id();
  res jsonb;
begin
  perform public.ledger_require(array['owner']::public.app_role[]);
  with bal as (
    select a.id, a.code, a.name, a.type, a.kind, a.method, l.party_type, l.party_id,
           coalesce(sum((l.debit - l.credit) * public.account_sign(a.type)), 0)::bigint as b
    from public.accounts a
    left join public.journal_lines l on l.account_id = a.id
    where a.shop_id = s
    group by a.id, l.party_type, l.party_id
  ),
  acc as (select id, code, name, type, kind, method, sum(b)::bigint as b from bal group by id, code, name, type, kind, method),
  per as (
    select coalesce(sum(case when a.type = 'revenue' then l.credit - l.debit else 0 end), 0)::bigint as revenue,
           coalesce(sum(case when a.type = 'expense' then l.debit - l.credit else 0 end), 0)::bigint as expenses
    from public.journal_lines l join public.accounts a on a.id = l.account_id join public.journal_entries e on e.id = l.entry_id
    where l.shop_id = s and e.occurred_at >= p_from and e.occurred_at < p_to
  ),
  tot as (
    select coalesce(sum(debit), 0)::bigint as d, coalesce(sum(credit), 0)::bigint as c from public.journal_lines where shop_id = s
  ),
  unb as (
    select count(*)::int as n from (
      select e.id from public.journal_entries e left join public.journal_lines l on l.entry_id = e.id
      where e.shop_id = s group by e.id having coalesce(sum(l.debit), 0) <> coalesce(sum(l.credit), 0) or count(l.id) < 2) x
  ),
  eq as (
    select coalesce(sum(b) filter (where type = 'asset'), 0)::bigint as assets,
           coalesce(sum(b) filter (where type = 'liability'), 0)::bigint as liabilities,
           coalesce(sum(b) filter (where type = 'equity'), 0)::bigint as equity,
           (coalesce(sum(b) filter (where type = 'revenue'), 0) - coalesce(sum(b) filter (where type = 'expense'), 0))::bigint as earnings
    from acc
  ),
  parts as (
    select
      coalesce(sum(b) filter (where kind = 'cash'), 0)::bigint as cash,
      coalesce(sum(greatest(b, 0)) filter (where kind in ('receivable', 'advances')), 0)::bigint as receivables,
      (coalesce(sum(greatest(b, 0)) filter (where kind in ('payable', 'salaries')), 0)
        + coalesce(sum(greatest(-b, 0)) filter (where kind in ('receivable', 'advances')), 0)
        + coalesce(sum(greatest(-b, 0)) filter (where kind = 'inventory'), 0))::bigint as payables,
      coalesce(sum(greatest(-b, 0)) filter (where kind in ('payable', 'salaries')), 0)::bigint as payables_debit,
      coalesce(sum(greatest(b, 0)) filter (where kind = 'inventory'), 0)::bigint as inventory
    from bal
  ),
  days as (
    select (date_trunc('day', e.occurred_at at time zone 'Africa/Cairo'))::date as day,
           coalesce(sum(case when a.type = 'revenue' then l.credit - l.debit else 0 end), 0)::bigint as revenue,
           coalesce(sum(case when a.type = 'expense' then l.debit - l.credit else 0 end), 0)::bigint as expenses
    from public.journal_lines l join public.accounts a on a.id = l.account_id join public.journal_entries e on e.id = l.entry_id
    where l.shop_id = s and e.occurred_at >= p_from and e.occurred_at < p_to and a.type in ('revenue', 'expense')
    group by 1
  )
  select jsonb_build_object(
    'cash', p.cash,
    'receivables', p.receivables + p.payables_debit,
    'payables', p.payables,
    'inventory', p.inventory,
    'revenue', per.revenue,
    'expenses', per.expenses,
    'profit', per.revenue - per.expenses,
    'net_worth', p.cash + p.receivables + p.payables_debit + p.inventory - p.payables,
    'equation', jsonb_build_object('assets', eq.assets, 'liabilities', eq.liabilities, 'equity', eq.equity, 'earnings', eq.earnings),
    'debits', tot.d, 'credits', tot.c, 'unbalanced_entries', unb.n,
    'balanced', tot.d = tot.c and unb.n = 0 and eq.assets = eq.liabilities + eq.equity + eq.earnings,
    'cashboxes', coalesce((select jsonb_agg(jsonb_build_object('id', a.id, 'code', a.code, 'name', a.name, 'method', a.method, 'balance', a.b) order by a.code nulls last, a.name)
       from acc a where a.kind = 'cash'), '[]'::jsonb),
    'top_customers', coalesce((select jsonb_agg(x order by (x ->> 'balance')::bigint desc) from (
       select jsonb_build_object('id', b.party_id, 'name', c.name, 'balance', sum(b.b)) as x
       from bal b join public.customers c on c.id = b.party_id where b.kind = 'receivable' and b.party_type = 'customer'
       group by b.party_id, c.name having sum(b.b) > 0 order by sum(b.b) desc limit 5) t), '[]'::jsonb),
    'top_suppliers', coalesce((select jsonb_agg(x order by (x ->> 'balance')::bigint desc) from (
       select jsonb_build_object('id', b.party_id, 'name', sp.name, 'balance', sum(b.b)) as x
       from bal b join public.suppliers sp on sp.id = b.party_id where b.kind = 'payable' and b.party_type = 'supplier'
       group by b.party_id, sp.name having sum(b.b) > 0 order by sum(b.b) desc limit 5) t), '[]'::jsonb),
    'daily', coalesce((select jsonb_agg(jsonb_build_object('day', day, 'revenue', revenue, 'expenses', expenses, 'profit', revenue - expenses) order by day) from days), '[]'::jsonb),
    'by_method', coalesce((select jsonb_object_agg(method, total) from (
       select p2.method, sum(p2.amount)::bigint as total from public.payments p2
       where p2.shop_id = s and p2.created_at >= p_from and p2.created_at < p_to
         and not exists (select 1 from public.journal_entries r where r.reverses_id = p2.entry_id)
       group by p2.method) m), '{}'::jsonb),
    'delivered', (select count(*) from public.devices d where d.shop_id = s and d.delivered_at >= p_from and d.delivered_at < p_to),
    'closings', coalesce((select jsonb_agg(jsonb_build_object('cashbox', dc.cashbox_id, 'expected', dc.expected, 'counted', dc.counted, 'diff', dc.diff, 'at', dc.created_at,
       'by', (select full_name from public.profiles where id = dc.closed_by)) order by dc.created_at)
       from public.drawer_closings dc where dc.shop_id = s and dc.created_at >= p_from and dc.created_at < p_to), '[]'::jsonb)
  ) into res
  from parts p, per, tot, unb, eq;
  return res;
end $$;

-- حركات خزنة أو كشف حساب (عميل/مورد/موظف) بالرصيد بعد كل حركة
-- p_kind: 'cashbox' (p_id = الخزنة) أو 'customer' / 'supplier' / 'employee' (p_id = الطرف)
create or replace function public.statement(p_kind text, p_id uuid, p_from timestamptz, p_to timestamptz) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare
  s uuid := public.current_shop_id();
  accs uuid[];
  opening bigint;
  res jsonb;
begin
  perform public.ledger_require(array['owner']::public.app_role[]);
  if p_kind = 'cashbox' then
    select array_agg(id) into accs from public.accounts where id = p_id and shop_id = s and kind = 'cash';
  elsif p_kind = 'customer' then
    select array_agg(id) into accs from public.accounts where shop_id = s and kind = 'receivable';
  elsif p_kind = 'supplier' then
    select array_agg(id) into accs from public.accounts where shop_id = s and kind = 'payable';
  elsif p_kind = 'employee' then
    select array_agg(id) into accs from public.accounts where shop_id = s and kind in ('advances', 'salaries');
  else
    raise exception 'E_BAD_INPUT';
  end if;
  if accs is null then raise exception 'E_NOT_FOUND'; end if;
  -- الرصيد: للخزنة والعميل والسلف = مدين − دائن. للمورد والمرتبات = دائن − مدين (الطرف الطبيعي)
  select coalesce(sum((l.debit - l.credit) * public.account_sign(a.type)), 0) into opening
  from public.journal_lines l join public.accounts a on a.id = l.account_id join public.journal_entries e on e.id = l.entry_id
  where l.account_id = any(accs) and (p_kind = 'cashbox' or l.party_id = p_id) and e.occurred_at < p_from;
  with mv as (
    select e.id as entry_id, e.entry_no, e.occurred_at, e.source_type, e.source_id, e.device_id, e.memo, e.reverses_id,
           d.order_no, p.full_name as by_name, a.code as account_code,
           ((l.debit - l.credit) * public.account_sign(a.type))::bigint as amount
    from public.journal_lines l
    join public.accounts a on a.id = l.account_id
    join public.journal_entries e on e.id = l.entry_id
    left join public.devices d on d.id = e.device_id
    left join public.profiles p on p.id = e.created_by
    where l.account_id = any(accs) and (p_kind = 'cashbox' or l.party_id = p_id) and e.occurred_at >= p_from and e.occurred_at < p_to
  ),
  mv2 as (select mv.*, opening + sum(amount) over (order by occurred_at, entry_no rows unbounded preceding) as running from mv)
  select jsonb_build_object('opening', opening, 'moves', coalesce(jsonb_agg(jsonb_build_object(
      'entry_id', entry_id, 'entry_no', entry_no, 'at', occurred_at, 'source_type', source_type, 'source_id', source_id,
      'device_id', device_id, 'order_no', order_no, 'memo', memo, 'by', by_name, 'account', account_code, 'amount', amount,
      'reversed', exists (select 1 from public.journal_entries r where r.reverses_id = entry_id), 'reverses', reverses_id,
      'balance', running) order by occurred_at, entry_no), '[]'::jsonb))
  into res from mv2;
  return res;
end $$;

-- الأصناف بالكمية (والتكلفة والقيمة لصاحب المحل بس)
create or replace function public.items_stock() returns table(id uuid, kind text, name text, sku text, sale_price integer, qty bigint, avg_cost bigint, value bigint)
language plpgsql stable security definer set search_path = public as $$
declare r public.app_role := public.current_app_role();
begin
  if r is null then raise exception 'E_FORBIDDEN'; end if;
  return query
  select i.id, i.kind, i.name, i.sku,
         case when r = 'technician' then null else i.sale_price end,
         coalesce(st.q, 0)::bigint,
         case when r = 'owner' and coalesce(st.q, 0) > 0 then (st.v / st.q)::bigint end,
         case when r = 'owner' then coalesce(st.v, 0)::bigint end
  from public.items i
  left join (select m.item_id, sum(m.qty) as q, sum(m.value) as v from public.stock_moves m group by m.item_id) st on st.item_id = i.id
  where i.shop_id = public.current_shop_id() and i.deleted_at is null
  order by i.kind, i.name;
end $$;

-- ============================================================
-- 10) الصلاحيات
-- ============================================================
alter table public.accounts enable row level security;
alter table public.journal_entries enable row level security;
alter table public.journal_lines enable row level security;
alter table public.suppliers enable row level security;
alter table public.items enable row level security;
alter table public.stock_moves enable row level security;
alter table public.payments enable row level security;
alter table public.drawer_closings enable row level security;

revoke all on public.accounts, public.journal_entries, public.journal_lines, public.suppliers, public.items,
  public.stock_moves, public.payments, public.drawer_closings from public, anon, authenticated;

-- الحسابات: صاحب المحل كلها، والاستقبال الخزن بس (أسماءها، من غير أرصدة)
create policy accounts_select on public.accounts for select to authenticated using (
  shop_id = public.current_shop_id() and (public.current_app_role() = 'owner' or (public.current_app_role() = 'reception' and kind = 'cash')));
grant select on public.accounts to authenticated;

-- القيود والسطور والمخزون: صاحب المحل بس. ومحدش بيكتب فيهم مباشرة (الدوال بس)
create policy entries_select on public.journal_entries for select to authenticated using (shop_id = public.current_shop_id() and public.current_app_role() = 'owner');
create policy lines_select on public.journal_lines for select to authenticated using (shop_id = public.current_shop_id() and public.current_app_role() = 'owner');
create policy moves_select on public.stock_moves for select to authenticated using (shop_id = public.current_shop_id() and public.current_app_role() = 'owner');
grant select on public.journal_entries, public.journal_lines, public.stock_moves to authenticated;

-- الدفعات: صاحب المحل والاستقبال يشوفوها
create policy payments_select on public.payments for select to authenticated using (shop_id = public.current_shop_id() and public.current_app_role() in ('owner', 'reception'));
grant select on public.payments to authenticated;

-- تقفيل الدرج: صاحب المحل الكل، والاستقبال بتاعه بس
create policy closings_select on public.drawer_closings for select to authenticated using (
  shop_id = public.current_shop_id() and (public.current_app_role() = 'owner' or closed_by = auth.uid()));
grant select on public.drawer_closings to authenticated;

-- الموردين: صاحب المحل بس
create policy suppliers_all on public.suppliers for select to authenticated using (shop_id = public.current_shop_id() and public.current_app_role() = 'owner');
create policy suppliers_insert on public.suppliers for insert to authenticated with check (shop_id = public.current_shop_id() and public.current_app_role() = 'owner');
create policy suppliers_update on public.suppliers for update to authenticated using (shop_id = public.current_shop_id() and public.current_app_role() = 'owner') with check (shop_id = public.current_shop_id());
grant select, insert, update on public.suppliers to authenticated;

-- الأصناف: صاحب المحل بيضيف ويعدّل، والاستقبال بيشوف (الفني من items_stock من غير أسعار)
create policy items_select on public.items for select to authenticated using (shop_id = public.current_shop_id() and public.current_app_role() in ('owner', 'reception'));
create policy items_insert on public.items for insert to authenticated with check (shop_id = public.current_shop_id() and public.current_app_role() = 'owner');
create policy items_update on public.items for update to authenticated using (shop_id = public.current_shop_id() and public.current_app_role() = 'owner') with check (shop_id = public.current_shop_id());
grant select, insert, update on public.items to authenticated;

-- الدوال: للمستخدمين المسجلين بس (وكل دالة بتتأكد من الدور جواها)
do $$
declare f text;
begin
  foreach f in array array[
    'record_payment(uuid, uuid, uuid, bigint, uuid, text, text)', 'reverse_entry(uuid, text)', 'transfer_cash(uuid, uuid, uuid, bigint, text)',
    'record_expense(uuid, uuid, uuid, bigint, text)', 'owner_capital(uuid, uuid, bigint, text)', 'owner_drawing(uuid, uuid, bigint, text)',
    'accrue_salary(uuid, uuid, bigint, text)', 'pay_salary(uuid, uuid, uuid, bigint, text)', 'give_advance(uuid, uuid, uuid, bigint, text)',
    'settle_advance(uuid, uuid, bigint, text)', 'record_purchase(uuid, uuid, jsonb, uuid, text)', 'pay_supplier(uuid, uuid, uuid, bigint, text)',
    'use_part(uuid, uuid, uuid, integer)', 'record_sale(uuid, jsonb, uuid, uuid, text)', 'my_drawers()', 'close_drawer(uuid, uuid, bigint, text)',
    'add_account(uuid, text, text, text, uuid)', 'update_account(uuid, text, uuid, boolean, boolean)', 'deliver_on_credit(uuid)',
    'device_money(uuid)', 'financial_position(timestamptz, timestamptz)', 'statement(text, uuid, timestamptz, timestamptz)', 'items_stock()'
  ] loop
    execute format('revoke execute on function public.%s from public, anon', f);
    execute format('grant execute on function public.%s to authenticated', f);
  end loop;
end $$;

-- ============================== 0009_tracking_guess_limit.sql ==============================
-- حد المحاولات على رقم الطلب: بيعدّ التخمينات المختلفة بس
--
-- المشكلة: رقم الطلب (زي 2026-0001) بيتكرر بين المحلات. لو القفل بيعدّ كل محاولة غلط،
-- عميل بيغلط في كتابة رقمه في محل، ممكن يقفل نفس الرقم على عميل في محل تاني.
-- الحل: القفل بيعدّ آخر 4 أرقام *المختلفة* اللي اتجربت على رقم الطلب ده (5 في 15 دقيقة).
-- العميل اللي بيكرر نفس الغلطة ما بيقفلش حاجة، واللي بيخمّن أرقام كتير بيتقفل بعد 5.
-- التخمين بيتخزن hash، مش الأرقام نفسها.

alter table public.tracking_attempts add column if not exists guess text;

create or replace function public.tracking_guess(p_order text, p_last4 text) returns text
language sql immutable set search_path = public, extensions as $$
  select case when p_order is null or p_last4 is null then null
    else encode(digest(upper(trim(p_order)) || ':' || trim(p_last4), 'sha256'), 'hex') end
$$;

create or replace function public.tracking_guard(p_order text) returns text
language plpgsql security definer set search_path = public as $$
declare k text := public.tracking_client_key();
begin
  if (select count(*) from public.tracking_attempts where client_key = k and not success and created_at > now() - interval '15 minutes') >= 10
     or (p_order is not null and (select count(distinct guess) from public.tracking_attempts
           where order_no = trim(p_order) and not success and guess is not null and created_at > now() - interval '15 minutes') >= 5) then
    raise exception 'E_RATE_LIMIT';
  end if;
  return k;
end $$;

create or replace function public.get_tracking(p_order text default null, p_last4 text default null, p_token text default null)
returns table(
  order_no text, status public.device_status, brand text, model text, received_at timestamptz,
  updated_at timestamptz, estimated_cost integer, final_cost integer, technician text,
  shop_name text, shop_phone text, shop_logo text, currency text, warranty_until timestamptz,
  can_decide boolean, decision text
)
language plpgsql security definer set search_path = public as $$
declare
  k text := public.tracking_guard(p_order);
  d public.devices;
begin
  d := public.tracking_find(p_order, p_last4, p_token);
  if d.id is null then
    -- مش بنرمي خطأ هنا عشان المحاولة الغلط تفضل متسجلة (الخطأ بيلغي التسجيل). النتيجة الفاضية = مش موجود
    insert into public.tracking_attempts(client_key, order_no, success, guess) values (k, trim(p_order), false, public.tracking_guess(p_order, p_last4));
    return;
  end if;
  insert into public.tracking_attempts(shop_id, client_key, order_no, success) values (d.shop_id, k, d.order_no, true);
  return query
  select d.order_no, d.status, d.brand, d.model, d.received_at,
    coalesce((select max(l.created_at) from public.status_log l where l.device_id = d.id), d.updated_at),
    dc.estimated_cost, dc.final_cost,
    -- اسم الفني: آخر فني غيّر الحالة (الاسم الأول بس)
    (select split_part(p.full_name, ' ', 1) from public.status_log l join public.profiles p on p.id = l.changed_by
       where l.device_id = d.id and p.role = 'technician' order by l.created_at desc limit 1),
    s.name, s.phone, s.logo_path, s.currency, d.warranty_until,
    d.status = 'awaiting_approval' and not exists (
      select 1 from public.quote_decisions q where q.device_id = d.id and q.created_at > coalesce(
        (select max(l.created_at) from public.status_log l where l.device_id = d.id and l.new_status = 'awaiting_approval'), d.received_at)),
    (select q.decision from public.quote_decisions q where q.device_id = d.id order by q.created_at desc limit 1)
  from public.shops s
  left join public.device_costs dc on dc.device_id = d.id and dc.deleted_at is null
  where s.id = d.shop_id;
end $$;

create or replace function public.decide_quote(p_decision text, p_order text default null, p_last4 text default null, p_token text default null)
returns public.device_status
language plpgsql security definer set search_path = public as $$
declare
  k text := public.tracking_guard(p_order);
  d public.devices;
  amt integer;
  next_status public.device_status;
begin
  if p_decision not in ('approved', 'rejected') then raise exception 'E_BAD_INPUT'; end if;
  d := public.tracking_find(p_order, p_last4, p_token);
  if d.id is null then
    insert into public.tracking_attempts(client_key, order_no, success, guess) values (k, trim(p_order), false, public.tracking_guess(p_order, p_last4));
    return null;
  end if;
  if d.status <> 'awaiting_approval' then raise exception 'E_BAD_TRANSITION'; end if;
  select coalesce(final_cost, estimated_cost) into amt from public.device_costs where device_id = d.id and deleted_at is null;
  insert into public.quote_decisions(shop_id, device_id, decision, amount, client_key) values (d.shop_id, d.id, p_decision, amt, k);
  next_status := case when p_decision = 'approved' then 'in_repair'::public.device_status else 'unrepairable'::public.device_status end;
  update public.devices set status = next_status where id = d.id;
  insert into public.audit_log(shop_id, actor_id, action, entity, entity_id, after)
  values (d.shop_id, null, 'customer_' || p_decision, 'devices', d.id, jsonb_build_object('amount', amt, 'order_no', d.order_no));
  return next_status;
end $$;

revoke execute on function public.get_tracking(text, text, text) from public;
revoke execute on function public.decide_quote(text, text, text, text) from public;
grant execute on function public.get_tracking(text, text, text) to anon, authenticated;
grant execute on function public.decide_quote(text, text, text, text) to anon, authenticated;
revoke execute on function public.tracking_guard(text) from public, anon, authenticated;
revoke execute on function public.tracking_guess(text, text) from public, anon, authenticated;

-- ============================== 0010_default_cashboxes.sql ==============================
-- الخزن الأساسية لكل محل (طلب صاحب المشروع): كاش الدرج، فودافون كاش، InstaPay، حساب بنك، الكارت (POS)،
-- غير أي طريقة دفع تانية مفعّلة في المحل (زي التقسيط). صاحب المحل يقدر يضيف خزن تانية من add_account.
create or replace function public.ensure_ledger_accounts(p_shop uuid) returns void
language plpgsql security definer set search_path = public as $$
declare m text;
begin
  insert into public.accounts(shop_id, code, type, kind)
  select p_shop, v.code, v.type::public.account_type, v.kind from (values
    ('ar', 'asset', 'receivable'), ('advances', 'asset', 'advances'), ('inventory', 'asset', 'inventory'),
    ('ap', 'liability', 'payable'), ('salaries_payable', 'liability', 'salaries'),
    ('capital', 'equity', 'capital'), ('drawings', 'equity', 'drawings'),
    ('rev_repair', 'revenue', 'revenue'), ('rev_parts', 'revenue', 'revenue'), ('rev_accessories', 'revenue', 'revenue'), ('overage', 'revenue', 'overage'),
    ('cogs', 'expense', 'cogs'), ('shortage', 'expense', 'shortage'),
    ('exp_salaries', 'expense', 'expense'), ('exp_rent', 'expense', 'expense'), ('exp_electricity', 'expense', 'expense'),
    ('exp_internet', 'expense', 'expense'), ('exp_purchases', 'expense', 'expense')
  ) as v(code, type, kind)
  on conflict (shop_id, code) where code is not null do nothing;
  for m in
    select unnest(array['cash', 'wallet', 'instapay', 'bank_transfer', 'card'])
    union
    select unnest(payment_methods) from public.shops where id = p_shop
  loop
    insert into public.accounts(shop_id, code, type, kind, method)
    values (p_shop, 'cash_' || m, 'asset', 'cash', m)
    on conflict (shop_id, code) where code is not null do nothing;
  end loop;
end $$;
revoke execute on function public.ensure_ledger_accounts(uuid) from public, anon, authenticated;

do $$
declare s uuid;
begin
  perform set_config('warsha.system', 'on', true);
  for s in select id from public.shops loop
    perform public.ensure_ledger_accounts(s);
  end loop;
  perform set_config('warsha.system', 'off', true);
end $$;

-- ============================== 0011_finance_drilldown.sql ==============================
-- تفاصيل أرقام شاشة "الوضع المالي" (صاحب المحل بس): كل رقم بيتفتح لتفاصيله

-- كل الأرصدة لنوع معيّن: customers (ليّا)، suppliers (عليّا)، employees (سلف ومرتبات)
create or replace function public.party_balances(p_kind text)
returns table(party_type text, party_id uuid, name text, account text, balance bigint)
language plpgsql stable security definer set search_path = public as $$
declare s uuid := public.current_shop_id();
begin
  perform public.ledger_require(array['owner']::public.app_role[]);
  if p_kind not in ('customers', 'suppliers', 'employees') then raise exception 'E_BAD_INPUT'; end if;
  return query
  select l.party_type, l.party_id,
         coalesce(c.name, sp.name, p.full_name) as name, a.code,
         sum((l.debit - l.credit) * public.account_sign(a.type))::bigint
  from public.journal_lines l
  join public.accounts a on a.id = l.account_id
  left join public.customers c on l.party_type = 'customer' and c.id = l.party_id
  left join public.suppliers sp on l.party_type = 'supplier' and sp.id = l.party_id
  left join public.profiles p on l.party_type = 'employee' and p.id = l.party_id
  where l.shop_id = s and l.party_id is not null
    and ((p_kind = 'customers' and a.kind = 'receivable') or (p_kind = 'suppliers' and a.kind = 'payable') or (p_kind = 'employees' and a.kind in ('advances', 'salaries')))
  group by l.party_type, l.party_id, c.name, sp.name, p.full_name, a.code
  having sum((l.debit - l.credit) * public.account_sign(a.type)) <> 0
  order by 5 desc;
end $$;

-- الإيرادات والمصروفات لكل بند في الفترة
create or replace function public.pl_breakdown(p_from timestamptz, p_to timestamptz)
returns table(account_id uuid, code text, name text, type public.account_type, amount bigint)
language plpgsql stable security definer set search_path = public as $$
begin
  perform public.ledger_require(array['owner']::public.app_role[]);
  return query
  select a.id, a.code, a.name, a.type,
         sum(case when a.type = 'revenue' then l.credit - l.debit else l.debit - l.credit end)::bigint
  from public.journal_lines l
  join public.accounts a on a.id = l.account_id
  join public.journal_entries e on e.id = l.entry_id
  where l.shop_id = public.current_shop_id() and a.type in ('revenue', 'expense') and e.occurred_at >= p_from and e.occurred_at < p_to
  group by a.id
  having sum(l.debit - l.credit) <> 0
  order by a.type desc, 5 desc;
end $$;

-- صافي حركة كل خزنة يوم بيوم في الفترة (للـ sparkline)
create or replace function public.cashbox_daily(p_from timestamptz, p_to timestamptz)
returns table(cashbox uuid, day date, net bigint)
language plpgsql stable security definer set search_path = public as $$
begin
  perform public.ledger_require(array['owner']::public.app_role[]);
  return query
  select l.account_id, (date_trunc('day', e.occurred_at at time zone 'Africa/Cairo'))::date, sum(l.debit - l.credit)::bigint
  from public.journal_lines l
  join public.accounts a on a.id = l.account_id and a.kind = 'cash'
  join public.journal_entries e on e.id = l.entry_id
  where l.shop_id = public.current_shop_id() and e.occurred_at >= p_from and e.occurred_at < p_to
  group by 1, 2
  order by 2;
end $$;

do $$
declare f text;
begin
  foreach f in array array['party_balances(text)', 'pl_breakdown(timestamptz, timestamptz)', 'cashbox_daily(timestamptz, timestamptz)'] loop
    execute format('revoke execute on function public.%s from public, anon', f);
    execute format('grant execute on function public.%s to authenticated', f);
  end loop;
end $$;

-- تحديث لحظي: أي قيد جديد بيحدّث شاشة الوضع المالي (والـ RLS بيخلي صاحب المحل بس يستقبله)
do $$
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    begin
      alter publication supabase_realtime add table public.journal_entries, public.payments;
    exception when duplicate_object then null;
    end;
  end if;
end $$;

-- قالب واتساب جديد: تذكير العميل المدين بالمبلغ اللي عليه
alter table public.message_templates drop constraint if exists message_templates_key_check;
alter table public.message_templates add constraint message_templates_key_check
  check (key in ('received', 'status', 'approval', 'ready', 'reminder', 'delivered', 'debt'));

-- ============================== 0012_spec_completion.sql ==============================
-- استكمال المراحل 1-3 حسب docs/spec.pdf (المراجعة يوم 2026-11-06)
--
-- 1) صفحة التتبع بتعرض المتبقي.
-- 2) التسليم بالآجل بيتسجل في سجل النشاط باسم صاحب المحل اللي وافق.
-- 3) كل قطعة بمصدرها: المورد وتاريخ الشراء وسعره (حتى في الشراء النقدي)، ومقارنة أسعار الموردين.
-- 4) حد أدنى لكل صنف وقائمة النواقص.
-- 5) قائمة المدينين بأقدم دين.
-- 6) القطع المستبدلة في الجهاز (للفاتورة) من غير تكاليف.
-- 7) التسعير: هامش الربح وأجرة كل نوع عطل من الإعدادات، والسعر المقترح للاستقبال من غير ما تشوف التكلفة.
-- 8) توقيع العميل على الشاشة عند الاستلام.

-- ---------- 1) التتبع ----------
drop function if exists public.get_tracking(text, text, text);
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
    -- مش بنرمي خطأ هنا عشان المحاولة الغلط تفضل متسجلة (الخطأ بيلغي التسجيل). النتيجة الفاضية = مش موجود
    insert into public.tracking_attempts(client_key, order_no, success, guess) values (k, trim(p_order), false, public.tracking_guess(p_order, p_last4));
    return;
  end if;
  insert into public.tracking_attempts(shop_id, client_key, order_no, success) values (d.shop_id, k, d.order_no, true);
  return query
  select d.order_no, d.status, d.brand, d.model, d.received_at,
    coalesce((select max(l.created_at) from public.status_log l where l.device_id = d.id), d.updated_at),
    dc.estimated_cost, dc.final_cost,
    -- اسم الفني: آخر فني غيّر الحالة (الاسم الأول بس)
    (select split_part(p.full_name, ' ', 1) from public.status_log l join public.profiles p on p.id = l.changed_by
       where l.device_id = d.id and p.role = 'technician' order by l.created_at desc limit 1),
    s.name, s.phone, s.logo_path, s.currency, d.warranty_until,
    d.status = 'awaiting_approval' and not exists (
      select 1 from public.quote_decisions q where q.device_id = d.id and q.created_at > coalesce(
        (select max(l.created_at) from public.status_log l where l.device_id = d.id and l.new_status = 'awaiting_approval'), d.received_at)),
    (select q.decision from public.quote_decisions q where q.device_id = d.id order by q.created_at desc limit 1),
    -- المتبقي على العميل للجهاز ده (بعد التكلفة النهائية بس)
    case when dc.final_cost is not null then greatest(dc.final_cost - public.device_paid(d.id), 0)::bigint end
  from public.shops s
  left join public.device_costs dc on dc.device_id = d.id and dc.deleted_at is null
  where s.id = d.shop_id;
end $$;
revoke execute on function public.get_tracking(text, text, text) from public;
grant execute on function public.get_tracking(text, text, text) to anon, authenticated;

-- ---------- 2) التسليم بالآجل في السجل ----------
create or replace function public.deliver_on_credit(p_device uuid) returns void
language plpgsql security definer set search_path = public as $$
declare due bigint;
begin
  perform public.ledger_require(array['owner']::public.app_role[]);
  select greatest(coalesce(c.final_cost, 0) - public.device_paid(p_device), 0) into due
  from public.devices d left join public.device_costs c on c.device_id = d.id and c.deleted_at is null
  where d.id = p_device and d.shop_id = public.current_shop_id();
  if not found then raise exception 'E_NOT_FOUND'; end if;
  perform set_config('warsha.credit_ok', p_device::text, true);
  update public.devices set status = 'delivered' where id = p_device and shop_id = public.current_shop_id();
  perform set_config('warsha.credit_ok', '', true);
  insert into public.audit_log(shop_id, actor_id, action, entity, entity_id, after)
  values (public.current_shop_id(), auth.uid(), 'deliver_on_credit', 'devices', p_device, jsonb_build_object('due', due));
end $$;

-- ---------- 3) مصدر كل قطعة ----------
create table public.purchases (
  id uuid primary key,
  shop_id uuid not null references public.shops(id),
  supplier_id uuid not null references public.suppliers(id),
  entry_id uuid not null unique references public.journal_entries(id),
  on_credit boolean not null,
  created_by uuid references public.profiles(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);
alter table public.purchases enable row level security;
revoke all on public.purchases from public, anon, authenticated;
create policy purchases_select on public.purchases for select to authenticated using (shop_id = public.current_shop_id() and public.current_app_role() = 'owner');
grant select on public.purchases to authenticated;
create trigger ledger_immutable before update or delete on public.purchases for each row execute function public.tg_ledger_immutable();
create trigger zz_audit after insert on public.purchases for each row execute function public.tg_audit();

-- المشتريات القديمة: المورد من سطر الآجل
insert into public.purchases(id, shop_id, supplier_id, entry_id, on_credit, created_by, created_at)
select e.source_id, e.shop_id, l.party_id, e.id, true, e.created_by, e.created_at
from public.journal_entries e join public.journal_lines l on l.entry_id = e.id and l.party_type = 'supplier'
where e.source_type = 'purchase' on conflict do nothing;

create or replace function public.tg_purchase_link() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  return null;
end $$;

-- record_purchase بيسجل المورد في purchases (نفس المنطق، وزيادة السطر ده)
create or replace function public.record_purchase(p_id uuid, p_supplier uuid, p_lines jsonb, p_cashbox uuid default null, p_note text default null)
returns uuid
language plpgsql security definer set search_path = public as $$
declare
  s uuid := public.current_shop_id();
  l jsonb;
  total bigint := 0;
  q bigint;
  u bigint;
  e uuid;
  credit_line jsonb;
begin
  perform public.ledger_require(array['owner']::public.app_role[]);
  e := public.ledger_idem(p_id);
  if e is not null then return e; end if;
  if not exists (select 1 from public.suppliers where id = p_supplier and shop_id = s and deleted_at is null) then raise exception 'E_NOT_FOUND'; end if;
  if jsonb_typeof(p_lines) <> 'array' or jsonb_array_length(p_lines) = 0 then raise exception 'E_BAD_INPUT'; end if;
  for l in select * from jsonb_array_elements(p_lines) loop
    q := (l ->> 'qty')::bigint;
    u := (l ->> 'unit_cost')::bigint;
    if q is null or q <= 0 or q > 100000 or u is null or u < 0 then raise exception 'E_BAD_AMOUNT'; end if;
    if not exists (select 1 from public.items where id = (l ->> 'item')::uuid and shop_id = s and deleted_at is null) then raise exception 'E_NOT_FOUND'; end if;
    total := total + q * u;
  end loop;
  perform public.ledger_amount(total);
  credit_line := case when p_cashbox is null
    then public.ledger_line(public.ledger_acc('ap'), 0, total, 'supplier', p_supplier)
    else public.ledger_line((public.ledger_cashbox(p_cashbox)).id, 0, total) end;
  e := public.ledger_post('purchase', p_id, p_note, jsonb_build_array(public.ledger_line(public.ledger_acc('inventory'), total, 0), credit_line), null, p_id);
  for l in select * from jsonb_array_elements(p_lines) loop
    insert into public.stock_moves(shop_id, item_id, entry_id, qty, value)
    values (s, (l ->> 'item')::uuid, e, (l ->> 'qty')::int, (l ->> 'qty')::bigint * (l ->> 'unit_cost')::bigint);
  end loop;
  insert into public.purchases(id, shop_id, supplier_id, entry_id, on_credit, created_by) values (p_id, s, p_supplier, e, p_cashbox is null, auth.uid());
  return e;
end $$;
drop function if exists public.tg_purchase_link();

-- أسعار الصنف عند كل مورد: آخر سعر، وأقل سعر، وآخر تاريخ شراء (صاحب المحل)
create or replace function public.item_suppliers(p_item uuid)
returns table(supplier_id uuid, supplier text, last_cost bigint, min_cost bigint, last_at timestamptz, total_qty bigint)
language plpgsql stable security definer set search_path = public as $$
#variable_conflict use_column
begin
  perform public.ledger_require(array['owner']::public.app_role[]);
  return query
  select p.supplier_id, sp.name,
         (array_agg((m.value / m.qty)::bigint order by m.created_at desc))[1],
         min((m.value / m.qty)::bigint),
         max(m.created_at), sum(m.qty)::bigint
  from public.stock_moves m
  join public.purchases p on p.entry_id = m.entry_id
  join public.suppliers sp on sp.id = p.supplier_id
  where m.item_id = p_item and m.shop_id = public.current_shop_id() and m.qty > 0
    and not exists (select 1 from public.journal_entries r where r.reverses_id = m.entry_id)
  group by p.supplier_id, sp.name
  order by 3;
end $$;

-- ---------- 4) الحد الأدنى والنواقص ----------
alter table public.items add column if not exists min_qty integer not null default 0 check (min_qty between 0 and 100000);
alter table public.items add column if not exists supplier_id uuid references public.suppliers(id);

drop function if exists public.items_stock();
create or replace function public.items_stock() returns table(id uuid, kind text, name text, sku text, sale_price integer, qty bigint, avg_cost bigint, value bigint, min_qty integer, supplier_id uuid, short boolean)
language plpgsql stable security definer set search_path = public as $$
declare r public.app_role := public.current_app_role();
begin
  if r is null then raise exception 'E_FORBIDDEN'; end if;
  return query
  select i.id, i.kind, i.name, i.sku,
         case when r = 'technician' then null else i.sale_price end,
         coalesce(st.q, 0)::bigint,
         case when r = 'owner' and coalesce(st.q, 0) > 0 then (st.v / st.q)::bigint end,
         case when r = 'owner' then coalesce(st.v, 0)::bigint end,
         i.min_qty, case when r = 'owner' then i.supplier_id end,
         i.min_qty > 0 and coalesce(st.q, 0) <= i.min_qty
  from public.items i
  left join (select m.item_id, sum(m.qty) as q, sum(m.value) as v from public.stock_moves m group by m.item_id) st on st.item_id = i.id
  where i.shop_id = public.current_shop_id() and i.deleted_at is null
  order by i.kind, i.name;
end $$;

-- ---------- 5) المدينين بأقدم دين ----------
-- أقدم دين = تاريخ أقدم حركة مدينة لسه ما اتسددتش (السداد بيقفل الأقدم الأول)
drop function if exists public.party_balances(text);
create or replace function public.party_balances(p_kind text)
returns table(party_type text, party_id uuid, name text, account text, balance bigint, oldest timestamptz)
language plpgsql stable security definer set search_path = public as $$
#variable_conflict use_column
declare s uuid := public.current_shop_id();
begin
  perform public.ledger_require(array['owner']::public.app_role[]);
  if p_kind not in ('customers', 'suppliers', 'employees') then raise exception 'E_BAD_INPUT'; end if;
  return query
  with lines as (
    select l.party_type, l.party_id, a.code, e.occurred_at, e.entry_no,
           (case when public.account_sign(a.type) = 1 then l.debit else l.credit end)::bigint as plus,
           (case when public.account_sign(a.type) = 1 then l.credit else l.debit end)::bigint as minus
    from public.journal_lines l join public.accounts a on a.id = l.account_id join public.journal_entries e on e.id = l.entry_id
    where l.shop_id = s and l.party_id is not null
      and ((p_kind = 'customers' and a.kind = 'receivable') or (p_kind = 'suppliers' and a.kind = 'payable') or (p_kind = 'employees' and a.kind in ('advances', 'salaries')))
  ),
  tot as (select party_type, party_id, code, sum(plus) - sum(minus) as bal, sum(minus) as paid from lines group by 1, 2, 3),
  cum as (select l.*, sum(l.plus) over (partition by l.party_id, l.code order by l.occurred_at, l.entry_no) as cum_plus from lines l where l.plus > 0)
  select t.party_type, t.party_id, coalesce(c.name, sp.name, p.full_name), t.code, t.bal::bigint,
         (select min(x.occurred_at) from cum x where x.party_id = t.party_id and x.code = t.code and x.cum_plus > t.paid)
  from tot t
  left join public.customers c on t.party_type = 'customer' and c.id = t.party_id
  left join public.suppliers sp on t.party_type = 'supplier' and sp.id = t.party_id
  left join public.profiles p on t.party_type = 'employee' and p.id = t.party_id
  where t.bal <> 0
  order by 5 desc;
end $$;

-- ---------- 6) القطع المستبدلة (للفاتورة) ----------
create or replace function public.device_parts(p_device uuid)
returns table(item_id uuid, name text, qty bigint)
language plpgsql stable security definer set search_path = public as $$
#variable_conflict use_column
begin
  if public.current_app_role() is null then raise exception 'E_FORBIDDEN'; end if;
  if not exists (select 1 from public.devices where id = p_device and shop_id = public.current_shop_id()) then raise exception 'E_NOT_FOUND'; end if;
  return query
  select i.id, i.name, (-sum(m.qty))::bigint
  from public.stock_moves m
  join public.journal_entries e on e.id = m.entry_id
  join public.items i on i.id = m.item_id
  where (e.device_id = p_device) and e.source_type in ('part_use', 'reversal')
  group by i.id, i.name
  having -sum(m.qty) > 0;
end $$;

-- ---------- 7) التسعير ----------
alter table public.shops add column if not exists default_margin_pct integer not null default 20 check (default_margin_pct between 0 and 1000);

create table public.labor_rates (
  id uuid primary key,
  shop_id uuid not null references public.shops(id),
  issue text not null check (length(trim(issue)) between 1 and 80),
  amount integer not null check (amount between 0 and 2000000000),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);
create unique index labor_rates_issue on public.labor_rates(shop_id, lower(trim(issue))) where deleted_at is null;
alter table public.labor_rates enable row level security;
revoke all on public.labor_rates from public, anon, authenticated;
create policy labor_select on public.labor_rates for select to authenticated using (shop_id = public.current_shop_id() and public.current_app_role() in ('owner', 'reception'));
create policy labor_insert on public.labor_rates for insert to authenticated with check (shop_id = public.current_shop_id() and public.current_app_role() = 'owner');
create policy labor_update on public.labor_rates for update to authenticated using (shop_id = public.current_shop_id() and public.current_app_role() = 'owner') with check (shop_id = public.current_shop_id());
grant select, insert, update on public.labor_rates to authenticated;
create trigger set_updated_at before update on public.labor_rates for each row execute function public.tg_set_updated_at();
create trigger block_delete before delete on public.labor_rates for each row execute function public.tg_block_delete();
create trigger a_force_shop_id before insert or update on public.labor_rates for each row execute function public.tg_force_shop_id();
create trigger zz_audit after insert or update on public.labor_rates for each row execute function public.tg_audit();

-- السعر المقترح = تكلفة القطع + أجرة العطل + هامش على القطع، متقرّب لأقرب 5 جنيه.
-- الاستقبال بتشوف السعر بس (من غير تكلفة القطع ولا الربح). نفس معادلة suggestPrice في src/lib/ledger.ts
create or replace function public.suggest_device_price(p_device uuid) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare
  d public.devices;
  parts bigint;
  labor bigint;
  margin int;
  markup bigint;
  price bigint;
begin
  perform public.ledger_require(array['owner', 'reception']::public.app_role[]);
  select * into d from public.devices where id = p_device and shop_id = public.current_shop_id();
  if not found then raise exception 'E_NOT_FOUND'; end if;
  select coalesce(-sum(m.value), 0) into parts from public.stock_moves m join public.journal_entries e on e.id = m.entry_id
   where e.device_id = p_device and e.source_type in ('part_use', 'reversal');
  select coalesce(sum(r.amount), 0) into labor from public.labor_rates r
   where r.shop_id = d.shop_id and r.deleted_at is null and position(lower(trim(r.issue)) in lower(d.issue)) > 0;
  select default_margin_pct into margin from public.shops where id = d.shop_id;
  markup := (parts * margin + 99) / 100;
  price := ((parts + labor + markup + 499) / 500) * 500;
  return case when public.current_app_role() = 'owner'
    then jsonb_build_object('price', price, 'parts', parts, 'labor', labor, 'margin', margin, 'markup', markup)
    else jsonb_build_object('price', price, 'labor', labor) end;
end $$;

-- ---------- 8) توقيع العميل ----------
alter table public.devices add column if not exists intake_signature text check (intake_signature is null or (intake_signature like 'data:image/png;base64,%' and length(intake_signature) < 300000));

do $$
declare f text;
begin
  foreach f in array array['item_suppliers(uuid)', 'items_stock()', 'party_balances(text)', 'device_parts(uuid)', 'suggest_device_price(uuid)', 'deliver_on_credit(uuid)'] loop
    execute format('revoke execute on function public.%s from public, anon', f);
    execute format('grant execute on function public.%s to authenticated', f);
  end loop;
end $$;

-- ============================== 0013_tracking_ambiguous.sql ==============================
-- التتبع برقم الطلب وآخر 4 أرقام: رقم الطلب بيتكرر بين المحلات، وممكن عميلين في محلين يشتركوا في آخر 4 أرقام.
-- قبل كده كان بيرجّع أحدث جهاز (ممكن يبقى جهاز محل تاني). دلوقتي لو فيه أكتر من جهاز مطابق، ما بيرجّعش أي واحد،
-- وبيطلب من العميل يمسح الـ QR (الرمز السري فريد). وده بيحمي كمان الموافقة على التكلفة من إنها توصل لجهاز غلط.
create or replace function public.tracking_find(p_order text, p_last4 text, p_token text)
returns public.devices
language plpgsql stable security definer set search_path = public as $$
declare d public.devices; n int;
begin
  if p_token is not null and length(p_token) >= 16 then
    select * into d from public.devices where tracking_token = p_token and deleted_at is null;
    if found and (p_order is null or d.order_no = trim(p_order)) then return d; end if;
    return null;
  end if;
  if p_order is null or p_last4 is null or p_last4 !~ '^[0-9]{4}$' then return null; end if;
  select count(*) into n
  from public.devices dv join public.customers c on c.id = dv.customer_id
  where dv.order_no = trim(p_order) and right(c.phone, 4) = p_last4 and dv.deleted_at is null;
  if n > 1 then raise exception 'E_TRACK_AMBIGUOUS'; end if;
  select dv.* into d
  from public.devices dv join public.customers c on c.id = dv.customer_id
  where dv.order_no = trim(p_order) and right(c.phone, 4) = p_last4 and dv.deleted_at is null;
  if found then return d; end if;
  return null;
end $$;
revoke execute on function public.tracking_find(text, text, text) from public, anon, authenticated;

-- ============================== 0014_technicians.sql ==============================
-- المرحلة 4: الفنيون وتوزيع الشغل (docs/spec.pdf صفحة 3)
--
-- - كل فني ليه تخصص أو أكتر، وكل نوع عطل ليه مسار (خطوات بالترتيب، كل خطوة تخصص). صاحب المحل بيعدّلهم من الإعدادات.
-- - الجهاز بيتحرك لوحده بين الفنيين حسب المسار. اللي عمل نفس التخصص قبل كده في نفس الجهاز بياخده تاني (اللي فك يركّب).
--   وإلا الفني صاحب التخصص الأقل شغلًا.
-- - الفني بيشوف أجهزته بس. أول ما يبدأ بيتسجل وقت البداية، ولما يخلّص الجهاز بيروح للخطوة اللي بعدها.
-- - آخر فني بيعمل فحص نهائي (نفس قائمة الفحص السريع) قبل ما الجهاز يبقى جاهز.
-- - "عطل غير معروف": أول فني بيفحص ويحدد المسار.
-- - مرتجع الضمان بيرجع لنفس الفني اللي قفله، وبيتسجل عليه كمرتجع.
-- - الأولوية: عاجل، عادي، ضمان. وتقدير الوقت من متوسط الأجهزة المشابهة (5 أو أكتر).
-- - الفني ما يبدأش شغل والجهاز مستني موافقة العميل.

-- ============================================================
-- الجداول
-- ============================================================
create table public.specialties (
  id uuid primary key,
  shop_id uuid not null references public.shops(id),
  code text,                         -- الأساسية: assembly / micro / software (الاسم بيتترجم في الواجهة)
  name text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  check (code is not null or nullif(trim(name), '') is not null)
);
create unique index specialties_code on public.specialties(shop_id, code) where code is not null;

create table public.staff_specialties (
  id uuid primary key,
  shop_id uuid not null references public.shops(id),
  profile_id uuid not null references public.profiles(id),
  specialty_id uuid not null references public.specialties(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);
create unique index staff_specialties_one on public.staff_specialties(profile_id, specialty_id) where deleted_at is null;

create table public.routes (
  id uuid primary key,
  shop_id uuid not null references public.shops(id),
  code text,
  name text,
  keywords text[] not null default '{}',
  steps uuid[] not null check (cardinality(steps) between 1 and 8),
  diagnose boolean not null default false,  -- عطل غير معروف: بعد أول خطوة الفني بيحدد المسار
  sort integer not null default 100,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  check (code is not null or nullif(trim(name), '') is not null)
);
create unique index routes_code on public.routes(shop_id, code) where code is not null;

alter table public.devices add column if not exists priority text not null default 'normal' check (priority in ('urgent', 'normal', 'warranty'));
alter table public.devices add column if not exists route_id uuid references public.routes(id);
alter table public.devices add column if not exists est_minutes integer check (est_minutes is null or est_minutes between 1 and 100000);
alter table public.devices add column if not exists return_of_tech uuid references public.profiles(id);

create table public.repair_steps (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references public.shops(id),
  device_id uuid not null references public.devices(id),
  route_id uuid references public.routes(id),
  step_no integer not null,
  specialty_id uuid not null references public.specialties(id),
  technician_id uuid references public.profiles(id),
  status text not null default 'pending' check (status in ('pending', 'active', 'done', 'skipped')),
  started_at timestamptz,
  finished_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  unique (device_id, step_no)
);
create index repair_steps_tech on public.repair_steps(technician_id, status);

do $$
declare t text;
begin
  foreach t in array array['specialties', 'staff_specialties', 'routes', 'repair_steps'] loop
    execute format('alter table public.%I enable row level security', t);
    execute format('revoke all on public.%I from public, anon, authenticated', t);
    execute format('create trigger set_updated_at before update on public.%I for each row execute function public.tg_set_updated_at()', t);
    execute format('create trigger block_delete before delete on public.%I for each row execute function public.tg_block_delete()', t);
    execute format('create trigger a_force_shop_id before insert or update on public.%I for each row execute function public.tg_force_shop_id()', t);
    execute format('create trigger zz_audit after insert or update on public.%I for each row execute function public.tg_audit()', t);
  end loop;
end $$;

-- الإعدادات: كل المحل بيقرا، وصاحب المحل بس بيعدّل
create policy specialties_select on public.specialties for select to authenticated using (shop_id = public.current_shop_id());
create policy specialties_write on public.specialties for insert to authenticated with check (shop_id = public.current_shop_id() and public.current_app_role() = 'owner');
create policy specialties_update on public.specialties for update to authenticated using (shop_id = public.current_shop_id() and public.current_app_role() = 'owner') with check (shop_id = public.current_shop_id());
create policy staff_spec_select on public.staff_specialties for select to authenticated using (shop_id = public.current_shop_id());
create policy staff_spec_write on public.staff_specialties for insert to authenticated with check (shop_id = public.current_shop_id() and public.current_app_role() = 'owner');
create policy staff_spec_update on public.staff_specialties for update to authenticated using (shop_id = public.current_shop_id() and public.current_app_role() = 'owner') with check (shop_id = public.current_shop_id());
create policy routes_select on public.routes for select to authenticated using (shop_id = public.current_shop_id());
create policy routes_write on public.routes for insert to authenticated with check (shop_id = public.current_shop_id() and public.current_app_role() = 'owner');
create policy routes_update on public.routes for update to authenticated using (shop_id = public.current_shop_id() and public.current_app_role() = 'owner') with check (shop_id = public.current_shop_id());
grant select, insert, update on public.specialties, public.staff_specialties, public.routes to authenticated;
-- الخطوات: القراءة للمحل، والكتابة بالدوال بس
create policy steps_select on public.repair_steps for select to authenticated using (shop_id = public.current_shop_id());
grant select on public.repair_steps to authenticated;

-- ============================================================
-- الفني بيشوف أجهزته بس
-- ============================================================
-- الفني "العام": فني ملوش أي تخصص متسجل، فبيقدر ياخد أي خطوة (المحل الصغير اللي فيه فني واحد)
create or replace function public.tech_has_specialty(p_tech uuid, p_specialty uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.profiles p where p.id = p_tech and p.role = 'technician' and p.deleted_at is null)
     and (exists (select 1 from public.staff_specialties ss where ss.profile_id = p_tech and ss.specialty_id = p_specialty and ss.deleted_at is null)
          or not exists (select 1 from public.staff_specialties ss where ss.profile_id = p_tech and ss.deleted_at is null))
$$;

-- أجهزته = فيها خطوة متعيّنة له، أو خطوة مش متعيّنة لحد وهو عنده تخصصها، أو أجهزة لسه ملهاش مسار خالص
create or replace function public.tech_can_see(p_device uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.repair_steps s where s.device_id = p_device and s.technician_id = auth.uid())
      or exists (select 1 from public.repair_steps s
                 where s.device_id = p_device and s.technician_id is null and s.status in ('pending', 'active') and public.tech_has_specialty(auth.uid(), s.specialty_id)
                   and not exists (select 1 from public.repair_steps p where p.device_id = s.device_id and p.step_no < s.step_no and p.status in ('pending', 'active')))
      or not exists (select 1 from public.repair_steps s where s.device_id = p_device)
$$;
drop policy if exists devices_select on public.devices;
create policy devices_select on public.devices for select to authenticated
  using (shop_id = public.current_shop_id() and (public.current_app_role() <> 'technician' or public.tech_can_see(id)));

-- ============================================================
-- الأساسيات لكل محل: 3 تخصصات و4 مسارات (من المواصفات)، وصاحب المحل يعدّلهم
-- ============================================================
create or replace function public.ensure_tech_defaults(p_shop uuid) returns void
language plpgsql security definer set search_path = public as $$
declare a uuid; m uuid; sw uuid;
begin
  insert into public.specialties(id, shop_id, code) select gen_random_uuid(), p_shop, c from unnest(array['assembly', 'micro', 'software']) c
  on conflict (shop_id, code) where code is not null do nothing;
  select id into a from public.specialties where shop_id = p_shop and code = 'assembly';
  select id into m from public.specialties where shop_id = p_shop and code = 'micro';
  select id into sw from public.specialties where shop_id = p_shop and code = 'software';
  insert into public.routes(id, shop_id, code, keywords, steps, diagnose, sort) values
    (gen_random_uuid(), p_shop, 'screen_battery', array['شاشة', 'شاشه', 'بطارية', 'بطاريه', 'تاتش', 'screen', 'battery', 'lcd'], array[a], false, 10),
    (gen_random_uuid(), p_shop, 'board', array['شحن', 'ic', 'شبكة', 'شبكه', 'بوردة', 'بورده', 'charging', 'network', 'board'], array[a, m, a], false, 20),
    (gen_random_uuid(), p_shop, 'software', array['سوفت', 'فلاشة', 'فلاشه', 'تعليق', 'بيعلق', 'software', 'flash'], array[sw], false, 30),
    (gen_random_uuid(), p_shop, 'unknown', '{}', array[a], true, 1000)
  on conflict (shop_id, code) where code is not null do nothing;
end $$;
revoke execute on function public.ensure_tech_defaults(uuid) from public, anon, authenticated;

create or replace function public.tg_shop_tech() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  perform set_config('warsha.system', 'on', true);
  perform public.ensure_tech_defaults(new.id);
  perform set_config('warsha.system', 'off', true);
  return null;
end $$;
create trigger zz_shop_tech after insert on public.shops for each row execute function public.tg_shop_tech();

do $$
declare s uuid;
begin
  perform set_config('warsha.system', 'on', true);
  for s in select id from public.shops loop perform public.ensure_tech_defaults(s); end loop;
  perform set_config('warsha.system', 'off', true);
end $$;

-- ============================================================
-- التوزيع
-- ============================================================
-- المسار المناسب لوصف العطل: أول مسار (بالترتيب) فيه كلمة من كلماته جوه الوصف، وإلا مسار "عطل غير معروف"
create or replace function public.detect_route(p_issue text) returns uuid
language sql stable security definer set search_path = public as $$
  select id from public.routes r
  where r.shop_id = public.current_shop_id() and r.deleted_at is null
    and (r.diagnose or exists (select 1 from unnest(r.keywords) k where position(lower(k) in lower(coalesce(p_issue, ''))) > 0))
  order by r.diagnose, r.sort, r.created_at
  limit 1
$$;

-- الفني للخطوة: اللي عمل نفس التخصص في نفس الجهاز قبل كده، وإلا صاحب التخصص الأقل شغلًا (خطوات مفتوحة)
create or replace function public.pick_technician(p_device uuid, p_specialty uuid) returns uuid
language sql stable security definer set search_path = public as $$
  select coalesce(
    (select s.technician_id from public.repair_steps s join public.profiles p on p.id = s.technician_id and p.deleted_at is null
      where s.device_id = p_device and s.specialty_id = p_specialty and s.technician_id is not null and s.status = 'done'
      order by s.step_no desc limit 1),
    (select ss.profile_id from public.staff_specialties ss join public.profiles p on p.id = ss.profile_id and p.deleted_at is null and p.role = 'technician'
      where ss.specialty_id = p_specialty and ss.deleted_at is null and ss.shop_id = public.current_shop_id()
      order by (select count(*) from public.repair_steps x where x.technician_id = ss.profile_id and x.status in ('pending', 'active')), p.full_name
      limit 1),
    -- مفيش حد عنده التخصص: فني عام (ملوش تخصصات)
    (select p.id from public.profiles p
      where p.shop_id = public.current_shop_id() and p.role = 'technician' and p.deleted_at is null
        and not exists (select 1 from public.staff_specialties ss where ss.profile_id = p.id and ss.deleted_at is null)
      order by (select count(*) from public.repair_steps x where x.technician_id = p.id and x.status in ('pending', 'active')), p.full_name
      limit 1))
$$;

-- حماية الجهاز من المرحلة 1، ومعاها استثناء لحقول التوزيع من جوه الدوال (warsha.routing)
create or replace function public.tg_device_guard() returns trigger
language plpgsql security definer set search_path = public as $$
declare
  r public.app_role := public.current_app_role();
  fc integer;
  -- حقول التوزيع (المسار، الأولوية، فني المرتجع) بتتغير من دوال التوزيع الموثوقة بس، حتى لو اللي نادى فني
  sys text[] := case when current_setting('warsha.routing', true) = 'on' then array['route_id', 'priority', 'return_of_tech', 'warranty_days', 'warranty_until'] else array[]::text[] end;
begin
  -- حاجات ما بتتغيرش بعد الاستلام
  if new.order_no is distinct from old.order_no
     or new.received_at is distinct from old.received_at
     or new.received_by is distinct from old.received_by then
    raise exception 'E_RECEIPT_IMMUTABLE';
  end if;

  -- الفني يغيّر الحالة بس
  if r = 'technician' and
     (to_jsonb(new) - 'status' - 'updated_at' - 'delivered_at' - sys) <> (to_jsonb(old) - 'status' - 'updated_at' - 'delivered_at' - sys) then
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

-- يحط مسار للجهاز: الخطوات المفتوحة القديمة بتتلغي (skipped)، والجديدة بتتضاف بعدها، وأول خطوة بتتعيّن لفني
create or replace function public.set_route(p_device uuid, p_route uuid) returns void
language plpgsql security definer set search_path = public as $$
declare
  d public.devices;
  r public.routes;
  n int;
  sp uuid;
  i int := 0;
  first_step uuid;
begin
  select * into d from public.devices where id = p_device and shop_id = public.current_shop_id() and deleted_at is null for update;
  if not found then raise exception 'E_NOT_FOUND'; end if;
  select * into r from public.routes where id = p_route and shop_id = d.shop_id and deleted_at is null;
  if not found then raise exception 'E_NOT_FOUND'; end if;
  -- الفني بيحدد المسار بس لو هو اللي فحص (خطوة فحص في مسار "غير معروف" متعيّنة له)
  if public.current_app_role() = 'technician' and not exists (
      select 1 from public.repair_steps s join public.routes rr on rr.id = s.route_id and rr.diagnose
      where s.device_id = d.id and s.technician_id = auth.uid() and s.status in ('active', 'done')) then
    raise exception 'E_FORBIDDEN';
  end if;
  if public.current_app_role() is null then raise exception 'E_FORBIDDEN'; end if;
  update public.repair_steps set status = 'skipped', finished_at = now() where device_id = d.id and status in ('pending', 'active');
  select coalesce(max(step_no), 0) into n from public.repair_steps where device_id = d.id;
  foreach sp in array r.steps loop
    i := i + 1;
    insert into public.repair_steps(shop_id, device_id, route_id, step_no, specialty_id, technician_id)
    values (d.shop_id, d.id, r.id, n + i, sp, case when i = 1 then public.pick_technician(d.id, sp) end)
    returning id into first_step;
  end loop;
  perform set_config('warsha.routing', 'on', true);
  update public.devices set route_id = r.id where id = d.id;
  perform set_config('warsha.routing', 'off', true);
end $$;

-- يمشّي الجهاز في الحالات المسموحة لحد حالة معيّنة (من غير ما يكسر قواعد الانتقال)
create or replace function public.walk_status(p_device uuid, p_target public.device_status) returns void
language plpgsql security definer set search_path = public as $$
declare cur public.device_status; nxt public.device_status; guard int := 0;
begin
  loop
    select status into cur from public.devices where id = p_device;
    exit when cur = p_target or guard > 6;
    guard := guard + 1;
    nxt := case
      when p_target = 'inspecting' and cur = 'received' then 'inspecting'
      when p_target = 'in_repair' and cur in ('received') then 'inspecting'
      when p_target = 'in_repair' and cur in ('inspecting', 'awaiting_part', 'repaired', 'warranty_return') then 'in_repair'
      when p_target in ('repaired', 'ready') and cur = 'received' then 'inspecting'
      when p_target in ('repaired', 'ready') and cur in ('inspecting', 'awaiting_part', 'warranty_return') then 'in_repair'
      when p_target in ('repaired', 'ready') and cur = 'in_repair' then 'repaired'
      when p_target = 'ready' and cur = 'repaired' then 'ready'
      else null end;
    if nxt is null then raise exception 'E_BAD_TRANSITION'; end if;
    update public.devices set status = nxt where id = p_device;
  end loop;
end $$;
revoke execute on function public.walk_status(uuid, public.device_status) from public, anon, authenticated;

-- الفني بيبدأ خطوة: بيتسجل وقت البداية، والجهاز بيتنقل للفحص أو الصيانة
create or replace function public.start_step(p_step uuid) returns void
language plpgsql security definer set search_path = public as $$
declare s public.repair_steps; d public.devices; r public.routes;
begin
  select * into s from public.repair_steps where id = p_step and shop_id = public.current_shop_id() for update;
  if not found then raise exception 'E_NOT_FOUND'; end if;
  if public.current_app_role() = 'technician' then
    if s.technician_id is null and public.tech_has_specialty(auth.uid(), s.specialty_id) then
      s.technician_id := auth.uid();  -- خطوة مش متعيّنة لحد وهو عنده التخصص: بياخدها
    elsif s.technician_id is distinct from auth.uid() then
      raise exception 'E_FORBIDDEN';
    end if;
  elsif public.current_app_role() is distinct from 'owner' then
    raise exception 'E_FORBIDDEN';
  end if;
  if s.status <> 'pending' then raise exception 'E_BAD_TRANSITION'; end if;
  if exists (select 1 from public.repair_steps x where x.device_id = s.device_id and x.step_no < s.step_no and x.status in ('pending', 'active')) then
    raise exception 'E_STEP_ORDER';
  end if;
  select * into d from public.devices where id = s.device_id;
  if d.status = 'awaiting_approval' then raise exception 'E_AWAITING_APPROVAL'; end if;
  if d.status in ('delivered', 'ready', 'unrepairable') then raise exception 'E_BAD_TRANSITION'; end if;
  update public.repair_steps set status = 'active', started_at = now(), technician_id = s.technician_id where id = s.id;
  select * into r from public.routes where id = s.route_id;
  perform public.walk_status(d.id, case when coalesce(r.diagnose, false) or d.status = 'received' then 'inspecting'::public.device_status else 'in_repair'::public.device_status end);
end $$;

-- الفني خلّص خطوته. لو فيه خطوة بعدها الجهاز بيروح للفني بتاعها. لو دي الأخيرة: فحص نهائي إجباري، والجهاز بيبقى جاهز.
-- لو مسار "غير معروف": الفني لازم يحدد المسار الجاي (p_next_route)
create or replace function public.finish_step(p_step uuid, p_check jsonb default null, p_next_route uuid default null) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  s public.repair_steps;
  r public.routes;
  nxt public.repair_steps;
  ck uuid;
begin
  select * into s from public.repair_steps where id = p_step and shop_id = public.current_shop_id() for update;
  if not found then raise exception 'E_NOT_FOUND'; end if;
  if public.current_app_role() = 'technician' and s.technician_id is distinct from auth.uid() then raise exception 'E_FORBIDDEN'; end if;
  if public.current_app_role() not in ('owner', 'technician') then raise exception 'E_FORBIDDEN'; end if;
  if s.status <> 'active' then raise exception 'E_BAD_TRANSITION'; end if;
  if (select status from public.devices where id = s.device_id) = 'awaiting_approval' then raise exception 'E_AWAITING_APPROVAL'; end if;
  select * into r from public.routes where id = s.route_id;
  select * into nxt from public.repair_steps where device_id = s.device_id and step_no > s.step_no and status = 'pending' order by step_no limit 1;

  if nxt.id is null and coalesce(r.diagnose, false) then
    -- الفحص خلص: الفني بيحدد المسار
    if p_next_route is null then raise exception 'E_ROUTE_REQUIRED'; end if;
    update public.repair_steps set status = 'done', finished_at = now() where id = s.id;
    perform public.set_route(s.device_id, p_next_route);
    select * into nxt from public.repair_steps where device_id = s.device_id and status = 'pending' order by step_no limit 1;
    return jsonb_build_object('next_step', nxt.id, 'next_tech', nxt.technician_id, 'ready', false);
  end if;

  if nxt.id is null then
    -- آخر خطوة: الفحص النهائي بنفس قائمة الفحص السريع
    if p_check is null or jsonb_typeof(p_check) <> 'object' or p_check = '{}'::jsonb then raise exception 'E_FINAL_CHECK_REQUIRED'; end if;
    select id into ck from public.device_checks where device_id = s.device_id and stage = 'delivery' and deleted_at is null;
    if ck is null then
      insert into public.device_checks(id, shop_id, device_id, stage, items) values (gen_random_uuid(), s.shop_id, s.device_id, 'delivery', p_check);
    else
      update public.device_checks set items = p_check where id = ck;
    end if;
    update public.repair_steps set status = 'done', finished_at = now() where id = s.id;
    perform public.walk_status(s.device_id, 'ready');
    return jsonb_build_object('next_step', null, 'ready', true);
  end if;

  update public.repair_steps set status = 'done', finished_at = now() where id = s.id;
  if nxt.technician_id is null then
    update public.repair_steps set technician_id = public.pick_technician(s.device_id, nxt.specialty_id) where id = nxt.id returning * into nxt;
  end if;
  return jsonb_build_object('next_step', nxt.id, 'next_tech', nxt.technician_id, 'ready', false);
end $$;

-- تحويل خطوة لفني تاني (صاحب المحل والاستقبال)
create or replace function public.reassign_step(p_step uuid, p_tech uuid) returns void
language plpgsql security definer set search_path = public as $$
declare s public.repair_steps;
begin
  perform public.ledger_require(array['owner', 'reception']::public.app_role[]);
  select * into s from public.repair_steps where id = p_step and shop_id = public.current_shop_id() for update;
  if not found or s.status not in ('pending', 'active') then raise exception 'E_NOT_FOUND'; end if;
  if p_tech is not null and not exists (select 1 from public.profiles where id = p_tech and shop_id = s.shop_id and role = 'technician' and deleted_at is null) then raise exception 'E_NOT_FOUND'; end if;
  update public.repair_steps set technician_id = p_tech, status = case when status = 'active' then 'pending' else status end, started_at = null where id = s.id;
end $$;

-- لما الجهاز يتسجل مرتجع ضمان: أولوية ضمان، وبيرجع لنفس الفني اللي قفله، وبيتسجل عليه كمرتجع
create or replace function public.tg_device_warranty_tech() returns trigger
language plpgsql security definer set search_path = public as $$
declare t uuid; sp uuid; n int;
begin
  if new.status = 'warranty_return' and old.status is distinct from 'warranty_return' then
    select s.technician_id, s.specialty_id into t, sp from public.repair_steps s
     where s.device_id = new.id and s.status = 'done' and s.technician_id is not null order by s.step_no desc limit 1;
    perform set_config('warsha.routing', 'on', true);
    update public.devices set priority = 'warranty', return_of_tech = t where id = new.id;
    perform set_config('warsha.routing', 'off', true);
    if sp is not null then
      select coalesce(max(step_no), 0) into n from public.repair_steps where device_id = new.id;
      insert into public.repair_steps(shop_id, device_id, route_id, step_no, specialty_id, technician_id)
      values (new.shop_id, new.id, new.route_id, n + 1, sp, t);
    end if;
  end if;
  return null;
end $$;
create trigger zz_warranty_tech after update of status on public.devices for each row execute function public.tg_device_warranty_tech();

-- ============================================================
-- قائمة الفني: أجهزته بالأولوية ثم بتاريخ الاستلام، والمتأخر متعلّم (من غير أسعار ولا بيانات عملاء)
-- ============================================================
create or replace function public.my_queue()
returns table(step_id uuid, device_id uuid, order_no text, brand text, model text, issue text, priority text, status public.device_status,
              received_at timestamptz, est_minutes integer, step_no integer, steps_total integer, specialty_id uuid, step_status text,
              started_at timestamptz, diagnose boolean, late boolean, is_return boolean)
language plpgsql stable security definer set search_path = public as $$
#variable_conflict use_column
begin
  if public.current_app_role() is null then raise exception 'E_FORBIDDEN'; end if;
  return query
  select s.id, d.id, d.order_no, d.brand, d.model, d.issue, d.priority, d.status, d.received_at, d.est_minutes, s.step_no,
         (select count(*)::int from public.repair_steps x where x.device_id = d.id and x.status <> 'skipped'),
         s.specialty_id, s.status, s.started_at, coalesce(r.diagnose, false),
         (d.est_minutes is not null and now() > d.received_at + make_interval(mins => d.est_minutes)) or now() - d.received_at > interval '7 days',
         d.return_of_tech is not null
  from public.repair_steps s
  join public.devices d on d.id = s.device_id and d.deleted_at is null
  left join public.routes r on r.id = s.route_id
  where s.shop_id = public.current_shop_id() and s.status in ('pending', 'active')
    and (s.technician_id = auth.uid()
         or (s.technician_id is null and public.tech_has_specialty(auth.uid(), s.specialty_id)))
    and not exists (select 1 from public.repair_steps p where p.device_id = s.device_id and p.step_no < s.step_no and p.status in ('pending', 'active'))
  order by case d.priority when 'urgent' then 0 when 'warranty' then 1 else 2 end, d.received_at;
end $$;

-- ============================================================
-- تقدير الوقت: متوسط الوقت الفعلي لنفس (نوع الجهاز + نوع العطل). لو 5 أجهزة أو أكتر بيقترح، لو أقل بيرجع null
-- ============================================================
create or replace function public.estimate_minutes(p_brand text, p_route uuid) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare n int; avgm numeric;
begin
  if public.current_app_role() is null then raise exception 'E_FORBIDDEN'; end if;
  select count(*), avg(mins) into n, avgm from (
    select extract(epoch from max(s.finished_at) - min(s.started_at)) / 60 as mins
    from public.devices d join public.repair_steps s on s.device_id = d.id and s.status = 'done'
    where d.shop_id = public.current_shop_id() and d.route_id = p_route and lower(d.brand) = lower(trim(p_brand)) and d.return_of_tech is null
      and not exists (select 1 from public.repair_steps o where o.device_id = d.id and o.status in ('pending', 'active'))
    group by d.id
  ) t where mins > 0;
  return jsonb_build_object('n', n, 'minutes', case when n >= 5 then greatest(1, round(avgm))::int end);
end $$;

-- الفني الحالي للجهاز (الاسم الأول): للرسايل باسم الفني
create or replace function public.device_tech_name(p_device uuid) returns text
language sql stable security definer set search_path = public as $$
  select split_part(p.full_name, ' ', 1) from public.repair_steps s join public.profiles p on p.id = s.technician_id
  where s.device_id = p_device and s.shop_id = public.current_shop_id() and s.status in ('active', 'pending', 'done')
  order by case s.status when 'active' then 0 when 'pending' then 1 else 2 end, s.step_no desc limit 1
$$;

-- ============================================================
-- التقارير (صاحب المحل)
-- ============================================================
-- أداء كل فني: الأجهزة اللي قفلها، ومتوسط وقت الخطوة، والمرتجعات ونسبتها، والإيراد اللي جابه (الأجهزة اللي قفلها واتسلّمت)
create or replace function public.tech_report(p_from timestamptz, p_to timestamptz)
returns table(tech_id uuid, name text, devices integer, steps integer, avg_minutes integer, returns integer, return_rate integer, revenue bigint)
language plpgsql stable security definer set search_path = public as $$
#variable_conflict use_column
declare s uuid := public.current_shop_id();
begin
  perform public.ledger_require(array['owner']::public.app_role[]);
  return query
  with closed as (  -- آخر خطوة "تمت" في كل جهاز اتقفل في الفترة = الفني اللي قفله
    select distinct on (x.device_id) x.device_id, x.technician_id, x.finished_at
    from public.repair_steps x where x.shop_id = s and x.status = 'done' and x.technician_id is not null
    order by x.device_id, x.step_no desc
  )
  select p.id, p.full_name,
    (select count(*)::int from closed c where c.technician_id = p.id and c.finished_at >= p_from and c.finished_at < p_to),
    (select count(*)::int from public.repair_steps x where x.technician_id = p.id and x.status = 'done' and x.finished_at >= p_from and x.finished_at < p_to),
    (select round(avg(extract(epoch from x.finished_at - x.started_at) / 60))::int from public.repair_steps x
      where x.technician_id = p.id and x.status = 'done' and x.started_at is not null and x.finished_at >= p_from and x.finished_at < p_to),
    (select count(*)::int from public.devices d where d.return_of_tech = p.id and d.updated_at >= p_from and d.updated_at < p_to),
    case when (select count(*) from closed c where c.technician_id = p.id) = 0 then 0
         else ((select count(*) from public.devices d where d.return_of_tech = p.id) * 100 / (select count(*) from closed c where c.technician_id = p.id))::int end,
    -- الإيراد من قيود التسليم نفسها (بتفضل حتى لو الجهاز رجع ضمان بعد كده)
    (select coalesce(sum(l.debit), 0)::bigint from closed c
       join public.journal_entries e on e.source_type = 'delivery' and e.source_id = c.device_id and e.occurred_at >= p_from and e.occurred_at < p_to
         and not exists (select 1 from public.journal_entries r where r.reverses_id = e.id)
       join public.journal_lines l on l.entry_id = e.id and l.debit > 0
     where c.technician_id = p.id)
  from public.profiles p
  where p.shop_id = s and p.role = 'technician' and p.deleted_at is null
  order by 3 desc, 2;
end $$;

-- ربحية كل نوع عطل: الأجهزة المسلّمة، والإيراد، وتكلفة القطع، والربح
create or replace function public.issue_report(p_from timestamptz, p_to timestamptz)
returns table(route_id uuid, code text, name text, devices integer, revenue bigint, parts bigint, profit bigint)
language plpgsql stable security definer set search_path = public as $$
#variable_conflict use_column
begin
  perform public.ledger_require(array['owner']::public.app_role[]);
  return query
  select r.id, r.code, r.name, count(d.id)::int,
         coalesce(sum(dc.final_cost), 0)::bigint,
         coalesce(sum((select -sum(m.value) from public.stock_moves m join public.journal_entries e on e.id = m.entry_id where e.device_id = d.id and e.source_type in ('part_use', 'reversal'))), 0)::bigint,
         (coalesce(sum(dc.final_cost), 0) - coalesce(sum((select -sum(m.value) from public.stock_moves m join public.journal_entries e on e.id = m.entry_id where e.device_id = d.id and e.source_type in ('part_use', 'reversal'))), 0))::bigint
  from public.devices d
  left join public.routes r on r.id = d.route_id
  left join public.device_costs dc on dc.device_id = d.id and dc.deleted_at is null
  where d.shop_id = public.current_shop_id() and d.status = 'delivered' and d.delivered_at >= p_from and d.delivered_at < p_to
  group by r.id, r.code, r.name
  order by 7 desc;
end $$;

-- أكتر الأعطال والموديلات اللي دخلت (للاستقبال كمان، من غير فلوس)
create or replace function public.models_report(p_from timestamptz, p_to timestamptz)
returns table(kind text, label text, devices integer)
language plpgsql stable security definer set search_path = public as $$
#variable_conflict use_column
begin
  perform public.ledger_require(array['owner', 'reception']::public.app_role[]);
  return query
  (select 'model'::text, d.brand || ' ' || d.model, count(*)::int from public.devices d
    where d.shop_id = public.current_shop_id() and d.received_at >= p_from and d.received_at < p_to and d.deleted_at is null
    group by d.brand, d.model order by 3 desc limit 10)
  union all
  (select 'route'::text, coalesce(r.code, r.name, '-'), count(*)::int from public.devices d left join public.routes r on r.id = d.route_id
    where d.shop_id = public.current_shop_id() and d.received_at >= p_from and d.received_at < p_to and d.deleted_at is null
    group by r.code, r.name order by 3 desc limit 10);
end $$;

-- ============================================================
-- الصلاحيات للدوال
-- ============================================================
do $$
declare f text;
begin
  foreach f in array array['tech_can_see(uuid)', 'pick_technician(uuid, uuid)', 'tech_has_specialty(uuid, uuid)'] loop
    execute format('revoke execute on function public.%s from public, anon, authenticated', f);
  end loop;
  foreach f in array array['detect_route(text)', 'set_route(uuid, uuid)', 'start_step(uuid)', 'finish_step(uuid, jsonb, uuid)', 'reassign_step(uuid, uuid)',
                           'my_queue()', 'estimate_minutes(text, uuid)', 'device_tech_name(uuid)', 'tech_report(timestamptz, timestamptz)',
                           'issue_report(timestamptz, timestamptz)', 'models_report(timestamptz, timestamptz)'] loop
    execute format('revoke execute on function public.%s from public, anon', f);
    execute format('grant execute on function public.%s to authenticated', f);
  end loop;
end $$;
-- السياسة بتنادي tech_can_see بصلاحيات المستخدم
grant execute on function public.tech_can_see(uuid) to authenticated;
grant execute on function public.tech_has_specialty(uuid, uuid) to authenticated;

-- تحديث لحظي لقائمة الفني
do $$
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    begin
      alter publication supabase_realtime add table public.repair_steps;
    exception when duplicate_object then null;
    end;
  end if;
end $$;

-- ============================== 0015_offline_backup.sql ==============================
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

-- ============================== 0016_shop_identity.sql ==============================
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

-- ============================== 0017_growth.sql ==============================
-- المرحلة 6: النمو
--
-- 1) دور "مدير التسويق" (marketing): بيشوف فيديوهات الإصلاح بس. مش معدود موظف في المحل في أي صلاحية تانية
--    (current_shop_id بيرجّع فاضي ليه)، فما بيشوفش أجهزة ولا عملاء ولا فلوس.
-- 2) فيديوهات الإصلاح: الفني بيرفع، ومدير التسويق بيراجع، والمقبول بيزوّد نقاط الفني. من غير بيانات العميل.
-- 3) تقييم العميل للجهاز بعد التسليم (من صفحة التتبع)، وبيتحسب للفني اللي قفله.
-- 4) مجتمع الفنيين: مشترك بين المحلات (مقصود)، ومن غير بيانات عملاء: أي نص فيه رقم موبايل أو IMEI بيترفض. والمشرف بيخفي.
-- 5) الخطط والحدود: كل محل على خطة (مجانية افتراضيًا)، والحد بيتطبق في قاعدة البيانات.
-- 6) لوحة المشرف (صاحب المنصة بس): المحلات واستخدامها من غير بيانات عملاء، وتغيير الخطة، والإيقاف، ومراجعة المجتمع.
-- 7) عداد استخدام المساعد الذكي (الحد اليومي من الخطة). الأسئلة نفسها ما بتتخزنش.
--
-- ملحوظة: القيمة الجديدة في enum بتتستخدم كنص (::text) في الملف ده، عشان الملف يشتغل في transaction واحدة.

alter type public.app_role add value if not exists 'marketing';

-- ============================================================
-- الخطط
-- ============================================================
create table public.plans (
  code text primary key,
  max_devices_month integer,  -- null = من غير حد
  max_staff integer,
  ai_daily integer not null default 0,
  max_videos integer,
  sort integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);
insert into public.plans(code, max_devices_month, max_staff, ai_daily, max_videos, sort) values
  ('free', 300, 5, 20, 50, 1),
  ('pro', null, null, 200, null, 2)
on conflict (code) do nothing;
alter table public.plans enable row level security;
revoke all on public.plans from public, anon, authenticated;
create policy plans_read on public.plans for select to authenticated using (true);
grant select on public.plans to authenticated;

alter table public.shops add column if not exists plan_code text not null default 'free' references public.plans(code);
alter table public.shops add column if not exists suspended_at timestamptz;

-- ============================================================
-- المشرفين (صاحب المنصة)
-- ============================================================
create table public.platform_admins (
  user_id uuid primary key references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);
alter table public.platform_admins enable row level security;
revoke all on public.platform_admins from public, anon, authenticated;

create or replace function public.is_platform_admin() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.platform_admins where user_id = auth.uid() and deleted_at is null)
$$;

-- ============================================================
-- المحل الحالي: مدير التسويق والمحل الموقوف ملهمش محل في الصلاحيات العادية
-- ============================================================
create or replace function public.current_shop_id() returns uuid
language sql stable security definer set search_path = public as $$
  select p.shop_id from public.profiles p join public.shops s on s.id = p.shop_id
  where p.id = auth.uid() and p.deleted_at is null and p.role::text <> 'marketing' and s.suspended_at is null
$$;
-- محل مدير التسويق (للفيديوهات بس)
create or replace function public.marketing_shop_id() returns uuid
language sql stable security definer set search_path = public as $$
  select p.shop_id from public.profiles p join public.shops s on s.id = p.shop_id
  where p.id = auth.uid() and p.deleted_at is null and p.role::text = 'marketing' and s.suspended_at is null
$$;
-- أي حد في المحل (لأي دور، ومنهم التسويق) — للفيديوهات والمجتمع
create or replace function public.member_shop_id() returns uuid
language sql stable security definer set search_path = public as $$
  select p.shop_id from public.profiles p join public.shops s on s.id = p.shop_id
  where p.id = auth.uid() and p.deleted_at is null and s.suspended_at is null
$$;
create or replace function public.member_role() returns text
language sql stable security definer set search_path = public as $$
  select p.role::text from public.profiles p where p.id = auth.uid() and p.deleted_at is null
$$;

-- الصف الجديد بياخد محل المستخدم (لأي دور، ومنهم التسويق). الصلاحيات (RLS) هي اللي بتمنع التسويق من الجداول
create or replace function public.tg_force_shop_id() returns trigger
language plpgsql security definer set search_path = public as $$
declare s uuid := coalesce(public.current_shop_id(), public.member_shop_id());
begin
  if current_setting('warsha.system', true) = 'on' then
    return new;
  end if;
  if s is null then
    if tg_op = 'UPDATE' and auth.uid() is null and new.shop_id = old.shop_id then
      return new;
    end if;
    raise exception 'E_NO_SHOP';
  end if;
  if tg_op = 'INSERT' then
    new.shop_id := s;
  elsif new.shop_id is distinct from old.shop_id then
    raise exception 'E_SHOP_CHANGE';
  end if;
  return new;
end $$;

-- ============================================================
-- حدود الخطة
-- ============================================================
create or replace function public.shop_plan(p_shop uuid) returns public.plans
language sql stable security definer set search_path = public as $$
  select pl.* from public.shops s join public.plans pl on pl.code = s.plan_code where s.id = p_shop
$$;

create or replace function public.tg_plan_devices() returns trigger
language plpgsql security definer set search_path = public as $$
declare pl public.plans := public.shop_plan(new.shop_id); n int;
begin
  if pl.max_devices_month is not null then
    select count(*) into n from public.devices
     where shop_id = new.shop_id and received_at >= date_trunc('month', now() at time zone 'Africa/Cairo') at time zone 'Africa/Cairo';
    if n >= pl.max_devices_month then raise exception 'E_PLAN_LIMIT'; end if;
  end if;
  return new;
end $$;
create trigger zz_plan_devices before insert on public.devices for each row execute function public.tg_plan_devices();

create or replace function public.tg_plan_staff() returns trigger
language plpgsql security definer set search_path = public as $$
declare pl public.plans := public.shop_plan(new.shop_id); n int;
begin
  if pl.max_staff is not null then
    select (select count(*) from public.profiles where shop_id = new.shop_id and deleted_at is null)
         + (select count(*) from public.staff_invites where shop_id = new.shop_id and accepted_at is null and deleted_at is null) into n;
    if n >= pl.max_staff then raise exception 'E_PLAN_LIMIT'; end if;
  end if;
  return new;
end $$;
create trigger zz_plan_staff before insert on public.staff_invites for each row execute function public.tg_plan_staff();

-- استخدام المحل وحدود خطته (صاحب المحل)
create or replace function public.plan_usage() returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare s uuid := public.current_shop_id(); pl public.plans;
begin
  if public.current_app_role() is distinct from 'owner' then raise exception 'E_FORBIDDEN'; end if;
  pl := public.shop_plan(s);
  return jsonb_build_object(
    'plan', pl.code, 'max_devices_month', pl.max_devices_month, 'max_staff', pl.max_staff, 'ai_daily', pl.ai_daily, 'max_videos', pl.max_videos,
    'devices_month', (select count(*) from public.devices where shop_id = s and received_at >= date_trunc('month', now() at time zone 'Africa/Cairo') at time zone 'Africa/Cairo'),
    'staff', (select count(*) from public.profiles where shop_id = s and deleted_at is null),
    'ai_today', (select count(*) from public.ai_usage where shop_id = s and created_at >= date_trunc('day', now() at time zone 'Africa/Cairo') at time zone 'Africa/Cairo'),
    'videos', (select count(*) from public.repair_videos where shop_id = s and deleted_at is null));
end $$;

-- ============================================================
-- فيديوهات الإصلاح
-- ============================================================
create table public.repair_videos (
  id uuid primary key,
  shop_id uuid not null references public.shops(id),
  technician_id uuid not null references public.profiles(id),
  device_id uuid references public.devices(id),
  title text not null check (length(trim(title)) between 1 and 120),
  description text check (description is null or length(description) <= 1000),
  storage_path text not null,
  status text not null default 'pending' check (status in ('pending', 'approved', 'rejected')),
  points integer not null default 0 check (points between 0 and 100),
  review_note text check (review_note is null or length(review_note) <= 500),
  reviewed_by uuid references public.profiles(id),
  reviewed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);
alter table public.repair_videos enable row level security;
revoke all on public.repair_videos from public, anon, authenticated;
-- الفني بيشوف فيديوهاته، وصاحب المحل ومدير التسويق بيشوفوا فيديوهات المحل كلها
create policy videos_select on public.repair_videos for select to authenticated using (
  shop_id = public.member_shop_id() and (technician_id = auth.uid() or public.member_role() in ('owner', 'marketing')));
grant select on public.repair_videos to authenticated;
create trigger set_updated_at before update on public.repair_videos for each row execute function public.tg_set_updated_at();
create trigger block_delete before delete on public.repair_videos for each row execute function public.tg_block_delete();
create trigger zz_audit after insert or update on public.repair_videos for each row execute function public.tg_audit();

-- الفني (أو صاحب المحل) بيضيف فيديو بعد ما يرفعه في Storage
create or replace function public.add_video(p_id uuid, p_title text, p_path text, p_device uuid default null, p_description text default null) returns uuid
language plpgsql security definer set search_path = public as $$
declare s uuid := public.member_shop_id(); pl public.plans;
begin
  if public.member_role() not in ('technician', 'owner') then raise exception 'E_FORBIDDEN'; end if;
  if p_path is null or split_part(p_path, '/', 1) <> s::text then raise exception 'E_BAD_INPUT'; end if;
  if p_device is not null and not exists (select 1 from public.devices where id = p_device and shop_id = s) then raise exception 'E_NOT_FOUND'; end if;
  if public.has_private_data(coalesce(p_title, '') || ' ' || coalesce(p_description, '')) then raise exception 'E_PRIVATE_DATA'; end if;
  pl := public.shop_plan(s);
  if pl.max_videos is not null and (select count(*) from public.repair_videos where shop_id = s and deleted_at is null) >= pl.max_videos then raise exception 'E_PLAN_LIMIT'; end if;
  insert into public.repair_videos(id, shop_id, technician_id, device_id, title, description, storage_path)
  values (p_id, s, auth.uid(), p_device, trim(p_title), nullif(trim(p_description), ''), p_path)
  on conflict (id) do nothing;
  return p_id;
end $$;

-- مدير التسويق (أو صاحب المحل) بيراجع: موافقة بنقاط للفني، أو رفض
create or replace function public.review_video(p_video uuid, p_approve boolean, p_points integer default 10, p_note text default null) returns void
language plpgsql security definer set search_path = public as $$
declare v public.repair_videos;
begin
  if public.member_role() not in ('marketing', 'owner') then raise exception 'E_FORBIDDEN'; end if;
  select * into v from public.repair_videos where id = p_video and shop_id = public.member_shop_id() and deleted_at is null for update;
  if not found then raise exception 'E_NOT_FOUND'; end if;
  if p_points < 0 or p_points > 100 then raise exception 'E_BAD_INPUT'; end if;
  update public.repair_videos set status = case when p_approve then 'approved' else 'rejected' end,
    points = case when p_approve then p_points else 0 end, review_note = nullif(trim(p_note), ''), reviewed_by = auth.uid(), reviewed_at = now()
  where id = v.id;
end $$;

-- Storage للفيديوهات: خاص بكل محل
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('repair-videos', 'repair-videos', false, 104857600, array['video/mp4', 'video/webm', 'video/quicktime'])
on conflict (id) do nothing;
create policy videos_upload on storage.objects for insert to authenticated
  with check (bucket_id = 'repair-videos' and (storage.foldername(name))[1] = public.member_shop_id()::text and public.member_role() in ('technician', 'owner'));
create policy videos_read on storage.objects for select to authenticated
  using (bucket_id = 'repair-videos' and (storage.foldername(name))[1] = public.member_shop_id()::text and public.member_role() in ('technician', 'owner', 'marketing'));

-- ============================================================
-- تقييمات العملاء
-- ============================================================
create table public.device_ratings (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references public.shops(id),
  device_id uuid not null unique references public.devices(id),
  technician_id uuid references public.profiles(id),
  stars integer not null check (stars between 1 and 5),
  comment text check (comment is null or length(comment) <= 500),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);
alter table public.device_ratings enable row level security;
revoke all on public.device_ratings from public, anon, authenticated;
create policy ratings_select on public.device_ratings for select to authenticated using (shop_id = public.current_shop_id() and public.current_app_role() in ('owner', 'reception'));
grant select on public.device_ratings to authenticated;
create trigger ratings_immutable before update or delete on public.device_ratings for each row execute function public.tg_ledger_immutable();

-- حالة التقييم في صفحة التتبع (بالرمز السري بس)
create or replace function public.rating_state(p_token text) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare d public.devices;
begin
  select * into d from public.devices where tracking_token = p_token and deleted_at is null;
  if not found then return jsonb_build_object('can_rate', false); end if;
  return jsonb_build_object('can_rate', d.status = 'delivered' and not exists (select 1 from public.device_ratings r where r.device_id = d.id),
                            'stars', (select stars from public.device_ratings r where r.device_id = d.id));
end $$;

-- العميل بيقيّم مرة واحدة بعد التسليم. التقييم بيتحسب للفني اللي قفل الجهاز
create or replace function public.rate_device(p_token text, p_stars integer, p_comment text default null) returns void
language plpgsql security definer set search_path = public as $$
declare d public.devices; k text := public.tracking_guard(null); t uuid;
begin
  if p_stars is null or p_stars < 1 or p_stars > 5 then raise exception 'E_BAD_INPUT'; end if;
  select * into d from public.devices where tracking_token = p_token and deleted_at is null;
  if not found then
    insert into public.tracking_attempts(client_key, order_no, success) values (k, null, false);
    return;
  end if;
  if d.status <> 'delivered' then raise exception 'E_BAD_TRANSITION'; end if;
  if exists (select 1 from public.device_ratings where device_id = d.id) then raise exception 'E_ALREADY_RATED'; end if;
  select s.technician_id into t from public.repair_steps s where s.device_id = d.id and s.status = 'done' and s.technician_id is not null order by s.step_no desc limit 1;
  insert into public.device_ratings(shop_id, device_id, technician_id, stars, comment)
  values (d.shop_id, d.id, t, p_stars, nullif(trim(left(p_comment, 500)), ''));
end $$;

-- ============================================================
-- المجتمع (مشترك بين المحلات، ومن غير بيانات عملاء)
-- ============================================================
-- نص فيه رقم موبايل أو IMEI أو أي رقم طويل = ممكن يكون بيانات عميل
create or replace function public.has_private_data(p text) returns boolean
language sql immutable as $$
  select coalesce(p, '') ~ '(\+?\d[\d\s-]{7,}\d)' or coalesce(p, '') ~ '[٠-٩]{8,}'
$$;

create table public.community_posts (
  id uuid primary key,
  shop_id uuid not null references public.shops(id),  -- محل الكاتب (المنشور نفسه مشترك)
  author_id uuid not null references public.profiles(id),
  parent_id uuid references public.community_posts(id), -- رد على منشور
  title text check (title is null or length(title) between 1 and 160),
  body text not null check (length(trim(body)) between 1 and 4000),
  tags text[] not null default '{}',
  hidden_at timestamptz,
  hidden_by uuid,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);
create index community_posts_parent on public.community_posts(parent_id, created_at);
alter table public.community_posts enable row level security;
revoke all on public.community_posts from public, anon, authenticated;
create policy community_select on public.community_posts for select to authenticated using (
  deleted_at is null and (hidden_at is null or author_id = auth.uid() or public.is_platform_admin()) and public.member_shop_id() is not null);
grant select on public.community_posts to authenticated;
create trigger set_updated_at before update on public.community_posts for each row execute function public.tg_set_updated_at();
create trigger block_delete before delete on public.community_posts for each row execute function public.tg_block_delete();

create table public.community_reports (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references public.shops(id),
  post_id uuid not null references public.community_posts(id),
  reporter_id uuid not null references public.profiles(id),
  reason text check (reason is null or length(reason) <= 300),
  resolved_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  unique (post_id, reporter_id)
);
alter table public.community_reports enable row level security;
revoke all on public.community_reports from public, anon, authenticated;

create or replace function public.community_post(p_id uuid, p_body text, p_title text default null, p_parent uuid default null, p_tags text[] default '{}') returns uuid
language plpgsql security definer set search_path = public as $$
declare s uuid := public.member_shop_id();
begin
  if s is null or public.member_role() = 'marketing' then raise exception 'E_FORBIDDEN'; end if;
  if public.has_private_data(coalesce(p_title, '') || ' ' || coalesce(p_body, '')) then raise exception 'E_PRIVATE_DATA'; end if;
  if p_parent is not null and not exists (select 1 from public.community_posts where id = p_parent and parent_id is null and deleted_at is null and hidden_at is null) then
    raise exception 'E_NOT_FOUND';
  end if;
  insert into public.community_posts(id, shop_id, author_id, parent_id, title, body, tags)
  values (p_id, s, auth.uid(), p_parent, case when p_parent is null then nullif(trim(p_title), '') end, trim(p_body), coalesce(p_tags, '{}'))
  on conflict (id) do nothing;
  return p_id;
end $$;

create or replace function public.community_report(p_post uuid, p_reason text default null) returns void
language plpgsql security definer set search_path = public as $$
begin
  if public.member_shop_id() is null then raise exception 'E_FORBIDDEN'; end if;
  insert into public.community_reports(shop_id, post_id, reporter_id, reason) values (public.member_shop_id(), p_post, auth.uid(), nullif(trim(p_reason), ''))
  on conflict (post_id, reporter_id) do nothing;
end $$;

-- المنشورات مع اسم الكاتب الأول بس واسم محله (من غير أي بيانات عملاء)
create or replace function public.community_feed(p_parent uuid default null, p_limit integer default 50)
returns table(id uuid, parent_id uuid, title text, body text, tags text[], author text, shop text, created_at timestamptz, replies integer, mine boolean, hidden boolean)
language plpgsql stable security definer set search_path = public as $$
#variable_conflict use_column
begin
  if public.member_shop_id() is null then raise exception 'E_FORBIDDEN'; end if;
  return query
  select c.id, c.parent_id, c.title, c.body, c.tags, split_part(p.full_name, ' ', 1), s.name, c.created_at,
         (select count(*)::int from public.community_posts r where r.parent_id = c.id and r.deleted_at is null and r.hidden_at is null),
         c.author_id = auth.uid(), c.hidden_at is not null
  from public.community_posts c join public.profiles p on p.id = c.author_id join public.shops s on s.id = c.shop_id
  where c.deleted_at is null and (c.hidden_at is null or c.author_id = auth.uid() or public.is_platform_admin())
    and ((p_parent is null and c.parent_id is null) or c.parent_id = p_parent or (p_parent is not null and c.id = p_parent))
  order by case when c.id = p_parent then 0 else 1 end, c.created_at desc
  limit least(greatest(p_limit, 1), 200);
end $$;

-- ============================================================
-- المساعد الذكي: عداد بس (الأسئلة ما بتتخزنش)
-- ============================================================
create table public.ai_usage (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references public.shops(id),
  user_id uuid not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);
create index ai_usage_shop_time on public.ai_usage(shop_id, created_at);
alter table public.ai_usage enable row level security;
revoke all on public.ai_usage from public, anon, authenticated;

-- بتتنادى من الـ Edge Function قبل أي سؤال: بتسجل الاستخدام وبترفض لو الحد اليومي خلص
create or replace function public.ai_take() returns jsonb
language plpgsql security definer set search_path = public as $$
declare s uuid := public.member_shop_id(); pl public.plans; n int;
begin
  if s is null or public.member_role() not in ('owner', 'reception', 'technician') then raise exception 'E_FORBIDDEN'; end if;
  pl := public.shop_plan(s);
  select count(*) into n from public.ai_usage where shop_id = s and created_at >= date_trunc('day', now() at time zone 'Africa/Cairo') at time zone 'Africa/Cairo';
  if n >= pl.ai_daily then raise exception 'E_PLAN_LIMIT'; end if;
  insert into public.ai_usage(shop_id, user_id) values (s, auth.uid());
  return jsonb_build_object('left', pl.ai_daily - n - 1);
end $$;

-- ============================================================
-- تقرير الفنيين: + متوسط التقييم + نقاط الفيديوهات
-- ============================================================
drop function if exists public.tech_report(timestamptz, timestamptz);
create or replace function public.tech_report(p_from timestamptz, p_to timestamptz)
returns table(tech_id uuid, name text, devices integer, steps integer, avg_minutes integer, returns integer, return_rate integer, revenue bigint, rating numeric, ratings integer, points integer)
language plpgsql stable security definer set search_path = public as $$
#variable_conflict use_column
declare s uuid := public.current_shop_id();
begin
  perform public.ledger_require(array['owner']::public.app_role[]);
  return query
  with closed as (
    select distinct on (x.device_id) x.device_id, x.technician_id, x.finished_at
    from public.repair_steps x where x.shop_id = s and x.status = 'done' and x.technician_id is not null
    order by x.device_id, x.step_no desc
  )
  select p.id, p.full_name,
    (select count(*)::int from closed c where c.technician_id = p.id and c.finished_at >= p_from and c.finished_at < p_to),
    (select count(*)::int from public.repair_steps x where x.technician_id = p.id and x.status = 'done' and x.finished_at >= p_from and x.finished_at < p_to),
    (select round(avg(extract(epoch from x.finished_at - x.started_at) / 60))::int from public.repair_steps x
      where x.technician_id = p.id and x.status = 'done' and x.started_at is not null and x.finished_at >= p_from and x.finished_at < p_to),
    (select count(*)::int from public.devices d where d.return_of_tech = p.id and d.updated_at >= p_from and d.updated_at < p_to),
    case when (select count(*) from closed c where c.technician_id = p.id) = 0 then 0
         else ((select count(*) from public.devices d where d.return_of_tech = p.id) * 100 / (select count(*) from closed c where c.technician_id = p.id))::int end,
    (select coalesce(sum(l.debit), 0)::bigint from closed c
       join public.journal_entries e on e.source_type = 'delivery' and e.source_id = c.device_id and e.occurred_at >= p_from and e.occurred_at < p_to
         and not exists (select 1 from public.journal_entries r where r.reverses_id = e.id)
       join public.journal_lines l on l.entry_id = e.id and l.debit > 0
     where c.technician_id = p.id),
    (select round(avg(r.stars)::numeric, 1) from public.device_ratings r where r.technician_id = p.id),
    (select count(*)::int from public.device_ratings r where r.technician_id = p.id),
    (select coalesce(sum(v.points), 0)::int from public.repair_videos v where v.technician_id = p.id and v.status = 'approved' and v.deleted_at is null)
  from public.profiles p
  where p.shop_id = s and p.role = 'technician' and p.deleted_at is null
  order by 3 desc, 2;
end $$;

-- ============================================================
-- لوحة المشرف (صاحب المنصة بس): من غير أي بيانات عملاء
-- ============================================================
create or replace function public.admin_shops()
returns table(id uuid, name text, created_at timestamptz, plan text, suspended boolean, staff integer, devices integer, devices_month integer, last_activity timestamptz)
language plpgsql stable security definer set search_path = public as $$
#variable_conflict use_column
begin
  if not public.is_platform_admin() then raise exception 'E_FORBIDDEN'; end if;
  return query
  select s.id, s.name, s.created_at, s.plan_code, s.suspended_at is not null,
         (select count(*)::int from public.profiles p where p.shop_id = s.id and p.deleted_at is null),
         (select count(*)::int from public.devices d where d.shop_id = s.id and d.deleted_at is null),
         (select count(*)::int from public.devices d where d.shop_id = s.id and d.received_at >= date_trunc('month', now())),
         (select max(a.created_at) from public.audit_log a where a.shop_id = s.id)
  from public.shops s order by s.created_at desc;
end $$;

create or replace function public.admin_set_plan(p_shop uuid, p_plan text) returns void
language plpgsql security definer set search_path = public as $$
begin
  if not public.is_platform_admin() then raise exception 'E_FORBIDDEN'; end if;
  if not exists (select 1 from public.plans where code = p_plan) then raise exception 'E_NOT_FOUND'; end if;
  perform set_config('warsha.system', 'on', true);
  update public.shops set plan_code = p_plan where id = p_shop;
  perform set_config('warsha.system', 'off', true);
  insert into public.audit_log(shop_id, actor_id, action, entity, entity_id, after) values (p_shop, auth.uid(), 'admin_set_plan', 'shops', p_shop, jsonb_build_object('plan', p_plan));
end $$;

create or replace function public.admin_suspend(p_shop uuid, p_suspend boolean) returns void
language plpgsql security definer set search_path = public as $$
begin
  if not public.is_platform_admin() then raise exception 'E_FORBIDDEN'; end if;
  perform set_config('warsha.system', 'on', true);
  update public.shops set suspended_at = case when p_suspend then now() end where id = p_shop;
  perform set_config('warsha.system', 'off', true);
  insert into public.audit_log(shop_id, actor_id, action, entity, entity_id, after) values (p_shop, auth.uid(), case when p_suspend then 'admin_suspend' else 'admin_unsuspend' end, 'shops', p_shop, '{}'::jsonb);
end $$;

create or replace function public.admin_reports()
returns table(post_id uuid, body text, author text, shop text, reports integer, hidden boolean, created_at timestamptz)
language plpgsql stable security definer set search_path = public as $$
#variable_conflict use_column
begin
  if not public.is_platform_admin() then raise exception 'E_FORBIDDEN'; end if;
  return query
  select c.id, c.body, split_part(p.full_name, ' ', 1), s.name, count(r.id)::int, c.hidden_at is not null, c.created_at
  from public.community_reports r join public.community_posts c on c.id = r.post_id
  join public.profiles p on p.id = c.author_id join public.shops s on s.id = c.shop_id
  where r.resolved_at is null
  group by c.id, p.full_name, s.name order by 5 desc, c.created_at desc;
end $$;

create or replace function public.admin_moderate(p_post uuid, p_hide boolean) returns void
language plpgsql security definer set search_path = public as $$
begin
  if not public.is_platform_admin() then raise exception 'E_FORBIDDEN'; end if;
  update public.community_posts set hidden_at = case when p_hide then now() end, hidden_by = case when p_hide then auth.uid() end where id = p_post;
  update public.community_reports set resolved_at = now() where post_id = p_post and resolved_at is null;
end $$;

-- الإيقاف والخطة بيتغيروا من المشرف بس (صاحب المحل ما يقدرش يغيّرهم)
create or replace function public.tg_shop_admin_fields() returns trigger
language plpgsql as $$
begin
  if (new.plan_code is distinct from old.plan_code or new.suspended_at is distinct from old.suspended_at)
     and coalesce(current_setting('warsha.system', true), '') <> 'on' then
    raise exception 'E_FORBIDDEN';
  end if;
  return new;
end $$;
create trigger zy_shop_admin_fields before update on public.shops for each row execute function public.tg_shop_admin_fields();

-- ============================================================
-- الصلاحيات للدوال
-- ============================================================
do $$
declare f text;
begin
  foreach f in array array['marketing_shop_id()', 'shop_plan(uuid)'] loop
    execute format('revoke execute on function public.%s from public, anon, authenticated', f);
  end loop;
  foreach f in array array['is_platform_admin()', 'member_shop_id()', 'member_role()', 'plan_usage()', 'add_video(uuid, text, text, uuid, text)',
                           'review_video(uuid, boolean, integer, text)', 'community_post(uuid, text, text, uuid, text[])', 'community_report(uuid, text)',
                           'community_feed(uuid, integer)', 'ai_take()', 'tech_report(timestamptz, timestamptz)', 'admin_shops()', 'admin_set_plan(uuid, text)',
                           'admin_suspend(uuid, boolean)', 'admin_reports()', 'admin_moderate(uuid, boolean)'] loop
    execute format('revoke execute on function public.%s from public, anon', f);
    execute format('grant execute on function public.%s to authenticated', f);
  end loop;
  -- صفحة التتبع (من غير تسجيل دخول)
  foreach f in array array['rating_state(text)', 'rate_device(text, integer, text)'] loop
    execute format('revoke execute on function public.%s from public', f);
    execute format('grant execute on function public.%s to anon, authenticated', f);
  end loop;
end $$;

-- ============================== 0018_account_state.sql ==============================
-- المرحلة 6 (تكملة): حالة الحساب للواجهة
-- مدير التسويق والمحل الموقوف ملهمش محل في الصلاحيات العادية (current_shop_id فاضي)،
-- فالواجهة محتاجة تعرف هي فين: ملف المستخدم نفسه، واسم المحل، والدور، وهل المحل موقوف، وهل هو مشرف المنصة.
-- الدالة بترجّع بيانات المستخدم نفسه ومحله بس، ومفيهاش أي بيانات أجهزة أو عملاء أو فلوس.
create or replace function public.my_account() returns jsonb
language sql stable security definer set search_path = public as $$
  select jsonb_build_object(
    'profile', (select jsonb_build_object('id', p.id, 'shop_id', p.shop_id, 'full_name', p.full_name, 'email', p.email, 'role', p.role::text, 'deleted_at', p.deleted_at)
                from public.profiles p where p.id = auth.uid()),
    'shop', (select jsonb_build_object('id', s.id, 'name', s.name, 'theme', s.theme, 'locale', s.locale, 'suspended', s.suspended_at is not null)
             from public.profiles p join public.shops s on s.id = p.shop_id where p.id = auth.uid() and p.deleted_at is null),
    'is_admin', public.is_platform_admin())
$$;
revoke all on function public.my_account() from public, anon;
grant execute on function public.my_account() to authenticated;

-- ============================== 0019_extras.sql ==============================
-- ميزات إضافية مجانية (بعد المرحلة 6). كلها إضافة فوق الموجود، ولكل واحدة مفتاح تشغيل في الإعدادات.
-- 1) أعطال جاهزة للاستلام: صاحب المحل بيكتب الأعطال المتكررة وسعرها التقريبي، والاستقبال بيختار بضغطة.
-- 2) مفاتيح التشغيل في shops.extras (صاحب المحل بس بيعدّلها، من سياسة shops_update الموجودة).
-- مفيش أي بيانات عملاء هنا.

alter table public.shops add column if not exists extras jsonb not null
  default '{"quick_issues": true, "day_summary": true, "auto_print": false}'::jsonb;

create table public.issue_presets (
  id uuid primary key,
  shop_id uuid not null references public.shops(id),
  label text not null check (length(trim(label)) between 1 and 60),
  issue text not null check (length(trim(issue)) between 1 and 300),
  est_cost integer check (est_cost is null or est_cost between 0 and 100000000), -- بالقروش
  sort integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);
create index issue_presets_shop on public.issue_presets(shop_id, sort) where deleted_at is null;
alter table public.issue_presets enable row level security;
revoke all on public.issue_presets from public, anon, authenticated;
create trigger set_updated_at before update on public.issue_presets for each row execute function public.tg_set_updated_at();
create trigger block_delete before delete on public.issue_presets for each row execute function public.tg_block_delete();
create trigger a_force_shop_id before insert or update on public.issue_presets for each row execute function public.tg_force_shop_id();
create trigger zz_audit after insert or update on public.issue_presets for each row execute function public.tg_audit();

-- الاستقبال وصاحب المحل بيقروا (الفني مش محتاجها، وفيها أسعار)، وصاحب المحل بس بيكتب
create policy presets_select on public.issue_presets for select to authenticated
  using (shop_id = public.current_shop_id() and public.current_app_role() in ('owner', 'reception'));
create policy presets_insert on public.issue_presets for insert to authenticated
  with check (shop_id = public.current_shop_id() and public.current_app_role() = 'owner');
create policy presets_update on public.issue_presets for update to authenticated
  using (shop_id = public.current_shop_id() and public.current_app_role() = 'owner')
  with check (shop_id = public.current_shop_id());
grant select, insert, update on public.issue_presets to authenticated;

-- النسخة الاحتياطية: كانت ناقصة جداول المرحلة 6 (الفيديوهات والتقييمات)، ودلوقتي فيها كمان الأعطال الجاهزة
create or replace function public.backup_snapshot(p_shop uuid) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare
  res jsonb := jsonb_build_object('format', 'warsha-backup', 'version', 1, 'generated_at', now(), 'shop_id', p_shop);
  t text;
  rows jsonb;
begin
  foreach t in array array['shops', 'shop_branding', 'profiles', 'customers', 'devices', 'device_costs', 'status_log', 'device_notes', 'device_photos', 'device_checks',
                           'quote_decisions', 'message_templates', 'message_log', 'accounts', 'journal_entries', 'journal_lines', 'payments', 'drawer_closings',
                           'suppliers', 'items', 'stock_moves', 'purchases', 'labor_rates', 'specialties', 'staff_specialties', 'routes', 'repair_steps',
                           'repair_videos', 'device_ratings', 'issue_presets', 'audit_log'] loop
    execute format('select coalesce(jsonb_agg(to_jsonb(x)), ''[]''::jsonb) from public.%I x where x.shop_id = $1', t) into rows using p_shop;
    res := res || jsonb_build_object(t, rows);
  end loop;
  select coalesce(jsonb_agg(jsonb_build_object('device_id', device_id, 'kind', kind, 'erased_at', erased_at)), '[]'::jsonb)
    into rows from public.device_passcodes where shop_id = p_shop;
  return res || jsonb_build_object('device_passcodes', rows);
end $$;
revoke execute on function public.backup_snapshot(uuid) from public, anon, authenticated;

-- ============================== 0020_admin_paging.sql ==============================
-- لوحة المشرف: المحلات على صفحات (50 في المرة) وبحث بالاسم، بدل ما كلهم يتجابوا مرة واحدة.
-- ليه: Supabase بيرجّع أقصى 1000 صف في الطلب، وحساب الأجهزة والموظفين لكل المحلات مرة واحدة كان تقيل.
-- الحسابات دلوقتي بتتعمل للمحلات اللي في الصفحة بس. ومفيش أي بيانات عملاء زي الأول.
drop function if exists public.admin_shops();

create or replace function public.admin_shops(p_search text default null, p_limit integer default 50, p_offset integer default 0)
returns table(id uuid, name text, created_at timestamptz, plan text, suspended boolean, staff integer, devices integer, devices_month integer, last_activity timestamptz, total integer)
language plpgsql stable security definer set search_path = public as $$
#variable_conflict use_column
declare q text := nullif(trim(coalesce(p_search, '')), '');
begin
  if not public.is_platform_admin() then raise exception 'E_FORBIDDEN'; end if;
  return query
  with matched as (
    select s.* from public.shops s
    where q is null or s.name ilike '%' || replace(replace(replace(q, '\', '\\'), '%', '\%'), '_', '\_') || '%'
  ), page as (
    select * from matched order by created_at desc, id limit greatest(1, least(coalesce(p_limit, 50), 200)) offset greatest(0, coalesce(p_offset, 0))
  )
  select s.id, s.name, s.created_at, s.plan_code, s.suspended_at is not null,
         (select count(*)::int from public.profiles p where p.shop_id = s.id and p.deleted_at is null),
         (select count(*)::int from public.devices d where d.shop_id = s.id and d.deleted_at is null),
         (select count(*)::int from public.devices d where d.shop_id = s.id and d.received_at >= date_trunc('month', now())),
         (select max(a.created_at) from public.audit_log a where a.shop_id = s.id),
         (select count(*)::int from matched)
  from page s order by s.created_at desc, s.id;
end $$;
revoke execute on function public.admin_shops(text, integer, integer) from public, anon;
grant execute on function public.admin_shops(text, integer, integer) to authenticated;

-- ============================== 0021_spec_rules.sql ==============================
-- استكمال قواعد من المواصفات (مراجعة شاملة 2026-11-07)
-- 1) مدة ضمان لكل نوع عطل (مسار)، ولو مش متحددة بتاخد مدة الضمان بتاعة المحل.
-- 2) حذف (أرشفة) جهاز أو عميل: صاحب المحل بس. ("أي عملية حساسة زي حذف جهاز تحتاج إذن صاحب المحل")
-- 3) خصم كبير: الاستقبال ما يقدرش ينزّل التكلفة عن التقديرية بأكتر من نسبة يحددها صاحب المحل (افتراضي 20%)
--    من غير صاحب المحل. وكل تعديل في الأسعار بيتسجل في سجل النشاط زي الأول.

-- ============================================================
-- 1) الضمان لكل نوع عطل
-- ============================================================
alter table public.routes add column if not exists warranty_days integer check (warranty_days is null or warranty_days between 0 and 3650);

create or replace function public.tg_device_warranty() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if new.status = 'delivered' and old.status is distinct from 'delivered' then
    if new.warranty_days is null then
      -- مدة ضمان نوع العطل (المسار)، وإلا مدة ضمان المحل
      select coalesce(r.warranty_days, s.warranty_days) into new.warranty_days
      from public.shops s left join public.routes r on r.id = new.route_id and r.deleted_at is null
      where s.id = new.shop_id;
    end if;
    new.warranty_until := now() + make_interval(days => coalesce(new.warranty_days, 0));
  end if;
  if new.tracking_token is distinct from old.tracking_token then
    raise exception 'E_RECEIPT_IMMUTABLE';
  end if;
  return new;
end $$;

-- ============================================================
-- 2) الأرشفة (soft delete) لصاحب المحل بس
-- ============================================================
create or replace function public.tg_owner_soft_delete() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if new.deleted_at is distinct from old.deleted_at
     and auth.uid() is not null
     and coalesce(current_setting('warsha.system', true), '') <> 'on'
     and public.current_app_role() is distinct from 'owner' then
    raise exception 'E_OWNER_APPROVAL';
  end if;
  return new;
end $$;
drop trigger if exists a_owner_soft_delete on public.devices;
create trigger a_owner_soft_delete before update on public.devices for each row execute function public.tg_owner_soft_delete();
drop trigger if exists a_owner_soft_delete on public.customers;
create trigger a_owner_soft_delete before update on public.customers for each row execute function public.tg_owner_soft_delete();

-- ============================================================
-- 3) الخصم الكبير محتاج صاحب المحل
-- ============================================================
alter table public.shops add column if not exists max_discount_pct integer not null default 20 check (max_discount_pct between 0 and 100);

create or replace function public.tg_cost_discount() returns trigger
language plpgsql security definer set search_path = public as $$
declare pct integer; est integer;
begin
  if auth.uid() is null or coalesce(current_setting('warsha.system', true), '') = 'on' or public.current_app_role() = 'owner' then
    return new;
  end if;
  select max_discount_pct into pct from public.shops where id = new.shop_id;
  pct := coalesce(pct, 20);
  -- التكلفة التقديرية نفسها ما تنزلش بخصم كبير
  if tg_op = 'UPDATE' and old.estimated_cost > 0 and new.estimated_cost is distinct from old.estimated_cost
     and coalesce(new.estimated_cost, 0)::bigint * 100 < old.estimated_cost::bigint * (100 - pct) then
    raise exception 'E_OWNER_APPROVAL';
  end if;
  -- التكلفة النهائية مقارنة بالتقديرية (أعداد صحيحة بس، من غير كسور)
  est := case when tg_op = 'UPDATE' then coalesce(old.estimated_cost, new.estimated_cost) else new.estimated_cost end;
  if new.final_cost is not null and est > 0
     and (tg_op = 'INSERT' or new.final_cost is distinct from old.final_cost)
     and new.final_cost::bigint * 100 < est::bigint * (100 - pct) then
    raise exception 'E_OWNER_APPROVAL';
  end if;
  return new;
end $$;
drop trigger if exists a_cost_discount on public.device_costs;
create trigger a_cost_discount before insert or update on public.device_costs for each row execute function public.tg_cost_discount();

-- ============================================================
-- 4) تذكيرات تسويقية بموافقة العميل ("صيانة من 6 شهور")
-- ============================================================
alter table public.message_templates drop constraint if exists message_templates_key_check;
alter table public.message_templates add constraint message_templates_key_check
  check (key in ('received', 'status', 'approval', 'ready', 'reminder', 'delivered', 'debt', 'marketing'));

-- العملاء اللي وافقوا على التذكيرات، وآخر جهاز ليهم اتسلّم من 6 شهور أو أكتر (لحد سنة)،
-- وما اتبعتلهمش تذكير تسويقي من وقت التسليم ده. للاستقبال وصاحب المحل بس.
create or replace function public.marketing_due(p_days integer default 180)
returns table(device_id uuid, order_no text, brand text, model text, issue text, delivered_at timestamptz,
              customer_id uuid, customer_name text, phone text, tracking_token text)
language plpgsql stable security definer set search_path = public as $$
#variable_conflict use_column
declare s uuid := public.current_shop_id(); days integer := greatest(30, least(coalesce(p_days, 180), 720));
begin
  if public.current_app_role() not in ('owner', 'reception') then raise exception 'E_FORBIDDEN'; end if;
  return query
  with last_dev as (
    select distinct on (d.customer_id) d.*
    from public.devices d
    where d.shop_id = s and d.deleted_at is null and d.status = 'delivered' and d.delivered_at is not null
    order by d.customer_id, d.delivered_at desc
  )
  select d.id, d.order_no, d.brand, d.model, d.issue, d.delivered_at, c.id, c.name, c.phone, d.tracking_token
  from last_dev d join public.customers c on c.id = d.customer_id and c.deleted_at is null
  where c.marketing_ok
    and d.delivered_at <= now() - make_interval(days => days)
    and d.delivered_at > now() - make_interval(days => days + 365)
    and not exists (select 1 from public.message_log m where m.customer_id = c.id and m.template_key = 'marketing' and m.created_at >= d.delivered_at and m.deleted_at is null)
  order by d.delivered_at
  limit 200;
end $$;
revoke execute on function public.marketing_due(integer) from public, anon;
grant execute on function public.marketing_due(integer) to authenticated;

-- ============================== 0022_security_review.sql ==============================
-- المراجعة الأمنية الشاملة (2026-11-07)
-- حالة التقييم في صفحة التتبع (rating_state) كانت الدالة العامة الوحيدة من غير حد للمحاولات.
-- دلوقتي زي باقي دوال الصفحة العامة: بعد 10 محاولات غلط من نفس الجهاز في 15 دقيقة بتقفل (E_RATE_LIMIT)،
-- والرمز الغلط بيتسجل كمحاولة فاشلة. والنتيجة زي ما هي: هل يقدر يقيّم، والنجوم لو قيّم، ومفيش أي بيانات تانية.
create or replace function public.rating_state(p_token text) returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare d public.devices; k text := public.tracking_guard(null);
begin
  select * into d from public.devices where tracking_token = p_token and deleted_at is null;
  if not found then
    insert into public.tracking_attempts(client_key, order_no, success) values (k, null, false);
    return jsonb_build_object('can_rate', false);
  end if;
  return jsonb_build_object('can_rate', d.status = 'delivered' and not exists (select 1 from public.device_ratings r where r.device_id = d.id),
                            'stars', (select stars from public.device_ratings r where r.device_id = d.id));
end $$;
revoke execute on function public.rating_state(text) from public;
grant execute on function public.rating_state(text) to anon, authenticated;

-- ============================== 0023_restore.sql ==============================
-- 0023: استرجاع نسخة احتياطية لمحل جديد فاضي (بقرار صاحب المشروع 2026-11-07)
--
-- - الاسترجاع لمحل جديد فاضي بس (في نفس مشروع Supabase أو مشروع جديد). ممنوع على محل فيه شغل.
-- - كل صف بياخد id جديد، وكل الروابط بين الجداول بتتظبط على الـ ids الجديدة، فمفيش تعارض مع المحل الأصلي
--   لو لسه موجود في نفس المشروع.
-- - الحسابات والمسارات والتخصصات وقوالب الرسايل اللي اتعملت مع التسجيل بتتطابق بالكود، وبتاخد قيم النسخة.
-- - الموظفين القدام بيرجعوا "موظفين سابقين" (بأساميهم، عشان سجل مين عمل إيه يفضل)، ولازم يتعزموا من جديد.
--   صاحب المحل في النسخة = صاحب المحل اللي بيسترجع.
-- - القيود بترجع زي ما هي (ما بتتعدلش): القيد المتوازن بيتأكد عند الحفظ، ورصيد كل حساب لازم يطابق النسخة
--   بالظبط، وإلا الاسترجاع كله بيتلغي ومحدش بيتغيّر.
-- - مش جوه النسخة أصلًا: ملفات الصور (Storage)، وأسرار أقفال الأجهزة، وحسابات الدخول.

-- علامة الاسترجاع: شغالة جوه restore_backup بس (set_config محلي للـ transaction)
create or replace function public.restoring() returns boolean
language sql stable set search_path = public as $$
  select coalesce(current_setting('warsha.restore', true), '') = 'on'
$$;

-- التريجرات اللي كانت هتغيّر الصفوف الراجعة (رقم الطلب، والحالة، والكاتب، وسجل الحالات، وحد الخطة، وسجل النشاط):
-- نفس تعريفها بالظبط، وزيادة سطر واحد في الأول بيسيب الصف زي ما هو وقت الاسترجاع بس.
CREATE OR REPLACE FUNCTION public.tg_audit()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  act text;
  shop uuid;
begin
  -- وقت الاسترجاع: الصف راجع زي ما هو من النسخة (src: 0023)
  if public.restoring() then return new; end if;
  if tg_op = 'INSERT' then
    act := 'insert';
  elsif new.deleted_at is not null and old.deleted_at is null then
    act := 'soft_delete';
  else
    act := 'update';
  end if;
  shop := coalesce(new.shop_id, old.shop_id);
  -- تحديث بدون أي تغيير حقيقي (غير updated_at) ما يتسجلش
  if tg_op = 'UPDATE' and (to_jsonb(new) - 'updated_at') = (to_jsonb(old) - 'updated_at') then
    return new;
  end if;
  insert into public.audit_log(shop_id, actor_id, action, entity, entity_id, before, after)
  values (
    shop, auth.uid(), act, tg_table_name, new.id,
    case when tg_op = 'UPDATE' then to_jsonb(old) end,
    to_jsonb(new)
  );
  return new;
end $function$;

CREATE OR REPLACE FUNCTION public.tg_check_author()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  -- وقت الاسترجاع: الصف راجع زي ما هو من النسخة (src: 0023)
  if public.restoring() then return new; end if;
  new.checked_by := auth.uid();
  return new;
end $function$;

CREATE OR REPLACE FUNCTION public.tg_note_author()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  -- وقت الاسترجاع: الصف راجع زي ما هو من النسخة (src: 0023)
  if public.restoring() then return new; end if;
  if tg_op = 'INSERT' then
    new.author_id := auth.uid();
  elsif new.body is distinct from old.body or new.author_id is distinct from old.author_id then
    raise exception 'E_NOTE_IMMUTABLE';
  end if;
  return new;
end $function$;

CREATE OR REPLACE FUNCTION public.tg_device_defaults()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  y integer := extract(year from (now() at time zone 'Africa/Cairo'))::integer;
  n integer;
begin
  -- وقت الاسترجاع: الصف راجع زي ما هو من النسخة (src: 0023)
  if public.restoring() then return new; end if;
  insert into public.order_counters(shop_id, year, last_value)
  values (new.shop_id, y, 1)
  on conflict (shop_id, year) do update set last_value = public.order_counters.last_value + 1
  returning last_value into n;
  new.order_no := y::text || '-' || lpad(n::text, 4, '0');
  new.status := 'received';
  new.received_by := auth.uid();
  new.received_at := now();
  new.delivered_at := null;
  return new;
end $function$;

CREATE OR REPLACE FUNCTION public.tg_device_status_log()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  -- وقت الاسترجاع: الصف راجع زي ما هو من النسخة (src: 0023)
  if public.restoring() then return null; end if;
  if tg_op = 'INSERT' then
    insert into public.status_log(shop_id, device_id, old_status, new_status, changed_by)
    values (new.shop_id, new.id, null, new.status, auth.uid());
  elsif new.status is distinct from old.status then
    insert into public.status_log(shop_id, device_id, old_status, new_status, changed_by)
    values (new.shop_id, new.id, old.status, new.status, auth.uid());
  end if;
  return null;
end $function$;

CREATE OR REPLACE FUNCTION public.tg_plan_devices()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare pl public.plans := public.shop_plan(new.shop_id); n int;
begin
  -- وقت الاسترجاع: الصف راجع زي ما هو من النسخة (src: 0023)
  if public.restoring() then return new; end if;
  if pl.max_devices_month is not null then
    select count(*) into n from public.devices
     where shop_id = new.shop_id and received_at >= date_trunc('month', now() at time zone 'Africa/Cairo') at time zone 'Africa/Cairo';
    if n >= pl.max_devices_month then raise exception 'E_PLAN_LIMIT'; end if;
  end if;
  return new;
end $function$;

-- ============================================================
-- الاسترجاع
-- ============================================================
create or replace function public.restore_remap(j jsonb) returns jsonb
language plpgsql stable set search_path = public, pg_temp as $$
declare res jsonb;
begin
  -- أي قيمة uuid ليها id جديد بتتبدل بيه (الـ ids والروابط كلها). جدول _rmap مؤقت جوه restore_backup
  select coalesce(jsonb_object_agg(k, case
      when jsonb_typeof(v) = 'string' and (v #>> '{}') ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
        then coalesce((select to_jsonb(m.new::text) from _rmap m where m.old = (v #>> '{}')::uuid), v)
      else v end), '{}'::jsonb)
    into res
  from jsonb_each(j) e(k, v);
  return res;
end $$;

create or replace function public.restore_backup(p_data jsonb) returns jsonb
-- extensions: فيها gen_random_bytes على Supabase
language plpgsql security definer set search_path = public, extensions, pg_temp as $$
declare
  s uuid := public.current_shop_id();
  me uuid := auth.uid();
  old_shop uuid;
  old_owner uuid;
  sh jsonb;
  t text;
  r jsonb;
  rows jsonb;
  n int;
  bad int;
  counts jsonb := '{}'::jsonb;
  -- بالترتيب ده عشان كل صف يلاقي اللي بيشاور عليه
  tabs text[] := array['profiles', 'shop_branding', 'accounts', 'customers', 'suppliers', 'specialties', 'staff_specialties', 'routes', 'labor_rates',
                       'issue_presets', 'message_templates', 'items', 'devices', 'device_costs', 'status_log', 'device_notes', 'device_checks',
                       'quote_decisions', 'repair_steps', 'repair_videos', 'device_ratings', 'journal_entries', 'journal_lines', 'payments',
                       'purchases', 'stock_moves', 'drawer_closings', 'message_log', 'audit_log'];
  -- الجداول دي ليها نسخة اتعملت مع التسجيل: بتتطابق بالكود (أو المفتاح) وبتاخد قيم النسخة
  keyed text[] := array['accounts', 'routes', 'specialties', 'message_templates', 'labor_rates', 'shop_branding'];
begin
  perform public.ledger_require(array['owner']::public.app_role[]);
  if s is null or me is null then raise exception 'E_FORBIDDEN'; end if;
  if p_data is null or p_data->>'format' is distinct from 'warsha-backup' or coalesce((p_data->>'version')::int, 0) <> 1 then
    raise exception 'E_BACKUP_FORMAT';
  end if;
  old_shop := (p_data->>'shop_id')::uuid;
  if old_shop is null or old_shop = s then raise exception 'E_BACKUP_FORMAT'; end if;

  -- محل جديد فاضي بس
  if exists (select 1 from public.devices where shop_id = s) or exists (select 1 from public.customers where shop_id = s)
     or exists (select 1 from public.journal_entries where shop_id = s) or exists (select 1 from public.items where shop_id = s)
     or exists (select 1 from public.suppliers where shop_id = s) or exists (select 1 from public.payments where shop_id = s)
     or exists (select 1 from public.purchases where shop_id = s) or exists (select 1 from public.drawer_closings where shop_id = s)
     or exists (select 1 from public.stock_moves where shop_id = s)
     or exists (select 1 from public.profiles where shop_id = s and id <> me) then
    raise exception 'E_RESTORE_NOT_EMPTY';
  end if;

  perform set_config('warsha.restore', 'on', true);
  drop table if exists pg_temp._rmap;
  create temp table _rmap(old uuid primary key, new uuid not null) on commit drop;
  insert into _rmap values (old_shop, s);

  -- 1) بيانات المحل نفسه (من غير الخطة والإيقاف واللوجو اللي في Storage)
  sh := p_data->'shops'->0;
  if sh is not null then
    update public.shops set
      name = coalesce(sh->>'name', name), phone = sh->>'phone', address = sh->>'address',
      receipt_terms = coalesce(sh->>'receipt_terms', receipt_terms), warranty_days = coalesce((sh->>'warranty_days')::int, warranty_days),
      country = coalesce(sh->>'country', country), currency = coalesce(sh->>'currency', currency),
      payment_methods = coalesce(array(select jsonb_array_elements_text(sh->'payment_methods')), payment_methods),
      theme = coalesce(sh->>'theme', theme), locale = coalesce(sh->>'locale', locale),
      default_margin_pct = coalesce((sh->>'default_margin_pct')::int, default_margin_pct),
      extras = coalesce(sh->'extras', extras), max_discount_pct = coalesce((sh->>'max_discount_pct')::int, max_discount_pct)
    where id = s;
  end if;

  -- 2) الـ ids الجديدة
  -- صاحب المحل في النسخة = اللي بيسترجع دلوقتي
  select (x->>'id')::uuid into old_owner from jsonb_array_elements(coalesce(p_data->'profiles', '[]')) x
   where x->>'role' = 'owner' order by x->>'created_at' limit 1;
  if old_owner is not null then insert into _rmap values (old_owner, me) on conflict do nothing; end if;
  insert into _rmap select (x->>'id')::uuid, coalesce((select a.id from public.accounts a where a.shop_id = s and a.code = x->>'code' and x->>'code' is not null), gen_random_uuid())
    from jsonb_array_elements(coalesce(p_data->'accounts', '[]')) x on conflict do nothing;
  insert into _rmap select (x->>'id')::uuid, coalesce((select a.id from public.routes a where a.shop_id = s and a.code = x->>'code' and x->>'code' is not null), gen_random_uuid())
    from jsonb_array_elements(coalesce(p_data->'routes', '[]')) x on conflict do nothing;
  insert into _rmap select (x->>'id')::uuid, coalesce((select a.id from public.specialties a where a.shop_id = s and a.code = x->>'code' and x->>'code' is not null), gen_random_uuid())
    from jsonb_array_elements(coalesce(p_data->'specialties', '[]')) x on conflict do nothing;
  insert into _rmap select (x->>'id')::uuid, coalesce((select a.id from public.message_templates a where a.shop_id = s and a.key = x->>'key'), gen_random_uuid())
    from jsonb_array_elements(coalesce(p_data->'message_templates', '[]')) x on conflict do nothing;
  insert into _rmap select (x->>'id')::uuid, coalesce((select a.id from public.labor_rates a where a.shop_id = s and a.deleted_at is null and lower(trim(a.issue)) = lower(trim(x->>'issue')) and x->>'deleted_at' is null), gen_random_uuid())
    from jsonb_array_elements(coalesce(p_data->'labor_rates', '[]')) x on conflict do nothing;
  insert into _rmap select (x->>'id')::uuid, coalesce((select a.id from public.shop_branding a where a.shop_id = s), gen_random_uuid())
    from jsonb_array_elements(coalesce(p_data->'shop_branding', '[]')) x on conflict do nothing;
  foreach t in array tabs loop
    insert into _rmap select (x->>'id')::uuid, gen_random_uuid() from jsonb_array_elements(coalesce(p_data->t, '[]')) x where x ? 'id' on conflict do nothing;
  end loop;

  -- 3) الصفوف نفسها بالترتيب
  foreach t in array tabs loop
    rows := '[]'::jsonb;
    for r in select public.restore_remap(x) from jsonb_array_elements(coalesce(p_data->t, '[]')) x loop
      if t = 'profiles' then
        -- صاحب المحل موجود أصلًا. الباقيين موظفين سابقين (من غير حساب دخول)
        continue when (r->>'id')::uuid = me;
        r := r || jsonb_build_object('deleted_at', coalesce(r->>'deleted_at', now()::text));
      elsif t = 'devices' then
        -- كود التتبع (الـ QR) بيفضل زي ما هو، إلا لو مستخدم في المشروع ده (المحل الأصلي لسه هنا)
        if exists (select 1 from public.devices d where d.tracking_token = r->>'tracking_token') then
          r := r || jsonb_build_object('tracking_token', encode(gen_random_bytes(12), 'hex'));
        end if;
      elsif t = 'journal_entries' then
        if r->>'idem_key' is not null and exists (select 1 from public.journal_entries j where j.idem_key = (r->>'idem_key')::uuid) then
          r := r || jsonb_build_object('idem_key', gen_random_uuid());
        end if;
      elsif t = 'shop_branding' then
        -- اللوجو الملون والحراري جوه الصف نفسه. الملف الأصلي في Storage مش جوه النسخة
        r := r || jsonb_build_object('logo_path', null);
      end if;
      if t = any (keyed) and exists (select 1 from _rmap m where m.new = (r->>'id')::uuid and m.old <> m.new)
         and (t <> 'shop_branding' or exists (select 1 from public.shop_branding b where b.id = (r->>'id')::uuid)) then
        -- موجود من التسجيل: بياخد قيم النسخة
        execute format('select count(*) from public.%I where id = $1', t) into n using (r->>'id')::uuid;
        if n > 0 then
          execute format('update public.%1$I x set (%2$s) = (select %2$s from jsonb_populate_record(null::public.%1$I, $1)) where x.id = $2', t,
            (select string_agg(quote_ident(c.column_name), ', ' order by c.ordinal_position) from information_schema.columns c
              where c.table_schema = 'public' and c.table_name = t and c.column_name not in ('id', 'shop_id')))
            using r, (r->>'id')::uuid;
          continue;
        end if;
      end if;
      rows := rows || jsonb_build_array(r);
    end loop;
    if jsonb_array_length(rows) > 0 then
      -- overriding system value: أرقام القيود (entry_no) بترجع زي ما هي
      execute format('insert into public.%1$I overriding system value select * from jsonb_populate_recordset(null::public.%1$I, $1)', t) using rows;
    end if;
    counts := counts || jsonb_build_object(t, jsonb_array_length(coalesce(p_data->t, '[]')));
  end loop;

  -- 4) عدّاد أرقام الطلبات: من آخر رقم راجع في كل سنة
  insert into public.order_counters(shop_id, year, last_value)
  select s, split_part(order_no, '-', 1)::int, max(split_part(order_no, '-', 2)::int)
    from public.devices where shop_id = s and order_no ~ '^\d{4}-\d+$' group by 2
  on conflict (shop_id, year) do update set last_value = greatest(public.order_counters.last_value, excluded.last_value);

  -- 5) التأكد: كل قيد متوازن، ورصيد كل حساب = رصيده في النسخة بالظبط
  select count(*) into bad from (
    select entry_id from public.journal_lines where shop_id = s group by entry_id having sum(debit) <> sum(credit)) x;
  if bad > 0 then raise exception 'E_RESTORE_UNBALANCED'; end if;
  select count(*) into bad from (
    select m.new acc, sum((l->>'debit')::bigint - (l->>'credit')::bigint) b
      from jsonb_array_elements(coalesce(p_data->'journal_lines', '[]')) l join _rmap m on m.old = (l->>'account_id')::uuid group by m.new
  ) x full join (select account_id, sum(debit - credit) b from public.journal_lines where shop_id = s group by account_id) y on y.account_id = x.acc
  where coalesce(x.b, 0) <> coalesce(y.b, 0);
  if bad > 0 then raise exception 'E_RESTORE_MISMATCH'; end if;
  -- وعدد الصفوف في كل جدول (الحسابات والقوالب اللي اتعملت مع التسجيل ممكن تزيد عن النسخة، مش تقل)
  foreach t in array tabs loop
    execute format('select count(*) from public.%I where shop_id = $1', t) into n using s;
    if n < jsonb_array_length(coalesce(p_data->t, '[]')) - (case when t = 'profiles' and old_owner is not null then 1 else 0 end) then
      raise exception 'E_RESTORE_MISMATCH';
    end if;
  end loop;

  perform set_config('warsha.restore', 'off', true);
  insert into public.audit_log(shop_id, actor_id, action, entity, entity_id, after)
  values (s, me, 'backup_restore', 'shops', s, jsonb_build_object('from_shop', old_shop, 'generated_at', p_data->>'generated_at', 'counts', counts));
  return jsonb_build_object('restored', true, 'counts', counts);
end $$;
revoke execute on function public.restore_backup(jsonb) from public, anon;
grant execute on function public.restore_backup(jsonb) to authenticated;
revoke execute on function public.restore_remap(jsonb) from public, anon, authenticated;
revoke execute on function public.restoring() from public, anon;
-- (قراءة بس: صح أو غلط. التريجرات بتستخدمها، ومحدش يقدر يفعّل العلامة من بره restore_backup)
grant execute on function public.restoring() to authenticated;

-- ============================== 0024_signout.sql ==============================
-- 0024: الخروج من غير أخطاء لما الجلسة تكون منتهية أو المستخدم اتحذف
--
-- الواجهة كانت بتنادي /auth/v1/logout، وده بيرجع 403 لو المستخدم اتحذف أو الجلسة اتلغت من السيرفر،
-- والمتصفح بيكتب الخطأ في الـ console. دلوقتي الواجهة بتنادي الدالة دي (بترجع نجاح دايمًا)، وبعدها بتمسح
-- الجلسة من الجهاز بس.
--
-- end_my_session: بتلغي الجلسة الحالية بس (والـ refresh tokens بتاعتها) لو لسه موجودة. لو مش موجودة: مفيش حاجة.
create or replace function public.end_my_session() returns void
language plpgsql security definer set search_path = public as $$
declare sid uuid;
begin
  begin
    sid := nullif(auth.jwt() ->> 'session_id', '')::uuid;
  exception when others then
    sid := null;
  end;
  if sid is null or auth.uid() is null then return; end if;
  begin
    delete from auth.sessions where id = sid and user_id = auth.uid();
  exception when insufficient_privilege or undefined_table then
    -- لو صلاحيات المشروع ما بتسمحش: الجلسة بتتمسح من الجهاز بس (زي "الخروج من الجهاز ده")
    null;
  end;
end $$;
revoke execute on function public.end_my_session() from public, anon;
grant execute on function public.end_my_session() to authenticated;

-- ============================== 0025_integrity.sql ==============================
-- 0025: دقة الحسابات
--
-- 1) خطأ اتلقى: إلغاء (قيد عكسي) لشراء بعد ما جزء من البضاعة اتصرف ممكن يسيب الصنف بكمية صفر وقيمة، أو بقيمة بالسالب
--    (مثال: 5 بـ 100 و10 بـ 1، صرف 9، إلغاء الشراء الأول = وحدة واحدة بقيمة -296 قرش). وده بيخلّي تكلفة أي صرف بعد كده غلط.
--    الحل: بعد أي إلغاء فيه مخزون، الصنف بيتسوّى: الفرق بيروح "فرق تكلفة" (تكلفة البضاعة) بقيد متوازن، والقيمة بتبقى صح.
-- 2) فحص سلامة تلقائي (integrity_report) لصاحب المحل: أي فرق بيظهر بالمكان والمبلغ.

alter table public.journal_entries drop constraint if exists journal_entries_source_type_check;
alter table public.journal_entries add constraint journal_entries_source_type_check check (source_type = any (array[
  'payment', 'delivery', 'purchase', 'supplier_payment', 'part_use', 'sale', 'expense', 'salary', 'salary_payment', 'advance',
  'advance_settle', 'capital', 'drawing', 'transfer', 'drawer_close', 'reversal', 'cost_adjust']));
-- حركة تسوية القيمة: كمية صفر وقيمة
alter table public.stock_moves drop constraint if exists stock_moves_qty_check;
alter table public.stock_moves add constraint stock_moves_qty_check check (qty <> 0 or value <> 0);

-- تسوية صنف: لو كميته صفر وفيه قيمة باقية، أو قيمته بالسالب، الفرق بيروح تكلفة البضاعة
create or replace function public.ledger_settle_item(p_item uuid, p_device uuid default null) returns void
language plpgsql security definer set search_path = public as $$
declare st record; v bigint; e uuid;
begin
  select * into st from public.item_stock(p_item);
  if not ((st.qty = 0 and st.value <> 0) or (st.qty > 0 and st.value < 0)) then return; end if;
  v := st.value;
  e := public.ledger_post('cost_adjust', p_item, 'فرق تكلفة مخزون',
    case when v > 0 then jsonb_build_array(public.ledger_line(public.ledger_acc('cogs'), v, 0), public.ledger_line(public.ledger_acc('inventory'), 0, v))
         else jsonb_build_array(public.ledger_line(public.ledger_acc('inventory'), -v, 0), public.ledger_line(public.ledger_acc('cogs'), 0, -v)) end,
    p_device);
  insert into public.stock_moves(shop_id, item_id, entry_id, qty, value) values (public.current_shop_id(), p_item, e, 0, -v);
end $$;
revoke execute on function public.ledger_settle_item(uuid, uuid) from public, anon, authenticated;

CREATE OR REPLACE FUNCTION public.reverse_entry(p_entry uuid, p_reason text)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  o public.journal_entries;
  e uuid;
  lines jsonb;
  mv record;
begin
  perform public.ledger_require(array['owner']::public.app_role[]);
  if nullif(trim(p_reason), '') is null then raise exception 'E_BAD_INPUT'; end if;
  select * into o from public.journal_entries where id = p_entry and shop_id = public.current_shop_id() for update;
  if not found then raise exception 'E_NOT_FOUND'; end if;
  if o.source_type = 'reversal' or exists (select 1 from public.journal_entries where reverses_id = o.id) then
    raise exception 'E_ALREADY_REVERSED';
  end if;
  select jsonb_agg(public.ledger_line(account_id, credit, debit, party_type, party_id)) into lines
  from public.journal_lines where entry_id = o.id;
  e := public.ledger_post('reversal', o.source_id, p_reason, lines, o.device_id, null, o.id);
  for mv in select * from public.stock_moves where entry_id = o.id loop
    perform 1 from public.items where id = mv.item_id for update;
    if (select coalesce(sum(qty), 0) from public.stock_moves where item_id = mv.item_id) - mv.qty < 0 then
      raise exception 'E_STOCK';
    end if;
    insert into public.stock_moves(shop_id, item_id, entry_id, qty, value) values (mv.shop_id, mv.item_id, e, -mv.qty, -mv.value);
  end loop;
  -- (0025) بعد إلغاء حركة مخزون: لو الصنف بقى كميته صفر وفيه قيمة، أو قيمته بالسالب، الفرق بيروح "فرق تكلفة"
  for mv in select distinct item_id from public.stock_moves where entry_id = o.id loop
    perform public.ledger_settle_item(mv.item_id, o.device_id);
  end loop;
  insert into public.audit_log(shop_id, actor_id, action, entity, entity_id, before, after)
  values (o.shop_id, auth.uid(), 'reverse_entry', 'journal_entries', o.id, to_jsonb(o), jsonb_build_object('reversal_id', e, 'reason', p_reason));
  return e;
end $function$;

-- ============================================================
-- فحص السلامة
-- ============================================================
create or replace function public.integrity_report() returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare s uuid := public.current_shop_id(); out jsonb := '[]'::jsonb; r record; inv bigint; mv bigint;
begin
  perform public.ledger_require(array['owner']::public.app_role[]);
  -- 1) قيد مش متوازن، أو ناقص طرف (أقل من سطرين)
  for r in select e.id, e.entry_no, coalesce(sum(l.debit), 0) - coalesce(sum(l.credit), 0) diff, count(l.id) n
           from public.journal_entries e left join public.journal_lines l on l.entry_id = e.id
           where e.shop_id = s group by e.id having coalesce(sum(l.debit), 0) <> coalesce(sum(l.credit), 0) or count(l.id) < 2 loop
    out := out || jsonb_build_array(jsonb_build_object('kind', case when r.n < 2 then 'entry_missing_side' else 'entry_unbalanced' end, 'amount', abs(r.diff), 'entry_id', r.id, 'entry_no', r.entry_no));
  end loop;
  -- 2) قيمة المخزون في الدفتر = مجموع حركات المخزون
  select coalesce(sum(l.debit - l.credit), 0) into inv from public.journal_lines l join public.accounts a on a.id = l.account_id where a.shop_id = s and a.kind = 'inventory';
  select coalesce(sum(m.value), 0) into mv from public.stock_moves m where m.shop_id = s;
  if inv <> mv then out := out || jsonb_build_array(jsonb_build_object('kind', 'inventory_ledger', 'amount', abs(inv - mv), 'ledger', inv, 'stock', mv)); end if;
  -- 3) كل صنف: الكمية مش بالسالب، ومفيش قيمة من غير كمية، ومفيش قيمة بالسالب
  for r in select i.id, i.name, coalesce(sum(m.qty), 0) q, coalesce(sum(m.value), 0) v from public.items i left join public.stock_moves m on m.item_id = i.id
           where i.shop_id = s group by i.id having coalesce(sum(m.qty), 0) < 0 or (coalesce(sum(m.qty), 0) = 0 and coalesce(sum(m.value), 0) <> 0) or coalesce(sum(m.value), 0) < 0 loop
    out := out || jsonb_build_array(jsonb_build_object('kind', 'item_value', 'amount', abs(r.v), 'item_id', r.id, 'item', r.name, 'qty', r.q, 'value', r.v));
  end loop;
  -- 4) كل حركة مخزون بقيمتها في قيد على حساب المخزون بنفس المبلغ
  for r in select m.entry_id, e.entry_no, sum(m.value) mvv,
                  (select coalesce(sum(l.debit - l.credit), 0) from public.journal_lines l join public.accounts a on a.id = l.account_id where l.entry_id = m.entry_id and a.kind = 'inventory') lv
           from public.stock_moves m join public.journal_entries e on e.id = m.entry_id where m.shop_id = s group by m.entry_id, e.entry_no loop
    if r.mvv <> r.lv then out := out || jsonb_build_array(jsonb_build_object('kind', 'stock_entry', 'amount', abs(r.mvv - r.lv), 'entry_id', r.entry_id, 'entry_no', r.entry_no)); end if;
  end loop;
  -- 5) كل دفعة مبلغها = المبلغ اللي دخل الخزنة في قيدها
  for r in select p.id, p.amount, p.entry_id, e.entry_no,
                  (select coalesce(sum(l.debit), 0) from public.journal_lines l join public.accounts a on a.id = l.account_id where l.entry_id = p.entry_id and a.kind = 'cash') cash
           from public.payments p join public.journal_entries e on e.id = p.entry_id where p.shop_id = s loop
    if r.cash <> r.amount then out := out || jsonb_build_array(jsonb_build_object('kind', 'payment_entry', 'amount', abs(r.cash - r.amount), 'entry_id', r.entry_id, 'entry_no', r.entry_no)); end if;
  end loop;
  -- 6) حسابات العملاء والموردين والموظفين: كل سطر عليه طرف (عشان رصيد كل واحد = كشف حسابه)
  for r in select l.entry_id, e.entry_no, sum(l.debit + l.credit) amt from public.journal_lines l join public.accounts a on a.id = l.account_id join public.journal_entries e on e.id = l.entry_id
           where l.shop_id = s and a.kind in ('receivable', 'payable', 'advances', 'salaries') and l.party_id is null group by l.entry_id, e.entry_no loop
    out := out || jsonb_build_array(jsonb_build_object('kind', 'party_missing', 'amount', r.amt, 'entry_id', r.entry_id, 'entry_no', r.entry_no));
  end loop;
  -- 7) كل سطر في نفس محل القيد
  for r in select l.entry_id, e.entry_no from public.journal_lines l join public.journal_entries e on e.id = l.entry_id where e.shop_id = s and l.shop_id <> e.shop_id group by 1, 2 loop
    out := out || jsonb_build_array(jsonb_build_object('kind', 'shop_mismatch', 'amount', 0, 'entry_id', r.entry_id, 'entry_no', r.entry_no));
  end loop;
  return out;
end $$;
revoke execute on function public.integrity_report() from public, anon;
grant execute on function public.integrity_report() to authenticated;

-- ============================== 0026_edit_delete.sql ==============================
-- ============================================================
-- 0026: تعديل وحذف في كل حاجة (البند 2)
-- - الفلوس والمخزون: القيد الأصلي ما بيتلمسش أبدًا. "الحذف" = قيد عكسي، و"التعديل" = قيد عكسي + قيد جديد
--   في نفس الـ transaction (لو أي جزء فشل، ولا حاجة بتتسجل). والسبب إجباري.
-- - الصلاحية: صاحب المحل، أو موظف صاحب المحل اداله إذن "تصحيح العمليات" (profiles.can_correct).
-- - العملاء والموردين والأصناف والأجهزة: حذف ناعم (deleted_at) بس، ومن غير ما يبوّظ أي رصيد:
--   العميل أو المورد اللي عليه أو ليه فلوس ما بيتحذفش، والصنف اللي في المخزون ما بيتحذفش،
--   والجهاز اللي عليه فلوس ما بيتحذفش. وكل ده بيتسجل في سجل النشاط بالسبب.
-- ============================================================

-- 1) إذن التصحيح لموظف
alter table public.profiles add column if not exists can_correct boolean not null default false;

create or replace function public.can_correct() returns boolean
language sql stable security definer set search_path = public as $$
  select public.current_app_role() = 'owner'
      or coalesce((select p.can_correct from public.profiles p where p.id = auth.uid() and p.deleted_at is null), false)
$$;
revoke execute on function public.can_correct() from public, anon;
grant execute on function public.can_correct() to authenticated;

create or replace function public.set_can_correct(p_user uuid, p_on boolean) returns void
language plpgsql security definer set search_path = public as $$
declare o public.profiles;
begin
  perform public.ledger_require(array['owner']::public.app_role[]);
  select * into o from public.profiles where id = p_user and shop_id = public.current_shop_id();
  if not found then raise exception 'E_NOT_FOUND'; end if;
  if o.role = 'owner' then raise exception 'E_BAD_INPUT'; end if;
  perform set_config('warsha.grant', '1', true);
  update public.profiles set can_correct = p_on, updated_at = now() where id = p_user;
  perform set_config('warsha.grant', '', true);
  insert into public.audit_log(shop_id, actor_id, action, entity, entity_id, before, after)
  values (o.shop_id, auth.uid(), 'set_can_correct', 'profiles', o.id, jsonb_build_object('can_correct', o.can_correct), jsonb_build_object('can_correct', p_on));
end $$;
revoke execute on function public.set_can_correct(uuid, boolean) from public, anon;
grant execute on function public.set_can_correct(uuid, boolean) to authenticated;

-- الإذن ما بيتغيرش غير من set_can_correct (ولا حتى الموظف لنفسه)
create or replace function public.tg_profile_grant_guard() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if new.can_correct is distinct from old.can_correct and coalesce(current_setting('warsha.grant', true), '') <> '1' and not public.restoring() then
    raise exception 'E_FORBIDDEN';
  end if;
  return new;
end $$;
drop trigger if exists profile_grant_guard on public.profiles;
create trigger profile_grant_guard before update on public.profiles for each row execute function public.tg_profile_grant_guard();

-- 2) الإلغاء بقيد عكسي: صاحب المحل أو اللي معاه الإذن (نفس جسم 0025 بالظبط، والصلاحية بس اللي اتغيرت)
CREATE OR REPLACE FUNCTION public.reverse_entry(p_entry uuid, p_reason text)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  o public.journal_entries;
  e uuid;
  lines jsonb;
  mv record;
begin
  if public.current_app_role() is null or not public.can_correct() then raise exception 'E_FORBIDDEN'; end if;
  if nullif(trim(p_reason), '') is null then raise exception 'E_REASON_REQUIRED'; end if;
  select * into o from public.journal_entries where id = p_entry and shop_id = public.current_shop_id() for update;
  if not found then raise exception 'E_NOT_FOUND'; end if;
  if o.source_type in ('reversal', 'cost_adjust') or exists (select 1 from public.journal_entries where reverses_id = o.id) then
    raise exception 'E_ALREADY_REVERSED';
  end if;
  select jsonb_agg(public.ledger_line(account_id, credit, debit, party_type, party_id)) into lines
  from public.journal_lines where entry_id = o.id;
  e := public.ledger_post('reversal', o.source_id, p_reason, lines, o.device_id, null, o.id);
  for mv in select * from public.stock_moves where entry_id = o.id loop
    perform 1 from public.items where id = mv.item_id for update;
    if (select coalesce(sum(qty), 0) from public.stock_moves where item_id = mv.item_id) - mv.qty < 0 then
      raise exception 'E_STOCK';
    end if;
    insert into public.stock_moves(shop_id, item_id, entry_id, qty, value) values (mv.shop_id, mv.item_id, e, -mv.qty, -mv.value);
  end loop;
  for mv in select distinct item_id from public.stock_moves where entry_id = o.id loop
    perform public.ledger_settle_item(mv.item_id, o.device_id);
  end loop;
  insert into public.audit_log(shop_id, actor_id, action, entity, entity_id, before, after)
  values (o.shop_id, auth.uid(), 'reverse_entry', 'journal_entries', o.id, to_jsonb(o), jsonb_build_object('reversal_id', e, 'reason', p_reason));
  return e;
end $function$;

-- 3) بيانات العملية عشان شاشة التعديل تتملي بيها (من القيد نفسه)
create or replace function public.entry_args(p_entry uuid) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare
  o public.journal_entries;
  cash_in uuid; cash_out uuid; amt bigint; party uuid; acc uuid; res jsonb; pay public.payments; pur public.purchases;
  ls jsonb; rev bigint; cust uuid;
begin
  if public.current_app_role() is null or not public.can_correct() then raise exception 'E_FORBIDDEN'; end if;
  select * into o from public.journal_entries where id = p_entry and shop_id = public.current_shop_id();
  if not found then raise exception 'E_NOT_FOUND'; end if;
  select max(l.account_id::text) filter (where a.kind = 'cash' and l.debit > 0)::uuid,
         max(l.account_id::text) filter (where a.kind = 'cash' and l.credit > 0)::uuid,
         max(l.party_id::text) filter (where l.party_id is not null)::uuid,
         max(l.account_id::text) filter (where a.kind = 'expense' and l.debit > 0)::uuid,
         greatest(sum(l.debit), 0)
    into cash_in, cash_out, party, acc, amt
  from public.journal_lines l join public.accounts a on a.id = l.account_id where l.entry_id = o.id;
  res := jsonb_build_object('source_type', o.source_type, 'entry_no', o.entry_no, 'note', o.memo,
    'reversed', exists (select 1 from public.journal_entries where reverses_id = o.id),
    'editable', o.source_type in ('payment', 'expense', 'transfer', 'capital', 'drawing', 'advance', 'salary', 'salary_payment', 'supplier_payment', 'purchase', 'sale'));
  if o.source_type = 'payment' then
    select * into pay from public.payments where entry_id = o.id;
    res := res || jsonb_build_object('customer', pay.customer_id, 'device', pay.device_id, 'cashbox', pay.cashbox_id, 'method', pay.method, 'amount', pay.amount);
  elsif o.source_type = 'expense' then
    res := res || jsonb_build_object('account', acc, 'cashbox', cash_out, 'amount', amt);
  elsif o.source_type = 'transfer' then
    res := res || jsonb_build_object('from', cash_out, 'to', cash_in, 'amount', amt);
  elsif o.source_type = 'capital' then
    res := res || jsonb_build_object('cashbox', cash_in, 'amount', amt);
  elsif o.source_type = 'drawing' then
    res := res || jsonb_build_object('cashbox', cash_out, 'amount', amt);
  elsif o.source_type in ('advance', 'salary_payment') then
    res := res || jsonb_build_object('employee', party, 'cashbox', cash_out, 'amount', amt);
  elsif o.source_type = 'salary' then
    res := res || jsonb_build_object('employee', party, 'amount', amt);
  elsif o.source_type = 'supplier_payment' then
    res := res || jsonb_build_object('supplier', party, 'cashbox', cash_out, 'amount', amt);
  elsif o.source_type = 'purchase' then
    select * into pur from public.purchases where entry_id = o.id;
    select jsonb_agg(jsonb_build_object('item', m.item_id, 'qty', m.qty, 'unit_cost', m.value / nullif(m.qty, 0)) order by m.created_at) into ls
    from public.stock_moves m where m.entry_id = o.id;
    res := res || jsonb_build_object('supplier', pur.supplier_id, 'cashbox', cash_out, 'lines', coalesce(ls, '[]'::jsonb));
  elsif o.source_type = 'sale' then
    -- سعر البيع: لو صنف واحد بيتحسب من الإيراد، ولو أكتر من صنف بيتاخد سعر الصنف المسجل
    select coalesce(sum(l.credit), 0) into rev from public.journal_lines l join public.accounts a on a.id = l.account_id where l.entry_id = o.id and a.type = 'revenue';
    select max(l.party_id::text) filter (where l.party_type = 'customer')::uuid into cust from public.journal_lines l where l.entry_id = o.id;
    select jsonb_agg(jsonb_build_object('item', x.item_id, 'qty', x.q,
             'price', case when x.n = 1 then rev / x.q else coalesce(i.sale_price, 0) end) order by x.first)
      into ls
    from (select m.item_id, -sum(m.qty) q, count(*) over () n, min(m.created_at) first from public.stock_moves m where m.entry_id = o.id group by m.item_id) x
    join public.items i on i.id = x.item_id;
    res := res || jsonb_build_object('customer', cust, 'cashbox', cash_in, 'lines', coalesce(ls, '[]'::jsonb));
  end if;
  return res;
end $$;
revoke execute on function public.entry_args(uuid) from public, anon;
grant execute on function public.entry_args(uuid) to authenticated;

-- 4) التعديل: قيد عكسي للأصل + نفس نوع العملية بالبيانات الجديدة، في نفس الـ transaction
-- p_new.id = id العملية الجديدة (من التطبيق). لو نفس التعديل اتبعت مرتين (مزامنة)، بيرجع نفس النتيجة من غير تكرار.
create or replace function public.edit_entry(p_entry uuid, p_reason text, p_new jsonb) returns uuid
language plpgsql security definer set search_path = public as $$
declare
  o public.journal_entries;
  nid uuid := (p_new ->> 'id')::uuid;
  e uuid;
  amt bigint := (p_new ->> 'amount')::bigint;
  note text := nullif(trim(p_new ->> 'note'), '');
begin
  if public.current_app_role() is null or not public.can_correct() then raise exception 'E_FORBIDDEN'; end if;
  if nid is null then raise exception 'E_BAD_INPUT'; end if;
  e := public.ledger_idem(nid);
  if e is not null then return e; end if;
  select * into o from public.journal_entries where id = p_entry and shop_id = public.current_shop_id();
  if not found then raise exception 'E_NOT_FOUND'; end if;
  perform public.reverse_entry(p_entry, p_reason);
  case o.source_type
    when 'payment' then e := public.record_payment(nid, (p_new ->> 'customer')::uuid, (p_new ->> 'cashbox')::uuid, amt, (p_new ->> 'device')::uuid, p_new ->> 'method', note);
    when 'expense' then e := public.record_expense(nid, (p_new ->> 'account')::uuid, (p_new ->> 'cashbox')::uuid, amt, note);
    when 'transfer' then e := public.transfer_cash(nid, (p_new ->> 'from')::uuid, (p_new ->> 'to')::uuid, amt, note);
    when 'capital' then e := public.owner_capital(nid, (p_new ->> 'cashbox')::uuid, amt, note);
    when 'drawing' then e := public.owner_drawing(nid, (p_new ->> 'cashbox')::uuid, amt, note);
    when 'advance' then e := public.give_advance(nid, (p_new ->> 'employee')::uuid, (p_new ->> 'cashbox')::uuid, amt, note);
    when 'salary' then e := public.accrue_salary(nid, (p_new ->> 'employee')::uuid, amt, note);
    when 'salary_payment' then e := public.pay_salary(nid, (p_new ->> 'employee')::uuid, (p_new ->> 'cashbox')::uuid, amt, note);
    when 'supplier_payment' then e := public.pay_supplier(nid, (p_new ->> 'supplier')::uuid, (p_new ->> 'cashbox')::uuid, amt, note);
    when 'purchase' then e := public.record_purchase(nid, (p_new ->> 'supplier')::uuid, p_new -> 'lines', (p_new ->> 'cashbox')::uuid, note);
    when 'sale' then e := public.record_sale(nid, p_new -> 'lines', (p_new ->> 'cashbox')::uuid, (p_new ->> 'customer')::uuid, note);
    else raise exception 'E_NOT_EDITABLE';
  end case;
  insert into public.audit_log(shop_id, actor_id, action, entity, entity_id, before, after)
  values (o.shop_id, auth.uid(), 'edit_entry', 'journal_entries', o.id, to_jsonb(o), jsonb_build_object('new_entry', e, 'reason', p_reason));
  return e;
end $$;
revoke execute on function public.edit_entry(uuid, text, jsonb) from public, anon;
grant execute on function public.edit_entry(uuid, text, jsonb) to authenticated;

-- 5) الحذف الناعم الآمن: عميل، مورد، صنف، جهاز
create or replace function public.soft_delete(p_kind text, p_id uuid, p_reason text default null) returns void
language plpgsql security definer set search_path = public as $$
declare s uuid := public.current_shop_id(); before jsonb; tbl text;
begin
  if public.current_app_role() is null or not public.can_correct() then raise exception 'E_FORBIDDEN'; end if;
  if p_kind = 'customer' then
    tbl := 'customers';
    select to_jsonb(c) into before from public.customers c where id = p_id and shop_id = s and deleted_at is null for update;
    if before is null then raise exception 'E_NOT_FOUND'; end if;
    if exists (select 1 from public.journal_lines l where l.party_id = p_id and l.shop_id = s group by l.account_id having sum(l.debit - l.credit) <> 0) then raise exception 'E_HAS_BALANCE'; end if;
    if exists (select 1 from public.devices d where d.customer_id = p_id and d.deleted_at is null and d.status not in ('delivered', 'unrepairable')) then raise exception 'E_HAS_OPEN_DEVICES'; end if;
  elsif p_kind = 'supplier' then
    tbl := 'suppliers';
    select to_jsonb(x) into before from public.suppliers x where id = p_id and shop_id = s and deleted_at is null for update;
    if before is null then raise exception 'E_NOT_FOUND'; end if;
    if exists (select 1 from public.journal_lines l where l.party_id = p_id and l.shop_id = s group by l.account_id having sum(l.debit - l.credit) <> 0) then raise exception 'E_HAS_BALANCE'; end if;
  elsif p_kind = 'item' then
    tbl := 'items';
    select to_jsonb(x) into before from public.items x where id = p_id and shop_id = s and deleted_at is null for update;
    if before is null then raise exception 'E_NOT_FOUND'; end if;
    if (select coalesce(sum(qty), 0) <> 0 or coalesce(sum(value), 0) <> 0 from public.stock_moves where item_id = p_id) then raise exception 'E_HAS_STOCK'; end if;
  elsif p_kind = 'device' then
    tbl := 'devices';
    select to_jsonb(x) into before from public.devices x where id = p_id and shop_id = s and deleted_at is null for update;
    if before is null then raise exception 'E_NOT_FOUND'; end if;
    if exists (select 1 from public.journal_entries e where e.device_id = p_id and not exists (select 1 from public.journal_entries r where r.reverses_id = e.id) and e.source_type not in ('reversal', 'cost_adjust')) then
      raise exception 'E_HAS_MONEY';
    end if;
  else
    raise exception 'E_BAD_INPUT';
  end if;
  perform set_config('warsha.system', 'on', true);
  execute format('update public.%I set deleted_at = now(), updated_at = now() where id = $1', tbl) using p_id;
  perform set_config('warsha.system', 'off', true);
  insert into public.audit_log(shop_id, actor_id, action, entity, entity_id, before, after)
  values (s, auth.uid(), 'soft_delete', tbl, p_id, before, jsonb_build_object('reason', nullif(trim(p_reason), '')));
end $$;
revoke execute on function public.soft_delete(text, uuid, text) from public, anon;
grant execute on function public.soft_delete(text, uuid, text) to authenticated;

-- ملاحظة: الأرشفة المباشرة (update deleted_at) لسه لصاحب المحل بس زي قاعدة 0021 (tg_owner_soft_delete).
-- soft_delete بتعدّي القاعدة دي للموظف اللي معاه إذن التصحيح، بعد ما تتأكد إن الحذف مش هيبوّظ أي رصيد.
drop trigger if exists soft_delete_guard on public.customers;
drop trigger if exists soft_delete_guard on public.suppliers;
drop trigger if exists soft_delete_guard on public.items;
drop trigger if exists soft_delete_guard on public.devices;
drop function if exists public.tg_soft_delete_guard();

-- ============================== 0027_inventory.sql ==============================
-- ============================================================
-- 0027: المخزون قسم مستقل بحساباته (البند 3)
-- كل عملية هنا قيد متوازن واحد جوه transaction، بالقروش، وبالمتوسط المرجّح، وما بتعديش المخزون بالسالب:
-- - الهالك (write_off): مصروف "هالك" مدين، والمخزون دائن بالتكلفة. والسبب إجباري.
-- - مرتجع للمورد (supplier_return): المخزون بيقل بالتكلفة، وحساب المورد بيقل (أو استرداد كاش) بالمبلغ المتفق عليه،
--   والفرق (لو المورد رجّع أقل أو أكتر من التكلفة) بيروح تكلفة البضاعة.
-- - مرتجع من العميل (sale_return): الإيراد بيقل بالمبلغ المرتجع، والفلوس بترجع من خزنة (أو رصيد للعميل).
--   والقطعة يا إما بترجع المخزون بتكلفتها، يا إما بتتسجل هالك لو بايظة.
-- - "ربط المخزون بالصيانة" (shops.extras.link_inventory، الافتراضي مربوط): لو مش مربوط،
--   القطعة بتتكتب على الجهاز يدوي بتكلفتها (device_manual_part) من غير ما المخزون يتأثر، والربح صح في الحالتين.
-- - الأصناف: تصنيف، وباركود (مش متكرر في نفس المحل)، وصورة في Storage تحت shop_id.
-- ============================================================

alter table public.journal_entries drop constraint if exists journal_entries_source_type_check;
alter table public.journal_entries add constraint journal_entries_source_type_check check (source_type = any (array[
  'payment', 'delivery', 'purchase', 'supplier_payment', 'part_use', 'sale', 'expense', 'salary', 'salary_payment', 'advance',
  'advance_settle', 'capital', 'drawing', 'transfer', 'drawer_close', 'reversal', 'cost_adjust',
  'write_off', 'supplier_return', 'sale_return']));

-- حساب "هالك" لكل محل (نوعه تكلفة بضاعة عشان ما يظهرش في قايمة المصروفات العادية)
create or replace function public.ensure_ledger_accounts(p_shop uuid) returns void
language plpgsql security definer set search_path = public as $$
declare m text;
begin
  insert into public.accounts(shop_id, code, type, kind)
  select p_shop, v.code, v.type::public.account_type, v.kind from (values
    ('ar', 'asset', 'receivable'), ('advances', 'asset', 'advances'), ('inventory', 'asset', 'inventory'),
    ('ap', 'liability', 'payable'), ('salaries_payable', 'liability', 'salaries'),
    ('capital', 'equity', 'capital'), ('drawings', 'equity', 'drawings'),
    ('rev_repair', 'revenue', 'revenue'), ('rev_parts', 'revenue', 'revenue'), ('rev_accessories', 'revenue', 'revenue'), ('overage', 'revenue', 'overage'),
    ('cogs', 'expense', 'cogs'), ('shortage', 'expense', 'shortage'), ('wastage', 'expense', 'cogs'),
    ('exp_salaries', 'expense', 'expense'), ('exp_rent', 'expense', 'expense'), ('exp_electricity', 'expense', 'expense'),
    ('exp_internet', 'expense', 'expense'), ('exp_purchases', 'expense', 'expense')
  ) as v(code, type, kind)
  on conflict (shop_id, code) where code is not null do nothing;
  for m in
    select unnest(array['cash', 'wallet', 'instapay', 'bank_transfer', 'card'])
    union
    select unnest(payment_methods) from public.shops where id = p_shop
  loop
    insert into public.accounts(shop_id, code, type, kind, method)
    values (p_shop, 'cash_' || m, 'asset', 'cash', m)
    on conflict (shop_id, code) where code is not null do nothing;
  end loop;
end $$;
revoke execute on function public.ensure_ledger_accounts(uuid) from public, anon, authenticated;
do $$
declare s uuid;
begin
  perform set_config('warsha.system', 'on', true);
  for s in select id from public.shops loop
    perform public.ensure_ledger_accounts(s);
  end loop;
  perform set_config('warsha.system', 'off', true);
end $$;

-- الأصناف: تصنيف وباركود وصورة
alter table public.items add column if not exists category text check (category is null or length(category) <= 60);
alter table public.items add column if not exists barcode text check (barcode is null or barcode ~ '^[0-9A-Za-z-]{4,32}$');
alter table public.items add column if not exists image_path text;
create unique index if not exists items_barcode_unique on public.items(shop_id, barcode) where barcode is not null and deleted_at is null;

-- صور الأصناف: خاصة بكل محل
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('item-images', 'item-images', false, 2097152, array['image/png', 'image/jpeg', 'image/webp'])
on conflict (id) do nothing;
do $$
begin
  begin drop policy if exists item_images_read on storage.objects; exception when others then null; end;
  begin drop policy if exists item_images_upload on storage.objects; exception when others then null; end;
  begin drop policy if exists item_images_update on storage.objects; exception when others then null; end;
end $$;
create policy item_images_read on storage.objects for select to authenticated
  using (bucket_id = 'item-images' and (storage.foldername(name))[1] = public.current_shop_id()::text);
create policy item_images_upload on storage.objects for insert to authenticated
  with check (bucket_id = 'item-images' and (storage.foldername(name))[1] = public.current_shop_id()::text and public.current_app_role() = 'owner');
create policy item_images_update on storage.objects for update to authenticated
  using (bucket_id = 'item-images' and (storage.foldername(name))[1] = public.current_shop_id()::text and public.current_app_role() = 'owner');

-- رصيد صنف (كمية وقيمة) + آخر تكلفة شراء (لو المخزون خلص، عشان المرتجع يرجع بتكلفة معقولة)
create or replace function public.item_last_cost(p_item uuid) returns bigint
language sql stable security definer set search_path = public as $$
  select coalesce(
    (select case when sum(qty) > 0 then sum(value) / sum(qty) end from public.stock_moves where item_id = p_item having sum(qty) > 0),
    (select m.value / m.qty from public.stock_moves m join public.journal_entries e on e.id = m.entry_id
      where m.item_id = p_item and m.qty > 0 and e.source_type = 'purchase' order by m.created_at desc limit 1),
    0)::bigint
$$;
revoke execute on function public.item_last_cost(uuid) from public, anon, authenticated;

-- ---------- الهالك ----------
create or replace function public.write_off(p_id uuid, p_item uuid, p_qty integer, p_reason text) returns uuid
language plpgsql security definer set search_path = public as $$
declare s uuid := public.current_shop_id(); e uuid; cost bigint;
begin
  perform public.ledger_require(array['owner']::public.app_role[]);
  e := public.ledger_idem(p_id);
  if e is not null then return e; end if;
  if nullif(trim(p_reason), '') is null then raise exception 'E_REASON_REQUIRED'; end if;
  if p_qty is null or p_qty <= 0 then raise exception 'E_BAD_AMOUNT'; end if;
  e := gen_random_uuid();
  insert into public.journal_entries(id, shop_id, source_type, source_id, memo, idem_key, created_by)
  values (e, s, 'write_off', p_item, trim(p_reason), p_id, auth.uid());
  cost := public.ledger_issue(p_item, p_qty, e);
  if cost > 0 then
    insert into public.journal_lines(shop_id, entry_id, account_id, debit, credit) values
      (s, e, public.ledger_acc('wastage'), cost, 0), (s, e, public.ledger_acc('inventory'), 0, cost);
  else
    -- صنف قيمته صفر: مفيش قيد يتعمل بطرفين، فبيترفض (والرسالة بتقول إن المبلغ غلط)
    raise exception 'E_BAD_AMOUNT';
  end if;
  return e;
end $$;

-- ---------- مرتجع للمورد ----------
-- p_refund: اللي المورد هيرجّعه (أو هيخصمه من حسابه). p_cashbox فاضي = بيتخصم من حساب المورد
create or replace function public.supplier_return(p_id uuid, p_supplier uuid, p_item uuid, p_qty integer, p_refund bigint, p_cashbox uuid default null, p_reason text default null) returns uuid
language plpgsql security definer set search_path = public as $$
declare s uuid := public.current_shop_id(); e uuid; cost bigint; diff bigint; cb uuid;
begin
  perform public.ledger_require(array['owner']::public.app_role[]);
  e := public.ledger_idem(p_id);
  if e is not null then return e; end if;
  if nullif(trim(p_reason), '') is null then raise exception 'E_REASON_REQUIRED'; end if;
  if p_qty is null or p_qty <= 0 or p_refund is null or p_refund < 0 then raise exception 'E_BAD_AMOUNT'; end if;
  if not exists (select 1 from public.suppliers where id = p_supplier and shop_id = s and deleted_at is null) then raise exception 'E_NOT_FOUND'; end if;
  if p_cashbox is not null then cb := (public.ledger_cashbox(p_cashbox)).id; end if;
  e := gen_random_uuid();
  insert into public.journal_entries(id, shop_id, source_type, source_id, memo, idem_key, created_by)
  values (e, s, 'supplier_return', p_supplier, trim(p_reason), p_id, auth.uid());
  cost := public.ledger_issue(p_item, p_qty, e);
  if cost = 0 and p_refund = 0 then raise exception 'E_BAD_AMOUNT'; end if;
  if cost > 0 then
    insert into public.journal_lines(shop_id, entry_id, account_id, debit, credit) values (s, e, public.ledger_acc('inventory'), 0, cost);
  end if;
  if p_refund > 0 then
    if cb is null then
      insert into public.journal_lines(shop_id, entry_id, account_id, party_type, party_id, debit, credit) values (s, e, public.ledger_acc('ap'), 'supplier', p_supplier, p_refund, 0);
    else
      insert into public.journal_lines(shop_id, entry_id, account_id, debit, credit) values (s, e, cb, p_refund, 0);
    end if;
  end if;
  diff := cost - p_refund;
  if diff > 0 then
    insert into public.journal_lines(shop_id, entry_id, account_id, debit, credit) values (s, e, public.ledger_acc('cogs'), diff, 0);
  elsif diff < 0 then
    insert into public.journal_lines(shop_id, entry_id, account_id, debit, credit) values (s, e, public.ledger_acc('cogs'), 0, -diff);
  end if;
  return e;
end $$;

-- ---------- مرتجع من العميل ----------
-- p_refund: اللي بيرجع للعميل. p_cashbox فاضي + p_customer = رصيد للعميل (بيتخصم من مديونيته). p_restock: القطعة سليمة وبترجع المخزون، وإلا هالك
create or replace function public.sale_return(p_id uuid, p_item uuid, p_qty integer, p_refund bigint, p_cashbox uuid default null, p_customer uuid default null, p_restock boolean default true, p_reason text default null) returns uuid
language plpgsql security definer set search_path = public as $$
declare s uuid := public.current_shop_id(); e uuid; it public.items; cost bigint; cb uuid; rev uuid;
begin
  perform public.ledger_require(array['owner', 'reception']::public.app_role[]);
  e := public.ledger_idem(p_id);
  if e is not null then return e; end if;
  if nullif(trim(p_reason), '') is null then raise exception 'E_REASON_REQUIRED'; end if;
  if p_qty is null or p_qty <= 0 or p_refund is null or p_refund < 0 then raise exception 'E_BAD_AMOUNT'; end if;
  select * into it from public.items where id = p_item and shop_id = s and deleted_at is null for update;
  if not found then raise exception 'E_NOT_FOUND'; end if;
  if p_cashbox is null and p_refund > 0 and p_customer is null then raise exception 'E_BAD_INPUT'; end if;
  if p_customer is not null and not exists (select 1 from public.customers where id = p_customer and shop_id = s and deleted_at is null) then raise exception 'E_NOT_FOUND'; end if;
  if p_cashbox is not null then cb := (public.ledger_cashbox(p_cashbox)).id; end if;
  rev := public.ledger_acc(case when it.kind = 'part' then 'rev_parts' else 'rev_accessories' end);
  cost := public.item_last_cost(p_item) * p_qty;
  if p_refund = 0 and (cost = 0 or not p_restock) then raise exception 'E_BAD_AMOUNT'; end if;
  e := gen_random_uuid();
  insert into public.journal_entries(id, shop_id, source_type, source_id, memo, idem_key, created_by)
  values (e, s, 'sale_return', p_item, trim(p_reason), p_id, auth.uid());
  if p_refund > 0 then
    insert into public.journal_lines(shop_id, entry_id, account_id, debit, credit) values (s, e, rev, p_refund, 0);
    if cb is not null then
      insert into public.journal_lines(shop_id, entry_id, account_id, debit, credit) values (s, e, cb, 0, p_refund);
    else
      insert into public.journal_lines(shop_id, entry_id, account_id, party_type, party_id, debit, credit) values (s, e, public.ledger_acc('ar'), 'customer', p_customer, 0, p_refund);
    end if;
  end if;
  -- القطعة السليمة بترجع المخزون بتكلفتها (والتكلفة بتخرج من تكلفة البضاعة). البايظة ما بترجعش، وتكلفتها فضلت مصروف.
  if p_restock and cost > 0 then
    insert into public.journal_lines(shop_id, entry_id, account_id, debit, credit) values
      (s, e, public.ledger_acc('inventory'), cost, 0), (s, e, public.ledger_acc('cogs'), 0, cost);
    insert into public.stock_moves(shop_id, item_id, entry_id, qty, value) values (s, p_item, e, p_qty, cost);
  elsif p_restock then
    insert into public.stock_moves(shop_id, item_id, entry_id, qty, value) values (s, p_item, e, p_qty, 0);
  end if;
  return e;
end $$;

-- ---------- قطعة يدوية على الجهاز (المخزون مش مربوط بالصيانة) ----------
-- اتدفع تمنها من خزنة، أو على مورد بالآجل. بتتسجل كتكلفة قطع على الجهاز (part_use) من غير أي حركة مخزون
create or replace function public.device_manual_part(p_id uuid, p_device uuid, p_name text, p_cost bigint, p_cashbox uuid default null, p_supplier uuid default null) returns uuid
language plpgsql security definer set search_path = public as $$
declare s uuid := public.current_shop_id(); e uuid; credit_line jsonb;
begin
  perform public.ledger_require(array['owner', 'reception']::public.app_role[]);
  e := public.ledger_idem(p_id);
  if e is not null then return e; end if;
  if nullif(trim(p_name), '') is null then raise exception 'E_BAD_INPUT'; end if;
  perform public.ledger_amount(p_cost);
  if not exists (select 1 from public.devices where id = p_device and shop_id = s and deleted_at is null and status <> 'delivered') then raise exception 'E_NOT_FOUND'; end if;
  if p_cashbox is not null then
    credit_line := public.ledger_line((public.ledger_cashbox(p_cashbox)).id, 0, p_cost);
  elsif p_supplier is not null then
    if not exists (select 1 from public.suppliers where id = p_supplier and shop_id = s and deleted_at is null) then raise exception 'E_NOT_FOUND'; end if;
    credit_line := public.ledger_line(public.ledger_acc('ap'), 0, p_cost, 'supplier', p_supplier);
  else
    raise exception 'E_BAD_INPUT';
  end if;
  return public.ledger_post('part_use', null, trim(p_name), jsonb_build_array(public.ledger_line(public.ledger_acc('cogs'), p_cost, 0), credit_line), p_device, p_id);
end $$;

do $$
declare f text;
begin
  foreach f in array array['write_off(uuid, uuid, integer, text)', 'supplier_return(uuid, uuid, uuid, integer, bigint, uuid, text)',
    'sale_return(uuid, uuid, integer, bigint, uuid, uuid, boolean, text)', 'device_manual_part(uuid, uuid, text, bigint, uuid, uuid)'] loop
    execute format('revoke execute on function public.%s from public, anon', f);
    execute format('grant execute on function public.%s to authenticated', f);
  end loop;
end $$;

-- ---------- المخزون بالأعمدة الجديدة (للكل حسب الصلاحية زي الأول) ----------
drop function if exists public.items_stock();
create or replace function public.items_stock() returns table(id uuid, kind text, name text, sku text, sale_price integer, qty bigint, avg_cost bigint, value bigint, min_qty integer, supplier_id uuid, short boolean, category text, barcode text, image_path text)
language plpgsql stable security definer set search_path = public as $$
declare r public.app_role := public.current_app_role();
begin
  if r is null then raise exception 'E_FORBIDDEN'; end if;
  return query
  select i.id, i.kind, i.name, i.sku,
         case when r = 'technician' then null else i.sale_price end,
         coalesce(st.q, 0)::bigint,
         case when r = 'owner' and coalesce(st.q, 0) > 0 then (st.v / st.q)::bigint end,
         case when r = 'owner' then coalesce(st.v, 0)::bigint end,
         i.min_qty, case when r = 'owner' then i.supplier_id end,
         i.min_qty > 0 and coalesce(st.q, 0) <= i.min_qty,
         i.category, i.barcode, i.image_path
  from public.items i
  left join (select m.item_id, sum(m.qty) as q, sum(m.value) as v from public.stock_moves m group by m.item_id) st on st.item_id = i.id
  where i.shop_id = public.current_shop_id() and i.deleted_at is null
  order by i.kind, i.name;
end $$;
revoke execute on function public.items_stock() from public, anon;
grant execute on function public.items_stock() to authenticated;

-- ---------- حركة صنف: كل دخول وخروج بالترتيب، والرصيد بعد كل حركة (صاحب المحل) ----------
create or replace function public.item_moves(p_item uuid) returns table(entry_id uuid, entry_no bigint, at timestamptz, source_type text, memo text, qty bigint, value bigint, balance_qty bigint, balance_value bigint, device_id uuid, order_no text, by text, reversed boolean)
language plpgsql stable security definer set search_path = public as $$
begin
  perform public.ledger_require(array['owner']::public.app_role[]);
  if not exists (select 1 from public.items where id = p_item and shop_id = public.current_shop_id()) then raise exception 'E_NOT_FOUND'; end if;
  return query
  select e.id, e.entry_no, e.occurred_at, e.source_type, e.memo, m.qty::bigint, m.value::bigint,
         (sum(m.qty) over w)::bigint, (sum(m.value) over w)::bigint,
         e.device_id, d.order_no, p.full_name,
         exists (select 1 from public.journal_entries r where r.reverses_id = e.id)
  from public.stock_moves m
  join public.journal_entries e on e.id = m.entry_id
  left join public.devices d on d.id = e.device_id
  left join public.profiles p on p.id = e.created_by
  where m.item_id = p_item
  window w as (order by e.occurred_at, e.entry_no, m.created_at rows unbounded preceding)
  order by e.occurred_at, e.entry_no, m.created_at;
end $$;
revoke execute on function public.item_moves(uuid) from public, anon;
grant execute on function public.item_moves(uuid) to authenticated;

-- ---------- حسابات المخزون لوحده لفترة: الإيراد والتكلفة والربح ----------
-- القيد العكسي بيتحسب مع نوع العملية الأصلية (إلغاء بيع بيقلل المبيعات)
create or replace function public.inventory_summary(p_from timestamptz, p_to timestamptz) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare s uuid := public.current_shop_id(); res jsonb;
begin
  perform public.ledger_require(array['owner']::public.app_role[]);
  with en as (
    select e.id, coalesce(o.source_type, e.source_type) t
    from public.journal_entries e left join public.journal_entries o on o.id = e.reverses_id
    where e.shop_id = s and e.occurred_at >= p_from and e.occurred_at < p_to
  ), ln as (
    select en.t, a.code, sum(l.credit - l.debit) cr from en join public.journal_lines l on l.entry_id = en.id join public.accounts a on a.id = l.account_id
    group by en.t, a.code
  )
  select jsonb_build_object(
    'sales', coalesce((select sum(cr) from ln where t in ('sale', 'sale_return') and code in ('rev_parts', 'rev_accessories')), 0),
    'sales_cost', coalesce((select -sum(cr) from ln where t in ('sale', 'sale_return') and code = 'cogs'), 0),
    'wastage', coalesce((select -sum(cr) from ln where code = 'wastage'), 0),
    'return_diff', coalesce((select -sum(cr) from ln where t = 'supplier_return' and code = 'cogs'), 0),
    'cost_adjust', coalesce((select -sum(cr) from ln where t = 'cost_adjust' and code = 'cogs'), 0),
    'parts_used', coalesce((select -sum(cr) from ln where t = 'part_use' and code = 'cogs'), 0),
    'purchases', coalesce((select -sum(cr) from ln where t = 'purchase' and code = 'inventory'), 0),
    'stock_value', (select coalesce(sum(value), 0) from public.stock_moves where shop_id = s),
    'stock_qty', (select coalesce(sum(qty), 0) from public.stock_moves where shop_id = s),
    'top', coalesce((select jsonb_agg(x order by x.qty desc) from (
        select i.id, i.name, -sum(m.qty)::bigint qty, -sum(m.value)::bigint cost
        from public.stock_moves m join en on en.id = m.entry_id join public.items i on i.id = m.item_id
        where en.t = 'sale' group by i.id, i.name order by -sum(m.qty) desc limit 10) x), '[]'::jsonb)
  ) into res;
  res := res || jsonb_build_object('profit', (res->>'sales')::bigint - (res->>'sales_cost')::bigint - (res->>'wastage')::bigint - (res->>'return_diff')::bigint - (res->>'cost_adjust')::bigint);
  return res;
end $$;
revoke execute on function public.inventory_summary(timestamptz, timestamptz) from public, anon;
grant execute on function public.inventory_summary(timestamptz, timestamptz) to authenticated;

-- ============================== 0028_opening.sql ==============================
-- ============================================================
-- 0028: جرد المحل أول مرة والأرصدة الافتتاحية (البند 4)
-- كل رصيد افتتاحي قيد متوازن (source_type = 'opening') قصاده "رأس المال" (حقوق ملكية):
--   - المخزون: المخزون مدين بالكمية × التكلفة، ورأس المال دائن (وحركة مخزون بنفس القيمة).
--   - الخزنة: الخزنة مدين، ورأس المال دائن.
--   - دين على عميل: العملاء مدين (للعميل)، ورأس المال دائن. ولو المحل هو اللي عليه للعميل (عربون مثلًا): العكس.
--   - دين لمورد: رأس المال مدين، والموردين دائن (للمورد). ولو المورد هو اللي عليه: العكس.
-- فالدفتر بيقفل متوازن دايمًا، وصافي "رأس المال الافتتاحي" = الأصول - الالتزامات.
-- أي رصيد غلط بيتصحح بقيد عكسي زي أي عملية. ونفس الرقم (p_id) لو اتبعت مرتين ما بيتسجلش مرتين.
-- ============================================================

alter table public.journal_entries drop constraint if exists journal_entries_source_type_check;
alter table public.journal_entries add constraint journal_entries_source_type_check check (source_type = any (array[
  'payment', 'delivery', 'purchase', 'supplier_payment', 'part_use', 'sale', 'expense', 'salary', 'salary_payment', 'advance',
  'advance_settle', 'capital', 'drawing', 'transfer', 'drawer_close', 'reversal', 'cost_adjust',
  'write_off', 'supplier_return', 'sale_return', 'opening']));

create or replace function public.opening_balance(p_id uuid, p_kind text, p_ref uuid, p_amount bigint default null, p_lines jsonb default null)
returns uuid
language plpgsql security definer set search_path = public as $$
declare
  s uuid := public.current_shop_id();
  e uuid;
  cap uuid := public.ledger_acc('capital');
  l jsonb; q bigint; u bigint; total bigint := 0;
  lines jsonb;
  memo text;
begin
  perform public.ledger_require(array['owner']::public.app_role[]);
  e := public.ledger_idem(p_id);
  if e is not null then return e; end if;
  if p_kind = 'stock' then
    if jsonb_typeof(p_lines) <> 'array' or jsonb_array_length(p_lines) = 0 then raise exception 'E_BAD_INPUT'; end if;
    for l in select * from jsonb_array_elements(p_lines) loop
      q := (l ->> 'qty')::bigint;
      u := (l ->> 'unit_cost')::bigint;
      if q is null or q <= 0 or q > 100000 or u is null or u < 0 then raise exception 'E_BAD_AMOUNT'; end if;
      if not exists (select 1 from public.items where id = (l ->> 'item')::uuid and shop_id = s and deleted_at is null) then raise exception 'E_NOT_FOUND'; end if;
      total := total + q * u;
    end loop;
    perform public.ledger_amount(total);
    e := public.ledger_post('opening', null, 'stock', jsonb_build_array(public.ledger_line(public.ledger_acc('inventory'), total, 0), public.ledger_line(cap, 0, total)), null, p_id);
    for l in select * from jsonb_array_elements(p_lines) loop
      insert into public.stock_moves(shop_id, item_id, entry_id, qty, value)
      values (s, (l ->> 'item')::uuid, e, (l ->> 'qty')::int, (l ->> 'qty')::bigint * (l ->> 'unit_cost')::bigint);
    end loop;
    return e;
  end if;
  if p_amount is null or p_amount = 0 then raise exception 'E_BAD_AMOUNT'; end if;
  perform public.ledger_amount(abs(p_amount));
  if p_kind = 'cash' then
    if p_amount < 0 then raise exception 'E_BAD_AMOUNT'; end if;
    lines := jsonb_build_array(public.ledger_line((public.ledger_cashbox(p_ref)).id, p_amount, 0), public.ledger_line(cap, 0, p_amount));
  elsif p_kind = 'customer' then
    if not exists (select 1 from public.customers where id = p_ref and shop_id = s and deleted_at is null) then raise exception 'E_NOT_FOUND'; end if;
    -- موجب = العميل عليه للمحل. سالب = المحل عليه للعميل
    lines := jsonb_build_array(
      public.ledger_line(public.ledger_acc('ar'), greatest(p_amount, 0), greatest(-p_amount, 0), 'customer', p_ref),
      public.ledger_line(cap, greatest(-p_amount, 0), greatest(p_amount, 0)));
  elsif p_kind = 'supplier' then
    if not exists (select 1 from public.suppliers where id = p_ref and shop_id = s and deleted_at is null) then raise exception 'E_NOT_FOUND'; end if;
    -- موجب = المحل عليه للمورد. سالب = المورد عليه للمحل
    lines := jsonb_build_array(
      public.ledger_line(public.ledger_acc('ap'), greatest(-p_amount, 0), greatest(p_amount, 0), 'supplier', p_ref),
      public.ledger_line(cap, greatest(p_amount, 0), greatest(-p_amount, 0)));
  else
    raise exception 'E_BAD_INPUT';
  end if;
  memo := p_kind;
  return public.ledger_post('opening', p_ref, memo, lines, null, p_id);
end $$;
revoke execute on function public.opening_balance(uuid, text, uuid, bigint, jsonb) from public, anon;
grant execute on function public.opening_balance(uuid, text, uuid, bigint, jsonb) to authenticated;

-- ملخص الأرصدة الافتتاحية (الساري بس، من غير الملغي): كل نوع لوحده، وصافي رأس المال، والدفتر متوازن ولا لأ
create or replace function public.opening_summary() returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare s uuid := public.current_shop_id(); res jsonb;
begin
  perform public.ledger_require(array['owner']::public.app_role[]);
  with en as (
    select e.id, e.memo from public.journal_entries e
    where e.shop_id = s and e.source_type = 'opening' and not exists (select 1 from public.journal_entries r where r.reverses_id = e.id)
  ), ln as (
    select en.memo, a.code, a.kind, l.debit, l.credit from en join public.journal_lines l on l.entry_id = en.id join public.accounts a on a.id = l.account_id
  )
  select jsonb_build_object(
    'stock', coalesce((select sum(debit - credit) from ln where kind = 'inventory'), 0),
    'stock_items', (select count(distinct m.item_id) from public.stock_moves m join en on en.id = m.entry_id),
    'cash', coalesce((select sum(debit - credit) from ln where kind = 'cash'), 0),
    'receivables', coalesce((select sum(debit - credit) from ln where kind = 'receivable'), 0),
    'payables', coalesce((select sum(credit - debit) from ln where kind = 'payable'), 0),
    'capital', coalesce((select sum(credit - debit) from ln where code = 'capital'), 0),
    'entries', (select count(*) from en),
    'balanced', coalesce((select sum(debit) = sum(credit) from ln), true),
    'done', coalesce((select (extras ->> 'opening_done')::boolean from public.shops where id = s), false)
  ) into res;
  return res;
end $$;
revoke execute on function public.opening_summary() from public, anon;
grant execute on function public.opening_summary() to authenticated;

-- ============================== 0029_partners.sql ==============================
-- ============================================================
-- 0029: الشركاء (البند 5)
-- - كل شريك: الاسم، ورأس ماله، ونسبته من صافي الربح (بالـ 0.01%: من 0 لـ 10000)، وتاريخ دخوله. ومجموع النسب ≤ 100%.
-- - حسابين لكل محل (حقوق ملكية): "رأس مال الشركاء" و"جاري الشركاء"، وكل سطر عليهم باسم الشريك.
--   - إيداع رأس مال: الخزنة مدين، ورأس مال الشريك دائن.
--   - سحب شريك: جاري الشريك (أو رأس ماله) مدين، والخزنة دائن. **مش مصروف**، فما بيقللش الربح.
--   - توزيع الأرباح لفترة: صافي الربح (الإيرادات − المصروفات) × نسبة كل شريك، بيتنقل من "أرباح محتجزة" لجاري الشريك.
--     الباقي (لو النسب أقل من 100%) بيفضل للمحل. والقسمة أعداد صحيحة بالقروش (من غير كسور).
--     ممنوع توزيع نفس الفترة مرتين (إلا لو التوزيع القديم اتلغى بقيد عكسي). والخسارة بتتوزع بنفس الطريقة.
-- - الشريك بيدخل توزيع الفترة لو تاريخ دخوله قبل نهايتها.
-- ============================================================

alter table public.journal_entries drop constraint if exists journal_entries_source_type_check;
alter table public.journal_entries add constraint journal_entries_source_type_check check (source_type = any (array[
  'payment', 'delivery', 'purchase', 'supplier_payment', 'part_use', 'sale', 'expense', 'salary', 'salary_payment', 'advance',
  'advance_settle', 'capital', 'drawing', 'transfer', 'drawer_close', 'reversal', 'cost_adjust',
  'write_off', 'supplier_return', 'sale_return', 'opening', 'partner_capital', 'partner_withdrawal', 'profit_distribution']));
alter table public.accounts drop constraint if exists accounts_kind_check;
alter table public.accounts add constraint accounts_kind_check check (kind = any (array[
  'cash', 'receivable', 'advances', 'inventory', 'payable', 'salaries', 'capital', 'drawings', 'revenue', 'cogs', 'expense', 'shortage', 'overage',
  'partner_capital', 'partner_current', 'retained']));
alter table public.journal_lines drop constraint if exists journal_lines_party_type_check;
alter table public.journal_lines add constraint journal_lines_party_type_check check (party_type = any (array['customer', 'supplier', 'employee', 'partner']));

-- ---------- الشركاء ----------
create table if not exists public.partners (
  id uuid primary key,
  shop_id uuid not null references public.shops(id),
  name text not null check (length(trim(name)) between 1 and 120),
  phone text check (phone is null or length(phone) <= 20),
  share_bp integer not null check (share_bp between 0 and 10000),
  joined_on date not null default current_date,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);
alter table public.partners enable row level security;
revoke all on public.partners from public, anon, authenticated;
grant select, insert, update on public.partners to authenticated;
drop policy if exists partners_select on public.partners;
drop policy if exists partners_insert on public.partners;
drop policy if exists partners_update on public.partners;
create policy partners_select on public.partners for select to authenticated using (shop_id = public.current_shop_id() and public.current_app_role() = 'owner');
create policy partners_insert on public.partners for insert to authenticated with check (shop_id = public.current_shop_id() and public.current_app_role() = 'owner');
create policy partners_update on public.partners for update to authenticated using (shop_id = public.current_shop_id() and public.current_app_role() = 'owner') with check (shop_id = public.current_shop_id());
drop trigger if exists set_updated_at on public.partners;
create trigger set_updated_at before update on public.partners for each row execute function public.tg_set_updated_at();
drop trigger if exists block_delete on public.partners;
create trigger block_delete before delete on public.partners for each row execute function public.tg_block_delete();
drop trigger if exists a_force_shop_id on public.partners;
create trigger a_force_shop_id before insert or update on public.partners for each row execute function public.tg_force_shop_id();
drop trigger if exists zz_audit on public.partners;
create trigger zz_audit after insert or update on public.partners for each row execute function public.tg_audit();

-- مجموع نسب الشركاء الساريين ≤ 100%
create or replace function public.tg_partners_share() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  perform pg_advisory_xact_lock(hashtext('partners:' || new.shop_id::text));
  -- الشريك اللي ليه أو عليه فلوس ما بيتحذفش (سوّي حسابه الأول)
  if tg_op = 'UPDATE' and old.deleted_at is null and new.deleted_at is not null
     and exists (select 1 from public.journal_lines l where l.party_type = 'partner' and l.party_id = new.id group by l.party_id having sum(l.credit - l.debit) <> 0) then
    raise exception 'E_HAS_BALANCE';
  end if;
  if (select coalesce(sum(share_bp), 0) from public.partners where shop_id = new.shop_id and deleted_at is null) > 10000 then
    raise exception 'E_SHARE_OVER_100';
  end if;
  return null;
end $$;
drop trigger if exists zz_partners_share on public.partners;
create constraint trigger zz_partners_share after insert or update on public.partners deferrable initially immediate for each row execute function public.tg_partners_share();

-- ---------- الحسابات ----------
create or replace function public.ensure_partner_accounts(p_shop uuid) returns void
language sql security definer set search_path = public as $$
  insert into public.accounts(shop_id, code, type, kind) values
    (p_shop, 'partners_capital', 'equity', 'partner_capital'),
    (p_shop, 'partners_current', 'equity', 'partner_current'),
    (p_shop, 'retained', 'equity', 'retained')
  on conflict (shop_id, code) where code is not null do nothing
$$;
revoke execute on function public.ensure_partner_accounts(uuid) from public, anon, authenticated;
create or replace function public.tg_shop_partner_accounts() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  perform set_config('warsha.system', 'on', true);
  perform public.ensure_partner_accounts(new.id);
  perform set_config('warsha.system', 'off', true);
  return null;
end $$;
drop trigger if exists zz_shop_partner_accounts on public.shops;
create trigger zz_shop_partner_accounts after insert on public.shops for each row execute function public.tg_shop_partner_accounts();
do $$
declare s uuid;
begin
  perform set_config('warsha.system', 'on', true);
  for s in select id from public.shops loop perform public.ensure_partner_accounts(s); end loop;
  perform set_config('warsha.system', 'off', true);
end $$;

-- ---------- توزيعات الأرباح (عشان نفس الفترة ما تتوزعش مرتين) ----------
create table if not exists public.profit_distributions (
  id uuid primary key,
  shop_id uuid not null references public.shops(id),
  period_from timestamptz not null,
  period_to timestamptz not null check (period_to > period_from),
  profit bigint not null,
  entry_id uuid not null unique references public.journal_entries(id),
  created_by uuid references public.profiles(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);
alter table public.profit_distributions enable row level security;
revoke all on public.profit_distributions from public, anon, authenticated;
grant select on public.profit_distributions to authenticated;
drop policy if exists distributions_select on public.profit_distributions;
create policy distributions_select on public.profit_distributions for select to authenticated using (shop_id = public.current_shop_id() and public.current_app_role() = 'owner');
drop trigger if exists block_delete on public.profit_distributions;
create trigger block_delete before delete on public.profit_distributions for each row execute function public.tg_block_delete();
-- ---------- إيداع رأس مال شريك ----------
create or replace function public.partner_deposit(p_id uuid, p_partner uuid, p_cashbox uuid, p_amount bigint, p_note text default null) returns uuid
language plpgsql security definer set search_path = public as $$
declare cb public.accounts; e uuid;
begin
  perform public.ledger_require(array['owner']::public.app_role[]);
  e := public.ledger_idem(p_id);
  if e is not null then return e; end if;
  perform public.ledger_amount(p_amount);
  cb := public.ledger_cashbox(p_cashbox);
  if not exists (select 1 from public.partners where id = p_partner and shop_id = cb.shop_id and deleted_at is null) then raise exception 'E_NOT_FOUND'; end if;
  return public.ledger_post('partner_capital', p_partner, p_note, jsonb_build_array(
    public.ledger_line(cb.id, p_amount, 0),
    public.ledger_line(public.ledger_acc('partners_capital'), 0, p_amount, 'partner', p_partner)), null, p_id);
end $$;

-- ---------- سحب شريك (مش مصروف): من جاريه، أو من رأس ماله ----------
create or replace function public.partner_withdraw(p_id uuid, p_partner uuid, p_cashbox uuid, p_amount bigint, p_note text default null, p_from_capital boolean default false) returns uuid
language plpgsql security definer set search_path = public as $$
declare cb public.accounts; e uuid;
begin
  perform public.ledger_require(array['owner']::public.app_role[]);
  e := public.ledger_idem(p_id);
  if e is not null then return e; end if;
  perform public.ledger_amount(p_amount);
  cb := public.ledger_cashbox(p_cashbox);
  if not exists (select 1 from public.partners where id = p_partner and shop_id = cb.shop_id) then raise exception 'E_NOT_FOUND'; end if;
  return public.ledger_post('partner_withdrawal', p_partner, p_note, jsonb_build_array(
    public.ledger_line(public.ledger_acc(case when p_from_capital then 'partners_capital' else 'partners_current' end), p_amount, 0, 'partner', p_partner),
    public.ledger_line(cb.id, 0, p_amount)), null, p_id);
end $$;

-- صافي الربح لفترة (الإيرادات − المصروفات) من القيود
create or replace function public.period_profit(p_shop uuid, p_from timestamptz, p_to timestamptz) returns bigint
language sql stable security definer set search_path = public as $$
  select coalesce(sum(l.credit - l.debit), 0)::bigint
  from public.journal_lines l join public.accounts a on a.id = l.account_id join public.journal_entries e on e.id = l.entry_id
  where e.shop_id = p_shop and a.type in ('revenue', 'expense') and e.occurred_at >= p_from and e.occurred_at < p_to
$$;
revoke execute on function public.period_profit(uuid, timestamptz, timestamptz) from public, anon, authenticated;

-- معاينة التوزيع: الربح ونصيب كل شريك (من غير ما يتسجل حاجة)
create or replace function public.profit_split(p_from timestamptz, p_to timestamptz) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare s uuid := public.current_shop_id(); pr bigint;
begin
  perform public.ledger_require(array['owner']::public.app_role[]);
  if p_to <= p_from then raise exception 'E_BAD_INPUT'; end if;
  pr := public.period_profit(s, p_from, p_to);
  return jsonb_build_object(
    'profit', pr,
    'overlap', exists (select 1 from public.profit_distributions d where d.shop_id = s and d.period_from < p_to and d.period_to > p_from
                        and not exists (select 1 from public.journal_entries r where r.reverses_id = d.entry_id)),
    'shares', coalesce((select jsonb_agg(jsonb_build_object('partner', p.id, 'name', p.name, 'share_bp', p.share_bp,
                 'amount', (pr * p.share_bp / 10000)::bigint) order by p.share_bp desc, p.name)
               from public.partners p where p.shop_id = s and p.deleted_at is null and p.joined_on <= ((p_to - interval '1 microsecond') at time zone 'Africa/Cairo')::date), '[]'::jsonb));
end $$;

-- التوزيع نفسه
create or replace function public.distribute_profit(p_id uuid, p_from timestamptz, p_to timestamptz) returns uuid
language plpgsql security definer set search_path = public as $$
declare s uuid := public.current_shop_id(); e uuid; sp jsonb; x jsonb; total bigint := 0; amt bigint; lines jsonb := '[]'::jsonb; pr bigint;
begin
  perform public.ledger_require(array['owner']::public.app_role[]);
  e := public.ledger_idem(p_id);
  if e is not null then return e; end if;
  perform pg_advisory_xact_lock(hashtext('distribute:' || s::text));
  sp := public.profit_split(p_from, p_to);
  if (sp ->> 'overlap')::boolean then raise exception 'E_PERIOD_DISTRIBUTED'; end if;
  pr := (sp ->> 'profit')::bigint;
  for x in select * from jsonb_array_elements(sp -> 'shares') loop
    amt := (x ->> 'amount')::bigint;
    if amt = 0 then continue; end if;
    total := total + amt;
    lines := lines || jsonb_build_array(public.ledger_line(public.ledger_acc('partners_current'), greatest(-amt, 0), greatest(amt, 0), 'partner', (x ->> 'partner')::uuid));
  end loop;
  if total = 0 then raise exception 'E_NOTHING_TO_DISTRIBUTE'; end if;
  lines := lines || jsonb_build_array(public.ledger_line(public.ledger_acc('retained'), greatest(total, 0), greatest(-total, 0)));
  e := public.ledger_post('profit_distribution', null, to_char(p_from at time zone 'Africa/Cairo', 'YYYY-MM-DD') || ' → ' || to_char((p_to - interval '1 second') at time zone 'Africa/Cairo', 'YYYY-MM-DD'), lines, null, p_id);
  insert into public.profit_distributions(id, shop_id, period_from, period_to, profit, entry_id, created_by) values (p_id, s, p_from, p_to, pr, e, auth.uid());
  return e;
end $$;

-- أرصدة الشركاء: رأس المال، والجاري، والإجمالي (اللي ليه عند المحل)
create or replace function public.partner_balances() returns table(id uuid, name text, phone text, share_bp integer, joined_on date, capital bigint, current bigint, total bigint)
language plpgsql stable security definer set search_path = public as $$
begin
  perform public.ledger_require(array['owner']::public.app_role[]);
  return query
  select p.id, p.name, p.phone, p.share_bp, p.joined_on,
         coalesce(sum(l.credit - l.debit) filter (where a.kind = 'partner_capital'), 0)::bigint,
         coalesce(sum(l.credit - l.debit) filter (where a.kind = 'partner_current'), 0)::bigint,
         coalesce(sum(l.credit - l.debit), 0)::bigint
  from public.partners p
  left join public.journal_lines l on l.party_type = 'partner' and l.party_id = p.id
  left join public.accounts a on a.id = l.account_id
  where p.shop_id = public.current_shop_id() and p.deleted_at is null
  group by p.id
  order by p.share_bp desc, p.name;
end $$;

do $$
declare f text;
begin
  foreach f in array array['partner_deposit(uuid, uuid, uuid, bigint, text)', 'partner_withdraw(uuid, uuid, uuid, bigint, text, boolean)',
    'profit_split(timestamptz, timestamptz)', 'distribute_profit(uuid, timestamptz, timestamptz)', 'partner_balances()'] loop
    execute format('revoke execute on function public.%s from public, anon', f);
    execute format('grant execute on function public.%s to authenticated', f);
  end loop;
end $$;

-- (0029) نفس ledger_post من 0008، والفرق: حسابات الشركاء لازم يبقى معاها الشريك
create or replace function public.ledger_post(
  p_source_type text, p_source_id uuid, p_memo text, p_lines jsonb,
  p_device uuid default null, p_idem uuid default null, p_reverses uuid default null
) returns uuid
language plpgsql security definer set search_path = public as $$
declare
  s uuid := public.current_shop_id();
  e uuid := gen_random_uuid();
  l jsonb;
  a public.accounts;
  d bigint := 0;
  c bigint := 0;
  ld bigint;
  lc bigint;
begin
  if s is null then raise exception 'E_NO_SHOP'; end if;
  if jsonb_typeof(p_lines) <> 'array' or jsonb_array_length(p_lines) < 2 then raise exception 'E_UNBALANCED'; end if;
  insert into public.journal_entries(id, shop_id, source_type, source_id, device_id, memo, idem_key, reverses_id, created_by)
  values (e, s, p_source_type, p_source_id, p_device, nullif(trim(p_memo), ''), p_idem, p_reverses, auth.uid());
  for l in select * from jsonb_array_elements(p_lines) loop
    select * into a from public.accounts where id = (l ->> 'account')::uuid and shop_id = s and deleted_at is null;
    if not found then raise exception 'E_BAD_ACCOUNT'; end if;
    ld := coalesce((l ->> 'debit')::bigint, 0);
    lc := coalesce((l ->> 'credit')::bigint, 0);
    if ld < 0 or lc < 0 or (ld > 0) = (lc > 0) then raise exception 'E_BAD_AMOUNT'; end if;
    -- العملاء والموردين والموظفين والشركاء لازم يبقى معاهم الطرف
    if a.kind in ('receivable', 'payable', 'advances', 'salaries', 'partner_capital', 'partner_current') and (l ->> 'party_id') is null then raise exception 'E_BAD_INPUT'; end if;
    insert into public.journal_lines(shop_id, entry_id, account_id, party_type, party_id, debit, credit)
    values (s, e, a.id, l ->> 'party_type', (l ->> 'party_id')::uuid, ld, lc);
    d := d + ld;
    c := c + lc;
  end loop;
  if d <> c or d = 0 then raise exception 'E_UNBALANCED'; end if;
  return e;
end $$;

-- (0029) نفس statement من 0008، والفرق: كشف حساب الشريك
create or replace function public.statement(p_kind text, p_id uuid, p_from timestamptz, p_to timestamptz) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare
  s uuid := public.current_shop_id();
  accs uuid[];
  opening bigint;
  res jsonb;
begin
  perform public.ledger_require(array['owner']::public.app_role[]);
  if p_kind = 'cashbox' then
    select array_agg(id) into accs from public.accounts where id = p_id and shop_id = s and kind = 'cash';
  elsif p_kind = 'customer' then
    select array_agg(id) into accs from public.accounts where shop_id = s and kind = 'receivable';
  elsif p_kind = 'supplier' then
    select array_agg(id) into accs from public.accounts where shop_id = s and kind = 'payable';
  elsif p_kind = 'employee' then
    select array_agg(id) into accs from public.accounts where shop_id = s and kind in ('advances', 'salaries');
  elsif p_kind = 'partner' then
    -- (0029) كشف الشريك: رأس ماله وحسابه الجاري. الرصيد = اللي ليه عند المحل
    select array_agg(id) into accs from public.accounts where shop_id = s and kind in ('partner_capital', 'partner_current');
  else
    raise exception 'E_BAD_INPUT';
  end if;
  if accs is null then raise exception 'E_NOT_FOUND'; end if;
  -- الرصيد: للخزنة والعميل والسلف = مدين − دائن. للمورد والمرتبات = دائن − مدين (الطرف الطبيعي)
  select coalesce(sum((l.debit - l.credit) * public.account_sign(a.type)), 0) into opening
  from public.journal_lines l join public.accounts a on a.id = l.account_id join public.journal_entries e on e.id = l.entry_id
  where l.account_id = any(accs) and (p_kind = 'cashbox' or l.party_id = p_id) and e.occurred_at < p_from;
  with mv as (
    select e.id as entry_id, e.entry_no, e.occurred_at, e.source_type, e.source_id, e.device_id, e.memo, e.reverses_id,
           d.order_no, p.full_name as by_name, a.code as account_code,
           ((l.debit - l.credit) * public.account_sign(a.type))::bigint as amount
    from public.journal_lines l
    join public.accounts a on a.id = l.account_id
    join public.journal_entries e on e.id = l.entry_id
    left join public.devices d on d.id = e.device_id
    left join public.profiles p on p.id = e.created_by
    where l.account_id = any(accs) and (p_kind = 'cashbox' or l.party_id = p_id) and e.occurred_at >= p_from and e.occurred_at < p_to
  ),
  mv2 as (select mv.*, opening + sum(amount) over (order by occurred_at, entry_no rows unbounded preceding) as running from mv)
  select jsonb_build_object('opening', opening, 'moves', coalesce(jsonb_agg(jsonb_build_object(
      'entry_id', entry_id, 'entry_no', entry_no, 'at', occurred_at, 'source_type', source_type, 'source_id', source_id,
      'device_id', device_id, 'order_no', order_no, 'memo', memo, 'by', by_name, 'account', account_code, 'amount', amount,
      'reversed', exists (select 1 from public.journal_entries r where r.reverses_id = entry_id), 'reverses', reverses_id,
      'balance', running) order by occurred_at, entry_no), '[]'::jsonb))
  into res from mv2;
  return res;
end $$;

-- (0029) نفس integrity_report من 0025، والفرق: سطور الشركاء من غير الشريك بتظهر كمشكلة
create or replace function public.integrity_report() returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare s uuid := public.current_shop_id(); out jsonb := '[]'::jsonb; r record; inv bigint; mv bigint;
begin
  perform public.ledger_require(array['owner']::public.app_role[]);
  -- 1) قيد مش متوازن، أو ناقص طرف (أقل من سطرين)
  for r in select e.id, e.entry_no, coalesce(sum(l.debit), 0) - coalesce(sum(l.credit), 0) diff, count(l.id) n
           from public.journal_entries e left join public.journal_lines l on l.entry_id = e.id
           where e.shop_id = s group by e.id having coalesce(sum(l.debit), 0) <> coalesce(sum(l.credit), 0) or count(l.id) < 2 loop
    out := out || jsonb_build_array(jsonb_build_object('kind', case when r.n < 2 then 'entry_missing_side' else 'entry_unbalanced' end, 'amount', abs(r.diff), 'entry_id', r.id, 'entry_no', r.entry_no));
  end loop;
  -- 2) قيمة المخزون في الدفتر = مجموع حركات المخزون
  select coalesce(sum(l.debit - l.credit), 0) into inv from public.journal_lines l join public.accounts a on a.id = l.account_id where a.shop_id = s and a.kind = 'inventory';
  select coalesce(sum(m.value), 0) into mv from public.stock_moves m where m.shop_id = s;
  if inv <> mv then out := out || jsonb_build_array(jsonb_build_object('kind', 'inventory_ledger', 'amount', abs(inv - mv), 'ledger', inv, 'stock', mv)); end if;
  -- 3) كل صنف: الكمية مش بالسالب، ومفيش قيمة من غير كمية، ومفيش قيمة بالسالب
  for r in select i.id, i.name, coalesce(sum(m.qty), 0) q, coalesce(sum(m.value), 0) v from public.items i left join public.stock_moves m on m.item_id = i.id
           where i.shop_id = s group by i.id having coalesce(sum(m.qty), 0) < 0 or (coalesce(sum(m.qty), 0) = 0 and coalesce(sum(m.value), 0) <> 0) or coalesce(sum(m.value), 0) < 0 loop
    out := out || jsonb_build_array(jsonb_build_object('kind', 'item_value', 'amount', abs(r.v), 'item_id', r.id, 'item', r.name, 'qty', r.q, 'value', r.v));
  end loop;
  -- 4) كل حركة مخزون بقيمتها في قيد على حساب المخزون بنفس المبلغ
  for r in select m.entry_id, e.entry_no, sum(m.value) mvv,
                  (select coalesce(sum(l.debit - l.credit), 0) from public.journal_lines l join public.accounts a on a.id = l.account_id where l.entry_id = m.entry_id and a.kind = 'inventory') lv
           from public.stock_moves m join public.journal_entries e on e.id = m.entry_id where m.shop_id = s group by m.entry_id, e.entry_no loop
    if r.mvv <> r.lv then out := out || jsonb_build_array(jsonb_build_object('kind', 'stock_entry', 'amount', abs(r.mvv - r.lv), 'entry_id', r.entry_id, 'entry_no', r.entry_no)); end if;
  end loop;
  -- 5) كل دفعة مبلغها = المبلغ اللي دخل الخزنة في قيدها
  for r in select p.id, p.amount, p.entry_id, e.entry_no,
                  (select coalesce(sum(l.debit), 0) from public.journal_lines l join public.accounts a on a.id = l.account_id where l.entry_id = p.entry_id and a.kind = 'cash') cash
           from public.payments p join public.journal_entries e on e.id = p.entry_id where p.shop_id = s loop
    if r.cash <> r.amount then out := out || jsonb_build_array(jsonb_build_object('kind', 'payment_entry', 'amount', abs(r.cash - r.amount), 'entry_id', r.entry_id, 'entry_no', r.entry_no)); end if;
  end loop;
  -- 6) حسابات العملاء والموردين والموظفين: كل سطر عليه طرف (عشان رصيد كل واحد = كشف حسابه)
  for r in select l.entry_id, e.entry_no, sum(l.debit + l.credit) amt from public.journal_lines l join public.accounts a on a.id = l.account_id join public.journal_entries e on e.id = l.entry_id
           where l.shop_id = s and a.kind in ('receivable', 'payable', 'advances', 'salaries', 'partner_capital', 'partner_current') and l.party_id is null group by l.entry_id, e.entry_no loop
    out := out || jsonb_build_array(jsonb_build_object('kind', 'party_missing', 'amount', r.amt, 'entry_id', r.entry_id, 'entry_no', r.entry_no));
  end loop;
  -- 7) كل سطر في نفس محل القيد
  for r in select l.entry_id, e.entry_no from public.journal_lines l join public.journal_entries e on e.id = l.entry_id where e.shop_id = s and l.shop_id <> e.shop_id group by 1, 2 loop
    out := out || jsonb_build_array(jsonb_build_object('kind', 'shop_mismatch', 'amount', 0, 'entry_id', r.entry_id, 'entry_no', r.entry_no));
  end loop;
  return out;
end $$;

-- (0029) نفس opening_balance من 0028، والفرق: رأس مال الشريك في الجرد
create or replace function public.opening_balance(p_id uuid, p_kind text, p_ref uuid, p_amount bigint default null, p_lines jsonb default null)
returns uuid
language plpgsql security definer set search_path = public as $$
declare
  s uuid := public.current_shop_id();
  e uuid;
  cap uuid := public.ledger_acc('capital');
  l jsonb; q bigint; u bigint; total bigint := 0;
  lines jsonb;
  memo text;
begin
  perform public.ledger_require(array['owner']::public.app_role[]);
  e := public.ledger_idem(p_id);
  if e is not null then return e; end if;
  if p_kind = 'stock' then
    if jsonb_typeof(p_lines) <> 'array' or jsonb_array_length(p_lines) = 0 then raise exception 'E_BAD_INPUT'; end if;
    for l in select * from jsonb_array_elements(p_lines) loop
      q := (l ->> 'qty')::bigint;
      u := (l ->> 'unit_cost')::bigint;
      if q is null or q <= 0 or q > 100000 or u is null or u < 0 then raise exception 'E_BAD_AMOUNT'; end if;
      if not exists (select 1 from public.items where id = (l ->> 'item')::uuid and shop_id = s and deleted_at is null) then raise exception 'E_NOT_FOUND'; end if;
      total := total + q * u;
    end loop;
    perform public.ledger_amount(total);
    e := public.ledger_post('opening', null, 'stock', jsonb_build_array(public.ledger_line(public.ledger_acc('inventory'), total, 0), public.ledger_line(cap, 0, total)), null, p_id);
    for l in select * from jsonb_array_elements(p_lines) loop
      insert into public.stock_moves(shop_id, item_id, entry_id, qty, value)
      values (s, (l ->> 'item')::uuid, e, (l ->> 'qty')::int, (l ->> 'qty')::bigint * (l ->> 'unit_cost')::bigint);
    end loop;
    return e;
  end if;
  if p_amount is null or p_amount = 0 then raise exception 'E_BAD_AMOUNT'; end if;
  perform public.ledger_amount(abs(p_amount));
  if p_kind = 'cash' then
    if p_amount < 0 then raise exception 'E_BAD_AMOUNT'; end if;
    lines := jsonb_build_array(public.ledger_line((public.ledger_cashbox(p_ref)).id, p_amount, 0), public.ledger_line(cap, 0, p_amount));
  elsif p_kind = 'customer' then
    if not exists (select 1 from public.customers where id = p_ref and shop_id = s and deleted_at is null) then raise exception 'E_NOT_FOUND'; end if;
    -- موجب = العميل عليه للمحل. سالب = المحل عليه للعميل
    lines := jsonb_build_array(
      public.ledger_line(public.ledger_acc('ar'), greatest(p_amount, 0), greatest(-p_amount, 0), 'customer', p_ref),
      public.ledger_line(cap, greatest(-p_amount, 0), greatest(p_amount, 0)));
  elsif p_kind = 'supplier' then
    if not exists (select 1 from public.suppliers where id = p_ref and shop_id = s and deleted_at is null) then raise exception 'E_NOT_FOUND'; end if;
    -- موجب = المحل عليه للمورد. سالب = المورد عليه للمحل
    lines := jsonb_build_array(
      public.ledger_line(public.ledger_acc('ap'), greatest(-p_amount, 0), greatest(p_amount, 0), 'supplier', p_ref),
      public.ledger_line(cap, greatest(p_amount, 0), greatest(-p_amount, 0)));
  elsif p_kind = 'partner' then
    -- (0029) رأس مال شريك وقت الجرد: جزء من رأس المال الافتتاحي بيتنقل لحساب الشريك
    if p_amount < 0 then raise exception 'E_BAD_AMOUNT'; end if;
    if not exists (select 1 from public.partners where id = p_ref and shop_id = s and deleted_at is null) then raise exception 'E_NOT_FOUND'; end if;
    lines := jsonb_build_array(public.ledger_line(cap, p_amount, 0), public.ledger_line(public.ledger_acc('partners_capital'), 0, p_amount, 'partner', p_ref));
  else
    raise exception 'E_BAD_INPUT';
  end if;
  memo := p_kind;
  return public.ledger_post('opening', p_ref, memo, lines, null, p_id);
end $$;

-- (0029) النسخة الاحتياطية والاسترجاع: نفس 0019 و0023، والفرق إن الشركاء وتوزيعات الأرباح بقوا جوه النسخة
create or replace function public.backup_snapshot(p_shop uuid) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare
  res jsonb := jsonb_build_object('format', 'warsha-backup', 'version', 1, 'generated_at', now(), 'shop_id', p_shop);
  t text;
  rows jsonb;
begin
  foreach t in array array['shops', 'shop_branding', 'profiles', 'customers', 'devices', 'device_costs', 'status_log', 'device_notes', 'device_photos', 'device_checks',
                           'quote_decisions', 'message_templates', 'message_log', 'accounts', 'journal_entries', 'journal_lines', 'payments', 'drawer_closings',
                           'suppliers', 'items', 'stock_moves', 'purchases', 'labor_rates', 'specialties', 'staff_specialties', 'routes', 'repair_steps',
                           'repair_videos', 'device_ratings', 'issue_presets', 'partners', 'profit_distributions', 'audit_log'] loop
    execute format('select coalesce(jsonb_agg(to_jsonb(x)), ''[]''::jsonb) from public.%I x where x.shop_id = $1', t) into rows using p_shop;
    res := res || jsonb_build_object(t, rows);
  end loop;
  select coalesce(jsonb_agg(jsonb_build_object('device_id', device_id, 'kind', kind, 'erased_at', erased_at)), '[]'::jsonb)
    into rows from public.device_passcodes where shop_id = p_shop;
  return res || jsonb_build_object('device_passcodes', rows);
end $$;
revoke execute on function public.backup_snapshot(uuid) from public, anon, authenticated;

create or replace function public.restore_backup(p_data jsonb) returns jsonb
-- extensions: فيها gen_random_bytes على Supabase
language plpgsql security definer set search_path = public, extensions, pg_temp as $$
declare
  s uuid := public.current_shop_id();
  me uuid := auth.uid();
  old_shop uuid;
  old_owner uuid;
  sh jsonb;
  t text;
  r jsonb;
  rows jsonb;
  n int;
  bad int;
  counts jsonb := '{}'::jsonb;
  -- بالترتيب ده عشان كل صف يلاقي اللي بيشاور عليه
  tabs text[] := array['profiles', 'shop_branding', 'accounts', 'customers', 'suppliers', 'partners', 'specialties', 'staff_specialties', 'routes', 'labor_rates',
                       'issue_presets', 'message_templates', 'items', 'devices', 'device_costs', 'status_log', 'device_notes', 'device_checks',
                       'quote_decisions', 'repair_steps', 'repair_videos', 'device_ratings', 'journal_entries', 'journal_lines', 'profit_distributions', 'payments',
                       'purchases', 'stock_moves', 'drawer_closings', 'message_log', 'audit_log'];
  -- الجداول دي ليها نسخة اتعملت مع التسجيل: بتتطابق بالكود (أو المفتاح) وبتاخد قيم النسخة
  keyed text[] := array['accounts', 'routes', 'specialties', 'message_templates', 'labor_rates', 'shop_branding'];
begin
  perform public.ledger_require(array['owner']::public.app_role[]);
  if s is null or me is null then raise exception 'E_FORBIDDEN'; end if;
  if p_data is null or p_data->>'format' is distinct from 'warsha-backup' or coalesce((p_data->>'version')::int, 0) <> 1 then
    raise exception 'E_BACKUP_FORMAT';
  end if;
  old_shop := (p_data->>'shop_id')::uuid;
  if old_shop is null or old_shop = s then raise exception 'E_BACKUP_FORMAT'; end if;

  -- محل جديد فاضي بس
  if exists (select 1 from public.devices where shop_id = s) or exists (select 1 from public.customers where shop_id = s)
     or exists (select 1 from public.journal_entries where shop_id = s) or exists (select 1 from public.items where shop_id = s)
     or exists (select 1 from public.suppliers where shop_id = s) or exists (select 1 from public.payments where shop_id = s)
     or exists (select 1 from public.purchases where shop_id = s) or exists (select 1 from public.drawer_closings where shop_id = s)
     or exists (select 1 from public.stock_moves where shop_id = s)
     or exists (select 1 from public.profiles where shop_id = s and id <> me) then
    raise exception 'E_RESTORE_NOT_EMPTY';
  end if;

  perform set_config('warsha.restore', 'on', true);
  drop table if exists pg_temp._rmap;
  create temp table _rmap(old uuid primary key, new uuid not null) on commit drop;
  insert into _rmap values (old_shop, s);

  -- 1) بيانات المحل نفسه (من غير الخطة والإيقاف واللوجو اللي في Storage)
  sh := p_data->'shops'->0;
  if sh is not null then
    update public.shops set
      name = coalesce(sh->>'name', name), phone = sh->>'phone', address = sh->>'address',
      receipt_terms = coalesce(sh->>'receipt_terms', receipt_terms), warranty_days = coalesce((sh->>'warranty_days')::int, warranty_days),
      country = coalesce(sh->>'country', country), currency = coalesce(sh->>'currency', currency),
      payment_methods = coalesce(array(select jsonb_array_elements_text(sh->'payment_methods')), payment_methods),
      theme = coalesce(sh->>'theme', theme), locale = coalesce(sh->>'locale', locale),
      default_margin_pct = coalesce((sh->>'default_margin_pct')::int, default_margin_pct),
      extras = coalesce(sh->'extras', extras), max_discount_pct = coalesce((sh->>'max_discount_pct')::int, max_discount_pct)
    where id = s;
  end if;

  -- 2) الـ ids الجديدة
  -- صاحب المحل في النسخة = اللي بيسترجع دلوقتي
  select (x->>'id')::uuid into old_owner from jsonb_array_elements(coalesce(p_data->'profiles', '[]')) x
   where x->>'role' = 'owner' order by x->>'created_at' limit 1;
  if old_owner is not null then insert into _rmap values (old_owner, me) on conflict do nothing; end if;
  insert into _rmap select (x->>'id')::uuid, coalesce((select a.id from public.accounts a where a.shop_id = s and a.code = x->>'code' and x->>'code' is not null), gen_random_uuid())
    from jsonb_array_elements(coalesce(p_data->'accounts', '[]')) x on conflict do nothing;
  insert into _rmap select (x->>'id')::uuid, coalesce((select a.id from public.routes a where a.shop_id = s and a.code = x->>'code' and x->>'code' is not null), gen_random_uuid())
    from jsonb_array_elements(coalesce(p_data->'routes', '[]')) x on conflict do nothing;
  insert into _rmap select (x->>'id')::uuid, coalesce((select a.id from public.specialties a where a.shop_id = s and a.code = x->>'code' and x->>'code' is not null), gen_random_uuid())
    from jsonb_array_elements(coalesce(p_data->'specialties', '[]')) x on conflict do nothing;
  insert into _rmap select (x->>'id')::uuid, coalesce((select a.id from public.message_templates a where a.shop_id = s and a.key = x->>'key'), gen_random_uuid())
    from jsonb_array_elements(coalesce(p_data->'message_templates', '[]')) x on conflict do nothing;
  insert into _rmap select (x->>'id')::uuid, coalesce((select a.id from public.labor_rates a where a.shop_id = s and a.deleted_at is null and lower(trim(a.issue)) = lower(trim(x->>'issue')) and x->>'deleted_at' is null), gen_random_uuid())
    from jsonb_array_elements(coalesce(p_data->'labor_rates', '[]')) x on conflict do nothing;
  insert into _rmap select (x->>'id')::uuid, coalesce((select a.id from public.shop_branding a where a.shop_id = s), gen_random_uuid())
    from jsonb_array_elements(coalesce(p_data->'shop_branding', '[]')) x on conflict do nothing;
  foreach t in array tabs loop
    insert into _rmap select (x->>'id')::uuid, gen_random_uuid() from jsonb_array_elements(coalesce(p_data->t, '[]')) x where x ? 'id' on conflict do nothing;
  end loop;

  -- 3) الصفوف نفسها بالترتيب
  foreach t in array tabs loop
    rows := '[]'::jsonb;
    for r in select public.restore_remap(x) from jsonb_array_elements(coalesce(p_data->t, '[]')) x loop
      if t = 'profiles' then
        -- صاحب المحل موجود أصلًا. الباقيين موظفين سابقين (من غير حساب دخول)
        continue when (r->>'id')::uuid = me;
        r := r || jsonb_build_object('deleted_at', coalesce(r->>'deleted_at', now()::text));
      elsif t = 'devices' then
        -- كود التتبع (الـ QR) بيفضل زي ما هو، إلا لو مستخدم في المشروع ده (المحل الأصلي لسه هنا)
        if exists (select 1 from public.devices d where d.tracking_token = r->>'tracking_token') then
          r := r || jsonb_build_object('tracking_token', encode(gen_random_bytes(12), 'hex'));
        end if;
      elsif t = 'journal_entries' then
        if r->>'idem_key' is not null and exists (select 1 from public.journal_entries j where j.idem_key = (r->>'idem_key')::uuid) then
          r := r || jsonb_build_object('idem_key', gen_random_uuid());
        end if;
      elsif t = 'shop_branding' then
        -- اللوجو الملون والحراري جوه الصف نفسه. الملف الأصلي في Storage مش جوه النسخة
        r := r || jsonb_build_object('logo_path', null);
      end if;
      if t = any (keyed) and exists (select 1 from _rmap m where m.new = (r->>'id')::uuid and m.old <> m.new)
         and (t <> 'shop_branding' or exists (select 1 from public.shop_branding b where b.id = (r->>'id')::uuid)) then
        -- موجود من التسجيل: بياخد قيم النسخة
        execute format('select count(*) from public.%I where id = $1', t) into n using (r->>'id')::uuid;
        if n > 0 then
          execute format('update public.%1$I x set (%2$s) = (select %2$s from jsonb_populate_record(null::public.%1$I, $1)) where x.id = $2', t,
            (select string_agg(quote_ident(c.column_name), ', ' order by c.ordinal_position) from information_schema.columns c
              where c.table_schema = 'public' and c.table_name = t and c.column_name not in ('id', 'shop_id')))
            using r, (r->>'id')::uuid;
          continue;
        end if;
      end if;
      rows := rows || jsonb_build_array(r);
    end loop;
    if jsonb_array_length(rows) > 0 then
      -- overriding system value: أرقام القيود (entry_no) بترجع زي ما هي
      execute format('insert into public.%1$I overriding system value select * from jsonb_populate_recordset(null::public.%1$I, $1)', t) using rows;
    end if;
    counts := counts || jsonb_build_object(t, jsonb_array_length(coalesce(p_data->t, '[]')));
  end loop;

  -- 4) عدّاد أرقام الطلبات: من آخر رقم راجع في كل سنة
  insert into public.order_counters(shop_id, year, last_value)
  select s, split_part(order_no, '-', 1)::int, max(split_part(order_no, '-', 2)::int)
    from public.devices where shop_id = s and order_no ~ '^\d{4}-\d+$' group by 2
  on conflict (shop_id, year) do update set last_value = greatest(public.order_counters.last_value, excluded.last_value);

  -- 5) التأكد: كل قيد متوازن، ورصيد كل حساب = رصيده في النسخة بالظبط
  select count(*) into bad from (
    select entry_id from public.journal_lines where shop_id = s group by entry_id having sum(debit) <> sum(credit)) x;
  if bad > 0 then raise exception 'E_RESTORE_UNBALANCED'; end if;
  select count(*) into bad from (
    select m.new acc, sum((l->>'debit')::bigint - (l->>'credit')::bigint) b
      from jsonb_array_elements(coalesce(p_data->'journal_lines', '[]')) l join _rmap m on m.old = (l->>'account_id')::uuid group by m.new
  ) x full join (select account_id, sum(debit - credit) b from public.journal_lines where shop_id = s group by account_id) y on y.account_id = x.acc
  where coalesce(x.b, 0) <> coalesce(y.b, 0);
  if bad > 0 then raise exception 'E_RESTORE_MISMATCH'; end if;
  -- وعدد الصفوف في كل جدول (الحسابات والقوالب اللي اتعملت مع التسجيل ممكن تزيد عن النسخة، مش تقل)
  foreach t in array tabs loop
    execute format('select count(*) from public.%I where shop_id = $1', t) into n using s;
    if n < jsonb_array_length(coalesce(p_data->t, '[]')) - (case when t = 'profiles' and old_owner is not null then 1 else 0 end) then
      raise exception 'E_RESTORE_MISMATCH';
    end if;
  end loop;

  perform set_config('warsha.restore', 'off', true);
  insert into public.audit_log(shop_id, actor_id, action, entity, entity_id, after)
  values (s, me, 'backup_restore', 'shops', s, jsonb_build_object('from_shop', old_shop, 'generated_at', p_data->>'generated_at', 'counts', counts));
  return jsonb_build_object('restored', true, 'counts', counts);
end $$;
revoke execute on function public.restore_backup(jsonb) from public, anon;
grant execute on function public.restore_backup(jsonb) to authenticated;

-- (0029) نفس opening_summary من 0028، والفرق: رأس مال الشركاء في الجرد بيظهر لوحده (والإجمالي زي ما هو)
create or replace function public.opening_summary() returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare s uuid := public.current_shop_id(); res jsonb;
begin
  perform public.ledger_require(array['owner']::public.app_role[]);
  with en as (
    select e.id, e.memo from public.journal_entries e
    where e.shop_id = s and e.source_type = 'opening' and not exists (select 1 from public.journal_entries r where r.reverses_id = e.id)
  ), ln as (
    select en.memo, a.code, a.kind, l.debit, l.credit from en join public.journal_lines l on l.entry_id = en.id join public.accounts a on a.id = l.account_id
  )
  select jsonb_build_object(
    'stock', coalesce((select sum(debit - credit) from ln where kind = 'inventory'), 0),
    'stock_items', (select count(distinct m.item_id) from public.stock_moves m join en on en.id = m.entry_id),
    'cash', coalesce((select sum(debit - credit) from ln where kind = 'cash'), 0),
    'receivables', coalesce((select sum(debit - credit) from ln where kind = 'receivable'), 0),
    'payables', coalesce((select sum(credit - debit) from ln where kind = 'payable'), 0),
    -- (0029) رأس مال المحل الافتتاحي كله = رأس المال + اللي اتنقل للشركاء
    'capital', coalesce((select sum(credit - debit) from ln where code in ('capital', 'partners_capital')), 0),
    'partners', coalesce((select sum(credit - debit) from ln where code = 'partners_capital'), 0),
    'entries', (select count(*) from en),
    'balanced', coalesce((select sum(debit) = sum(credit) from ln), true),
    'done', coalesce((select (extras ->> 'opening_done')::boolean from public.shops where id = s), false)
  ) into res;
  return res;
end $$;

-- ============================== 0030_party_links.sql ==============================
-- ============================================================
-- 0030: ربط عميل بمورد (البند 6)
-- نفس الشخص ممكن يكون عميل (بيصلّح أو بيشتري) ومورد (بيبيعلنا قطع). بالربط:
-- - كشف واحد بالرصيد الصافي: اللي عليه كعميل − اللي ليه كمورد.
-- - مقاصة: قيد متوازن (الموردين مدين، والعملاء دائن) بيخصم الدينين من بعض، لحد أقل رصيد فيهم. وبتتلغي بقيد عكسي.
-- - فك الربط في أي وقت (حذف ناعم للربط بس)، والقيود والكشوف القديمة زي ما هي.
-- كل عميل أو مورد ليه ربط واحد ساري بس.
-- ============================================================

alter table public.journal_entries drop constraint if exists journal_entries_source_type_check;
alter table public.journal_entries add constraint journal_entries_source_type_check check (source_type = any (array[
  'payment', 'delivery', 'purchase', 'supplier_payment', 'part_use', 'sale', 'expense', 'salary', 'salary_payment', 'advance',
  'advance_settle', 'capital', 'drawing', 'transfer', 'drawer_close', 'reversal', 'cost_adjust',
  'write_off', 'supplier_return', 'sale_return', 'opening', 'partner_capital', 'partner_withdrawal', 'profit_distribution', 'netting']));

create table if not exists public.party_links (
  id uuid primary key,
  shop_id uuid not null references public.shops(id),
  customer_id uuid not null references public.customers(id),
  supplier_id uuid not null references public.suppliers(id),
  created_by uuid references public.profiles(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);
create unique index if not exists party_links_customer on public.party_links(customer_id) where deleted_at is null;
create unique index if not exists party_links_supplier on public.party_links(supplier_id) where deleted_at is null;
alter table public.party_links enable row level security;
revoke all on public.party_links from public, anon, authenticated;
grant select on public.party_links to authenticated;
drop policy if exists party_links_select on public.party_links;
create policy party_links_select on public.party_links for select to authenticated using (shop_id = public.current_shop_id() and public.current_app_role() = 'owner');
drop trigger if exists set_updated_at on public.party_links;
create trigger set_updated_at before update on public.party_links for each row execute function public.tg_set_updated_at();
drop trigger if exists block_delete on public.party_links;
create trigger block_delete before delete on public.party_links for each row execute function public.tg_block_delete();
drop trigger if exists zz_audit on public.party_links;
create trigger zz_audit after insert or update on public.party_links for each row execute function public.tg_audit();

create or replace function public.link_parties(p_id uuid, p_customer uuid, p_supplier uuid) returns uuid
language plpgsql security definer set search_path = public as $$
declare s uuid := public.current_shop_id();
begin
  perform public.ledger_require(array['owner']::public.app_role[]);
  if exists (select 1 from public.party_links where id = p_id) then return p_id; end if;
  if not exists (select 1 from public.customers where id = p_customer and shop_id = s and deleted_at is null)
     or not exists (select 1 from public.suppliers where id = p_supplier and shop_id = s and deleted_at is null) then raise exception 'E_NOT_FOUND'; end if;
  if exists (select 1 from public.party_links where deleted_at is null and (customer_id = p_customer or supplier_id = p_supplier)) then raise exception 'E_ALREADY_LINKED'; end if;
  insert into public.party_links(id, shop_id, customer_id, supplier_id, created_by) values (p_id, s, p_customer, p_supplier, auth.uid());
  return p_id;
end $$;

create or replace function public.unlink_parties(p_link uuid) returns void
language plpgsql security definer set search_path = public as $$
begin
  perform public.ledger_require(array['owner']::public.app_role[]);
  update public.party_links set deleted_at = now() where id = p_link and shop_id = public.current_shop_id() and deleted_at is null;
  if not found then raise exception 'E_NOT_FOUND'; end if;
end $$;

-- الربط بتاع عميل أو مورد (لو موجود)، والأرصدة: عليه كعميل، وليه كمورد، والصافي، وأقصى مقاصة
create or replace function public.party_link_info(p_kind text, p_id uuid) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare s uuid := public.current_shop_id(); lk public.party_links; ar bigint; ap bigint;
begin
  perform public.ledger_require(array['owner']::public.app_role[]);
  select * into lk from public.party_links where shop_id = s and deleted_at is null
    and ((p_kind = 'customer' and customer_id = p_id) or (p_kind = 'supplier' and supplier_id = p_id) or (p_kind = 'link' and id = p_id));
  if not found then return null; end if;
  select coalesce(sum(l.debit - l.credit), 0) into ar from public.journal_lines l join public.accounts a on a.id = l.account_id where a.shop_id = s and a.kind = 'receivable' and l.party_id = lk.customer_id;
  select coalesce(sum(l.credit - l.debit), 0) into ap from public.journal_lines l join public.accounts a on a.id = l.account_id where a.shop_id = s and a.kind = 'payable' and l.party_id = lk.supplier_id;
  return jsonb_build_object('id', lk.id, 'customer_id', lk.customer_id, 'supplier_id', lk.supplier_id,
    'customer', (select name from public.customers where id = lk.customer_id), 'supplier', (select name from public.suppliers where id = lk.supplier_id),
    'receivable', ar, 'payable', ap, 'net', ar - ap, 'max_netting', greatest(least(ar, ap), 0));
end $$;

-- المقاصة: الموردين مدين (المحل عليه أقل للمورد)، والعملاء دائن (العميل عليه أقل). p_amount فاضي = أقصى مبلغ
create or replace function public.net_parties(p_id uuid, p_link uuid, p_amount bigint default null) returns uuid
language plpgsql security definer set search_path = public as $$
declare e uuid; info jsonb; amt bigint;
begin
  perform public.ledger_require(array['owner']::public.app_role[]);
  e := public.ledger_idem(p_id);
  if e is not null then return e; end if;
  info := public.party_link_info('link', p_link);
  if info is null then raise exception 'E_NOT_FOUND'; end if;
  amt := coalesce(p_amount, (info ->> 'max_netting')::bigint);
  if amt <= 0 or amt > (info ->> 'max_netting')::bigint then raise exception 'E_NETTING_LIMIT'; end if;
  return public.ledger_post('netting', p_link, null, jsonb_build_array(
    public.ledger_line(public.ledger_acc('ap'), amt, 0, 'supplier', (info ->> 'supplier_id')::uuid),
    public.ledger_line(public.ledger_acc('ar'), 0, amt, 'customer', (info ->> 'customer_id')::uuid)), null, p_id);
end $$;

do $$
declare f text;
begin
  foreach f in array array['link_parties(uuid, uuid, uuid)', 'unlink_parties(uuid)', 'party_link_info(text, uuid)', 'net_parties(uuid, uuid, bigint)'] loop
    execute format('revoke execute on function public.%s from public, anon', f);
    execute format('grant execute on function public.%s to authenticated', f);
  end loop;
end $$;

-- (0030) نفس statement من 0029، والفرق: كشف صافي للعميل والمورد المربوطين (kind = 'linked'، والـ id = رقم الربط)
create or replace function public.statement(p_kind text, p_id uuid, p_from timestamptz, p_to timestamptz) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare
  s uuid := public.current_shop_id();
  accs uuid[];
  parties uuid[] := array[p_id];
  lk public.party_links;
  opening bigint;
  res jsonb;
begin
  perform public.ledger_require(array['owner']::public.app_role[]);
  if p_kind = 'cashbox' then
    select array_agg(id) into accs from public.accounts where id = p_id and shop_id = s and kind = 'cash';
  elsif p_kind = 'customer' then
    select array_agg(id) into accs from public.accounts where shop_id = s and kind = 'receivable';
  elsif p_kind = 'supplier' then
    select array_agg(id) into accs from public.accounts where shop_id = s and kind = 'payable';
  elsif p_kind = 'employee' then
    select array_agg(id) into accs from public.accounts where shop_id = s and kind in ('advances', 'salaries');
  elsif p_kind = 'partner' then
    -- (0029) كشف الشريك: رأس ماله وحسابه الجاري. الرصيد = اللي ليه عند المحل
    select array_agg(id) into accs from public.accounts where shop_id = s and kind in ('partner_capital', 'partner_current');
  elsif p_kind = 'linked' then
    -- (0030) كشف صافي لعميل ومورد مربوطين: اللي عليه كعميل − اللي ليه كمورد. موجب = هو عليه للمحل
    select * into lk from public.party_links where id = p_id and shop_id = s and deleted_at is null;
    if not found then raise exception 'E_NOT_FOUND'; end if;
    parties := array[lk.customer_id, lk.supplier_id];
    select array_agg(id) into accs from public.accounts where shop_id = s and kind in ('receivable', 'payable');
  else
    raise exception 'E_BAD_INPUT';
  end if;
  if accs is null then raise exception 'E_NOT_FOUND'; end if;
  -- الرصيد: للخزنة والعميل والسلف = مدين − دائن. للمورد والمرتبات = دائن − مدين (الطرف الطبيعي)
  select coalesce(sum((l.debit - l.credit) * (case when p_kind = 'linked' then 1 else public.account_sign(a.type) end)), 0) into opening
  from public.journal_lines l join public.accounts a on a.id = l.account_id join public.journal_entries e on e.id = l.entry_id
  where l.account_id = any(accs) and (p_kind = 'cashbox' or l.party_id = any(parties)) and e.occurred_at < p_from;
  with mv as (
    select e.id as entry_id, e.entry_no, e.occurred_at, e.source_type, e.source_id, e.device_id, e.memo, e.reverses_id,
           d.order_no, p.full_name as by_name, a.code as account_code,
           ((l.debit - l.credit) * (case when p_kind = 'linked' then 1 else public.account_sign(a.type) end))::bigint as amount
    from public.journal_lines l
    join public.accounts a on a.id = l.account_id
    join public.journal_entries e on e.id = l.entry_id
    left join public.devices d on d.id = e.device_id
    left join public.profiles p on p.id = e.created_by
    where l.account_id = any(accs) and (p_kind = 'cashbox' or l.party_id = any(parties)) and e.occurred_at >= p_from and e.occurred_at < p_to
  ),
  mv2 as (select mv.*, opening + sum(amount) over (order by occurred_at, entry_no rows unbounded preceding) as running from mv)
  select jsonb_build_object('opening', opening, 'moves', coalesce(jsonb_agg(jsonb_build_object(
      'entry_id', entry_id, 'entry_no', entry_no, 'at', occurred_at, 'source_type', source_type, 'source_id', source_id,
      'device_id', device_id, 'order_no', order_no, 'memo', memo, 'by', by_name, 'account', account_code, 'amount', amount,
      'reversed', exists (select 1 from public.journal_entries r where r.reverses_id = entry_id), 'reverses', reverses_id,
      'balance', running) order by occurred_at, entry_no), '[]'::jsonb))
  into res from mv2;
  return res;
end $$;

-- (0030) النسخة الاحتياطية والاسترجاع: نفس 0029، والفرق إن روابط العملاء بالموردين بقت جوه النسخة
create or replace function public.backup_snapshot(p_shop uuid) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare
  res jsonb := jsonb_build_object('format', 'warsha-backup', 'version', 1, 'generated_at', now(), 'shop_id', p_shop);
  t text;
  rows jsonb;
begin
  foreach t in array array['shops', 'shop_branding', 'profiles', 'customers', 'devices', 'device_costs', 'status_log', 'device_notes', 'device_photos', 'device_checks',
                           'quote_decisions', 'message_templates', 'message_log', 'accounts', 'journal_entries', 'journal_lines', 'payments', 'drawer_closings',
                           'suppliers', 'items', 'stock_moves', 'purchases', 'labor_rates', 'specialties', 'staff_specialties', 'routes', 'repair_steps',
                           'repair_videos', 'device_ratings', 'issue_presets', 'partners', 'profit_distributions', 'party_links', 'audit_log'] loop
    execute format('select coalesce(jsonb_agg(to_jsonb(x)), ''[]''::jsonb) from public.%I x where x.shop_id = $1', t) into rows using p_shop;
    res := res || jsonb_build_object(t, rows);
  end loop;
  select coalesce(jsonb_agg(jsonb_build_object('device_id', device_id, 'kind', kind, 'erased_at', erased_at)), '[]'::jsonb)
    into rows from public.device_passcodes where shop_id = p_shop;
  return res || jsonb_build_object('device_passcodes', rows);
end $$;
revoke execute on function public.backup_snapshot(uuid) from public, anon, authenticated;

create or replace function public.restore_backup(p_data jsonb) returns jsonb
-- extensions: فيها gen_random_bytes على Supabase
language plpgsql security definer set search_path = public, extensions, pg_temp as $$
declare
  s uuid := public.current_shop_id();
  me uuid := auth.uid();
  old_shop uuid;
  old_owner uuid;
  sh jsonb;
  t text;
  r jsonb;
  rows jsonb;
  n int;
  bad int;
  counts jsonb := '{}'::jsonb;
  -- بالترتيب ده عشان كل صف يلاقي اللي بيشاور عليه
  tabs text[] := array['profiles', 'shop_branding', 'accounts', 'customers', 'suppliers', 'party_links', 'partners', 'specialties', 'staff_specialties', 'routes', 'labor_rates',
                       'issue_presets', 'message_templates', 'items', 'devices', 'device_costs', 'status_log', 'device_notes', 'device_checks',
                       'quote_decisions', 'repair_steps', 'repair_videos', 'device_ratings', 'journal_entries', 'journal_lines', 'profit_distributions', 'payments',
                       'purchases', 'stock_moves', 'drawer_closings', 'message_log', 'audit_log'];
  -- الجداول دي ليها نسخة اتعملت مع التسجيل: بتتطابق بالكود (أو المفتاح) وبتاخد قيم النسخة
  keyed text[] := array['accounts', 'routes', 'specialties', 'message_templates', 'labor_rates', 'shop_branding'];
begin
  perform public.ledger_require(array['owner']::public.app_role[]);
  if s is null or me is null then raise exception 'E_FORBIDDEN'; end if;
  if p_data is null or p_data->>'format' is distinct from 'warsha-backup' or coalesce((p_data->>'version')::int, 0) <> 1 then
    raise exception 'E_BACKUP_FORMAT';
  end if;
  old_shop := (p_data->>'shop_id')::uuid;
  if old_shop is null or old_shop = s then raise exception 'E_BACKUP_FORMAT'; end if;

  -- محل جديد فاضي بس
  if exists (select 1 from public.devices where shop_id = s) or exists (select 1 from public.customers where shop_id = s)
     or exists (select 1 from public.journal_entries where shop_id = s) or exists (select 1 from public.items where shop_id = s)
     or exists (select 1 from public.suppliers where shop_id = s) or exists (select 1 from public.payments where shop_id = s)
     or exists (select 1 from public.purchases where shop_id = s) or exists (select 1 from public.drawer_closings where shop_id = s)
     or exists (select 1 from public.stock_moves where shop_id = s)
     or exists (select 1 from public.profiles where shop_id = s and id <> me) then
    raise exception 'E_RESTORE_NOT_EMPTY';
  end if;

  perform set_config('warsha.restore', 'on', true);
  drop table if exists pg_temp._rmap;
  create temp table _rmap(old uuid primary key, new uuid not null) on commit drop;
  insert into _rmap values (old_shop, s);

  -- 1) بيانات المحل نفسه (من غير الخطة والإيقاف واللوجو اللي في Storage)
  sh := p_data->'shops'->0;
  if sh is not null then
    update public.shops set
      name = coalesce(sh->>'name', name), phone = sh->>'phone', address = sh->>'address',
      receipt_terms = coalesce(sh->>'receipt_terms', receipt_terms), warranty_days = coalesce((sh->>'warranty_days')::int, warranty_days),
      country = coalesce(sh->>'country', country), currency = coalesce(sh->>'currency', currency),
      payment_methods = coalesce(array(select jsonb_array_elements_text(sh->'payment_methods')), payment_methods),
      theme = coalesce(sh->>'theme', theme), locale = coalesce(sh->>'locale', locale),
      default_margin_pct = coalesce((sh->>'default_margin_pct')::int, default_margin_pct),
      extras = coalesce(sh->'extras', extras), max_discount_pct = coalesce((sh->>'max_discount_pct')::int, max_discount_pct)
    where id = s;
  end if;

  -- 2) الـ ids الجديدة
  -- صاحب المحل في النسخة = اللي بيسترجع دلوقتي
  select (x->>'id')::uuid into old_owner from jsonb_array_elements(coalesce(p_data->'profiles', '[]')) x
   where x->>'role' = 'owner' order by x->>'created_at' limit 1;
  if old_owner is not null then insert into _rmap values (old_owner, me) on conflict do nothing; end if;
  insert into _rmap select (x->>'id')::uuid, coalesce((select a.id from public.accounts a where a.shop_id = s and a.code = x->>'code' and x->>'code' is not null), gen_random_uuid())
    from jsonb_array_elements(coalesce(p_data->'accounts', '[]')) x on conflict do nothing;
  insert into _rmap select (x->>'id')::uuid, coalesce((select a.id from public.routes a where a.shop_id = s and a.code = x->>'code' and x->>'code' is not null), gen_random_uuid())
    from jsonb_array_elements(coalesce(p_data->'routes', '[]')) x on conflict do nothing;
  insert into _rmap select (x->>'id')::uuid, coalesce((select a.id from public.specialties a where a.shop_id = s and a.code = x->>'code' and x->>'code' is not null), gen_random_uuid())
    from jsonb_array_elements(coalesce(p_data->'specialties', '[]')) x on conflict do nothing;
  insert into _rmap select (x->>'id')::uuid, coalesce((select a.id from public.message_templates a where a.shop_id = s and a.key = x->>'key'), gen_random_uuid())
    from jsonb_array_elements(coalesce(p_data->'message_templates', '[]')) x on conflict do nothing;
  insert into _rmap select (x->>'id')::uuid, coalesce((select a.id from public.labor_rates a where a.shop_id = s and a.deleted_at is null and lower(trim(a.issue)) = lower(trim(x->>'issue')) and x->>'deleted_at' is null), gen_random_uuid())
    from jsonb_array_elements(coalesce(p_data->'labor_rates', '[]')) x on conflict do nothing;
  insert into _rmap select (x->>'id')::uuid, coalesce((select a.id from public.shop_branding a where a.shop_id = s), gen_random_uuid())
    from jsonb_array_elements(coalesce(p_data->'shop_branding', '[]')) x on conflict do nothing;
  foreach t in array tabs loop
    insert into _rmap select (x->>'id')::uuid, gen_random_uuid() from jsonb_array_elements(coalesce(p_data->t, '[]')) x where x ? 'id' on conflict do nothing;
  end loop;

  -- 3) الصفوف نفسها بالترتيب
  foreach t in array tabs loop
    rows := '[]'::jsonb;
    for r in select public.restore_remap(x) from jsonb_array_elements(coalesce(p_data->t, '[]')) x loop
      if t = 'profiles' then
        -- صاحب المحل موجود أصلًا. الباقيين موظفين سابقين (من غير حساب دخول)
        continue when (r->>'id')::uuid = me;
        r := r || jsonb_build_object('deleted_at', coalesce(r->>'deleted_at', now()::text));
      elsif t = 'devices' then
        -- كود التتبع (الـ QR) بيفضل زي ما هو، إلا لو مستخدم في المشروع ده (المحل الأصلي لسه هنا)
        if exists (select 1 from public.devices d where d.tracking_token = r->>'tracking_token') then
          r := r || jsonb_build_object('tracking_token', encode(gen_random_bytes(12), 'hex'));
        end if;
      elsif t = 'journal_entries' then
        if r->>'idem_key' is not null and exists (select 1 from public.journal_entries j where j.idem_key = (r->>'idem_key')::uuid) then
          r := r || jsonb_build_object('idem_key', gen_random_uuid());
        end if;
      elsif t = 'shop_branding' then
        -- اللوجو الملون والحراري جوه الصف نفسه. الملف الأصلي في Storage مش جوه النسخة
        r := r || jsonb_build_object('logo_path', null);
      end if;
      if t = any (keyed) and exists (select 1 from _rmap m where m.new = (r->>'id')::uuid and m.old <> m.new)
         and (t <> 'shop_branding' or exists (select 1 from public.shop_branding b where b.id = (r->>'id')::uuid)) then
        -- موجود من التسجيل: بياخد قيم النسخة
        execute format('select count(*) from public.%I where id = $1', t) into n using (r->>'id')::uuid;
        if n > 0 then
          execute format('update public.%1$I x set (%2$s) = (select %2$s from jsonb_populate_record(null::public.%1$I, $1)) where x.id = $2', t,
            (select string_agg(quote_ident(c.column_name), ', ' order by c.ordinal_position) from information_schema.columns c
              where c.table_schema = 'public' and c.table_name = t and c.column_name not in ('id', 'shop_id')))
            using r, (r->>'id')::uuid;
          continue;
        end if;
      end if;
      rows := rows || jsonb_build_array(r);
    end loop;
    if jsonb_array_length(rows) > 0 then
      -- overriding system value: أرقام القيود (entry_no) بترجع زي ما هي
      execute format('insert into public.%1$I overriding system value select * from jsonb_populate_recordset(null::public.%1$I, $1)', t) using rows;
    end if;
    counts := counts || jsonb_build_object(t, jsonb_array_length(coalesce(p_data->t, '[]')));
  end loop;

  -- 4) عدّاد أرقام الطلبات: من آخر رقم راجع في كل سنة
  insert into public.order_counters(shop_id, year, last_value)
  select s, split_part(order_no, '-', 1)::int, max(split_part(order_no, '-', 2)::int)
    from public.devices where shop_id = s and order_no ~ '^\d{4}-\d+$' group by 2
  on conflict (shop_id, year) do update set last_value = greatest(public.order_counters.last_value, excluded.last_value);

  -- 5) التأكد: كل قيد متوازن، ورصيد كل حساب = رصيده في النسخة بالظبط
  select count(*) into bad from (
    select entry_id from public.journal_lines where shop_id = s group by entry_id having sum(debit) <> sum(credit)) x;
  if bad > 0 then raise exception 'E_RESTORE_UNBALANCED'; end if;
  select count(*) into bad from (
    select m.new acc, sum((l->>'debit')::bigint - (l->>'credit')::bigint) b
      from jsonb_array_elements(coalesce(p_data->'journal_lines', '[]')) l join _rmap m on m.old = (l->>'account_id')::uuid group by m.new
  ) x full join (select account_id, sum(debit - credit) b from public.journal_lines where shop_id = s group by account_id) y on y.account_id = x.acc
  where coalesce(x.b, 0) <> coalesce(y.b, 0);
  if bad > 0 then raise exception 'E_RESTORE_MISMATCH'; end if;
  -- وعدد الصفوف في كل جدول (الحسابات والقوالب اللي اتعملت مع التسجيل ممكن تزيد عن النسخة، مش تقل)
  foreach t in array tabs loop
    execute format('select count(*) from public.%I where shop_id = $1', t) into n using s;
    if n < jsonb_array_length(coalesce(p_data->t, '[]')) - (case when t = 'profiles' and old_owner is not null then 1 else 0 end) then
      raise exception 'E_RESTORE_MISMATCH';
    end if;
  end loop;

  perform set_config('warsha.restore', 'off', true);
  insert into public.audit_log(shop_id, actor_id, action, entity, entity_id, after)
  values (s, me, 'backup_restore', 'shops', s, jsonb_build_object('from_shop', old_shop, 'generated_at', p_data->>'generated_at', 'counts', counts));
  return jsonb_build_object('restored', true, 'counts', counts);
end $$;
revoke execute on function public.restore_backup(jsonb) from public, anon;
grant execute on function public.restore_backup(jsonb) to authenticated;

-- ============================== 0031_partner_capital.sql ==============================
-- ============================================================
-- 0031: رأس مال الشريك بأنواعه، وحقوق الملكية في الوضع المالي (ملاحظات صاحب المشروع على البند 5)
-- رأس مال الشريك حقوق ملكية، مش دين على المحل، ومش إيراد ولا ربح:
--   أ) فلوس دخلت دلوقتي: الخزنة مدين، ورأس مال الشريك دائن.
--   ب) بضاعة: المخزون مدين (وحركة مخزون بالكمية والتكلفة)، ورأس مال الشريك دائن.
--   ج) معدات: "أصول ثابتة" مدين، ورأس مال الشريك دائن (وبتدخل في قيمة المحل).
--   د) رأس مال قديم (قبل البرنامج): رصيد افتتاحي من غير ما يلمس الخزن: جزء من رأس المال الافتتاحي بيتنقل للشريك.
-- كل حركة بتاريخها (النهارده أو قبل كده). وزيادة رأس المال أو سحب جزء منه بعدين بنفس الطريقة.
-- الوضع المالي: "عليا للناس" فيها الموردين والمرتبات بس (ومعاهم عربون العملاء لأنه فلوس لناس من بره)، وحقوق الملكية في قسم لوحده.
-- ============================================================

alter table public.accounts drop constraint if exists accounts_kind_check;
alter table public.accounts add constraint accounts_kind_check check (kind = any (array[
  'cash', 'receivable', 'advances', 'inventory', 'payable', 'salaries', 'capital', 'drawings', 'revenue', 'cogs', 'expense', 'shortage', 'overage',
  'partner_capital', 'partner_current', 'retained', 'fixed_asset']));

create or replace function public.ensure_partner_accounts(p_shop uuid) returns void
language sql security definer set search_path = public as $$
  insert into public.accounts(shop_id, code, type, kind) values
    (p_shop, 'partners_capital', 'equity', 'partner_capital'),
    (p_shop, 'partners_current', 'equity', 'partner_current'),
    (p_shop, 'retained', 'equity', 'retained'),
    (p_shop, 'fixed_assets', 'asset', 'fixed_asset')
  on conflict (shop_id, code) where code is not null do nothing
$$;
revoke execute on function public.ensure_partner_accounts(uuid) from public, anon, authenticated;
do $$
declare s uuid;
begin
  perform set_config('warsha.system', 'on', true);
  for s in select id from public.shops loop perform public.ensure_partner_accounts(s); end loop;
  perform set_config('warsha.system', 'off', true);
end $$;

-- نفس ledger_post (0029) بتاريخ محدد للعملية (للحركات اللي حصلت قبل النهارده)
create or replace function public.ledger_post_at(
  p_at timestamptz, p_source_type text, p_source_id uuid, p_memo text, p_lines jsonb,
  p_device uuid default null, p_idem uuid default null
) returns uuid
language plpgsql security definer set search_path = public as $$
declare
  s uuid := public.current_shop_id();
  e uuid := gen_random_uuid();
  l jsonb;
  a public.accounts;
  d bigint := 0;
  c bigint := 0;
  ld bigint;
  lc bigint;
begin
  if s is null then raise exception 'E_NO_SHOP'; end if;
  if jsonb_typeof(p_lines) <> 'array' or jsonb_array_length(p_lines) < 2 then raise exception 'E_UNBALANCED'; end if;
  insert into public.journal_entries(id, shop_id, occurred_at, source_type, source_id, device_id, memo, idem_key, created_by)
  values (e, s, p_at, p_source_type, p_source_id, p_device, nullif(trim(p_memo), ''), p_idem, auth.uid());
  for l in select * from jsonb_array_elements(p_lines) loop
    select * into a from public.accounts where id = (l ->> 'account')::uuid and shop_id = s and deleted_at is null;
    if not found then raise exception 'E_BAD_ACCOUNT'; end if;
    ld := coalesce((l ->> 'debit')::bigint, 0);
    lc := coalesce((l ->> 'credit')::bigint, 0);
    if ld < 0 or lc < 0 or (ld > 0) = (lc > 0) then raise exception 'E_BAD_AMOUNT'; end if;
    -- العملاء والموردين والموظفين والشركاء لازم يبقى معاهم الطرف
    if a.kind in ('receivable', 'payable', 'advances', 'salaries', 'partner_capital', 'partner_current') and (l ->> 'party_id') is null then raise exception 'E_BAD_INPUT'; end if;
    insert into public.journal_lines(shop_id, entry_id, account_id, party_type, party_id, debit, credit)
    values (s, e, a.id, l ->> 'party_type', (l ->> 'party_id')::uuid, ld, lc);
    d := d + ld;
    c := c + lc;
  end loop;
  if d <> c or d = 0 then raise exception 'E_UNBALANCED'; end if;
  return e;
end $$;
revoke execute on function public.ledger_post_at(timestamptz, text, uuid, text, jsonb, uuid, uuid) from public, anon, authenticated;

-- تاريخ العملية: اليوم اللي اتكتب (بتوقيت القاهرة، الساعة 12 الضهر) أو دلوقتي لو النهارده. ممنوع تاريخ في المستقبل
create or replace function public.ledger_day_at(p_date date) returns timestamptz
language plpgsql stable set search_path = public as $$
declare today date := (now() at time zone 'Africa/Cairo')::date;
begin
  if p_date is null or p_date = today then return now(); end if;
  if p_date > today or p_date < date '2000-01-01' then raise exception 'E_BAD_DATE'; end if;
  return (p_date + time '12:00') at time zone 'Africa/Cairo';
end $$;
revoke execute on function public.ledger_day_at(date) from public, anon, authenticated;

-- رأس مال داخل من شريك: p_kind = cash | goods | equipment | old
create or replace function public.partner_capital_in(p_id uuid, p_partner uuid, p_kind text, p_amount bigint default null, p_date date default null,
  p_cashbox uuid default null, p_lines jsonb default null, p_note text default null) returns uuid
language plpgsql security definer set search_path = public as $$
declare s uuid := public.current_shop_id(); e uuid; at timestamptz; l jsonb; q bigint; u bigint; total bigint := 0; debit_line jsonb; memo text;
begin
  perform public.ledger_require(array['owner']::public.app_role[]);
  e := public.ledger_idem(p_id);
  if e is not null then return e; end if;
  if not exists (select 1 from public.partners where id = p_partner and shop_id = s and deleted_at is null) then raise exception 'E_NOT_FOUND'; end if;
  at := public.ledger_day_at(p_date);
  memo := coalesce(nullif(trim(p_note), ''), p_kind);
  if p_kind = 'goods' then
    if jsonb_typeof(p_lines) <> 'array' or jsonb_array_length(p_lines) = 0 then raise exception 'E_BAD_INPUT'; end if;
    for l in select * from jsonb_array_elements(p_lines) loop
      q := (l ->> 'qty')::bigint;
      u := (l ->> 'unit_cost')::bigint;
      if q is null or q <= 0 or q > 100000 or u is null or u < 0 then raise exception 'E_BAD_AMOUNT'; end if;
      if not exists (select 1 from public.items where id = (l ->> 'item')::uuid and shop_id = s and deleted_at is null) then raise exception 'E_NOT_FOUND'; end if;
      total := total + q * u;
    end loop;
    perform public.ledger_amount(total);
    debit_line := public.ledger_line(public.ledger_acc('inventory'), total, 0);
  else
    perform public.ledger_amount(p_amount);
    total := p_amount;
    if p_kind = 'cash' then
      debit_line := public.ledger_line((public.ledger_cashbox(p_cashbox)).id, total, 0);
    elsif p_kind = 'equipment' then
      debit_line := public.ledger_line(public.ledger_acc('fixed_assets'), total, 0);
    elsif p_kind = 'old' then
      -- رأس مال قديم: الأصول نفسها اتسجلت في الجرد قصاد رأس المال، فهنا جزء منه بيتنقل للشريك بس
      debit_line := public.ledger_line(public.ledger_acc('capital'), total, 0);
    else
      raise exception 'E_BAD_INPUT';
    end if;
  end if;
  e := public.ledger_post_at(at, case when p_kind = 'old' then 'opening' else 'partner_capital' end, p_partner, memo, jsonb_build_array(
    debit_line, public.ledger_line(public.ledger_acc('partners_capital'), 0, total, 'partner', p_partner)), null, p_id);
  if p_kind = 'goods' then
    for l in select * from jsonb_array_elements(p_lines) loop
      insert into public.stock_moves(shop_id, item_id, entry_id, qty, value) values (s, (l ->> 'item')::uuid, e, (l ->> 'qty')::int, (l ->> 'qty')::bigint * (l ->> 'unit_cost')::bigint);
    end loop;
  end if;
  return e;
end $$;

-- سحب من الشريك بتاريخ: من رأس ماله (تخفيض رأس المال) أو من أرباحه (الجاري). مش مصروف
create or replace function public.partner_capital_out(p_id uuid, p_partner uuid, p_cashbox uuid, p_amount bigint, p_date date default null,
  p_from_capital boolean default true, p_note text default null) returns uuid
language plpgsql security definer set search_path = public as $$
declare e uuid; cb public.accounts;
begin
  perform public.ledger_require(array['owner']::public.app_role[]);
  e := public.ledger_idem(p_id);
  if e is not null then return e; end if;
  perform public.ledger_amount(p_amount);
  cb := public.ledger_cashbox(p_cashbox);
  if not exists (select 1 from public.partners where id = p_partner and shop_id = cb.shop_id) then raise exception 'E_NOT_FOUND'; end if;
  return public.ledger_post_at(public.ledger_day_at(p_date), 'partner_withdrawal', p_partner, p_note, jsonb_build_array(
    public.ledger_line(public.ledger_acc(case when p_from_capital then 'partners_capital' else 'partners_current' end), p_amount, 0, 'partner', p_partner),
    public.ledger_line(cb.id, 0, p_amount)), null, p_id);
end $$;

do $$
declare f text;
begin
  foreach f in array array['partner_capital_in(uuid, uuid, text, bigint, date, uuid, jsonb, text)', 'partner_capital_out(uuid, uuid, uuid, bigint, date, boolean, text)'] loop
    execute format('revoke execute on function public.%s from public, anon', f);
    execute format('grant execute on function public.%s to authenticated', f);
  end loop;
end $$;

-- (0031) نفس financial_position من 0008، والفرق: الأصول الثابتة، و"أرباح مستحقة للشركاء" لوحدها، وتفاصيل حقوق الملكية
create or replace function public.financial_position(p_from timestamptz, p_to timestamptz) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare
  s uuid := public.current_shop_id();
  res jsonb;
begin
  perform public.ledger_require(array['owner']::public.app_role[]);
  with bal as (
    select a.id, a.code, a.name, a.type, a.kind, a.method, l.party_type, l.party_id,
           coalesce(sum((l.debit - l.credit) * public.account_sign(a.type)), 0)::bigint as b
    from public.accounts a
    left join public.journal_lines l on l.account_id = a.id
    where a.shop_id = s
    group by a.id, l.party_type, l.party_id
  ),
  acc as (select id, code, name, type, kind, method, sum(b)::bigint as b from bal group by id, code, name, type, kind, method),
  per as (
    select coalesce(sum(case when a.type = 'revenue' then l.credit - l.debit else 0 end), 0)::bigint as revenue,
           coalesce(sum(case when a.type = 'expense' then l.debit - l.credit else 0 end), 0)::bigint as expenses
    from public.journal_lines l join public.accounts a on a.id = l.account_id join public.journal_entries e on e.id = l.entry_id
    where l.shop_id = s and e.occurred_at >= p_from and e.occurred_at < p_to
  ),
  tot as (
    select coalesce(sum(debit), 0)::bigint as d, coalesce(sum(credit), 0)::bigint as c from public.journal_lines where shop_id = s
  ),
  unb as (
    select count(*)::int as n from (
      select e.id from public.journal_entries e left join public.journal_lines l on l.entry_id = e.id
      where e.shop_id = s group by e.id having coalesce(sum(l.debit), 0) <> coalesce(sum(l.credit), 0) or count(l.id) < 2) x
  ),
  eq as (
    select coalesce(sum(b) filter (where type = 'asset'), 0)::bigint as assets,
           coalesce(sum(b) filter (where type = 'liability'), 0)::bigint as liabilities,
           coalesce(sum(b) filter (where type = 'equity'), 0)::bigint as equity,
           (coalesce(sum(b) filter (where type = 'revenue'), 0) - coalesce(sum(b) filter (where type = 'expense'), 0))::bigint as earnings
    from acc
  ),
  parts as (
    select
      coalesce(sum(b) filter (where kind = 'cash'), 0)::bigint as cash,
      coalesce(sum(greatest(b, 0)) filter (where kind in ('receivable', 'advances')), 0)::bigint as receivables,
      (coalesce(sum(greatest(b, 0)) filter (where kind in ('payable', 'salaries')), 0)
        + coalesce(sum(greatest(-b, 0)) filter (where kind in ('receivable', 'advances')), 0)
        + coalesce(sum(greatest(-b, 0)) filter (where kind = 'inventory'), 0))::bigint as payables,
      coalesce(sum(greatest(-b, 0)) filter (where kind in ('payable', 'salaries')), 0)::bigint as payables_debit,
      coalesce(sum(greatest(b, 0)) filter (where kind = 'inventory'), 0)::bigint as inventory,
      coalesce(sum(b) filter (where kind = 'fixed_asset'), 0)::bigint as fixed_assets,
      -- أرباح اتوزعت على الشركاء ولسه ما اتسحبتش (حقوق ملكية، مش دين من بره)
      coalesce(sum(greatest(b, 0)) filter (where kind = 'partner_current'), 0)::bigint as partners_due
    from bal
  ),
  days as (
    select (date_trunc('day', e.occurred_at at time zone 'Africa/Cairo'))::date as day,
           coalesce(sum(case when a.type = 'revenue' then l.credit - l.debit else 0 end), 0)::bigint as revenue,
           coalesce(sum(case when a.type = 'expense' then l.debit - l.credit else 0 end), 0)::bigint as expenses
    from public.journal_lines l join public.accounts a on a.id = l.account_id join public.journal_entries e on e.id = l.entry_id
    where l.shop_id = s and e.occurred_at >= p_from and e.occurred_at < p_to and a.type in ('revenue', 'expense')
    group by 1
  )
  select jsonb_build_object(
    'cash', p.cash,
    'receivables', p.receivables + p.payables_debit,
    'payables', p.payables,
    'inventory', p.inventory,
    'revenue', per.revenue,
    'expenses', per.expenses,
    'profit', per.revenue - per.expenses,
    'fixed_assets', p.fixed_assets,
    'partners_due', p.partners_due,
    -- قيمة المحل = الأصول − الالتزامات اللي لناس من بره بس (رأس مال الشركاء وأرباحهم حقوق ملكية، فما بتقللهاش)
    'net_worth', p.cash + p.receivables + p.payables_debit + p.inventory + p.fixed_assets - p.payables,
    -- حقوق الملكية بالتفصيل (من أول يوم): رأس مال صاحب المحل، والسحوبات، ورأس مال وجاري كل شريك، والأرباح المحتجزة
    'equity_parts', jsonb_build_object(
      'owner_capital', coalesce((select b from acc where code = 'capital'), 0),
      'drawings', -coalesce((select b from acc where code = 'drawings'), 0),
      'retained', eq.earnings + coalesce((select b from acc where code = 'retained'), 0),
      'partners', coalesce((select jsonb_agg(jsonb_build_object('id', pt.id, 'name', pt.name, 'share_bp', pt.share_bp,
          'capital', coalesce((select sum(b.b) from bal b where b.kind = 'partner_capital' and b.party_id = pt.id), 0),
          'current', coalesce((select sum(b.b) from bal b where b.kind = 'partner_current' and b.party_id = pt.id), 0)) order by pt.share_bp desc, pt.name)
        from public.partners pt where pt.shop_id = s and (pt.deleted_at is null or exists (select 1 from bal b where b.party_id = pt.id and b.b <> 0))), '[]'::jsonb)),
    'equation', jsonb_build_object('assets', eq.assets, 'liabilities', eq.liabilities, 'equity', eq.equity, 'earnings', eq.earnings),
    'debits', tot.d, 'credits', tot.c, 'unbalanced_entries', unb.n,
    'balanced', tot.d = tot.c and unb.n = 0 and eq.assets = eq.liabilities + eq.equity + eq.earnings,
    'cashboxes', coalesce((select jsonb_agg(jsonb_build_object('id', a.id, 'code', a.code, 'name', a.name, 'method', a.method, 'balance', a.b) order by a.code nulls last, a.name)
       from acc a where a.kind = 'cash'), '[]'::jsonb),
    'top_customers', coalesce((select jsonb_agg(x order by (x ->> 'balance')::bigint desc) from (
       select jsonb_build_object('id', b.party_id, 'name', c.name, 'balance', sum(b.b)) as x
       from bal b join public.customers c on c.id = b.party_id where b.kind = 'receivable' and b.party_type = 'customer'
       group by b.party_id, c.name having sum(b.b) > 0 order by sum(b.b) desc limit 5) t), '[]'::jsonb),
    'top_suppliers', coalesce((select jsonb_agg(x order by (x ->> 'balance')::bigint desc) from (
       select jsonb_build_object('id', b.party_id, 'name', sp.name, 'balance', sum(b.b)) as x
       from bal b join public.suppliers sp on sp.id = b.party_id where b.kind = 'payable' and b.party_type = 'supplier'
       group by b.party_id, sp.name having sum(b.b) > 0 order by sum(b.b) desc limit 5) t), '[]'::jsonb),
    'daily', coalesce((select jsonb_agg(jsonb_build_object('day', day, 'revenue', revenue, 'expenses', expenses, 'profit', revenue - expenses) order by day) from days), '[]'::jsonb),
    'by_method', coalesce((select jsonb_object_agg(method, total) from (
       select p2.method, sum(p2.amount)::bigint as total from public.payments p2
       where p2.shop_id = s and p2.created_at >= p_from and p2.created_at < p_to
         and not exists (select 1 from public.journal_entries r where r.reverses_id = p2.entry_id)
       group by p2.method) m), '{}'::jsonb),
    'delivered', (select count(*) from public.devices d where d.shop_id = s and d.delivered_at >= p_from and d.delivered_at < p_to),
    'closings', coalesce((select jsonb_agg(jsonb_build_object('cashbox', dc.cashbox_id, 'expected', dc.expected, 'counted', dc.counted, 'diff', dc.diff, 'at', dc.created_at,
       'by', (select full_name from public.profiles where id = dc.closed_by)) order by dc.created_at)
       from public.drawer_closings dc where dc.shop_id = s and dc.created_at >= p_from and dc.created_at < p_to), '[]'::jsonb)
  ) into res
  from parts p, per, tot, unb, eq;
  return res;
end $$;

-- ============================== 0032_lists.sql ==============================
-- ============================================================
-- 0032: القوائم اللي بيديرها صاحب المحل (البند 7)
-- - القوايم: الماركات، والموديلات، والملحقات، والألوان، والحالة الشكلية، وتصنيفات الأصناف، وأسباب الهالك، والحالات الفرعية تحت كل حالة أساسية.
--   (الأعطال الجاهزة في الإعدادات ← إضافات، والمصروفات في ← الخزن والمصروفات، وطرق الدفع في ← طرق الدفع: ليهم شاشاتهم من قبل كده)
-- - البيانات نفسها بتتخزن بالقيمة (نص)، مش برقم البند: فحذف بند من القايمة (حذف ناعم) بيخفيه من الاختيار بس،
--   والأجهزة والأصناف القديمة بتفضل زي ما هي بالظبط.
-- - الحالات الأساسية ثابتة (src/lib/status.ts وis_valid_transition)، والحالة الفرعية تفصيلة تحتها بس
--   (مثلًا "مستني قطعة" ← "اتطلبت من المورد" أو "في الطريق"). ولما الحالة الأساسية تتغير، الفرعية بتتشال لوحدها.
-- - الكل بيشوف القوايم، وصاحب المحل بس اللي بيعدّلها.
-- ============================================================

create table if not exists public.shop_lists (
  id uuid primary key,
  shop_id uuid not null references public.shops(id),
  list text not null check (list in ('brands', 'models', 'accessories', 'colors', 'conditions', 'item_categories', 'write_off_reasons', 'sub_statuses')),
  value text not null check (length(trim(value)) between 1 and 60),
  -- للحالات الفرعية: الحالة الأساسية اللي تحتها
  parent text check (parent is null or parent in ('received', 'inspecting', 'awaiting_approval', 'awaiting_part', 'in_repair', 'repaired', 'ready', 'delivered', 'warranty_return', 'unrepairable')),
  sort integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  check ((list = 'sub_statuses') = (parent is not null))
);
-- (لو الجدول اتعمل قبل كده بقايمة أقصر)
alter table public.shop_lists drop constraint if exists shop_lists_list_check;
alter table public.shop_lists add constraint shop_lists_list_check check (list in ('brands', 'models', 'accessories', 'colors', 'conditions', 'item_categories', 'write_off_reasons', 'sub_statuses'));
-- نفس البند ما يتكررش في نفس القايمة (الساري بس)
create unique index if not exists shop_lists_unique on public.shop_lists(shop_id, list, coalesce(parent, ''), lower(trim(value))) where deleted_at is null;
create index if not exists shop_lists_shop on public.shop_lists(shop_id, list);
alter table public.shop_lists enable row level security;
revoke all on public.shop_lists from public, anon, authenticated;
grant select, insert, update on public.shop_lists to authenticated;
drop policy if exists lists_select on public.shop_lists;
drop policy if exists lists_insert on public.shop_lists;
drop policy if exists lists_update on public.shop_lists;
create policy lists_select on public.shop_lists for select to authenticated using (shop_id = public.current_shop_id());
create policy lists_insert on public.shop_lists for insert to authenticated with check (shop_id = public.current_shop_id() and public.current_app_role() = 'owner');
create policy lists_update on public.shop_lists for update to authenticated using (shop_id = public.current_shop_id() and public.current_app_role() = 'owner') with check (shop_id = public.current_shop_id());
drop trigger if exists set_updated_at on public.shop_lists;
create trigger set_updated_at before update on public.shop_lists for each row execute function public.tg_set_updated_at();
drop trigger if exists block_delete on public.shop_lists;
create trigger block_delete before delete on public.shop_lists for each row execute function public.tg_block_delete();
drop trigger if exists a_force_shop_id on public.shop_lists;
create trigger a_force_shop_id before insert or update on public.shop_lists for each row execute function public.tg_force_shop_id();
drop trigger if exists zz_audit on public.shop_lists;
create trigger zz_audit after insert or update on public.shop_lists for each row execute function public.tg_audit();

-- ---------- الحالة الفرعية على الجهاز ----------
alter table public.devices add column if not exists sub_status text check (sub_status is null or length(trim(sub_status)) between 1 and 60);

-- لما الحالة الأساسية تتغير، الفرعية بتتشال (لأنها كانت تفصيلة للحالة القديمة)
create or replace function public.tg_device_sub_status() returns trigger
language plpgsql as $$
begin
  if new.status is distinct from old.status and new.sub_status is not distinct from old.sub_status then
    new.sub_status := null;
  end if;
  return new;
end $$;
drop trigger if exists b_device_sub_status on public.devices;
create trigger b_device_sub_status before update on public.devices for each row execute function public.tg_device_sub_status();

-- (0032) نفس tg_device_guard من 0014، والفرق: الفني يقدر يغيّر الحالة الفرعية برضه
create or replace function public.tg_device_guard() returns trigger
language plpgsql security definer set search_path = public as $$
declare
  r public.app_role := public.current_app_role();
  fc integer;
  -- حقول التوزيع (المسار، الأولوية، فني المرتجع) بتتغير من دوال التوزيع الموثوقة بس، حتى لو اللي نادى فني
  sys text[] := case when current_setting('warsha.routing', true) = 'on' then array['route_id', 'priority', 'return_of_tech', 'warranty_days', 'warranty_until'] else array[]::text[] end;
begin
  -- حاجات ما بتتغيرش بعد الاستلام
  if new.order_no is distinct from old.order_no
     or new.received_at is distinct from old.received_at
     or new.received_by is distinct from old.received_by then
    raise exception 'E_RECEIPT_IMMUTABLE';
  end if;

  -- الفني يغيّر الحالة (والحالة الفرعية تحتها، من 0032) بس
  if r = 'technician' and
     (to_jsonb(new) - 'status' - 'sub_status' - 'updated_at' - 'delivered_at' - sys) <> (to_jsonb(old) - 'status' - 'sub_status' - 'updated_at' - 'delivered_at' - sys) then
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

-- (0032) النسخة الاحتياطية والاسترجاع: نفس 0030، والفرق إن القوايم بقت جوه النسخة
create or replace function public.backup_snapshot(p_shop uuid) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare
  res jsonb := jsonb_build_object('format', 'warsha-backup', 'version', 1, 'generated_at', now(), 'shop_id', p_shop);
  t text;
  rows jsonb;
begin
  foreach t in array array['shops', 'shop_branding', 'profiles', 'customers', 'devices', 'device_costs', 'status_log', 'device_notes', 'device_photos', 'device_checks',
                           'quote_decisions', 'message_templates', 'message_log', 'accounts', 'journal_entries', 'journal_lines', 'payments', 'drawer_closings',
                           'suppliers', 'items', 'stock_moves', 'purchases', 'labor_rates', 'specialties', 'staff_specialties', 'routes', 'repair_steps',
                           'repair_videos', 'device_ratings', 'issue_presets', 'partners', 'profit_distributions', 'party_links', 'shop_lists', 'audit_log'] loop
    execute format('select coalesce(jsonb_agg(to_jsonb(x)), ''[]''::jsonb) from public.%I x where x.shop_id = $1', t) into rows using p_shop;
    res := res || jsonb_build_object(t, rows);
  end loop;
  select coalesce(jsonb_agg(jsonb_build_object('device_id', device_id, 'kind', kind, 'erased_at', erased_at)), '[]'::jsonb)
    into rows from public.device_passcodes where shop_id = p_shop;
  return res || jsonb_build_object('device_passcodes', rows);
end $$;
revoke execute on function public.backup_snapshot(uuid) from public, anon, authenticated;

create or replace function public.restore_backup(p_data jsonb) returns jsonb
-- extensions: فيها gen_random_bytes على Supabase
language plpgsql security definer set search_path = public, extensions, pg_temp as $$
declare
  s uuid := public.current_shop_id();
  me uuid := auth.uid();
  old_shop uuid;
  old_owner uuid;
  sh jsonb;
  t text;
  r jsonb;
  rows jsonb;
  n int;
  bad int;
  counts jsonb := '{}'::jsonb;
  -- بالترتيب ده عشان كل صف يلاقي اللي بيشاور عليه
  tabs text[] := array['profiles', 'shop_branding', 'accounts', 'customers', 'suppliers', 'party_links', 'partners', 'specialties', 'staff_specialties', 'routes', 'labor_rates',
                       'issue_presets', 'shop_lists', 'message_templates', 'items', 'devices', 'device_costs', 'status_log', 'device_notes', 'device_checks',
                       'quote_decisions', 'repair_steps', 'repair_videos', 'device_ratings', 'journal_entries', 'journal_lines', 'profit_distributions', 'payments',
                       'purchases', 'stock_moves', 'drawer_closings', 'message_log', 'audit_log'];
  -- الجداول دي ليها نسخة اتعملت مع التسجيل: بتتطابق بالكود (أو المفتاح) وبتاخد قيم النسخة
  keyed text[] := array['accounts', 'routes', 'specialties', 'message_templates', 'labor_rates', 'shop_branding'];
begin
  perform public.ledger_require(array['owner']::public.app_role[]);
  if s is null or me is null then raise exception 'E_FORBIDDEN'; end if;
  if p_data is null or p_data->>'format' is distinct from 'warsha-backup' or coalesce((p_data->>'version')::int, 0) <> 1 then
    raise exception 'E_BACKUP_FORMAT';
  end if;
  old_shop := (p_data->>'shop_id')::uuid;
  if old_shop is null or old_shop = s then raise exception 'E_BACKUP_FORMAT'; end if;

  -- محل جديد فاضي بس
  if exists (select 1 from public.devices where shop_id = s) or exists (select 1 from public.customers where shop_id = s)
     or exists (select 1 from public.journal_entries where shop_id = s) or exists (select 1 from public.items where shop_id = s)
     or exists (select 1 from public.suppliers where shop_id = s) or exists (select 1 from public.payments where shop_id = s)
     or exists (select 1 from public.purchases where shop_id = s) or exists (select 1 from public.drawer_closings where shop_id = s)
     or exists (select 1 from public.stock_moves where shop_id = s)
     or exists (select 1 from public.profiles where shop_id = s and id <> me) then
    raise exception 'E_RESTORE_NOT_EMPTY';
  end if;

  perform set_config('warsha.restore', 'on', true);
  drop table if exists pg_temp._rmap;
  create temp table _rmap(old uuid primary key, new uuid not null) on commit drop;
  insert into _rmap values (old_shop, s);

  -- 1) بيانات المحل نفسه (من غير الخطة والإيقاف واللوجو اللي في Storage)
  sh := p_data->'shops'->0;
  if sh is not null then
    update public.shops set
      name = coalesce(sh->>'name', name), phone = sh->>'phone', address = sh->>'address',
      receipt_terms = coalesce(sh->>'receipt_terms', receipt_terms), warranty_days = coalesce((sh->>'warranty_days')::int, warranty_days),
      country = coalesce(sh->>'country', country), currency = coalesce(sh->>'currency', currency),
      payment_methods = coalesce(array(select jsonb_array_elements_text(sh->'payment_methods')), payment_methods),
      theme = coalesce(sh->>'theme', theme), locale = coalesce(sh->>'locale', locale),
      default_margin_pct = coalesce((sh->>'default_margin_pct')::int, default_margin_pct),
      extras = coalesce(sh->'extras', extras), max_discount_pct = coalesce((sh->>'max_discount_pct')::int, max_discount_pct)
    where id = s;
  end if;

  -- 2) الـ ids الجديدة
  -- صاحب المحل في النسخة = اللي بيسترجع دلوقتي
  select (x->>'id')::uuid into old_owner from jsonb_array_elements(coalesce(p_data->'profiles', '[]')) x
   where x->>'role' = 'owner' order by x->>'created_at' limit 1;
  if old_owner is not null then insert into _rmap values (old_owner, me) on conflict do nothing; end if;
  insert into _rmap select (x->>'id')::uuid, coalesce((select a.id from public.accounts a where a.shop_id = s and a.code = x->>'code' and x->>'code' is not null), gen_random_uuid())
    from jsonb_array_elements(coalesce(p_data->'accounts', '[]')) x on conflict do nothing;
  insert into _rmap select (x->>'id')::uuid, coalesce((select a.id from public.routes a where a.shop_id = s and a.code = x->>'code' and x->>'code' is not null), gen_random_uuid())
    from jsonb_array_elements(coalesce(p_data->'routes', '[]')) x on conflict do nothing;
  insert into _rmap select (x->>'id')::uuid, coalesce((select a.id from public.specialties a where a.shop_id = s and a.code = x->>'code' and x->>'code' is not null), gen_random_uuid())
    from jsonb_array_elements(coalesce(p_data->'specialties', '[]')) x on conflict do nothing;
  insert into _rmap select (x->>'id')::uuid, coalesce((select a.id from public.message_templates a where a.shop_id = s and a.key = x->>'key'), gen_random_uuid())
    from jsonb_array_elements(coalesce(p_data->'message_templates', '[]')) x on conflict do nothing;
  insert into _rmap select (x->>'id')::uuid, coalesce((select a.id from public.labor_rates a where a.shop_id = s and a.deleted_at is null and lower(trim(a.issue)) = lower(trim(x->>'issue')) and x->>'deleted_at' is null), gen_random_uuid())
    from jsonb_array_elements(coalesce(p_data->'labor_rates', '[]')) x on conflict do nothing;
  insert into _rmap select (x->>'id')::uuid, coalesce((select a.id from public.shop_branding a where a.shop_id = s), gen_random_uuid())
    from jsonb_array_elements(coalesce(p_data->'shop_branding', '[]')) x on conflict do nothing;
  foreach t in array tabs loop
    insert into _rmap select (x->>'id')::uuid, gen_random_uuid() from jsonb_array_elements(coalesce(p_data->t, '[]')) x where x ? 'id' on conflict do nothing;
  end loop;

  -- 3) الصفوف نفسها بالترتيب
  foreach t in array tabs loop
    rows := '[]'::jsonb;
    for r in select public.restore_remap(x) from jsonb_array_elements(coalesce(p_data->t, '[]')) x loop
      if t = 'profiles' then
        -- صاحب المحل موجود أصلًا. الباقيين موظفين سابقين (من غير حساب دخول)
        continue when (r->>'id')::uuid = me;
        r := r || jsonb_build_object('deleted_at', coalesce(r->>'deleted_at', now()::text));
      elsif t = 'devices' then
        -- كود التتبع (الـ QR) بيفضل زي ما هو، إلا لو مستخدم في المشروع ده (المحل الأصلي لسه هنا)
        if exists (select 1 from public.devices d where d.tracking_token = r->>'tracking_token') then
          r := r || jsonb_build_object('tracking_token', encode(gen_random_bytes(12), 'hex'));
        end if;
      elsif t = 'journal_entries' then
        if r->>'idem_key' is not null and exists (select 1 from public.journal_entries j where j.idem_key = (r->>'idem_key')::uuid) then
          r := r || jsonb_build_object('idem_key', gen_random_uuid());
        end if;
      elsif t = 'shop_branding' then
        -- اللوجو الملون والحراري جوه الصف نفسه. الملف الأصلي في Storage مش جوه النسخة
        r := r || jsonb_build_object('logo_path', null);
      end if;
      if t = any (keyed) and exists (select 1 from _rmap m where m.new = (r->>'id')::uuid and m.old <> m.new)
         and (t <> 'shop_branding' or exists (select 1 from public.shop_branding b where b.id = (r->>'id')::uuid)) then
        -- موجود من التسجيل: بياخد قيم النسخة
        execute format('select count(*) from public.%I where id = $1', t) into n using (r->>'id')::uuid;
        if n > 0 then
          execute format('update public.%1$I x set (%2$s) = (select %2$s from jsonb_populate_record(null::public.%1$I, $1)) where x.id = $2', t,
            (select string_agg(quote_ident(c.column_name), ', ' order by c.ordinal_position) from information_schema.columns c
              where c.table_schema = 'public' and c.table_name = t and c.column_name not in ('id', 'shop_id')))
            using r, (r->>'id')::uuid;
          continue;
        end if;
      end if;
      rows := rows || jsonb_build_array(r);
    end loop;
    if jsonb_array_length(rows) > 0 then
      -- overriding system value: أرقام القيود (entry_no) بترجع زي ما هي
      execute format('insert into public.%1$I overriding system value select * from jsonb_populate_recordset(null::public.%1$I, $1)', t) using rows;
    end if;
    counts := counts || jsonb_build_object(t, jsonb_array_length(coalesce(p_data->t, '[]')));
  end loop;

  -- 4) عدّاد أرقام الطلبات: من آخر رقم راجع في كل سنة
  insert into public.order_counters(shop_id, year, last_value)
  select s, split_part(order_no, '-', 1)::int, max(split_part(order_no, '-', 2)::int)
    from public.devices where shop_id = s and order_no ~ '^\d{4}-\d+$' group by 2
  on conflict (shop_id, year) do update set last_value = greatest(public.order_counters.last_value, excluded.last_value);

  -- 5) التأكد: كل قيد متوازن، ورصيد كل حساب = رصيده في النسخة بالظبط
  select count(*) into bad from (
    select entry_id from public.journal_lines where shop_id = s group by entry_id having sum(debit) <> sum(credit)) x;
  if bad > 0 then raise exception 'E_RESTORE_UNBALANCED'; end if;
  select count(*) into bad from (
    select m.new acc, sum((l->>'debit')::bigint - (l->>'credit')::bigint) b
      from jsonb_array_elements(coalesce(p_data->'journal_lines', '[]')) l join _rmap m on m.old = (l->>'account_id')::uuid group by m.new
  ) x full join (select account_id, sum(debit - credit) b from public.journal_lines where shop_id = s group by account_id) y on y.account_id = x.acc
  where coalesce(x.b, 0) <> coalesce(y.b, 0);
  if bad > 0 then raise exception 'E_RESTORE_MISMATCH'; end if;
  -- وعدد الصفوف في كل جدول (الحسابات والقوالب اللي اتعملت مع التسجيل ممكن تزيد عن النسخة، مش تقل)
  foreach t in array tabs loop
    execute format('select count(*) from public.%I where shop_id = $1', t) into n using s;
    if n < jsonb_array_length(coalesce(p_data->t, '[]')) - (case when t = 'profiles' and old_owner is not null then 1 else 0 end) then
      raise exception 'E_RESTORE_MISMATCH';
    end if;
  end loop;

  perform set_config('warsha.restore', 'off', true);
  insert into public.audit_log(shop_id, actor_id, action, entity, entity_id, after)
  values (s, me, 'backup_restore', 'shops', s, jsonb_build_object('from_shop', old_shop, 'generated_at', p_data->>'generated_at', 'counts', counts));
  return jsonb_build_object('restored', true, 'counts', counts);
end $$;
revoke execute on function public.restore_backup(jsonb) from public, anon;
grant execute on function public.restore_backup(jsonb) to authenticated;

-- ============================== 0033_assistant.sql ==============================
-- ============================================================
-- 0033: المساعد الذكي في البرنامج كله (S3)
--
-- الإعدادات في shops.extras -> 'assistant' (صاحب المحل بيغيّرها من الإعدادات ← المساعد):
--   enabled  : المساعد كله شغال ولا لأ (الافتراضي شغال)
--   areas    : كل مكان لوحده. المالية مقفولة افتراضيًا (فيها تنبيه عن الطبقة المجانية)
--   staff    : مين من الموظفين يستخدمه (الاستقبال، والفني). صاحب المحل دايمًا
--   daily    : حد يومي للمحل (أقل من حد الخطة أو زيه)
--
-- القواعد دي بتتأكد هنا في قاعدة البيانات (مش في الشاشة بس): الـ Edge Function بتنادي
-- ai_take_area قبل أي سؤال، ولو المكان مقفول أو الموظف مش مسموح له أو الحد خلص بترفض.
-- السؤال والإجابة ما بيتخزنوش. اللي بيتسجل: المحل، والمستخدم، والمكان، والوقت بس.
-- ============================================================

alter table public.ai_usage add column if not exists area text not null default 'tech';

-- الأماكن، ومين يقدر يستخدم كل واحد حسب دوره (فوق إعدادات صاحب المحل)
--   tech      : تلميحات التشخيص للجهاز            (كل الموظفين)
--   intake    : اقتراحات وقت الاستلام               (صاحب المحل والاستقبال)
--   inventory : اقتراحات الشراء                    (صاحب المحل)
--   finance   : أسئلة المالية والملخص الأسبوعي      (صاحب المحل)
--   customers : مسودة رسالة واتساب                  (صاحب المحل والاستقبال)
--   reports   : ملخص مكتوب للتقارير                 (صاحب المحل)
--   screen    : الزرار العايم (شرح الشاشة)          (كل الموظفين)
create or replace function public.assistant_area_roles(p_area text) returns text[]
language sql immutable set search_path = public as $$
  select case p_area
    when 'tech' then array['owner', 'reception', 'technician']
    when 'screen' then array['owner', 'reception', 'technician']
    when 'intake' then array['owner', 'reception']
    when 'customers' then array['owner', 'reception']
    when 'inventory' then array['owner']
    when 'finance' then array['owner']
    when 'reports' then array['owner']
    else array[]::text[] end
$$;
revoke all on function public.assistant_area_roles(text) from public, anon, authenticated;

-- الإعدادات بعد الافتراضي (نفس الافتراضي في src/lib/assistantSettings.ts، وفيه اختبار بيقارنهم)
create or replace function public.assistant_settings(s uuid) returns jsonb
language sql stable security definer set search_path = public as $$
  select jsonb_build_object(
    'enabled', coalesce((a ->> 'enabled')::boolean, true),
    'areas', jsonb_build_object(
      'tech', coalesce((a -> 'areas' ->> 'tech')::boolean, true),
      'intake', coalesce((a -> 'areas' ->> 'intake')::boolean, true),
      'inventory', coalesce((a -> 'areas' ->> 'inventory')::boolean, true),
      'finance', coalesce((a -> 'areas' ->> 'finance')::boolean, false),
      'customers', coalesce((a -> 'areas' ->> 'customers')::boolean, true),
      'reports', coalesce((a -> 'areas' ->> 'reports')::boolean, true),
      'screen', coalesce((a -> 'areas' ->> 'screen')::boolean, true)),
    'staff', jsonb_build_object(
      'reception', coalesce((a -> 'staff' ->> 'reception')::boolean, true),
      'technician', coalesce((a -> 'staff' ->> 'technician')::boolean, true)),
    'daily', case when jsonb_typeof(a -> 'daily') = 'number' and (a ->> 'daily')::numeric >= 0 then floor((a ->> 'daily')::numeric)::int else null end)
  from (select coalesce(extras -> 'assistant', '{}'::jsonb) a from public.shops where id = s) x
$$;
revoke all on function public.assistant_settings(uuid) from public, anon, authenticated;

-- بتتنادى من الـ Edge Function قبل أي سؤال: الصلاحية، والإعدادات، والحد اليومي، وبتسجل الاستخدام
create or replace function public.ai_take_area(p_area text) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  s uuid := public.member_shop_id();
  r text := public.member_role();
  st jsonb;
  pl public.plans;
  lim int;
  n int;
begin
  if s is null or r not in ('owner', 'reception', 'technician') then raise exception 'E_FORBIDDEN'; end if;
  if not (r = any (public.assistant_area_roles(p_area))) then raise exception 'E_FORBIDDEN'; end if;
  st := public.assistant_settings(s);
  if not (st ->> 'enabled')::boolean or not coalesce((st -> 'areas' ->> p_area)::boolean, false) then raise exception 'E_AI_OFF'; end if;
  if r <> 'owner' and not coalesce((st -> 'staff' ->> r)::boolean, false) then raise exception 'E_AI_OFF'; end if;
  pl := public.shop_plan(s);
  lim := least(pl.ai_daily, coalesce((st ->> 'daily')::int, pl.ai_daily));
  -- قفل للمحل ده بس، عشان سؤالين في نفس اللحظة ما يعدّوش الحد
  perform pg_advisory_xact_lock(hashtext('ai_take:' || s::text));
  select count(*) into n from public.ai_usage
    where shop_id = s and created_at >= date_trunc('day', now() at time zone 'Africa/Cairo') at time zone 'Africa/Cairo';
  if n >= lim then raise exception 'E_PLAN_LIMIT'; end if;
  insert into public.ai_usage(shop_id, user_id, area) values (s, auth.uid(), p_area);
  return jsonb_build_object('left', lim - n - 1, 'limit', lim);
end $$;
revoke all on function public.ai_take_area(text) from public, anon;
grant execute on function public.ai_take_area(text) to authenticated;

-- (0033) نفس ai_take من 0017 والفرق: بقت بتمشي على إعدادات المساعد كمان (مكان "التشخيص")
create or replace function public.ai_take() returns jsonb
language plpgsql security definer set search_path = public as $$
declare r jsonb;
begin
  r := public.ai_take_area('tech');
  return jsonb_build_object('left', (r ->> 'left')::int);
end $$;

-- للشاشة: الإعدادات، والمستخدم ده يقدر يستخدم أنهي أماكن، واستخدام النهارده من الحد
create or replace function public.assistant_info() returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare
  s uuid := public.member_shop_id();
  r text := public.member_role();
  st jsonb;
  pl public.plans;
  lim int;
  used int;
  allowed jsonb := '{}'::jsonb;
  a text;
begin
  if s is null then raise exception 'E_FORBIDDEN'; end if;
  st := public.assistant_settings(s);
  pl := public.shop_plan(s);
  lim := least(pl.ai_daily, coalesce((st ->> 'daily')::int, pl.ai_daily));
  select count(*) into used from public.ai_usage
    where shop_id = s and created_at >= date_trunc('day', now() at time zone 'Africa/Cairo') at time zone 'Africa/Cairo';
  foreach a in array array['tech', 'intake', 'inventory', 'finance', 'customers', 'reports', 'screen'] loop
    allowed := allowed || jsonb_build_object(a,
      (st ->> 'enabled')::boolean
      and coalesce((st -> 'areas' ->> a)::boolean, false)
      and r = any (public.assistant_area_roles(a))
      and (r = 'owner' or coalesce((st -> 'staff' ->> r)::boolean, false)));
  end loop;
  return jsonb_build_object('settings', st, 'allowed', allowed, 'used', used, 'limit', lim, 'plan_limit', pl.ai_daily);
end $$;
revoke all on function public.assistant_info() from public, anon;
grant execute on function public.assistant_info() to authenticated;

-- اقتراحات الشراء: اللي خرج من كل صنف آخر 30 يوم (بيع أو اتركب في جهاز)، من غير القيود الملغية. صاحب المحل بس
create or replace function public.items_sold30() returns table(item_id uuid, qty bigint)
language plpgsql stable security definer set search_path = public as $$
begin
  perform public.ledger_require(array['owner']::public.app_role[]);
  return query
  select m.item_id, (-sum(m.qty))::bigint
  from public.stock_moves m
  join public.journal_entries e on e.id = m.entry_id
  where e.shop_id = public.current_shop_id()
    and m.qty < 0
    and e.occurred_at >= now() - interval '30 days'
    and e.reverses_id is null
    and not exists (select 1 from public.journal_entries r where r.reverses_id = e.id)
  group by m.item_id;
end $$;
revoke execute on function public.items_sold30() from public, anon;
grant execute on function public.items_sold30() to authenticated;

-- ============================== 0034_branches.sql ==============================
-- =====================================================================
-- B. الفروع (قرار صاحب المشروع 2026-11-08)
-- - كل محل ليه "الفرع الرئيسي"، وكل البيانات الحالية بتتنقل له (والأرصدة زي ما هي بالظبط).
-- - لكل فرع: خزن ومخزون وأجهزة وموظفين ودرج، وبادئة لأرقام الطلبات.
-- - الدفتر واحد للمحل، وكل قيد مربوط بفرع. وحركات المخزون بفرعها (المتوسط المرجّح لكل فرع).
-- - الموظف مربوط بفرع أو أكتر (RLS). صاحب المحل بيشوف كل الفروع.
-- - الفرع الشغال بيتبعت مع كل طلب في الهيدر x-branch-id (وبيتراجع إن الموظف ليه الفرع ده).
-- - المحل اللي ليه فرع واحد: مفيش أي حاجة بتتغير (رقم الطلب زي ما هو 2026-0042).
-- =====================================================================

-- ---------- الجداول ----------
create table public.branches (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references public.shops(id),
  name text not null check (length(trim(name)) between 1 and 80),
  -- بادئة رقم الطلب (حروف إنجليزي كبيرة وأرقام). الرئيسي من غير بادئة عشان الأرقام القديمة تفضل زي ما هي
  prefix text not null default '' check (prefix ~ '^[A-Z0-9]{0,4}$'),
  is_main boolean not null default false,
  phone text check (phone is null or length(phone) <= 40),
  address text check (address is null or length(address) <= 200),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  constraint branches_prefix_needed check (is_main or prefix <> '')
);
create unique index branches_one_main on public.branches(shop_id) where is_main and deleted_at is null;
create unique index branches_prefix_uq on public.branches(shop_id, prefix) where deleted_at is null;
create unique index branches_name_uq on public.branches(shop_id, lower(trim(name))) where deleted_at is null;

-- الموظف ← فروعه. الموظف اللي مالوش صفوف هنا = الفرع الرئيسي بس (المحل اللي ليه فرع واحد ما يحتاجش يختار)
create table public.staff_branches (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references public.shops(id),
  profile_id uuid not null references public.profiles(id),
  branch_id uuid not null references public.branches(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);
create unique index staff_branches_uq on public.staff_branches(profile_id, branch_id) where deleted_at is null;

alter table public.staff_invites add column branch_ids uuid[] not null default '{}';

do $$
declare t text;
begin
  foreach t in array array['branches', 'staff_branches'] loop
    execute format('alter table public.%I enable row level security', t);
    execute format('create trigger set_updated_at before update on public.%I for each row execute function public.tg_set_updated_at()', t);
    execute format('create trigger block_delete before delete on public.%I for each row execute function public.tg_block_delete()', t);
    execute format('create trigger zz_audit after insert or update on public.%I for each row execute function public.tg_audit()', t);
  end loop;
end $$;

-- ---------- دوال الفروع ----------
create or replace function public.main_branch(p_shop uuid) returns uuid
language sql stable security definer set search_path = public as $$
  select id from public.branches where shop_id = p_shop and is_main and deleted_at is null
$$;

-- الفروع اللي المستخدم الحالي يشتغل فيها
create or replace function public.my_branch_ids() returns uuid[]
language sql stable security definer set search_path = public as $$
  select case
    when public.current_app_role() = 'owner' then
      array(select b.id from public.branches b where b.shop_id = public.current_shop_id() and b.deleted_at is null order by b.is_main desc, b.created_at)
    else coalesce(
      nullif(array(select sb.branch_id from public.staff_branches sb join public.branches b on b.id = sb.branch_id and b.deleted_at is null
                   where sb.profile_id = auth.uid() and sb.deleted_at is null and sb.shop_id = public.current_shop_id()
                   order by b.is_main desc, b.created_at), '{}'),
      array[public.main_branch(public.current_shop_id())])
  end
$$;

create or replace function public.can_branch(p uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select p is not null and p = any (public.my_branch_ids())
$$;

-- فرع العملية الحالية:
-- 1) app.branch: بتحطه دوال البرنامج نفسها (الخزنة المختارة، أو فرع القيد الأصلي في التصحيح)
-- 2) الهيدر x-branch-id من التطبيق (لو الموظف ليه الفرع ده)
-- 3) الافتراضي: الرئيسي لو ليه، وإلا أول فرع ليه
create or replace function public.op_branch() returns uuid
language plpgsql stable security definer set search_path = public as $$
declare g text := nullif(current_setting('app.branch', true), ''); h text; mine uuid[];
begin
  if g is not null then return g::uuid; end if;
  mine := public.my_branch_ids();
  begin
    h := nullif(current_setting('request.headers', true), '')::json ->> 'x-branch-id';
  exception when others then h := null;
  end;
  if h ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' and h::uuid = any (mine) then return h::uuid; end if;
  return coalesce((select x from unnest(mine) x where x = public.main_branch(public.current_shop_id())), mine[1]);
end $$;

-- بيثبّت فرع العملية لآخر الـ transaction (لو لسه ما اتحددش)
create or replace function public.pin_branch(p uuid) returns void
language plpgsql security definer set search_path = public as $$
begin
  if p is not null and nullif(current_setting('app.branch', true), '') is null then
    perform set_config('app.branch', p::text, true);
  end if;
end $$;

revoke execute on function public.main_branch(uuid), public.op_branch(), public.pin_branch(uuid) from public, anon, authenticated;
revoke execute on function public.my_branch_ids(), public.can_branch(uuid) from public, anon;
grant execute on function public.my_branch_ids(), public.can_branch(uuid) to authenticated;

-- ---------- الفرع الرئيسي لكل محل (الموجود والجديد) ----------
insert into public.branches(shop_id, name, is_main)
select s.id, 'الفرع الرئيسي', true from public.shops s
where not exists (select 1 from public.branches b where b.shop_id = s.id and b.is_main and b.deleted_at is null);

create or replace function public.tg_shop_main_branch() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  insert into public.branches(shop_id, name, is_main) values (new.id, 'الفرع الرئيسي', true);
  return null;
end $$;
-- a_: لازم يشتغل قبل zz_shop_ledger (الخزن الأساسية بتتعمل في الفرع الرئيسي)
create trigger a_shop_main_branch after insert on public.shops for each row execute function public.tg_shop_main_branch();

-- ---------- عمود الفرع ----------
alter table public.devices add column branch_id uuid references public.branches(id);
alter table public.devices add column transfer_to uuid references public.branches(id);
alter table public.devices add column transfer_at timestamptz;
alter table public.devices add column transfer_by uuid references public.profiles(id);
alter table public.accounts add column branch_id uuid references public.branches(id);
alter table public.journal_entries add column branch_id uuid references public.branches(id);
alter table public.stock_moves add column branch_id uuid references public.branches(id);
alter table public.order_counters add column branch_id uuid references public.branches(id);

-- النقل: كل الموجود ← الفرع الرئيسي. القيود والمخزون ما بيتعدلوش عادي، فالحماية بتتقفل لحظة النقل بس (وفي نفس الـ transaction)
alter table public.devices disable trigger user;
alter table public.accounts disable trigger user;
alter table public.journal_entries disable trigger user;
alter table public.stock_moves disable trigger user;
alter table public.order_counters disable trigger user;
update public.devices set branch_id = public.main_branch(shop_id) where branch_id is null;
update public.accounts set branch_id = public.main_branch(shop_id) where branch_id is null and kind = 'cash';
update public.journal_entries set branch_id = public.main_branch(shop_id) where branch_id is null;
update public.stock_moves set branch_id = public.main_branch(shop_id) where branch_id is null;
update public.order_counters set branch_id = public.main_branch(shop_id) where branch_id is null;
alter table public.devices enable trigger user;
alter table public.accounts enable trigger user;
alter table public.journal_entries enable trigger user;
alter table public.stock_moves enable trigger user;
alter table public.order_counters enable trigger user;

alter table public.devices alter column branch_id set not null;
alter table public.journal_entries alter column branch_id set not null;
alter table public.stock_moves alter column branch_id set not null;
alter table public.order_counters alter column branch_id set not null;
alter table public.accounts add constraint accounts_branch_cash check ((kind = 'cash') = (branch_id is not null));
alter table public.order_counters drop constraint order_counters_shop_id_year_key;
alter table public.order_counters add constraint order_counters_branch_year unique (shop_id, branch_id, year);
create index devices_branch on public.devices(shop_id, branch_id);
create index entries_branch on public.journal_entries(shop_id, branch_id);
create index moves_item_branch on public.stock_moves(item_id, branch_id);

-- ---------- الافتراضي والتأكد ----------
-- الجهاز والخزنة: الفرع الشغال (ولازم يكون من فروع الموظف)
create or replace function public.tg_branch_default() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if TG_TABLE_NAME = 'accounts' and new.kind <> 'cash' then
    new.branch_id := null;
    return new;
  end if;
  if new.branch_id is null then
    if public.restoring() or auth.uid() is null or public.current_shop_id() is distinct from new.shop_id or new.code is not null then
      new.branch_id := public.main_branch(new.shop_id);
    else
      new.branch_id := public.op_branch();
    end if;
  end if;
  -- (وقت الاسترجاع: الفرع ممكن يكون اتقفل قبل كده، وصفوفه القديمة بترجع زي ما هي)
  if not exists (select 1 from public.branches b where b.id = new.branch_id and b.shop_id = new.shop_id and (b.deleted_at is null or public.restoring())) then
    raise exception 'E_BAD_BRANCH';
  end if;
  return new;
end $$;
-- الأجهزة ما فيهاش code: نسخة منفصلة عشان new.code
create or replace function public.tg_device_branch_default() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if new.branch_id is null then
    if public.restoring() or auth.uid() is null or public.current_shop_id() is distinct from new.shop_id then
      new.branch_id := public.main_branch(new.shop_id);
    else
      new.branch_id := public.op_branch();
    end if;
  end if;
  -- (وقت الاسترجاع: الفرع ممكن يكون اتقفل قبل كده، وصفوفه القديمة بترجع زي ما هي)
  if not exists (select 1 from public.branches b where b.id = new.branch_id and b.shop_id = new.shop_id and (b.deleted_at is null or public.restoring())) then
    raise exception 'E_BAD_BRANCH';
  end if;
  if not public.restoring() and auth.uid() is not null and not public.can_branch(new.branch_id) then raise exception 'E_FORBIDDEN'; end if;
  new.transfer_to := null;
  new.transfer_at := null;
  new.transfer_by := null;
  return new;
end $$;
-- b_: بعد a_force_shop_id وقبل device_defaults (رقم الطلب بيتحسب من الفرع)
create trigger b_branch_default before insert on public.devices for each row execute function public.tg_device_branch_default();
create trigger b_branch_default before insert on public.accounts for each row execute function public.tg_branch_default();

-- فرع الجهاز بيتغيّر من النقل بس (بعت/استلام)
create or replace function public.tg_device_branch_guard() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if (new.branch_id is distinct from old.branch_id or new.transfer_to is distinct from old.transfer_to
      or new.transfer_at is distinct from old.transfer_at or new.transfer_by is distinct from old.transfer_by)
     and not public.restoring() and current_setting('app.device_move', true) is distinct from 'on' then
    raise exception 'E_BRANCH_MOVE';
  end if;
  return new;
end $$;
create trigger b_device_branch_guard before update on public.devices for each row execute function public.tg_device_branch_guard();

-- فرع الخزنة ما بيتغيرش بعد ما اتعملت (رصيدها بتاع الفرع ده)
create or replace function public.tg_account_branch_guard() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if new.branch_id is distinct from old.branch_id and not public.restoring() then raise exception 'E_BRANCH_MOVE'; end if;
  return new;
end $$;
create trigger b_account_branch_guard before update on public.accounts for each row execute function public.tg_account_branch_guard();

-- القيد: الفرع المثبّت للعملية (الخزنة أو التصحيح)، وإلا فرع الجهاز، وإلا الفرع الشغال
create or replace function public.tg_entry_branch() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if new.branch_id is null then
    new.branch_id := coalesce(
      nullif(current_setting('app.branch', true), '')::uuid,
      (select d.branch_id from public.devices d where d.id = new.device_id),
      case when public.current_shop_id() = new.shop_id then public.op_branch() end,
      public.main_branch(new.shop_id));
  end if;
  if not exists (select 1 from public.branches b where b.id = new.branch_id and b.shop_id = new.shop_id) then raise exception 'E_BAD_BRANCH'; end if;
  return new;
end $$;
create trigger b_entry_branch before insert on public.journal_entries for each row execute function public.tg_entry_branch();

-- حركة المخزون: فرع قيدها (إلا التحويل بين الفروع وعكسه: كل حركة بفرعها)
create or replace function public.tg_move_branch() returns trigger
language plpgsql security definer set search_path = public as $$
declare eb uuid; st text;
begin
  select e.branch_id, e.source_type into eb, st from public.journal_entries e where e.id = new.entry_id;
  if new.branch_id is null then new.branch_id := eb; end if;
  if new.branch_id is distinct from eb and st not in ('stock_transfer', 'reversal') and not public.restoring() then raise exception 'E_BAD_BRANCH'; end if;
  if not exists (select 1 from public.branches b where b.id = new.branch_id and b.shop_id = new.shop_id) then raise exception 'E_BAD_BRANCH'; end if;
  return new;
end $$;
create trigger b_move_branch before insert on public.stock_moves for each row execute function public.tg_move_branch();

-- سطر خزنة لازم يكون من فرع القيد (إلا تحويل الفلوس بين الفروع وعكسه)
create or replace function public.tg_line_branch() returns trigger
language plpgsql security definer set search_path = public as $$
declare ab uuid; eb uuid; st text; rv uuid;
begin
  select a.branch_id into ab from public.accounts a where a.id = new.account_id and a.kind = 'cash';
  if ab is null or public.restoring() then return new; end if;
  select e.branch_id, e.source_type, e.reverses_id into eb, st, rv from public.journal_entries e where e.id = new.entry_id;
  if ab is distinct from eb and st <> 'transfer'
     and not (st = 'reversal' and exists (select 1 from public.journal_entries o where o.id = rv and o.source_type = 'transfer')) then
    raise exception 'E_BRANCH_CASHBOX';
  end if;
  return new;
end $$;
create trigger b_line_branch before insert on public.journal_lines for each row execute function public.tg_line_branch();

-- ---------- أنواع القيود: تحويل بضاعة بين الفروع ----------
alter table public.journal_entries drop constraint if exists journal_entries_source_type_check;
alter table public.journal_entries add constraint journal_entries_source_type_check check (source_type = any (array[
  'payment', 'delivery', 'purchase', 'supplier_payment', 'part_use', 'sale', 'expense', 'salary', 'salary_payment', 'advance',
  'advance_settle', 'capital', 'drawing', 'transfer', 'drawer_close', 'reversal', 'cost_adjust',
  'write_off', 'supplier_return', 'sale_return', 'opening', 'partner_capital', 'partner_withdrawal', 'profit_distribution', 'netting',
  'stock_transfer']));

-- ---------- رقم الطلب: بادئة الفرع ----------
CREATE OR REPLACE FUNCTION public.tg_device_defaults()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  y integer := extract(year from (now() at time zone 'Africa/Cairo'))::integer;
  n integer;
  pre text;
begin
  -- وقت الاسترجاع: الصف راجع زي ما هو من النسخة (src: 0023)
  if public.restoring() then return new; end if;
  select b.prefix into pre from public.branches b where b.id = new.branch_id;
  insert into public.order_counters(shop_id, branch_id, year, last_value)
  values (new.shop_id, new.branch_id, y, 1)
  on conflict (shop_id, branch_id, year) do update set last_value = public.order_counters.last_value + 1
  returning last_value into n;
  -- الرئيسي: 2026-0042 زي الأول. فرع تاني: B2-2026-0001
  new.order_no := case when coalesce(pre, '') = '' then '' else pre || '-' end || y::text || '-' || lpad(n::text, 4, '0');
  new.status := 'received';
  new.received_by := auth.uid();
  new.received_at := now();
  new.delivered_at := null;
  return new;
end $function$;

-- ---------- المخزون لكل فرع ----------
create or replace function public.item_stock_at(p_item uuid, p_branch uuid, out qty bigint, out value bigint)
language sql stable security definer set search_path = public as $$
  select coalesce(sum(m.qty), 0)::bigint, coalesce(sum(m.value), 0)::bigint from public.stock_moves m where m.item_id = p_item and m.branch_id = p_branch
$$;
create or replace function public.item_stock(p_item uuid, out qty bigint, out value bigint)
language sql stable security definer set search_path = public as $$
  select * from public.item_stock_at(p_item, public.op_branch())
$$;
revoke execute on function public.item_stock(uuid), public.item_stock_at(uuid, uuid) from public, anon, authenticated;

-- الخروج من المخزون: من فرع القيد نفسه، بالمتوسط المرجّح بتاع الفرع ده
create or replace function public.ledger_issue(p_item uuid, p_qty bigint, p_entry uuid) returns bigint
language plpgsql security definer set search_path = public as $$
declare st record; cost bigint; b uuid;
begin
  perform 1 from public.items where id = p_item and shop_id = public.current_shop_id() and deleted_at is null for update;
  if not found then raise exception 'E_NOT_FOUND'; end if;
  select e.branch_id into b from public.journal_entries e where e.id = p_entry;
  select * into st from public.item_stock_at(p_item, b);
  if p_qty <= 0 or st.qty < p_qty then raise exception 'E_STOCK'; end if;
  cost := public.ledger_issue_cost(st.qty, st.value, p_qty);
  insert into public.stock_moves(shop_id, item_id, entry_id, qty, value, branch_id) values (public.current_shop_id(), p_item, p_entry, -p_qty, -cost, b);
  return cost;
end $$;
revoke execute on function public.ledger_issue(uuid, bigint, uuid) from public, anon, authenticated;

-- تسوية صنف في فرع: لو كميته صفر وفيه قيمة باقية، أو قيمته بالسالب، الفرق بيروح تكلفة البضاعة
drop function if exists public.ledger_settle_item(uuid, uuid);
create or replace function public.ledger_settle_item(p_item uuid, p_device uuid default null, p_branch uuid default null) returns void
language plpgsql security definer set search_path = public as $$
declare st record; v bigint; e uuid; b uuid; old text := current_setting('app.branch', true);
begin
  b := coalesce(p_branch, nullif(old, '')::uuid, (select d.branch_id from public.devices d where d.id = p_device), public.op_branch());
  select * into st from public.item_stock_at(p_item, b);
  if not ((st.qty = 0 and st.value <> 0) or (st.qty > 0 and st.value < 0)) then return; end if;
  v := st.value;
  perform set_config('app.branch', b::text, true);
  e := public.ledger_post('cost_adjust', p_item, 'فرق تكلفة مخزون',
    case when v > 0 then jsonb_build_array(public.ledger_line(public.ledger_acc('cogs'), v, 0), public.ledger_line(public.ledger_acc('inventory'), 0, v))
         else jsonb_build_array(public.ledger_line(public.ledger_acc('inventory'), -v, 0), public.ledger_line(public.ledger_acc('cogs'), 0, -v)) end,
    p_device);
  insert into public.stock_moves(shop_id, item_id, entry_id, qty, value, branch_id) values (public.current_shop_id(), p_item, e, 0, -v, b);
  perform set_config('app.branch', coalesce(old, ''), true);
end $$;
revoke execute on function public.ledger_settle_item(uuid, uuid, uuid) from public, anon, authenticated;

-- الخزنة: لازم تكون في فرع من فروع الموظف، وبتحدد فرع العملية (أول خزنة في العملية)
create or replace function public.ledger_cashbox(p uuid) returns public.accounts
language plpgsql security definer set search_path = public as $$
declare a public.accounts;
begin
  select * into a from public.accounts where id = p and shop_id = public.current_shop_id() and kind = 'cash' and active and deleted_at is null;
  if not found then raise exception 'E_BAD_ACCOUNT'; end if;
  if not public.can_branch(a.branch_id) then raise exception 'E_FORBIDDEN'; end if;
  perform public.pin_branch(a.branch_id);
  return a;
end $$;
revoke execute on function public.ledger_cashbox(uuid) from public, anon, authenticated;

-- ---------- RLS ----------
create policy branches_select on public.branches for select to authenticated
  using (shop_id = public.current_shop_id());
create policy staff_branches_select on public.staff_branches for select to authenticated
  using (shop_id = public.current_shop_id() and (public.current_app_role() = 'owner' or profile_id = auth.uid()));
grant select on public.branches, public.staff_branches to authenticated;

-- الأجهزة: فروع الموظف بس (والجهاز اللي في الطريق لفرعه)
drop policy if exists devices_select on public.devices;
create policy devices_select on public.devices for select to authenticated
  using (shop_id = public.current_shop_id()
         and (branch_id in (select unnest(public.my_branch_ids())) or transfer_to in (select unnest(public.my_branch_ids())))
         and (public.current_app_role() <> 'technician' or public.tech_can_see(id)));
drop policy if exists devices_insert on public.devices;
create policy devices_insert on public.devices for insert to authenticated
  with check (shop_id = public.current_shop_id() and public.current_app_role() in ('owner','reception') and branch_id in (select unnest(public.my_branch_ids())));
drop policy if exists devices_update on public.devices;
create policy devices_update on public.devices for update to authenticated
  using (shop_id = public.current_shop_id() and branch_id in (select unnest(public.my_branch_ids())))
  with check (shop_id = public.current_shop_id());

-- الخزن: الاستقبال بيشوف خزن فروعه بس
drop policy if exists accounts_select on public.accounts;
create policy accounts_select on public.accounts for select to authenticated using (
  shop_id = public.current_shop_id() and (public.current_app_role() = 'owner'
    or (public.current_app_role() = 'reception' and kind = 'cash' and branch_id in (select unnest(public.my_branch_ids())))));

-- ---------- إدارة الفروع (صاحب المحل) ----------
-- إضافة أو تعديل فرع. الفرع الجديد بيتعمله خزنة لكل طريقة دفع في المحل
create or replace function public.save_branch(p_id uuid, p_name text, p_prefix text, p_phone text default null, p_address text default null) returns uuid
language plpgsql security definer set search_path = public as $$
declare s uuid := public.current_shop_id(); b public.branches; pre text := upper(trim(coalesce(p_prefix, ''))); m text; nm text := trim(coalesce(p_name, ''));
begin
  perform public.ledger_require(array['owner']::public.app_role[]);
  if nm = '' or length(nm) > 80 then raise exception 'E_BAD_INPUT'; end if;
  select * into b from public.branches where id = p_id and shop_id = s for update;
  if found then
    if b.deleted_at is not null then raise exception 'E_NOT_FOUND'; end if;
    if b.is_main then pre := b.prefix; end if; -- الرئيسي: أرقامه زي ما هي
    if pre !~ '^[A-Z0-9]{1,4}$' and not b.is_main then raise exception 'E_BAD_PREFIX'; end if;
    if exists (select 1 from public.branches x where x.shop_id = s and x.deleted_at is null and x.id <> b.id and x.prefix = pre) then raise exception 'E_DUP_PREFIX'; end if;
    if exists (select 1 from public.branches x where x.shop_id = s and x.deleted_at is null and x.id <> b.id and lower(trim(x.name)) = lower(nm)) then raise exception 'E_DUP_NAME'; end if;
    update public.branches set name = nm, prefix = pre, phone = nullif(trim(p_phone), ''), address = nullif(trim(p_address), '') where id = b.id;
    return b.id;
  end if;
  if pre !~ '^[A-Z0-9]{1,4}$' then raise exception 'E_BAD_PREFIX'; end if;
  if exists (select 1 from public.branches x where x.shop_id = s and x.deleted_at is null and x.prefix = pre) then raise exception 'E_DUP_PREFIX'; end if;
  if exists (select 1 from public.branches x where x.shop_id = s and x.deleted_at is null and lower(trim(x.name)) = lower(nm)) then raise exception 'E_DUP_NAME'; end if;
  insert into public.branches(id, shop_id, name, prefix, phone, address) values (p_id, s, nm, pre, nullif(trim(p_phone), ''), nullif(trim(p_address), ''));
  for m in select unnest(array['cash']) union select unnest(payment_methods) from public.shops where id = s loop
    insert into public.accounts(shop_id, name, type, kind, method, branch_id) values (s, nm, 'asset', 'cash', m, p_id);
  end loop;
  return p_id;
end $$;

-- قفل فرع (soft delete): مش الرئيسي، ومن غير أجهزة مفتوحة ولا فلوس في خزنه ولا مخزون
create or replace function public.archive_branch(p_id uuid) returns void
language plpgsql security definer set search_path = public as $$
declare s uuid := public.current_shop_id(); b public.branches;
begin
  perform public.ledger_require(array['owner']::public.app_role[]);
  select * into b from public.branches where id = p_id and shop_id = s and deleted_at is null for update;
  if not found then raise exception 'E_NOT_FOUND'; end if;
  if b.is_main then raise exception 'E_MAIN_BRANCH'; end if;
  if exists (select 1 from public.devices d where (d.branch_id = p_id or d.transfer_to = p_id) and d.deleted_at is null and d.status not in ('delivered', 'unrepairable')) then raise exception 'E_HAS_OPEN_DEVICES'; end if;
  if exists (select 1 from public.journal_lines l join public.accounts a on a.id = l.account_id where a.branch_id = p_id group by a.id having sum(l.debit - l.credit) <> 0) then raise exception 'E_HAS_BALANCE'; end if;
  if exists (select 1 from public.stock_moves m where m.branch_id = p_id group by m.item_id having sum(m.qty) <> 0 or sum(m.value) <> 0) then raise exception 'E_HAS_STOCK'; end if;
  update public.accounts set active = false where branch_id = p_id;
  update public.staff_branches set deleted_at = now() where branch_id = p_id and deleted_at is null;
  update public.branches set deleted_at = now() where id = p_id;
end $$;

-- فروع الموظف (صاحب المحل بيشوف كل الفروع دايمًا)
create or replace function public.set_staff_branches(p_profile uuid, p_branches uuid[]) returns void
language plpgsql security definer set search_path = public as $$
declare s uuid := public.current_shop_id(); before uuid[];
begin
  perform public.ledger_require(array['owner']::public.app_role[]);
  if not exists (select 1 from public.profiles where id = p_profile and shop_id = s and deleted_at is null and role <> 'owner') then raise exception 'E_NOT_FOUND'; end if;
  if coalesce(array_length(p_branches, 1), 0) = 0 then raise exception 'E_BAD_INPUT'; end if;
  if exists (select 1 from unnest(p_branches) x where not exists (select 1 from public.branches b where b.id = x and b.shop_id = s and b.deleted_at is null)) then raise exception 'E_BAD_BRANCH'; end if;
  before := array(select branch_id from public.staff_branches where profile_id = p_profile and deleted_at is null);
  update public.staff_branches set deleted_at = now() where profile_id = p_profile and deleted_at is null and branch_id <> all (p_branches);
  insert into public.staff_branches(shop_id, profile_id, branch_id)
  select s, p_profile, x from unnest(p_branches) x
  where not exists (select 1 from public.staff_branches sb where sb.profile_id = p_profile and sb.branch_id = x and sb.deleted_at is null);
  insert into public.audit_log(shop_id, actor_id, action, entity, entity_id, before, after)
  values (s, auth.uid(), 'staff_branches', 'profiles', p_profile, jsonb_build_object('branches', before), jsonb_build_object('branches', p_branches));
end $$;

-- ---------- بين الفروع ----------
-- تحويل بضاعة: بتخرج من فرع بالمتوسط المرجّح بتاعه وتدخل الفرع التاني بنفس القيمة. حساب المخزون زي ما هو (القيد بيتقابل)
create or replace function public.transfer_stock(p_id uuid, p_item uuid, p_qty integer, p_from uuid, p_to uuid, p_note text default null) returns uuid
language plpgsql security definer set search_path = public as $$
declare s uuid := public.current_shop_id(); e uuid; cost bigint; inv uuid := public.ledger_acc('inventory');
begin
  perform public.ledger_require(array['owner']::public.app_role[]);
  e := public.ledger_idem(p_id);
  if e is not null then return e; end if;
  if p_from is null or p_to is null or p_from = p_to or coalesce(p_qty, 0) <= 0 then raise exception 'E_BAD_INPUT'; end if;
  if not exists (select 1 from public.branches where id = p_from and shop_id = s and deleted_at is null)
     or not exists (select 1 from public.branches where id = p_to and shop_id = s and deleted_at is null) then raise exception 'E_BAD_BRANCH'; end if;
  perform set_config('app.branch', p_from::text, true);
  e := gen_random_uuid();
  insert into public.journal_entries(id, shop_id, source_type, source_id, memo, idem_key, created_by, branch_id)
  values (e, s, 'stock_transfer', p_item, nullif(trim(p_note), ''), p_id, auth.uid(), p_from);
  cost := public.ledger_issue(p_item, p_qty, e);
  if cost <= 0 then raise exception 'E_BAD_AMOUNT'; end if;
  insert into public.stock_moves(shop_id, item_id, entry_id, qty, value, branch_id) values (s, p_item, e, p_qty, cost, p_to);
  insert into public.journal_lines(shop_id, entry_id, account_id, debit, credit) values (s, e, inv, cost, 0), (s, e, inv, 0, cost);
  perform public.ledger_settle_item(p_item, null, p_from);
  insert into public.audit_log(shop_id, actor_id, action, entity, entity_id, after)
  values (s, auth.uid(), 'stock_transfer', 'items', p_item, jsonb_build_object('qty', p_qty, 'from', p_from, 'to', p_to, 'value', cost, 'entry', e));
  return e;
end $$;

-- جهاز "في الطريق للفرع": بيتبعت من فرعه، والفرع التاني بيستلمه (أو بيتلغي)
create or replace function public.send_device(p_device uuid, p_to uuid) returns void
language plpgsql security definer set search_path = public as $$
declare s uuid := public.current_shop_id(); d public.devices;
begin
  perform public.ledger_require(array['owner', 'reception']::public.app_role[]);
  select * into d from public.devices where id = p_device and shop_id = s and deleted_at is null for update;
  if not found or not public.can_branch(d.branch_id) then raise exception 'E_NOT_FOUND'; end if;
  if d.status = 'delivered' then raise exception 'E_DELIVERED'; end if;
  if d.transfer_to is not null then raise exception 'E_IN_TRANSIT'; end if;
  if p_to = d.branch_id or not exists (select 1 from public.branches where id = p_to and shop_id = s and deleted_at is null) then raise exception 'E_BAD_BRANCH'; end if;
  perform set_config('app.device_move', 'on', true);
  update public.devices set transfer_to = p_to, transfer_at = now(), transfer_by = auth.uid() where id = d.id;
  perform set_config('app.device_move', 'off', true);
  insert into public.audit_log(shop_id, actor_id, action, entity, entity_id, before, after)
  values (s, auth.uid(), 'device_send', 'devices', d.id, jsonb_build_object('branch', d.branch_id), jsonb_build_object('to', p_to));
end $$;

create or replace function public.receive_device(p_device uuid) returns void
language plpgsql security definer set search_path = public as $$
declare s uuid := public.current_shop_id(); d public.devices;
begin
  perform public.ledger_require(array['owner', 'reception']::public.app_role[]);
  select * into d from public.devices where id = p_device and shop_id = s and deleted_at is null for update;
  if not found or d.transfer_to is null then raise exception 'E_NOT_FOUND'; end if;
  if not public.can_branch(d.transfer_to) then raise exception 'E_FORBIDDEN'; end if;
  perform set_config('app.device_move', 'on', true);
  update public.devices set branch_id = d.transfer_to, transfer_to = null, transfer_at = null, transfer_by = null where id = d.id;
  perform set_config('app.device_move', 'off', true);
  insert into public.audit_log(shop_id, actor_id, action, entity, entity_id, before, after)
  values (s, auth.uid(), 'device_receive', 'devices', d.id, jsonb_build_object('branch', d.branch_id), jsonb_build_object('branch', d.transfer_to));
end $$;

create or replace function public.cancel_device_transfer(p_device uuid) returns void
language plpgsql security definer set search_path = public as $$
declare s uuid := public.current_shop_id(); d public.devices;
begin
  perform public.ledger_require(array['owner', 'reception']::public.app_role[]);
  select * into d from public.devices where id = p_device and shop_id = s and deleted_at is null for update;
  if not found or d.transfer_to is null then raise exception 'E_NOT_FOUND'; end if;
  if not (public.can_branch(d.branch_id) or public.can_branch(d.transfer_to)) then raise exception 'E_FORBIDDEN'; end if;
  perform set_config('app.device_move', 'on', true);
  update public.devices set transfer_to = null, transfer_at = null, transfer_by = null where id = d.id;
  perform set_config('app.device_move', 'off', true);
  insert into public.audit_log(shop_id, actor_id, action, entity, entity_id, before, after)
  values (s, auth.uid(), 'device_transfer_cancel', 'devices', d.id, jsonb_build_object('to', d.transfer_to), null);
end $$;

-- مخزون صنف في كل فرع (للتحويل وشاشة المخزون)
create or replace function public.item_branch_stock(p_item uuid) returns table(branch_id uuid, qty bigint, value bigint)
language sql stable security definer set search_path = public as $$
  select b.id, coalesce(sum(m.qty), 0)::bigint, coalesce(sum(m.value), 0)::bigint
  from public.branches b left join public.stock_moves m on m.branch_id = b.id and m.item_id = p_item
  where b.shop_id = public.current_shop_id() and b.deleted_at is null and b.id = any (public.my_branch_ids())
    and public.current_app_role() in ('owner', 'reception', 'technician')
  group by b.id
$$;

revoke execute on function public.save_branch(uuid, text, text, text, text), public.archive_branch(uuid), public.set_staff_branches(uuid, uuid[]),
  public.transfer_stock(uuid, uuid, integer, uuid, uuid, text), public.send_device(uuid, uuid), public.receive_device(uuid),
  public.cancel_device_transfer(uuid), public.item_branch_stock(uuid) from public, anon;
grant execute on function public.save_branch(uuid, text, text, text, text), public.archive_branch(uuid), public.set_staff_branches(uuid, uuid[]),
  public.transfer_stock(uuid, uuid, integer, uuid, uuid, text), public.send_device(uuid, uuid), public.receive_device(uuid),
  public.cancel_device_transfer(uuid), public.item_branch_stock(uuid) to authenticated;


-- قايمة الأجهزة: الفرع، والجهاز اللي في الطريق لفرع (أعمدة جديدة في الآخر)
create or replace view public.devices_list with (security_invoker = true) as
select d.id, d.shop_id, d.order_no, d.brand, d.model, d.imei, d.color, d.status,
       d.received_at, d.delivered_at, d.customer_id, d.deleted_at,
       c.name as customer_name, c.phone as customer_phone,
       dc.estimated_cost, dc.final_cost, d.warranty_until,
       d.branch_id, d.transfer_to
from public.devices d
left join public.customers c on c.id = d.customer_id
left join public.device_costs dc on dc.device_id = d.id and dc.deleted_at is null;

-- ---------- دوال موجودة اتعدّلت للفروع ----------
-- bootstrap_account: (src: 0004_error_codes.sql)
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
    -- فروع الموظف من الدعوة (لو فاضية: الفرع الرئيسي بس)
    insert into public.staff_branches(shop_id, profile_id, branch_id)
    select inv.shop_id, uid, b.id from public.branches b where b.shop_id = inv.shop_id and b.deleted_at is null and b.id = any (inv.branch_ids);
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

-- reverse_entry: (src: 0026_edit_delete.sql)
CREATE OR REPLACE FUNCTION public.reverse_entry(p_entry uuid, p_reason text)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  o public.journal_entries;
  e uuid;
  lines jsonb;
  mv record;
begin
  if public.current_app_role() is null or not public.can_correct() then raise exception 'E_FORBIDDEN'; end if;
  if nullif(trim(p_reason), '') is null then raise exception 'E_REASON_REQUIRED'; end if;
  select * into o from public.journal_entries where id = p_entry and shop_id = public.current_shop_id() for update;
  if not found then raise exception 'E_NOT_FOUND'; end if;
  if o.source_type in ('reversal', 'cost_adjust') or exists (select 1 from public.journal_entries where reverses_id = o.id) then
    raise exception 'E_ALREADY_REVERSED';
  end if;
  select jsonb_agg(public.ledger_line(account_id, credit, debit, party_type, party_id)) into lines
  from public.journal_lines where entry_id = o.id;
  -- العكس بيتسجل في نفس فرع القيد الأصلي
  perform set_config('app.branch', o.branch_id::text, true);
  e := public.ledger_post('reversal', o.source_id, p_reason, lines, o.device_id, null, o.id);
  for mv in select * from public.stock_moves where entry_id = o.id loop
    perform 1 from public.items where id = mv.item_id for update;
    if (select coalesce(sum(qty), 0) from public.stock_moves where item_id = mv.item_id and branch_id = mv.branch_id) - mv.qty < 0 then
      raise exception 'E_STOCK';
    end if;
    insert into public.stock_moves(shop_id, item_id, entry_id, qty, value, branch_id) values (mv.shop_id, mv.item_id, e, -mv.qty, -mv.value, mv.branch_id);
  end loop;
  for mv in select distinct item_id, branch_id from public.stock_moves where entry_id = o.id loop
    perform public.ledger_settle_item(mv.item_id, o.device_id, mv.branch_id);
  end loop;
  insert into public.audit_log(shop_id, actor_id, action, entity, entity_id, before, after)
  values (o.shop_id, auth.uid(), 'reverse_entry', 'journal_entries', o.id, to_jsonb(o), jsonb_build_object('reversal_id', e, 'reason', p_reason));
  return e;
end $function$;

-- backup_snapshot: (src: 0032_lists.sql)
create or replace function public.backup_snapshot(p_shop uuid) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare
  res jsonb := jsonb_build_object('format', 'warsha-backup', 'version', 1, 'generated_at', now(), 'shop_id', p_shop);
  t text;
  rows jsonb;
begin
  foreach t in array array['shops', 'branches', 'staff_branches', 'shop_branding', 'profiles', 'customers', 'devices', 'device_costs', 'status_log', 'device_notes', 'device_photos', 'device_checks',
                           'quote_decisions', 'message_templates', 'message_log', 'accounts', 'journal_entries', 'journal_lines', 'payments', 'drawer_closings',
                           'suppliers', 'items', 'stock_moves', 'purchases', 'labor_rates', 'specialties', 'staff_specialties', 'routes', 'repair_steps',
                           'repair_videos', 'device_ratings', 'issue_presets', 'partners', 'profit_distributions', 'party_links', 'shop_lists', 'audit_log'] loop
    execute format('select coalesce(jsonb_agg(to_jsonb(x)), ''[]''::jsonb) from public.%I x where x.shop_id = $1', t) into rows using p_shop;
    res := res || jsonb_build_object(t, rows);
  end loop;
  select coalesce(jsonb_agg(jsonb_build_object('device_id', device_id, 'kind', kind, 'erased_at', erased_at)), '[]'::jsonb)
    into rows from public.device_passcodes where shop_id = p_shop;
  return res || jsonb_build_object('device_passcodes', rows);
end $$;

-- restore_backup: (src: 0032_lists.sql)
create or replace function public.restore_backup(p_data jsonb) returns jsonb
-- extensions: فيها gen_random_bytes على Supabase
language plpgsql security definer set search_path = public, extensions, pg_temp as $$
declare
  s uuid := public.current_shop_id();
  me uuid := auth.uid();
  old_shop uuid;
  old_owner uuid;
  sh jsonb;
  t text;
  r jsonb;
  rows jsonb;
  n int;
  bad int;
  counts jsonb := '{}'::jsonb;
  -- بالترتيب ده عشان كل صف يلاقي اللي بيشاور عليه
  tabs text[] := array['branches', 'profiles', 'staff_branches', 'shop_branding', 'accounts', 'customers', 'suppliers', 'party_links', 'partners', 'specialties', 'staff_specialties', 'routes', 'labor_rates',
                       'issue_presets', 'shop_lists', 'message_templates', 'items', 'devices', 'device_costs', 'status_log', 'device_notes', 'device_checks',
                       'quote_decisions', 'repair_steps', 'repair_videos', 'device_ratings', 'journal_entries', 'journal_lines', 'profit_distributions', 'payments',
                       'purchases', 'stock_moves', 'drawer_closings', 'message_log', 'audit_log'];
  -- الجداول دي ليها نسخة اتعملت مع التسجيل: بتتطابق بالكود (أو المفتاح) وبتاخد قيم النسخة
  keyed text[] := array['branches', 'accounts', 'routes', 'specialties', 'message_templates', 'labor_rates', 'shop_branding'];
begin
  perform public.ledger_require(array['owner']::public.app_role[]);
  if s is null or me is null then raise exception 'E_FORBIDDEN'; end if;
  if p_data is null or p_data->>'format' is distinct from 'warsha-backup' or coalesce((p_data->>'version')::int, 0) <> 1 then
    raise exception 'E_BACKUP_FORMAT';
  end if;
  old_shop := (p_data->>'shop_id')::uuid;
  if old_shop is null or old_shop = s then raise exception 'E_BACKUP_FORMAT'; end if;

  -- محل جديد فاضي بس
  if exists (select 1 from public.devices where shop_id = s) or exists (select 1 from public.customers where shop_id = s)
     or exists (select 1 from public.journal_entries where shop_id = s) or exists (select 1 from public.items where shop_id = s)
     or exists (select 1 from public.suppliers where shop_id = s) or exists (select 1 from public.payments where shop_id = s)
     or exists (select 1 from public.purchases where shop_id = s) or exists (select 1 from public.drawer_closings where shop_id = s)
     or exists (select 1 from public.stock_moves where shop_id = s)
     or exists (select 1 from public.profiles where shop_id = s and id <> me) then
    raise exception 'E_RESTORE_NOT_EMPTY';
  end if;

  perform set_config('warsha.restore', 'on', true);
  drop table if exists pg_temp._rmap;
  create temp table _rmap(old uuid primary key, new uuid not null) on commit drop;
  insert into _rmap values (old_shop, s);

  -- 1) بيانات المحل نفسه (من غير الخطة والإيقاف واللوجو اللي في Storage)
  sh := p_data->'shops'->0;
  if sh is not null then
    update public.shops set
      name = coalesce(sh->>'name', name), phone = sh->>'phone', address = sh->>'address',
      receipt_terms = coalesce(sh->>'receipt_terms', receipt_terms), warranty_days = coalesce((sh->>'warranty_days')::int, warranty_days),
      country = coalesce(sh->>'country', country), currency = coalesce(sh->>'currency', currency),
      payment_methods = coalesce(array(select jsonb_array_elements_text(sh->'payment_methods')), payment_methods),
      theme = coalesce(sh->>'theme', theme), locale = coalesce(sh->>'locale', locale),
      default_margin_pct = coalesce((sh->>'default_margin_pct')::int, default_margin_pct),
      extras = coalesce(sh->'extras', extras), max_discount_pct = coalesce((sh->>'max_discount_pct')::int, max_discount_pct)
    where id = s;
  end if;

  -- 2) الـ ids الجديدة
  -- صاحب المحل في النسخة = اللي بيسترجع دلوقتي
  select (x->>'id')::uuid into old_owner from jsonb_array_elements(coalesce(p_data->'profiles', '[]')) x
   where x->>'role' = 'owner' order by x->>'created_at' limit 1;
  if old_owner is not null then insert into _rmap values (old_owner, me) on conflict do nothing; end if;
  insert into _rmap select (x->>'id')::uuid, coalesce((select a.id from public.accounts a where a.shop_id = s and a.code = x->>'code' and x->>'code' is not null), gen_random_uuid())
    from jsonb_array_elements(coalesce(p_data->'accounts', '[]')) x on conflict do nothing;
  -- الفرع الرئيسي في النسخة = الفرع الرئيسي للمحل الجديد
  insert into _rmap select (x->>'id')::uuid, public.main_branch(s)
    from jsonb_array_elements(coalesce(p_data->'branches', '[]')) x where (x->>'is_main')::boolean and x->>'deleted_at' is null on conflict do nothing;
  insert into _rmap select (x->>'id')::uuid, coalesce((select a.id from public.routes a where a.shop_id = s and a.code = x->>'code' and x->>'code' is not null), gen_random_uuid())
    from jsonb_array_elements(coalesce(p_data->'routes', '[]')) x on conflict do nothing;
  insert into _rmap select (x->>'id')::uuid, coalesce((select a.id from public.specialties a where a.shop_id = s and a.code = x->>'code' and x->>'code' is not null), gen_random_uuid())
    from jsonb_array_elements(coalesce(p_data->'specialties', '[]')) x on conflict do nothing;
  insert into _rmap select (x->>'id')::uuid, coalesce((select a.id from public.message_templates a where a.shop_id = s and a.key = x->>'key'), gen_random_uuid())
    from jsonb_array_elements(coalesce(p_data->'message_templates', '[]')) x on conflict do nothing;
  insert into _rmap select (x->>'id')::uuid, coalesce((select a.id from public.labor_rates a where a.shop_id = s and a.deleted_at is null and lower(trim(a.issue)) = lower(trim(x->>'issue')) and x->>'deleted_at' is null), gen_random_uuid())
    from jsonb_array_elements(coalesce(p_data->'labor_rates', '[]')) x on conflict do nothing;
  insert into _rmap select (x->>'id')::uuid, coalesce((select a.id from public.shop_branding a where a.shop_id = s), gen_random_uuid())
    from jsonb_array_elements(coalesce(p_data->'shop_branding', '[]')) x on conflict do nothing;
  foreach t in array tabs loop
    insert into _rmap select (x->>'id')::uuid, gen_random_uuid() from jsonb_array_elements(coalesce(p_data->t, '[]')) x where x ? 'id' on conflict do nothing;
  end loop;

  -- 3) الصفوف نفسها بالترتيب
  foreach t in array tabs loop
    rows := '[]'::jsonb;
    for r in select public.restore_remap(x) from jsonb_array_elements(coalesce(p_data->t, '[]')) x loop
      if t = 'profiles' then
        -- صاحب المحل موجود أصلًا. الباقيين موظفين سابقين (من غير حساب دخول)
        continue when (r->>'id')::uuid = me;
        r := r || jsonb_build_object('deleted_at', coalesce(r->>'deleted_at', now()::text));
      elsif t = 'devices' then
        -- كود التتبع (الـ QR) بيفضل زي ما هو، إلا لو مستخدم في المشروع ده (المحل الأصلي لسه هنا)
        if exists (select 1 from public.devices d where d.tracking_token = r->>'tracking_token') then
          r := r || jsonb_build_object('tracking_token', encode(gen_random_bytes(12), 'hex'));
        end if;
      elsif t = 'journal_entries' then
        if r->>'idem_key' is not null and exists (select 1 from public.journal_entries j where j.idem_key = (r->>'idem_key')::uuid) then
          r := r || jsonb_build_object('idem_key', gen_random_uuid());
        end if;
      elsif t = 'accounts' and r->>'kind' = 'cash' and r->>'branch_id' is null then
        -- نسخة من قبل الفروع: الخزن كلها في الفرع الرئيسي
        r := r || jsonb_build_object('branch_id', public.main_branch(s));
      elsif t = 'shop_branding' then
        -- اللوجو الملون والحراري جوه الصف نفسه. الملف الأصلي في Storage مش جوه النسخة
        r := r || jsonb_build_object('logo_path', null);
      end if;
      if t = any (keyed) and exists (select 1 from _rmap m where m.new = (r->>'id')::uuid and m.old <> m.new)
         and (t <> 'shop_branding' or exists (select 1 from public.shop_branding b where b.id = (r->>'id')::uuid)) then
        -- موجود من التسجيل: بياخد قيم النسخة
        execute format('select count(*) from public.%I where id = $1', t) into n using (r->>'id')::uuid;
        if n > 0 then
          execute format('update public.%1$I x set (%2$s) = (select %2$s from jsonb_populate_record(null::public.%1$I, $1)) where x.id = $2', t,
            (select string_agg(quote_ident(c.column_name), ', ' order by c.ordinal_position) from information_schema.columns c
              where c.table_schema = 'public' and c.table_name = t and c.column_name not in ('id', 'shop_id')))
            using r, (r->>'id')::uuid;
          continue;
        end if;
      end if;
      rows := rows || jsonb_build_array(r);
    end loop;
    if jsonb_array_length(rows) > 0 then
      -- overriding system value: أرقام القيود (entry_no) بترجع زي ما هي
      execute format('insert into public.%1$I overriding system value select * from jsonb_populate_recordset(null::public.%1$I, $1)', t) using rows;
    end if;
    counts := counts || jsonb_build_object(t, jsonb_array_length(coalesce(p_data->t, '[]')));
  end loop;

  -- 4) عدّاد أرقام الطلبات: من آخر رقم راجع في كل سنة
  -- (لكل فرع: الرقم ممكن يبقى قبله بادئة الفرع B2-2026-0001)
  insert into public.order_counters(shop_id, branch_id, year, last_value)
  select s, branch_id, (regexp_match(order_no, '(\d{4})-(\d+)$'))[1]::int, max((regexp_match(order_no, '(\d{4})-(\d+)$'))[2]::int)
    from public.devices where shop_id = s and order_no ~ '\d{4}-\d+$' group by 2, 3
  on conflict (shop_id, branch_id, year) do update set last_value = greatest(public.order_counters.last_value, excluded.last_value);

  -- 5) التأكد: كل قيد متوازن، ورصيد كل حساب = رصيده في النسخة بالظبط
  select count(*) into bad from (
    select entry_id from public.journal_lines where shop_id = s group by entry_id having sum(debit) <> sum(credit)) x;
  if bad > 0 then raise exception 'E_RESTORE_UNBALANCED'; end if;
  select count(*) into bad from (
    select m.new acc, sum((l->>'debit')::bigint - (l->>'credit')::bigint) b
      from jsonb_array_elements(coalesce(p_data->'journal_lines', '[]')) l join _rmap m on m.old = (l->>'account_id')::uuid group by m.new
  ) x full join (select account_id, sum(debit - credit) b from public.journal_lines where shop_id = s group by account_id) y on y.account_id = x.acc
  where coalesce(x.b, 0) <> coalesce(y.b, 0);
  if bad > 0 then raise exception 'E_RESTORE_MISMATCH'; end if;
  -- وعدد الصفوف في كل جدول (الحسابات والقوالب اللي اتعملت مع التسجيل ممكن تزيد عن النسخة، مش تقل)
  foreach t in array tabs loop
    execute format('select count(*) from public.%I where shop_id = $1', t) into n using s;
    if n < jsonb_array_length(coalesce(p_data->t, '[]')) - (case when t = 'profiles' and old_owner is not null then 1 else 0 end) then
      raise exception 'E_RESTORE_MISMATCH';
    end if;
  end loop;

  perform set_config('warsha.restore', 'off', true);
  insert into public.audit_log(shop_id, actor_id, action, entity, entity_id, after)
  values (s, me, 'backup_restore', 'shops', s, jsonb_build_object('from_shop', old_shop, 'generated_at', p_data->>'generated_at', 'counts', counts));
  return jsonb_build_object('restored', true, 'counts', counts);
end $$;

-- ---------- المخزون في الشاشات: الفرع الشغال، أو كل الفروع (صاحب المحل) ----------
drop function if exists public.items_stock();
create or replace function public.items_stock(p_all boolean default false) returns table(id uuid, kind text, name text, sku text, sale_price integer, qty bigint, avg_cost bigint, value bigint, min_qty integer, supplier_id uuid, short boolean, category text, barcode text, image_path text)
language plpgsql stable security definer set search_path = public as $$
declare r public.app_role := public.current_app_role(); b uuid := public.op_branch(); everywhere boolean;
begin
  if r is null then raise exception 'E_FORBIDDEN'; end if;
  everywhere := p_all and r = 'owner';
  return query
  select i.id, i.kind, i.name, i.sku,
         case when r = 'technician' then null else i.sale_price end,
         coalesce(st.q, 0)::bigint,
         case when r = 'owner' and coalesce(st.q, 0) > 0 then (st.v / st.q)::bigint end,
         case when r = 'owner' then coalesce(st.v, 0)::bigint end,
         i.min_qty, case when r = 'owner' then i.supplier_id end,
         i.min_qty > 0 and coalesce(st.q, 0) <= i.min_qty,
         i.category, i.barcode, i.image_path
  from public.items i
  left join (select m.item_id, sum(m.qty) as q, sum(m.value) as v from public.stock_moves m where everywhere or m.branch_id = b group by m.item_id) st on st.item_id = i.id
  where i.shop_id = public.current_shop_id() and i.deleted_at is null
  order by i.kind, i.name;
end $$;
revoke execute on function public.items_stock(boolean) from public, anon;
grant execute on function public.items_stock(boolean) to authenticated;

-- ---------- الوضع المالي لفرع (التقارير بفلتر الفرع) ----------
-- financial_position: (src: 0031_partner_capital.sql)
drop function if exists public.financial_position(timestamptz, timestamptz);
create or replace function public.financial_position(p_from timestamptz, p_to timestamptz, p_branch uuid default null) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare
  s uuid := public.current_shop_id();
  res jsonb;
begin
  perform public.ledger_require(array['owner']::public.app_role[]);
  with bal as (
    select a.id, a.code, a.name, a.type, a.kind, a.method, l.party_type, l.party_id,
           coalesce(sum((l.debit - l.credit) * public.account_sign(a.type)), 0)::bigint as b
    from public.accounts a
    -- B: فرع واحد: الخزن بتاعته (كل حركاتها)، وباقي الحسابات من قيود الفرع ده
    left join public.journal_lines l on l.account_id = a.id
      and (p_branch is null or a.kind = 'cash' or exists (select 1 from public.journal_entries be where be.id = l.entry_id and be.branch_id = p_branch))
    where a.shop_id = s and (p_branch is null or a.kind <> 'cash' or a.branch_id = p_branch)
    group by a.id, l.party_type, l.party_id
  ),
  -- المعادلة والتوازن دايمًا للمحل كله (الدفتر واحد)
  bal_all as (
    select a.type, coalesce(sum((l.debit - l.credit) * public.account_sign(a.type)), 0)::bigint as b
    from public.accounts a left join public.journal_lines l on l.account_id = a.id
    where a.shop_id = s group by a.id, a.type
  ),
  eq_all as (
    select coalesce(sum(b) filter (where type = 'asset'), 0)::bigint as assets,
           coalesce(sum(b) filter (where type = 'liability'), 0)::bigint as liabilities,
           coalesce(sum(b) filter (where type = 'equity'), 0)::bigint as equity,
           (coalesce(sum(b) filter (where type = 'revenue'), 0) - coalesce(sum(b) filter (where type = 'expense'), 0))::bigint as earnings
    from bal_all
  ),
  acc as (select id, code, name, type, kind, method, sum(b)::bigint as b from bal group by id, code, name, type, kind, method),
  per as (
    select coalesce(sum(case when a.type = 'revenue' then l.credit - l.debit else 0 end), 0)::bigint as revenue,
           coalesce(sum(case when a.type = 'expense' then l.debit - l.credit else 0 end), 0)::bigint as expenses
    from public.journal_lines l join public.accounts a on a.id = l.account_id join public.journal_entries e on e.id = l.entry_id
    where l.shop_id = s and e.occurred_at >= p_from and e.occurred_at < p_to and (p_branch is null or e.branch_id = p_branch)
  ),
  tot as (
    select coalesce(sum(debit), 0)::bigint as d, coalesce(sum(credit), 0)::bigint as c from public.journal_lines where shop_id = s
  ),
  unb as (
    select count(*)::int as n from (
      select e.id from public.journal_entries e left join public.journal_lines l on l.entry_id = e.id
      where e.shop_id = s group by e.id having coalesce(sum(l.debit), 0) <> coalesce(sum(l.credit), 0) or count(l.id) < 2) x
  ),
  eq as (
    select coalesce(sum(b) filter (where type = 'asset'), 0)::bigint as assets,
           coalesce(sum(b) filter (where type = 'liability'), 0)::bigint as liabilities,
           coalesce(sum(b) filter (where type = 'equity'), 0)::bigint as equity,
           (coalesce(sum(b) filter (where type = 'revenue'), 0) - coalesce(sum(b) filter (where type = 'expense'), 0))::bigint as earnings
    from acc
  ),
  parts as (
    select
      coalesce(sum(b) filter (where kind = 'cash'), 0)::bigint as cash,
      coalesce(sum(greatest(b, 0)) filter (where kind in ('receivable', 'advances')), 0)::bigint as receivables,
      (coalesce(sum(greatest(b, 0)) filter (where kind in ('payable', 'salaries')), 0)
        + coalesce(sum(greatest(-b, 0)) filter (where kind in ('receivable', 'advances')), 0)
        + coalesce(sum(greatest(-b, 0)) filter (where kind = 'inventory'), 0))::bigint as payables,
      coalesce(sum(greatest(-b, 0)) filter (where kind in ('payable', 'salaries')), 0)::bigint as payables_debit,
      coalesce(sum(greatest(b, 0)) filter (where kind = 'inventory'), 0)::bigint as inventory,
      coalesce(sum(b) filter (where kind = 'fixed_asset'), 0)::bigint as fixed_assets,
      -- أرباح اتوزعت على الشركاء ولسه ما اتسحبتش (حقوق ملكية، مش دين من بره)
      coalesce(sum(greatest(b, 0)) filter (where kind = 'partner_current'), 0)::bigint as partners_due
    from bal
  ),
  days as (
    select (date_trunc('day', e.occurred_at at time zone 'Africa/Cairo'))::date as day,
           coalesce(sum(case when a.type = 'revenue' then l.credit - l.debit else 0 end), 0)::bigint as revenue,
           coalesce(sum(case when a.type = 'expense' then l.debit - l.credit else 0 end), 0)::bigint as expenses
    from public.journal_lines l join public.accounts a on a.id = l.account_id join public.journal_entries e on e.id = l.entry_id
    where l.shop_id = s and e.occurred_at >= p_from and e.occurred_at < p_to and a.type in ('revenue', 'expense') and (p_branch is null or e.branch_id = p_branch)
    group by 1
  )
  select jsonb_build_object(
    'cash', p.cash,
    'receivables', p.receivables + p.payables_debit,
    'payables', p.payables,
    -- مخزون فرع: قيمة حركاته (التحويل بين الفروع بيتقابل في حساب المخزون نفسه)
    'inventory', case when p_branch is null then p.inventory else (select coalesce(sum(m.value), 0)::bigint from public.stock_moves m where m.shop_id = s and m.branch_id = p_branch) end,
    'revenue', per.revenue,
    'expenses', per.expenses,
    'profit', per.revenue - per.expenses,
    'fixed_assets', p.fixed_assets,
    'partners_due', p.partners_due,
    -- قيمة المحل = الأصول − الالتزامات اللي لناس من بره بس (رأس مال الشركاء وأرباحهم حقوق ملكية، فما بتقللهاش)
    'net_worth', p.cash + p.receivables + p.payables_debit + p.fixed_assets - p.payables
      + case when p_branch is null then p.inventory else (select coalesce(sum(m.value), 0)::bigint from public.stock_moves m where m.shop_id = s and m.branch_id = p_branch) end,
    'branch', p_branch,
    -- حقوق الملكية بالتفصيل (من أول يوم): رأس مال صاحب المحل، والسحوبات، ورأس مال وجاري كل شريك، والأرباح المحتجزة
    'equity_parts', jsonb_build_object(
      'owner_capital', coalesce((select b from acc where code = 'capital'), 0),
      'drawings', -coalesce((select b from acc where code = 'drawings'), 0),
      'retained', eq.earnings + coalesce((select b from acc where code = 'retained'), 0),
      'partners', coalesce((select jsonb_agg(jsonb_build_object('id', pt.id, 'name', pt.name, 'share_bp', pt.share_bp,
          'capital', coalesce((select sum(b.b) from bal b where b.kind = 'partner_capital' and b.party_id = pt.id), 0),
          'current', coalesce((select sum(b.b) from bal b where b.kind = 'partner_current' and b.party_id = pt.id), 0)) order by pt.share_bp desc, pt.name)
        from public.partners pt where pt.shop_id = s and (pt.deleted_at is null or exists (select 1 from bal b where b.party_id = pt.id and b.b <> 0))), '[]'::jsonb)),
    'equation', jsonb_build_object('assets', eq_all.assets, 'liabilities', eq_all.liabilities, 'equity', eq_all.equity, 'earnings', eq_all.earnings),
    'debits', tot.d, 'credits', tot.c, 'unbalanced_entries', unb.n,
    'balanced', tot.d = tot.c and unb.n = 0 and eq_all.assets = eq_all.liabilities + eq_all.equity + eq_all.earnings,
    'cashboxes', coalesce((select jsonb_agg(jsonb_build_object('id', a.id, 'code', a.code, 'name', a.name, 'method', a.method, 'balance', a.b,
         'branch_id', (select x.branch_id from public.accounts x where x.id = a.id)) order by a.code nulls last, a.name)
       from acc a where a.kind = 'cash'), '[]'::jsonb),
    'top_customers', coalesce((select jsonb_agg(x order by (x ->> 'balance')::bigint desc) from (
       select jsonb_build_object('id', b.party_id, 'name', c.name, 'balance', sum(b.b)) as x
       from bal b join public.customers c on c.id = b.party_id where b.kind = 'receivable' and b.party_type = 'customer'
       group by b.party_id, c.name having sum(b.b) > 0 order by sum(b.b) desc limit 5) t), '[]'::jsonb),
    'top_suppliers', coalesce((select jsonb_agg(x order by (x ->> 'balance')::bigint desc) from (
       select jsonb_build_object('id', b.party_id, 'name', sp.name, 'balance', sum(b.b)) as x
       from bal b join public.suppliers sp on sp.id = b.party_id where b.kind = 'payable' and b.party_type = 'supplier'
       group by b.party_id, sp.name having sum(b.b) > 0 order by sum(b.b) desc limit 5) t), '[]'::jsonb),
    'daily', coalesce((select jsonb_agg(jsonb_build_object('day', day, 'revenue', revenue, 'expenses', expenses, 'profit', revenue - expenses) order by day) from days), '[]'::jsonb),
    'by_method', coalesce((select jsonb_object_agg(method, total) from (
       select p2.method, sum(p2.amount)::bigint as total from public.payments p2
       where p2.shop_id = s and p2.created_at >= p_from and p2.created_at < p_to
         and (p_branch is null or exists (select 1 from public.journal_entries pe where pe.id = p2.entry_id and pe.branch_id = p_branch))
         and not exists (select 1 from public.journal_entries r where r.reverses_id = p2.entry_id)
       group by p2.method) m), '{}'::jsonb),
    'delivered', (select count(*) from public.devices d where d.shop_id = s and d.delivered_at >= p_from and d.delivered_at < p_to and (p_branch is null or d.branch_id = p_branch)),
    'closings', coalesce((select jsonb_agg(jsonb_build_object('cashbox', dc.cashbox_id, 'expected', dc.expected, 'counted', dc.counted, 'diff', dc.diff, 'at', dc.created_at,
       'by', (select full_name from public.profiles where id = dc.closed_by)) order by dc.created_at)
       from public.drawer_closings dc where dc.shop_id = s and dc.created_at >= p_from and dc.created_at < p_to
         and (p_branch is null or exists (select 1 from public.accounts ca where ca.id = dc.cashbox_id and ca.branch_id = p_branch))), '[]'::jsonb)
  ) into res
  from parts p, per, tot, unb, eq, eq_all;
  return res;
end $$;
revoke execute on function public.financial_position(timestamptz, timestamptz, uuid) from public, anon;
grant execute on function public.financial_position(timestamptz, timestamptz, uuid) to authenticated;

-- ---------- الشركاء: على المحل كله أو على فرع ----------
-- شريك على فرع: نصيبه من ربح الفرع ده بس. ومجموع النسب في أي فرع (شركاء المحل كله + شركاء الفرع) مايعديش 100%
alter table public.partners add column branch_id uuid references public.branches(id);

create or replace function public.branch_profit(p_shop uuid, p_branch uuid, p_from timestamptz, p_to timestamptz) returns bigint
language sql stable security definer set search_path = public as $$
  select coalesce(sum(l.credit - l.debit), 0)::bigint
  from public.journal_lines l join public.accounts a on a.id = l.account_id join public.journal_entries e on e.id = l.entry_id
  where e.shop_id = p_shop and e.branch_id = p_branch and a.type in ('revenue', 'expense') and e.occurred_at >= p_from and e.occurred_at < p_to
$$;
revoke execute on function public.branch_profit(uuid, uuid, timestamptz, timestamptz) from public, anon, authenticated;

create or replace function public.tg_partners_share() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  perform pg_advisory_xact_lock(hashtext('partners:' || new.shop_id::text));
  -- الشريك اللي ليه أو عليه فلوس ما بيتحذفش (سوّي حسابه الأول)
  if tg_op = 'UPDATE' and old.deleted_at is null and new.deleted_at is not null
     and exists (select 1 from public.journal_lines l where l.party_type = 'partner' and l.party_id = new.id group by l.party_id having sum(l.credit - l.debit) <> 0) then
    raise exception 'E_HAS_BALANCE';
  end if;
  if new.branch_id is not null and not exists (select 1 from public.branches b where b.id = new.branch_id and b.shop_id = new.shop_id) then
    raise exception 'E_BAD_BRANCH';
  end if;
  -- المحل كله
  if (select coalesce(sum(share_bp), 0) from public.partners where shop_id = new.shop_id and deleted_at is null and branch_id is null) > 10000 then
    raise exception 'E_SHARE_OVER_100';
  end if;
  -- كل فرع: شركاء المحل كله + شركاء الفرع
  if exists (
    select 1 from public.branches b
    where b.shop_id = new.shop_id and b.deleted_at is null
      and (select coalesce(sum(p.share_bp), 0) from public.partners p where p.shop_id = new.shop_id and p.deleted_at is null and (p.branch_id is null or p.branch_id = b.id)) > 10000) then
    raise exception 'E_SHARE_OVER_100';
  end if;
  return null;
end $$;

-- التوزيع: شريك المحل كله من ربح المحل، وشريك الفرع من ربح فرعه
create or replace function public.profit_split(p_from timestamptz, p_to timestamptz) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare s uuid := public.current_shop_id(); pr bigint;
begin
  perform public.ledger_require(array['owner']::public.app_role[]);
  if p_to <= p_from then raise exception 'E_BAD_INPUT'; end if;
  pr := public.period_profit(s, p_from, p_to);
  return jsonb_build_object(
    'profit', pr,
    'overlap', exists (select 1 from public.profit_distributions d where d.shop_id = s and d.period_from < p_to and d.period_to > p_from
                        and not exists (select 1 from public.journal_entries r where r.reverses_id = d.entry_id)),
    'shares', coalesce((select jsonb_agg(jsonb_build_object('partner', p.id, 'name', p.name, 'share_bp', p.share_bp, 'branch_id', p.branch_id,
                 'base', case when p.branch_id is null then pr else public.branch_profit(s, p.branch_id, p_from, p_to) end,
                 'amount', ((case when p.branch_id is null then pr else public.branch_profit(s, p.branch_id, p_from, p_to) end) * p.share_bp / 10000)::bigint)
                 order by p.share_bp desc, p.name)
               from public.partners p where p.shop_id = s and p.deleted_at is null and p.joined_on <= ((p_to - interval '1 microsecond') at time zone 'Africa/Cairo')::date), '[]'::jsonb));
end $$;

drop function if exists public.partner_balances();
create or replace function public.partner_balances() returns table(id uuid, name text, phone text, share_bp integer, joined_on date, capital bigint, current bigint, total bigint, branch_id uuid)
language plpgsql stable security definer set search_path = public as $$
begin
  perform public.ledger_require(array['owner']::public.app_role[]);
  return query
  select p.id, p.name, p.phone, p.share_bp, p.joined_on,
         coalesce(sum(l.credit - l.debit) filter (where a.kind = 'partner_capital'), 0)::bigint,
         coalesce(sum(l.credit - l.debit) filter (where a.kind = 'partner_current'), 0)::bigint,
         coalesce(sum(l.credit - l.debit), 0)::bigint,
         p.branch_id
  from public.partners p
  left join public.journal_lines l on l.party_type = 'partner' and l.party_id = p.id
  left join public.accounts a on a.id = l.account_id
  where p.shop_id = public.current_shop_id() and p.deleted_at is null
  group by p.id
  order by p.share_bp desc, p.name;
end $$;
revoke execute on function public.partner_balances() from public, anon;
grant execute on function public.partner_balances() to authenticated;

-- ---------- فلتر الفرع في التقارير (null = كل الفروع) ----------
-- pl_breakdown: (src: 0011_finance_drilldown.sql)
drop function if exists public.pl_breakdown(timestamptz, timestamptz);
create or replace function public.pl_breakdown(p_from timestamptz, p_to timestamptz, p_branch uuid default null)
returns table(account_id uuid, code text, name text, type public.account_type, amount bigint)
language plpgsql stable security definer set search_path = public as $$
begin
  perform public.ledger_require(array['owner']::public.app_role[]);
  return query
  select a.id, a.code, a.name, a.type,
         sum(case when a.type = 'revenue' then l.credit - l.debit else l.debit - l.credit end)::bigint
  from public.journal_lines l
  join public.accounts a on a.id = l.account_id
  join public.journal_entries e on e.id = l.entry_id
  where l.shop_id = public.current_shop_id() and a.type in ('revenue', 'expense') and e.occurred_at >= p_from and e.occurred_at < p_to
    and (p_branch is null or e.branch_id = p_branch)
  group by a.id
  having sum(l.debit - l.credit) <> 0
  order by a.type desc, 5 desc;
end $$;
revoke execute on function public.pl_breakdown(timestamptz, timestamptz, uuid) from public, anon;
grant execute on function public.pl_breakdown(timestamptz, timestamptz, uuid) to authenticated;
-- issue_report: (src: 0014_technicians.sql)
drop function if exists public.issue_report(timestamptz, timestamptz);
create or replace function public.issue_report(p_from timestamptz, p_to timestamptz, p_branch uuid default null)
returns table(route_id uuid, code text, name text, devices integer, revenue bigint, parts bigint, profit bigint)
language plpgsql stable security definer set search_path = public as $$
#variable_conflict use_column
begin
  perform public.ledger_require(array['owner']::public.app_role[]);
  return query
  select r.id, r.code, r.name, count(d.id)::int,
         coalesce(sum(dc.final_cost), 0)::bigint,
         coalesce(sum((select -sum(m.value) from public.stock_moves m join public.journal_entries e on e.id = m.entry_id where e.device_id = d.id and e.source_type in ('part_use', 'reversal'))), 0)::bigint,
         (coalesce(sum(dc.final_cost), 0) - coalesce(sum((select -sum(m.value) from public.stock_moves m join public.journal_entries e on e.id = m.entry_id where e.device_id = d.id and e.source_type in ('part_use', 'reversal'))), 0))::bigint
  from public.devices d
  left join public.routes r on r.id = d.route_id
  left join public.device_costs dc on dc.device_id = d.id and dc.deleted_at is null
  where d.shop_id = public.current_shop_id() and d.status = 'delivered' and d.delivered_at >= p_from and d.delivered_at < p_to and (p_branch is null or d.branch_id = p_branch)
  group by r.id, r.code, r.name
  order by 7 desc;
end $$;
revoke execute on function public.issue_report(timestamptz, timestamptz, uuid) from public, anon;
grant execute on function public.issue_report(timestamptz, timestamptz, uuid) to authenticated;
-- models_report: (src: 0014_technicians.sql)
drop function if exists public.models_report(timestamptz, timestamptz);
create or replace function public.models_report(p_from timestamptz, p_to timestamptz, p_branch uuid default null)
returns table(kind text, label text, devices integer)
language plpgsql stable security definer set search_path = public as $$
#variable_conflict use_column
begin
  perform public.ledger_require(array['owner', 'reception']::public.app_role[]);
  return query
  (select 'model'::text, d.brand || ' ' || d.model, count(*)::int from public.devices d
    where d.shop_id = public.current_shop_id() and d.received_at >= p_from and d.received_at < p_to and d.deleted_at is null and (p_branch is null or d.branch_id = p_branch)
    group by d.brand, d.model order by 3 desc limit 10)
  union all
  (select 'route'::text, coalesce(r.code, r.name, '-'), count(*)::int from public.devices d left join public.routes r on r.id = d.route_id
    where d.shop_id = public.current_shop_id() and d.received_at >= p_from and d.received_at < p_to and d.deleted_at is null and (p_branch is null or d.branch_id = p_branch)
    group by r.code, r.name order by 3 desc limit 10);
end $$;
revoke execute on function public.models_report(timestamptz, timestamptz, uuid) from public, anon;
grant execute on function public.models_report(timestamptz, timestamptz, uuid) to authenticated;
-- inventory_summary: (src: 0027_inventory.sql)
drop function if exists public.inventory_summary(timestamptz, timestamptz);
create or replace function public.inventory_summary(p_from timestamptz, p_to timestamptz, p_branch uuid default null) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare s uuid := public.current_shop_id(); res jsonb;
begin
  perform public.ledger_require(array['owner']::public.app_role[]);
  with en as (
    select e.id, coalesce(o.source_type, e.source_type) t
    from public.journal_entries e left join public.journal_entries o on o.id = e.reverses_id
    where e.shop_id = s and e.occurred_at >= p_from and e.occurred_at < p_to and (p_branch is null or e.branch_id = p_branch)
  ), ln as (
    select en.t, a.code, sum(l.credit - l.debit) cr from en join public.journal_lines l on l.entry_id = en.id join public.accounts a on a.id = l.account_id
    group by en.t, a.code
  )
  select jsonb_build_object(
    'sales', coalesce((select sum(cr) from ln where t in ('sale', 'sale_return') and code in ('rev_parts', 'rev_accessories')), 0),
    'sales_cost', coalesce((select -sum(cr) from ln where t in ('sale', 'sale_return') and code = 'cogs'), 0),
    'wastage', coalesce((select -sum(cr) from ln where code = 'wastage'), 0),
    'return_diff', coalesce((select -sum(cr) from ln where t = 'supplier_return' and code = 'cogs'), 0),
    'cost_adjust', coalesce((select -sum(cr) from ln where t = 'cost_adjust' and code = 'cogs'), 0),
    'parts_used', coalesce((select -sum(cr) from ln where t = 'part_use' and code = 'cogs'), 0),
    'purchases', coalesce((select -sum(cr) from ln where t = 'purchase' and code = 'inventory'), 0),
    'stock_value', (select coalesce(sum(value), 0) from public.stock_moves where shop_id = s and (p_branch is null or branch_id = p_branch)),
    'stock_qty', (select coalesce(sum(qty), 0) from public.stock_moves where shop_id = s and (p_branch is null or branch_id = p_branch)),
    'top', coalesce((select jsonb_agg(x order by x.qty desc) from (
        select i.id, i.name, -sum(m.qty)::bigint qty, -sum(m.value)::bigint cost
        from public.stock_moves m join en on en.id = m.entry_id join public.items i on i.id = m.item_id
        where en.t = 'sale' group by i.id, i.name order by -sum(m.qty) desc limit 10) x), '[]'::jsonb)
  ) into res;
  res := res || jsonb_build_object('profit', (res->>'sales')::bigint - (res->>'sales_cost')::bigint - (res->>'wastage')::bigint - (res->>'return_diff')::bigint - (res->>'cost_adjust')::bigint);
  return res;
end $$;
revoke execute on function public.inventory_summary(timestamptz, timestamptz, uuid) from public, anon;
grant execute on function public.inventory_summary(timestamptz, timestamptz, uuid) to authenticated;

-- ============================== 0035_lists_everywhere.sql ==============================
-- ============================================================
-- 0035: قوائم الملء السريع في البرنامج كله (طلب صاحب المشروع 2026-11-10)
-- - قوايم جديدة: أنواع الأجهزة، والأعطال (زراير "+ عطل" في الاستلام)، وقطع الغيار، وأسباب المرتجع (جنب الماركات والموديلات والملحقات
--   والألوان والحالة الشكلية وتصنيفات الأصناف وأسباب الهالك والحالات الفرعية).
-- - الأعطال الجاهزة بالسعر (issue_presets) بقت بنفس الصلاحية.
-- - الإضافة والحذف من أي مكان بيستخدم القايمة، لكل الموظفين في المحل (القايمة واحدة للمحل).
-- - مين يضيف ويحذف: صاحب المحل دايمًا، والأدوار اللي يختارها في shops.extras.lists_edit (مثلًا ["reception"]).
-- - الحذف ناعم وبيخفي البند من الاختيار بس: البيانات القديمة متخزنة بالقيمة (نص)، فما بتتغيرش.
-- - كل إضافة وحذف بيتسجلوا في سجل النشاط (zz_audit على shop_lists من 0032).
-- - الصنف في المخزون ليه ماركة (اختياري) من نفس قايمة الماركات.
-- ============================================================

alter table public.shop_lists drop constraint if exists shop_lists_list_check;
alter table public.shop_lists add constraint shop_lists_list_check check (list in (
  'brands', 'models', 'accessories', 'colors', 'conditions', 'item_categories', 'write_off_reasons', 'sub_statuses',
  'device_types', 'issues', 'parts', 'return_reasons'));

-- مين يقدر يضيف أو يحذف من القوايم
create or replace function public.can_edit_lists() returns boolean
language sql stable security definer set search_path = public as $$
  select coalesce(public.current_app_role() = 'owner'
    or exists (select 1 from public.shops s where s.id = public.current_shop_id()
               and coalesce(s.extras -> 'lists_edit', '[]'::jsonb) ? public.current_app_role()::text), false)
$$;
revoke execute on function public.can_edit_lists() from public, anon;
grant execute on function public.can_edit_lists() to authenticated;

drop policy if exists lists_insert on public.shop_lists;
drop policy if exists lists_update on public.shop_lists;
create policy lists_insert on public.shop_lists for insert to authenticated
  with check (shop_id = public.current_shop_id() and public.can_edit_lists());
create policy lists_update on public.shop_lists for update to authenticated
  using (shop_id = public.current_shop_id() and public.can_edit_lists())
  with check (shop_id = public.current_shop_id());

-- الحذف من القايمة بس (deleted_at)، مش تعديل القيمة: عشان البيانات القديمة اللي اتسجلت بالقيمة تفضل مفهومة
create or replace function public.tg_list_value_fixed() returns trigger
language plpgsql as $$
begin
  if (new.value is distinct from old.value or new.list is distinct from old.list or new.parent is distinct from old.parent) and not public.restoring() then
    raise exception 'E_LIST_VALUE_FIXED';
  end if;
  return new;
end $$;
drop trigger if exists b_list_value_fixed on public.shop_lists;
create trigger b_list_value_fixed before update on public.shop_lists for each row execute function public.tg_list_value_fixed();

-- الأعطال الجاهزة: نفس صلاحية القوايم
drop policy if exists presets_insert on public.issue_presets;
drop policy if exists presets_update on public.issue_presets;
create policy presets_insert on public.issue_presets for insert to authenticated
  with check (shop_id = public.current_shop_id() and public.can_edit_lists());
create policy presets_update on public.issue_presets for update to authenticated
  using (shop_id = public.current_shop_id() and public.can_edit_lists())
  with check (shop_id = public.current_shop_id());

-- نوع الجهاز (اختياري، من قايمة أنواع الأجهزة)
alter table public.devices add column if not exists device_type text check (device_type is null or length(trim(device_type)) between 1 and 60);

-- ماركة الصنف (اختياري)
alter table public.items add column if not exists brand text check (brand is null or length(trim(brand)) between 1 and 60);
create index if not exists items_brand on public.items(shop_id, brand) where deleted_at is null and brand is not null;

-- المخزون بماركة الصنف (نفس 0034 + عمود brand)
drop function if exists public.items_stock(boolean);
create or replace function public.items_stock(p_all boolean default false) returns table(id uuid, kind text, name text, sku text, sale_price integer, qty bigint, avg_cost bigint, value bigint, min_qty integer, supplier_id uuid, short boolean, category text, barcode text, image_path text, brand text)
language plpgsql stable security definer set search_path = public as $$
declare r public.app_role := public.current_app_role(); b uuid := public.op_branch(); everywhere boolean;
begin
  if r is null then raise exception 'E_FORBIDDEN'; end if;
  everywhere := p_all and r = 'owner';
  return query
  select i.id, i.kind, i.name, i.sku,
         case when r = 'technician' then null else i.sale_price end,
         coalesce(st.q, 0)::bigint,
         case when r = 'owner' and coalesce(st.q, 0) > 0 then (st.v / st.q)::bigint end,
         case when r = 'owner' then coalesce(st.v, 0)::bigint end,
         i.min_qty, case when r = 'owner' then i.supplier_id end,
         i.min_qty > 0 and coalesce(st.q, 0) <= i.min_qty,
         i.category, i.barcode, i.image_path, i.brand
  from public.items i
  left join (select m.item_id, sum(m.qty) as q, sum(m.value) as v from public.stock_moves m where everywhere or m.branch_id = b group by m.item_id) st on st.item_id = i.id
  where i.shop_id = public.current_shop_id() and i.deleted_at is null
  order by i.kind, i.name;
end $$;
revoke execute on function public.items_stock(boolean) from public, anon;
grant execute on function public.items_stock(boolean) to authenticated;

-- ---------- بنود المصروفات من نافذة المصروف نفسها (بنفس صلاحية القوايم) ----------
-- بند المصروف حساب في الدفتر: الإضافة حساب جديد، و"الحذف" بيقفله بس (قيوده القديمة زي ما هي)
create or replace function public.add_expense_type(p_id uuid, p_name text) returns uuid
language plpgsql security definer set search_path = public as $$
declare s uuid := public.current_shop_id(); nm text := trim(coalesce(p_name, ''));
begin
  if s is null or not public.can_edit_lists() then raise exception 'E_FORBIDDEN'; end if;
  if nm = '' or length(nm) > 80 then raise exception 'E_BAD_INPUT'; end if;
  if exists (select 1 from public.accounts where id = p_id) then return p_id; end if;
  insert into public.accounts(id, shop_id, name, type, kind) values (p_id, s, nm, 'expense', 'expense');
  return p_id;
end $$;

create or replace function public.hide_expense_type(p_id uuid) returns void
language plpgsql security definer set search_path = public as $$
declare s uuid := public.current_shop_id();
begin
  if s is null or not public.can_edit_lists() then raise exception 'E_FORBIDDEN'; end if;
  update public.accounts set active = false where id = p_id and shop_id = s and kind = 'expense' and deleted_at is null;
  if not found then raise exception 'E_NOT_FOUND'; end if;
end $$;
revoke execute on function public.add_expense_type(uuid, text), public.hide_expense_type(uuid) from public, anon;
grant execute on function public.add_expense_type(uuid, text), public.hide_expense_type(uuid) to authenticated;

-- ============================== 0036_roles.sql ==============================
-- =====================================================================
-- P (المرحلة الأولى): الأدوار والصلاحيات التفصيلية، ونوع الفرع
-- قرار صاحب المشروع: مرحلتين. المرحلة دي: جدول الصلاحيات، والأدوار الجاهزة، و"شيل" أي صلاحية،
-- ونوع الفرع. فتح صلاحيات الموظف ما عندوش النهارده (زي الأرباح) في المرحلة التانية.
--
-- - الأدوار بأسماء من صاحب المحل. كل دور: جدول (الأقسام × يشوف/يضيف/يعدّل/يحذف/يشوف المبالغ/يطبع ويصدّر).
-- - كل موظف: دور أو أكتر (staff_roles)، وفرع أو أكتر (staff_branches من B)، واستثناءات ليه هو (staff_overrides).
-- - الحماية في قاعدة البيانات: سياسات RLS "مقيّدة" (as restrictive) فوق الموجودة، فبتشيل بس ومش بتفتح حاجة،
--   والدوال اللي بتكتب (البيع، والدفعة، والمصروف، والقطع) بتتأكد من الصلاحية.
-- - صاحب المحل عنده كل الصلاحيات دايمًا (من غير أدوار)، وما ينفعش يتشال. وكل تغيير في سجل النشاط.
-- - نقل الأدوار القديمة: الاستقبال ← دور "استقبال"، والفني ← دور "فني"، بنفس اللي كانوا بيعملوه بالظبط.
-- =====================================================================

-- ---------- الأقسام والعمليات ----------
create or replace function public.perm_sections() returns text[]
language sql immutable as $$
  select array['devices', 'intake', 'customers', 'technicians', 'inventory', 'sales', 'purchases', 'cashbox', 'expenses', 'finance', 'partners', 'reports', 'staff', 'settings', 'audit']
$$;
create or replace function public.perm_ops() returns text[]
language sql immutable as $$
  select array['view', 'add', 'edit', 'delete', 'amounts', 'export']
$$;

-- صلاحيات صالحة: {"devices": ["view", "add"], ...} من الأقسام والعمليات دي بس
create or replace function public.perms_valid(p jsonb) returns boolean
language sql immutable as $$
  select jsonb_typeof(p) = 'object' and not exists (
    select 1 from jsonb_each(p) e
    where not (e.key = any (public.perm_sections())) or jsonb_typeof(e.value) <> 'array'
       or exists (select 1 from jsonb_array_elements_text(e.value) o where not (o = any (public.perm_ops()))))
$$;

revoke execute on function public.perm_sections(), public.perm_ops(), public.perms_valid(jsonb) from public, anon;
grant execute on function public.perm_sections(), public.perm_ops(), public.perms_valid(jsonb) to authenticated;

-- ---------- الجداول ----------
create table public.roles (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references public.shops(id),
  name text not null check (length(trim(name)) between 1 and 60),
  -- الأدوار الجاهزة (صاحب المحل يقدر يعدّلها). base = الدور الأساسي في البرنامج اللي الدور ده بيتبني عليه
  preset text check (preset is null or preset in ('branch_manager', 'reception', 'technician', 'cashier', 'accountant')),
  base public.app_role not null default 'reception' check (base in ('reception', 'technician')),
  perms jsonb not null default '{}'::jsonb check (public.perms_valid(perms)),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);
create unique index roles_name_uq on public.roles(shop_id, lower(trim(name))) where deleted_at is null;
create unique index roles_preset_uq on public.roles(shop_id, preset) where deleted_at is null and preset is not null;

create table public.staff_roles (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references public.shops(id),
  profile_id uuid not null references public.profiles(id),
  role_id uuid not null references public.roles(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);
create unique index staff_roles_uq on public.staff_roles(profile_id, role_id) where deleted_at is null;

-- استثناء لموظف معيّن بعيد عن دوره (يسمح أو يمنع)، وبيظهر في الشاشة إنه استثناء
create table public.staff_overrides (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references public.shops(id),
  profile_id uuid not null references public.profiles(id),
  section text not null check (section = any (public.perm_sections())),
  op text not null check (op = any (public.perm_ops())),
  allow boolean not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);
create unique index staff_overrides_uq on public.staff_overrides(profile_id, section, op) where deleted_at is null;

alter table public.staff_invites add column role_ids uuid[] not null default '{}';

-- نوع الفرع: صيانة بس، أو مبيعات بس، أو الاتنين. تغييره ما بيمسحش أي بيانات
alter table public.branches add column kind text not null default 'both' check (kind in ('repair', 'sales', 'both'));

do $$
declare t text;
begin
  foreach t in array array['roles', 'staff_roles', 'staff_overrides'] loop
    execute format('alter table public.%I enable row level security', t);
    execute format('create trigger set_updated_at before update on public.%I for each row execute function public.tg_set_updated_at()', t);
    execute format('create trigger block_delete before delete on public.%I for each row execute function public.tg_block_delete()', t);
    execute format('create trigger zz_audit after insert or update on public.%I for each row execute function public.tg_audit()', t);
  end loop;
end $$;

-- ---------- الأدوار الجاهزة ----------
-- نفس اللي الدور الأساسي كان بيعمله قبل كده بالظبط (من غير ما حد يكسب أو يخسر صلاحية)
create or replace function public.preset_perms(p text) returns jsonb
language sql immutable as $$
  select case p
    when 'reception' then '{"devices":["view","add","edit","amounts","export"],"intake":["view","add"],"customers":["view","add","edit","export"],"technicians":["view"],"inventory":["view","add","edit","export"],"sales":["view","add","edit","export"],"cashbox":["view","add"],"expenses":["view","add"]}'::jsonb
    when 'branch_manager' then '{"devices":["view","add","edit","amounts","export"],"intake":["view","add"],"customers":["view","add","edit","export"],"technicians":["view"],"inventory":["view","add","edit","export"],"sales":["view","add","edit","export"],"cashbox":["view","add"],"expenses":["view","add"]}'::jsonb
    when 'technician' then '{"devices":["view","edit"],"technicians":["view"],"inventory":["view"]}'::jsonb
    when 'cashier' then '{"customers":["view","add"],"inventory":["view","export"],"sales":["view","add","edit","export"],"cashbox":["view","add"]}'::jsonb
    when 'accountant' then '{"cashbox":["view"],"expenses":["view","add"],"inventory":["view","export"],"sales":["view","export"],"customers":["view"]}'::jsonb
    else '{}'::jsonb end
$$;
create or replace function public.preset_name(p text) returns text
language sql immutable as $$
  select case p when 'branch_manager' then 'مدير فرع' when 'reception' then 'استقبال' when 'technician' then 'فني'
                when 'cashier' then 'كاشير مبيعات' when 'accountant' then 'محاسب' end
$$;

revoke execute on function public.preset_perms(text), public.preset_name(text) from public, anon;
grant execute on function public.preset_perms(text), public.preset_name(text) to authenticated;

create or replace function public.ensure_role_presets(p_shop uuid) returns void
language plpgsql security definer set search_path = public as $$
declare p text;
begin
  foreach p in array array['branch_manager', 'reception', 'technician', 'cashier', 'accountant'] loop
    insert into public.roles(shop_id, name, preset, base, perms)
    select p_shop, public.preset_name(p), p, (case when p = 'technician' then 'technician' else 'reception' end)::public.app_role, public.preset_perms(p)
    where not exists (select 1 from public.roles r where r.shop_id = p_shop and r.preset = p and r.deleted_at is null);
  end loop;
end $$;
revoke execute on function public.ensure_role_presets(uuid) from public, anon, authenticated;

select public.ensure_role_presets(id) from public.shops;
create or replace function public.tg_shop_roles() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  perform public.ensure_role_presets(new.id);
  return null;
end $$;
create trigger zz_shop_roles after insert on public.shops for each row execute function public.tg_shop_roles();

-- النقل: كل موظف حالي (استقبال أو فني) ← الدور الجاهز بتاع دوره
insert into public.staff_roles(shop_id, profile_id, role_id)
select p.shop_id, p.id, r.id from public.profiles p
join public.roles r on r.shop_id = p.shop_id and r.preset = p.role::text and r.deleted_at is null
where p.role in ('reception', 'technician')
  and not exists (select 1 from public.staff_roles sr where sr.profile_id = p.id and sr.deleted_at is null);

-- ---------- التحقق ----------
-- صلاحيات المستخدم الحالي الفعلية {"devices": [...], ...}: أدواره + الاستثناءات. صاحب المحل: كله
create or replace function public.my_perms() returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare r public.app_role := public.current_app_role(); uid uuid := auth.uid(); res jsonb := '{}'::jsonb; sec text; ops text[];
begin
  if r is null then return '{}'::jsonb; end if;
  if r = 'owner' then
    select jsonb_object_agg(s, to_jsonb(public.perm_ops())) into res from unnest(public.perm_sections()) s;
    return res;
  end if;
  foreach sec in array public.perm_sections() loop
    ops := array(
      select o from unnest(public.perm_ops()) o
      where coalesce(
        (select ov.allow from public.staff_overrides ov where ov.profile_id = uid and ov.section = sec and ov.op = o and ov.deleted_at is null),
        exists (select 1 from public.staff_roles sr join public.roles ro on ro.id = sr.role_id and ro.deleted_at is null
                where sr.profile_id = uid and sr.deleted_at is null and coalesce(ro.perms -> sec, '[]'::jsonb) ? o)
        -- موظف من غير أدوار (مفروض ما يحصلش بعد النقل): صلاحيات دوره الأساسي الجاهزة
        or (not exists (select 1 from public.staff_roles sr where sr.profile_id = uid and sr.deleted_at is null)
            and coalesce(public.preset_perms(r::text) -> sec, '[]'::jsonb) ? o)));
    if array_length(ops, 1) > 0 then res := res || jsonb_build_object(sec, to_jsonb(ops)); end if;
  end loop;
  return res;
end $$;

create or replace function public.has_perm(p_section text, p_op text) returns boolean
language sql stable security definer set search_path = public as $$
  select public.current_app_role() = 'owner' or coalesce(public.my_perms() -> p_section, '[]'::jsonb) ? p_op
$$;

-- نوع فرع العملية: صيانة بس ← ما فيش مبيعات، ومبيعات بس ← ما فيش استلام أجهزة
create or replace function public.branch_allows(p_branch uuid, p_section text) returns boolean
language sql stable security definer set search_path = public as $$
  select coalesce((select case b.kind when 'repair' then p_section <> 'sales' when 'sales' then p_section not in ('devices', 'intake', 'technicians') else true end
                   from public.branches b where b.id = p_branch), true)
$$;

revoke execute on function public.my_perms(), public.has_perm(text, text), public.branch_allows(uuid, text) from public, anon;
grant execute on function public.my_perms(), public.has_perm(text, text), public.branch_allows(uuid, text) to authenticated;

-- الحذف والتصحيح: صلاحية "يحذف" في أي قسم من الجدول (جنب الإذن القديم can_correct من البند 2)
create or replace function public.can_correct() returns boolean
language sql stable security definer set search_path = public as $$
  select public.current_app_role() = 'owner'
      or coalesce((select p.can_correct from public.profiles p where p.id = auth.uid() and p.deleted_at is null), false)
      or exists (select 1 from jsonb_each(public.my_perms()) e where e.value ? 'delete')
$$;

-- ---------- RLS: سياسات مقيّدة فوق الموجودة (بتشيل بس) ----------
-- (select ...) = بتتحسب مرة واحدة للطلب، مش لكل صف
create policy perm_devices_select on public.devices as restrictive for select to authenticated using ((select public.has_perm('devices', 'view')));
create policy perm_devices_insert on public.devices as restrictive for insert to authenticated
  with check ((select public.has_perm('intake', 'add')) and public.branch_allows(branch_id, 'intake'));
create policy perm_devices_update on public.devices as restrictive for update to authenticated using ((select public.has_perm('devices', 'edit')));

create policy perm_customers_select on public.customers as restrictive for select to authenticated
  using ((select public.has_perm('customers', 'view')) or (select public.has_perm('intake', 'add')));
create policy perm_customers_insert on public.customers as restrictive for insert to authenticated
  with check ((select public.has_perm('customers', 'add')) or (select public.has_perm('intake', 'add')));
create policy perm_customers_update on public.customers as restrictive for update to authenticated using ((select public.has_perm('customers', 'edit')));

-- مبالغ الجهاز (التكلفة): "يشوف المبالغ" في الأجهزة
create policy perm_costs_select on public.device_costs as restrictive for select to authenticated using ((select public.has_perm('devices', 'amounts')));
create policy perm_costs_insert on public.device_costs as restrictive for insert to authenticated with check ((select public.has_perm('devices', 'amounts')) or (select public.has_perm('intake', 'add')));
create policy perm_costs_update on public.device_costs as restrictive for update to authenticated using ((select public.has_perm('devices', 'amounts')));

-- تفاصيل الأجهزة (الملاحظات والصور والسجل والفحص): بتاعة اللي بيشوف الأجهزة بس
do $$
declare t text;
begin
  foreach t in array array['device_notes', 'device_photos', 'status_log', 'device_checks', 'quote_decisions'] loop
    if to_regclass('public.' || t) is not null then
      execute format('create policy perm_%1$s_select on public.%1$I as restrictive for select to authenticated using ((select public.has_perm(''devices'', ''view'')))', t);
    end if;
  end loop;
end $$;

-- الفنيين: خطوات الصيانة والتخصصات، وبيانات الفنيين نفسهم (كاشير المبيعات ما يشوفهمش ولا من الـ API)
create policy perm_steps_select on public.repair_steps as restrictive for select to authenticated
  using ((select public.has_perm('technicians', 'view')) or technician_id = auth.uid());
create policy perm_staff_spec_select on public.staff_specialties as restrictive for select to authenticated
  using ((select public.has_perm('technicians', 'view')) or profile_id = auth.uid());
create policy perm_profiles_select on public.profiles as restrictive for select to authenticated
  using (id = auth.uid() or role <> 'technician' or (select public.has_perm('technicians', 'view')) or (select public.has_perm('staff', 'view')));

-- المخزون
create policy perm_items_select on public.items as restrictive for select to authenticated
  using ((select public.has_perm('inventory', 'view')) or (select public.has_perm('sales', 'view')));
create policy perm_items_insert on public.items as restrictive for insert to authenticated with check ((select public.has_perm('inventory', 'add')));
create policy perm_items_update on public.items as restrictive for update to authenticated using ((select public.has_perm('inventory', 'edit')));

-- الخزن: اللي بيشوف الخزن أو بيبيع (بيختار الخزنة)
create policy perm_accounts_select on public.accounts as restrictive for select to authenticated
  using (kind <> 'cash' or (select public.has_perm('cashbox', 'view')) or (select public.has_perm('sales', 'add')));

-- الأدوار نفسها: صاحب المحل بيعدّل، وكل موظف بيشوف أدواره واستثناءاته
create policy roles_select on public.roles for select to authenticated using (shop_id = public.current_shop_id());
create policy staff_roles_select on public.staff_roles for select to authenticated
  using (shop_id = public.current_shop_id() and (public.current_app_role() = 'owner' or profile_id = auth.uid()));
create policy staff_overrides_select on public.staff_overrides for select to authenticated
  using (shop_id = public.current_shop_id() and (public.current_app_role() = 'owner' or profile_id = auth.uid()));
grant select on public.roles, public.staff_roles, public.staff_overrides to authenticated;

-- ---------- إدارة الأدوار (صاحب المحل بس، وكله في سجل النشاط) ----------
create or replace function public.save_role(p_id uuid, p_name text, p_base public.app_role, p_perms jsonb) returns uuid
language plpgsql security definer set search_path = public as $$
declare s uuid := public.current_shop_id(); r public.roles; nm text := trim(coalesce(p_name, ''));
begin
  perform public.ledger_require(array['owner']::public.app_role[]);
  if nm = '' or length(nm) > 60 or p_base not in ('reception', 'technician') or not public.perms_valid(coalesce(p_perms, '{}'::jsonb)) then raise exception 'E_BAD_INPUT'; end if;
  if exists (select 1 from public.roles x where x.shop_id = s and x.deleted_at is null and x.id <> p_id and lower(trim(x.name)) = lower(nm)) then raise exception 'E_DUP_NAME'; end if;
  select * into r from public.roles where id = p_id and shop_id = s for update;
  if found then
    if r.deleted_at is not null then raise exception 'E_NOT_FOUND'; end if;
    update public.roles set name = nm, base = p_base, perms = p_perms where id = p_id;
    -- الموظفين اللي عندهم الدور ده: دورهم الأساسي بيتحدّث على طول (من غير خروج ودخول)
    perform public.sync_base_role(sr.profile_id) from public.staff_roles sr where sr.role_id = p_id and sr.deleted_at is null;
  else
    insert into public.roles(id, shop_id, name, base, perms) values (p_id, s, nm, p_base, coalesce(p_perms, '{}'::jsonb));
  end if;
  return p_id;
end $$;

create or replace function public.archive_role(p_id uuid) returns void
language plpgsql security definer set search_path = public as $$
declare s uuid := public.current_shop_id();
begin
  perform public.ledger_require(array['owner']::public.app_role[]);
  if exists (select 1 from public.staff_roles sr join public.profiles p on p.id = sr.profile_id and p.deleted_at is null where sr.role_id = p_id and sr.deleted_at is null) then raise exception 'E_ROLE_IN_USE'; end if;
  update public.roles set deleted_at = now() where id = p_id and shop_id = s and deleted_at is null;
  if not found then raise exception 'E_NOT_FOUND'; end if;
end $$;

-- الدور الأساسي للموظف (استقبال أو فني) من أدواره: لو فيه دور مبني على "فني" ← فني، وإلا استقبال
create or replace function public.sync_base_role(p_profile uuid) returns void
language plpgsql security definer set search_path = public as $$
declare b public.app_role;
begin
  select case when bool_or(r.base = 'technician') and not bool_or(r.base = 'reception') then 'technician' else 'reception' end::public.app_role
    into b from public.staff_roles sr join public.roles r on r.id = sr.role_id and r.deleted_at is null
   where sr.profile_id = p_profile and sr.deleted_at is null;
  if b is null then return; end if;
  perform set_config('warsha.grant', '1', true);
  update public.profiles set role = b where id = p_profile and role in ('reception', 'technician') and role is distinct from b;
  perform set_config('warsha.grant', '', true);
end $$;
revoke execute on function public.sync_base_role(uuid) from public, anon, authenticated;

-- أدوار موظف (دور أو أكتر). صاحب المحل ما بيتغيّرش (عنده كل حاجة دايمًا)
create or replace function public.set_staff_roles(p_profile uuid, p_roles uuid[]) returns void
language plpgsql security definer set search_path = public as $$
declare s uuid := public.current_shop_id(); o public.profiles; before uuid[];
begin
  perform public.ledger_require(array['owner']::public.app_role[]);
  select * into o from public.profiles where id = p_profile and shop_id = s and deleted_at is null;
  if not found then raise exception 'E_NOT_FOUND'; end if;
  if o.role = 'owner' then raise exception 'E_OWNER_PERMS'; end if;
  if coalesce(array_length(p_roles, 1), 0) = 0 then raise exception 'E_BAD_INPUT'; end if;
  if exists (select 1 from unnest(p_roles) x where not exists (select 1 from public.roles r where r.id = x and r.shop_id = s and r.deleted_at is null)) then raise exception 'E_NOT_FOUND'; end if;
  before := array(select role_id from public.staff_roles where profile_id = p_profile and deleted_at is null);
  update public.staff_roles set deleted_at = now() where profile_id = p_profile and deleted_at is null and role_id <> all (p_roles);
  insert into public.staff_roles(shop_id, profile_id, role_id)
  select s, p_profile, x from unnest(p_roles) x
  where not exists (select 1 from public.staff_roles sr where sr.profile_id = p_profile and sr.role_id = x and sr.deleted_at is null);
  perform public.sync_base_role(p_profile);
  insert into public.audit_log(shop_id, actor_id, action, entity, entity_id, before, after)
  values (s, auth.uid(), 'staff_roles', 'profiles', p_profile, jsonb_build_object('roles', before), jsonb_build_object('roles', p_roles));
end $$;

-- استثناء لموظف: يسمح أو يمنع، أو null = يرجع زي دوره
create or replace function public.set_staff_override(p_profile uuid, p_section text, p_op text, p_allow boolean) returns void
language plpgsql security definer set search_path = public as $$
declare s uuid := public.current_shop_id(); o public.profiles;
begin
  perform public.ledger_require(array['owner']::public.app_role[]);
  select * into o from public.profiles where id = p_profile and shop_id = s and deleted_at is null;
  if not found then raise exception 'E_NOT_FOUND'; end if;
  if o.role = 'owner' then raise exception 'E_OWNER_PERMS'; end if;
  if not (p_section = any (public.perm_sections())) or not (p_op = any (public.perm_ops())) then raise exception 'E_BAD_INPUT'; end if;
  update public.staff_overrides set deleted_at = now() where profile_id = p_profile and section = p_section and op = p_op and deleted_at is null;
  if p_allow is not null then
    insert into public.staff_overrides(shop_id, profile_id, section, op, allow) values (s, p_profile, p_section, p_op, p_allow);
  end if;
end $$;

-- الدعوة: الأدوار اللي اتختارت (لو فاضية: الدور الجاهز بتاع دوره الأساسي)
create or replace function public.tg_join_roles() returns trigger
language plpgsql security definer set search_path = public as $$
declare inv public.staff_invites;
begin
  if new.role not in ('reception', 'technician') then return null; end if;
  select * into inv from public.staff_invites where shop_id = new.shop_id and lower(email) = lower(new.email) order by accepted_at desc nulls last, created_at desc limit 1;
  insert into public.staff_roles(shop_id, profile_id, role_id)
  select new.shop_id, new.id, r.id from public.roles r
  where r.shop_id = new.shop_id and r.deleted_at is null
    and (r.id = any (coalesce(inv.role_ids, '{}')) or (coalesce(array_length(inv.role_ids, 1), 0) = 0 and r.preset = new.role::text))
    and not exists (select 1 from public.staff_roles sr where sr.profile_id = new.id and sr.role_id = r.id and sr.deleted_at is null);
  perform public.sync_base_role(new.id);
  return null;
end $$;
create trigger zz_join_roles after insert on public.profiles for each row execute function public.tg_join_roles();

-- الدور الأساسي بيتغير من الأدوار بس (sync_base_role)، مش بتعديل مباشر
create or replace function public.tg_profile_role_guard() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if new.role is distinct from old.role and old.role in ('reception', 'technician') and new.role in ('reception', 'technician')
     and coalesce(current_setting('warsha.grant', true), '') <> '1' and not public.restoring() then
    raise exception 'E_FORBIDDEN';
  end if;
  return new;
end $$;
create trigger b_profile_role_guard before update on public.profiles for each row execute function public.tg_profile_role_guard();

-- نوع الفرع (صاحب المحل)
create or replace function public.set_branch_kind(p_id uuid, p_kind text) returns void
language plpgsql security definer set search_path = public as $$
begin
  perform public.ledger_require(array['owner']::public.app_role[]);
  if p_kind not in ('repair', 'sales', 'both') then raise exception 'E_BAD_INPUT'; end if;
  update public.branches set kind = p_kind where id = p_id and shop_id = public.current_shop_id() and deleted_at is null;
  if not found then raise exception 'E_NOT_FOUND'; end if;
end $$;

revoke execute on function public.save_role(uuid, text, public.app_role, jsonb), public.archive_role(uuid), public.set_staff_roles(uuid, uuid[]),
  public.set_staff_override(uuid, text, text, boolean), public.set_branch_kind(uuid, text) from public, anon;
grant execute on function public.save_role(uuid, text, public.app_role, jsonb), public.archive_role(uuid), public.set_staff_roles(uuid, uuid[]),
  public.set_staff_override(uuid, text, text, boolean), public.set_branch_kind(uuid, text) to authenticated;

-- ---------- الدوال اللي بتكتب: الصلاحية (ونوع الفرع) قبل أي حاجة ----------
create or replace function public.perm_require(p_section text, p_op text) returns void
language plpgsql stable security definer set search_path = public as $$
begin
  if not public.has_perm(p_section, p_op) then raise exception 'E_FORBIDDEN'; end if;
  if not public.branch_allows(public.op_branch(), p_section) then raise exception 'E_BRANCH_KIND'; end if;
end $$;
revoke execute on function public.perm_require(text, text) from public, anon, authenticated;

-- ---------- الدوال اللي بتكتب أو بتقرا مبالغ: الصلاحية ----------
-- record_sale: (src: 0008_ledger.sql) + الصلاحية
create or replace function public.record_sale(p_id uuid, p_lines jsonb, p_cashbox uuid default null, p_customer uuid default null, p_note text default null)
returns uuid
language plpgsql security definer set search_path = public as $$
declare
  s uuid := public.current_shop_id();
  e uuid := gen_random_uuid();
  l jsonb;
  it public.items;
  q bigint; p bigint; cost bigint;
  rev_parts bigint := 0; rev_acc bigint := 0; total_cost bigint := 0;
  debit_acc uuid; pt text; pid uuid;
begin
  perform public.ledger_require(array['owner', 'reception']::public.app_role[]);
  perform public.perm_require('sales', 'add');
  if public.ledger_idem(p_id) is not null then return public.ledger_idem(p_id); end if;
  -- البيع بالآجل لصاحب المحل بس
  if p_cashbox is null and (p_customer is null or public.current_app_role() <> 'owner') then raise exception 'E_BAD_INPUT'; end if;
  if p_customer is not null and not exists (select 1 from public.customers where id = p_customer and shop_id = s and deleted_at is null) then raise exception 'E_NOT_FOUND'; end if;
  if jsonb_typeof(p_lines) <> 'array' or jsonb_array_length(p_lines) = 0 then raise exception 'E_BAD_INPUT'; end if;
  insert into public.journal_entries(id, shop_id, source_type, source_id, memo, idem_key, created_by)
  values (e, s, 'sale', p_id, nullif(trim(p_note), ''), p_id, auth.uid());
  for l in select * from jsonb_array_elements(p_lines) loop
    select * into it from public.items where id = (l ->> 'item')::uuid and shop_id = s and deleted_at is null;
    if not found then raise exception 'E_NOT_FOUND'; end if;
    q := (l ->> 'qty')::bigint;
    p := (l ->> 'price')::bigint;
    if q is null or q <= 0 or p is null or p < 0 then raise exception 'E_BAD_AMOUNT'; end if;
    cost := public.ledger_issue(it.id, q, e);
    total_cost := total_cost + cost;
    if it.kind = 'part' then rev_parts := rev_parts + q * p; else rev_acc := rev_acc + q * p; end if;
  end loop;
  perform public.ledger_amount(rev_parts + rev_acc);
  if p_cashbox is null then
    debit_acc := public.ledger_acc('ar'); pt := 'customer'; pid := p_customer;
  else
    debit_acc := (public.ledger_cashbox(p_cashbox)).id;
  end if;
  insert into public.journal_lines(shop_id, entry_id, account_id, party_type, party_id, debit, credit)
  values (s, e, debit_acc, pt, pid, rev_parts + rev_acc, 0);
  if rev_parts > 0 then insert into public.journal_lines(shop_id, entry_id, account_id, debit, credit) values (s, e, public.ledger_acc('rev_parts'), 0, rev_parts); end if;
  if rev_acc > 0 then insert into public.journal_lines(shop_id, entry_id, account_id, debit, credit) values (s, e, public.ledger_acc('rev_accessories'), 0, rev_acc); end if;
  if total_cost > 0 then
    insert into public.journal_lines(shop_id, entry_id, account_id, debit, credit) values
      (s, e, public.ledger_acc('cogs'), total_cost, 0), (s, e, public.ledger_acc('inventory'), 0, total_cost);
  end if;
  if p_cashbox is not null and p_customer is not null then
    null; -- البيع النقدي لعميل معروف ما بيأثرش على رصيده
  end if;
  return e;
end $$;

-- sale_return: (src: 0027_inventory.sql) + الصلاحية
create or replace function public.sale_return(p_id uuid, p_item uuid, p_qty integer, p_refund bigint, p_cashbox uuid default null, p_customer uuid default null, p_restock boolean default true, p_reason text default null) returns uuid
language plpgsql security definer set search_path = public as $$
declare s uuid := public.current_shop_id(); e uuid; it public.items; cost bigint; cb uuid; rev uuid;
begin
  perform public.ledger_require(array['owner', 'reception']::public.app_role[]);
  perform public.perm_require('sales', 'edit');
  e := public.ledger_idem(p_id);
  if e is not null then return e; end if;
  if nullif(trim(p_reason), '') is null then raise exception 'E_REASON_REQUIRED'; end if;
  if p_qty is null or p_qty <= 0 or p_refund is null or p_refund < 0 then raise exception 'E_BAD_AMOUNT'; end if;
  select * into it from public.items where id = p_item and shop_id = s and deleted_at is null for update;
  if not found then raise exception 'E_NOT_FOUND'; end if;
  if p_cashbox is null and p_refund > 0 and p_customer is null then raise exception 'E_BAD_INPUT'; end if;
  if p_customer is not null and not exists (select 1 from public.customers where id = p_customer and shop_id = s and deleted_at is null) then raise exception 'E_NOT_FOUND'; end if;
  if p_cashbox is not null then cb := (public.ledger_cashbox(p_cashbox)).id; end if;
  rev := public.ledger_acc(case when it.kind = 'part' then 'rev_parts' else 'rev_accessories' end);
  cost := public.item_last_cost(p_item) * p_qty;
  if p_refund = 0 and (cost = 0 or not p_restock) then raise exception 'E_BAD_AMOUNT'; end if;
  e := gen_random_uuid();
  insert into public.journal_entries(id, shop_id, source_type, source_id, memo, idem_key, created_by)
  values (e, s, 'sale_return', p_item, trim(p_reason), p_id, auth.uid());
  if p_refund > 0 then
    insert into public.journal_lines(shop_id, entry_id, account_id, debit, credit) values (s, e, rev, p_refund, 0);
    if cb is not null then
      insert into public.journal_lines(shop_id, entry_id, account_id, debit, credit) values (s, e, cb, 0, p_refund);
    else
      insert into public.journal_lines(shop_id, entry_id, account_id, party_type, party_id, debit, credit) values (s, e, public.ledger_acc('ar'), 'customer', p_customer, 0, p_refund);
    end if;
  end if;
  -- القطعة السليمة بترجع المخزون بتكلفتها (والتكلفة بتخرج من تكلفة البضاعة). البايظة ما بترجعش، وتكلفتها فضلت مصروف.
  if p_restock and cost > 0 then
    insert into public.journal_lines(shop_id, entry_id, account_id, debit, credit) values
      (s, e, public.ledger_acc('inventory'), cost, 0), (s, e, public.ledger_acc('cogs'), 0, cost);
    insert into public.stock_moves(shop_id, item_id, entry_id, qty, value) values (s, p_item, e, p_qty, cost);
  elsif p_restock then
    insert into public.stock_moves(shop_id, item_id, entry_id, qty, value) values (s, p_item, e, p_qty, 0);
  end if;
  return e;
end $$;

-- record_payment: (src: 0008_ledger.sql) + الصلاحية
create or replace function public.record_payment(p_id uuid, p_customer uuid, p_cashbox uuid, p_amount bigint, p_device uuid default null, p_method text default null, p_note text default null)
returns uuid
language plpgsql security definer set search_path = public as $$
declare
  cb public.accounts;
  e uuid;
  dev public.devices;
begin
  perform public.ledger_require(array['owner', 'reception']::public.app_role[]);
  perform public.perm_require('cashbox', 'add');
  e := public.ledger_idem(p_id);
  if e is not null then return e; end if;
  perform public.ledger_amount(p_amount);
  cb := public.ledger_cashbox(p_cashbox);
  if not exists (select 1 from public.customers where id = p_customer and shop_id = cb.shop_id and deleted_at is null) then raise exception 'E_NOT_FOUND'; end if;
  if p_device is not null then
    select * into dev from public.devices where id = p_device and shop_id = cb.shop_id and deleted_at is null;
    if not found or dev.customer_id <> p_customer then raise exception 'E_CROSS_SHOP'; end if;
  end if;
  e := public.ledger_post('payment', p_id, p_note, jsonb_build_array(
    public.ledger_line(cb.id, p_amount, 0),
    public.ledger_line(public.ledger_acc('ar'), 0, p_amount, 'customer', p_customer)
  ), p_device, p_id);
  insert into public.payments(id, shop_id, customer_id, device_id, cashbox_id, method, amount, entry_id, created_by)
  values (p_id, cb.shop_id, p_customer, p_device, cb.id, coalesce(p_method, cb.method), p_amount, e, auth.uid());
  return e;
end $$;

-- record_expense: (src: 0008_ledger.sql) + الصلاحية
create or replace function public.record_expense(p_id uuid, p_account uuid, p_cashbox uuid, p_amount bigint, p_note text default null)
returns uuid
language plpgsql security definer set search_path = public as $$
declare cb public.accounts; e uuid;
begin
  perform public.ledger_require(array['owner']::public.app_role[]);
  perform public.perm_require('expenses', 'add');
  e := public.ledger_idem(p_id);
  if e is not null then return e; end if;
  perform public.ledger_amount(p_amount);
  cb := public.ledger_cashbox(p_cashbox);
  if not exists (select 1 from public.accounts where id = p_account and shop_id = cb.shop_id and kind = 'expense' and active and deleted_at is null) then raise exception 'E_BAD_ACCOUNT'; end if;
  return public.ledger_post('expense', p_id, p_note, jsonb_build_array(public.ledger_line(p_account, p_amount, 0), public.ledger_line(cb.id, 0, p_amount)), null, p_id);
end $$;

-- use_part: (src: 0008_ledger.sql) + الصلاحية
create or replace function public.use_part(p_id uuid, p_device uuid, p_item uuid, p_qty integer default 1)
returns uuid
language plpgsql security definer set search_path = public as $$
declare
  e uuid;
  cost bigint;
  inv uuid := public.ledger_acc('inventory');
  cg uuid := public.ledger_acc('cogs');
begin
  perform public.ledger_require(array['owner', 'technician']::public.app_role[]);
  perform public.perm_require('devices', 'edit');
  e := public.ledger_idem(p_id);
  if e is not null then return e; end if;
  if not exists (select 1 from public.devices where id = p_device and shop_id = public.current_shop_id() and deleted_at is null and status <> 'delivered') then raise exception 'E_NOT_FOUND'; end if;
  -- القيد محتاج يتعمل الأول عشان حركة المخزون تتربط بيه، والتوازن بيتراجع في آخر العملية
  e := gen_random_uuid();
  insert into public.journal_entries(id, shop_id, source_type, source_id, device_id, idem_key, created_by)
  values (e, public.current_shop_id(), 'part_use', p_item, p_device, p_id, auth.uid());
  cost := public.ledger_issue(p_item, p_qty, e);
  if cost > 0 then
    insert into public.journal_lines(shop_id, entry_id, account_id, debit, credit) values
      (public.current_shop_id(), e, cg, cost, 0),
      (public.current_shop_id(), e, inv, 0, cost);
  else
    raise exception 'E_BAD_AMOUNT';  -- صنف من غير تكلفة: لازم يتشتري بسعر الأول
  end if;
  return e;
end $$;

-- device_manual_part: (src: 0027_inventory.sql) + الصلاحية
create or replace function public.device_manual_part(p_id uuid, p_device uuid, p_name text, p_cost bigint, p_cashbox uuid default null, p_supplier uuid default null) returns uuid
language plpgsql security definer set search_path = public as $$
declare s uuid := public.current_shop_id(); e uuid; credit_line jsonb;
begin
  perform public.ledger_require(array['owner', 'reception']::public.app_role[]);
  perform public.perm_require('devices', 'edit');
  e := public.ledger_idem(p_id);
  if e is not null then return e; end if;
  if nullif(trim(p_name), '') is null then raise exception 'E_BAD_INPUT'; end if;
  perform public.ledger_amount(p_cost);
  if not exists (select 1 from public.devices where id = p_device and shop_id = s and deleted_at is null and status <> 'delivered') then raise exception 'E_NOT_FOUND'; end if;
  if p_cashbox is not null then
    credit_line := public.ledger_line((public.ledger_cashbox(p_cashbox)).id, 0, p_cost);
  elsif p_supplier is not null then
    if not exists (select 1 from public.suppliers where id = p_supplier and shop_id = s and deleted_at is null) then raise exception 'E_NOT_FOUND'; end if;
    credit_line := public.ledger_line(public.ledger_acc('ap'), 0, p_cost, 'supplier', p_supplier);
  else
    raise exception 'E_BAD_INPUT';
  end if;
  return public.ledger_post('part_use', null, trim(p_name), jsonb_build_array(public.ledger_line(public.ledger_acc('cogs'), p_cost, 0), credit_line), p_device, p_id);
end $$;

-- device_money: (src: 0008_ledger.sql) + الصلاحية
create or replace function public.device_money(p_device uuid) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare fc integer; paid bigint;
begin
  perform public.ledger_require(array['owner', 'reception']::public.app_role[]);
  if not public.has_perm('devices', 'amounts') then raise exception 'E_FORBIDDEN'; end if;
  if not exists (select 1 from public.devices where id = p_device and shop_id = public.current_shop_id()) then raise exception 'E_NOT_FOUND'; end if;
  select final_cost into fc from public.device_costs where device_id = p_device and deleted_at is null;
  paid := public.device_paid(p_device);
  return jsonb_build_object(
    'final', fc, 'paid', paid, 'due', greatest(coalesce(fc, 0) - paid, 0),
    'payments', coalesce((select jsonb_agg(jsonb_build_object(
        'id', p.id, 'amount', p.amount, 'method', p.method, 'created_at', p.created_at, 'entry_id', p.entry_id,
        'by', (select full_name from public.profiles where id = p.created_by),
        'reversed', exists (select 1 from public.journal_entries r where r.reverses_id = p.entry_id)) order by p.created_at)
      from public.payments p where p.device_id = p_device), '[]'::jsonb),
    'parts_cost', case when public.current_app_role() = 'owner' then (
      select coalesce(sum(l.debit), 0) from public.journal_lines l join public.journal_entries e on e.id = l.entry_id
      where e.device_id = p_device and e.source_type in ('part_use', 'reversal') and l.account_id = public.ledger_acc('cogs')) - (
      select coalesce(sum(l.credit), 0) from public.journal_lines l join public.journal_entries e on e.id = l.entry_id
      where e.device_id = p_device and e.source_type = 'reversal' and l.account_id = public.ledger_acc('cogs')) end
  );
end $$;

-- items_stock: (src: 0035_lists_everywhere.sql) + الصلاحية
create or replace function public.items_stock(p_all boolean default false) returns table(id uuid, kind text, name text, sku text, sale_price integer, qty bigint, avg_cost bigint, value bigint, min_qty integer, supplier_id uuid, short boolean, category text, barcode text, image_path text, brand text)
language plpgsql stable security definer set search_path = public as $$
declare r public.app_role := public.current_app_role(); b uuid := public.op_branch(); everywhere boolean;
begin
  if r is null then raise exception 'E_FORBIDDEN'; end if;
  if not (public.has_perm('inventory', 'view') or public.has_perm('sales', 'view')) then raise exception 'E_FORBIDDEN'; end if;
  everywhere := p_all and r = 'owner';
  return query
  select i.id, i.kind, i.name, i.sku,
         case when r = 'technician' then null else i.sale_price end,
         coalesce(st.q, 0)::bigint,
         case when r = 'owner' and coalesce(st.q, 0) > 0 then (st.v / st.q)::bigint end,
         case when r = 'owner' then coalesce(st.v, 0)::bigint end,
         i.min_qty, case when r = 'owner' then i.supplier_id end,
         i.min_qty > 0 and coalesce(st.q, 0) <= i.min_qty,
         i.category, i.barcode, i.image_path, i.brand
  from public.items i
  left join (select m.item_id, sum(m.qty) as q, sum(m.value) as v from public.stock_moves m where everywhere or m.branch_id = b group by m.item_id) st on st.item_id = i.id
  where i.shop_id = public.current_shop_id() and i.deleted_at is null
  order by i.kind, i.name;
end $$;
