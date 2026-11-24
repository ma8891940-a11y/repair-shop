-- 0078: (4) تصدير للمحاسب: كل القيود بسطورها، والمدفوعات، وسطور البيع، لفترة وفرع. المبالغ بالقروش، ومجموع المدين = مجموع الدائن.
-- - صلاحية "يصدّر" في الوضع المالي. الموظف فرعه بس، ومن غير قيود المرتبات والسلف والشركاء ورأس المال، ولا تحويل لخزنة فرع تاني (restricted = true).
-- - sales = سطور البيع بأسعارها شاملة الضريبة (المرتجع بالسالب)، ومش بديل القيود: المرتجع من غير فاتورة والصيانة في lines بس.
-- - الأيام بتوقيت القاهرة، من وإلى داخلين. وكل تصدير في سجل النشاط.
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
  if not public.all_my_branches() and (p_branch is null or not public.can_branch(p_branch)) then
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
revoke execute on function public.accountant_export(date, date, uuid) from public, anon;
grant execute on function public.accountant_export(date, date, uuid) to authenticated;
