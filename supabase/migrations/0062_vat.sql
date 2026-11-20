-- ============================================================
-- 0062: R5 ضريبة القيمة المضافة الاختيارية (لكل محل مسجّل)
-- - مقفولة افتراضيًا. صاحب المحل بيفتحها من الإعدادات (shops.extras.vat: enabled، rate_bp، reg_no).
-- - السعر شامل الضريبة دايمًا: العميل بيدفع نفس المبلغ، والقيد بيفصل "ضريبة مستحقة" (التزام) عن الإيراد.
--   الضريبة = round(المبلغ × النسبة ÷ (1 + النسبة)) بالقروش، لكل نوع إيراد لوحده (قطع، إكسسوار، خدمة/صيانة).
-- - النسبة بتتاخد ساعة القيد وبتتخزن في القيد نفسه، فتغييرها بعدين ما بيغيّرش القديم.
-- - البيع والتسليم بس. الإلغاء بقيد عكسي (reverse_entry) بيرجّع الضريبة لوحده.
-- - سداد الضريبة للمصلحة: pay_vat (صاحب المحل بس)، وتقرير الضريبة للفترة: vat_report.
-- - الفاتورة الإلكترونية والإيصال الإلكتروني لسه ممنوعين (CLAUDE.md)، ده تجهيز بس.
-- ============================================================

-- ---------- حساب "ضريبة القيمة المضافة المستحقة" ----------
alter table public.accounts drop constraint if exists accounts_kind_check;
alter table public.accounts add constraint accounts_kind_check check (kind = any (array[
  'cash', 'receivable', 'advances', 'inventory', 'payable', 'salaries', 'capital', 'drawings', 'revenue', 'cogs', 'expense', 'shortage', 'overage',
  'partner_capital', 'partner_current', 'retained', 'fixed_asset', 'tax']));

alter table public.journal_entries drop constraint if exists journal_entries_source_type_check;
alter table public.journal_entries add constraint journal_entries_source_type_check check (source_type = any (array[
  'payment', 'delivery', 'purchase', 'supplier_payment', 'part_use', 'sale', 'expense', 'salary', 'salary_payment', 'advance', 'advance_settle',
  'capital', 'drawing', 'transfer', 'drawer_close', 'reversal', 'cost_adjust', 'write_off', 'supplier_return', 'sale_return', 'opening',
  'partner_capital', 'partner_withdrawal', 'profit_distribution', 'netting', 'stock_transfer', 'commission', 'bonus', 'penalty', 'vat_payment']));

-- ---------- النسبة والحساب ----------
-- النسبة بالـ basis points (1400 = 14%). مقفولة أو قيمة مش سليمة = 0. أقصى حاجة 30%
create or replace function public.vat_bp(p_shop uuid) returns integer
language sql stable security definer set search_path = public as $$
  select case
    -- true كـ boolean بس (مش نص)، زي readVat في الواجهة
    when (sh.extras -> 'vat' -> 'enabled') is distinct from 'true'::jsonb then 0
    when coalesce(sh.extras -> 'vat' ->> 'rate_bp', '') !~ '^[0-9]{1,5}$' then 1400
    else least((sh.extras -> 'vat' ->> 'rate_bp')::integer, 3000)
  end
  from public.shops sh where sh.id = p_shop
$$;
revoke execute on function public.vat_bp(uuid) from public, anon, authenticated;

-- الضريبة جوه مبلغ شامل: round(g × bp ÷ (10000 + bp))، تقريب نص لفوق، أعداد صحيحة بس
create or replace function public.vat_of(p_gross bigint, p_bp integer) returns bigint
language sql immutable as $$
  select case when coalesce(p_bp, 0) <= 0 or coalesce(p_gross, 0) <= 0 then 0::bigint
    else (p_gross * p_bp * 2 + (10000 + p_bp)) / (2 * (10000 + p_bp)) end
$$;
revoke execute on function public.vat_of(bigint, integer) from public, anon;
grant execute on function public.vat_of(bigint, integer) to authenticated;

-- حساب الضريبة لكل المحلات الموجودة
insert into public.accounts(shop_id, code, type, kind)
select sh.id, 'vat_payable', 'liability', 'tax' from public.shops sh
on conflict (shop_id, code) where code is not null do nothing;

