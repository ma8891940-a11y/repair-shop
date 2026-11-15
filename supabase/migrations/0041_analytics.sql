-- 0041: U3: الأداء والتحليلات لكل فرع وللمحل كله، وأهداف شهرية لكل فرع.
-- كل رقم محسوب من القيود (بنسبة الفروع من 0040) ومن الأجهزة وحركات المخزون. من غير أي ذكاء اصطناعي.

create table public.branch_goals (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references public.shops(id),
  branch_id uuid not null references public.branches(id),
  month date not null check (extract(day from month) = 1),
  metric text not null check (metric in ('revenue', 'profit')),
  target bigint not null check (target > 0 and target <= 100000000000),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);
create unique index branch_goals_uq on public.branch_goals(branch_id, month, metric) where deleted_at is null;
alter table public.branch_goals enable row level security;
create trigger set_updated_at before update on public.branch_goals for each row execute function public.tg_set_updated_at();
create trigger block_delete before delete on public.branch_goals for each row execute function public.tg_block_delete();
create trigger zz_audit after insert or update on public.branch_goals for each row execute function public.tg_audit();
create policy goals_select on public.branch_goals for select to authenticated
  using (shop_id = public.current_shop_id() and (public.current_app_role() = 'owner' or (public.current_app_role() = 'reception' and (select public.has_perm('reports', 'view')) and public.can_branch(branch_id))));
grant select on public.branch_goals to authenticated;

-- هدف الشهر (صاحب المحل بس). 0 أو أقل ← بيتشال
create or replace function public.save_goal(p_branch uuid, p_month date, p_metric text, p_target bigint) returns void
language plpgsql security definer set search_path = public as $$
declare s uuid := public.current_shop_id(); m date := date_trunc('month', p_month)::date;
begin
  perform public.ledger_require(array['owner']::public.app_role[]);
  if p_metric not in ('revenue', 'profit') then raise exception 'E_BAD_INPUT'; end if;
  if not exists (select 1 from public.branches where id = p_branch and shop_id = s and deleted_at is null) then raise exception 'E_BAD_BRANCH'; end if;
  update public.branch_goals set deleted_at = now() where branch_id = p_branch and month = m and metric = p_metric and deleted_at is null;
  if coalesce(p_target, 0) > 0 then
    perform public.ledger_amount(p_target);
    insert into public.branch_goals(shop_id, branch_id, month, metric, target) values (s, p_branch, m, p_metric, p_target);
  end if;
end $$;
revoke execute on function public.save_goal(uuid, date, text, bigint) from public, anon;
grant execute on function public.save_goal(uuid, date, text, bigint) to authenticated;

-- المؤشرات لكل فرع في فترة (والمجموع بيتحسب في الواجهة من نفس الأرقام الخام، عشان النسب تطلع صح).
-- كل المبالغ بالقروش، والمدد بالدقايق، والنسب بتتحسب في الواجهة من الأعداد الخام دي.
create or replace function public.branch_kpis(p_from timestamptz, p_to timestamptz)
returns table(branch_id uuid, revenue bigint, cogs bigint, opex bigint, invoices integer, devices_in integer, devices_out integer,
              repair_minutes bigint, returns integer, stock_value bigint, stale_value bigint, stale_items integer,
              receivables bigint, receivables_60 bigint, goal_revenue bigint, goal_profit bigint)
language plpgsql stable security definer set search_path = public as $$
#variable_conflict use_column
declare s uuid := public.current_shop_id(); stale interval := interval '60 days';
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
      coalesce(sum(bl.amount) filter (where bl.type = 'expense' and bl.kind <> 'cogs' and bl.occurred_at >= p_from), 0)::bigint ox,
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
revoke execute on function public.branch_kpis(timestamptz, timestamptz) from public, anon;
grant execute on function public.branch_kpis(timestamptz, timestamptz) to authenticated;

-- الأصناف الراكدة (فيها رصيد ومحدش باعها من 60 يوم) لكل فرع، للتوصيات
create or replace function public.stale_items(p_days integer default 60)
returns table(branch_id uuid, item_id uuid, name text, qty bigint, value bigint, last_out timestamptz)
language plpgsql stable security definer set search_path = public as $$
#variable_conflict use_column
declare s uuid := public.current_shop_id();
begin
  perform public.grant_require('reports', 'view');
  return query
  select m.branch_id, i.id, i.name, sum(m.qty)::bigint, sum(m.value)::bigint, max(m.created_at) filter (where m.qty < 0)
  from public.stock_moves m join public.items i on i.id = m.item_id and i.deleted_at is null
  where m.shop_id = s and (public.all_my_branches() or public.can_branch(m.branch_id))
  group by m.branch_id, i.id, i.name
  having sum(m.qty) > 0 and coalesce(max(m.created_at) filter (where m.qty < 0), 'epoch'::timestamptz) < now() - make_interval(days => greatest(coalesce(p_days, 60), 1))
  order by 5 desc
  limit 50;
end $$;
revoke execute on function public.stale_items(integer) from public, anon;
grant execute on function public.stale_items(integer) to authenticated;
