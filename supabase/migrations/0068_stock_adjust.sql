-- ============================================================
-- 0068: بند 14 من qa-37: نقص المخزون في البيع = تسوية مخزون بصلاحية لوحدها وسبب وسجل.
-- - قبل كده: شاشة البيع لما الكمية مش كفاية كانت بتعرض "سجّل الكمية والتكلفة" (stock_in) لأي حد معاه "المخزون ← يضيف"
--   (الاستقبال)، من غير سبب، والقيد على رأس المال. يعني زيادة مخزون خفية من شاشة البيع.
-- - دلوقتي: stock_in = "تسوية مخزون": صاحب المحل أو اللي معاه "المخزون ← المبالغ" بس، والسبب إجباري،
--   وبيتسجل في سجل النشاط (مين، وإمتى، والكمية، والتكلفة، والسبب). البيع نفسه عمره ما بيزوّد المخزون (E_STOCK زي ما هو).
-- ============================================================

-- stock_in: (src: 0037_item_details.sql) + صلاحية التسوية والسبب والسجل
create or replace function public.stock_in(p_id uuid, p_item uuid, p_qty integer, p_unit_cost bigint, p_note text default null) returns uuid
language plpgsql security definer set search_path = public as $$
declare s uuid := public.current_shop_id(); e uuid; total bigint; reason text := nullif(trim(p_note), '');
begin
  perform public.grant_require('inventory', 'amounts');
  e := public.ledger_idem(p_id);
  if e is not null then return e; end if;
  if reason is null then raise exception 'E_REASON_REQUIRED'; end if;
  if p_qty is null or p_qty <= 0 or p_qty > 100000 or p_unit_cost is null or p_unit_cost < 0 then raise exception 'E_BAD_AMOUNT'; end if;
  if not exists (select 1 from public.items where id = p_item and shop_id = s and deleted_at is null) then raise exception 'E_NOT_FOUND'; end if;
  total := p_qty::bigint * p_unit_cost;
  if total <= 0 then raise exception 'E_BAD_AMOUNT'; end if;
  perform public.ledger_amount(total);
  e := public.ledger_post('opening', p_item, left(reason, 300),
    jsonb_build_array(public.ledger_line(public.ledger_acc('inventory'), total, 0), public.ledger_line(public.ledger_acc('capital'), 0, total)), null, p_id);
  insert into public.stock_moves(shop_id, item_id, entry_id, qty, value) values (s, p_item, e, p_qty, total);
  insert into public.audit_log(shop_id, actor_id, action, entity, entity_id, after)
  values (s, auth.uid(), 'stock_adjust', 'items', p_item, jsonb_build_object('qty', p_qty, 'unit_cost', p_unit_cost, 'value', total, 'reason', left(reason, 300), 'entry', e));
  return e;
end $$;
revoke execute on function public.stock_in(uuid, uuid, integer, bigint, text) from public, anon;
grant execute on function public.stock_in(uuid, uuid, integer, bigint, text) to authenticated;
