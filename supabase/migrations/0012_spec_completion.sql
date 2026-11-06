-- استكمال المراحل 1-3 حسب docs/spec.pdf (المراجعة يوم 2026-11-06)
--
-- 1) صفحة التتبع بتعرض المتبقي.
-- 2) التسليم بالآجل بيتسجل في سجل النشاط باسم صاحب المحل اللي وافق.
-- 3) كل قطعة بمصدرها: المورد وتاريخ الشراء وسعره (حتى في الشراء النقدي)، ومقارنة أسعار الموردين.
-- 4) حد أدنى لكل صنف وقائمة النواقص.
-- 5) قائمة المدينين بأقدم دين.
-- 6) القطع المستبدلة في الجهاز (للفاتورة) من غير تكاليف.
-- 7) التسعير: هامش الربح وأجرة كل نوع عطل من الإعدادات، والسعر المقترح للاستقبال من غير ما تشوف التكلفة.
-- 8) توقيع العميل على الشاشة عند الاستلام.

-- ---------- 1) التتبع ----------
drop function if exists public.get_tracking(text, text, text);
create or replace function public.get_tracking(p_order text default null, p_last4 text default null, p_token text default null)
returns table(
  order_no text, status public.device_status, brand text, model text, received_at timestamptz,
  updated_at timestamptz, estimated_cost integer, final_cost integer, technician text,
  shop_name text, shop_phone text, shop_logo text, currency text, warranty_until timestamptz,
  can_decide boolean, decision text, due bigint
)
language plpgsql security definer set search_path = public as $$
declare
  k text := public.tracking_guard(p_order);
  d public.devices;
begin
  d := public.tracking_find(p_order, p_last4, p_token);
  if d.id is null then
    -- مش بنرمي خطأ هنا عشان المحاولة الغلط تفضل متسجلة (الخطأ بيلغي التسجيل). النتيجة الفاضية = مش موجود
    insert into public.tracking_attempts(client_key, order_no, success, guess) values (k, trim(p_order), false, public.tracking_guess(p_order, p_last4));
    return;
  end if;
  insert into public.tracking_attempts(shop_id, client_key, order_no, success) values (d.shop_id, k, d.order_no, true);
  return query
  select d.order_no, d.status, d.brand, d.model, d.received_at,
    coalesce((select max(l.created_at) from public.status_log l where l.device_id = d.id), d.updated_at),
    dc.estimated_cost, dc.final_cost,
    -- اسم الفني: آخر فني غيّر الحالة (الاسم الأول بس)
    (select split_part(p.full_name, ' ', 1) from public.status_log l join public.profiles p on p.id = l.changed_by
       where l.device_id = d.id and p.role = 'technician' order by l.created_at desc limit 1),
    s.name, s.phone, s.logo_path, s.currency, d.warranty_until,
    d.status = 'awaiting_approval' and not exists (
      select 1 from public.quote_decisions q where q.device_id = d.id and q.created_at > coalesce(
        (select max(l.created_at) from public.status_log l where l.device_id = d.id and l.new_status = 'awaiting_approval'), d.received_at)),
    (select q.decision from public.quote_decisions q where q.device_id = d.id order by q.created_at desc limit 1),
    -- المتبقي على العميل للجهاز ده (بعد التكلفة النهائية بس)
    case when dc.final_cost is not null then greatest(dc.final_cost - public.device_paid(d.id), 0)::bigint end
  from public.shops s
  left join public.device_costs dc on dc.device_id = d.id and dc.deleted_at is null
  where s.id = d.shop_id;
end $$;
revoke execute on function public.get_tracking(text, text, text) from public;
grant execute on function public.get_tracking(text, text, text) to anon, authenticated;

-- ---------- 2) التسليم بالآجل في السجل ----------
create or replace function public.deliver_on_credit(p_device uuid) returns void
language plpgsql security definer set search_path = public as $$
declare due bigint;
begin
  perform public.ledger_require(array['owner']::public.app_role[]);
  select greatest(coalesce(c.final_cost, 0) - public.device_paid(p_device), 0) into due
  from public.devices d left join public.device_costs c on c.device_id = d.id and c.deleted_at is null
  where d.id = p_device and d.shop_id = public.current_shop_id();
  if not found then raise exception 'E_NOT_FOUND'; end if;
  perform set_config('warsha.credit_ok', p_device::text, true);
  update public.devices set status = 'delivered' where id = p_device and shop_id = public.current_shop_id();
  perform set_config('warsha.credit_ok', '', true);
  insert into public.audit_log(shop_id, actor_id, action, entity, entity_id, after)
  values (public.current_shop_id(), auth.uid(), 'deliver_on_credit', 'devices', p_device, jsonb_build_object('due', due));
