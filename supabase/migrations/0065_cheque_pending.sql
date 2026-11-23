-- ============================================================
-- 0065: قرار صاحب المشروع (2026-11-23): شيك العميل "تحت التحصيل" ما بيقللش دين العميل غير لما يتصرف.
-- - الاستلام: بيتسجل الشيك بس، من غير قيد (اللي على العميل زي ما هو).
-- - الصرف: قيد واحد: الخزنة (مدين) / العملاء (دائن)، وصف في payments (لو الشيك على جهاز بيتحسب مدفوع للجهاز).
-- - الرفض: الحالة بس، من غير قيد (الدين أصلًا ما اتغيرش).
-- - التسليم قبل الصرف: الشيك مش دفعة، فـ"منع التسليم قبل السداد" (E_UNPAID) بيوقفه، وصاحب المحل بس يقدر "يسلّم بالآجل" (deliver_on_credit).
-- - الشيكات القديمة (قبل الملف ده) ليها قيد استلام: بتكمّل بنفس طريقتها القديمة لحد ما تتصرف أو تترفض، عشان الدفتر يفضل متوازن.
-- - شيكات الموردين ما اتغيرتش.
-- ============================================================

alter table public.cheques alter column entry_id drop not null;
alter table public.cheques add column if not exists device_id uuid references public.devices(id);
-- رقم عملية الرفض للشيك الجديد (مالوش قيد): نفس الطلب لو اتبعت تاني (من غير نت) ما يطلعش خطأ
alter table public.cheques add column if not exists settle_op uuid;
-- فريد جوه المحل بس: الاسترجاع بينسخ القيمة لمحل جديد (زي idem_key)
create unique index if not exists cheques_settle_op on public.cheques(shop_id, settle_op) where settle_op is not null;
-- الرفض الجديد ما لوش قيد: الحالة مربوطة بتاريخ التسوية مش بالقيد
do $c$
declare n text;
begin
  -- القيد القديم ((status = 'pending') = (settle_entry_id is null)) من غير اسم صريح: بندوّر عليه بتعريفه
  for n in select conname from pg_constraint where conrelid = 'public.cheques'::regclass and contype = 'c'
             and pg_get_constraintdef(oid) like '%settle_entry_id IS NULL%' loop
    execute format('alter table public.cheques drop constraint %I', n);
  end loop;
end $c$;
alter table public.cheques drop constraint if exists cheques_settled_check;
alter table public.cheques add constraint cheques_settled_check check ((status = 'pending') = (settled_at is null));
-- الشيك الجديد (من غير قيد استلام) لعميل بس
alter table public.cheques drop constraint if exists cheques_entry_check;
alter table public.cheques add constraint cheques_entry_check check (entry_id is not null or direction = 'in');

-- ---------- استلام شيك من عميل (src: 0063_cheques.sql) + من غير قيد، وجهاز اختياري ----------
drop function if exists public.cheque_receive(uuid, uuid, text, text, date, bigint, text);
create or replace function public.cheque_receive(p_id uuid, p_customer uuid, p_no text, p_bank text, p_due date, p_amount bigint, p_note text default null, p_device uuid default null)
returns uuid
language plpgsql security definer set search_path = public as $$
declare s uuid := public.current_shop_id();
begin
  perform public.cheque_require();
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
revoke execute on function public.cheque_receive(uuid, uuid, text, text, date, bigint, text, uuid) from public, anon;
grant execute on function public.cheque_receive(uuid, uuid, text, text, date, bigint, text, uuid) to authenticated;

