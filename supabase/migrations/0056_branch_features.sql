-- 0056: الميزات الجديدة (C1-C8) بالفروع: كل فرع ليه بياناته وحساباته، وعرض "كل الفروع" المجمّع لصاحب المحل،
-- والموظف ما بيشوفش غير فرعه. لو المحل فرع واحد، كل ده بيشتغل على الفرع الرئيسي من غير ما يبان.
-- (الصور وسجل الـ IMEI والفحص تبع الجهاز، والجهاز أصلًا معزول بالفرع من 0034.)

-- ========== الأجهزة المستعملة ==========
-- البيع في فرع الجهاز نفسه، وبخزنة من نفس الفرع
create or replace function public.sell_used_device(p_id uuid, p_used uuid, p_price bigint, p_cashbox uuid default null, p_customer uuid default null, p_note text default null)
returns uuid
language plpgsql security definer set search_path = public as $$
declare u public.used_devices; e uuid; cb uuid;
begin
  select * into u from public.used_devices where id = p_used and shop_id = public.current_shop_id() and deleted_at is null for update;
  if not found then raise exception 'E_NOT_FOUND'; end if;
  if not public.can_branch(u.branch_id) then raise exception 'E_FORBIDDEN'; end if;
  e := public.ledger_idem(p_id);
  if e is not null then return e; end if;
  if p_cashbox is not null then
    select branch_id into cb from public.accounts where id = p_cashbox and shop_id = u.shop_id;
    if cb is distinct from u.branch_id then raise exception 'E_BAD_BRANCH'; end if;
  end if;
  perform set_config('app.branch', u.branch_id::text, true);
  perform set_config('app.used_sale', 'on', true);
  e := public.record_sale(p_id, jsonb_build_array(jsonb_build_object('item', u.item_id, 'qty', 1, 'price', p_price)), p_cashbox, p_customer, p_note);
  perform set_config('app.used_sale', 'off', true);
  update public.used_devices set sold_entry = e, sold_price = p_price, sold_customer = p_customer, sold_at = now() where id = u.id;
  return e;
end $$;

drop function if exists public.used_devices_list();
create or replace function public.used_devices_list(p_branch uuid default null)
returns table(id uuid, item_id uuid, imei text, brand text, model text, storage text, color text, condition text, branch_id uuid,
              status text, bought_at timestamptz, buy_price bigint, sale_price integer, sold_price bigint, sold_at timestamptz, profit bigint, has_seller_id boolean)
language plpgsql stable security definer set search_path = public as $$
declare amounts boolean := public.current_app_role() = 'owner' or public.has_perm('inventory', 'amounts');
begin
  if public.current_app_role() is null or public.current_app_role() = 'technician' then raise exception 'E_FORBIDDEN'; end if;
  return query
  select u.id, u.item_id, u.imei, u.brand, u.model, u.storage, u.color, u.condition, u.branch_id,
    case when q.qty > 0 then 'in_stock'
         when u.sold_entry is not null and not exists (select 1 from public.journal_entries r where r.reverses_id = u.sold_entry) then 'sold'
         else 'cancelled' end,
    u.created_at,
    case when amounts then u.buy_price end,
    i.sale_price,
    u.sold_price,
    u.sold_at,
    case when amounts and u.sold_price is not null and q.qty = 0 and not exists (select 1 from public.journal_entries r where r.reverses_id = u.sold_entry) then u.sold_price - u.buy_price end,
    u.seller_nid_secret is not null or u.seller_photo is not null
  from public.used_devices u
  join public.items i on i.id = u.item_id
  cross join lateral (select coalesce(sum(m.qty), 0)::bigint qty from public.stock_moves m where m.item_id = u.item_id) q
  where u.shop_id = public.current_shop_id() and u.deleted_at is null
    and (public.all_my_branches() or public.can_branch(u.branch_id))
    and (p_branch is null or u.branch_id = p_branch)
  order by u.created_at desc;
end $$;
revoke execute on function public.used_devices_list(uuid) from public, anon;
grant execute on function public.used_devices_list(uuid) to authenticated;

