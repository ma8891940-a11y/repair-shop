-- 0084: (قرار صاحب المشروع 2026-11-24) أرصدة العملاء والموردين للموظف اللي معاه "الوضع المالي": فرعه بس، حتى لو معاه كل الفروع. صاحب المحل بس اللي يشوف المحل كله.
-- نفس القاعدة في الأرصدة، وكشف حساب العميل والمورد والمربوطين، وأعمار المديونية، عشان الأرقام تطابق.

-- null = المحل كله (صاحب المحل)
create or replace function public.party_branch() returns uuid
language plpgsql stable security definer set search_path = public as $$
declare b uuid;
begin
  if public.current_app_role() = 'owner' then return null; end if;
  b := public.op_branch();
  if b is null then raise exception 'E_FORBIDDEN'; end if;
  return b;
end $$;
revoke execute on function public.party_branch() from public, anon, authenticated;

-- party_balances: (src: 0038_roles_grant.sql)
create or replace function public.party_balances(p_kind text)
returns table(party_type text, party_id uuid, name text, account text, balance bigint, oldest timestamptz)
language plpgsql stable security definer set search_path = public as $$
#variable_conflict use_column
declare s uuid := public.current_shop_id(); br uuid := public.party_branch();
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

-- statement: (src: 0038_roles_grant.sql)
create or replace function public.statement(p_kind text, p_id uuid, p_from timestamptz, p_to timestamptz) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare
  s uuid := public.current_shop_id();
  accs uuid[];
  parties uuid[] := array[p_id];
  lk public.party_links;
  opening bigint;
  br uuid; -- كشف العميل والمورد للموظف: فرعه بس. الخزنة ليها فحصها
  res jsonb;
begin
  perform public.grant_require('finance', 'view');
  -- المرتبات والشركاء لصاحب المحل بس، والخزنة لازم تكون في فروع الموظف
  if public.current_app_role() <> 'owner' and (p_kind in ('employee', 'partner')
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
    select e.id as entry_id, e.entry_no, e.occurred_at, e.source_type, e.source_id, e.device_id, e.memo, e.reverses_id,
           d.order_no, p.full_name as by_name, a.code as account_code,
           ((l.debit - l.credit) * (case when p_kind = 'linked' then 1 else public.account_sign(a.type) end))::bigint as amount
    from public.journal_lines l
    join public.accounts a on a.id = l.account_id
    join public.journal_entries e on e.id = l.entry_id
    left join public.devices d on d.id = e.device_id
    left join public.profiles p on p.id = e.created_by
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

-- debt_aging: (src: 0076_debt_aging.sql)
create or replace function public.debt_aging(p_kind text, p_as_of date default null, p_branch uuid default null)
returns table(party_id uuid, name text, balance bigint, d0 bigint, d30 bigint, d60 bigint, oldest date, as_of date)
language plpgsql stable security definer set search_path = public as $$
#variable_conflict use_column
declare s uuid := public.current_shop_id(); today date := (now() at time zone 'Africa/Cairo')::date; d date := coalesce(p_as_of, today);
  upto timestamptz := (d + 1)::timestamp at time zone 'Africa/Cairo';  -- أول لحظة بعد التاريخ
begin
  perform public.grant_require('finance', 'view');
  if p_kind is null or p_kind not in ('customers', 'suppliers') then raise exception 'E_BAD_INPUT'; end if;
  if d > today then raise exception 'E_BAD_INPUT'; end if;
  -- الموظف: فرع واحد من فروعه، حتى لو طلب غيره. المحل كله لصاحب المحل بس
  if public.current_app_role() <> 'owner' and (p_branch is null or not public.can_branch(p_branch)) then
    p_branch := public.op_branch();
    if p_branch is null then raise exception 'E_FORBIDDEN'; end if;
  end if;
  return query
  with ent as (
    select e.id, e.entry_no, e.occurred_at, (e.occurred_at at time zone 'Africa/Cairo')::date as day
    from public.journal_entries e
    where e.shop_id = s and e.occurred_at < upto and (p_branch is null or e.branch_id = p_branch)
      and e.reverses_id is null
      and not exists (select 1 from public.journal_entries r where r.reverses_id = e.id and r.occurred_at < upto)
  ),
  raw as (
    select l.party_id, ent.id as entry_id, ent.day, ent.occurred_at, ent.entry_no, l.id as line_id,
           (case when p_kind = 'customers' then l.debit else l.credit end)::bigint as plus,
           (case when p_kind = 'customers' then l.credit else l.debit end)::bigint as minus
    from ent join public.journal_lines l on l.entry_id = ent.id join public.accounts a on a.id = l.account_id
    where l.party_id is not null and a.kind = case when p_kind = 'customers' then 'receivable' else 'payable' end
  ),
  -- مرتجع بفاتورة من بيع آجل: بيقلّل دين البيع نفسه (مش الأقدم)
  ret as (
    select distinct x.line_id, sale.line_id as sale_line
    from raw x join public.sale_lines rl on rl.entry_id = x.entry_id join public.sale_lines b on b.id = rl.return_of
    join raw sale on sale.entry_id = b.entry_id and sale.party_id = x.party_id and sale.plus > 0
    where p_kind = 'customers' and x.minus > 0
  ),
  ln as (
    select x.party_id, x.day, x.occurred_at, x.entry_no, x.line_id,
           x.plus - coalesce((select sum(q.minus) from ret join raw q on q.line_id = ret.line_id where ret.sale_line = x.line_id), 0)::bigint as plus,
           case when exists (select 1 from ret where ret.line_id = x.line_id) then 0 else x.minus end as minus
    from raw x
  ),
  paid as (select ln.party_id, sum(ln.minus) as m, sum(ln.plus) as p from ln group by 1 having sum(ln.plus) > sum(ln.minus)),
  cum as (
    select ln.party_id, ln.day, least(ln.plus, greatest(0, sum(ln.plus) over (partition by ln.party_id order by ln.occurred_at, ln.entry_no, ln.line_id) - paid.m))::bigint as open
    from ln join paid on paid.party_id = ln.party_id where ln.plus > 0
  )
  select c.party_id, coalesce(cu.name, sp.name), sum(c.open)::bigint,
         coalesce(sum(c.open) filter (where d - c.day < 30), 0)::bigint,
         coalesce(sum(c.open) filter (where d - c.day between 30 and 59), 0)::bigint,
         coalesce(sum(c.open) filter (where d - c.day >= 60), 0)::bigint,
         min(c.day) filter (where c.open > 0), d
  from cum c
  left join public.customers cu on p_kind = 'customers' and cu.id = c.party_id
  left join public.suppliers sp on p_kind = 'suppliers' and sp.id = c.party_id
  group by c.party_id, coalesce(cu.name, sp.name)
  order by 6 desc, 5 desc, 3 desc;
end $$;
