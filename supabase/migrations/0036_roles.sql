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