-- ========== العمولات ==========
-- قاعدة لفرع معيّن (اختياري)
alter table public.commission_rules add column if not exists branch_id uuid references public.branches(id);
drop index if exists public.commission_rules_one;
create unique index commission_rules_one on public.commission_rules(shop_id,
  coalesce(technician_id, '00000000-0000-0000-0000-000000000000'::uuid), coalesce(route_id, '00000000-0000-0000-0000-000000000000'::uuid),
  coalesce(branch_id, '00000000-0000-0000-0000-000000000000'::uuid)) where deleted_at is null;

drop function if exists public.commission_rule_for(uuid, uuid, uuid);
create or replace function public.commission_rule_for(p_shop uuid, p_tech uuid, p_route uuid, p_branch uuid) returns public.commission_rules
language sql stable security definer set search_path = public as $$
  select r.* from public.commission_rules r
  where r.shop_id = p_shop and r.deleted_at is null
    and (r.technician_id is null or r.technician_id = p_tech) and (r.route_id is null or r.route_id = p_route)
    and (r.branch_id is null or r.branch_id = p_branch)
  order by (r.technician_id is not null) desc, (r.route_id is not null) desc, (r.branch_id is not null) desc limit 1
$$;
revoke execute on function public.commission_rule_for(uuid, uuid, uuid, uuid) from public, anon, authenticated;

create or replace function public.commission_preview(p_device uuid) returns table(technician_id uuid, amount bigint)
language plpgsql stable security definer set search_path = public as $$
declare d public.devices; techs uuid[]; n int; base bigint; r public.commission_rules; t uuid; share bigint;
begin
  select * into d from public.devices where id = p_device;
  if d.id is null then return; end if;
  techs := public.device_technicians(p_device);
  n := coalesce(array_length(techs, 1), 0);
  if n = 0 then return; end if;
  base := greatest(coalesce((select c.final_cost from public.device_costs c where c.device_id = p_device and c.deleted_at is null), 0) - public.device_parts_cost(p_device), 0);
  foreach t in array techs loop
    r := public.commission_rule_for(d.shop_id, t, d.route_id, d.branch_id);
    continue when r.id is null;
    share := case when r.mode = 'fixed' then r.value else (base / n) * r.value / 10000 end;
    if share > 0 then technician_id := t; amount := share; return next; end if;
  end loop;
end $$;

-- العمولة بتتقيّد في فرع الجهاز
create or replace function public.tg_commission() returns trigger
language plpgsql security definer set search_path = public as $$
declare x record; k uuid;
begin
  if public.restoring() then return new; end if;
  if new.status <> 'delivered' or old.status = 'delivered' then return new; end if;
  for x in select * from public.commission_preview(new.id) loop
    k := md5(new.id::text || ':' || x.technician_id::text || ':commission')::uuid;
    continue when exists (select 1 from public.journal_entries j where j.idem_key = k);
    perform set_config('app.branch', new.branch_id::text, true);
    perform public.ledger_post('commission', new.id, new.order_no, jsonb_build_array(
      public.ledger_line(public.ledger_acc('exp_salaries'), x.amount, 0),
      public.ledger_line(public.ledger_acc('salaries_payable'), 0, x.amount, 'employee', x.technician_id)), new.id, k);
  end loop;
  return new;
end $$;

