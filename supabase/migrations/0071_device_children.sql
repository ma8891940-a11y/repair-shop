-- 0071: (24ب) تفاصيل الجهاز (التكلفة والدفعات والصور والملاحظات والسجل والفحص والخطوات والرسايل وكلمة السر)
-- كانت معزولة بالمحل بس. بقت: اللي بيشوف الجهاز نفسه (فرعه، والفني أجهزته بس)، والكتابة في فرع الجهاز.
-- سياسات مقيّدة فوق الموجود (وسياسة قراية ملفات الصور اتعادت أضيق)، من غير أي تغيير في البيانات.
-- الدفعات بالخزنة مش بالجهاز: الكاشير والمحاسب بيشوفوا دفعات خزنهم، وكشف العميل محتاجها.

-- الكتابة على الجهاز: فرع الموظف نفسه (مش جهاز في الطريق)، والفني أجهزته بس
create or replace function public.device_writable(p_device uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.devices d where d.id = p_device and d.shop_id = public.current_shop_id()
      and (public.current_app_role() = 'owner' or public.can_branch(d.branch_id))
      and (public.current_app_role() <> 'technician' or public.tech_can_see(d.id)))
$$;
revoke execute on function public.device_writable(uuid) from public, anon;
grant execute on function public.device_writable(uuid) to authenticated;

-- ---------- القراية: الاستعلام على devices بيمشي بسياسات devices نفسها ----------
do $$
declare t text;
begin
  foreach t in array array['device_costs', 'device_photos', 'device_notes', 'status_log', 'device_checks', 'repair_steps', 'device_passcodes', 'quote_decisions', 'device_ratings', 'photo_upload_sessions'] loop
    execute format('create policy reach_%1$s_select on public.%1$I as restrictive for select to authenticated using (exists (select 1 from public.devices d where d.id = device_id))', t);
  end loop;
end $$;
-- رابط الرفع (token) للي بيستلم أو بيعدّل بس
create policy perm_upload_sessions_select on public.photo_upload_sessions as restrictive for select to authenticated
  using ((select public.has_perm('devices', 'edit')) or (select public.has_perm('intake', 'add')));
-- رسالة من غير جهاز (كشف حساب مثلًا): لأصحاب العملاء
create policy reach_message_log_select on public.message_log as restrictive for select to authenticated
  using (case when device_id is null then (select public.has_perm('customers', 'view')) else exists (select 1 from public.devices d where d.id = device_id) end);
-- الدفعة: خزنتها لازم تكون باينة للموظف (فرعه)
create policy reach_payments_select on public.payments as restrictive for select to authenticated
  using (exists (select 1 from public.accounts a where a.id = cashbox_id));

-- ---------- الكتابة ----------
-- التحديث using (true): الصف باين (القراية فوق)، والممنوع بيرجّع خطأ بدل ما يعدّي من غير ما حاجة تتحفظ
create policy reach_device_costs_insert on public.device_costs as restrictive for insert to authenticated with check (public.device_writable(device_id));
create policy reach_device_costs_update on public.device_costs as restrictive for update to authenticated using (true) with check (public.device_writable(device_id));
create policy reach_device_notes_insert on public.device_notes as restrictive for insert to authenticated
  with check ((select public.has_perm('devices', 'view')) and public.device_writable(device_id));
create policy reach_device_notes_update on public.device_notes as restrictive for update to authenticated using (true) with check (public.device_writable(device_id));
create policy reach_device_photos_insert on public.device_photos as restrictive for insert to authenticated
  with check (((select public.has_perm('devices', 'edit')) or (select public.has_perm('intake', 'add'))) and public.device_writable(device_id));
create policy reach_device_photos_update on public.device_photos as restrictive for update to authenticated
  using (true) with check ((select public.has_perm('devices', 'edit')) and public.device_writable(device_id));
create policy reach_device_checks_insert on public.device_checks as restrictive for insert to authenticated
  with check (((select public.has_perm('devices', 'edit')) or (select public.has_perm('intake', 'add'))) and public.device_writable(device_id));
create policy reach_device_checks_update on public.device_checks as restrictive for update to authenticated
  using (true) with check (((select public.has_perm('devices', 'edit')) or (select public.has_perm('intake', 'add'))) and public.device_writable(device_id));
create policy reach_message_log_insert on public.message_log as restrictive for insert to authenticated
  with check (case when device_id is null then (select public.has_perm('customers', 'view')) else exists (select 1 from public.devices d where d.id = device_id) end);

-- ---------- ملفات الصور نفسها ----------
drop policy if exists device_photos_read on storage.objects;
create policy device_photos_read on storage.objects for select to authenticated
  using (
    bucket_id = 'device-photos'
    and (storage.foldername(name))[1] = (select public.current_shop_id())::text
    and exists (select 1 from public.devices d where d.id = case when (storage.foldername(objects.name))[2] ~ '^[0-9a-f]{8}-([0-9a-f]{4}-){3}[0-9a-f]{12}$' then (storage.foldername(objects.name))[2]::uuid end)
  );