end $$;

-- ---------- 3) مصدر كل قطعة ----------
create table public.purchases (
  id uuid primary key,
  shop_id uuid not null references public.shops(id),
  supplier_id uuid not null references public.suppliers(id),
  entry_id uuid not null unique references public.journal_entries(id),
  on_credit boolean not null,
  created_by uuid references public.profiles(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);
alter table public.purchases enable row level security;
revoke all on public.purchases from public, anon, authenticated;
create policy purchases_select on public.purchases for select to authenticated using (shop_id = public.current_shop_id() and public.current_app_role() = 'owner');
grant select on public.purchases to authenticated;
create trigger ledger_immutable before update or delete on public.purchases for each row execute function public.tg_ledger_immutable();
create trigger zz_audit after insert on public.purchases for each row execute function public.tg_audit();

-- المشتريات القديمة: المورد من سطر الآجل
insert into public.purchases(id, shop_id, supplier_id, entry_id, on_credit, created_by, created_at)
select e.source_id, e.shop_id, l.party_id, e.id, true, e.created_by, e.created_at
from public.journal_entries e join public.journal_lines l on l.entry_id = e.id and l.party_type = 'supplier'
where e.source_type = 'purchase' on conflict do nothing;

create or replace function public.tg_purchase_link() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  return null;
end $$;

-- record_purchase بيسجل المورد في purchases (نفس المنطق، وزيادة السطر ده)
create or replace function public.record_purchase(p_id uuid, p_supplier uuid, p_lines jsonb, p_cashbox uuid default null, p_note text default null)
returns uuid
language plpgsql security definer set search_path = public as $$
declare
  s uuid := public.current_shop_id();
  l jsonb;
  total bigint := 0;
  q bigint;
  u bigint;
  e uuid;
  credit_line jsonb;
begin
  perform public.ledger_require(array['owner']::public.app_role[]);
  e := public.ledger_idem(p_id);
  if e is not null then return e; end if;
  if not exists (select 1 from public.suppliers where id = p_supplier and shop_id = s and deleted_at is null) then raise exception 'E_NOT_FOUND'; end if;
  if jsonb_typeof(p_lines) <> 'array' or jsonb_array_length(p_lines) = 0 then raise exception 'E_BAD_INPUT'; end if;
  for l in select * from jsonb_array_elements(p_lines) loop
    q := (l ->> 'qty')::bigint;
    u := (l ->> 'unit_cost')::bigint;
    if q is null or q <= 0 or q > 100000 or u is null or u < 0 then raise exception 'E_BAD_AMOUNT'; end if;
    if not exists (select 1 from public.items where id = (l ->> 'item')::uuid and shop_id = s and deleted_at is null) then raise exception 'E_NOT_FOUND'; end if;
    total := total + q * u;
  end loop;
  perform public.ledger_amount(total);
  credit_line := case when p_cashbox is null
    then public.ledger_line(public.ledger_acc('ap'), 0, total, 'supplier', p_supplier)
    else public.ledger_line((public.ledger_cashbox(p_cashbox)).id, 0, total) end;
  e := public.ledger_post('purchase', p_id, p_note, jsonb_build_array(public.ledger_line(public.ledger_acc('inventory'), total, 0), credit_line), null, p_id);
  for l in select * from jsonb_array_elements(p_lines) loop
    insert into public.stock_moves(shop_id, item_id, entry_id, qty, value)
    values (s, (l ->> 'item')::uuid, e, (l ->> 'qty')::int, (l ->> 'qty')::bigint * (l ->> 'unit_cost')::bigint);
  end loop;
  insert into public.purchases(id, shop_id, supplier_id, entry_id, on_credit, created_by) values (p_id, s, p_supplier, e, p_cashbox is null, auth.uid());
  return e;
end $$;
drop function if exists public.tg_purchase_link();

-- أسعار الصنف عند كل مورد: آخر سعر، وأقل سعر، وآخر تاريخ شراء (صاحب المحل)
create or replace function public.item_suppliers(p_item uuid)
returns table(supplier_id uuid, supplier text, last_cost bigint, min_cost bigint, last_at timestamptz, total_qty bigint)
language plpgsql stable security definer set search_path = public as $$
#variable_conflict use_column
begin
  perform public.ledger_require(array['owner']::public.app_role[]);
  return query
  select p.supplier_id, sp.name,
         (array_agg((m.value / m.qty)::bigint order by m.created_at desc))[1],
         min((m.value / m.qty)::bigint),
         max(m.created_at), sum(m.qty)::bigint
  from public.stock_moves m
  join public.purchases p on p.entry_id = m.entry_id
  join public.suppliers sp on sp.id = p.supplier_id
  where m.item_id = p_item and m.shop_id = public.current_shop_id() and m.qty > 0
    and not exists (select 1 from public.journal_entries r where r.reverses_id = m.entry_id)
  group by p.supplier_id, sp.name
  order by 3;
end $$;

-- ---------- 4) الحد الأدنى والنواقص ----------
alter table public.items add column if not exists min_qty integer not null default 0 check (min_qty between 0 and 100000);
alter table public.items add column if not exists supplier_id uuid references public.suppliers(id);

