-- ============================================================
-- 0027: المخزون قسم مستقل بحساباته (البند 3)
-- كل عملية هنا قيد متوازن واحد جوه transaction، بالقروش، وبالمتوسط المرجّح، وما بتعديش المخزون بالسالب:
-- - الهالك (write_off): مصروف "هالك" مدين، والمخزون دائن بالتكلفة. والسبب إجباري.
-- - مرتجع للمورد (supplier_return): المخزون بيقل بالتكلفة، وحساب المورد بيقل (أو استرداد كاش) بالمبلغ المتفق عليه،
--   والفرق (لو المورد رجّع أقل أو أكتر من التكلفة) بيروح تكلفة البضاعة.
-- - مرتجع من العميل (sale_return): الإيراد بيقل بالمبلغ المرتجع، والفلوس بترجع من خزنة (أو رصيد للعميل).
--   والقطعة يا إما بترجع المخزون بتكلفتها، يا إما بتتسجل هالك لو بايظة.
-- - "ربط المخزون بالصيانة" (shops.extras.link_inventory، الافتراضي مربوط): لو مش مربوط،
--   القطعة بتتكتب على الجهاز يدوي بتكلفتها (device_manual_part) من غير ما المخزون يتأثر، والربح صح في الحالتين.
-- - الأصناف: تصنيف، وباركود (مش متكرر في نفس المحل)، وصورة في Storage تحت shop_id.
-- ============================================================

alter table public.journal_entries drop constraint if exists journal_entries_source_type_check;
alter table public.journal_entries add constraint journal_entries_source_type_check check (source_type = any (array[
  'payment', 'delivery', 'purchase', 'supplier_payment', 'part_use', 'sale', 'expense', 'salary', 'salary_payment', 'advance',
  'advance_settle', 'capital', 'drawing', 'transfer', 'drawer_close', 'reversal', 'cost_adjust',
  'write_off', 'supplier_return', 'sale_return']));

-- حساب "هالك" لكل محل (نوعه تكلفة بضاعة عشان ما يظهرش في قايمة المصروفات العادية)
create or replace function public.ensure_ledger_accounts(p_shop uuid) returns void
language plpgsql security definer set search_path = public as $$
declare m text;
begin
  insert into public.accounts(shop_id, code, type, kind)
  select p_shop, v.code, v.type::public.account_type, v.kind from (values
    ('ar', 'asset', 'receivable'), ('advances', 'asset', 'advances'), ('inventory', 'asset', 'inventory'),
    ('ap', 'liability', 'payable'), ('salaries_payable', 'liability', 'salaries'),
    ('capital', 'equity', 'capital'), ('drawings', 'equity', 'drawings'),
    ('rev_repair', 'revenue', 'revenue'), ('rev_parts', 'revenue', 'revenue'), ('rev_accessories', 'revenue', 'revenue'), ('overage', 'revenue', 'overage'),
    ('cogs', 'expense', 'cogs'), ('shortage', 'expense', 'shortage'), ('wastage', 'expense', 'cogs'),
    ('exp_salaries', 'expense', 'expense'), ('exp_rent', 'expense', 'expense'), ('exp_electricity', 'expense', 'expense'),
    ('exp_internet', 'expense', 'expense'), ('exp_purchases', 'expense', 'expense')
  ) as v(code, type, kind)
  on conflict (shop_id, code) where code is not null do nothing;
  for m in
    select unnest(array['cash', 'wallet', 'instapay', 'bank_transfer', 'card'])
    union
    select unnest(payment_methods) from public.shops where id = p_shop
  loop
    insert into public.accounts(shop_id, code, type, kind, method)
    values (p_shop, 'cash_' || m, 'asset', 'cash', m)
    on conflict (shop_id, code) where code is not null do nothing;
  end loop;
end $$;
revoke execute on function public.ensure_ledger_accounts(uuid) from public, anon, authenticated;
do $$
declare s uuid;
begin
  perform set_config('warsha.system', 'on', true);
  for s in select id from public.shops loop
    perform public.ensure_ledger_accounts(s);
  end loop;
  perform set_config('warsha.system', 'off', true);
end $$;