-- ---------- ضريبة جهاز اتسلّم (للفاتورة والإيصال) ----------
-- من قيد التسليم نفسه (مش من النسبة الحالية). الفني لأ (مفيش أسعار)
create or replace function public.device_vat(p_device uuid) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare s uuid := public.current_shop_id(); r public.app_role := public.current_app_role(); v bigint; g bigint;
begin
  if s is null or r is null or r = 'technician' or r = 'marketing' then raise exception 'E_FORBIDDEN'; end if;
  select coalesce(sum(l.credit) filter (where a.kind = 'tax'), 0), coalesce(sum(l.credit) filter (where a.kind in ('tax', 'revenue')), 0)
    into v, g
  from public.journal_entries e join public.journal_lines l on l.entry_id = e.id join public.accounts a on a.id = l.account_id
  where e.shop_id = s and e.source_type = 'delivery' and e.source_id = p_device
    and not exists (select 1 from public.journal_entries x where x.reverses_id = e.id);
  if g = 0 then return null; end if;
  return jsonb_build_object('vat', v, 'gross', g, 'net', g - v);
end $$;
revoke execute on function public.device_vat(uuid) from public, anon;
grant execute on function public.device_vat(uuid) to authenticated;

-- ---------- سداد الضريبة للمصلحة ----------
create or replace function public.pay_vat(p_id uuid, p_cashbox uuid, p_amount bigint, p_note text default null)
returns uuid
language plpgsql security definer set search_path = public as $$
declare cb public.accounts; e uuid;
begin
  perform public.ledger_require(array['owner']::public.app_role[]);
  e := public.ledger_idem(p_id);
  if e is not null then return e; end if;
  perform public.ledger_amount(p_amount);
  cb := public.ledger_cashbox(p_cashbox);
  if public.ledger_acc('vat_payable') is null then raise exception 'E_NOT_FOUND'; end if;
  return public.ledger_post('vat_payment', p_id, p_note, jsonb_build_array(
    public.ledger_line(public.ledger_acc('vat_payable'), p_amount, 0), public.ledger_line(cb.id, 0, p_amount)), null, p_id);
end $$;
revoke execute on function public.pay_vat(uuid, uuid, bigint, text) from public, anon;
grant execute on function public.pay_vat(uuid, uuid, bigint, text) to authenticated;

-- ---------- تقرير الضريبة للفترة ----------
-- من الدفتر بس: ضريبة المبيعات والصيانة (والصافي قبلها)، والمرتجع بالإلغاء، والمدفوع للمصلحة، والرصيد المستحق لحد آخر الفترة
create or replace function public.vat_report(p_from timestamptz, p_to timestamptz, p_branch uuid default null) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare
  s uuid := public.current_shop_id();
  res jsonb;
