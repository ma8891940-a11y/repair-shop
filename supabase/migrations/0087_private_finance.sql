-- 0087: (قرار صاحب المشروع 2026-11-24) المرتبات ورأس المال: صلاحية لوحدها (private_finance ← يشوف)، مقفولة لكل الأدوار ما عدا صاحب المحل. الفني عمره ما ياخدها.
-- من غيرها: مش في الميزان ولا الأرباح ولا مؤشرات الفروع ولا أرقام الوضع المالي، وفي كشف الخزنة والتقرير اليومي "حركة خاصة" بالمبلغ بس، والقيد نفسه ما بيتقراش من الجداول.
-- صافي القيمة وحقوق الملكية وحسابات الشركاء لصاحب المحل بس، حتى مع الصلاحية.

-- perm_sections: (src: 0083_print_perm.sql) + private_finance
create or replace function public.perm_sections() returns text[]
language sql immutable as $$
  select array['devices', 'intake', 'customers', 'technicians', 'inventory', 'item_create', 'sales', 'purchases', 'cashbox', 'expenses', 'finance', 'private_finance', 'partners', 'reports', 'staff', 'settings', 'print_templates', 'audit']
$$;

-- مستوى المستخدم: 2 صاحب المحل، 1 موظف معاه الصلاحية، 0 الباقي
create or replace function public.private_level() returns integer
language sql stable security definer set search_path = public as $$
  select case when public.current_app_role() = 'owner' then 2 when public.current_app_role() = 'reception' and public.has_perm('private_finance', 'view') then 1 else 0 end
$$;
revoke execute on function public.private_level() from public, anon;
grant execute on function public.private_level() to authenticated;

-- مستوى الحساب: 2 الشركاء والأرباح المحتجزة (صاحب المحل بس)، 1 المرتبات والسلف ورأس المال والسحوبات، 0 عادي
create or replace function public.private_account(p_kind text, p_code text) returns integer
language sql immutable as $$
  select case when p_kind in ('partner_capital', 'partner_current', 'retained') then 2
              when p_kind in ('advances', 'salaries', 'capital', 'drawings') or p_code = 'exp_salaries' then 1 else 0 end
$$;
revoke execute on function public.private_account(text, text) from public, anon;
grant execute on function public.private_account(text, text) to authenticated;

-- مستوى القيد = أعلى حساب فيه (قيود محل المستخدم بس)
create or replace function public.private_entry(p_entry uuid) returns integer
language sql stable security definer set search_path = public as $$
  select coalesce(max(public.private_account(a.kind, a.code)), 0) from public.journal_lines l join public.accounts a on a.id = l.account_id
  where l.entry_id = p_entry and l.shop_id = public.current_shop_id()
$$;
revoke execute on function public.private_entry(uuid) from public, anon;
grant execute on function public.private_entry(uuid) to authenticated;