-- الأصناف: تصنيف وباركود وصورة
alter table public.items add column if not exists category text check (category is null or length(category) <= 60);
alter table public.items add column if not exists barcode text check (barcode is null or barcode ~ '^[0-9A-Za-z-]{4,32}$');
alter table public.items add column if not exists image_path text;
create unique index if not exists items_barcode_unique on public.items(shop_id, barcode) where barcode is not null and deleted_at is null;

-- صور الأصناف: خاصة بكل محل
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('item-images', 'item-images', false, 2097152, array['image/png', 'image/jpeg', 'image/webp'])
on conflict (id) do nothing;
do $$
begin
  begin drop policy if exists item_images_read on storage.objects; exception when others then null; end;
  begin drop policy if exists item_images_upload on storage.objects; exception when others then null; end;
  begin drop policy if exists item_images_update on storage.objects; exception when others then null; end;
end $$;
create policy item_images_read on storage.objects for select to authenticated
  using (bucket_id = 'item-images' and (storage.foldername(name))[1] = public.current_shop_id()::text);
create policy item_images_upload on storage.objects for insert to authenticated
  with check (bucket_id = 'item-images' and (storage.foldername(name))[1] = public.current_shop_id()::text and public.current_app_role() = 'owner');
create policy item_images_update on storage.objects for update to authenticated
  using (bucket_id = 'item-images' and (storage.foldername(name))[1] = public.current_shop_id()::text and public.current_app_role() = 'owner');

-- رصيد صنف (كمية وقيمة) + آخر تكلفة شراء (لو المخزون خلص، عشان المرتجع يرجع بتكلفة معقولة)
create or replace function public.item_last_cost(p_item uuid) returns bigint
language sql stable security definer set search_path = public as $$
  select coalesce(
    (select case when sum(qty) > 0 then sum(value) / sum(qty) end from public.stock_moves where item_id = p_item having sum(qty) > 0),
    (select m.value / m.qty from public.stock_moves m join public.journal_entries e on e.id = m.entry_id
      where m.item_id = p_item and m.qty > 0 and e.source_type = 'purchase' order by m.created_at desc limit 1),
    0)::bigint
$$;
revoke execute on function public.item_last_cost(uuid) from public, anon, authenticated;

-- ---------- الهالك ----------
create or replace function public.write_off(p_id uuid, p_item uuid, p_qty integer, p_reason text) returns uuid
language plpgsql security definer set search_path = public as $$
declare s uuid := public.current_shop_id(); e uuid; cost bigint;
begin
  perform public.ledger_require(array['owner']::public.app_role[]);
  e := public.ledger_idem(p_id);
  if e is not null then return e; end if;
  if nullif(trim(p_reason), '') is null then raise exception 'E_REASON_REQUIRED'; end if;
  if p_qty is null or p_qty <= 0 then raise exception 'E_BAD_AMOUNT'; end if;
  e := gen_random_uuid();
  insert into public.journal_entries(id, shop_id, source_type, source_id, memo, idem_key, created_by)
  values (e, s, 'write_off', p_item, trim(p_reason), p_id, auth.uid());
  cost := public.ledger_issue(p_item, p_qty, e);
  if cost > 0 then
    insert into public.journal_lines(shop_id, entry_id, account_id, debit, credit) values
      (s, e, public.ledger_acc('wastage'), cost, 0), (s, e, public.ledger_acc('inventory'), 0, cost);
  else
    -- صنف قيمته صفر: مفيش قيد يتعمل بطرفين، فبيترفض (والرسالة بتقول إن المبلغ غلط)
    raise exception 'E_BAD_AMOUNT';
  end if;
  return e;
end $$;

