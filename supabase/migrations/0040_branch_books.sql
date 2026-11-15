-- 0040: U2: كل فرع مستقل ماليًا (التطوير الكبير).
-- الدفتر واحد للمحل والقيود ما بتتغيرش خالص. كل سطر بيتنسب لفرع:
--   - الخزنة (kind = cash) ← فرع الخزنة نفسها.
--   - المخزون ← فرع حركة المخزون بتاعة نفس القيد (التحويل بين فرعين: الخارج من فرع والداخل للتاني).
--   - أي حساب تاني ← فرع القيد.
-- القيد اللي لمس فرعين (تحويل فلوس أو بضاعة) بيتولد له سطر محسوب "مستحق من فرع / مستحق لفرع" في كل فرع،
-- بحيث كل فرع يقفل متوازن لوحده، والمستحقات تلغي بعض في المجموع (مجموع المحل زي ما هو بالظبط).

-- السطور منسوبة للفروع: amount = مدين − دائن. account_id = null ← سطر "مستحق بين الفروع"
create or replace function public.branch_lines(p_to timestamptz default null)
returns table(entry_id uuid, occurred_at timestamptz, source_type text, branch_id uuid, account_id uuid, amount bigint)
language plpgsql stable security definer set search_path = public as $$
#variable_conflict use_column
declare s uuid := public.current_shop_id(); inv uuid;
begin
  perform public.grant_require('finance', 'view');
  select a.id into inv from public.accounts a where a.shop_id = s and a.code = 'inventory' and a.deleted_at is null limit 1;
  return query
  with en as (
    select e.id, e.branch_id, e.occurred_at, e.source_type from public.journal_entries e
    where e.shop_id = s and (p_to is null or e.occurred_at < p_to)
  ), raw as (
    -- كل الحسابات غير المخزون
    select l.entry_id, coalesce(case when a.kind = 'cash' then a.branch_id end, en.branch_id) br, l.account_id acc, (l.debit - l.credit)::bigint amt
    from public.journal_lines l join en on en.id = l.entry_id join public.accounts a on a.id = l.account_id
    where l.account_id is distinct from inv
    union all
    -- المخزون: بفرع حركة المخزون
    select m.entry_id, m.branch_id, inv, sum(m.value)::bigint
    from public.stock_moves m join en on en.id = m.entry_id
    group by m.entry_id, m.branch_id
    union all
    -- لو سطر المخزون في القيد مش متغطي بحركات (نادر): الفرق على فرع القيد، عشان ولا قرش يضيع
    select en.id, en.branch_id, inv,
           (coalesce((select sum(l.debit - l.credit) from public.journal_lines l where l.entry_id = en.id and l.account_id = inv), 0)
            - coalesce((select sum(m.value) from public.stock_moves m where m.entry_id = en.id), 0))::bigint
    from en
  ), agg as (
    select r.entry_id, r.br, r.acc, sum(r.amt)::bigint amt from raw r group by 1, 2, 3 having sum(r.amt) <> 0
  ), due as (
    select a.entry_id, a.br, null::uuid acc, (-sum(a.amt))::bigint amt from agg a group by 1, 2 having sum(a.amt) <> 0
  )
  select x.entry_id, en.occurred_at, en.source_type, x.br, x.acc, x.amt
  from (select * from agg union all select * from due) x join en on en.id = x.entry_id
  -- الموظف: فروعه بس
  where public.all_my_branches() or public.can_branch(x.br);
end $$;
revoke execute on function public.branch_lines(timestamptz) from public, anon;
grant execute on function public.branch_lines(timestamptz) to authenticated;

-- ميزان المراجعة: لفرع (p_branch) أو موحّد (null). كل فرع بيقفل متوازن لوحده (مجموع الأرصدة = صفر)،
-- والموحّد ما فيهوش مستحقات (بتلغي بعض)
create or replace function public.trial_balance(p_branch uuid default null, p_to timestamptz default null)
returns table(account_id uuid, code text, name text, type text, kind text, debit bigint, credit bigint, balance bigint)
language plpgsql stable security definer set search_path = public as $$
#variable_conflict use_column
begin
  perform public.grant_require('finance', 'view');
  if p_branch is not null and not public.all_my_branches() and not public.can_branch(p_branch) then raise exception 'E_FORBIDDEN'; end if;
  if p_branch is null and not public.all_my_branches() then p_branch := public.op_branch(); end if;
  return query
  with b as (select * from public.branch_lines(p_to) bl where p_branch is null or bl.branch_id = p_branch),
  t as (select b.account_id acc, sum(greatest(b.amount, 0))::bigint dr, sum(greatest(-b.amount, 0))::bigint cr from b group by 1)
  select t.acc, a.code, a.name, coalesce(a.type::text, 'inter_branch'), coalesce(a.kind, 'inter_branch'), t.dr, t.cr, (t.dr - t.cr)::bigint
  from t left join public.accounts a on a.id = t.acc
  where t.dr - t.cr <> 0 or t.acc is null and p_branch is not null
  order by case coalesce(a.type::text, 'inter_branch') when 'asset' then 1 when 'liability' then 2 when 'equity' then 3 when 'revenue' then 4 when 'expense' then 5 else 6 end, a.code nulls last, a.name;
end $$;
revoke execute on function public.trial_balance(uuid, timestamptz) from public, anon;
grant execute on function public.trial_balance(uuid, timestamptz) to authenticated;

-- المستحقات بين كل فرعين: موجب = الفرع ده ليه عند التاني (مستحق من)، سالب = عليه (مستحق لـ)
create or replace function public.inter_branch_dues(p_to timestamptz default null)
returns table(branch_id uuid, other_id uuid, amount bigint)
language plpgsql stable security definer set search_path = public as $$
#variable_conflict use_column
begin
  perform public.grant_require('finance', 'view');
  return query
  with d as (select bl.entry_id, bl.branch_id, bl.amount from public.branch_lines(p_to) bl where bl.account_id is null),
  -- القيد بين فرعين: كل فرع قصاد التاني. لو أكتر من فرعين: بالنسبة (نادر جدًا)
  pairs as (
    select a.branch_id, o.branch_id other, (a.amount * abs(o.amount) / nullif((select sum(abs(z.amount)) from d z where z.entry_id = a.entry_id and z.branch_id <> a.branch_id), 0))::bigint amt
    from d a join d o on o.entry_id = a.entry_id and o.branch_id <> a.branch_id and sign(o.amount) <> sign(a.amount)
  )
  select p.branch_id, p.other, sum(p.amt)::bigint from pairs p group by 1, 2 having sum(p.amt) <> 0 order by 1, 2;
end $$;
revoke execute on function public.inter_branch_dues(timestamptz) from public, anon;
grant execute on function public.inter_branch_dues(timestamptz) to authenticated;