-- الرفع: مقيّدة فوق سياسة 0002 (جلسة الرفع من الموبايل بـ token ليها فحصها)
create policy device_photos_upload_reach on storage.objects as restrictive for insert to authenticated
  with check (
    bucket_id <> 'device-photos'
    or public.photo_upload_allowed(name)
    or (((select public.has_perm('devices', 'edit')) or (select public.has_perm('intake', 'add')))
        and public.device_writable(case when (storage.foldername(objects.name))[2] ~ '^[0-9a-f]{8}-([0-9a-f]{4}-){3}[0-9a-f]{12}$' then (storage.foldername(objects.name))[2]::uuid end))
  );

-- ---------- التوزيع: الفني في فرع الجهاز بس ----------
create or replace function public.tech_in_branch(p_tech uuid, p_branch uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select coalesce(
    (select bool_or(sb.branch_id = p_branch) from public.staff_branches sb join public.branches b on b.id = sb.branch_id and b.deleted_at is null
      where sb.profile_id = p_tech and sb.deleted_at is null),
    -- من غير فروع: الرئيسي (زي my_branch_ids)
    exists (select 1 from public.branches b where b.id = p_branch and b.is_main and b.deleted_at is null))
$$;
revoke execute on function public.tech_in_branch(uuid, uuid) from public, anon, authenticated;

-- pick_technician: (src: 0014_technicians.sql) + فني في فرع الجهاز بس
create or replace function public.pick_technician(p_device uuid, p_specialty uuid) returns uuid
language sql stable security definer set search_path = public as $$
  select coalesce(
    (select s.technician_id from public.repair_steps s join public.profiles p on p.id = s.technician_id and p.deleted_at is null
      where s.device_id = p_device and s.specialty_id = p_specialty and s.technician_id is not null and s.status = 'done'
        and public.tech_in_branch(s.technician_id, (select branch_id from public.devices where id = p_device))
      order by s.step_no desc limit 1),
    (select ss.profile_id from public.staff_specialties ss join public.profiles p on p.id = ss.profile_id and p.deleted_at is null and p.role = 'technician'
      where ss.specialty_id = p_specialty and ss.deleted_at is null and ss.shop_id = public.current_shop_id()
        and public.tech_in_branch(ss.profile_id, (select branch_id from public.devices where id = p_device))
      order by (select count(*) from public.repair_steps x where x.technician_id = ss.profile_id and x.status in ('pending', 'active')), p.full_name
      limit 1),
    -- مفيش حد عنده التخصص: فني عام (ملوش تخصصات)
    (select p.id from public.profiles p
      where p.shop_id = public.current_shop_id() and p.role = 'technician' and p.deleted_at is null
        and public.tech_in_branch(p.id, (select branch_id from public.devices where id = p_device))
        and not exists (select 1 from public.staff_specialties ss where ss.profile_id = p.id and ss.deleted_at is null)
      order by (select count(*) from public.repair_steps x where x.technician_id = p.id and x.status in ('pending', 'active')), p.full_name
      limit 1))
$$;

-- my_queue: (src: 0014_technicians.sql) + فروع الفني بس
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
    and public.can_branch(d.branch_id)
    and (s.technician_id = auth.uid()
         or (s.technician_id is null and public.tech_has_specialty(auth.uid(), s.specialty_id)))
    and not exists (select 1 from public.repair_steps p where p.device_id = s.device_id and p.step_no < s.step_no and p.status in ('pending', 'active'))
  order by case d.priority when 'urgent' then 0 when 'warranty' then 1 else 2 end, d.received_at;
end $$;

-- start_step: (src: 0014_technicians.sql) + صلاحية الأجهزة وفرع الجهاز
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
  perform public.device_require(s.device_id, 'edit');
  select * into d from public.devices where id = s.device_id;
  if d.status = 'awaiting_approval' then raise exception 'E_AWAITING_APPROVAL'; end if;
  if d.status in ('delivered', 'ready', 'unrepairable') then raise exception 'E_BAD_TRANSITION'; end if;
  update public.repair_steps set status = 'active', started_at = now(), technician_id = s.technician_id where id = s.id;
  select * into r from public.routes where id = s.route_id;
  perform public.walk_status(d.id, case when coalesce(r.diagnose, false) or d.status = 'received' then 'inspecting'::public.device_status else 'in_repair'::public.device_status end);
end $$;

-- finish_step: (src: 0014_technicians.sql) + صلاحية الأجهزة وفرع الجهاز
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
  perform public.device_require(s.device_id, 'edit');
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

-- reassign_step: (src: 0070_perm_matrix.sql) + الفني لازم يكون في فرع الجهاز
create or replace function public.reassign_step(p_step uuid, p_tech uuid) returns void
language plpgsql security definer set search_path = public as $$
declare s public.repair_steps;
begin
  perform public.ledger_require(array['owner', 'reception']::public.app_role[]);
  select * into s from public.repair_steps where id = p_step and shop_id = public.current_shop_id() for update;
  if not found or s.status not in ('pending', 'active') then raise exception 'E_NOT_FOUND'; end if;
  perform public.device_require(s.device_id, 'edit');
  if p_tech is not null and not exists (select 1 from public.profiles where id = p_tech and shop_id = s.shop_id and role = 'technician' and deleted_at is null) then raise exception 'E_NOT_FOUND'; end if;
  if p_tech is not null and not public.tech_in_branch(p_tech, (select branch_id from public.devices where id = s.device_id)) then raise exception 'E_TECH_BRANCH'; end if;
  update public.repair_steps set technician_id = p_tech, status = case when status = 'active' then 'pending' else status end, started_at = null where id = s.id;
end $$;

-- record_payment: (src: 0036_roles.sql) + جهاز يوصله الموظف بس
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
    -- أو كان في فرعي واتنقل: كاش اتحصّل أوفلاين قبل النقل لازم يتسجل
    if public.device_reach(p_device) is not true and not exists (
        select 1 from public.audit_log l where l.shop_id = cb.shop_id and l.entity = 'devices' and l.entity_id = p_device and l.action = 'device_receive' and public.can_branch((l.before ->> 'branch')::uuid)) then
      raise exception 'E_FORBIDDEN';
    end if;
  end if;
  e := public.ledger_post('payment', p_id, p_note, jsonb_build_array(
    public.ledger_line(cb.id, p_amount, 0),
    public.ledger_line(public.ledger_acc('ar'), 0, p_amount, 'customer', p_customer)
  ), p_device, p_id);
  insert into public.payments(id, shop_id, customer_id, device_id, cashbox_id, method, amount, entry_id, created_by)
  values (p_id, cb.shop_id, p_customer, p_device, cb.id, coalesce(p_method, cb.method), p_amount, e, auth.uid());
  return e;
end $$;

-- receive_device: (src: 0070_perm_matrix.sql) + الخطوات المفتوحة بتتوزع على فنيين الفرع الجديد
create or replace function public.receive_device(p_device uuid) returns void
language plpgsql security definer set search_path = public as $$
declare s uuid := public.current_shop_id(); d public.devices;
begin
  perform public.ledger_require(array['owner', 'reception']::public.app_role[]);
  if public.has_perm('devices', 'edit') is not true then raise exception 'E_FORBIDDEN'; end if;
  select * into d from public.devices where id = p_device and shop_id = s and deleted_at is null for update;
  if not found or d.transfer_to is null then raise exception 'E_NOT_FOUND'; end if;
  if not public.can_branch(d.transfer_to) then raise exception 'E_FORBIDDEN'; end if;
  perform set_config('app.device_move', 'on', true);
  update public.devices set branch_id = d.transfer_to, transfer_to = null, transfer_at = null, transfer_by = null where id = d.id;
  perform set_config('app.device_move', 'off', true);
  update public.repair_steps st set technician_id = public.pick_technician(d.id, st.specialty_id), status = 'pending', started_at = null
  where st.device_id = d.id and st.status in ('pending', 'active') and st.technician_id is not null and not public.tech_in_branch(st.technician_id, d.transfer_to);
  insert into public.audit_log(shop_id, actor_id, action, entity, entity_id, before, after)
  values (s, auth.uid(), 'device_receive', 'devices', d.id, jsonb_build_object('branch', d.branch_id), jsonb_build_object('branch', d.transfer_to));
end $$;

-- tg_device_warranty_tech: (src: 0014_technicians.sql) + الفني لازم يكون لسه في فرع الجهاز، وإلا توزيع جديد
create or replace function public.tg_device_warranty_tech() returns trigger
language plpgsql security definer set search_path = public as $$
declare t uuid; sp uuid; n int;
begin
  if new.status = 'warranty_return' and old.status is distinct from 'warranty_return' then
    select s.technician_id, s.specialty_id into t, sp from public.repair_steps s
     where s.device_id = new.id and s.status = 'done' and s.technician_id is not null order by s.step_no desc limit 1;
    if t is not null and not public.tech_in_branch(t, new.branch_id) then t := public.pick_technician(new.id, sp); end if;
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

-- device_tech_name: (src: 0014_technicians.sql) + جهاز يوصله الموظف بس
create or replace function public.device_tech_name(p_device uuid) returns text
language sql stable security definer set search_path = public as $$
  select split_part(p.full_name, ' ', 1) from public.repair_steps s join public.profiles p on p.id = s.technician_id
  where s.device_id = p_device and s.shop_id = public.current_shop_id() and public.device_reach(p_device) and s.status in ('active', 'pending', 'done')
  order by case s.status when 'active' then 0 when 'pending' then 1 else 2 end, s.step_no desc limit 1
$$;