-- ---------- مرتجع للمورد ----------
-- p_refund: اللي المورد هيرجّعه (أو هيخصمه من حسابه). p_cashbox فاضي = بيتخصم من حساب المورد
create or replace function public.supplier_return(p_id uuid, p_supplier uuid, p_item uuid, p_qty integer, p_refund bigint, p_cashbox uuid default null, p_reason text default null) returns uuid
language plpgsql security definer set search_path = public as $$
declare s uuid := public.current_shop_id(); e uuid; cost bigint; diff bigint; cb uuid;
begin
  perform public.ledger_require(array['owner']::public.app_role[]);
  e := public.ledger_idem(p_id);
  if e is not null then return e; end if;
  if nullif(trim(p_reason), '') is null then raise exception 'E_REASON_REQUIRED'; end if;
  if p_qty is null or p_qty <= 0 or p_refund is null or p_refund < 0 then raise exception 'E_BAD_AMOUNT'; end if;
  if not exists (select 1 from public.suppliers where id = p_supplier and shop_id = s and deleted_at is null) then raise exception 'E_NOT_FOUND'; end if;
  if p_cashbox is not null then cb := (public.ledger_cashbox(p_cashbox)).id; end if;
  e := gen_random_uuid();
  insert into public.journal_entries(id, shop_id, source_type, source_id, memo, idem_key, created_by)
  values (e, s, 'supplier_return', p_supplier, trim(p_reason), p_id, auth.uid());
  cost := public.ledger_issue(p_item, p_qty, e);
  if cost = 0 and p_refund = 0 then raise exception 'E_BAD_AMOUNT'; end if;
  if cost > 0 then
    insert into public.journal_lines(shop_id, entry_id, account_id, debit, credit) values (s, e, public.ledger_acc('inventory'), 0, cost);
  end if;
  if p_refund > 0 then
    if cb is null then
      insert into public.journal_lines(shop_id, entry_id, account_id, party_type, party_id, debit, credit) values (s, e, public.ledger_acc('ap'), 'supplier', p_supplier, p_refund, 0);
    else
      insert into public.journal_lines(shop_id, entry_id, account_id, debit, credit) values (s, e, cb, p_refund, 0);
    end if;
  end if;
  diff := cost - p_refund;
  if diff > 0 then
    insert into public.journal_lines(shop_id, entry_id, account_id, debit, credit) values (s, e, public.ledger_acc('cogs'), diff, 0);
  elsif diff < 0 then
    insert into public.journal_lines(shop_id, entry_id, account_id, debit, credit) values (s, e, public.ledger_acc('cogs'), 0, -diff);
  end if;
  return e;
end $$;

-- ---------- مرتجع من العميل ----------
-- p_refund: اللي بيرجع للعميل. p_cashbox فاضي + p_customer = رصيد للعميل (بيتخصم من مديونيته). p_restock: القطعة سليمة وبترجع المخزون، وإلا هالك
create or replace function public.sale_return(p_id uuid, p_item uuid, p_qty integer, p_refund bigint, p_cashbox uuid default null, p_customer uuid default null, p_restock boolean default true, p_reason text default null) returns uuid
language plpgsql security definer set search_path = public as $$
declare s uuid := public.current_shop_id(); e uuid; it public.items; cost bigint; cb uuid; rev uuid;
begin
  perform public.ledger_require(array['owner', 'reception']::public.app_role[]);
  e := public.ledger_idem(p_id);
  if e is not null then return e; end if;
  if nullif(trim(p_reason), '') is null then raise exception 'E_REASON_REQUIRED'; end if;
  if p_qty is null or p_qty <= 0 or p_refund is null or p_refund < 0 then raise exception 'E_BAD_AMOUNT'; end if;
  select * into it from public.items where id = p_item and shop_id = s and deleted_at is null for update;
  if not found then raise exception 'E_NOT_FOUND'; end if;
  if p_cashbox is null and p_refund > 0 and p_customer is null then raise exception 'E_BAD_INPUT'; end if;
  if p_customer is not null and not exists (select 1 from public.customers where id = p_customer and shop_id = s and deleted_at is null) then raise exception 'E_NOT_FOUND'; end if;
  if p_cashbox is not null then cb := (public.ledger_cashbox(p_cashbox)).id; end if;
  rev := public.ledger_acc(case when it.kind = 'part' then 'rev_parts' else 'rev_accessories' end);
  cost := public.item_last_cost(p_item) * p_qty;
  if p_refund = 0 and (cost = 0 or not p_restock) then raise exception 'E_BAD_AMOUNT'; end if;
  e := gen_random_uuid();
  insert into public.journal_entries(id, shop_id, source_type, source_id, memo, idem_key, created_by)
  values (e, s, 'sale_return', p_item, trim(p_reason), p_id, auth.uid());
  if p_refund > 0 then
    insert into public.journal_lines(shop_id, entry_id, account_id, debit, credit) values (s, e, rev, p_refund, 0);
    if cb is not null then
      insert into public.journal_lines(shop_id, entry_id, account_id, debit, credit) values (s, e, cb, 0, p_refund);
    else
      insert into public.journal_lines(shop_id, entry_id, account_id, party_type, party_id, debit, credit) values (s, e, public.ledger_acc('ar'), 'customer', p_customer, 0, p_refund);
    end if;
  end if;
  -- القطعة السليمة بترجع المخزون بتكلفتها (والتكلفة بتخرج من تكلفة البضاعة). البايظة ما بترجعش، وتكلفتها فضلت مصروف.
  if p_restock and cost > 0 then
    insert into public.journal_lines(shop_id, entry_id, account_id, debit, credit) values
      (s, e, public.ledger_acc('inventory'), cost, 0), (s, e, public.ledger_acc('cogs'), 0, cost);
    insert into public.stock_moves(shop_id, item_id, entry_id, qty, value) values (s, p_item, e, p_qty, cost);
  elsif p_restock then
    insert into public.stock_moves(shop_id, item_id, entry_id, qty, value) values (s, p_item, e, p_qty, 0);
  end if;
  return e;
