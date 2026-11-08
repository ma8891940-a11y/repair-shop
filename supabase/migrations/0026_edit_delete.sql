-- ============================================================
-- 0026: تعديل وحذف في كل حاجة (البند 2)
-- - الفلوس والمخزون: القيد الأصلي ما بيتلمسش أبدًا. "الحذف" = قيد عكسي، و"التعديل" = قيد عكسي + قيد جديد
--   في نفس الـ transaction (لو أي جزء فشل، ولا حاجة بتتسجل). والسبب إجباري.
-- - الصلاحية: صاحب المحل، أو موظف صاحب المحل اداله إذن "تصحيح العمليات" (profiles.can_correct).
-- - العملاء والموردين والأصناف والأجهزة: حذف ناعم (deleted_at) بس، ومن غير ما يبوّظ أي رصيد:
--   العميل أو المورد اللي عليه أو ليه فلوس ما بيتحذفش، والصنف اللي في المخزون ما بيتحذفش،
--   والجهاز اللي عليه فلوس ما بيتحذفش. وكل ده بيتسجل في سجل النشاط بالسبب.
-- ============================================================

-- 1) إذن التصحيح لموظف
alter table public.profiles add column if not exists can_correct boolean not null default false;

create or replace function public.can_correct() returns boolean
language sql stable security definer set search_path = public as $$
  select public.current_app_role() = 'owner'
      or coalesce((select p.can_correct from public.profiles p where p.id = auth.uid() and p.deleted_at is null), false)
$$;
revoke execute on function public.can_correct() from public, anon;
grant execute on function public.can_correct() to authenticated;

create or replace function public.set_can_correct(p_user uuid, p_on boolean) returns void
language plpgsql security definer set search_path = public as $$
declare o public.profiles;
begin
  perform public.ledger_require(array['owner']::public.app_role[]);
  select * into o from public.profiles where id = p_user and shop_id = public.current_shop_id();
  if not found then raise exception 'E_NOT_FOUND'; end if;
  if o.role = 'owner' then raise exception 'E_BAD_INPUT'; end if;
  perform set_config('warsha.grant', '1', true);
  update public.profiles set can_correct = p_on, updated_at = now() where id = p_user;
  perform set_config('warsha.grant', '', true);
  insert into public.audit_log(shop_id, actor_id, action, entity, entity_id, before, after)
  values (o.shop_id, auth.uid(), 'set_can_correct', 'profiles', o.id, jsonb_build_object('can_correct', o.can_correct), jsonb_build_object('can_correct', p_on));
end $$;
revoke execute on function public.set_can_correct(uuid, boolean) from public, anon;
grant execute on function public.set_can_correct(uuid, boolean) to authenticated;

-- الإذن ما بيتغيرش غير من set_can_correct (ولا حتى الموظف لنفسه)
create or replace function public.tg_profile_grant_guard() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if new.can_correct is distinct from old.can_correct and coalesce(current_setting('warsha.grant', true), '') <> '1' and not public.restoring() then
    raise exception 'E_FORBIDDEN';
  end if;
  return new;
end $$;
drop trigger if exists profile_grant_guard on public.profiles;
create trigger profile_grant_guard before update on public.profiles for each row execute function public.tg_profile_grant_guard();

-- 2) الإلغاء بقيد عكسي: صاحب المحل أو اللي معاه الإذن (نفس جسم 0025 بالظبط، والصلاحية بس اللي اتغيرت)
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
  if public.current_app_role() is null or not public.can_correct() then raise exception 'E_FORBIDDEN'; end if;
  if nullif(trim(p_reason), '') is null then raise exception 'E_REASON_REQUIRED'; end if;
  select * into o from public.journal_entries where id = p_entry and shop_id = public.current_shop_id() for update;
  if not found then raise exception 'E_NOT_FOUND'; end if;
  if o.source_type in ('reversal', 'cost_adjust') or exists (select 1 from public.journal_entries where reverses_id = o.id) then
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
  for mv in select distinct item_id from public.stock_moves where entry_id = o.id loop
    perform public.ledger_settle_item(mv.item_id, o.device_id);
  end loop;
  insert into public.audit_log(shop_id, actor_id, action, entity, entity_id, before, after)
  values (o.shop_id, auth.uid(), 'reverse_entry', 'journal_entries', o.id, to_jsonb(o), jsonb_build_object('reversal_id', e, 'reason', p_reason));
  return e;
