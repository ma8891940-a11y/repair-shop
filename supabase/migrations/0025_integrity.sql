-- 0025: دقة الحسابات
--
-- 1) خطأ اتلقى: إلغاء (قيد عكسي) لشراء بعد ما جزء من البضاعة اتصرف ممكن يسيب الصنف بكمية صفر وقيمة، أو بقيمة بالسالب
--    (مثال: 5 بـ 100 و10 بـ 1، صرف 9، إلغاء الشراء الأول = وحدة واحدة بقيمة -296 قرش). وده بيخلّي تكلفة أي صرف بعد كده غلط.
--    الحل: بعد أي إلغاء فيه مخزون، الصنف بيتسوّى: الفرق بيروح "فرق تكلفة" (تكلفة البضاعة) بقيد متوازن، والقيمة بتبقى صح.
-- 2) فحص سلامة تلقائي (integrity_report) لصاحب المحل: أي فرق بيظهر بالمكان والمبلغ.

alter table public.journal_entries drop constraint if exists journal_entries_source_type_check;
alter table public.journal_entries add constraint journal_entries_source_type_check check (source_type = any (array[
  'payment', 'delivery', 'purchase', 'supplier_payment', 'part_use', 'sale', 'expense', 'salary', 'salary_payment', 'advance',
  'advance_settle', 'capital', 'drawing', 'transfer', 'drawer_close', 'reversal', 'cost_adjust']));
-- حركة تسوية القيمة: كمية صفر وقيمة
alter table public.stock_moves drop constraint if exists stock_moves_qty_check;
alter table public.stock_moves add constraint stock_moves_qty_check check (qty <> 0 or value <> 0);

-- تسوية صنف: لو كميته صفر وفيه قيمة باقية، أو قيمته بالسالب، الفرق بيروح تكلفة البضاعة
create or replace function public.ledger_settle_item(p_item uuid, p_device uuid default null) returns void
language plpgsql security definer set search_path = public as $$
declare st record; v bigint; e uuid;
begin
  select * into st from public.item_stock(p_item);
  if not ((st.qty = 0 and st.value <> 0) or (st.qty > 0 and st.value < 0)) then return; end if;
  v := st.value;
  e := public.ledger_post('cost_adjust', p_item, 'فرق تكلفة مخزون',
    case when v > 0 then jsonb_build_array(public.ledger_line(public.ledger_acc('cogs'), v, 0), public.ledger_line(public.ledger_acc('inventory'), 0, v))
         else jsonb_build_array(public.ledger_line(public.ledger_acc('inventory'), -v, 0), public.ledger_line(public.ledger_acc('cogs'), 0, -v)) end,
    p_device);
  insert into public.stock_moves(shop_id, item_id, entry_id, qty, value) values (public.current_shop_id(), p_item, e, 0, -v);
end $$;
revoke execute on function public.ledger_settle_item(uuid, uuid) from public, anon, authenticated;

CREATE OR REPLACE FUNCTION public.reverse_entry(p_entry uuid, p_reason text)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  o public.journal_entries;
  e uuid;
  lines jsonb;
  mv record;
begin
  perform public.ledger_require(array['owner']::public.app_role[]);
  if nullif(trim(p_reason), '') is null then raise exception 'E_BAD_INPUT'; end if;
  select * into o from public.journal_entries where id = p_entry and shop_id = public.current_shop_id() for update;
  if not found then raise exception 'E_NOT_FOUND'; end if;
  if o.source_type = 'reversal' or exists (select 1 from public.journal_entries where reverses_id = o.id) then
    raise exception 'E_ALREADY_REVERSED';
  end if;
  select jsonb_agg(public.ledger_line(account_id, credit, debit, party_type, party_id)) into lines
  from public.journal_lines where entry_id = o.id;
  e := public.ledger_post('reversal', o.source_id, p_reason, lines, o.device_id, null, o.id);
  for mv in select * from public.stock_moves where entry_id = o.id loop
    perform 1 from public.items where id = mv.item_id for update;
    if (select coalesce(sum(qty), 0) from public.stock_moves where item_id = mv.item_id) - mv.qty < 0 then
      raise exception 'E_STOCK';
    end if;
    insert into public.stock_moves(shop_id, item_id, entry_id, qty, value) values (mv.shop_id, mv.item_id, e, -mv.qty, -mv.value);
  end loop;
  -- (0025) بعد إلغاء حركة مخزون: لو الصنف بقى كميته صفر وفيه قيمة، أو قيمته بالسالب، الفرق بيروح "فرق تكلفة"
  for mv in select distinct item_id from public.stock_moves where entry_id = o.id loop
    perform public.ledger_settle_item(mv.item_id, o.device_id);
  end loop;
  insert into public.audit_log(shop_id, actor_id, action, entity, entity_id, before, after)
  values (o.shop_id, auth.uid(), 'reverse_entry', 'journal_entries', o.id, to_jsonb(o), jsonb_build_object('reversal_id', e, 'reason', p_reason));
  return e;
end $function$;

-- ============================================================
-- فحص السلامة
-- ============================================================
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
           where i.shop_id = s group by i.id having coalesce(sum(m.qty), 0) < 0 or (coalesce(sum(m.qty), 0) = 0 and coalesce(sum(m.value), 0) <> 0) or coalesce(sum(m.value), 0) < 0 loop
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
           where l.shop_id = s and a.kind in ('receivable', 'payable', 'advances', 'salaries') and l.party_id is null group by l.entry_id, e.entry_no loop
    out := out || jsonb_build_array(jsonb_build_object('kind', 'party_missing', 'amount', r.amt, 'entry_id', r.entry_id, 'entry_no', r.entry_no));
  end loop;
  -- 7) كل سطر في نفس محل القيد
  for r in select l.entry_id, e.entry_no from public.journal_lines l join public.journal_entries e on e.id = l.entry_id where e.shop_id = s and l.shop_id <> e.shop_id group by 1, 2 loop
    out := out || jsonb_build_array(jsonb_build_object('kind', 'shop_mismatch', 'amount', 0, 'entry_id', r.entry_id, 'entry_no', r.entry_no));
  end loop;
  return out;
end $$;
revoke execute on function public.integrity_report() from public, anon;
grant execute on function public.integrity_report() to authenticated;