begin
  perform public.grant_require('finance', 'view');
  if p_from is null or p_to is null or p_to <= p_from then raise exception 'E_BAD_INPUT'; end if;
  if not public.all_my_branches() and (p_branch is null or not public.can_branch(p_branch)) then p_branch := public.op_branch(); end if;
  with ln as (
    -- قيد الإلغاء بيتحسب على نوع القيد الأصلي (بيع أو تسليم)
    select coalesce(o.source_type, e.source_type) as src, e.source_type as own, a.kind, l.debit, l.credit
    from public.journal_entries e
    join public.journal_lines l on l.entry_id = e.id
    join public.accounts a on a.id = l.account_id
    left join public.journal_entries o on o.id = e.reverses_id
    where e.shop_id = s and e.occurred_at >= p_from and e.occurred_at < p_to
      and (p_branch is null or e.branch_id = p_branch)
      and a.kind in ('tax', 'revenue')
      and coalesce(o.source_type, e.source_type) in ('sale', 'delivery', 'vat_payment')
  ),
  -- الحركات اللي فيها ضريبة بس (الصافي قبل الضريبة = إيراد نفس القيود)
  tx as (
    select e.id from public.journal_entries e join public.journal_lines l on l.entry_id = e.id join public.accounts a on a.id = l.account_id
    where e.shop_id = s and e.occurred_at >= p_from and e.occurred_at < p_to and (p_branch is null or e.branch_id = p_branch) and a.kind = 'tax'
    group by e.id
  ),
  net as (
    select coalesce(o.source_type, e.source_type) as src, coalesce(sum(l.credit - l.debit), 0)::bigint as v
    from tx join public.journal_entries e on e.id = tx.id
    join public.journal_lines l on l.entry_id = e.id join public.accounts a on a.id = l.account_id
    left join public.journal_entries o on o.id = e.reverses_id
    where a.kind = 'revenue' group by 1
  )
  select jsonb_build_object(
    'from', p_from, 'to', p_to, 'branch', p_branch, 'rate_bp', public.vat_bp(s),
    'sales_vat', coalesce(sum(credit) filter (where kind = 'tax' and src = 'sale' and own <> 'reversal'), 0),
    'repair_vat', coalesce(sum(credit) filter (where kind = 'tax' and src = 'delivery' and own <> 'reversal'), 0),
    'reversed_vat', coalesce(sum(debit - credit) filter (where kind = 'tax' and own = 'reversal' and src in ('sale', 'delivery')), 0),
    'paid', coalesce(sum(debit) filter (where kind = 'tax' and src = 'vat_payment' and own <> 'reversal'), 0)
      - coalesce(sum(credit) filter (where kind = 'tax' and src = 'vat_payment' and own = 'reversal'), 0),
    'sales_net', coalesce((select v from net where src = 'sale'), 0),
    'repair_net', coalesce((select v from net where src = 'delivery'), 0),
    -- المستحق لحد آخر الفترة (كل الفروع: الضريبة على المحل كله)
    'due', coalesce((select sum(l.credit - l.debit) from public.journal_lines l join public.journal_entries e on e.id = l.entry_id
                     join public.accounts a on a.id = l.account_id where e.shop_id = s and a.kind = 'tax' and e.occurred_at < p_to), 0)::bigint
  ) into res from ln;
  return res;
end $$;
revoke execute on function public.vat_report(timestamptz, timestamptz, uuid) from public, anon;
grant execute on function public.vat_report(timestamptz, timestamptz, uuid) to authenticated;