end $function$;

-- 3) بيانات العملية عشان شاشة التعديل تتملي بيها (من القيد نفسه)
create or replace function public.entry_args(p_entry uuid) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare
  o public.journal_entries;
  cash_in uuid; cash_out uuid; amt bigint; party uuid; acc uuid; res jsonb; pay public.payments; pur public.purchases;
  ls jsonb; rev bigint; cust uuid;
begin
  if public.current_app_role() is null or not public.can_correct() then raise exception 'E_FORBIDDEN'; end if;
  select * into o from public.journal_entries where id = p_entry and shop_id = public.current_shop_id();
  if not found then raise exception 'E_NOT_FOUND'; end if;
  select max(l.account_id::text) filter (where a.kind = 'cash' and l.debit > 0)::uuid,
         max(l.account_id::text) filter (where a.kind = 'cash' and l.credit > 0)::uuid,
         max(l.party_id::text) filter (where l.party_id is not null)::uuid,
         max(l.account_id::text) filter (where a.kind = 'expense' and l.debit > 0)::uuid,
         greatest(sum(l.debit), 0)
    into cash_in, cash_out, party, acc, amt
  from public.journal_lines l join public.accounts a on a.id = l.account_id where l.entry_id = o.id;
  res := jsonb_build_object('source_type', o.source_type, 'entry_no', o.entry_no, 'note', o.memo,
    'reversed', exists (select 1 from public.journal_entries where reverses_id = o.id),
    'editable', o.source_type in ('payment', 'expense', 'transfer', 'capital', 'drawing', 'advance', 'salary', 'salary_payment', 'supplier_payment', 'purchase', 'sale'));
  if o.source_type = 'payment' then
    select * into pay from public.payments where entry_id = o.id;
    res := res || jsonb_build_object('customer', pay.customer_id, 'device', pay.device_id, 'cashbox', pay.cashbox_id, 'method', pay.method, 'amount', pay.amount);
  elsif o.source_type = 'expense' then
    res := res || jsonb_build_object('account', acc, 'cashbox', cash_out, 'amount', amt);
  elsif o.source_type = 'transfer' then
    res := res || jsonb_build_object('from', cash_out, 'to', cash_in, 'amount', amt);
  elsif o.source_type = 'capital' then
    res := res || jsonb_build_object('cashbox', cash_in, 'amount', amt);
  elsif o.source_type = 'drawing' then
    res := res || jsonb_build_object('cashbox', cash_out, 'amount', amt);
  elsif o.source_type in ('advance', 'salary_payment') then
    res := res || jsonb_build_object('employee', party, 'cashbox', cash_out, 'amount', amt);
  elsif o.source_type = 'salary' then
    res := res || jsonb_build_object('employee', party, 'amount', amt);
  elsif o.source_type = 'supplier_payment' then
    res := res || jsonb_build_object('supplier', party, 'cashbox', cash_out, 'amount', amt);
  elsif o.source_type = 'purchase' then
    select * into pur from public.purchases where entry_id = o.id;
    select jsonb_agg(jsonb_build_object('item', m.item_id, 'qty', m.qty, 'unit_cost', m.value / nullif(m.qty, 0)) order by m.created_at) into ls
    from public.stock_moves m where m.entry_id = o.id;
    res := res || jsonb_build_object('supplier', pur.supplier_id, 'cashbox', cash_out, 'lines', coalesce(ls, '[]'::jsonb));
  elsif o.source_type = 'sale' then
    -- سعر البيع: لو صنف واحد بيتحسب من الإيراد، ولو أكتر من صنف بيتاخد سعر الصنف المسجل
    select coalesce(sum(l.credit), 0) into rev from public.journal_lines l join public.accounts a on a.id = l.account_id where l.entry_id = o.id and a.type = 'revenue';
    select max(l.party_id::text) filter (where l.party_type = 'customer')::uuid into cust from public.journal_lines l where l.entry_id = o.id;
    select jsonb_agg(jsonb_build_object('item', x.item_id, 'qty', x.q,
             'price', case when x.n = 1 then rev / x.q else coalesce(i.sale_price, 0) end) order by x.first)
      into ls
    from (select m.item_id, -sum(m.qty) q, count(*) over () n, min(m.created_at) first from public.stock_moves m where m.entry_id = o.id group by m.item_id) x
    join public.items i on i.id = x.item_id;
    res := res || jsonb_build_object('customer', cust, 'cashbox', cash_in, 'lines', coalesce(ls, '[]'::jsonb));
  end if;
  return res;