drop function if exists public.commissions_report(timestamptz, timestamptz);
create or replace function public.commissions_report(p_from timestamptz, p_to timestamptz, p_branch uuid default null)
returns table(technician_id uuid, full_name text, devices bigint, commission bigint, bonus bigint, penalty bigint, paid bigint, balance bigint)
language plpgsql stable security definer set search_path = public as $$
begin
  perform public.ledger_require(array['owner']::public.app_role[]);
  return query
  with l as (
    select jl.party_id pid, e.source_type st, e.reverses_id, e.id eid, e.device_id dev, e.occurred_at occ, jl.debit, jl.credit
    from public.journal_lines jl join public.journal_entries e on e.id = jl.entry_id join public.accounts a on a.id = jl.account_id
    where jl.shop_id = public.current_shop_id() and a.code = 'salaries_payable' and jl.party_type = 'employee'
      and (p_branch is null or e.branch_id = p_branch)
  ), rev as (
    select l.*, coalesce(o.source_type, l.st) kind from l left join public.journal_entries o on o.id = l.reverses_id
  )
  select p.id, p.full_name,
    (select count(distinct r.dev) from rev r where r.pid = p.id and r.kind = 'commission' and r.reverses_id is null and r.occ >= p_from and r.occ < p_to)::bigint,
    coalesce(sum(case when r.kind = 'commission' and r.occ >= p_from and r.occ < p_to then r.credit - r.debit end), 0)::bigint,
    coalesce(sum(case when r.kind = 'bonus' and r.occ >= p_from and r.occ < p_to then r.credit - r.debit end), 0)::bigint,
    coalesce(sum(case when r.kind = 'penalty' and r.occ >= p_from and r.occ < p_to then r.debit - r.credit end), 0)::bigint,
    coalesce(sum(case when r.kind = 'salary_payment' and r.occ >= p_from and r.occ < p_to then r.debit - r.credit end), 0)::bigint,
    coalesce(sum(r.credit - r.debit), 0)::bigint
  from public.profiles p
  left join rev r on r.pid = p.id
  where p.shop_id = public.current_shop_id() and p.role = 'technician'
  group by p.id, p.full_name
  order by 4 desc, p.full_name;
end $$;
revoke execute on function public.commissions_report(timestamptz, timestamptz, uuid) from public, anon;
grant execute on function public.commissions_report(timestamptz, timestamptz, uuid) to authenticated;

-- ========== قوايم الفحص: قالب للفرع بيكسب قالب المحل ==========
alter table public.check_templates add column if not exists branch_id uuid references public.branches(id);
drop index if exists public.check_templates_brand;
create unique index check_templates_brand on public.check_templates(shop_id, brand, coalesce(branch_id, '00000000-0000-0000-0000-000000000000'::uuid)) where deleted_at is null;

-- ========== الكتالوج: رابط لكل فرع (التوفر من مخزون الفرع) + رابط كل الفروع ==========
alter table public.branches add column if not exists catalog_token text unique check (catalog_token is null or length(catalog_token) = 32);

drop function if exists public.set_catalog(boolean);
create or replace function public.set_catalog(p_on boolean, p_branch uuid default null) returns text
language plpgsql security definer set search_path = public, extensions, pg_temp as $$
declare s uuid := public.current_shop_id(); t text := case when p_on then encode(gen_random_bytes(16), 'hex') end;
begin
  perform public.ledger_require(array['owner']::public.app_role[]);
  if p_branch is null then
    perform set_config('warsha.system', 'on', true);
    update public.shops set catalog_token = t where id = s;
    perform set_config('warsha.system', 'off', true);
  else
    if not exists (select 1 from public.branches where id = p_branch and shop_id = s and deleted_at is null) then raise exception 'E_BAD_BRANCH'; end if;
    update public.branches set catalog_token = t where id = p_branch;
  end if;
  return t;
end $$;
revoke execute on function public.set_catalog(boolean, uuid) from public, anon;
grant execute on function public.set_catalog(boolean, uuid) to authenticated;

-- المحل والفرع (null = كل الفروع) من الـ token
create or replace function public.catalog_target(p_token text) returns table(shop_id uuid, branch_id uuid)
language sql stable security definer set search_path = public as $$
  select s.id, null::uuid from public.shops s
   where p_token is not null and length(p_token) = 32 and s.catalog_token = p_token and s.deleted_at is null and s.suspended_at is null
  union all
  select s.id, b.id from public.branches b join public.shops s on s.id = b.shop_id
   where p_token is not null and length(p_token) = 32 and b.catalog_token = p_token and b.deleted_at is null and s.deleted_at is null and s.suspended_at is null
  limit 1
$$;
revoke execute on function public.catalog_target(text) from public, anon, authenticated;

create or replace function public.catalog_shop(p_token text) returns uuid
language sql stable security definer set search_path = public as $$
  select shop_id from public.catalog_target(p_token)
$$;

