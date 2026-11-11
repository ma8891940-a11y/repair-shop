-- 0038: P المرحلة التانية: صاحب المحل يقدر يدي الموظف صلاحيات ما كانتش عنده قبل كده (من جدول الصلاحيات).
-- الأقسام اللي بقت تتفتح للموظف: المشتريات، والوضع المالي، والتقارير، والتحويل بين الخزن، والهالك والتحويل لفرع، والمصروفات، وسجل النشاط.
-- اللي بيفضل لصاحب المحل بس: الإعدادات، والمرتبات، والشركاء، والنسخ الاحتياطي، والأدوار، والفروع، والجرد الافتتاحي.
-- الأدوار المبنية على "فني" عمرها ما بتاخد حاجة من دول (الفني ما يشوفش أسعار ولا أرباح): الدوال بتقبل owner وreception بس.
-- ومحدش بيكسب صلاحية لوحده: دور "استقبال" (اللي الموظفين الحاليين عليه) بيتشال منه "المصروفات" اللي ما كانتش شغالة.

-- الموظف معاه كل فروع المحل؟ (التقارير على مستوى المحل كله بتحتاج كده)
create or replace function public.all_my_branches() returns boolean
language sql stable security definer set search_path = public as $$
  select public.current_app_role() = 'owner' or not exists (
    select 1 from public.branches b where b.shop_id = public.current_shop_id() and b.deleted_at is null and not (b.id = any (public.my_branch_ids())))
$$;
revoke execute on function public.all_my_branches() from public, anon;
grant execute on function public.all_my_branches() to authenticated;

-- صاحب المحل، أو موظف (مش فني) ليه الصلاحية في الجدول. p_wide: العملية على مستوى المحل كله ← لازم كل الفروع
create or replace function public.grant_require(p_section text, p_op text, p_wide boolean default false) returns void
language plpgsql stable security definer set search_path = public as $$
begin
  perform public.ledger_require(array['owner', 'reception']::public.app_role[]);
  perform public.perm_require(p_section, p_op);
  if p_wide and not public.all_my_branches() then raise exception 'E_FORBIDDEN'; end if;
end $$;
revoke execute on function public.grant_require(text, text, boolean) from public, anon, authenticated;

-- ---------- الأدوار الجاهزة ----------
create or replace function public.preset_perms(p text) returns jsonb
language sql immutable as $$
  select case p
    when 'reception' then '{"devices":["view","add","edit","amounts","export"],"intake":["view","add"],"customers":["view","add","edit","export"],"technicians":["view"],"inventory":["view","add","edit","export"],"sales":["view","add","edit","export"],"cashbox":["view","add"]}'::jsonb
    when 'branch_manager' then '{"devices":["view","add","edit","amounts","export"],"intake":["view","add"],"customers":["view","add","edit","export"],"technicians":["view"],"inventory":["view","add","edit","delete","amounts","export"],"sales":["view","add","edit","export"],"purchases":["view","add","edit"],"cashbox":["view","add","edit"],"expenses":["view","add"],"finance":["view","amounts"],"reports":["view","export"],"audit":["view"]}'::jsonb
    when 'technician' then '{"devices":["view","edit"],"technicians":["view"],"inventory":["view"]}'::jsonb
    when 'cashier' then '{"customers":["view","add"],"inventory":["view","export"],"sales":["view","add","edit","export"],"cashbox":["view","add"]}'::jsonb
    when 'accountant' then '{"cashbox":["view"],"expenses":["view","add"],"inventory":["view","amounts","export"],"sales":["view","export"],"customers":["view"],"purchases":["view"],"finance":["view","amounts","export"],"reports":["view","export"],"audit":["view"]}'::jsonb
    else '{}'::jsonb end
$$;

-- دور "استقبال" الحالي: "المصروفات" كانت متعلّمة بس ما كانتش شغالة ← بتتشال عشان محدش يكسبها لوحده
update public.roles set perms = perms - 'expenses' where preset = 'reception' and deleted_at is null;
-- مدير الفرع والمحاسب: لو لسه زي ما اتعملوا (ما اتعدّلوش)، بياخدوا الصلاحيات الجديدة الجاهزة
update public.roles set perms = public.preset_perms(preset)
where deleted_at is null and preset = 'branch_manager'
  and perms = '{"devices":["view","add","edit","amounts","export"],"intake":["view","add"],"customers":["view","add","edit","export"],"technicians":["view"],"inventory":["view","add","edit","export"],"sales":["view","add","edit","export"],"cashbox":["view","add"],"expenses":["view","add"]}'::jsonb;