end $$;
revoke execute on function public.entry_args(uuid) from public, anon;
grant execute on function public.entry_args(uuid) to authenticated;

-- 4) التعديل: قيد عكسي للأصل + نفس نوع العملية بالبيانات الجديدة، في نفس الـ transaction
-- p_new.id = id العملية الجديدة (من التطبيق). لو نفس التعديل اتبعت مرتين (مزامنة)، بيرجع نفس النتيجة من غير تكرار.
create or replace function public.edit_entry(p_entry uuid, p_reason text, p_new jsonb) returns uuid
language plpgsql security definer set search_path = public as $$
declare
  o public.journal_entries;
  nid uuid := (p_new ->> 'id')::uuid;
  e uuid;
  amt bigint := (p_new ->> 'amount')::bigint;
  note text := nullif(trim(p_new ->> 'note'), '');
begin
  if public.current_app_role() is null or not public.can_correct() then raise exception 'E_FORBIDDEN'; end if;
  if nid is null then raise exception 'E_BAD_INPUT'; end if;
  e := public.ledger_idem(nid);
  if e is not null then return e; end if;
  select * into o from public.journal_entries where id = p_entry and shop_id = public.current_shop_id();
  if not found then raise exception 'E_NOT_FOUND'; end if;
  perform public.reverse_entry(p_entry, p_reason);
  case o.source_type
    when 'payment' then e := public.record_payment(nid, (p_new ->> 'customer')::uuid, (p_new ->> 'cashbox')::uuid, amt, (p_new ->> 'device')::uuid, p_new ->> 'method', note);
    when 'expense' then e := public.record_expense(nid, (p_new ->> 'account')::uuid, (p_new ->> 'cashbox')::uuid, amt, note);
    when 'transfer' then e := public.transfer_cash(nid, (p_new ->> 'from')::uuid, (p_new ->> 'to')::uuid, amt, note);
    when 'capital' then e := public.owner_capital(nid, (p_new ->> 'cashbox')::uuid, amt, note);
    when 'drawing' then e := public.owner_drawing(nid, (p_new ->> 'cashbox')::uuid, amt, note);
    when 'advance' then e := public.give_advance(nid, (p_new ->> 'employee')::uuid, (p_new ->> 'cashbox')::uuid, amt, note);
    when 'salary' then e := public.accrue_salary(nid, (p_new ->> 'employee')::uuid, amt, note);
    when 'salary_payment' then e := public.pay_salary(nid, (p_new ->> 'employee')::uuid, (p_new ->> 'cashbox')::uuid, amt, note);
    when 'supplier_payment' then e := public.pay_supplier(nid, (p_new ->> 'supplier')::uuid, (p_new ->> 'cashbox')::uuid, amt, note);
    when 'purchase' then e := public.record_purchase(nid, (p_new ->> 'supplier')::uuid, p_new -> 'lines', (p_new ->> 'cashbox')::uuid, note);
    when 'sale' then e := public.record_sale(nid, p_new -> 'lines', (p_new ->> 'cashbox')::uuid, (p_new ->> 'customer')::uuid, note);
    else raise exception 'E_NOT_EDITABLE';
  end case;
  insert into public.audit_log(shop_id, actor_id, action, entity, entity_id, before, after)
  values (o.shop_id, auth.uid(), 'edit_entry', 'journal_entries', o.id, to_jsonb(o), jsonb_build_object('new_entry', e, 'reason', p_reason));
  return e;
