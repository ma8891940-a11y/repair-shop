-- 0070: (34) الصلاحيات على السيرفر لكل الأدوار: دوال كانت بتتأكد من الدور العام بس (استقبال/فني)،
-- من غير صلاحية الجدول ولا الفرع، فالكاشير والمحاسب وموظف الفرع التاني كانوا يقدروا ينادوها بالـ id.
-- من غير أي تغيير في البيانات ولا الحسابات.

-- الموظف ليه الجهاز ده؟ (فرعه أو جهاز في الطريق لفرعه، والفني أجهزته بس، زي سياسة devices_select)
create or replace function public.device_reach(p_device uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select public.current_app_role() = 'owner' or exists (
    select 1 from public.devices d where d.id = p_device and d.shop_id = public.current_shop_id()
      and (public.can_branch(d.branch_id) or public.can_branch(d.transfer_to))
      and (public.current_app_role() <> 'technician' or public.tech_can_see(d.id)))
$$;

-- صلاحية في الأجهزة + الجهاز نفسه. p_intake: اللي بيستلم أجهزة كمان (المسار وكلمة السر والصور وقت الاستلام)
create or replace function public.device_require(p_device uuid, p_op text, p_intake boolean default false) returns void
language plpgsql stable security definer set search_path = public as $$
begin
  if (public.has_perm('devices', p_op) or (p_intake and public.has_perm('intake', 'add'))) is not true then raise exception 'E_FORBIDDEN'; end if;
  if public.device_reach(p_device) is not true then raise exception 'E_FORBIDDEN'; end if;
  -- جهاز في الطريق لفرعي: أشوفه بس، والتعديل بعد الاستلام (زي سياسة devices_update)
  if p_op = 'edit' and not exists (select 1 from public.devices d where d.id = p_device and (public.current_app_role() = 'owner' or public.can_branch(d.branch_id))) then raise exception 'E_FORBIDDEN'; end if;
end $$;

-- التصحيح: الموظف (حتى لو معاه "يحذف") في فروعه بس، والمرتبات والشركاء ورأس المال وسداد الضريبة لصاحب المحل بس
create or replace function public.entry_require(p_entry uuid) returns void
language plpgsql stable security definer set search_path = public as $$
begin
  if public.current_app_role() = 'owner' then return; end if;
  if exists (select 1 from public.journal_entries e where e.id = p_entry and (e.source_type = 'vat_payment' or not public.can_branch(e.branch_id)))
     or exists (select 1 from public.journal_lines l join public.accounts a on a.id = l.account_id where l.entry_id = p_entry
                and (a.kind in ('advances', 'salaries', 'partner_capital', 'partner_current', 'capital', 'drawings') or (a.kind = 'cash' and not public.can_branch(a.branch_id))))
     or exists (select 1 from public.stock_moves m where m.entry_id = p_entry and not public.can_branch(m.branch_id)) then
    raise exception 'E_FORBIDDEN';
  end if;
end $$;
revoke execute on function public.device_reach(uuid), public.device_require(uuid, text, boolean), public.entry_require(uuid) from public, anon, authenticated;

-- send_device: (src: 0034_branches.sql) + صلاحية "يعدّل" في الأجهزة
create or replace function public.send_device(p_device uuid, p_to uuid) returns void
language plpgsql security definer set search_path = public as $$
declare s uuid := public.current_shop_id(); d public.devices;
begin
  perform public.ledger_require(array['owner', 'reception']::public.app_role[]);
  if public.has_perm('devices', 'edit') is not true then raise exception 'E_FORBIDDEN'; end if;
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

-- cancel_device_transfer: (src: 0034_branches.sql) + صلاحية "يعدّل" في الأجهزة
create or replace function public.cancel_device_transfer(p_device uuid) returns void
language plpgsql security definer set search_path = public as $$
declare s uuid := public.current_shop_id(); d public.devices;
begin
  perform public.ledger_require(array['owner', 'reception']::public.app_role[]);
  if public.has_perm('devices', 'edit') is not true then raise exception 'E_FORBIDDEN'; end if;
  select * into d from public.devices where id = p_device and shop_id = s and deleted_at is null for update;
  if not found or d.transfer_to is null then raise exception 'E_NOT_FOUND'; end if;
  if not (public.can_branch(d.branch_id) or public.can_branch(d.transfer_to)) then raise exception 'E_FORBIDDEN'; end if;
  perform set_config('app.device_move', 'on', true);
  update public.devices set transfer_to = null, transfer_at = null, transfer_by = null where id = d.id;
  perform set_config('app.device_move', 'off', true);
  insert into public.audit_log(shop_id, actor_id, action, entity, entity_id, before, after)
  values (s, auth.uid(), 'device_transfer_cancel', 'devices', d.id, jsonb_build_object('to', d.transfer_to), null);
end $$;

-- receive_device: (src: 0034_branches.sql) + صلاحية "يعدّل" في الأجهزة
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
  insert into public.audit_log(shop_id, actor_id, action, entity, entity_id, before, after)
  values (s, auth.uid(), 'device_receive', 'devices', d.id, jsonb_build_object('branch', d.branch_id), jsonb_build_object('branch', d.transfer_to));
end $$;

-- reassign_step: (src: 0014_technicians.sql) + الصلاحية والفرع
create or replace function public.reassign_step(p_step uuid, p_tech uuid) returns void
language plpgsql security definer set search_path = public as $$
declare s public.repair_steps;
begin
  perform public.ledger_require(array['owner', 'reception']::public.app_role[]);
  select * into s from public.repair_steps where id = p_step and shop_id = public.current_shop_id() for update;
  if not found or s.status not in ('pending', 'active') then raise exception 'E_NOT_FOUND'; end if;
  perform public.device_require(s.device_id, 'edit');
  if p_tech is not null and not exists (select 1 from public.profiles where id = p_tech and shop_id = s.shop_id and role = 'technician' and deleted_at is null) then raise exception 'E_NOT_FOUND'; end if;
  update public.repair_steps set technician_id = p_tech, status = case when status = 'active' then 'pending' else status end, started_at = null where id = s.id;
end $$;

-- suggest_device_price: (src: 0012_spec_completion.sql) + مبالغ الأجهزة والفرع
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
  perform public.device_require(p_device, 'amounts');
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

-- device_money: (src: 0036_roles.sql) + الفرع
create or replace function public.device_money(p_device uuid) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare fc integer; paid bigint;
begin
  perform public.ledger_require(array['owner', 'reception']::public.app_role[]);
  if not public.has_perm('devices', 'amounts') then raise exception 'E_FORBIDDEN'; end if;
  if not exists (select 1 from public.devices where id = p_device and shop_id = public.current_shop_id()) then raise exception 'E_NOT_FOUND'; end if;
  perform public.device_require(p_device, 'amounts');
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

-- device_vat: (src: 0062_vat.sql) + مبالغ الأجهزة أو الوضع المالي، والفرع
create or replace function public.device_vat(p_device uuid) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare s uuid := public.current_shop_id(); r public.app_role := public.current_app_role(); v bigint; g bigint;
begin
  if s is null or r is null or r = 'technician' or r = 'marketing' then raise exception 'E_FORBIDDEN'; end if;
  if (public.has_perm('devices', 'amounts') or public.has_perm('finance', 'view')) is not true or public.device_reach(p_device) is not true then raise exception 'E_FORBIDDEN'; end if;
  select coalesce(sum(l.credit) filter (where a.kind = 'tax'), 0), coalesce(sum(l.credit) filter (where a.kind in ('tax', 'revenue')), 0)
    into v, g
  from public.journal_entries e join public.journal_lines l on l.entry_id = e.id join public.accounts a on a.id = l.account_id
  where e.shop_id = s and e.source_type = 'delivery' and e.source_id = p_device
    and not exists (select 1 from public.journal_entries x where x.reverses_id = e.id);
  if g = 0 then return null; end if;
  return jsonb_build_object('vat', v, 'gross', g, 'net', g - v);
end $$;

-- device_parts: (src: 0012_spec_completion.sql) + الصلاحية والفرع
create or replace function public.device_parts(p_device uuid)
returns table(item_id uuid, name text, qty bigint)
language plpgsql stable security definer set search_path = public as $$
#variable_conflict use_column
begin
  if public.current_app_role() is null then raise exception 'E_FORBIDDEN'; end if;
  if not exists (select 1 from public.devices where id = p_device and shop_id = public.current_shop_id()) then raise exception 'E_NOT_FOUND'; end if;
  perform public.device_require(p_device, 'view');
  return query
  select i.id, i.name, (-sum(m.qty))::bigint
  from public.stock_moves m
  join public.journal_entries e on e.id = m.entry_id
  join public.items i on i.id = m.item_id
  where (e.device_id = p_device) and e.source_type in ('part_use', 'reversal')
  group by i.id, i.name
  having -sum(m.qty) > 0;
end $$;

-- device_manual_part: (src: 0036_roles.sql) + الفرع والجهاز نفسه
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
  perform public.device_require(p_device, 'edit');
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

-- use_part: (src: 0036_roles.sql) + الفني أجهزته بس، وفي فرعه
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
  perform public.device_require(p_device, 'edit');
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

-- set_device_passcode: (src: 0005_device_passcode.sql) + الصلاحية والفرع
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
  perform public.device_require(p_device_id, 'edit', true);
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

-- reveal_device_passcode: (src: 0005_device_passcode.sql) + صلاحية "يشوف" في الأجهزة، والفني أجهزته بس، وفي فرعه
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
  perform public.device_require(p_device_id, 'view');
  select ds.decrypted_secret into v from vault.decrypted_secrets ds where ds.id = pc.secret_id;
  insert into public.audit_log(shop_id, actor_id, action, entity, entity_id, after)
  values (shop, auth.uid(), 'passcode_viewed', 'device_passcodes', p_device_id, jsonb_build_object('kind', pc.kind));
  return query select pc.kind, v;
end $$;

-- set_route: (src: 0014_technicians.sql) + الصلاحية والفرع
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
  perform public.device_require(d.id, 'edit', true);
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

-- start_photo_upload: (src: 0044_capture.sql) + الصلاحية والفرع
create or replace function public.start_photo_upload(p_device uuid)
returns table(token text, expires_at timestamptz)
-- extensions: فيها gen_random_bytes على Supabase
language plpgsql security definer set search_path = public, extensions, pg_temp as $$
declare d public.devices; t text := encode(gen_random_bytes(16), 'hex'); e timestamptz := now() + interval '30 minutes';
begin
  if public.current_app_role() not in ('owner', 'reception') then raise exception 'E_FORBIDDEN'; end if;
  select * into d from public.devices where id = p_device and shop_id = public.current_shop_id() and deleted_at is null;
  if d.id is null then raise exception 'E_NOT_FOUND'; end if;
  perform public.device_require(d.id, 'edit', true);
  if d.status = 'delivered' then raise exception 'E_DELIVERED'; end if;
  -- الجلسات القديمة لنفس الجهاز بتتقفل (رابط واحد شغال في نفس الوقت)
  update public.photo_upload_sessions s set deleted_at = now() where s.device_id = d.id and s.deleted_at is null;
  insert into public.photo_upload_sessions(shop_id, device_id, token, expires_at, created_by)
  values (d.shop_id, d.id, t, e, auth.uid());
  return query select t, e;
end $$;

-- apply_status_lww: (src: 0015_offline_backup.sql) + الصلاحية والفرع
create or replace function public.apply_status_lww(p_device uuid, p_status public.device_status, p_client_ts timestamptz)
returns jsonb
language plpgsql security definer set search_path = public as $$
declare d public.devices;
begin
  if public.current_app_role() is null then raise exception 'E_FORBIDDEN'; end if;
  select * into d from public.devices where id = p_device and shop_id = public.current_shop_id() and deleted_at is null for update;
  if not found then raise exception 'E_NOT_FOUND'; end if;
  perform public.device_require(d.id, 'edit');
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

-- models_report: (src: 0034_branches.sql) + صلاحية التقارير، والموظف فرعه بس
create or replace function public.models_report(p_from timestamptz, p_to timestamptz, p_branch uuid default null)
returns table(kind text, label text, devices integer)
language plpgsql stable security definer set search_path = public as $$
#variable_conflict use_column
begin
  perform public.grant_require('reports', 'view');
  if not public.all_my_branches() and (p_branch is null or not public.can_branch(p_branch)) then p_branch := public.op_branch(); end if;
  return query
  (select 'model'::text, d.brand || ' ' || d.model, count(*)::int from public.devices d
    where d.shop_id = public.current_shop_id() and d.received_at >= p_from and d.received_at < p_to and d.deleted_at is null and (p_branch is null or d.branch_id = p_branch)
    group by d.brand, d.model order by 3 desc limit 10)
  union all
  (select 'route'::text, coalesce(r.code, r.name, '-'), count(*)::int from public.devices d left join public.routes r on r.id = d.route_id
    where d.shop_id = public.current_shop_id() and d.received_at >= p_from and d.received_at < p_to and d.deleted_at is null and (p_branch is null or d.branch_id = p_branch)
    group by r.code, r.name order by 3 desc limit 10);
end $$;

-- marketing_due: (src: 0021_spec_rules.sql) + صلاحية الأجهزة والعملاء، والموظف فرعه بس
create or replace function public.marketing_due(p_days integer default 180)
returns table(device_id uuid, order_no text, brand text, model text, issue text, delivered_at timestamptz,
              customer_id uuid, customer_name text, phone text, tracking_token text)
language plpgsql stable security definer set search_path = public as $$
#variable_conflict use_column
declare s uuid := public.current_shop_id(); days integer := greatest(30, least(coalesce(p_days, 180), 720));
begin
  if public.current_app_role() not in ('owner', 'reception') then raise exception 'E_FORBIDDEN'; end if;
  if (public.has_perm('devices', 'view') and public.has_perm('customers', 'view')) is not true then raise exception 'E_FORBIDDEN'; end if;
  return query
  with last_dev as (
    select distinct on (d.customer_id) d.*
    from public.devices d
    where d.shop_id = s and d.deleted_at is null and d.status = 'delivered' and d.delivered_at is not null
      and (public.all_my_branches() or public.can_branch(d.branch_id))
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

-- item_branch_stock: (src: 0034_branches.sql) + القيمة (التكلفة) بصلاحية مبالغ المخزون
create or replace function public.item_branch_stock(p_item uuid) returns table(branch_id uuid, qty bigint, value bigint)
language sql stable security definer set search_path = public as $$
  select b.id, coalesce(sum(m.qty), 0)::bigint, case when (select public.has_perm('inventory', 'amounts')) then coalesce(sum(m.value), 0)::bigint end
  from public.branches b left join public.stock_moves m on m.branch_id = b.id and m.item_id = p_item
  where b.shop_id = public.current_shop_id() and b.deleted_at is null and b.id = any (public.my_branch_ids())
    and public.current_app_role() in ('owner', 'reception', 'technician')
  group by b.id
$$;

-- reverse_entry: (src: 0046_master.sql) + الموظف فروعه بس، والمرتبات والشركاء لصاحب المحل
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
  -- C3: كلمة السر الرئيسية (لو صاحب المحل حددها)
  perform public.master_require();
  if nullif(trim(p_reason), '') is null then raise exception 'E_REASON_REQUIRED'; end if;
  select * into o from public.journal_entries where id = p_entry and shop_id = public.current_shop_id() for update;
  if not found then raise exception 'E_NOT_FOUND'; end if;
  perform public.entry_require(o.id);
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

-- entry_args: (src: 0060_sale_lines.sql) + نفس شرط reverse_entry
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
  perform public.entry_require(o.id);
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
    -- 6ب: البيع الجديد بسطوره زي ما اتباع بالظبط. القديم (قبل 0060) زي الأول
    select jsonb_agg(jsonb_build_object('item', sl.item_id, 'qty', sl.qty, 'price', sl.price) order by sl.seq) into ls
    from public.sale_lines sl where sl.entry_id = o.id and sl.deleted_at is null;
    if ls is null then
    select jsonb_agg(jsonb_build_object('item', x.item_id, 'qty', x.q,
             'price', case when x.n = 1 then rev / x.q else coalesce(i.sale_price, 0) end) order by x.first)
      into ls
    from (select m.item_id, -sum(m.qty) q, count(*) over () n, min(m.created_at) first from public.stock_moves m where m.entry_id = o.id group by m.item_id) x
    join public.items i on i.id = x.item_id;
    end if;
    res := res || jsonb_build_object('customer', cust, 'cashbox', cash_in, 'lines', coalesce(ls, '[]'::jsonb));
  end if;
  return res;
end $$;

-- soft_delete: (src: 0046_master.sql) + الجهاز في فرع الموظف بس
create or replace function public.soft_delete(p_kind text, p_id uuid, p_reason text default null) returns void
language plpgsql security definer set search_path = public as $$
declare s uuid := public.current_shop_id(); before jsonb; tbl text;
begin
  if public.current_app_role() is null or not public.can_correct() then raise exception 'E_FORBIDDEN'; end if;
  -- C3: كلمة السر الرئيسية (لو صاحب المحل حددها)
  perform public.master_require();
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
    if public.current_app_role() <> 'owner' and not public.can_branch((before ->> 'branch_id')::uuid) then raise exception 'E_FORBIDDEN'; end if;
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
