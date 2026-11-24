-- 0085: (قرار صاحب المشروع 2026-11-24) المالية للموظف: فرع واحد من فروعه دايمًا (اللي اختاره، وإلا الشغال عليه). صاحب المحل بس اللي يشوف المحل كله.
-- الوضع المالي، والأرباح، والتدفق اليومي، وميزان المراجعة، والمستحق بين الفروع، والضريبة، والشيكات، والأقساط وتنبيهاتها، والتقرير اليومي، وملف المحاسب.

-- financial_position: (src: 0063_cheques.sql)
create or replace function public.financial_position(p_from timestamptz, p_to timestamptz, p_branch uuid default null) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare
  s uuid := public.current_shop_id();
  res jsonb;
  own boolean := public.current_app_role() = 'owner';
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
    'cheques_in', coalesce((select sum(b) from acc where kind = 'cheque_in'), 0),
    'cheques_out', coalesce((select sum(b) from acc where kind = 'cheque_out'), 0),
    -- الضريبة على المحل كله لصاحب المحل، وللموظف فرعه
    'vat_due', (select coalesce(sum(l.credit - l.debit), 0)::bigint from public.journal_lines l join public.accounts a on a.id = l.account_id where l.shop_id = s and a.kind = 'tax' and (own or exists (select 1 from public.journal_entries te where te.id = l.entry_id and te.branch_id = p_branch))),
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

-- pl_breakdown: (src: 0038_roles_grant.sql)
create or replace function public.pl_breakdown(p_from timestamptz, p_to timestamptz, p_branch uuid default null)
returns table(account_id uuid, code text, name text, type public.account_type, amount bigint)
language plpgsql stable security definer set search_path = public as $$
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
  where l.shop_id = public.current_shop_id() and a.type in ('revenue', 'expense') and e.occurred_at >= p_from and e.occurred_at < p_to
    and (p_branch is null or e.branch_id = p_branch)
  group by a.id
  having sum(l.debit - l.credit) <> 0
  order by a.type desc, 5 desc;
end $$;

-- cashbox_daily: (src: 0038_roles_grant.sql)
create or replace function public.cashbox_daily(p_from timestamptz, p_to timestamptz)
returns table(cashbox uuid, day date, net bigint)
language plpgsql stable security definer set search_path = public as $$
declare br uuid;
begin
  perform public.grant_require('finance', 'view', true);
  br := public.party_branch();
  return query
  select l.account_id, (date_trunc('day', e.occurred_at at time zone 'Africa/Cairo'))::date, sum(l.debit - l.credit)::bigint
  from public.journal_lines l
  join public.accounts a on a.id = l.account_id and a.kind = 'cash'
  join public.journal_entries e on e.id = l.entry_id
  where l.shop_id = public.current_shop_id() and e.occurred_at >= p_from and e.occurred_at < p_to and (br is null or a.branch_id = br)
  group by 1, 2
  order by 2;
end $$;

-- vat_report: (src: 0062_vat.sql)
create or replace function public.vat_report(p_from timestamptz, p_to timestamptz, p_branch uuid default null) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare
  s uuid := public.current_shop_id();
  res jsonb;
  whole boolean := public.current_app_role() = 'owner';