create or replace function public.public_catalog(p_token text) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare s uuid; b uuid; multi boolean;
begin
  select shop_id, branch_id into s, b from public.catalog_target(p_token);
  if s is null then return null; end if;
  multi := (select count(*) from public.branches x where x.shop_id = s and x.deleted_at is null) > 1;
  return jsonb_build_object(
    'shop', (select jsonb_build_object(
               'name', sh.name,
               -- فرع معيّن: اسمه وتليفونه (لو المحل فروع)
               'branch', case when b is not null and multi then (select br.name from public.branches br where br.id = b) end,
               'phone', coalesce(case when b is not null then (select nullif(br.phone, '') from public.branches br where br.id = b) end, sh.phone),
               'currency', sh.currency,
               'logo', (select x.logo_color from public.shop_branding x where x.shop_id = sh.id and x.deleted_at is null)) from public.shops sh where sh.id = s),
    'items', coalesce((
      select jsonb_agg(x order by x->>'kind', x->>'name') from (
        select jsonb_build_object('id', i.id, 'name', i.name, 'kind', i.kind, 'price', i.sale_price, 'image', i.image_path,
                 'in_stock', coalesce((select sum(m.qty) from public.stock_moves m where m.item_id = i.id and (b is null or m.branch_id = b)), 0) > 0,
                 'details', case when i.kind = 'used' then (select jsonb_build_object('brand', u.brand, 'model', u.model, 'storage', u.storage, 'color', u.color, 'condition', u.condition)
                                                             from public.used_devices u where u.item_id = i.id) end) x
        from public.items i
        where i.shop_id = s and i.in_catalog and i.deleted_at is null and i.sale_price is not null
          and (i.kind <> 'used' or coalesce((select sum(m.qty) from public.stock_moves m where m.item_id = i.id and (b is null or m.branch_id = b)), 0) > 0)
        limit 500) q), '[]'::jsonb));
end $$;

-- ========== بوابة الجملة: البوابة ممكن تبقى لفرع (كشف حساب الفرع وطلبياته) ==========
alter table public.customers add column if not exists portal_branch uuid references public.branches(id);
alter table public.wholesale_orders add column if not exists branch_id uuid references public.branches(id);

drop function if exists public.set_portal(uuid, boolean);
create or replace function public.set_portal(p_customer uuid, p_on boolean, p_branch uuid default null) returns text
language plpgsql security definer set search_path = public, extensions, pg_temp as $$
declare s uuid := public.current_shop_id(); t text := case when p_on then encode(gen_random_bytes(16), 'hex') end; b uuid := p_branch;
begin
  perform public.ledger_require(array['owner', 'reception']::public.app_role[]);
  perform public.perm_require('customers', 'edit');
  if not exists (select 1 from public.customers where id = p_customer and shop_id = s and deleted_at is null) then raise exception 'E_NOT_FOUND'; end if;
  -- الموظف اللي مش معاه كل الفروع: البوابة لفرعه هو بس
  if not public.all_my_branches() then b := public.op_branch(); end if;
  if b is not null and not exists (select 1 from public.branches where id = b and shop_id = s and deleted_at is null) then raise exception 'E_BAD_BRANCH'; end if;
  update public.customers set portal_token = t, portal_branch = case when p_on then b end where id = p_customer;
  return t;
end $$;
revoke execute on function public.set_portal(uuid, boolean, uuid) from public, anon;
grant execute on function public.set_portal(uuid, boolean, uuid) to authenticated;