drop function if exists public.items_stock();
create or replace function public.items_stock() returns table(id uuid, kind text, name text, sku text, sale_price integer, qty bigint, avg_cost bigint, value bigint, min_qty integer, supplier_id uuid, short boolean)
language plpgsql stable security definer set search_path = public as $$
declare r public.app_role := public.current_app_role();
begin
  if r is null then raise exception 'E_FORBIDDEN'; end if;
  return query
  select i.id, i.kind, i.name, i.sku,
         case when r = 'technician' then null else i.sale_price end,
         coalesce(st.q, 0)::bigint,
         case when r = 'owner' and coalesce(st.q, 0) > 0 then (st.v / st.q)::bigint end,
         case when r = 'owner' then coalesce(st.v, 0)::bigint end,
         i.min_qty, case when r = 'owner' then i.supplier_id end,
         i.min_qty > 0 and coalesce(st.q, 0) <= i.min_qty
  from public.items i
  left join (select m.item_id, sum(m.qty) as q, sum(m.value) as v from public.stock_moves m group by m.item_id) st on st.item_id = i.id
  where i.shop_id = public.current_shop_id() and i.deleted_at is null
  order by i.kind, i.name;
end $$;

-- ---------- 5) المدينين بأقدم دين ----------
-- أقدم دين = تاريخ أقدم حركة مدينة لسه ما اتسددتش (السداد بيقفل الأقدم الأول)
drop function if exists public.party_balances(text);
create or replace function public.party_balances(p_kind text)
returns table(party_type text, party_id uuid, name text, account text, balance bigint, oldest timestamptz)
language plpgsql stable security definer set search_path = public as $$
#variable_conflict use_column
declare s uuid := public.current_shop_id();
begin
  perform public.ledger_require(array['owner']::public.app_role[]);
  if p_kind not in ('customers', 'suppliers', 'employees') then raise exception 'E_BAD_INPUT'; end if;
  return query
  with lines as (
    select l.party_type, l.party_id, a.code, e.occurred_at, e.entry_no,
           (case when public.account_sign(a.type) = 1 then l.debit else l.credit end)::bigint as plus,
           (case when public.account_sign(a.type) = 1 then l.credit else l.debit end)::bigint as minus
    from public.journal_lines l join public.accounts a on a.id = l.account_id join public.journal_entries e on e.id = l.entry_id
    where l.shop_id = s and l.party_id is not null
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

-- ---------- 6) القطع المستبدلة (للفاتورة) ----------
create or replace function public.device_parts(p_device uuid)
returns table(item_id uuid, name text, qty bigint)
language plpgsql stable security definer set search_path = public as $$
#variable_conflict use_column
begin
  if public.current_app_role() is null then raise exception 'E_FORBIDDEN'; end if;
  if not exists (select 1 from public.devices where id = p_device and shop_id = public.current_shop_id()) then raise exception 'E_NOT_FOUND'; end if;
  return query
  select i.id, i.name, (-sum(m.qty))::bigint
  from public.stock_moves m
  join public.journal_entries e on e.id = m.entry_id
  join public.items i on i.id = m.item_id
  where (e.device_id = p_device) and e.source_type in ('part_use', 'reversal')
  group by i.id, i.name
  having -sum(m.qty) > 0;
