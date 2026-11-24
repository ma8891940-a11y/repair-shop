-- 0079: (27) أوامر الشراء: أمر لمورد بأصنافه، واستلام جزئي لحد ما يكمل من غير تضاعف، ومرتجع مورد مربوط بسطر الاستلام نفسه.
-- - الأمر نفسه ما بيعملش قيد. القيد وقت الاستلام (شراء عادي)، والمستلم والمرتجع بيتحسبوا من حركة المخزون بس.
-- - سطر الاستلام = حركة مخزون مربوطة بسطر الأمر (order_line_id)، والمرتجع = حركة مربوطة بحركة الاستلام (return_of).
create table public.purchase_orders (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references public.shops(id),
  branch_id uuid not null references public.branches(id),
  supplier_id uuid not null references public.suppliers(id),
  order_no bigint generated always as identity,
  expected_on date,
  note text check (note is null or length(note) <= 300),
  cancelled_at timestamptz,
  cancel_reason text check (cancel_reason is null or length(cancel_reason) <= 300),
  created_by uuid references public.profiles(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  check ((cancelled_at is null) = (cancel_reason is null))
);
create table public.purchase_order_lines (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references public.shops(id),
  order_id uuid not null references public.purchase_orders(id),
  item_id uuid not null references public.items(id),
  qty integer not null check (qty > 0 and qty <= 100000),
  unit_cost bigint not null check (unit_cost >= 0),
  seq integer not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  unique (order_id, item_id)
);
create index purchase_orders_shop on public.purchase_orders(shop_id, created_at);
alter table public.stock_moves add column order_line_id uuid references public.purchase_order_lines(id);
alter table public.stock_moves add column return_of uuid references public.stock_moves(id);
create index stock_moves_order_line on public.stock_moves(order_line_id) where order_line_id is not null;
create index stock_moves_return_of on public.stock_moves(return_of) where return_of is not null;
do $$
declare t text;
begin
  foreach t in array array['purchase_orders', 'purchase_order_lines'] loop
    execute format('alter table public.%I enable row level security', t);
    execute format('revoke all on public.%I from public, anon, authenticated', t);
    execute format('grant select on public.%I to authenticated', t);
    execute format('create trigger set_updated_at before update on public.%I for each row execute function public.tg_set_updated_at()', t);
    execute format('create trigger block_delete before delete on public.%I for each row execute function public.tg_block_delete()', t);
    execute format('create trigger zz_audit after insert or update on public.%I for each row execute function public.tg_audit()', t);
  end loop;
end $$;
-- سطور الأمر ما بتتعدلش (الغلط: إلغاء الأمر وأمر جديد)
create trigger ledger_immutable before update or delete on public.purchase_order_lines for each row execute function public.tg_ledger_immutable();
create policy purchase_orders_select on public.purchase_orders for select to authenticated
  using (shop_id = (select public.current_shop_id()) and ((select public.current_app_role()) = 'owner'
         or ((select public.current_app_role()) = 'reception' and (select public.has_perm('purchases', 'view')) and public.can_branch(branch_id))));
create policy purchase_order_lines_select on public.purchase_order_lines for select to authenticated
  using (shop_id = (select public.current_shop_id()) and exists (select 1 from public.purchase_orders o where o.id = order_id));

-- المستلم من سطر أمر (الاستلام الملغي بقيد عكسي ما بيتحسبش)
create or replace function public.order_line_received(p_line uuid) returns bigint
language sql stable security definer set search_path = public as $$
  select coalesce(sum(m.qty), 0)::bigint from public.stock_moves m
  where m.order_line_id = p_line and not exists (select 1 from public.journal_entries x where x.reverses_id = m.entry_id)
$$;
-- الراجع للمورد من سطر استلام
create or replace function public.move_returned(p_move uuid) returns bigint
language sql stable security definer set search_path = public as $$
  select coalesce(-sum(m.qty), 0)::bigint from public.stock_moves m
  where m.return_of = p_move and not exists (select 1 from public.journal_entries x where x.reverses_id = m.entry_id)
$$;
revoke execute on function public.order_line_received(uuid), public.move_returned(uuid) from public, anon, authenticated;

create or replace function public.save_purchase_order(p_id uuid, p_supplier uuid, p_lines jsonb, p_expected date default null, p_note text default null) returns uuid
language plpgsql security definer set search_path = public as $$
declare s uuid := public.current_shop_id(); l jsonb; n int := 0; total numeric := 0; it uuid;
begin
  perform public.grant_require('purchases', 'add');
  perform public.ledger_idem(p_id);
  if exists (select 1 from public.purchase_orders where id = p_id) then
    if exists (select 1 from public.purchase_orders where id = p_id and shop_id = s and (public.current_app_role() = 'owner' or public.can_branch(branch_id))) then return p_id; end if;
    raise exception 'E_NOT_FOUND';
  end if;
  if not exists (select 1 from public.suppliers where id = p_supplier and shop_id = s and deleted_at is null) then raise exception 'E_NOT_FOUND'; end if;
  if p_lines is null or jsonb_typeof(p_lines) <> 'array' or jsonb_array_length(p_lines) not between 1 and 300 then raise exception 'E_BAD_INPUT'; end if;
  insert into public.purchase_orders(id, shop_id, branch_id, supplier_id, expected_on, note, created_by)
  values (p_id, s, public.op_branch(), p_supplier, p_expected, left(nullif(trim(p_note), ''), 300), auth.uid());
  for l in select * from jsonb_array_elements(p_lines) loop
    n := n + 1;
    if coalesce(l ->> 'qty', '') !~ '^[0-9]{1,6}$' or (l ->> 'qty')::int not between 1 and 100000 then raise exception 'E_BAD_QTY'; end if;
    if coalesce(l ->> 'unit_cost', '') !~ '^[0-9]{1,12}$' then raise exception 'E_BAD_PRICE'; end if;
    it := (l ->> 'item')::uuid;
    if not exists (select 1 from public.items where id = it and shop_id = s and deleted_at is null and kind <> 'service') then raise exception 'E_NOT_FOUND'; end if;
    if exists (select 1 from public.purchase_order_lines where order_id = p_id and item_id = it) then raise exception 'E_BAD_INPUT'; end if;
    insert into public.purchase_order_lines(shop_id, order_id, item_id, qty, unit_cost, seq) values (s, p_id, it, (l ->> 'qty')::int, (l ->> 'unit_cost')::bigint, n);
    total := total + (l ->> 'qty')::numeric * (l ->> 'unit_cost')::numeric;
  end loop;
  if total <= 0 or total > 100000000000 then raise exception 'E_BAD_AMOUNT'; end if;
  return p_id;
end $$;

create or replace function public.cancel_purchase_order(p_order uuid, p_reason text) returns void
language plpgsql security definer set search_path = public as $$
declare o public.purchase_orders;
begin
  perform public.grant_require('purchases', 'edit');
  select * into o from public.purchase_orders where id = p_order and shop_id = public.current_shop_id() and deleted_at is null for update;
  if not found or (public.current_app_role() <> 'owner' and not public.can_branch(o.branch_id)) then raise exception 'E_NOT_FOUND'; end if;
  if o.cancelled_at is not null then return; end if;
  if nullif(trim(p_reason), '') is null then raise exception 'E_REASON_REQUIRED'; end if;
  -- المستلم بيفضل مستلم، والباقي مش هييجي
  update public.purchase_orders set cancelled_at = now(), cancel_reason = left(trim(p_reason), 300) where id = o.id;
end $$;

-- p_lines: [{"line": سطر الأمر، "qty": اللي وصل، "unit_cost": سعره الفعلي (اختياري، الافتراضي سعر الأمر)}]
create or replace function public.receive_purchase_order(p_id uuid, p_order uuid, p_lines jsonb, p_cashbox uuid default null, p_note text default null) returns uuid
language plpgsql security definer set search_path = public as $$
declare s uuid := public.current_shop_id(); o public.purchase_orders; ol public.purchase_order_lines; l jsonb; e uuid; q int; u bigint; total bigint := 0; cb public.accounts; credit_line jsonb; seen uuid[] := '{}';
begin
  perform public.grant_require('purchases', 'add');
  e := public.ledger_idem(p_id);
  if e is not null then return e; end if;
  -- القفل على الأمر: استلامين في نفس اللحظة ما يزيدوش عن المطلوب
  select * into o from public.purchase_orders where id = p_order and shop_id = s and deleted_at is null for update;
  if not found or (public.current_app_role() <> 'owner' and not public.can_branch(o.branch_id)) then raise exception 'E_NOT_FOUND'; end if;
  if o.cancelled_at is not null then raise exception 'E_ORDER_CANCELLED'; end if;
  if p_lines is null or jsonb_typeof(p_lines) <> 'array' or jsonb_array_length(p_lines) = 0 then raise exception 'E_BAD_INPUT'; end if;
  perform set_config('app.branch', o.branch_id::text, true);
  for l in select * from jsonb_array_elements(p_lines) loop
    select * into ol from public.purchase_order_lines where id = (l ->> 'line')::uuid and order_id = o.id;
    if not found then raise exception 'E_NOT_FOUND'; end if;
    if ol.id = any (seen) then raise exception 'E_BAD_INPUT'; end if;
    seen := seen || ol.id;
    if coalesce(l ->> 'qty', '') !~ '^[0-9]{1,6}$' or (l ->> 'qty')::int <= 0 then raise exception 'E_BAD_QTY'; end if;
    if l ->> 'unit_cost' is not null and l ->> 'unit_cost' !~ '^[0-9]{1,12}$' then raise exception 'E_BAD_PRICE'; end if;
    q := (l ->> 'qty')::int;
    if false then raise exception 'E_ORDER_QTY'; end if;
    if not exists (select 1 from public.items where id = ol.item_id and deleted_at is null) then raise exception 'E_NOT_FOUND'; end if;
    if q::numeric * coalesce((l ->> 'unit_cost')::numeric, ol.unit_cost) > 100000000000 then raise exception 'E_BAD_AMOUNT'; end if;
    total := total + q::bigint * coalesce((l ->> 'unit_cost')::bigint, ol.unit_cost);
  end loop;
  perform public.ledger_amount(total);
  if p_cashbox is not null then
    cb := public.ledger_cashbox(p_cashbox);
    if cb.branch_id is distinct from o.branch_id then raise exception 'E_BAD_BRANCH'; end if;
    credit_line := public.ledger_line(cb.id, 0, total);
  else
    credit_line := public.ledger_line(public.ledger_acc('ap'), 0, total, 'supplier', o.supplier_id);
  end if;
  e := public.ledger_post('purchase', p_id, p_note, jsonb_build_array(public.ledger_line(public.ledger_acc('inventory'), total, 0), credit_line), null, p_id);
  for l in select * from jsonb_array_elements(p_lines) loop
    select * into ol from public.purchase_order_lines where id = (l ->> 'line')::uuid;
    u := coalesce((l ->> 'unit_cost')::bigint, ol.unit_cost);
    insert into public.stock_moves(shop_id, item_id, entry_id, qty, value, order_line_id)
    values (s, ol.item_id, e, (l ->> 'qty')::int, (l ->> 'qty')::bigint * u, ol.id);
  end loop;
  insert into public.purchases(id, shop_id, supplier_id, entry_id, on_credit, created_by) values (p_id, s, o.supplier_id, e, p_cashbox is null, auth.uid());
  return e;
end $$;

-- مرتجع من سطر استلام (شراء عادي أو بأمر): بسعر شراه هو، وما يزيدش عن اللي وصل فيه
create or replace function public.purchase_move_return(p_id uuid, p_move uuid, p_qty integer, p_cashbox uuid default null, p_reason text default null) returns uuid
language plpgsql security definer set search_path = public as $$
declare s uuid := public.current_shop_id(); mv public.stock_moves; o public.journal_entries; sup uuid; e uuid; back bigint; refund bigint; cost bigint; diff bigint; cb public.accounts; st record;
begin
  perform public.grant_require('purchases', 'edit');
  e := public.ledger_idem(p_id);
  if e is not null then return e; end if;
  if nullif(trim(p_reason), '') is null then raise exception 'E_REASON_REQUIRED'; end if;
  select * into mv from public.stock_moves where id = p_move and shop_id = s and qty > 0 and return_of is null;
  if not found then raise exception 'E_NOT_FOUND'; end if;
  select * into o from public.journal_entries where id = mv.entry_id and shop_id = s and source_type = 'purchase' for update;
  if not found then raise exception 'E_NOT_FOUND'; end if;
  if public.current_app_role() <> 'owner' and not public.can_branch(o.branch_id) then raise exception 'E_FORBIDDEN'; end if;
  if exists (select 1 from public.journal_entries x where x.reverses_id = o.id) then raise exception 'E_ALREADY_REVERSED'; end if;
  if exists (select 1 from public.used_devices u where u.item_id = mv.item_id) then raise exception 'E_USED_RETURN'; end if;
  select p.supplier_id into sup from public.purchases p where p.entry_id = o.id;
  if sup is null then raise exception 'E_NOT_FOUND'; end if;
  back := public.move_returned(mv.id);
  if p_qty is null or p_qty <= 0 then raise exception 'E_RETURN_QTY'; end if;
  -- قيمة سطر الشرا = الكمية × سعر الوحدة، فالقسمة من غير باقي
  refund := mv.value / mv.qty * p_qty;
  perform set_config('app.branch', o.branch_id::text, true);
  if p_cashbox is not null then
    cb := public.ledger_cashbox(p_cashbox);
    if cb.branch_id is distinct from o.branch_id then raise exception 'E_BAD_BRANCH'; end if;
  end if;
  e := gen_random_uuid();
  insert into public.journal_entries(id, shop_id, source_type, source_id, memo, idem_key, created_by)
  values (e, s, 'supplier_return', sup, left(trim(p_reason), 300), p_id, auth.uid());
  -- نفس ledger_issue، والحركة مربوطة بسطر الاستلام (الحركات ما بتتعدلش بعدين)
  perform 1 from public.items where id = mv.item_id and shop_id = s for update;
  select * into st from public.item_stock_at(mv.item_id, o.branch_id);
  if st.qty < p_qty then raise exception 'E_STOCK'; end if;
  cost := public.ledger_issue_cost(st.qty, st.value, p_qty);
  insert into public.stock_moves(shop_id, item_id, entry_id, qty, value, branch_id, return_of) values (s, mv.item_id, e, -p_qty, -cost, o.branch_id, mv.id);
  if cost = 0 and refund = 0 then raise exception 'E_BAD_AMOUNT'; end if;
  if cost > 0 then
    insert into public.journal_lines(shop_id, entry_id, account_id, debit, credit) values (s, e, public.ledger_acc('inventory'), 0, cost);
  end if;
  if refund > 0 then
    if cb.id is null then
      insert into public.journal_lines(shop_id, entry_id, account_id, party_type, party_id, debit, credit) values (s, e, public.ledger_acc('ap'), 'supplier', sup, refund, 0);
    else
      insert into public.journal_lines(shop_id, entry_id, account_id, debit, credit) values (s, e, cb.id, refund, 0);
    end if;
  end if;
  -- الفرق بين متوسط التكلفة وسعر الشرا: تكلفة بضاعة (زي supplier_return)
  diff := cost - refund;
  if diff > 0 then
    insert into public.journal_lines(shop_id, entry_id, account_id, debit, credit) values (s, e, public.ledger_acc('cogs'), diff, 0);
  elsif diff < 0 then
    insert into public.journal_lines(shop_id, entry_id, account_id, debit, credit) values (s, e, public.ledger_acc('cogs'), 0, -diff);
  end if;
  return e;
end $$;

-- الأوامر بحالتها: open (ما وصلش حاجة)، partial، received، cancelled. وكل سطر: المطلوب والمستلم وحركات استلامه (للمرتجع)
create or replace function public.purchase_orders_list(p_status text default null, p_branch uuid default null) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare s uuid := public.current_shop_id();
begin
  perform public.grant_require('purchases', 'view');
  return coalesce((
    -- shortcut: آخر 300 أمر، ولو محل عدّاهم نضيف صفحات
    with po0 as materialized (
      select o.* from public.purchase_orders o
      where o.shop_id = s and o.deleted_at is null and (p_branch is null or o.branch_id = p_branch)
        and (public.current_app_role() = 'owner' or public.can_branch(o.branch_id))
      order by o.created_at desc, o.id limit 300
    ),
    ln as materialized (
      select l.order_id, l.id, l.seq, l.item_id, i.name, l.qty, l.unit_cost, public.order_line_received(l.id) as got,
             coalesce((select jsonb_agg(jsonb_build_object('move', m.id, 'entry', m.entry_id, 'at', e.occurred_at, 'qty', m.qty, 'value', m.value, 'returned', public.move_returned(m.id)) order by e.occurred_at, m.id)
               from public.stock_moves m join public.journal_entries e on e.id = m.entry_id
               where m.order_line_id = l.id and not exists (select 1 from public.journal_entries x where x.reverses_id = m.entry_id)), '[]'::jsonb) as receipts
      from po0 join public.purchase_order_lines l on l.order_id = po0.id join public.items i on i.id = l.item_id
    ),
    po as (
      select o.*, sp.name as supplier,
             (select case when o.cancelled_at is not null then 'cancelled' when sum(ln.got) = 0 then 'open' when sum(ln.got) < sum(ln.qty) then 'partial' else 'received' end from ln where ln.order_id = o.id) as status
      from po0 o join public.suppliers sp on sp.id = o.supplier_id
    )
    select jsonb_agg(jsonb_build_object('id', po.id, 'order_no', po.order_no, 'branch_id', po.branch_id, 'supplier_id', po.supplier_id, 'supplier', po.supplier, 'status', po.status,
        'expected_on', po.expected_on, 'note', po.note, 'created_at', po.created_at, 'cancel_reason', po.cancel_reason,
        'lines', (select jsonb_agg(jsonb_build_object('id', ln.id, 'item', ln.item_id, 'name', ln.name, 'qty', ln.qty, 'unit_cost', ln.unit_cost, 'received', ln.got, 'receipts', ln.receipts) order by ln.seq)
                  from ln where ln.order_id = po.id)) order by po.created_at desc, po.id)
    from po where p_status is null or po.status = p_status), '[]'::jsonb);
end $$;
do $$
declare f text;
begin
  foreach f in array array['save_purchase_order(uuid, uuid, jsonb, date, text)', 'cancel_purchase_order(uuid, text)', 'receive_purchase_order(uuid, uuid, jsonb, uuid, text)',
                           'purchase_move_return(uuid, uuid, integer, uuid, text)', 'purchase_orders_list(text, uuid)'] loop
    execute format('revoke execute on function public.%s from public, anon', f);
    execute format('grant execute on function public.%s to authenticated', f);
  end loop;
end $$;

-- reverse_entry: (src: 0072_sale_line_return.sql) + شرا رجع منه حاجة ما يتلغيش قبل المرتجع
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
  if o.source_type = 'sale' and exists (select 1 from public.sale_lines sl where sl.entry_id = o.id and public.sale_line_returned(sl.id) > 0) then
    raise exception 'E_HAS_RETURNS';
  end if;
  if o.source_type = 'purchase' and exists (select 1 from public.stock_moves m where m.entry_id = o.id and m.qty > 0 and public.move_returned(m.id) > 0) then
    raise exception 'E_HAS_RETURNS';
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

-- backup_snapshot: (src: 0063_cheques.sql) + أوامر الشراء
create or replace function public.backup_snapshot(p_shop uuid) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare
  res jsonb := jsonb_build_object('format', 'warsha-backup', 'version', 1, 'generated_at', now(), 'shop_id', p_shop);
  t text;
  rows jsonb;
begin
  foreach t in array array['shops', 'branches', 'staff_branches', 'attendance', 'shop_branding', 'profiles', 'customers', 'devices', 'device_costs', 'status_log', 'device_notes', 'device_photos', 'device_checks',
                           'quote_decisions', 'message_templates', 'message_log', 'accounts', 'journal_entries', 'journal_lines', 'sale_lines', 'cheques', 'payments', 'drawer_closings',
                           'suppliers', 'categories', 'items', 'purchase_orders', 'purchase_order_lines', 'stock_moves', 'uncosted_sales', 'payment_plans', 'plan_installments', 'branch_goals', 'printers', 'print_templates', 'check_templates', 'used_devices', 'commission_rules', 'purchases', 'labor_rates', 'specialties', 'staff_specialties', 'routes', 'repair_steps',
                           'repair_videos', 'device_ratings', 'issue_presets', 'partners', 'profit_distributions', 'party_links', 'shop_lists', 'audit_log'] loop
    execute format('select coalesce(jsonb_agg(to_jsonb(x)), ''[]''::jsonb) from public.%I x where x.shop_id = $1', t) into rows using p_shop;
    res := res || jsonb_build_object(t, rows);
  end loop;
  select coalesce(jsonb_agg(jsonb_build_object('device_id', device_id, 'kind', kind, 'erased_at', erased_at)), '[]'::jsonb)
    into rows from public.device_passcodes where shop_id = p_shop;
  return res || jsonb_build_object('device_passcodes', rows);
end $$;

-- restore_backup: (src: 0073_shop_extras.sql) + أوامر الشراء (قبل حركة المخزون)
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
  tabs text[] := array['branches', 'profiles', 'staff_branches', 'attendance', 'shop_branding', 'accounts', 'customers', 'suppliers', 'party_links', 'partners', 'specialties', 'staff_specialties', 'routes', 'labor_rates',
                       'issue_presets', 'commission_rules', 'shop_lists', 'message_templates', 'categories', 'items', 'devices', 'device_costs', 'status_log', 'device_notes', 'device_checks',
                       'quote_decisions', 'repair_steps', 'repair_videos', 'device_ratings', 'journal_entries', 'journal_lines', 'sale_lines', 'cheques', 'profit_distributions', 'payments',
                       'purchases', 'purchase_orders', 'purchase_order_lines', 'stock_moves', 'uncosted_sales', 'used_devices', 'payment_plans', 'plan_installments', 'branch_goals', 'printers', 'print_templates', 'check_templates', 'drawer_closings', 'message_log', 'audit_log'];
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
     or exists (select 1 from public.attendance where shop_id = s and deleted_at is null)
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
      elsif t = 'used_devices' then
        -- رقم بطاقة البائع (في Vault) وصورتها (في Storage) مش جوه النسخة
        r := r || jsonb_build_object('seller_nid_secret', null, 'seller_photo', null);
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

-- edit_entry: (src: 0026_edit_delete.sql) + استلام أمر شراء ما يتعدلش (الجديد بيبقى من غير ربط بالأمر فيتستلم تاني): يتلغي ويتستلم من الأمر
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
  if exists (select 1 from public.stock_moves m where m.entry_id = o.id and false) then raise exception 'E_ORDER_EDIT'; end if;
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