begin
  perform public.grant_require('finance', 'view');
  if p_from is null or p_to is null or p_to <= p_from then raise exception 'E_BAD_INPUT'; end if;
  if public.current_app_role() <> 'owner' and (p_branch is null or not public.can_branch(p_branch)) then p_branch := public.op_branch(); end if;
  with ln as (
    -- قيد الإلغاء بيتحسب على نوع القيد الأصلي (بيع أو تسليم)
    select coalesce(o.source_type, e.source_type) as src, e.source_type as own, a.kind, l.debit, l.credit
    from public.journal_entries e
    join public.journal_lines l on l.entry_id = e.id
    join public.accounts a on a.id = l.account_id
    left join public.journal_entries o on o.id = e.reverses_id
    where e.shop_id = s and e.occurred_at >= p_from and e.occurred_at < p_to
      -- السداد على المحل كله لصاحب المحل (الضريبة على المحل مش الفرع)، والباقي بفلتر الفرع
      and (p_branch is null or e.branch_id = p_branch or whole and coalesce(o.source_type, e.source_type) = 'vat_payment')
      and a.kind in ('tax', 'revenue')
      and coalesce(o.source_type, e.source_type) in ('sale', 'delivery', 'vat_payment', 'sale_return')
  ),
  -- الحركات اللي فيها ضريبة بس (الصافي قبل الضريبة = إيراد نفس القيود)
  tx as (
    select e.id from public.journal_entries e join public.journal_lines l on l.entry_id = e.id join public.accounts a on a.id = l.account_id
    where e.shop_id = s and e.occurred_at >= p_from and e.occurred_at < p_to and (p_branch is null or e.branch_id = p_branch) and a.kind = 'tax'
    group by e.id
  ),
  net as (
    -- الصافي قبل الضريبة من البيع والتسليم الأصليين بس (زي ضريبتهم). الإلغاء والمرتجع في سطر "ضريبة مرتجعة"
    select e.source_type as src, coalesce(sum(l.credit - l.debit), 0)::bigint as v
    from tx join public.journal_entries e on e.id = tx.id
    join public.journal_lines l on l.entry_id = e.id join public.accounts a on a.id = l.account_id
    where a.kind = 'revenue' and e.reverses_id is null and e.source_type in ('sale', 'delivery') group by 1
  )
  select jsonb_build_object(
    'from', p_from, 'to', p_to, 'branch', p_branch, 'rate_bp', public.vat_bp(s),
    'sales_vat', coalesce(sum(credit) filter (where kind = 'tax' and src = 'sale' and own <> 'reversal'), 0),
    'repair_vat', coalesce(sum(credit) filter (where kind = 'tax' and src = 'delivery' and own <> 'reversal'), 0),
    -- المرتجع: إلغاء بيع أو تسليم بقيد عكسي، أو مرتجع من عميل
    'reversed_vat', coalesce(sum(debit - credit) filter (where kind = 'tax' and ((own = 'reversal' and src in ('sale', 'delivery')) or src = 'sale_return')), 0),
    'paid', coalesce(sum(debit) filter (where kind = 'tax' and src = 'vat_payment' and own <> 'reversal'), 0)
      - coalesce(sum(credit) filter (where kind = 'tax' and src = 'vat_payment' and own = 'reversal'), 0),
    'sales_net', coalesce((select v from net where src = 'sale'), 0),
    'repair_net', coalesce((select v from net where src = 'delivery'), 0),
    -- المستحق لحد آخر الفترة (صاحب المحل: كل الفروع، والموظف فرعه)
    'due', coalesce((select sum(l.credit - l.debit) from public.journal_lines l join public.journal_entries e on e.id = l.entry_id
                     join public.accounts a on a.id = l.account_id where e.shop_id = s and a.kind = 'tax' and e.occurred_at < p_to and (whole or e.branch_id = p_branch)), 0)::bigint
  ) into res from ln;
  return res;
end $$;

-- cheques_list: (src: 0063_cheques.sql)
create or replace function public.cheques_list(p_status text default null, p_branch uuid default null) returns table (
  id uuid, direction text, party_type text, party_id uuid, party_name text, cheque_no text, bank text, due_date date,
  amount bigint, status text, branch_id uuid, settled_at timestamptz, note text, created_at timestamptz)
language plpgsql stable security definer set search_path = public as $$
declare s uuid := public.current_shop_id();
begin
  perform public.grant_require('finance', 'view');
  if public.current_app_role() <> 'owner' and (p_branch is null or not public.can_branch(p_branch)) then p_branch := public.op_branch(); end if;
  return query
  select c.id, c.direction, c.party_type, c.party_id, coalesce(cu.name, sp.name), c.cheque_no, c.bank, c.due_date,
         c.amount, c.status, c.branch_id, c.settled_at, c.note, c.created_at
  from public.cheques c
  left join public.customers cu on c.party_type = 'customer' and cu.id = c.party_id
  left join public.suppliers sp on c.party_type = 'supplier' and sp.id = c.party_id
  where c.shop_id = s and c.deleted_at is null
    and (p_status is null or c.status = p_status)
    and (p_branch is null or c.branch_id = p_branch)
  order by (c.status = 'pending') desc, c.due_date, c.created_at;
end $$;

-- day_cash_report: (src: 0064_day_report.sql)
create or replace function public.day_cash_report(p_from timestamptz, p_to timestamptz, p_branch uuid default null) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare
  s uuid := public.current_shop_id();
  res jsonb;
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
        'entries', coalesce((select jsonb_agg(jsonb_build_object('entry_id', m.entry_id, 'entry_no', m.entry_no, 'source_type', m.source_type,
            'memo', m.memo, 'at', m.occurred_at, 'in', m.debit, 'out', m.credit, 'cancelled', m.cancelled) order by m.occurred_at, m.entry_no)
          from mv m where m.account_id = b.id), '[]'::jsonb)) as x
      from boxes b
      cross join lateral (select coalesce(sum(l.debit - l.credit), 0)::bigint as opening from public.journal_lines l join public.journal_entries e on e.id = l.entry_id
                          where l.account_id = b.id and e.occurred_at < p_from) o
      left join lateral (select sum(m.debit)::bigint as d, sum(m.credit)::bigint as c from mv m where m.account_id = b.id) t on true
      -- الخزنة اللي ما اتحركتش ورصيدها صفر ما بتظهرش
      where o.opening <> 0 or t.d is not null) y), '[]'::jsonb)
  ) into res;
  return res;