update public.roles set perms = public.preset_perms(preset)
where deleted_at is null and preset = 'accountant'
  and perms = '{"cashbox":["view"],"expenses":["view","add"],"inventory":["view","export"],"sales":["view","export"],"customers":["view"]}'::jsonb;
-- استثناءات "مسموح" لصلاحيات ما كانتش شغالة: بتتشال (عشان محدش يكسب حاجة لوحده)
update public.staff_overrides set deleted_at = now()
where deleted_at is null and allow
  and ((section in ('purchases', 'finance', 'reports', 'expenses', 'audit')) or (section = 'inventory' and op in ('delete', 'amounts')) or (section = 'cashbox' and op = 'edit'));

-- record_purchase: (src: 0012_spec_completion.sql) + الصلاحية من الجدول
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
  perform public.grant_require('purchases', 'add');
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

-- pay_supplier: (src: 0008_ledger.sql) + الصلاحية من الجدول
create or replace function public.pay_supplier(p_id uuid, p_supplier uuid, p_cashbox uuid, p_amount bigint, p_note text default null)
returns uuid
language plpgsql security definer set search_path = public as $$
declare cb public.accounts; e uuid;
begin
  perform public.grant_require('purchases', 'add');
  e := public.ledger_idem(p_id);
  if e is not null then return e; end if;
  perform public.ledger_amount(p_amount);
  cb := public.ledger_cashbox(p_cashbox);
  if not exists (select 1 from public.suppliers where id = p_supplier and shop_id = cb.shop_id and deleted_at is null) then raise exception 'E_NOT_FOUND'; end if;
  return public.ledger_post('supplier_payment', p_id, p_note, jsonb_build_array(
    public.ledger_line(public.ledger_acc('ap'), p_amount, 0, 'supplier', p_supplier),
    public.ledger_line(cb.id, 0, p_amount)), null, p_id);
end $$;

-- supplier_return: (src: 0027_inventory.sql) + الصلاحية من الجدول
create or replace function public.supplier_return(p_id uuid, p_supplier uuid, p_item uuid, p_qty integer, p_refund bigint, p_cashbox uuid default null, p_reason text default null) returns uuid
language plpgsql security definer set search_path = public as $$
declare s uuid := public.current_shop_id(); e uuid; cost bigint; diff bigint; cb uuid;
begin
  perform public.grant_require('purchases', 'edit');
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

-- item_suppliers: (src: 0012_spec_completion.sql) + الصلاحية من الجدول
create or replace function public.item_suppliers(p_item uuid)
returns table(supplier_id uuid, supplier text, last_cost bigint, min_cost bigint, last_at timestamptz, total_qty bigint)
language plpgsql stable security definer set search_path = public as $$
#variable_conflict use_column
begin
  perform public.grant_require('purchases', 'view');
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

-- write_off: (src: 0027_inventory.sql) + الصلاحية من الجدول
create or replace function public.write_off(p_id uuid, p_item uuid, p_qty integer, p_reason text) returns uuid
language plpgsql security definer set search_path = public as $$
declare s uuid := public.current_shop_id(); e uuid; cost bigint;
begin
  perform public.grant_require('inventory', 'delete');
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

-- transfer_stock: (src: 0034_branches.sql) + الصلاحية من الجدول
create or replace function public.transfer_stock(p_id uuid, p_item uuid, p_qty integer, p_from uuid, p_to uuid, p_note text default null) returns uuid
language plpgsql security definer set search_path = public as $$
declare s uuid := public.current_shop_id(); e uuid; cost bigint; inv uuid := public.ledger_acc('inventory');
begin
  perform public.grant_require('inventory', 'edit');
  perform public.grant_require('inventory', 'amounts');
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

-- item_moves: (src: 0027_inventory.sql) + الصلاحية من الجدول
create or replace function public.item_moves(p_item uuid) returns table(entry_id uuid, entry_no bigint, at timestamptz, source_type text, memo text, qty bigint, value bigint, balance_qty bigint, balance_value bigint, device_id uuid, order_no text, by text, reversed boolean)
language plpgsql stable security definer set search_path = public as $$
begin
  perform public.grant_require('inventory', 'amounts');
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