-- ---------- الدوال اللي اتعدلت ----------
-- ensure_ledger_accounts: (src: 0027_inventory.sql) + vat_payable
create or replace function public.ensure_ledger_accounts(p_shop uuid) returns void
language plpgsql security definer set search_path = public as $$
declare m text;
begin
  insert into public.accounts(shop_id, code, type, kind)
  select p_shop, v.code, v.type::public.account_type, v.kind from (values
    ('ar', 'asset', 'receivable'), ('advances', 'asset', 'advances'), ('inventory', 'asset', 'inventory'),
    ('ap', 'liability', 'payable'), ('salaries_payable', 'liability', 'salaries'), ('vat_payable', 'liability', 'tax'),
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

-- record_sale: (src: 0060_sale_lines.sql) + فصل الضريبة
create or replace function public.record_sale(p_id uuid, p_lines jsonb, p_cashbox uuid default null, p_customer uuid default null, p_note text default null)
returns uuid
language plpgsql security definer set search_path = public as $$
declare
  s uuid := public.current_shop_id();
  e uuid := gen_random_uuid();
  l jsonb;
  it public.items;
  q bigint; p bigint; cost bigint;
  rev_parts bigint := 0; rev_acc bigint := 0; rev_srv bigint := 0; total_cost bigint := 0;
  debit_acc uuid; pt text; pid uuid;
  n int := 0;
  bp integer := public.vat_bp(s); v_parts bigint := 0; v_acc bigint := 0; v_srv bigint := 0;
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
  -- البيع بس: لو الإعداد مفتوح، اللي مش موجود بيخرج من غير تكلفة ويتسوى بعدين
  perform set_config('app.uncosted', 'on', true);
  for l in select * from jsonb_array_elements(p_lines) loop
    select * into it from public.items where id = (l ->> 'item')::uuid and shop_id = s and deleted_at is null;
    if not found then raise exception 'E_NOT_FOUND'; end if;
    q := (l ->> 'qty')::bigint;
    p := (l ->> 'price')::bigint;
    if q is null or q <= 0 or p is null or p < 0 then raise exception 'E_BAD_AMOUNT'; end if;
    -- 6ب: سطر البيع زي ما اتباع (الاسم والكمية والسعر) عشان فاتورة البيع
    n := n + 1;
    insert into public.sale_lines(shop_id, entry_id, item_id, name, qty, price, seq, customer_id) values (s, e, it.id, it.name, q, p, n, p_customer);
    -- K: الخدمة من غير مخزون ولا تكلفة، وإيرادها إيراد الصيانة
    if it.kind = 'service' then rev_srv := rev_srv + q * p; continue; end if;
    cost := public.ledger_issue(it.id, q, e);
    total_cost := total_cost + cost;
    if it.kind = 'part' then rev_parts := rev_parts + q * p; else rev_acc := rev_acc + q * p; end if;
  end loop;
  perform set_config('app.uncosted', 'off', true);
  perform public.ledger_amount(rev_parts + rev_acc + rev_srv);
  if p_cashbox is null then
    debit_acc := public.ledger_acc('ar'); pt := 'customer'; pid := p_customer;
  else
    debit_acc := (public.ledger_cashbox(p_cashbox)).id;
  end if;
  insert into public.journal_lines(shop_id, entry_id, account_id, party_type, party_id, debit, credit)
  values (s, e, debit_acc, pt, pid, rev_parts + rev_acc + rev_srv, 0);
  -- R5: السعر شامل الضريبة. الضريبة بتتفصل من كل نوع إيراد لوحده، ومجموعها في حساب الضريبة المستحقة
  if bp > 0 then
    v_parts := public.vat_of(rev_parts, bp); v_acc := public.vat_of(rev_acc, bp); v_srv := public.vat_of(rev_srv, bp);
    if v_parts + v_acc + v_srv > 0 then
      insert into public.journal_lines(shop_id, entry_id, account_id, debit, credit) values (s, e, public.ledger_acc('vat_payable'), 0, v_parts + v_acc + v_srv);
    end if;
  end if;
  if rev_parts > 0 then insert into public.journal_lines(shop_id, entry_id, account_id, debit, credit) values (s, e, public.ledger_acc('rev_parts'), 0, rev_parts - v_parts); end if;
  if rev_acc > 0 then insert into public.journal_lines(shop_id, entry_id, account_id, debit, credit) values (s, e, public.ledger_acc('rev_accessories'), 0, rev_acc - v_acc); end if;
  if rev_srv > 0 then insert into public.journal_lines(shop_id, entry_id, account_id, debit, credit) values (s, e, public.ledger_acc('rev_repair'), 0, rev_srv - v_srv); end if;
  if total_cost > 0 then
    insert into public.journal_lines(shop_id, entry_id, account_id, debit, credit) values
      (s, e, public.ledger_acc('cogs'), total_cost, 0), (s, e, public.ledger_acc('inventory'), 0, total_cost);
  end if;
  if p_cashbox is not null and p_customer is not null then
    null; -- البيع النقدي لعميل معروف ما بيأثرش على رصيده
  end if;
  return e;
end $$;

-- tg_device_revenue: (src: 0008_ledger.sql) + فصل الضريبة
create or replace function public.tg_device_revenue() returns trigger
language plpgsql security definer set search_path = public as $$
declare fc integer; v bigint;
begin
  if new.status = 'delivered' and old.status is distinct from 'delivered'
     and not exists (select 1 from public.journal_entries e where e.source_type = 'delivery' and e.source_id = new.id
                     and not exists (select 1 from public.journal_entries r where r.reverses_id = e.id)) then
    select final_cost into fc from public.device_costs where device_id = new.id and deleted_at is null;
    if coalesce(fc, 0) > 0 then
      -- R5: التكلفة النهائية شاملة الضريبة (لو المحل مسجّل)
      v := public.vat_of(fc, public.vat_bp(new.shop_id));
      perform public.ledger_post('delivery', new.id, new.order_no, jsonb_build_array(
        public.ledger_line(public.ledger_acc('ar'), fc, 0, 'customer', new.customer_id),
        public.ledger_line(public.ledger_acc('rev_repair'), 0, fc - v))
        || case when v > 0 then jsonb_build_array(public.ledger_line(public.ledger_acc('vat_payable'), 0, v)) else '[]'::jsonb end, new.id);
    end if;
  end if;
  return null;
end $$;

-- sale_invoice: (src: 0060_sale_lines.sql) + الضريبة ورقم التسجيل
create or replace function public.sale_invoice(p_entry uuid) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare
  s uuid := public.current_shop_id(); r public.app_role := public.current_app_role();
  o public.journal_entries; ls jsonb; old boolean := false;
  total bigint; vat bigint; paid bigint; due bigint; cust uuid; cname text; cphone text; rev_no integer;
begin
  if s is null or r is null or r = 'technician' then raise exception 'E_FORBIDDEN'; end if;
  select * into o from public.journal_entries where id = p_entry and shop_id = s and source_type = 'sale';
  if not found then raise exception 'E_NOT_FOUND'; end if;
  if r <> 'owner' and not ((public.has_perm('sales', 'add') or public.has_perm('finance', 'view')) and public.can_branch(o.branch_id)) then
    raise exception 'E_FORBIDDEN';
  end if;
  -- المبالغ من الدفتر: الإجمالي = الإيراد، والمدفوع = اللي دخل الخزنة، والباقي = على العميل
  select coalesce(sum(l.credit) filter (where a.type = 'revenue' or a.kind = 'tax'), 0),
         coalesce(sum(l.credit) filter (where a.kind = 'tax'), 0),
         coalesce(sum(l.debit) filter (where a.kind = 'cash'), 0),
         coalesce(sum(l.debit) filter (where a.kind = 'receivable'), 0),
         max(l.party_id::text) filter (where l.party_type = 'customer')::uuid
    into total, vat, paid, due, cust
  from public.journal_lines l join public.accounts a on a.id = l.account_id where l.entry_id = o.id;
  select jsonb_agg(jsonb_build_object('name', sl.name, 'qty', sl.qty, 'price', sl.price, 'amount', sl.qty * sl.price) order by sl.seq) into ls
  from public.sale_lines sl where sl.entry_id = o.id and sl.deleted_at is null;
  if ls is null then
    -- بيع قديم: الأصناف والكميات بس (السعر ما كانش متخزّن)
    old := true;
    select jsonb_agg(jsonb_build_object('name', i.name, 'qty', x.q, 'price', null, 'amount', null) order by x.first) into ls
    from (select m.item_id, -sum(m.qty) q, min(m.created_at) first from public.stock_moves m where m.entry_id = o.id group by m.item_id) x
    join public.items i on i.id = x.item_id;
  end if;
  -- البيع الكاش لعميل معروف: العميل من سطور البيع
  cust := coalesce(cust, (select max(sl.customer_id::text)::uuid from public.sale_lines sl where sl.entry_id = o.id));
  -- اسم العميل وتليفونه لمين يشوف العملاء بس (نفس صلاحية جدول العملاء)
  if cust is not null and (r = 'owner' or public.has_perm('customers', 'view') or public.has_perm('intake', 'add')) then
    select c.name, c.phone into cname, cphone from public.customers c where c.id = cust;
  end if;
  select e.entry_no into rev_no from public.journal_entries e where e.reverses_id = o.id;
  return jsonb_build_object('entry_no', o.entry_no, 'at', o.occurred_at, 'memo', o.memo, 'branch_id', o.branch_id,
    'lines', coalesce(ls, '[]'::jsonb), 'legacy', old, 'total', total, 'vat', vat, 'net', total - vat,
    'vat_no', case when vat > 0 then (select nullif(trim(sh.extras -> 'vat' ->> 'reg_no'), '') from public.shops sh where sh.id = s) end,
    'paid', paid, 'due', due,
    'customer', cname, 'phone', cphone, 'cancelled_by', rev_no);
end $$;

-- financial_position: (src: 0038_roles_grant.sql) + الضريبة المستحقة
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
      (coalesce(sum(greatest(b, 0)) filter (where kind in ('payable', 'salaries', 'tax')), 0)
        + coalesce(sum(greatest(-b, 0)) filter (where kind in ('receivable', 'advances')), 0)
        + coalesce(sum(greatest(-b, 0)) filter (where kind = 'inventory'), 0))::bigint as payables,
      coalesce(sum(greatest(-b, 0)) filter (where kind in ('payable', 'salaries', 'tax')), 0)::bigint as payables_debit,
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
    'vat_due', coalesce((select sum(b) from acc where kind = 'tax'), 0),
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
