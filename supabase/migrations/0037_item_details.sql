-- =====================================================================
-- 0037: تفاصيل الصنف، والبيع لصنف مالوش رصيد (تعديل صاحب المشروع 2026-11-11)
-- - الصنف ليه خانات: النوع، والماركة (من 0035)، والموديل، والجودة، واللون. كلها اختيارية، والأصناف القديمة زي ما هي.
--   وكل خانة قايمة ملء سريع (item_types وqualities جديدة، والماركات والموديلات والألوان موجودة).
-- - "السماح بالبيع بدون رصيد" (shops.extras.allow_negative_stock، مقفول افتراضيًا):
--   - مقفول: البيع بكمية أكتر من الرصيد مرفوض (E_STOCK) زي الأول، والكاشير يسجّل الكمية والتكلفة الأول (stock_in).
--   - مفتوح: الكمية الموجودة بتخرج بتكلفتها، والباقي بيخرج من غير تكلفة ويتسجل "محتاج تسوية" (uncosted_sales).
--     ولما الكمية تيجي بعدين (شراء، أو رصيد، أو مرتجع، أو تحويل)، الفرق بيتسوى لوحده بقيد متوازن
--     (تكلفة البضاعة المباعة ← من المخزون) بالمتوسط المرجّح للفرع.
-- - الدفتر متوازن دايمًا، والأرصدة بتتحسب من القيود.
-- =====================================================================

alter table public.items add column if not exists item_type text check (item_type is null or length(trim(item_type)) between 1 and 60);
alter table public.items add column if not exists model text check (model is null or length(trim(model)) between 1 and 80);
alter table public.items add column if not exists quality text check (quality is null or length(trim(quality)) between 1 and 60);
alter table public.items add column if not exists color text check (color is null or length(trim(color)) between 1 and 40);

alter table public.shop_lists drop constraint if exists shop_lists_list_check;
alter table public.shop_lists add constraint shop_lists_list_check check (list in (
  'brands', 'models', 'accessories', 'colors', 'conditions', 'item_categories', 'write_off_reasons', 'sub_statuses',
  'device_types', 'issues', 'parts', 'return_reasons', 'item_types', 'qualities'));

-- ---------- البيع من غير رصيد ----------
create table public.uncosted_sales (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references public.shops(id),
  branch_id uuid not null references public.branches(id),
  item_id uuid not null references public.items(id),
  entry_id uuid not null references public.journal_entries(id),
  qty integer not null check (qty > 0),
  settled integer not null default 0 check (settled >= 0 and settled <= qty),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);
create index uncosted_open on public.uncosted_sales(item_id, branch_id) where settled < qty and deleted_at is null;
alter table public.uncosted_sales enable row level security;
create trigger set_updated_at before update on public.uncosted_sales for each row execute function public.tg_set_updated_at();
create trigger block_delete before delete on public.uncosted_sales for each row execute function public.tg_block_delete();
create trigger zz_audit after insert or update on public.uncosted_sales for each row execute function public.tg_audit();
create policy uncosted_select on public.uncosted_sales for select to authenticated using (shop_id = public.current_shop_id());
grant select on public.uncosted_sales to authenticated;

create or replace function public.allow_negative_stock() returns boolean
language sql stable security definer set search_path = public as $$
  select coalesce((select (s.extras ->> 'allow_negative_stock')::boolean from public.shops s where s.id = public.current_shop_id()), false)
$$;
revoke execute on function public.allow_negative_stock() from public, anon, authenticated;

-- الكمية اللي لسه محتاجة تسوية لصنف في فرع (بيعات ما اتلغتش)
create or replace function public.uncosted_open(p_item uuid, p_branch uuid) returns bigint
language sql stable security definer set search_path = public as $$
  select coalesce(sum(u.qty - u.settled), 0)::bigint from public.uncosted_sales u
  where u.item_id = p_item and u.branch_id = p_branch and u.deleted_at is null and u.settled < u.qty
    and not exists (select 1 from public.journal_entries r where r.reverses_id = u.entry_id)
$$;
revoke execute on function public.uncosted_open(uuid, uuid) from public, anon, authenticated;