end $$;

-- accountant_export: (src: 0078_accountant_export.sql)
create or replace function public.accountant_export(p_from date, p_to date, p_branch uuid default null) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  s uuid := public.current_shop_id(); own boolean := public.current_app_role() = 'owner'; names boolean; res jsonb;
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
                              where l.entry_id = e.id and (a.kind in ('advances', 'salaries', 'partner_capital', 'partner_current', 'capital', 'drawings')
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

-- trial_balance: (src: 0040_branch_books.sql)
create or replace function public.trial_balance(p_branch uuid default null, p_to timestamptz default null)
returns table(account_id uuid, code text, name text, type text, kind text, debit bigint, credit bigint, balance bigint)
language plpgsql stable security definer set search_path = public as $$
#variable_conflict use_column
begin
  perform public.grant_require('finance', 'view');
  if p_branch is not null and public.current_app_role() <> 'owner' and not public.can_branch(p_branch) then raise exception 'E_FORBIDDEN'; end if;
  if p_branch is null then p_branch := public.party_branch(); end if;
  return query
  with b as (select * from public.branch_lines_raw(p_to) bl where p_branch is null or bl.branch_id = p_branch),
  t as (select b.account_id acc, sum(greatest(b.amount, 0))::bigint dr, sum(greatest(-b.amount, 0))::bigint cr from b group by 1)
  select t.acc, a.code, a.name, coalesce(a.type::text, 'inter_branch'), coalesce(a.kind, 'inter_branch'), t.dr, t.cr, (t.dr - t.cr)::bigint
  from t left join public.accounts a on a.id = t.acc
  where t.dr - t.cr <> 0 or t.acc is null and p_branch is not null
  order by case coalesce(a.type::text, 'inter_branch') when 'asset' then 1 when 'liability' then 2 when 'equity' then 3 when 'revenue' then 4 when 'expense' then 5 else 6 end, a.code nulls last, a.name;
end $$;

-- inter_branch_dues: (src: 0040_branch_books.sql)
create or replace function public.inter_branch_dues(p_to timestamptz default null)
returns table(branch_id uuid, other_id uuid, amount bigint)
language plpgsql stable security definer set search_path = public as $$
#variable_conflict use_column
declare br uuid;
begin
  perform public.grant_require('finance', 'view');
  br := public.party_branch();
  return query
  with d as (select bl.entry_id, bl.branch_id, bl.amount from public.branch_lines_raw(p_to) bl where bl.account_id is null),
  -- القيد بين فرعين: كل فرع قصاد التاني. لو أكتر من فرعين: بالنسبة (نادر جدًا)
  pairs as (
    select a.branch_id, o.branch_id other, (a.amount * abs(o.amount) / nullif((select sum(abs(z.amount)) from d z where z.entry_id = a.entry_id and z.branch_id <> a.branch_id), 0))::bigint amt
    from d a join d o on o.entry_id = a.entry_id and o.branch_id <> a.branch_id and sign(o.amount) <> sign(a.amount)
  )
  select p.branch_id, p.other, sum(p.amt)::bigint from pairs p where br is null or p.branch_id = br group by 1, 2 having sum(p.amt) <> 0 order by 1, 2;
end $$;

-- branch_lines: (src: 0040_branch_books.sql)
create or replace function public.branch_lines(p_to timestamptz default null)
returns table(entry_id uuid, occurred_at timestamptz, source_type text, branch_id uuid, account_id uuid, amount bigint)
language plpgsql stable security definer set search_path = public as $$
#variable_conflict use_column
declare br uuid;
begin
  perform public.grant_require('finance', 'view');
  br := public.party_branch();
  return query select * from public.branch_lines_raw(p_to) x where br is null or x.branch_id = br;
end $$;

-- plans_overview: (src: 0039_payment_plans.sql)
create or replace function public.plans_overview(p_party_type text default null, p_party uuid default null)
returns table(plan_id uuid, party_type text, party_id uuid, party_name text, title text, total bigint, paid bigint, remaining bigint,
              next_due date, next_amount bigint, overdue bigint, status text, created_at timestamptz, installments jsonb)
language plpgsql stable security definer set search_path = public as $$
#variable_conflict use_column
declare s uuid := public.current_shop_id(); today date := (now() at time zone 'Africa/Cairo')::date; soon integer := public.reminder_days(); br uuid;
begin
  perform public.grant_require('finance', 'view');
  br := public.party_branch();
  return query
  with pl as (
    select p.*, min(p.created_at) over (partition by p.party_type, p.party_id) first_at,
           coalesce(sum(p.total) over (partition by p.party_type, p.party_id order by p.created_at, p.id rows between unbounded preceding and 1 preceding), 0) before_total
    from public.payment_plans p
    where p.shop_id = s and p.deleted_at is null
      and (p_party_type is null or p.party_type = p_party_type) and (p_party is null or p.party_id = p_party)
  ), pool as (
    select distinct x.party_type, x.party_id, public.party_paid_since(x.party_type, x.party_id, x.first_at) amount from pl x
  ), paid as (
    select pl.*, least(pl.total, greatest(0, po.amount - pl.before_total))::bigint got
    from pl join pool po on po.party_type = pl.party_type and po.party_id = pl.party_id
  ), inst as (
    select i.plan_id, i.seq, i.due_date, i.amount,
           least(i.amount, greatest(0, pd.got - coalesce(sum(i.amount) over (partition by i.plan_id order by i.seq rows between unbounded preceding and 1 preceding), 0)))::bigint covered
    from public.plan_installments i join paid pd on pd.id = i.plan_id
    where i.deleted_at is null
  )
  select pd.id, pd.party_type, pd.party_id,
         coalesce((select c.name from public.customers c where pd.party_type = 'customer' and c.id = pd.party_id),
                  (select sp.name from public.suppliers sp where pd.party_type = 'supplier' and sp.id = pd.party_id)),
         pd.title, pd.total, pd.got, pd.total - pd.got,
         (select min(x.due_date) from inst x where x.plan_id = pd.id and x.covered < x.amount),
         (select x.amount - x.covered from inst x where x.plan_id = pd.id and x.covered < x.amount order by x.seq limit 1),
         coalesce((select sum(x.amount - x.covered) from inst x where x.plan_id = pd.id and x.covered < x.amount and x.due_date < today), 0)::bigint,
         case when pd.got >= pd.total then 'done'
              when exists (select 1 from inst x where x.plan_id = pd.id and x.covered < x.amount and x.due_date < today) then 'overdue'
              when exists (select 1 from inst x where x.plan_id = pd.id and x.covered < x.amount and x.due_date <= today + soon) then 'due_soon'
              else 'open' end,
         pd.created_at,
         coalesce((select jsonb_agg(jsonb_build_object('seq', x.seq, 'due', x.due_date, 'amount', x.amount, 'covered', x.covered,
                     'status', case when x.covered >= x.amount then 'paid' when x.due_date < today then 'overdue' when x.due_date <= today + soon then 'due_soon' else 'upcoming' end)
                     order by x.seq) from inst x where x.plan_id = pd.id), '[]'::jsonb)
  from paid pd
  -- السداد بيتوزع على كل خطط الطرف الأول، وبعدها الموظف يشوف خطط فرعه بس
  where br is null or coalesce(pd.branch_id, public.main_branch(s)) = br
  order by (pd.got >= pd.total), (select min(x.due_date) from inst x where x.plan_id = pd.id and x.covered < x.amount) nulls last, pd.created_at;
end $$;

-- cancel_plan: (src: 0039_payment_plans.sql)
create or replace function public.cancel_plan(p_id uuid) returns void
language plpgsql security definer set search_path = public as $$
begin
  perform public.grant_require('finance', 'delete');
  update public.payment_plans set deleted_at = now() where id = p_id and shop_id = public.current_shop_id() and deleted_at is null
    and (public.current_app_role() = 'owner' or public.can_branch(coalesce(branch_id, public.main_branch(shop_id))));
  if not found then raise exception 'E_NOT_FOUND'; end if;
end $$;

-- القراية المباشرة لخطط الأقساط: فروع الموظف بس
drop policy plans_select on public.payment_plans;
create policy plans_select on public.payment_plans for select to authenticated
  using (shop_id = (select public.current_shop_id()) and ((select public.current_app_role()) = 'owner'
    or ((select public.current_app_role()) = 'reception' and (select public.has_perm('finance', 'view')) and (branch_id in (select unnest(public.my_branch_ids())) or branch_id is null and (select public.all_my_branches())))));
drop policy installments_select on public.plan_installments;
create policy installments_select on public.plan_installments for select to authenticated
  using (shop_id = (select public.current_shop_id()) and exists (select 1 from public.payment_plans p where p.id = plan_id));