end $$;
revoke execute on function public.edit_entry(uuid, text, jsonb) from public, anon;
grant execute on function public.edit_entry(uuid, text, jsonb) to authenticated;

-- 5) الحذف الناعم الآمن: عميل، مورد، صنف، جهاز
create or replace function public.soft_delete(p_kind text, p_id uuid, p_reason text default null) returns void
language plpgsql security definer set search_path = public as $$
declare s uuid := public.current_shop_id(); before jsonb; tbl text;
begin
  if public.current_app_role() is null or not public.can_correct() then raise exception 'E_FORBIDDEN'; end if;
  if p_kind = 'customer' then
    tbl := 'customers';
    select to_jsonb(c) into before from public.customers c where id = p_id and shop_id = s and deleted_at is null for update;
    if before is null then raise exception 'E_NOT_FOUND'; end if;
    if exists (select 1 from public.journal_lines l where l.party_id = p_id and l.shop_id = s group by l.account_id having sum(l.debit - l.credit) <> 0) then raise exception 'E_HAS_BALANCE'; end if;
    if exists (select 1 from public.devices d where d.customer_id = p_id and d.deleted_at is null and d.status not in ('delivered', 'unrepairable')) then raise exception 'E_HAS_OPEN_DEVICES'; end if;
  elsif p_kind = 'supplier' then
    tbl := 'suppliers';
    select to_jsonb(x) into before from public.suppliers x where id = p_id and shop_id = s and deleted_at is null for update;
    if before is null then raise exception 'E_NOT_FOUND'; end if;
    if exists (select 1 from public.journal_lines l where l.party_id = p_id and l.shop_id = s group by l.account_id having sum(l.debit - l.credit) <> 0) then raise exception 'E_HAS_BALANCE'; end if;
  elsif p_kind = 'item' then
    tbl := 'items';
    select to_jsonb(x) into before from public.items x where id = p_id and shop_id = s and deleted_at is null for update;
    if before is null then raise exception 'E_NOT_FOUND'; end if;
    if (select coalesce(sum(qty), 0) <> 0 or coalesce(sum(value), 0) <> 0 from public.stock_moves where item_id = p_id) then raise exception 'E_HAS_STOCK'; end if;
  elsif p_kind = 'device' then
    tbl := 'devices';
    select to_jsonb(x) into before from public.devices x where id = p_id and shop_id = s and deleted_at is null for update;
    if before is null then raise exception 'E_NOT_FOUND'; end if;
    if exists (select 1 from public.journal_entries e where e.device_id = p_id and not exists (select 1 from public.journal_entries r where r.reverses_id = e.id) and e.source_type not in ('reversal', 'cost_adjust')) then
      raise exception 'E_HAS_MONEY';
    end if;
  else
    raise exception 'E_BAD_INPUT';
  end if;
  perform set_config('warsha.system', 'on', true);
  execute format('update public.%I set deleted_at = now(), updated_at = now() where id = $1', tbl) using p_id;
  perform set_config('warsha.system', 'off', true);
  insert into public.audit_log(shop_id, actor_id, action, entity, entity_id, before, after)
  values (s, auth.uid(), 'soft_delete', tbl, p_id, before, jsonb_build_object('reason', nullif(trim(p_reason), '')));
end $$;
revoke execute on function public.soft_delete(text, uuid, text) from public, anon;
grant execute on function public.soft_delete(text, uuid, text) to authenticated;

-- ملاحظة: الأرشفة المباشرة (update deleted_at) لسه لصاحب المحل بس زي قاعدة 0021 (tg_owner_soft_delete).
-- soft_delete بتعدّي القاعدة دي للموظف اللي معاه إذن التصحيح، بعد ما تتأكد إن الحذف مش هيبوّظ أي رصيد.
drop trigger if exists soft_delete_guard on public.customers;
drop trigger if exists soft_delete_guard on public.suppliers;
drop trigger if exists soft_delete_guard on public.items;
drop trigger if exists soft_delete_guard on public.devices;
drop function if exists public.tg_soft_delete_guard();