-- items_sold30: (src: 0033_assistant.sql) + الصلاحية من الجدول
create or replace function public.items_sold30() returns table(item_id uuid, qty bigint)
language plpgsql stable security definer set search_path = public as $$
begin
  perform public.grant_require('reports', 'view', true);
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

-- inventory_summary: (src: 0037_item_details.sql) + الصلاحية من الجدول
create or replace function public.inventory_summary(p_from timestamptz, p_to timestamptz, p_branch uuid default null, p_filter jsonb default null) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare s uuid := public.current_shop_id(); res jsonb;
  -- S6: فلتر الأصناف (النوع والماركة والموديل والجودة) على أكتر الأصناف مبيعًا وقيمة المخزون بتاعتها
  fk text := nullif(trim(p_filter ->> 'item_type'), ''); fb text := nullif(trim(p_filter ->> 'brand'), '');
  fm text := nullif(trim(p_filter ->> 'model'), ''); fq text := nullif(trim(p_filter ->> 'quality'), '');
  has_f boolean := coalesce(fk, fb, fm, fq) is not null;
begin
  perform public.grant_require('reports', 'view');
  -- الموظف: فروعه بس (لو مش معاه كل الفروع)
  if not public.all_my_branches() and (p_branch is null or not public.can_branch(p_branch)) then p_branch := public.op_branch(); end if;
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
        where en.t = 'sale' and (fk is null or i.item_type = fk) and (fb is null or i.brand = fb) and (fm is null or i.model = fm) and (fq is null or i.quality = fq) group by i.id, i.name order by -sum(m.qty) desc limit case when has_f then 50 else 10 end) x), '[]'::jsonb),
    'filtered', case when has_f then (select jsonb_build_object('stock_value', coalesce(sum(m.value), 0), 'stock_qty', coalesce(sum(m.qty), 0), 'items', count(distinct i.id))
        from public.items i left join public.stock_moves m on m.item_id = i.id and (p_branch is null or m.branch_id = p_branch)
        where i.shop_id = s and i.deleted_at is null and (fk is null or i.item_type = fk) and (fb is null or i.brand = fb) and (fm is null or i.model = fm) and (fq is null or i.quality = fq)) end
  ) into res;
  res := res || jsonb_build_object('profit', (res->>'sales')::bigint - (res->>'sales_cost')::bigint - (res->>'wastage')::bigint - (res->>'return_diff')::bigint - (res->>'cost_adjust')::bigint);
  return res;
end $$;

-- tech_report: (src: 0017_growth.sql) + الصلاحية من الجدول
create or replace function public.tech_report(p_from timestamptz, p_to timestamptz)
returns table(tech_id uuid, name text, devices integer, steps integer, avg_minutes integer, returns integer, return_rate integer, revenue bigint, rating numeric, ratings integer, points integer)
language plpgsql stable security definer set search_path = public as $$
#variable_conflict use_column
declare s uuid := public.current_shop_id();
begin
  perform public.grant_require('reports', 'view', true);
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

-- issue_report: (src: 0034_branches.sql) + الصلاحية من الجدول
create or replace function public.issue_report(p_from timestamptz, p_to timestamptz, p_branch uuid default null)
returns table(route_id uuid, code text, name text, devices integer, revenue bigint, parts bigint, profit bigint)
language plpgsql stable security definer set search_path = public as $$
#variable_conflict use_column
begin
  perform public.grant_require('reports', 'view');
  -- الموظف: فروعه بس (لو مش معاه كل الفروع)
  if not public.all_my_branches() and (p_branch is null or not public.can_branch(p_branch)) then p_branch := public.op_branch(); end if;
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

-- financial_position: (src: 0034_branches.sql) + الصلاحية من الجدول
create or replace function public.financial_position(p_from timestamptz, p_to timestamptz, p_branch uuid default null) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare
  s uuid := public.current_shop_id();
  res jsonb;
begin
  perform public.grant_require('finance', 'view');
  -- الموظف: فروعه بس (لو مش معاه كل الفروع)
  if not public.all_my_branches() and (p_branch is null or not public.can_branch(p_branch)) then p_branch := public.op_branch(); end if;
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