end $$;

-- ---------- قطعة يدوية على الجهاز (المخزون مش مربوط بالصيانة) ----------
-- اتدفع تمنها من خزنة، أو على مورد بالآجل. بتتسجل كتكلفة قطع على الجهاز (part_use) من غير أي حركة مخزون
create or replace function public.device_manual_part(p_id uuid, p_device uuid, p_name text, p_cost bigint, p_cashbox uuid default null, p_supplier uuid default null) returns uuid
language plpgsql security definer set search_path = public as $$
declare s uuid := public.current_shop_id(); e uuid; credit_line jsonb;
begin
  perform public.ledger_require(array['owner', 'reception']::public.app_role[]);
  e := public.ledger_idem(p_id);
  if e is not null then return e; end if;
  if nullif(trim(p_name), '') is null then raise exception 'E_BAD_INPUT'; end if;
  perform public.ledger_amount(p_cost);
  if not exists (select 1 from public.devices where id = p_device and shop_id = s and deleted_at is null and status <> 'delivered') then raise exception 'E_NOT_FOUND'; end if;
  if p_cashbox is not null then
    credit_line := public.ledger_line((public.ledger_cashbox(p_cashbox)).id, 0, p_cost);
  elsif p_supplier is not null then
    if not exists (select 1 from public.suppliers where id = p_supplier and shop_id = s and deleted_at is null) then raise exception 'E_NOT_FOUND'; end if;
    credit_line := public.ledger_line(public.ledger_acc('ap'), 0, p_cost, 'supplier', p_supplier);
  else
    raise exception 'E_BAD_INPUT';
  end if;
  return public.ledger_post('part_use', null, trim(p_name), jsonb_build_array(public.ledger_line(public.ledger_acc('cogs'), p_cost, 0), credit_line), p_device, p_id);
end $$;

do $$
declare f text;
begin
  foreach f in array array['write_off(uuid, uuid, integer, text)', 'supplier_return(uuid, uuid, uuid, integer, bigint, uuid, text)',
    'sale_return(uuid, uuid, integer, bigint, uuid, uuid, boolean, text)', 'device_manual_part(uuid, uuid, text, bigint, uuid, uuid)'] loop
    execute format('revoke execute on function public.%s from public, anon', f);
    execute format('grant execute on function public.%s to authenticated', f);
  end loop;
end $$;

-- ---------- المخزون بالأعمدة الجديدة (للكل حسب الصلاحية زي الأول) ----------
drop function if exists public.items_stock();
create or replace function public.items_stock() returns table(id uuid, kind text, name text, sku text, sale_price integer, qty bigint, avg_cost bigint, value bigint, min_qty integer, supplier_id uuid, short boolean, category text, barcode text, image_path text)
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
         i.min_qty > 0 and coalesce(st.q, 0) <= i.min_qty,
         i.category, i.barcode, i.image_path
  from public.items i
  left join (select m.item_id, sum(m.qty) as q, sum(m.value) as v from public.stock_moves m group by m.item_id) st on st.item_id = i.id
  where i.shop_id = public.current_shop_id() and i.deleted_at is null
  order by i.kind, i.name;
end $$;
revoke execute on function public.items_stock() from public, anon;
grant execute on function public.items_stock() to authenticated;