-- الخروج من المخزون: لو الإعداد مفتوح وفي بيع (app.uncosted = on)، اللي مش موجود بيخرج من غير تكلفة ويتسجل للتسوية
create or replace function public.ledger_issue(p_item uuid, p_qty bigint, p_entry uuid) returns bigint
language plpgsql security definer set search_path = public as $$
declare st record; cost bigint; b uuid; avail bigint; short bigint;
begin
  perform 1 from public.items where id = p_item and shop_id = public.current_shop_id() and deleted_at is null for update;
  if not found then raise exception 'E_NOT_FOUND'; end if;
  select e.branch_id into b from public.journal_entries e where e.id = p_entry;
  select * into st from public.item_stock_at(p_item, b);
  if p_qty <= 0 then raise exception 'E_STOCK'; end if;
  if st.qty < p_qty then
    if current_setting('app.uncosted', true) is distinct from 'on' or not public.allow_negative_stock() then raise exception 'E_STOCK'; end if;
    avail := greatest(st.qty, 0);
    short := p_qty - avail;
    cost := case when avail > 0 then public.ledger_issue_cost(st.qty, st.value, avail) else 0 end;
    insert into public.stock_moves(shop_id, item_id, entry_id, qty, value, branch_id) values (public.current_shop_id(), p_item, p_entry, -p_qty, -cost, b);
    insert into public.uncosted_sales(shop_id, branch_id, item_id, entry_id, qty) values (public.current_shop_id(), b, p_item, p_entry, short);
    return cost;
  end if;
  cost := public.ledger_issue_cost(st.qty, st.value, p_qty);
  insert into public.stock_moves(shop_id, item_id, entry_id, qty, value, branch_id) values (public.current_shop_id(), p_item, p_entry, -p_qty, -cost, b);
  return cost;
end $$;
revoke execute on function public.ledger_issue(uuid, bigint, uuid) from public, anon, authenticated;

-- التسوية: الوحدات اللي اتباعت من غير تكلفة بتاخد تكلفتها من اللي وصل (المتوسط المرجّح للفرع):
-- مدين تكلفة البضاعة المباعة / دائن المخزون، وحركة مخزون بالقيمة بس (من غير كمية)
create or replace function public.settle_uncosted(p_item uuid, p_branch uuid) returns void
language plpgsql security definer set search_path = public as $$
declare pend bigint; st record; units bigint; n bigint; v bigint; e uuid; old text := current_setting('app.branch', true); u record; left_ bigint;
begin
  pend := public.uncosted_open(p_item, p_branch);
  if pend <= 0 then return; end if;
  select * into st from public.item_stock_at(p_item, p_branch);
  -- القيمة الموجودة بتاعة (الكمية + اللي اتباع من غير تكلفة)
  units := st.qty + pend;
  if units <= 0 or st.value <= 0 then return; end if;
  n := least(pend, units);
  v := public.ledger_issue_cost(units, st.value, n);
  if v <= 0 then return; end if;
  perform set_config('app.branch', p_branch::text, true);
  e := public.ledger_post('cost_adjust', p_item, 'تسوية بيع بدون رصيد',
    jsonb_build_array(public.ledger_line(public.ledger_acc('cogs'), v, 0), public.ledger_line(public.ledger_acc('inventory'), 0, v)));
  insert into public.stock_moves(shop_id, item_id, entry_id, qty, value, branch_id) values (public.current_shop_id(), p_item, e, 0, -v, p_branch);
  perform set_config('app.branch', coalesce(old, ''), true);
  -- الأقدم الأول
  left_ := n;
  for u in select * from public.uncosted_sales where item_id = p_item and branch_id = p_branch and deleted_at is null and settled < qty
             and not exists (select 1 from public.journal_entries r where r.reverses_id = uncosted_sales.entry_id)
           order by created_at, id for update loop
    exit when left_ <= 0;
    update public.uncosted_sales set settled = settled + least(left_, u.qty - u.settled) where id = u.id;
    left_ := left_ - least(left_, u.qty - u.settled);
  end loop;
end $$;
revoke execute on function public.settle_uncosted(uuid, uuid) from public, anon, authenticated;

-- أي كمية بتدخل (شراء، رصيد، مرتجع، تحويل، رأس مال بضاعة): لو فيه بيع محتاج تسوية في الفرع ده، بيتسوى
create or replace function public.tg_move_settle() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if new.qty > 0 and not public.restoring() and exists (select 1 from public.uncosted_sales u where u.item_id = new.item_id and u.branch_id = new.branch_id and u.settled < u.qty and u.deleted_at is null) then
    perform public.settle_uncosted(new.item_id, new.branch_id);
  end if;
  return null;
end $$;
create trigger zz_move_settle after insert on public.stock_moves for each row execute function public.tg_move_settle();

-- عكس بيع اتسوّى فعلًا مرفوض (التسوية قيد تاني اتسجل خلاص). العكس قبل التسوية: الكمية بترجع والتسوية بتتلغي
create or replace function public.tg_reverse_settled() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if new.reverses_id is not null and exists (select 1 from public.uncosted_sales u where u.entry_id = new.reverses_id and u.settled > 0) then
    raise exception 'E_SETTLED';
  end if;
  return new;