-- pl_breakdown: (src: 0034_branches.sql) + الصلاحية من الجدول
create or replace function public.pl_breakdown(p_from timestamptz, p_to timestamptz, p_branch uuid default null)
returns table(account_id uuid, code text, name text, type public.account_type, amount bigint)
language plpgsql stable security definer set search_path = public as $$
begin
  perform public.grant_require('finance', 'view');
  -- الموظف: فروعه بس (لو مش معاه كل الفروع)
  if not public.all_my_branches() and (p_branch is null or not public.can_branch(p_branch)) then p_branch := public.op_branch(); end if;
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

-- cashbox_daily: (src: 0011_finance_drilldown.sql) + الصلاحية من الجدول
create or replace function public.cashbox_daily(p_from timestamptz, p_to timestamptz)
returns table(cashbox uuid, day date, net bigint)
language plpgsql stable security definer set search_path = public as $$
begin
  perform public.grant_require('finance', 'view', true);
  return query
  select l.account_id, (date_trunc('day', e.occurred_at at time zone 'Africa/Cairo'))::date, sum(l.debit - l.credit)::bigint
  from public.journal_lines l
  join public.accounts a on a.id = l.account_id and a.kind = 'cash'
  join public.journal_entries e on e.id = l.entry_id
  where l.shop_id = public.current_shop_id() and e.occurred_at >= p_from and e.occurred_at < p_to
  group by 1, 2
  order by 2;
end $$;

-- party_balances: (src: 0012_spec_completion.sql) + الصلاحية من الجدول
create or replace function public.party_balances(p_kind text)
returns table(party_type text, party_id uuid, name text, account text, balance bigint, oldest timestamptz)
language plpgsql stable security definer set search_path = public as $$
#variable_conflict use_column
declare s uuid := public.current_shop_id();
begin
  perform public.grant_require('finance', 'view');
  if p_kind = 'employees' and public.current_app_role() <> 'owner' then raise exception 'E_FORBIDDEN'; end if;
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

-- statement: (src: 0030_party_links.sql) + الصلاحية من الجدول
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
  perform public.grant_require('finance', 'view');
  -- المرتبات والشركاء لصاحب المحل بس، والخزنة لازم تكون في فروع الموظف
  if public.current_app_role() <> 'owner' and (p_kind in ('employee', 'partner')
     or (p_kind = 'cashbox' and not exists (select 1 from public.accounts a where a.id = p_id and public.can_branch(a.branch_id)))) then raise exception 'E_FORBIDDEN'; end if;
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

-- transfer_cash: (src: 0008_ledger.sql) + الصلاحية من الجدول
create or replace function public.transfer_cash(p_id uuid, p_from uuid, p_to uuid, p_amount bigint, p_note text default null)
returns uuid
language plpgsql security definer set search_path = public as $$
declare a public.accounts; b public.accounts; e uuid;
begin
  perform public.grant_require('cashbox', 'edit');
  e := public.ledger_idem(p_id);
  if e is not null then return e; end if;
  perform public.ledger_amount(p_amount);
  a := public.ledger_cashbox(p_from);
  b := public.ledger_cashbox(p_to);
  if a.id = b.id then raise exception 'E_SAME_CASHBOX'; end if;
  if public.ledger_balance(a.id) < p_amount then raise exception 'E_INSUFFICIENT'; end if;
  return public.ledger_post('transfer', p_id, p_note, jsonb_build_array(public.ledger_line(b.id, p_amount, 0), public.ledger_line(a.id, 0, p_amount)), null, p_id);
end $$;

-- record_expense: (src: 0036_roles.sql) + الصلاحية من الجدول
create or replace function public.record_expense(p_id uuid, p_account uuid, p_cashbox uuid, p_amount bigint, p_note text default null)
returns uuid
language plpgsql security definer set search_path = public as $$
declare cb public.accounts; e uuid;
begin
  perform public.grant_require('expenses', 'add');
  e := public.ledger_idem(p_id);
  if e is not null then return e; end if;
  perform public.ledger_amount(p_amount);
  cb := public.ledger_cashbox(p_cashbox);
  if not exists (select 1 from public.accounts where id = p_account and shop_id = cb.shop_id and kind = 'expense' and active and deleted_at is null) then raise exception 'E_BAD_ACCOUNT'; end if;
  return public.ledger_post('expense', p_id, p_note, jsonb_build_array(public.ledger_line(p_account, p_amount, 0), public.ledger_line(cb.id, 0, p_amount)), null, p_id);