create or replace function public.public_portal(p_token text) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare c public.customers := public.portal_customer(p_token); b uuid; multi boolean;
begin
  if c.id is null then return null; end if;
  b := c.portal_branch;
  multi := (select count(*) from public.branches x where x.shop_id = c.shop_id and x.deleted_at is null) > 1;
  return jsonb_build_object(
    'shop', (select jsonb_build_object('name', sh.name, 'currency', sh.currency,
               'branch', case when b is not null and multi then (select br.name from public.branches br where br.id = b) end,
               'phone', coalesce(case when b is not null then (select nullif(br.phone, '') from public.branches br where br.id = b) end, sh.phone),
               'logo', (select x.logo_color from public.shop_branding x where x.shop_id = sh.id and x.deleted_at is null)) from public.shops sh where sh.id = c.shop_id),
    'customer', jsonb_build_object('name', c.name),
    'balance', (select coalesce(sum(l.debit - l.credit), 0)::bigint from public.journal_lines l join public.accounts a on a.id = l.account_id join public.journal_entries e on e.id = l.entry_id
                where l.shop_id = c.shop_id and l.party_type = 'customer' and l.party_id = c.id and a.kind = 'receivable' and (b is null or e.branch_id = b)),
    'entries', coalesce((select jsonb_agg(x order by x->>'at' desc) from (
        select jsonb_build_object('at', e.occurred_at, 'type', e.source_type, 'no', e.entry_no, 'debit', sum(l.debit), 'credit', sum(l.credit)) x
        from public.journal_lines l join public.journal_entries e on e.id = l.entry_id join public.accounts a on a.id = l.account_id
        where l.shop_id = c.shop_id and l.party_type = 'customer' and l.party_id = c.id and a.kind = 'receivable' and (b is null or e.branch_id = b)
        group by e.id order by e.occurred_at desc limit 100) q), '[]'::jsonb),
    'orders', coalesce((select jsonb_agg(jsonb_build_object('id', o.id, 'at', o.created_at, 'status', o.status, 'lines', o.lines, 'note', o.note) order by o.created_at desc)
                        from (select * from public.wholesale_orders w where w.customer_id = c.id and w.deleted_at is null and (b is null or w.branch_id = b) order by w.created_at desc limit 20) o), '[]'::jsonb),
    'items', coalesce((select jsonb_agg(jsonb_build_object('id', i.id, 'name', i.name, 'price', i.sale_price) order by i.name)
                       from public.items i where i.shop_id = c.shop_id and i.in_catalog and i.deleted_at is null and i.kind <> 'used' and i.sale_price is not null), '[]'::jsonb));
end $$;

create or replace function public.portal_order(p_token text, p_lines jsonb, p_note text default null) returns uuid
language plpgsql security definer set search_path = public as $$
declare c public.customers := public.portal_customer(p_token); l jsonb; out jsonb := '[]'::jsonb; it public.items; q int; id uuid := gen_random_uuid();
begin
  if c.id is null then raise exception 'E_NOT_FOUND'; end if;
  if jsonb_typeof(p_lines) <> 'array' or jsonb_array_length(p_lines) not between 1 and 50 then raise exception 'E_BAD_INPUT'; end if;
  if (select count(*) from public.wholesale_orders w where w.customer_id = c.id and w.created_at > now() - interval '1 day') >= 20 then raise exception 'E_TOO_MANY'; end if;
  for l in select * from jsonb_array_elements(p_lines) loop
    select * into it from public.items i where i.id = (l ->> 'item')::uuid and i.shop_id = c.shop_id and i.in_catalog and i.deleted_at is null and i.kind <> 'used';
    if it.id is null then raise exception 'E_NOT_FOUND'; end if;
    q := (l ->> 'qty')::int;
    if q is null or q < 1 or q > 10000 then raise exception 'E_BAD_AMOUNT'; end if;
    out := out || jsonb_build_array(jsonb_build_object('item', it.id, 'name', it.name, 'qty', q));
  end loop;
  perform set_config('warsha.system', 'on', true);
  insert into public.wholesale_orders(id, shop_id, customer_id, branch_id, lines, note) values (id, c.shop_id, c.id, c.portal_branch, out, nullif(trim(left(p_note, 500)), ''));
  perform set_config('warsha.system', 'off', true);
  return id;
exception when invalid_text_representation then raise exception 'E_BAD_INPUT';
end $$;

-- الطلبيات: الموظف بيشوف طلبيات فرعه بس (وطلبيات "كل الفروع" لصاحب كل الفروع)
drop policy if exists wholesale_orders_select on public.wholesale_orders;
drop policy if exists wholesale_orders_update on public.wholesale_orders;
create policy wholesale_orders_select on public.wholesale_orders for select to authenticated
  using (shop_id = public.current_shop_id() and public.current_app_role() in ('owner', 'reception')
         and (public.all_my_branches() or public.can_branch(branch_id)));