end $$;
create trigger b_reverse_settled before insert on public.journal_entries for each row execute function public.tg_reverse_settled();

-- ---------- تسجيل كمية وتكلفة من نافذة البيع (أو أي مكان) ----------
-- بضاعة دخلت المحل من غير مورد (زي الرصيد الافتتاحي): مدين المخزون / دائن رأس المال، بصلاحية "يضيف" في المخزون
create or replace function public.stock_in(p_id uuid, p_item uuid, p_qty integer, p_unit_cost bigint, p_note text default null) returns uuid
language plpgsql security definer set search_path = public as $$
declare s uuid := public.current_shop_id(); e uuid; total bigint;
begin
  perform public.ledger_require(array['owner', 'reception']::public.app_role[]);
  perform public.perm_require('inventory', 'add');
  e := public.ledger_idem(p_id);
  if e is not null then return e; end if;
  if p_qty is null or p_qty <= 0 or p_qty > 100000 or p_unit_cost is null or p_unit_cost < 0 then raise exception 'E_BAD_AMOUNT'; end if;
  if not exists (select 1 from public.items where id = p_item and shop_id = s and deleted_at is null) then raise exception 'E_NOT_FOUND'; end if;
  total := p_qty::bigint * p_unit_cost;
  if total <= 0 then raise exception 'E_BAD_AMOUNT'; end if;
  perform public.ledger_amount(total);
  e := public.ledger_post('opening', p_item, coalesce(nullif(trim(p_note), ''), 'stock'),
    jsonb_build_array(public.ledger_line(public.ledger_acc('inventory'), total, 0), public.ledger_line(public.ledger_acc('capital'), 0, total)), null, p_id);
  insert into public.stock_moves(shop_id, item_id, entry_id, qty, value) values (s, p_item, e, p_qty, total);
  return e;
end $$;
revoke execute on function public.stock_in(uuid, uuid, integer, bigint, text) from public, anon;
grant execute on function public.stock_in(uuid, uuid, integer, bigint, text) to authenticated;

-- ---------- دوال موجودة اتعدّلت ----------
-- record_sale: (src: 0036_roles.sql)
create or replace function public.record_sale(p_id uuid, p_lines jsonb, p_cashbox uuid default null, p_customer uuid default null, p_note text default null)
returns uuid
language plpgsql security definer set search_path = public as $$
declare
  s uuid := public.current_shop_id();
  e uuid := gen_random_uuid();
  l jsonb;
  it public.items;
  q bigint; p bigint; cost bigint;
  rev_parts bigint := 0; rev_acc bigint := 0; total_cost bigint := 0;
  debit_acc uuid; pt text; pid uuid;
begin
  perform public.ledger_require(array['owner', 'reception']::public.app_role[]);
  perform public.perm_require('sales', 'add');
  if public.ledger_idem(p_id) is not null then return public.ledger_idem(p_id); end if;
  -- البيع بالآجل لصاحب المحل بس
  if p_cashbox is null and (p_customer is null or public.current_app_role() <> 'owner') then raise exception 'E_BAD_INPUT'; end if;
  if p_customer is not null and not exists (select 1 from public.customers where id = p_customer and shop_id = s and deleted_at is null) then raise exception 'E_NOT_FOUND'; end if;
  if jsonb_typeof(p_lines) <> 'array' or jsonb_array_length(p_lines) = 0 then raise exception 'E_BAD_INPUT'; end if;
  insert into public.journal_entries(id, shop_id, source_type, source_id, memo, idem_key, created_by)
  values (e, s, 'sale', p_id, nullif(trim(p_note), ''), p_id, auth.uid());
  -- البيع بس: لو الإعداد مفتوح، اللي مش موجود بيخرج من غير تكلفة ويتسوى بعدين
  perform set_config('app.uncosted', 'on', true);
  for l in select * from jsonb_array_elements(p_lines) loop
    select * into it from public.items where id = (l ->> 'item')::uuid and shop_id = s and deleted_at is null;
    if not found then raise exception 'E_NOT_FOUND'; end if;
    q := (l ->> 'qty')::bigint;
    p := (l ->> 'price')::bigint;
    if q is null or q <= 0 or p is null or p < 0 then raise exception 'E_BAD_AMOUNT'; end if;
    cost := public.ledger_issue(it.id, q, e);
    total_cost := total_cost + cost;
    if it.kind = 'part' then rev_parts := rev_parts + q * p; else rev_acc := rev_acc + q * p; end if;
  end loop;
  perform set_config('app.uncosted', 'off', true);
  perform public.ledger_amount(rev_parts + rev_acc);
  if p_cashbox is null then
    debit_acc := public.ledger_acc('ar'); pt := 'customer'; pid := p_customer;
  else
    debit_acc := (public.ledger_cashbox(p_cashbox)).id;
  end if;
  insert into public.journal_lines(shop_id, entry_id, account_id, party_type, party_id, debit, credit)
  values (s, e, debit_acc, pt, pid, rev_parts + rev_acc, 0);
  if rev_parts > 0 then insert into public.journal_lines(shop_id, entry_id, account_id, debit, credit) values (s, e, public.ledger_acc('rev_parts'), 0, rev_parts); end if;
  if rev_acc > 0 then insert into public.journal_lines(shop_id, entry_id, account_id, debit, credit) values (s, e, public.ledger_acc('rev_accessories'), 0, rev_acc); end if;
  if total_cost > 0 then
    insert into public.journal_lines(shop_id, entry_id, account_id, debit, credit) values
      (s, e, public.ledger_acc('cogs'), total_cost, 0), (s, e, public.ledger_acc('inventory'), 0, total_cost);
  end if;
  if p_cashbox is not null and p_customer is not null then
    null; -- البيع النقدي لعميل معروف ما بيأثرش على رصيده
  end if;
  return e;
