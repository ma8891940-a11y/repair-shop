-- 0074: (22ب) ضغطتين متزامنتين على استلام شيك أو إصداره أو حفظ خطة أقساط: التاني بيستنى الأول ويرجّع نفس الرقم من غير خطأ.
-- ledger_idem (0067) بياخد القفل على رقم العملية قبل ما الدالة تبص هي موجودة ولا لأ.

-- cheque_receive: (src: 0065_cheque_pending.sql) + القفل
create or replace function public.cheque_receive(p_id uuid, p_customer uuid, p_no text, p_bank text, p_due date, p_amount bigint, p_note text default null, p_device uuid default null)
returns uuid
language plpgsql security definer set search_path = public as $$
declare s uuid := public.current_shop_id();
begin
  perform public.cheque_require();
  perform public.ledger_idem(p_id);
  if exists (select 1 from public.cheques where id = p_id) then return p_id; end if;
  perform public.ledger_amount(p_amount);
  if coalesce(trim(p_no), '') = '' or p_due is null then raise exception 'E_BAD_INPUT'; end if;
  if not exists (select 1 from public.customers where id = p_customer and shop_id = s and deleted_at is null) then raise exception 'E_NOT_FOUND'; end if;
  if p_device is not null and not exists (select 1 from public.devices where id = p_device and shop_id = s and customer_id = p_customer and deleted_at is null and public.can_branch(branch_id)) then
    raise exception 'E_NOT_FOUND';
  end if;
  insert into public.cheques(id, shop_id, branch_id, direction, party_type, party_id, cheque_no, bank, due_date, amount, entry_id, device_id, note, created_by)
  values (p_id, s, public.op_branch(), 'in', 'customer', p_customer, trim(p_no), nullif(trim(p_bank), ''), p_due, p_amount, null, p_device, nullif(trim(p_note), ''), auth.uid());
  return p_id;
end $$;

-- cheque_issue: (src: 0063_cheques.sql) + القفل
create or replace function public.cheque_issue(p_id uuid, p_supplier uuid, p_no text, p_bank text, p_due date, p_amount bigint, p_note text default null)
returns uuid
language plpgsql security definer set search_path = public as $$
declare s uuid := public.current_shop_id(); e uuid;
begin
  perform public.cheque_require();
  perform public.ledger_idem(p_id);
  if exists (select 1 from public.cheques where id = p_id) then return p_id; end if;
  perform public.ledger_amount(p_amount);
  if coalesce(trim(p_no), '') = '' or p_due is null then raise exception 'E_BAD_INPUT'; end if;
  if not exists (select 1 from public.suppliers where id = p_supplier and shop_id = s and deleted_at is null) then raise exception 'E_NOT_FOUND'; end if;
  e := public.ledger_post('cheque_out', p_id, nullif(trim(p_note), ''), jsonb_build_array(
    public.ledger_line(public.ledger_acc('ap'), p_amount, 0, 'supplier', p_supplier),
    public.ledger_line(public.ledger_acc('cheques_out'), 0, p_amount, 'supplier', p_supplier)), null, p_id);
  insert into public.cheques(id, shop_id, branch_id, direction, party_type, party_id, cheque_no, bank, due_date, amount, entry_id, note, created_by)
  values (p_id, s, public.op_branch(), 'out', 'supplier', p_supplier, trim(p_no), nullif(trim(p_bank), ''), p_due, p_amount, e, nullif(trim(p_note), ''), auth.uid());
  return p_id;
end $$;

-- save_plan: (src: 0039_payment_plans.sql) + القفل
create or replace function public.save_plan(p_id uuid, p_party_type text, p_party uuid, p_rows jsonb, p_title text default null, p_note text default null) returns uuid
language plpgsql security definer set search_path = public as $$
declare s uuid := public.current_shop_id(); r jsonb; n integer := 0; tot bigint := 0; a bigint; d date;
begin
  perform public.grant_require('finance', 'add');
  perform public.ledger_idem(p_id);
  if exists (select 1 from public.payment_plans where id = p_id) then
    if exists (select 1 from public.payment_plans where id = p_id and shop_id = s) then return p_id; end if;
    raise exception 'E_NOT_FOUND';
  end if;
  if p_party_type not in ('customer', 'supplier') then raise exception 'E_BAD_INPUT'; end if;
  if p_party_type = 'customer' and not exists (select 1 from public.customers where id = p_party and shop_id = s and deleted_at is null) then raise exception 'E_NOT_FOUND'; end if;
  if p_party_type = 'supplier' and not exists (select 1 from public.suppliers where id = p_party and shop_id = s and deleted_at is null) then raise exception 'E_NOT_FOUND'; end if;
  if jsonb_typeof(p_rows) <> 'array' or jsonb_array_length(p_rows) not between 1 and 120 then raise exception 'E_BAD_INPUT'; end if;
  insert into public.payment_plans(id, shop_id, branch_id, party_type, party_id, title, total, note, created_by)
  values (p_id, s, public.op_branch(), p_party_type, p_party, nullif(trim(p_title), ''), 1, nullif(trim(p_note), ''), auth.uid());
  for r in select * from jsonb_array_elements(p_rows) loop
    n := n + 1;
    a := (r ->> 'amount')::bigint;
    d := (r ->> 'due')::date;
    if a is null or a <= 0 or d is null then raise exception 'E_BAD_AMOUNT'; end if;
    perform public.ledger_amount(a);
    tot := tot + a;
    insert into public.plan_installments(shop_id, plan_id, seq, due_date, amount) values (s, p_id, n, d, a);
  end loop;
  perform public.ledger_amount(tot);
  update public.payment_plans set total = tot where id = p_id;
  return p_id;
end $$;
