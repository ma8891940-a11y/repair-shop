-- ============================================================
-- 0069: بند 13 من qa-37: أخطاء البيع برسالة الحقل، وسياسة البيع المجاني.
-- - الكمية الغلط E_BAD_QTY، والسعر الغلط E_BAD_PRICE (بدل رسالة عامة).
-- - صنف مجاني (سعر صفر): صاحب المحل أو اللي معاه "المخزون ← المبالغ"، والسبب (reason في السطر) إجباري.
--   السبب في سجل النشاط بس: ملاحظة البيع بتتطبع على فاتورة العميل، فما بيتحطش فيها.
-- - فاتورة كلها مجانية مرفوضة زي الأول (E_BAD_AMOUNT).
-- ============================================================

-- record_sale: (src: 0062_vat.sql)
create or replace function public.record_sale(p_id uuid, p_lines jsonb, p_cashbox uuid default null, p_customer uuid default null, p_note text default null)
returns uuid
language plpgsql security definer set search_path = public as $$
declare
  s uuid := public.current_shop_id();
  e uuid := gen_random_uuid();
  l jsonb;
  it public.items;
  q bigint; p bigint; cost bigint;
  rev_parts bigint := 0; rev_acc bigint := 0; rev_srv bigint := 0; total_cost bigint := 0;
  debit_acc uuid; pt text; pid uuid;
  n int := 0;
  bp integer := public.vat_bp(s); v_parts bigint := 0; v_acc bigint := 0; v_srv bigint := 0;
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
    -- أعداد صحيحة بس (الكسور والفراغ وNaN والسالب بيترفضوا برسالة الحقل نفسه)
    if coalesce(l ->> 'qty', '') !~ '^[0-9]{1,6}$' or (l ->> 'qty')::bigint <= 0 then raise exception 'E_BAD_QTY'; end if;
    if coalesce(l ->> 'price', '') !~ '^[0-9]{1,12}$' then raise exception 'E_BAD_PRICE'; end if;
    q := (l ->> 'qty')::bigint;
    p := (l ->> 'price')::bigint;
    if p = 0 then
      if public.current_app_role() <> 'owner' and not public.has_perm('inventory', 'amounts') then raise exception 'E_FREE_SALE'; end if;
      if nullif(trim(l ->> 'reason'), '') is null then raise exception 'E_REASON_REQUIRED'; end if;
      insert into public.audit_log(shop_id, actor_id, action, entity, entity_id, after)
      values (s, auth.uid(), 'free_sale', 'items', it.id, jsonb_build_object('name', it.name, 'qty', q, 'reason', left(trim(l ->> 'reason'), 300), 'entry', e));
    end if;
    -- 6ب: سطر البيع زي ما اتباع (الاسم والكمية والسعر) عشان فاتورة البيع
    n := n + 1;
    insert into public.sale_lines(shop_id, entry_id, item_id, name, qty, price, seq, customer_id) values (s, e, it.id, it.name, q, p, n, p_customer);
    -- K: الخدمة من غير مخزون ولا تكلفة، وإيرادها إيراد الصيانة
    if it.kind = 'service' then rev_srv := rev_srv + q * p; continue; end if;
    cost := public.ledger_issue(it.id, q, e);
    total_cost := total_cost + cost;
    if it.kind = 'part' then rev_parts := rev_parts + q * p; else rev_acc := rev_acc + q * p; end if;
  end loop;
  perform set_config('app.uncosted', 'off', true);
  perform public.ledger_amount(rev_parts + rev_acc + rev_srv);
  if p_cashbox is null then
    debit_acc := public.ledger_acc('ar'); pt := 'customer'; pid := p_customer;
  else
    debit_acc := (public.ledger_cashbox(p_cashbox)).id;
  end if;
  insert into public.journal_lines(shop_id, entry_id, account_id, party_type, party_id, debit, credit)
  values (s, e, debit_acc, pt, pid, rev_parts + rev_acc + rev_srv, 0);
  -- R5: السعر شامل الضريبة. الضريبة بتتفصل من كل نوع إيراد لوحده، ومجموعها في حساب الضريبة المستحقة
  if bp > 0 then
    v_parts := public.vat_of(rev_parts, bp); v_acc := public.vat_of(rev_acc, bp); v_srv := public.vat_of(rev_srv, bp);
    if v_parts + v_acc + v_srv > 0 then
      insert into public.journal_lines(shop_id, entry_id, account_id, debit, credit) values (s, e, public.ledger_acc('vat_payable'), 0, v_parts + v_acc + v_srv);
    end if;
  end if;
  if rev_parts > 0 then insert into public.journal_lines(shop_id, entry_id, account_id, debit, credit) values (s, e, public.ledger_acc('rev_parts'), 0, rev_parts - v_parts); end if;
  if rev_acc > 0 then insert into public.journal_lines(shop_id, entry_id, account_id, debit, credit) values (s, e, public.ledger_acc('rev_accessories'), 0, rev_acc - v_acc); end if;
  if rev_srv > 0 then insert into public.journal_lines(shop_id, entry_id, account_id, debit, credit) values (s, e, public.ledger_acc('rev_repair'), 0, rev_srv - v_srv); end if;
  if total_cost > 0 then
    insert into public.journal_lines(shop_id, entry_id, account_id, debit, credit) values
      (s, e, public.ledger_acc('cogs'), total_cost, 0), (s, e, public.ledger_acc('inventory'), 0, total_cost);
  end if;
  if p_cashbox is not null and p_customer is not null then
    null; -- البيع النقدي لعميل معروف ما بيأثرش على رصيده
  end if;
  return e;
end $$;

-- stock_in: (src: 0068_stock_adjust.sql) + اسم الصنف في سجل النشاط
create or replace function public.stock_in(p_id uuid, p_item uuid, p_qty integer, p_unit_cost bigint, p_note text default null) returns uuid
language plpgsql security definer set search_path = public as $$
declare s uuid := public.current_shop_id(); e uuid; reason text := left(nullif(trim(p_note), ''), 300);
begin
  perform public.grant_require('inventory', 'amounts');
  e := public.ledger_idem(p_id);
  if e is not null then return e; end if;
  if reason is null then raise exception 'E_REASON_REQUIRED'; end if;
  e := public._stock_in(p_id, p_item, p_qty, p_unit_cost, reason);
  insert into public.audit_log(shop_id, actor_id, action, entity, entity_id, after)
  values (s, auth.uid(), 'stock_adjust', 'items', p_item, jsonb_build_object('name', (select name from public.items where id = p_item), 'qty', p_qty, 'unit_cost', p_unit_cost, 'value', p_qty::bigint * p_unit_cost, 'reason', reason, 'entry', e));
  return e;
end $$;
