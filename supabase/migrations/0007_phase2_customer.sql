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