end $$;

-- items_stock: (src: 0036_roles.sql) + تفاصيل الصنف و"محتاج تسوية"
drop function if exists public.items_stock(boolean);
create or replace function public.items_stock(p_all boolean default false) returns table(id uuid, kind text, name text, sku text, sale_price integer, qty bigint, avg_cost bigint, value bigint, min_qty integer, supplier_id uuid, short boolean, category text, barcode text, image_path text, brand text, item_type text, model text, quality text, color text, unsettled bigint)
language plpgsql stable security definer set search_path = public as $$
declare r public.app_role := public.current_app_role(); b uuid := public.op_branch(); everywhere boolean;
begin
  if r is null then raise exception 'E_FORBIDDEN'; end if;
  if not (public.has_perm('inventory', 'view') or public.has_perm('sales', 'view')) then raise exception 'E_FORBIDDEN'; end if;
  everywhere := p_all and r = 'owner';
  return query
  select i.id, i.kind, i.name, i.sku,
         case when r = 'technician' then null else i.sale_price end,
         coalesce(st.q, 0)::bigint,
         case when r = 'owner' and coalesce(st.q, 0) > 0 then (st.v / st.q)::bigint end,
         case when r = 'owner' then coalesce(st.v, 0)::bigint end,
         i.min_qty, case when r = 'owner' then i.supplier_id end,
         i.min_qty > 0 and coalesce(st.q, 0) <= i.min_qty,
         i.category, i.barcode, i.image_path, i.brand, i.item_type, i.model, i.quality, i.color,
         (select coalesce(sum(u.qty - u.settled), 0)::bigint from public.uncosted_sales u where u.item_id = i.id and u.deleted_at is null and u.settled < u.qty
            and (everywhere or u.branch_id = b) and not exists (select 1 from public.journal_entries rv where rv.reverses_id = u.entry_id))
  from public.items i
  left join (select m.item_id, sum(m.qty) as q, sum(m.value) as v from public.stock_moves m where everywhere or m.branch_id = b group by m.item_id) st on st.item_id = i.id
  where i.shop_id = public.current_shop_id() and i.deleted_at is null
  order by i.kind, i.name;
end $$;
revoke execute on function public.items_stock(boolean) from public, anon;
grant execute on function public.items_stock(boolean) to authenticated;

