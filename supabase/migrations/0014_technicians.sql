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