end $$;

-- ---------- 7) التسعير ----------
alter table public.shops add column if not exists default_margin_pct integer not null default 20 check (default_margin_pct between 0 and 1000);

create table public.labor_rates (
  id uuid primary key,
  shop_id uuid not null references public.shops(id),
  issue text not null check (length(trim(issue)) between 1 and 80),
  amount integer not null check (amount between 0 and 2000000000),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);
create unique index labor_rates_issue on public.labor_rates(shop_id, lower(trim(issue))) where deleted_at is null;
alter table public.labor_rates enable row level security;
revoke all on public.labor_rates from public, anon, authenticated;
create policy labor_select on public.labor_rates for select to authenticated using (shop_id = public.current_shop_id() and public.current_app_role() in ('owner', 'reception'));
create policy labor_insert on public.labor_rates for insert to authenticated with check (shop_id = public.current_shop_id() and public.current_app_role() = 'owner');
create policy labor_update on public.labor_rates for update to authenticated using (shop_id = public.current_shop_id() and public.current_app_role() = 'owner') with check (shop_id = public.current_shop_id());
grant select, insert, update on public.labor_rates to authenticated;
create trigger set_updated_at before update on public.labor_rates for each row execute function public.tg_set_updated_at();
create trigger block_delete before delete on public.labor_rates for each row execute function public.tg_block_delete();
create trigger a_force_shop_id before insert or update on public.labor_rates for each row execute function public.tg_force_shop_id();
create trigger zz_audit after insert or update on public.labor_rates for each row execute function public.tg_audit();

-- السعر المقترح = تكلفة القطع + أجرة العطل + هامش على القطع، متقرّب لأقرب 5 جنيه.
-- الاستقبال بتشوف السعر بس (من غير تكلفة القطع ولا الربح). نفس معادلة suggestPrice في src/lib/ledger.ts
create or replace function public.suggest_device_price(p_device uuid) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare
  d public.devices;
  parts bigint;
  labor bigint;
  margin int;
  markup bigint;
  price bigint;
begin
  perform public.ledger_require(array['owner', 'reception']::public.app_role[]);
  select * into d from public.devices where id = p_device and shop_id = public.current_shop_id();
  if not found then raise exception 'E_NOT_FOUND'; end if;
  select coalesce(-sum(m.value), 0) into parts from public.stock_moves m join public.journal_entries e on e.id = m.entry_id
   where e.device_id = p_device and e.source_type in ('part_use', 'reversal');
  select coalesce(sum(r.amount), 0) into labor from public.labor_rates r
   where r.shop_id = d.shop_id and r.deleted_at is null and position(lower(trim(r.issue)) in lower(d.issue)) > 0;
  select default_margin_pct into margin from public.shops where id = d.shop_id;
  markup := (parts * margin + 99) / 100;
  price := ((parts + labor + markup + 499) / 500) * 500;
  return case when public.current_app_role() = 'owner'
    then jsonb_build_object('price', price, 'parts', parts, 'labor', labor, 'margin', margin, 'markup', markup)
    else jsonb_build_object('price', price, 'labor', labor) end;
end $$;

-- ---------- 8) توقيع العميل ----------
alter table public.devices add column if not exists intake_signature text check (intake_signature is null or (intake_signature like 'data:image/png;base64,%' and length(intake_signature) < 300000));

do $$
declare f text;
begin
  foreach f in array array['item_suppliers(uuid)', 'items_stock()', 'party_balances(text)', 'device_parts(uuid)', 'suggest_device_price(uuid)', 'deliver_on_credit(uuid)'] loop
    execute format('revoke execute on function public.%s from public, anon', f);
    execute format('grant execute on function public.%s to authenticated', f);
  end loop;
end $$;