-- integrity_report: (src: 0029_partners.sql)
create or replace function public.integrity_report() returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare s uuid := public.current_shop_id(); out jsonb := '[]'::jsonb; r record; inv bigint; mv bigint;
begin
  perform public.ledger_require(array['owner']::public.app_role[]);
  -- 1) قيد مش متوازن، أو ناقص طرف (أقل من سطرين)
  for r in select e.id, e.entry_no, coalesce(sum(l.debit), 0) - coalesce(sum(l.credit), 0) diff, count(l.id) n
           from public.journal_entries e left join public.journal_lines l on l.entry_id = e.id
           where e.shop_id = s group by e.id having coalesce(sum(l.debit), 0) <> coalesce(sum(l.credit), 0) or count(l.id) < 2 loop
    out := out || jsonb_build_array(jsonb_build_object('kind', case when r.n < 2 then 'entry_missing_side' else 'entry_unbalanced' end, 'amount', abs(r.diff), 'entry_id', r.id, 'entry_no', r.entry_no));
  end loop;
  -- 2) قيمة المخزون في الدفتر = مجموع حركات المخزون
  select coalesce(sum(l.debit - l.credit), 0) into inv from public.journal_lines l join public.accounts a on a.id = l.account_id where a.shop_id = s and a.kind = 'inventory';
  select coalesce(sum(m.value), 0) into mv from public.stock_moves m where m.shop_id = s;
  if inv <> mv then out := out || jsonb_build_array(jsonb_build_object('kind', 'inventory_ledger', 'amount', abs(inv - mv), 'ledger', inv, 'stock', mv)); end if;
  -- 3) كل صنف: الكمية مش بالسالب، ومفيش قيمة من غير كمية، ومفيش قيمة بالسالب
  for r in select i.id, i.name, coalesce(sum(m.qty), 0) q, coalesce(sum(m.value), 0) v from public.items i left join public.stock_moves m on m.item_id = i.id
           where i.shop_id = s group by i.id
           -- (0037) كمية بالسالب مسموحة بقدر البيع اللي لسه محتاج تسوية بس
           having coalesce(sum(m.qty), 0) + (select coalesce(sum(u.qty - u.settled), 0) from public.uncosted_sales u where u.item_id = i.id and u.deleted_at is null and u.settled < u.qty and not exists (select 1 from public.journal_entries rv where rv.reverses_id = u.entry_id)) < 0
              or (coalesce(sum(m.qty), 0) = 0 and coalesce(sum(m.value), 0) <> 0) or coalesce(sum(m.value), 0) < 0 loop
    out := out || jsonb_build_array(jsonb_build_object('kind', 'item_value', 'amount', abs(r.v), 'item_id', r.id, 'item', r.name, 'qty', r.q, 'value', r.v));
  end loop;
  -- 4) كل حركة مخزون بقيمتها في قيد على حساب المخزون بنفس المبلغ
  for r in select m.entry_id, e.entry_no, sum(m.value) mvv,
                  (select coalesce(sum(l.debit - l.credit), 0) from public.journal_lines l join public.accounts a on a.id = l.account_id where l.entry_id = m.entry_id and a.kind = 'inventory') lv
           from public.stock_moves m join public.journal_entries e on e.id = m.entry_id where m.shop_id = s group by m.entry_id, e.entry_no loop
    if r.mvv <> r.lv then out := out || jsonb_build_array(jsonb_build_object('kind', 'stock_entry', 'amount', abs(r.mvv - r.lv), 'entry_id', r.entry_id, 'entry_no', r.entry_no)); end if;
  end loop;
  -- 5) كل دفعة مبلغها = المبلغ اللي دخل الخزنة في قيدها
  for r in select p.id, p.amount, p.entry_id, e.entry_no,
                  (select coalesce(sum(l.debit), 0) from public.journal_lines l join public.accounts a on a.id = l.account_id where l.entry_id = p.entry_id and a.kind = 'cash') cash
           from public.payments p join public.journal_entries e on e.id = p.entry_id where p.shop_id = s loop
    if r.cash <> r.amount then out := out || jsonb_build_array(jsonb_build_object('kind', 'payment_entry', 'amount', abs(r.cash - r.amount), 'entry_id', r.entry_id, 'entry_no', r.entry_no)); end if;
  end loop;
  -- 6) حسابات العملاء والموردين والموظفين: كل سطر عليه طرف (عشان رصيد كل واحد = كشف حسابه)
  for r in select l.entry_id, e.entry_no, sum(l.debit + l.credit) amt from public.journal_lines l join public.accounts a on a.id = l.account_id join public.journal_entries e on e.id = l.entry_id
           where l.shop_id = s and a.kind in ('receivable', 'payable', 'advances', 'salaries', 'partner_capital', 'partner_current') and l.party_id is null group by l.entry_id, e.entry_no loop
    out := out || jsonb_build_array(jsonb_build_object('kind', 'party_missing', 'amount', r.amt, 'entry_id', r.entry_id, 'entry_no', r.entry_no));
  end loop;
  -- 7) كل سطر في نفس محل القيد
  for r in select l.entry_id, e.entry_no from public.journal_lines l join public.journal_entries e on e.id = l.entry_id where e.shop_id = s and l.shop_id <> e.shop_id group by 1, 2 loop
    out := out || jsonb_build_array(jsonb_build_object('kind', 'shop_mismatch', 'amount', 0, 'entry_id', r.entry_id, 'entry_no', r.entry_no));
  end loop;
  return out;
end $$;

-- backup_snapshot: (src: 0034_branches.sql)
create or replace function public.backup_snapshot(p_shop uuid) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare
  res jsonb := jsonb_build_object('format', 'warsha-backup', 'version', 1, 'generated_at', now(), 'shop_id', p_shop);
  t text;
  rows jsonb;