end $$;

-- items_stock: (src: 0037_item_details.sql) + المبالغ بالصلاحية
create or replace function public.items_stock(p_all boolean default false) returns table(id uuid, kind text, name text, sku text, sale_price integer, qty bigint, avg_cost bigint, value bigint, min_qty integer, supplier_id uuid, short boolean, category text, barcode text, image_path text, brand text, item_type text, model text, quality text, color text, unsettled bigint)
language plpgsql stable security definer set search_path = public as $$
declare r public.app_role := public.current_app_role(); b uuid := public.op_branch(); everywhere boolean;
  amt boolean := r = 'owner' or (r = 'reception' and public.has_perm('inventory', 'amounts'));
begin
  if r is null then raise exception 'E_FORBIDDEN'; end if;
  if not (public.has_perm('inventory', 'view') or public.has_perm('sales', 'view')) then raise exception 'E_FORBIDDEN'; end if;
  everywhere := p_all and r = 'owner';
  return query
  select i.id, i.kind, i.name, i.sku,
         case when r = 'technician' then null else i.sale_price end,
         coalesce(st.q, 0)::bigint,
         case when amt and coalesce(st.q, 0) > 0 then (st.v / st.q)::bigint end,
         case when amt then coalesce(st.v, 0)::bigint end,
         i.min_qty, case when amt then i.supplier_id end,
         i.min_qty > 0 and coalesce(st.q, 0) <= i.min_qty,
         i.category, i.barcode, i.image_path, i.brand, i.item_type, i.model, i.quality, i.color,
         (select coalesce(sum(u.qty - u.settled), 0)::bigint from public.uncosted_sales u where u.item_id = i.id and u.deleted_at is null and u.settled < u.qty
            and (everywhere or u.branch_id = b) and not exists (select 1 from public.journal_entries rv where rv.reverses_id = u.entry_id))
  from public.items i
  left join (select m.item_id, sum(m.qty) as q, sum(m.value) as v from public.stock_moves m where everywhere or m.branch_id = b group by m.item_id) st on st.item_id = i.id
  where i.shop_id = public.current_shop_id() and i.deleted_at is null
  order by i.kind, i.name;
end $$;

-- ---------- القراية (RLS): للموظف (مش الفني) اللي معاه الصلاحية، وفي فروعه بس ----------
create policy staff_entries_select on public.journal_entries for select to authenticated
  using (shop_id = public.current_shop_id() and public.current_app_role() = 'reception' and (select public.has_perm('finance', 'view')) and public.can_branch(branch_id));
create policy staff_lines_select on public.journal_lines for select to authenticated
  using (shop_id = public.current_shop_id() and public.current_app_role() = 'reception' and (select public.has_perm('finance', 'view'))
         and exists (select 1 from public.journal_entries e where e.id = entry_id and public.can_branch(e.branch_id)));
create policy staff_accounts_select on public.accounts for select to authenticated
  using (shop_id = public.current_shop_id() and public.current_app_role() = 'reception' and (select public.has_perm('finance', 'view'))
         and (kind <> 'cash' or public.can_branch(branch_id)) and kind not in ('advances', 'salaries', 'partner_capital', 'partner_current'));
create policy staff_moves_select on public.stock_moves for select to authenticated
  using (shop_id = public.current_shop_id() and public.current_app_role() = 'reception' and (select public.has_perm('inventory', 'amounts')) and public.can_branch(branch_id));
create policy staff_suppliers_select on public.suppliers for select to authenticated
  using (shop_id = public.current_shop_id() and public.current_app_role() = 'reception' and (select public.has_perm('purchases', 'view')));
create policy staff_suppliers_insert on public.suppliers for insert to authenticated
  with check (shop_id = public.current_shop_id() and public.current_app_role() = 'reception' and (select public.has_perm('purchases', 'add')));
create policy staff_suppliers_update on public.suppliers for update to authenticated
  using (shop_id = public.current_shop_id() and public.current_app_role() = 'reception' and (select public.has_perm('purchases', 'edit')));
create policy staff_audit_select on public.audit_log for select to authenticated
  using (shop_id = public.current_shop_id() and public.current_app_role() = 'reception' and (select public.has_perm('audit', 'view')));