-- ---------- الصرف (src: 0063_cheques.sql) + شيك العميل الجديد بيقلل الدين وقت الصرف ----------
create or replace function public.cheque_clear(p_op uuid, p_cheque uuid, p_cashbox uuid)
returns uuid
language plpgsql security definer set search_path = public as $$
declare c public.cheques; cb public.accounts; e uuid;
begin
  perform public.cheque_require();
  e := public.ledger_idem(p_op);
  if e is not null then return e; end if;
  c := public.cheque_lock(p_cheque);
  if c.status <> 'pending' then raise exception 'E_CHEQUE_DONE'; end if;
  cb := public.ledger_cashbox(p_cashbox);
  if c.direction = 'in' and c.entry_id is null then
    -- جديد: دلوقتي بس الفلوس وصلت، فالدين بيقل
    e := public.ledger_post('cheque_clear', c.id, c.cheque_no, jsonb_build_array(
      public.ledger_line(cb.id, c.amount, 0),
      public.ledger_line(public.ledger_acc('ar'), 0, c.amount, 'customer', c.party_id)), c.device_id, p_op);
    insert into public.payments(id, shop_id, customer_id, device_id, cashbox_id, method, amount, entry_id, created_by)
    values (gen_random_uuid(), c.shop_id, c.party_id, c.device_id, cb.id, cb.method, c.amount, e, auth.uid());
  elsif c.direction = 'in' then
    -- قديم: الدين اتخصم وقت الاستلام
    e := public.ledger_post('cheque_clear', c.id, c.cheque_no, jsonb_build_array(
      public.ledger_line(cb.id, c.amount, 0),
      public.ledger_line(public.ledger_acc('cheques_in'), 0, c.amount, 'customer', c.party_id)), null, p_op);
  else
    e := public.ledger_post('cheque_clear', c.id, c.cheque_no, jsonb_build_array(
      public.ledger_line(public.ledger_acc('cheques_out'), c.amount, 0, 'supplier', c.party_id),
      public.ledger_line(cb.id, 0, c.amount)), null, p_op);
  end if;
  update public.cheques set status = 'cleared', settle_entry_id = e, settled_at = now() where id = c.id;
  return e;
end $$;

-- ---------- الرفض (src: 0063_cheques.sql) + شيك العميل الجديد من غير قيد ----------
create or replace function public.cheque_bounce(p_op uuid, p_cheque uuid, p_reason text)
returns uuid
language plpgsql security definer set search_path = public as $$
declare c public.cheques; e uuid;
begin
  perform public.cheque_require();
  e := public.ledger_idem(p_op);
  if e is not null then return e; end if;
  if exists (select 1 from public.cheques where settle_op = p_op and shop_id = public.current_shop_id()) then return null; end if;
  if coalesce(trim(p_reason), '') = '' then raise exception 'E_REASON_REQUIRED'; end if;
  c := public.cheque_lock(p_cheque);
  -- نفس الطلب اتبعت مرتين في نفس اللحظة: التاني بيستنى القفل، وبعدها يرجع من غير خطأ
  if c.settle_op = p_op then return null; end if;
  if c.status <> 'pending' then raise exception 'E_CHEQUE_DONE'; end if;
  if c.direction = 'in' and c.entry_id is null then
    -- جديد: الدين ما اتغيرش أصلًا، فمفيش قيد. السبب في الملاحظة وفي سجل النشاط (zz_audit)
    update public.cheques set status = 'bounced', settled_at = now(), settle_op = p_op,
      note = left(concat_ws(' · ', note, trim(p_reason)), 300) where id = c.id;
    return null;
  elsif c.direction = 'in' then
    e := public.ledger_post('cheque_bounce', c.id, left(trim(p_reason), 300), jsonb_build_array(
      public.ledger_line(public.ledger_acc('ar'), c.amount, 0, 'customer', c.party_id),
      public.ledger_line(public.ledger_acc('cheques_in'), 0, c.amount, 'customer', c.party_id)), null, p_op);
  else
    e := public.ledger_post('cheque_bounce', c.id, left(trim(p_reason), 300), jsonb_build_array(
      public.ledger_line(public.ledger_acc('cheques_out'), c.amount, 0, 'supplier', c.party_id),
      public.ledger_line(public.ledger_acc('ap'), 0, c.amount, 'supplier', c.party_id)), null, p_op);
  end if;
  update public.cheques set status = 'bounced', settle_entry_id = e, settled_at = now() where id = c.id;
  return e;
end $$;