create policy wholesale_orders_update on public.wholesale_orders for update to authenticated
  using (shop_id = public.current_shop_id() and public.current_app_role() in ('owner', 'reception')
         and (public.all_my_branches() or public.can_branch(branch_id)));

-- ========== التحليلات بالفرع ==========
drop function if exists public.parts_profit(timestamptz, timestamptz);
create or replace function public.parts_profit(p_from timestamptz, p_to timestamptz, p_branch uuid default null)
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
      and (p_branch is null or d.branch_id = p_branch)
  ), per as (
    select u.item_id, sum(u.q)::bigint uses, count(distinct u.device_id)::bigint devs, sum(u.v)::bigint cost from used u group by u.item_id
  )
  select p.item_id, i.name, p.uses, p.devs, p.cost,
    (select coalesce(sum(c.final_cost), 0)::bigint from public.device_costs c
      where c.deleted_at is null and c.device_id in (select distinct u.device_id from used u where u.item_id = p.item_id))
  from per p join public.items i on i.id = p.item_id
  order by p.cost desc limit 30;
end $$;
revoke execute on function public.parts_profit(timestamptz, timestamptz, uuid) from public, anon;
grant execute on function public.parts_profit(timestamptz, timestamptz, uuid) to authenticated;

drop function if exists public.items_usage30();
create or replace function public.items_usage30(p_branch uuid default null) returns table(item_id uuid, used bigint)
language plpgsql stable security definer set search_path = public as $$
#variable_conflict use_column
begin
  perform public.grant_require('reports', 'view');
  return query
  select m.item_id, (-sum(m.qty))::bigint
  from public.stock_moves m join public.journal_entries e on e.id = m.entry_id
  where e.shop_id = public.current_shop_id() and m.qty < 0 and e.source_type in ('sale', 'part_use')
    and e.occurred_at >= now() - interval '30 days'
    and not exists (select 1 from public.journal_entries r where r.reverses_id = e.id)
    and (public.all_my_branches() or public.can_branch(m.branch_id))
    and (p_branch is null or m.branch_id = p_branch)
  group by m.item_id;
end $$;
revoke execute on function public.items_usage30(uuid) from public, anon;
grant execute on function public.items_usage30(uuid) to authenticated;

-- ========== تيليجرام: اسم الفرع في الرسالة لو المحل فروع ==========
create or replace function public.tg_telegram_device() returns trigger
language plpgsql security definer set search_path = public as $$
declare ev text; txt text; amt bigint; br text;
begin
  if public.restoring() then return new; end if;
  if not exists (select 1 from public.shop_telegram t where t.shop_id = new.shop_id and t.enabled) then return new; end if;
  if (select count(*) from public.branches x where x.shop_id = new.shop_id and x.deleted_at is null) > 1 then
    select ' [' || b.name || ']' into br from public.branches b where b.id = new.branch_id;
  end if;
  if tg_op = 'INSERT' then
    ev := 'intake'; txt := 'جهاز جديد ' || coalesce(new.order_no, '') || ': ' || new.brand || ' ' || new.model || ' (' || left(coalesce(new.issue, ''), 80) || ')';
  elsif new.status is distinct from old.status and new.status = 'ready' then
    ev := 'ready'; txt := 'جاهز للتسليم ' || coalesce(new.order_no, '') || ': ' || new.brand || ' ' || new.model;
  elsif new.status is distinct from old.status and new.status = 'delivered' then
    select c.final_cost into amt from public.device_costs c where c.device_id = new.id and c.deleted_at is null;
    ev := 'delivered'; txt := 'اتسلّم ' || coalesce(new.order_no, '') || ': ' || new.brand || ' ' || new.model || coalesce(' · ' || to_char(amt / 100.0, 'FM999,999,990.00'), '');
  else
    return new;
  end if;
  perform public.telegram_send(new.shop_id, ev, txt || coalesce(br, ''));
  return new;
end $$;