-- ---------- حركة صنف: كل دخول وخروج بالترتيب، والرصيد بعد كل حركة (صاحب المحل) ----------
create or replace function public.item_moves(p_item uuid) returns table(entry_id uuid, entry_no bigint, at timestamptz, source_type text, memo text, qty bigint, value bigint, balance_qty bigint, balance_value bigint, device_id uuid, order_no text, by text, reversed boolean)
language plpgsql stable security definer set search_path = public as $$
begin
  perform public.ledger_require(array['owner']::public.app_role[]);
  if not exists (select 1 from public.items where id = p_item and shop_id = public.current_shop_id()) then raise exception 'E_NOT_FOUND'; end if;
  return query
  select e.id, e.entry_no, e.occurred_at, e.source_type, e.memo, m.qty::bigint, m.value::bigint,
         (sum(m.qty) over w)::bigint, (sum(m.value) over w)::bigint,
         e.device_id, d.order_no, p.full_name,
         exists (select 1 from public.journal_entries r where r.reverses_id = e.id)
  from public.stock_moves m
  join public.journal_entries e on e.id = m.entry_id
  left join public.devices d on d.id = e.device_id
  left join public.profiles p on p.id = e.created_by
  where m.item_id = p_item
  window w as (order by e.occurred_at, e.entry_no, m.created_at rows unbounded preceding)
  order by e.occurred_at, e.entry_no, m.created_at;
end $$;
revoke execute on function public.item_moves(uuid) from public, anon;
grant execute on function public.item_moves(uuid) to authenticated;

-- ---------- حسابات المخزون لوحده لفترة: الإيراد والتكلفة والربح ----------
-- القيد العكسي بيتحسب مع نوع العملية الأصلية (إلغاء بيع بيقلل المبيعات)
create or replace function public.inventory_summary(p_from timestamptz, p_to timestamptz) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare s uuid := public.current_shop_id(); res jsonb;
begin
  perform public.ledger_require(array['owner']::public.app_role[]);
  with en as (
    select e.id, coalesce(o.source_type, e.source_type) t
    from public.journal_entries e left join public.journal_entries o on o.id = e.reverses_id
    where e.shop_id = s and e.occurred_at >= p_from and e.occurred_at < p_to
  ), ln as (
    select en.t, a.code, sum(l.credit - l.debit) cr from en join public.journal_lines l on l.entry_id = en.id join public.accounts a on a.id = l.account_id
    group by en.t, a.code
  )
  select jsonb_build_object(
    'sales', coalesce((select sum(cr) from ln where t in ('sale', 'sale_return') and code in ('rev_parts', 'rev_accessories')), 0),
    'sales_cost', coalesce((select -sum(cr) from ln where t in ('sale', 'sale_return') and code = 'cogs'), 0),
    'wastage', coalesce((select -sum(cr) from ln where code = 'wastage'), 0),
    'return_diff', coalesce((select -sum(cr) from ln where t = 'supplier_return' and code = 'cogs'), 0),
    'cost_adjust', coalesce((select -sum(cr) from ln where t = 'cost_adjust' and code = 'cogs'), 0),
    'parts_used', coalesce((select -sum(cr) from ln where t = 'part_use' and code = 'cogs'), 0),
    'purchases', coalesce((select -sum(cr) from ln where t = 'purchase' and code = 'inventory'), 0),
    'stock_value', (select coalesce(sum(value), 0) from public.stock_moves where shop_id = s),
    'stock_qty', (select coalesce(sum(qty), 0) from public.stock_moves where shop_id = s),
    'top', coalesce((select jsonb_agg(x order by x.qty desc) from (
        select i.id, i.name, -sum(m.qty)::bigint qty, -sum(m.value)::bigint cost
        from public.stock_moves m join en on en.id = m.entry_id join public.items i on i.id = m.item_id
        where en.t = 'sale' group by i.id, i.name order by -sum(m.qty) desc limit 10) x), '[]'::jsonb)
  ) into res;
  res := res || jsonb_build_object('profit', (res->>'sales')::bigint - (res->>'sales_cost')::bigint - (res->>'wastage')::bigint - (res->>'return_diff')::bigint - (res->>'cost_adjust')::bigint);
  return res;
end $$;
revoke execute on function public.inventory_summary(timestamptz, timestamptz) from public, anon;
grant execute on function public.inventory_summary(timestamptz, timestamptz) to authenticated;
