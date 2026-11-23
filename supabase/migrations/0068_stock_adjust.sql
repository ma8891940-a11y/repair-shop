-- ============================================================
-- 0068: بند 14 من qa-37: نقص المخزون في البيع = تسوية مخزون بصلاحية لوحدها وسبب وسجل.
-- - قبل كده: شاشة البيع لما الكمية مش كفاية كانت بتعرض "سجّل الكمية والتكلفة" (stock_in) لأي حد معاه "المخزون ← يضيف"
--   (الاستقبال)، من غير سبب، والقيد على رأس المال. يعني زيادة مخزون خفية من شاشة البيع.
-- - دلوقتي: stock_in = "تسوية مخزون": صاحب المحل أو اللي معاه "المخزون ← المبالغ" بس، والسبب إجباري،
--   وبيتسجل في سجل النشاط (مين، وإمتى، والكمية، والتكلفة، والسبب). البيع نفسه عمره ما بيزوّد المخزون (E_STOCK زي ما هو).
-- - الرصيد الأول لصنف جديد (create_item) فاضل زي ما هو: بصلاحيات إضافة الصنف والمخزون (من غير "المبالغ")، عن طريق _stock_in.
-- ============================================================

-- الشغل نفسه من غير صلاحيات (داخلي بس، محدش يناديه من بره)
create or replace function public._stock_in(p_id uuid, p_item uuid, p_qty integer, p_unit_cost bigint, p_memo text) returns uuid
language plpgsql security definer set search_path = public as $$
declare s uuid := public.current_shop_id(); e uuid; total bigint;
begin
  e := public.ledger_idem(p_id);
  if e is not null then return e; end if;
  if p_qty is null or p_qty <= 0 or p_qty > 100000 or p_unit_cost is null or p_unit_cost < 0 then raise exception 'E_BAD_AMOUNT'; end if;
  if not exists (select 1 from public.items where id = p_item and shop_id = s and deleted_at is null) then raise exception 'E_NOT_FOUND'; end if;
  total := p_qty::bigint * p_unit_cost;
  if total <= 0 then raise exception 'E_BAD_AMOUNT'; end if;
  perform public.ledger_amount(total);
  e := public.ledger_post('opening', p_item, left(coalesce(nullif(trim(p_memo), ''), 'stock'), 300),
    jsonb_build_array(public.ledger_line(public.ledger_acc('inventory'), total, 0), public.ledger_line(public.ledger_acc('capital'), 0, total)), null, p_id);
  insert into public.stock_moves(shop_id, item_id, entry_id, qty, value) values (s, p_item, e, p_qty, total);
  return e;
end $$;
revoke execute on function public._stock_in(uuid, uuid, integer, bigint, text) from public, anon, authenticated;

-- stock_in: (src: 0037_item_details.sql) = تسوية مخزون: صلاحية "المخزون ← المبالغ" والسبب إجباري وسجل
create or replace function public.stock_in(p_id uuid, p_item uuid, p_qty integer, p_unit_cost bigint, p_note text default null) returns uuid
language plpgsql security definer set search_path = public as $$
declare s uuid := public.current_shop_id(); e uuid; reason text := left(nullif(trim(p_note), ''), 300);
begin
  e := public.ledger_idem(p_id);
  if e is not null then return e; end if;
  if reason is null then raise exception 'E_REASON_REQUIRED'; end if;
  e := public._stock_in(p_id, p_item, p_qty, p_unit_cost, reason);
  insert into public.audit_log(shop_id, actor_id, action, entity, entity_id, after)
  values (s, auth.uid(), 'stock_adjust', 'items', p_item, jsonb_build_object('qty', p_qty, 'unit_cost', p_unit_cost, 'value', p_qty::bigint * p_unit_cost, 'reason', reason, 'entry', e));
  return e;
end $$;
revoke execute on function public.stock_in(uuid, uuid, integer, bigint, text) from public, anon;
grant execute on function public.stock_in(uuid, uuid, integer, bigint, text) to authenticated;

-- create_item: (src: 0057_categories.sql) + الرصيد الأول بـ _stock_in بنفس صلاحيات stock_in القديمة (المخزون ← يضيف)
create or replace function public.create_item(
  p_id uuid, p_kind text, p_name text, p_item_type text default null, p_brand text default null, p_model text default null,
  p_quality text default null, p_color text default null, p_sale_price integer default null, p_qty integer default null, p_unit_cost bigint default null,
  p_stock_id uuid default null
) returns uuid
language plpgsql security definer set search_path = public as $$
declare s uuid := public.current_shop_id(); nm text := trim(coalesce(p_name, ''));
begin
  perform public.ledger_require(array['owner', 'reception']::public.app_role[]);
  perform public.perm_require('item_create', 'add');
  if exists (select 1 from public.items where id = p_id and shop_id = s) then return p_id; end if;
  if p_kind not in ('part', 'accessory', 'service') or nm = '' or length(nm) > 160 then raise exception 'E_BAD_INPUT'; end if;
  if p_sale_price is not null and (p_sale_price < 0 or p_sale_price > 2000000000) then raise exception 'E_BAD_AMOUNT'; end if;
  insert into public.items(id, shop_id, kind, name, item_type, brand, model, quality, color, sale_price)
  values (p_id, s, p_kind, nm, nullif(trim(p_item_type), ''), nullif(trim(p_brand), ''), nullif(trim(p_model), ''), nullif(trim(p_quality), ''), nullif(trim(p_color), ''), p_sale_price);
  if coalesce(p_qty, 0) > 0 then
    if p_unit_cost is null or p_unit_cost <= 0 then raise exception 'E_BAD_AMOUNT'; end if;
    perform public.perm_require('inventory', 'add');
    perform public._stock_in(coalesce(p_stock_id, gen_random_uuid()), p_id, p_qty, p_unit_cost, 'stock');
  end if;
  return p_id;
end $$;
