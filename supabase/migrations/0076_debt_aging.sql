-- 0076: (5) أعمار المديونية: رصيد كل عميل أو مورد متقسم على عمر العملية اللي عملته (0–29، 30–59، 60 يوم أو أكتر).
-- - من القيود بس، لحد تاريخ معيّن (as-of) بتوقيت القاهرة. مفيش رصيد متخزن.
-- - الدفعة والمرتجع بيغطوا الأقدم الأول (زي party_balances). القيد الملغي وعكسه بيتشالوا الاتنين، فإلغاء بيع جديد ما يغطيش دين قديم.
-- - اللي رصيده صفر أو ليه فلوس عندنا مش في الكشف. مجموع الشرايح = الرصيد بالظبط.
create or replace function public.debt_aging(p_kind text, p_as_of date default null, p_branch uuid default null)
returns table(party_id uuid, name text, balance bigint, d0 bigint, d30 bigint, d60 bigint, oldest date, as_of date)
language plpgsql stable security definer set search_path = public as $$
#variable_conflict use_column
declare s uuid := public.current_shop_id(); d date := coalesce(p_as_of, (now() at time zone 'Africa/Cairo')::date);
begin
  perform public.grant_require('finance', 'view');
  if p_kind is null or p_kind not in ('customers', 'suppliers') then raise exception 'E_BAD_INPUT'; end if;
  if not public.all_my_branches() and (p_branch is null or not public.can_branch(p_branch)) then
    p_branch := public.op_branch();
    if p_branch is null then raise exception 'E_FORBIDDEN'; end if;
  end if;
  return query
  with ent as (
    select e.id, e.entry_no, e.occurred_at, (e.occurred_at at time zone 'Africa/Cairo')::date as day
    from public.journal_entries e
    where e.shop_id = s and (e.occurred_at at time zone 'Africa/Cairo')::date <= d and (p_branch is null or e.branch_id = p_branch)
      and e.reverses_id is null
      and not exists (select 1 from public.journal_entries r where r.reverses_id = e.id and (r.occurred_at at time zone 'Africa/Cairo')::date <= d)
  ),
  ln as (
    select l.party_id, ent.day, ent.occurred_at, ent.entry_no, l.id as line_id,
           (case when p_kind = 'customers' then l.debit else l.credit end)::bigint as plus,
           (case when p_kind = 'customers' then l.credit else l.debit end)::bigint as minus
    from ent join public.journal_lines l on l.entry_id = ent.id join public.accounts a on a.id = l.account_id
    where l.party_id is not null and a.kind = case when p_kind = 'customers' then 'receivable' else 'payable' end
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
revoke execute on function public.debt_aging(text, date, uuid) from public, anon;
grant execute on function public.debt_aging(text, date, uuid) to authenticated;