begin
  foreach t in array array['shops', 'branches', 'staff_branches', 'shop_branding', 'profiles', 'customers', 'devices', 'device_costs', 'status_log', 'device_notes', 'device_photos', 'device_checks',
                           'quote_decisions', 'message_templates', 'message_log', 'accounts', 'journal_entries', 'journal_lines', 'payments', 'drawer_closings',
                           'suppliers', 'items', 'stock_moves', 'uncosted_sales', 'purchases', 'labor_rates', 'specialties', 'staff_specialties', 'routes', 'repair_steps',
                           'repair_videos', 'device_ratings', 'issue_presets', 'partners', 'profit_distributions', 'party_links', 'shop_lists', 'audit_log'] loop
    execute format('select coalesce(jsonb_agg(to_jsonb(x)), ''[]''::jsonb) from public.%I x where x.shop_id = $1', t) into rows using p_shop;
    res := res || jsonb_build_object(t, rows);
  end loop;
  select coalesce(jsonb_agg(jsonb_build_object('device_id', device_id, 'kind', kind, 'erased_at', erased_at)), '[]'::jsonb)
    into rows from public.device_passcodes where shop_id = p_shop;
  return res || jsonb_build_object('device_passcodes', rows);
end $$;

-- restore_backup: (src: 0034_branches.sql)
create or replace function public.restore_backup(p_data jsonb) returns jsonb
-- extensions: فيها gen_random_bytes على Supabase
language plpgsql security definer set search_path = public, extensions, pg_temp as $$
declare
  s uuid := public.current_shop_id();
  me uuid := auth.uid();
  old_shop uuid;
  old_owner uuid;
  sh jsonb;
  t text;
  r jsonb;
  rows jsonb;
  n int;
  bad int;
  counts jsonb := '{}'::jsonb;
  -- بالترتيب ده عشان كل صف يلاقي اللي بيشاور عليه
  tabs text[] := array['branches', 'profiles', 'staff_branches', 'shop_branding', 'accounts', 'customers', 'suppliers', 'party_links', 'partners', 'specialties', 'staff_specialties', 'routes', 'labor_rates',
                       'issue_presets', 'shop_lists', 'message_templates', 'items', 'devices', 'device_costs', 'status_log', 'device_notes', 'device_checks',
                       'quote_decisions', 'repair_steps', 'repair_videos', 'device_ratings', 'journal_entries', 'journal_lines', 'profit_distributions', 'payments',
                       'purchases', 'stock_moves', 'uncosted_sales', 'drawer_closings', 'message_log', 'audit_log'];
  -- الجداول دي ليها نسخة اتعملت مع التسجيل: بتتطابق بالكود (أو المفتاح) وبتاخد قيم النسخة
  keyed text[] := array['branches', 'accounts', 'routes', 'specialties', 'message_templates', 'labor_rates', 'shop_branding'];