-- party_balances: (src: 0084_party_branch.sql)
create or replace function public.party_balances(p_kind text)
returns table(party_type text, party_id uuid, name text, account text, balance bigint, oldest timestamptz)
language plpgsql stable security definer set search_path = public as $$
#variable_conflict use_column
declare s uuid := public.current_shop_id(); br uuid := public.party_branch();
begin
  perform public.grant_require('finance', 'view');
  if p_kind = 'employees' and public.private_level() < 1 then raise exception 'E_FORBIDDEN'; end if;
  if p_kind not in ('customers', 'suppliers', 'employees') then raise exception 'E_BAD_INPUT'; end if;
  return query
  with lines as (
    select l.party_type, l.party_id, a.code, e.occurred_at, e.entry_no,
           (case when public.account_sign(a.type) = 1 then l.debit else l.credit end)::bigint as plus,
           (case when public.account_sign(a.type) = 1 then l.credit else l.debit end)::bigint as minus
    from public.journal_lines l join public.accounts a on a.id = l.account_id join public.journal_entries e on e.id = l.entry_id
    where l.shop_id = s and l.party_id is not null and (br is null or e.branch_id = br)
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

-- statement: (src: 0084_party_branch.sql)
create or replace function public.statement(p_kind text, p_id uuid, p_from timestamptz, p_to timestamptz) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare
  s uuid := public.current_shop_id();
  accs uuid[];
  parties uuid[] := array[p_id];
  lk public.party_links;
  opening bigint;
  lvl integer := public.private_level();
  br uuid; -- كشف العميل والمورد للموظف: فرعه بس. الخزنة ليها فحصها
  res jsonb;
begin
  perform public.grant_require('finance', 'view');
  -- المرتبات والشركاء لصاحب المحل بس، والخزنة لازم تكون في فروع الموظف
  if public.current_app_role() <> 'owner' and (p_kind = 'partner' or (p_kind = 'employee' and lvl < 1)
     or (p_kind = 'cashbox' and not exists (select 1 from public.accounts a where a.id = p_id and public.can_branch(a.branch_id)))) then raise exception 'E_FORBIDDEN'; end if;
  if p_kind <> 'cashbox' then br := public.party_branch(); end if;
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
  where l.account_id = any(accs) and (p_kind = 'cashbox' or l.party_id = any(parties)) and (br is null or e.branch_id = br) and e.occurred_at < p_from;
  with mv as (
    -- الخزنة: حركة المرتبات ورأس المال بالمبلغ بس (عشان الرصيد وإقفال الدرج)
    select e.id as entry_id, e.entry_no, e.occurred_at, case when h.hide then 'private' else e.source_type end as source_type, case when not h.hide then e.source_id end as source_id,
           case when not h.hide then e.device_id end as device_id, case when not h.hide then e.memo end as memo, case when not h.hide then e.reverses_id end as reverses_id,
           case when not h.hide then d.order_no end as order_no, case when not h.hide then p.full_name end as by_name, a.code as account_code,
           ((l.debit - l.credit) * (case when p_kind = 'linked' then 1 else public.account_sign(a.type) end))::bigint as amount
    from public.journal_lines l
    join public.accounts a on a.id = l.account_id
    join public.journal_entries e on e.id = l.entry_id
    left join public.devices d on d.id = e.device_id
    left join public.profiles p on p.id = e.created_by
    cross join lateral (select p_kind = 'cashbox' and lvl < public.private_entry(e.id) as hide) h
    where l.account_id = any(accs) and (p_kind = 'cashbox' or l.party_id = any(parties)) and (br is null or e.branch_id = br) and e.occurred_at >= p_from and e.occurred_at < p_to
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

-- trial_balance: (src: 0085_finance_branch.sql)
create or replace function public.trial_balance(p_branch uuid default null, p_to timestamptz default null)
returns table(account_id uuid, code text, name text, type text, kind text, debit bigint, credit bigint, balance bigint)
language plpgsql stable security definer set search_path = public as $$
#variable_conflict use_column
declare lvl integer := public.private_level();
begin
  perform public.grant_require('finance', 'view');
  if p_branch is not null and public.current_app_role() <> 'owner' and not public.can_branch(p_branch) then raise exception 'E_FORBIDDEN'; end if;
  if p_branch is null then p_branch := public.party_branch(); end if;
  return query
  with b as (select * from public.branch_lines_raw(p_to) bl where p_branch is null or bl.branch_id = p_branch),
  t as (select b.account_id acc, sum(greatest(b.amount, 0))::bigint dr, sum(greatest(-b.amount, 0))::bigint cr from b group by 1)
  select t.acc, a.code, a.name, coalesce(a.type::text, 'inter_branch'), coalesce(a.kind, 'inter_branch'), t.dr, t.cr, (t.dr - t.cr)::bigint
  from t left join public.accounts a on a.id = t.acc
  where (t.dr - t.cr <> 0 or t.acc is null and p_branch is not null) and (a.id is null or lvl >= public.private_account(a.kind, a.code))
  order by case coalesce(a.type::text, 'inter_branch') when 'asset' then 1 when 'liability' then 2 when 'equity' then 3 when 'revenue' then 4 when 'expense' then 5 else 6 end, a.code nulls last, a.name;
end $$;

-- pl_breakdown: (src: 0085_finance_branch.sql)
create or replace function public.pl_breakdown(p_from timestamptz, p_to timestamptz, p_branch uuid default null)
returns table(account_id uuid, code text, name text, type public.account_type, amount bigint)
language plpgsql stable security definer set search_path = public as $$
declare lvl integer := public.private_level();
begin
  perform public.grant_require('finance', 'view');
  -- الموظف: فرع واحد من فروعه
  if public.current_app_role() <> 'owner' and (p_branch is null or not public.can_branch(p_branch)) then p_branch := public.op_branch(); end if;
  return query
  select a.id, a.code, a.name, a.type,
         sum(case when a.type = 'revenue' then l.credit - l.debit else l.debit - l.credit end)::bigint
  from public.journal_lines l
  join public.accounts a on a.id = l.account_id
  join public.journal_entries e on e.id = l.entry_id
  where l.shop_id = public.current_shop_id() and a.type in ('revenue', 'expense') and e.occurred_at >= p_from and e.occurred_at < p_to and lvl >= public.private_account(a.kind, a.code)
    and (p_branch is null or e.branch_id = p_branch)
  group by a.id
  having sum(l.debit - l.credit) <> 0
  order by a.type desc, 5 desc;
end $$;

-- branch_lines: (src: 0085_finance_branch.sql)
create or replace function public.branch_lines(p_to timestamptz default null)
returns table(entry_id uuid, occurred_at timestamptz, source_type text, branch_id uuid, account_id uuid, amount bigint)
language plpgsql stable security definer set search_path = public as $$
#variable_conflict use_column
declare br uuid; lvl integer := public.private_level();
begin
  perform public.grant_require('finance', 'view');
  br := public.party_branch();
  return query select * from public.branch_lines_raw(p_to) x where (br is null or x.branch_id = br)
    and not exists (select 1 from public.accounts a where a.id = x.account_id and lvl < public.private_account(a.kind, a.code));
end $$;

-- financial_position: (src: 0086_finance_cards.sql)
create or replace function public.financial_position(p_from timestamptz, p_to timestamptz, p_branch uuid default null) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare
  s uuid := public.current_shop_id();
  res jsonb;
  own boolean := public.current_app_role() = 'owner';
  lvl integer := public.private_level(); -- المرتبات ورأس المال
begin
  perform public.grant_require('finance', 'view');
  -- الموظف: فرع واحد من فروعه دايمًا، ومن غير إجماليات المحل كله
  if public.current_app_role() <> 'owner' and (p_branch is null or not public.can_branch(p_branch)) then p_branch := public.op_branch(); end if;
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
    where l.shop_id = s and e.occurred_at >= p_from and e.occurred_at < p_to and (p_branch is null or e.branch_id = p_branch) and lvl >= public.private_account(a.kind, a.code)
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
      coalesce(sum(greatest(b, 0)) filter (where kind in ('receivable', 'advances', 'cheque_in')), 0)::bigint as receivables,
      (coalesce(sum(greatest(b, 0)) filter (where kind in ('payable', 'salaries', 'tax', 'cheque_out')), 0)
        + coalesce(sum(greatest(-b, 0)) filter (where kind in ('receivable', 'advances', 'cheque_in')), 0)
        + coalesce(sum(greatest(-b, 0)) filter (where kind = 'inventory'), 0))::bigint as payables,
      coalesce(sum(greatest(-b, 0)) filter (where kind in ('payable', 'salaries', 'tax', 'cheque_out')), 0)::bigint as payables_debit,
      coalesce(sum(greatest(b, 0)) filter (where kind = 'inventory'), 0)::bigint as inventory,
      coalesce(sum(b) filter (where kind = 'fixed_asset'), 0)::bigint as fixed_assets,
      -- أرباح اتوزعت على الشركاء ولسه ما اتسحبتش (حقوق ملكية، مش دين من بره)
      coalesce(sum(greatest(b, 0)) filter (where kind = 'partner_current'), 0)::bigint as partners_due
    from bal
    where lvl >= 1 or kind not in ('advances', 'salaries')
  ),
  days as (
    select (date_trunc('day', e.occurred_at at time zone 'Africa/Cairo'))::date as day,
           coalesce(sum(case when a.type = 'revenue' then l.credit - l.debit else 0 end), 0)::bigint as revenue,
           coalesce(sum(case when a.type = 'expense' then l.debit - l.credit else 0 end), 0)::bigint as expenses
    from public.journal_lines l join public.accounts a on a.id = l.account_id join public.journal_entries e on e.id = l.entry_id
    where l.shop_id = s and e.occurred_at >= p_from and e.occurred_at < p_to and a.type in ('revenue', 'expense') and (p_branch is null or e.branch_id = p_branch) and lvl >= public.private_account(a.kind, a.code)
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
    'cheques_in', coalesce((select sum(b) from acc where kind = 'cheque_in'), 0),
    'cheques_out', coalesce((select sum(b) from acc where kind = 'cheque_out'), 0),
    -- الضريبة على المحل كله لصاحب المحل، وللموظف فرعه
    'vat_due', (select coalesce(sum(l.credit - l.debit), 0)::bigint from public.journal_lines l join public.accounts a on a.id = l.account_id where l.shop_id = s and a.kind = 'tax' and (own or exists (select 1 from public.journal_entries te where te.id = l.entry_id and te.branch_id = p_branch))),
    'partners_due', case when own then p.partners_due end,
    -- قيمة المحل = الأصول − الالتزامات اللي لناس من بره بس (رأس مال الشركاء وأرباحهم حقوق ملكية، فما بتقللهاش)
    'net_worth', case when own then p.cash + p.receivables + p.payables_debit + p.fixed_assets - p.payables
      + case when p_branch is null then p.inventory else (select coalesce(sum(m.value), 0)::bigint from public.stock_moves m where m.shop_id = s and m.branch_id = p_branch) end end,
    'branch', p_branch,
    -- حقوق الملكية بالتفصيل (من أول يوم): رأس مال صاحب المحل، والسحوبات، ورأس مال وجاري كل شريك، والأرباح المحتجزة
    'equity_parts', case when own then jsonb_build_object(
      'owner_capital', coalesce((select b from acc where code = 'capital'), 0),
      'drawings', -coalesce((select b from acc where code = 'drawings'), 0),
      'retained', eq.earnings + coalesce((select b from acc where code = 'retained'), 0),
      'partners', coalesce((select jsonb_agg(jsonb_build_object('id', pt.id, 'name', pt.name, 'share_bp', pt.share_bp,
          'capital', coalesce((select sum(b.b) from bal b where b.kind = 'partner_capital' and b.party_id = pt.id), 0),
          'current', coalesce((select sum(b.b) from bal b where b.kind = 'partner_current' and b.party_id = pt.id), 0)) order by pt.share_bp desc, pt.name)
        from public.partners pt where pt.shop_id = s and (pt.deleted_at is null or exists (select 1 from bal b where b.party_id = pt.id and b.b <> 0))), '[]'::jsonb)) end,
    'equation', case when own then jsonb_build_object('assets', eq_all.assets, 'liabilities', eq_all.liabilities, 'equity', eq_all.equity, 'earnings', eq_all.earnings) end,
    'debits', case when own then tot.d end, 'credits', case when own then tot.c end, 'unbalanced_entries', unb.n,
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

-- day_cash_report: (src: 0085_finance_branch.sql)
create or replace function public.day_cash_report(p_from timestamptz, p_to timestamptz, p_branch uuid default null) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare
  s uuid := public.current_shop_id();
  res jsonb;
  lvl integer := public.private_level();
begin
  perform public.grant_require('finance', 'view');
  if public.current_app_role() <> 'owner' and (p_branch is null or not public.can_branch(p_branch)) then
    p_branch := public.op_branch();
    -- موظف من غير فرع: ما يشوفش خزن المحل كله
    if p_branch is null then raise exception 'E_FORBIDDEN'; end if;
  end if;
  with boxes as (
    select a.id, a.code, a.name, a.method, a.branch_id from public.accounts a
    where a.shop_id = s and a.kind = 'cash' and (p_branch is null or a.branch_id = p_branch)
  ),
  mv as (
    select l.account_id, e.id as entry_id, e.entry_no, e.source_type, e.memo, e.occurred_at, l.debit, l.credit,
           -- الإلغاء اللي حصل بعد الفترة ما يغيّرش تقرير يوم قديم
           (e.reverses_id is not null or exists (select 1 from public.journal_entries r where r.reverses_id = e.id and r.occurred_at < p_to)) as cancelled
    from public.journal_lines l join public.journal_entries e on e.id = l.entry_id
    where l.shop_id = s and l.account_id in (select id from boxes) and e.occurred_at >= p_from and e.occurred_at < p_to
  ),
  -- طريقة الدفع = طريقة الخزنة (record_payment بيسجل p_method، بس الواجهة ما بتبعتهوش، فهي نفس طريقة الخزنة)
  -- شيك العميل: بيتحسب تحصيل يوم ما يتصرف (cheque_clear لخزنة = فلوس دخلت). شيك المورد بيخرج من الخزنة (دائن) فما بيدخلش
  col as (
    select b.method,
           coalesce(sum(m.debit) filter (where m.source_type = 'payment'), 0)::bigint as payments,
           coalesce(sum(m.debit) filter (where m.source_type = 'sale'), 0)::bigint as sales,
           coalesce(sum(m.debit) filter (where m.source_type = 'cheque_clear'), 0)::bigint as cheques,
           coalesce(sum(m.credit) filter (where m.source_type = 'sale_return'), 0)::bigint as refunds
    from mv m join boxes b on b.id = m.account_id
    where not m.cancelled and m.source_type in ('payment', 'sale', 'cheque_clear', 'sale_return')
    group by b.method
  )
  select jsonb_build_object(
    'branch', p_branch,
    'collections', coalesce((select jsonb_agg(jsonb_build_object('method', method, 'payments', payments, 'sales', sales, 'cheques', cheques, 'refunds', refunds,
        'total', payments + sales + cheques - refunds) order by method) from col where payments + sales + cheques + refunds > 0), '[]'::jsonb),
    'cashboxes', coalesce((select jsonb_agg(x order by x ->> 'code' nulls last, x ->> 'name') from (
      select jsonb_build_object('id', b.id, 'code', b.code, 'name', b.name, 'method', b.method, 'branch_id', b.branch_id,
        'opening', o.opening, 'in', coalesce(t.d, 0), 'out', coalesce(t.c, 0), 'closing', o.opening + coalesce(t.d, 0) - coalesce(t.c, 0),
        'entries', coalesce((select jsonb_agg(jsonb_build_object('entry_id', m.entry_id, 'entry_no', m.entry_no, 'source_type', case when h.hide then 'private' else m.source_type end,
            'memo', case when not h.hide then m.memo end, 'at', m.occurred_at, 'in', m.debit, 'out', m.credit, 'cancelled', m.cancelled) order by m.occurred_at, m.entry_no)
          from mv m cross join lateral (select lvl < public.private_entry(m.entry_id) as hide) h where m.account_id = b.id), '[]'::jsonb)) as x
      from boxes b
      cross join lateral (select coalesce(sum(l.debit - l.credit), 0)::bigint as opening from public.journal_lines l join public.journal_entries e on e.id = l.entry_id
                          where l.account_id = b.id and e.occurred_at < p_from) o
      left join lateral (select sum(m.debit)::bigint as d, sum(m.credit)::bigint as c from mv m where m.account_id = b.id) t on true
      -- الخزنة اللي ما اتحركتش ورصيدها صفر ما بتظهرش
      where o.opening <> 0 or t.d is not null) y), '[]'::jsonb)
  ) into res;
  return res;
end $$;

-- accountant_export: (src: 0085_finance_branch.sql)
create or replace function public.accountant_export(p_from date, p_to date, p_branch uuid default null) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  s uuid := public.current_shop_id(); own boolean := public.current_app_role() = 'owner'; names boolean; res jsonb; lvl integer := public.private_level();
  f timestamptz; t timestamptz;
begin
  perform public.grant_require('finance', 'view');
  perform public.grant_require('finance', 'export');
  if p_from is null or p_to is null or not isfinite(p_from) or not isfinite(p_to) or p_to < p_from or p_to - p_from > 366 then raise exception 'E_BAD_INPUT'; end if;
  f := p_from::timestamp at time zone 'Africa/Cairo';
  t := (p_to + 1)::timestamp at time zone 'Africa/Cairo';
  if public.current_app_role() <> 'owner' and (p_branch is null or not public.can_branch(p_branch)) then
    p_branch := public.op_branch();
    if p_branch is null then raise exception 'E_FORBIDDEN'; end if;
  end if;
  if p_branch is not null and not exists (select 1 from public.branches where id = p_branch and shop_id = s) then raise exception 'E_BAD_BRANCH'; end if;
  names := own or public.has_perm('customers', 'view');
  with ent as materialized (
    select e.* from public.journal_entries e
    where e.shop_id = s and e.occurred_at >= f and e.occurred_at < t and (p_branch is null or e.branch_id = p_branch)
      and (own or not exists (select 1 from public.journal_lines l join public.accounts a on a.id = l.account_id
                              where l.entry_id = e.id and (lvl < public.private_account(a.kind, a.code)
                                or a.kind = 'cash' and not public.can_branch(a.branch_id))))
  ),
  ln as (
    select ent.entry_no, ent.occurred_at, ent.source_type, ent.memo, b.name as branch, a.code, a.name as account, a.type::text as account_type, l.debit, l.credit, l.id,
           (select o.entry_no from public.journal_entries o where o.id = ent.reverses_id) as reverses_no,
           case l.party_type when 'customer' then case when names then (select c.name from public.customers c where c.id = l.party_id) end
                             when 'supplier' then case when own or public.has_perm('purchases', 'view') then (select sp.name from public.suppliers sp where sp.id = l.party_id) end
                             when 'employee' then (select p.full_name from public.profiles p where p.id = l.party_id)
                             when 'partner' then (select pr.name from public.partners pr where pr.id = l.party_id) end as party
    from ent join public.journal_lines l on l.entry_id = ent.id join public.accounts a on a.id = l.account_id left join public.branches b on b.id = ent.branch_id
  )
  select jsonb_build_object(
    'from', p_from, 'to', p_to, 'branch', p_branch, 'restricted', not own,
    'lines', coalesce((select jsonb_agg(jsonb_build_object('entry_no', entry_no, 'at', occurred_at, 'source', source_type, 'memo', memo, 'branch', branch, 'code', code, 'account', account,
        'type', account_type, 'party', party, 'debit', debit, 'credit', credit, 'reverses_no', reverses_no) order by occurred_at, entry_no, debit = 0, id) from ln), '[]'::jsonb),
    'payments', coalesce((select jsonb_agg(jsonb_build_object('entry_no', ent.entry_no, 'at', ent.occurred_at, 'method', p.method, 'amount', p.amount, 'cashbox', a.code, 'cashbox_name', a.name,
        'customer', case when names then c.name end, 'order_no', d.order_no,
        'reversed', exists (select 1 from public.journal_entries r where r.reverses_id = ent.id and r.occurred_at < t)) order by ent.occurred_at, ent.entry_no)
      from ent join public.payments p on p.entry_id = ent.id join public.accounts a on a.id = p.cashbox_id
      left join public.customers c on c.id = p.customer_id left join public.devices d on d.id = p.device_id), '[]'::jsonb),
    'sales', coalesce((select jsonb_agg(jsonb_build_object('entry_no', ent.entry_no, 'at', ent.occurred_at, 'item', sl.name, 'qty', sl.qty, 'price', sl.price, 'amount', case when sl.return_of is null then 1 else -1 end * sl.qty * sl.price,
        'return_of', (select o.entry_no from public.sale_lines b join public.journal_entries o on o.id = b.entry_id where b.id = sl.return_of),
        'reversed', exists (select 1 from public.journal_entries r where r.reverses_id = ent.id and r.occurred_at < t)) order by ent.occurred_at, ent.entry_no, sl.seq)
      from ent join public.sale_lines sl on sl.entry_id = ent.id and sl.deleted_at is null), '[]'::jsonb),
    'debit', (select coalesce(sum(debit), 0) from ln), 'credit', (select coalesce(sum(credit), 0) from ln))
  into res;
  insert into public.audit_log(shop_id, actor_id, action, entity, entity_id, after)
  values (s, auth.uid(), 'accountant_export', 'shops', s, jsonb_build_object('from', p_from, 'to', p_to, 'branch', p_branch));
  return res;
end $$;

-- branch_kpis: (src: 0041_analytics.sql)
create or replace function public.branch_kpis(p_from timestamptz, p_to timestamptz)
returns table(branch_id uuid, revenue bigint, cogs bigint, opex bigint, invoices integer, devices_in integer, devices_out integer,
              repair_minutes bigint, returns integer, stock_value bigint, stale_value bigint, stale_items integer,
              receivables bigint, receivables_60 bigint, goal_revenue bigint, goal_profit bigint)
language plpgsql stable security definer set search_path = public as $$
#variable_conflict use_column
declare s uuid := public.current_shop_id(); stale interval := interval '60 days'; lvl integer := public.private_level();
begin
  perform public.grant_require('reports', 'view');
  return query
  with br as (
    select b.id from public.branches b where b.shop_id = s and b.deleted_at is null and (public.all_my_branches() or public.can_branch(b.id))
  ), bl as (
    select l.*, a.type, a.kind, a.code from public.branch_lines_raw(p_to) l left join public.accounts a on a.id = l.account_id
  ), money as (
    select bl.branch_id,
      coalesce(-sum(bl.amount) filter (where bl.type = 'revenue' and bl.kind = 'revenue' and bl.occurred_at >= p_from), 0)::bigint rev,
      coalesce(sum(bl.amount) filter (where bl.type = 'expense' and bl.kind = 'cogs' and bl.occurred_at >= p_from), 0)::bigint cg,
      coalesce(sum(bl.amount) filter (where bl.type = 'expense' and bl.kind <> 'cogs' and bl.occurred_at >= p_from and lvl >= public.private_account(bl.kind, bl.code)), 0)::bigint ox,
      count(distinct bl.entry_id) filter (where bl.source_type in ('sale', 'delivery') and bl.type = 'revenue' and bl.occurred_at >= p_from)::int inv,
      coalesce(sum(bl.amount) filter (where bl.kind = 'receivable'), 0)::bigint ar,
      coalesce(sum(bl.amount) filter (where bl.kind = 'receivable' and bl.occurred_at < now() - interval '60 days'), 0)::bigint ar60
    from bl group by 1
  ), dev as (
    select d.branch_id,
      count(*) filter (where d.received_at >= p_from and d.received_at < p_to)::int din,
      count(*) filter (where d.status = 'delivered' and d.delivered_at >= p_from and d.delivered_at < p_to)::int dout,
      coalesce(sum(extract(epoch from d.delivered_at - d.received_at) / 60) filter (where d.status = 'delivered' and d.delivered_at >= p_from and d.delivered_at < p_to), 0)::bigint mins,
      count(*) filter (where d.status = 'warranty_return' and d.updated_at >= p_from and d.updated_at < p_to)::int ret
    from public.devices d where d.shop_id = s and d.deleted_at is null group by 1
  ), stock as (
    select m.branch_id, m.item_id, sum(m.qty) q, sum(m.value) v,
           max(m.created_at) filter (where m.qty < 0) last_out
    from public.stock_moves m where m.shop_id = s group by 1, 2
  ), st as (
    select x.branch_id, coalesce(sum(x.v) filter (where x.q > 0), 0)::bigint sv,
      coalesce(sum(x.v) filter (where x.q > 0 and coalesce(x.last_out, 'epoch'::timestamptz) < now() - stale), 0)::bigint stv,
      count(*) filter (where x.q > 0 and coalesce(x.last_out, 'epoch'::timestamptz) < now() - stale)::int sti
    from stock x group by 1
  ), g as (
    select gg.branch_id,
      max(gg.target) filter (where gg.metric = 'revenue') gr, max(gg.target) filter (where gg.metric = 'profit') gp
    from public.branch_goals gg where gg.shop_id = s and gg.deleted_at is null and gg.month = date_trunc('month', p_from at time zone 'Africa/Cairo')::date
    group by 1
  )
  select br.id, coalesce(m.rev, 0), coalesce(m.cg, 0), coalesce(m.ox, 0), coalesce(m.inv, 0), coalesce(dv.din, 0), coalesce(dv.dout, 0),
         coalesce(dv.mins, 0), coalesce(dv.ret, 0), coalesce(st.sv, 0), coalesce(st.stv, 0), coalesce(st.sti, 0),
         coalesce(m.ar, 0), coalesce(m.ar60, 0), g.gr, g.gp
  from br left join money m on m.branch_id = br.id left join dev dv on dv.branch_id = br.id left join st on st.branch_id = br.id left join g on g.branch_id = br.id;
end $$;

-- entry_require: (src: 0075_delete_by_section.sql)
create or replace function public.entry_require(p_entry uuid) returns void
language plpgsql stable security definer set search_path = public as $$
begin
  if public.current_app_role() = 'owner' then return; end if;
  if public.can_delete((select public.entry_section(e.source_type) from public.journal_entries e where e.id = p_entry)) is not true then raise exception 'E_FORBIDDEN'; end if;
  if public.private_level() < public.private_entry(p_entry) then raise exception 'E_FORBIDDEN'; end if;
  if exists (select 1 from public.journal_entries e where e.id = p_entry and (e.source_type = 'vat_payment' or not public.can_branch(e.branch_id)))
     or exists (select 1 from public.journal_lines l join public.accounts a on a.id = l.account_id where l.entry_id = p_entry
                and (a.kind in ('advances', 'salaries', 'partner_capital', 'partner_current', 'capital', 'drawings') or (a.kind = 'cash' and not public.can_branch(a.branch_id))))
     or exists (select 1 from public.stock_moves m where m.entry_id = p_entry and not public.can_branch(m.branch_id)) then
    raise exception 'E_FORBIDDEN';
  end if;
end $$;

-- ---------- القراية المباشرة ----------
drop policy staff_entries_select on public.journal_entries;
create policy staff_entries_select on public.journal_entries for select to authenticated
  using (shop_id = (select public.current_shop_id()) and (select public.current_app_role()) = 'reception' and (select public.has_perm('finance', 'view')) and public.can_branch(branch_id)
         and (select public.private_level()) >= public.private_entry(id));
drop policy staff_lines_select on public.journal_lines;
create policy staff_lines_select on public.journal_lines for select to authenticated
  using (shop_id = (select public.current_shop_id()) and (select public.current_app_role()) = 'reception' and (select public.has_perm('finance', 'view'))
         and exists (select 1 from public.journal_entries e where e.id = entry_id and public.can_branch(e.branch_id))
         and (select public.private_level()) >= public.private_entry(entry_id));
drop policy staff_accounts_select on public.accounts;
create policy staff_accounts_select on public.accounts for select to authenticated
  using (shop_id = (select public.current_shop_id()) and (select public.current_app_role()) = 'reception' and (select public.has_perm('finance', 'view'))
         and (kind <> 'cash' or public.can_branch(branch_id)) and kind not in ('partner_capital', 'partner_current') and ((select public.private_level()) >= 1 or kind not in ('advances', 'salaries')));
drop policy staff_audit_select on public.audit_log;
create policy staff_audit_select on public.audit_log for select to authenticated
  using (shop_id = (select public.current_shop_id()) and (select public.current_app_role()) = 'reception' and (select public.has_perm('audit', 'view'))
         and entity not in ('partners', 'profit_distributions') and ((select public.private_level()) >= 1 or entity <> 'commission_rules')
         and (entity <> 'journal_entries' or (select public.private_level()) >= public.private_entry(entity_id)));
