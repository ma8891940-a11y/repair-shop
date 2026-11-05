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