begin
  perform public.ledger_require(array['owner']::public.app_role[]);
  if s is null or me is null then raise exception 'E_FORBIDDEN'; end if;
  if p_data is null or p_data->>'format' is distinct from 'warsha-backup' or coalesce((p_data->>'version')::int, 0) <> 1 then
    raise exception 'E_BACKUP_FORMAT';
  end if;
  old_shop := (p_data->>'shop_id')::uuid;
  if old_shop is null or old_shop = s then raise exception 'E_BACKUP_FORMAT'; end if;

  -- محل جديد فاضي بس
  if exists (select 1 from public.devices where shop_id = s) or exists (select 1 from public.customers where shop_id = s)
     or exists (select 1 from public.journal_entries where shop_id = s) or exists (select 1 from public.items where shop_id = s)
     or exists (select 1 from public.suppliers where shop_id = s) or exists (select 1 from public.payments where shop_id = s)
     or exists (select 1 from public.purchases where shop_id = s) or exists (select 1 from public.drawer_closings where shop_id = s)
     or exists (select 1 from public.stock_moves where shop_id = s)
     or exists (select 1 from public.profiles where shop_id = s and id <> me) then
    raise exception 'E_RESTORE_NOT_EMPTY';
  end if;

  perform set_config('warsha.restore', 'on', true);
  drop table if exists pg_temp._rmap;
  create temp table _rmap(old uuid primary key, new uuid not null) on commit drop;
  insert into _rmap values (old_shop, s);

  -- 1) بيانات المحل نفسه (من غير الخطة والإيقاف واللوجو اللي في Storage)
  sh := p_data->'shops'->0;
  if sh is not null then
    update public.shops set
      name = coalesce(sh->>'name', name), phone = sh->>'phone', address = sh->>'address',
      receipt_terms = coalesce(sh->>'receipt_terms', receipt_terms), warranty_days = coalesce((sh->>'warranty_days')::int, warranty_days),
      country = coalesce(sh->>'country', country), currency = coalesce(sh->>'currency', currency),
      payment_methods = coalesce(array(select jsonb_array_elements_text(sh->'payment_methods')), payment_methods),
      theme = coalesce(sh->>'theme', theme), locale = coalesce(sh->>'locale', locale),
      default_margin_pct = coalesce((sh->>'default_margin_pct')::int, default_margin_pct),
      extras = coalesce(sh->'extras', extras), max_discount_pct = coalesce((sh->>'max_discount_pct')::int, max_discount_pct)
    where id = s;
  end if;

  -- 2) الـ ids الجديدة
  -- صاحب المحل في النسخة = اللي بيسترجع دلوقتي
  select (x->>'id')::uuid into old_owner from jsonb_array_elements(coalesce(p_data->'profiles', '[]')) x
   where x->>'role' = 'owner' order by x->>'created_at' limit 1;
  if old_owner is not null then insert into _rmap values (old_owner, me) on conflict do nothing; end if;
  insert into _rmap select (x->>'id')::uuid, coalesce((select a.id from public.accounts a where a.shop_id = s and a.code = x->>'code' and x->>'code' is not null), gen_random_uuid())
    from jsonb_array_elements(coalesce(p_data->'accounts', '[]')) x on conflict do nothing;
  -- الفرع الرئيسي في النسخة = الفرع الرئيسي للمحل الجديد
  insert into _rmap select (x->>'id')::uuid, public.main_branch(s)
    from jsonb_array_elements(coalesce(p_data->'branches', '[]')) x where (x->>'is_main')::boolean and x->>'deleted_at' is null on conflict do nothing;
  insert into _rmap select (x->>'id')::uuid, coalesce((select a.id from public.routes a where a.shop_id = s and a.code = x->>'code' and x->>'code' is not null), gen_random_uuid())
    from jsonb_array_elements(coalesce(p_data->'routes', '[]')) x on conflict do nothing;
  insert into _rmap select (x->>'id')::uuid, coalesce((select a.id from public.specialties a where a.shop_id = s and a.code = x->>'code' and x->>'code' is not null), gen_random_uuid())
    from jsonb_array_elements(coalesce(p_data->'specialties', '[]')) x on conflict do nothing;
  insert into _rmap select (x->>'id')::uuid, coalesce((select a.id from public.message_templates a where a.shop_id = s and a.key = x->>'key'), gen_random_uuid())
    from jsonb_array_elements(coalesce(p_data->'message_templates', '[]')) x on conflict do nothing;
  insert into _rmap select (x->>'id')::uuid, coalesce((select a.id from public.labor_rates a where a.shop_id = s and a.deleted_at is null and lower(trim(a.issue)) = lower(trim(x->>'issue')) and x->>'deleted_at' is null), gen_random_uuid())
    from jsonb_array_elements(coalesce(p_data->'labor_rates', '[]')) x on conflict do nothing;
  insert into _rmap select (x->>'id')::uuid, coalesce((select a.id from public.shop_branding a where a.shop_id = s), gen_random_uuid())
    from jsonb_array_elements(coalesce(p_data->'shop_branding', '[]')) x on conflict do nothing;
  foreach t in array tabs loop
    insert into _rmap select (x->>'id')::uuid, gen_random_uuid() from jsonb_array_elements(coalesce(p_data->t, '[]')) x where x ? 'id' on conflict do nothing;
  end loop;

  -- 3) الصفوف نفسها بالترتيب
  foreach t in array tabs loop
    rows := '[]'::jsonb;
    for r in select public.restore_remap(x) from jsonb_array_elements(coalesce(p_data->t, '[]')) x loop
      if t = 'profiles' then
        -- صاحب المحل موجود أصلًا. الباقيين موظفين سابقين (من غير حساب دخول)
        continue when (r->>'id')::uuid = me;
        r := r || jsonb_build_object('deleted_at', coalesce(r->>'deleted_at', now()::text));
      elsif t = 'devices' then
        -- كود التتبع (الـ QR) بيفضل زي ما هو، إلا لو مستخدم في المشروع ده (المحل الأصلي لسه هنا)
        if exists (select 1 from public.devices d where d.tracking_token = r->>'tracking_token') then
          r := r || jsonb_build_object('tracking_token', encode(gen_random_bytes(12), 'hex'));
        end if;
      elsif t = 'journal_entries' then
        if r->>'idem_key' is not null and exists (select 1 from public.journal_entries j where j.idem_key = (r->>'idem_key')::uuid) then
          r := r || jsonb_build_object('idem_key', gen_random_uuid());
        end if;
      elsif t = 'accounts' and r->>'kind' = 'cash' and r->>'branch_id' is null then
        -- نسخة من قبل الفروع: الخزن كلها في الفرع الرئيسي
        r := r || jsonb_build_object('branch_id', public.main_branch(s));
      elsif t = 'shop_branding' then
        -- اللوجو الملون والحراري جوه الصف نفسه. الملف الأصلي في Storage مش جوه النسخة
        r := r || jsonb_build_object('logo_path', null);
      end if;
      if t = any (keyed) and exists (select 1 from _rmap m where m.new = (r->>'id')::uuid and m.old <> m.new)
         and (t <> 'shop_branding' or exists (select 1 from public.shop_branding b where b.id = (r->>'id')::uuid)) then
        -- موجود من التسجيل: بياخد قيم النسخة
        execute format('select count(*) from public.%I where id = $1', t) into n using (r->>'id')::uuid;
        if n > 0 then
          execute format('update public.%1$I x set (%2$s) = (select %2$s from jsonb_populate_record(null::public.%1$I, $1)) where x.id = $2', t,
            (select string_agg(quote_ident(c.column_name), ', ' order by c.ordinal_position) from information_schema.columns c
              where c.table_schema = 'public' and c.table_name = t and c.column_name not in ('id', 'shop_id')))
            using r, (r->>'id')::uuid;
          continue;
        end if;
      end if;
      rows := rows || jsonb_build_array(r);
    end loop;
    if jsonb_array_length(rows) > 0 then
      -- overriding system value: أرقام القيود (entry_no) بترجع زي ما هي
      execute format('insert into public.%1$I overriding system value select * from jsonb_populate_recordset(null::public.%1$I, $1)', t) using rows;
    end if;
    counts := counts || jsonb_build_object(t, jsonb_array_length(coalesce(p_data->t, '[]')));
  end loop;

  -- 4) عدّاد أرقام الطلبات: من آخر رقم راجع في كل سنة
  -- (لكل فرع: الرقم ممكن يبقى قبله بادئة الفرع B2-2026-0001)
  insert into public.order_counters(shop_id, branch_id, year, last_value)
  select s, branch_id, (regexp_match(order_no, '(\d{4})-(\d+)$'))[1]::int, max((regexp_match(order_no, '(\d{4})-(\d+)$'))[2]::int)
    from public.devices where shop_id = s and order_no ~ '\d{4}-\d+$' group by 2, 3
  on conflict (shop_id, branch_id, year) do update set last_value = greatest(public.order_counters.last_value, excluded.last_value);

  -- 5) التأكد: كل قيد متوازن، ورصيد كل حساب = رصيده في النسخة بالظبط
  select count(*) into bad from (
    select entry_id from public.journal_lines where shop_id = s group by entry_id having sum(debit) <> sum(credit)) x;
  if bad > 0 then raise exception 'E_RESTORE_UNBALANCED'; end if;
  select count(*) into bad from (
    select m.new acc, sum((l->>'debit')::bigint - (l->>'credit')::bigint) b
      from jsonb_array_elements(coalesce(p_data->'journal_lines', '[]')) l join _rmap m on m.old = (l->>'account_id')::uuid group by m.new
  ) x full join (select account_id, sum(debit - credit) b from public.journal_lines where shop_id = s group by account_id) y on y.account_id = x.acc
  where coalesce(x.b, 0) <> coalesce(y.b, 0);
  if bad > 0 then raise exception 'E_RESTORE_MISMATCH'; end if;
  -- وعدد الصفوف في كل جدول (الحسابات والقوالب اللي اتعملت مع التسجيل ممكن تزيد عن النسخة، مش تقل)
  foreach t in array tabs loop
    execute format('select count(*) from public.%I where shop_id = $1', t) into n using s;
    if n < jsonb_array_length(coalesce(p_data->t, '[]')) - (case when t = 'profiles' and old_owner is not null then 1 else 0 end) then
      raise exception 'E_RESTORE_MISMATCH';
    end if;
  end loop;

  perform set_config('warsha.restore', 'off', true);
  insert into public.audit_log(shop_id, actor_id, action, entity, entity_id, after)
  values (s, me, 'backup_restore', 'shops', s, jsonb_build_object('from_shop', old_shop, 'generated_at', p_data->>'generated_at', 'counts', counts));
  return jsonb_build_object('restored', true, 'counts', counts);
end $$;
