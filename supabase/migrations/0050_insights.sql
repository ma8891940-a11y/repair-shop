-- 0050: C6: تحليلات إضافية: أكتر الأعطال لكل موديل، والقطع اللي بتاكل الربح، والصرف لتوقع نفاد المخزون.
-- (متوسط وقت الإصلاح لكل فني موجود أصلًا في tech_report.) كله محسوب من البيانات والقيود، ومن غير بيانات عملاء.

-- أكتر الأعطال لكل موديل: نوع العطل (المسار) لو متحدد، وإلا وصف العطل زي ما اتكتب
create or replace function public.faults_by_model(p_from timestamptz, p_to timestamptz, p_branch uuid default null)
returns table(brand text, model text, route_code text, route_name text, issue text, devices integer, returns integer)
language plpgsql stable security definer set search_path = public as $$
#variable_conflict use_column
begin
  perform public.grant_require('reports', 'view');
  return query
  select d.brand, d.model, r.code, r.name,
    case when d.route_id is null then lower(trim(left(d.issue, 80))) end,
    count(*)::int,
    count(*) filter (where d.priority = 'warranty' or d.return_of_tech is not null)::int
  from public.devices d left join public.routes r on r.id = d.route_id
  where d.shop_id = public.current_shop_id() and d.deleted_at is null and d.received_at >= p_from and d.received_at < p_to
    and (p_branch is null or d.branch_id = p_branch) and (public.all_my_branches() or public.can_branch(d.branch_id))
  group by d.brand, d.model, r.code, r.name, case when d.route_id is null then lower(trim(left(d.issue, 80))) end
  order by 6 desc, 1, 2 limit 40;
end $$;
revoke execute on function public.faults_by_model(timestamptz, timestamptz, uuid) from public, anon;
grant execute on function public.faults_by_model(timestamptz, timestamptz, uuid) to authenticated;

-- القطع اللي بتاكل الربح: لكل قطعة اتركبت في أجهزة اتسلّمت في الفترة: تكلفتها، وإيراد الأجهزة دي، ونسبتها (صاحب المحل)
create or replace function public.parts_profit(p_from timestamptz, p_to timestamptz)
returns table(item_id uuid, name text, uses bigint, devices bigint, cost bigint, revenue bigint)
language plpgsql stable security definer set search_path = public as $$
#variable_conflict use_column
begin
  perform public.ledger_require(array['owner']::public.app_role[]);
  return query
  with used as (
    select m.item_id, e.device_id, (-m.qty)::bigint q, (-m.value)::bigint v
    from public.stock_moves m join public.journal_entries e on e.id = m.entry_id
    join public.devices d on d.id = e.device_id
    where e.shop_id = public.current_shop_id() and e.source_type = 'part_use' and m.qty < 0
      and not exists (select 1 from public.journal_entries x where x.reverses_id = e.id)
      and d.status = 'delivered' and d.delivered_at >= p_from and d.delivered_at < p_to and d.deleted_at is null
  ), per as (
    select u.item_id, sum(u.q)::bigint uses, count(distinct u.device_id)::bigint devs, sum(u.v)::bigint cost from used u group by u.item_id
  )
  select p.item_id, i.name, p.uses, p.devs, p.cost,
    (select coalesce(sum(c.final_cost), 0)::bigint from public.device_costs c
      where c.deleted_at is null and c.device_id in (select distinct u.device_id from used u where u.item_id = p.item_id))
  from per p join public.items i on i.id = p.item_id
  order by p.cost desc limit 30;
end $$;
revoke execute on function public.parts_profit(timestamptz, timestamptz) from public, anon;
grant execute on function public.parts_profit(timestamptz, timestamptz) to authenticated;

-- الصرف الفعلي في آخر 30 يوم (بيع + قطع اتركبت، من غير التحويلات بين الفروع والهالك والمعكوس)
create or replace function public.items_usage30() returns table(item_id uuid, used bigint)
language plpgsql stable security definer set search_path = public as $$
#variable_conflict use_column
begin
  perform public.grant_require('reports', 'view', true);
  return query
  select m.item_id, (-sum(m.qty))::bigint
  from public.stock_moves m join public.journal_entries e on e.id = m.entry_id
  where e.shop_id = public.current_shop_id() and m.qty < 0 and e.source_type in ('sale', 'part_use')
    and e.occurred_at >= now() - interval '30 days'
    and not exists (select 1 from public.journal_entries r where r.reverses_id = e.id)
  group by m.item_id;
end $$;
revoke execute on function public.items_usage30() from public, anon;
grant execute on function public.items_usage30() to authenticated;
