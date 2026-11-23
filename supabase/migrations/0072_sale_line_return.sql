-- 0072: (3) مرتجع مربوط بسطر البيع: بكميته وسعره وضريبته وتكلفته وقت البيع، وما يزيدش عن اللي اتباع.
-- صف المرتجع في sale_lines نفسه: return_of = سطر البيع الأصلي، وentry_id = قيد المرتجع. إضافة بس زي الباقي.

alter table public.sale_lines add column return_of uuid references public.sale_lines(id);
create index sale_lines_return_of on public.sale_lines(return_of) where return_of is not null;

-- نوع الصنف بيحدد حساب إيراده: صنف اتباع ما يتغيّرش نوعه (المرتجع وتقسيم الإيراد بيعتمدوا عليه)
create or replace function public.tg_item_kind_fixed() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if new.kind is distinct from old.kind and not public.restoring() and exists (select 1 from public.sale_lines l where l.item_id = old.id) then
    raise exception 'E_ITEM_KIND';
  end if;
  return new;
end $$;
create trigger b_item_kind_fixed before update of kind on public.items for each row execute function public.tg_item_kind_fixed();
create index sale_lines_item on public.sale_lines(item_id);

-- حساب الإيراد من نوع الصنف (نفس تقسيم record_sale)
create or replace function public.item_rev_code(p_kind text) returns text
language sql immutable as $$
  select case p_kind when 'service' then 'rev_repair' when 'part' then 'rev_parts' else 'rev_accessories' end
$$;
revoke execute on function public.item_rev_code(text) from public, anon, authenticated;

-- اللي رجع من سطر بيع (المرتجع الملغي بقيد عكسي ما بيتحسبش)
create or replace function public.sale_line_returned(p_line uuid) returns bigint
language sql stable security definer set search_path = public as $$
  select coalesce(sum(r.qty), 0)::bigint from public.sale_lines r
  where r.return_of = p_line and not exists (select 1 from public.journal_entries x where x.reverses_id = r.entry_id)
$$;
revoke execute on function public.sale_line_returned(uuid) from public, anon, authenticated;

-- الفاتورة برقمها عشان المرتجع: السطور واللي رجع من كل سطر، من غير تكلفة ولا بيانات العميل
create or replace function public.sale_for_return(p_no bigint) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare s uuid := public.current_shop_id(); o public.journal_entries;
begin
  perform public.ledger_require(array['owner', 'reception']::public.app_role[]);
  if public.has_perm('sales', 'edit') is not true then raise exception 'E_FORBIDDEN'; end if;
  select * into o from public.journal_entries where entry_no = p_no and shop_id = s and source_type = 'sale'
    and (public.current_app_role() = 'owner' or public.can_branch(branch_id))
    -- بعد الاسترجاع ممكن رقم قديم يتكرر: الأحدث (والشاشة بتعرض التاريخ)
    order by occurred_at desc limit 1;
  if not found then raise exception 'E_NOT_FOUND'; end if;
  return jsonb_build_object('entry', o.id, 'entry_no', o.entry_no, 'at', o.occurred_at, 'branch_id', o.branch_id,
    'cancelled', exists (select 1 from public.journal_entries r where r.reverses_id = o.id),
    'credit', exists (select 1 from public.journal_lines l join public.accounts a on a.id = l.account_id where l.entry_id = o.id and a.kind = 'receivable'),
    'has_customer', exists (select 1 from public.sale_lines l join public.customers c on c.id = l.customer_id and c.deleted_at is null where l.entry_id = o.id),
    'lines', coalesce((select jsonb_agg(jsonb_build_object('id', l.id, 'name', l.name, 'qty', l.qty, 'price', l.price, 'returned', public.sale_line_returned(l.id),
        'service', i.kind = 'service') order by l.seq)
      from public.sale_lines l join public.items i on i.id = l.item_id where l.entry_id = o.id), '[]'::jsonb));
end $$;
revoke execute on function public.sale_for_return(bigint) from public, anon;
grant execute on function public.sale_for_return(bigint) to authenticated;

create or replace function public.sale_line_return(p_id uuid, p_line uuid, p_qty integer, p_cashbox uuid default null, p_restock boolean default true, p_reason text default null) returns uuid
language plpgsql security definer set search_path = public as $$
declare
  s uuid := public.current_shop_id(); e uuid; sl public.sale_lines; o public.journal_entries; it public.items; cb public.accounts;
  cust uuid; amt bigint; rev uuid; gross bigint; net bigint; back bigint; vat_back bigint; v bigint;
  sold bigint; sold_cost bigint; item_back bigint; cost_back bigint; cost bigint := 0;
begin
  perform public.ledger_require(array['owner', 'reception']::public.app_role[]);
  perform public.perm_require('sales', 'edit');
  e := public.ledger_idem(p_id);
  if e is not null then return e; end if;
  if nullif(trim(p_reason), '') is null then raise exception 'E_REASON_REQUIRED'; end if;
  select * into sl from public.sale_lines where id = p_line and shop_id = s and return_of is null;
  if not found then raise exception 'E_NOT_FOUND'; end if;
  -- القفل على قيد البيع: مرتجعين في نفس اللحظة (أو مرتجع وإلغاء) ما يعدّوش مع بعض
  select * into o from public.journal_entries where id = sl.entry_id and shop_id = s and source_type = 'sale' for update;
  if not found then raise exception 'E_NOT_FOUND'; end if;
  if public.current_app_role() <> 'owner' and not public.can_branch(o.branch_id) then raise exception 'E_FORBIDDEN'; end if;
  if exists (select 1 from public.journal_entries r where r.reverses_id = o.id) then raise exception 'E_ALREADY_REVERSED'; end if;
  -- موبايل مستعمل: بيترجع بإلغاء بيعه (عشان حالته ترجع "متاح")
  if exists (select 1 from public.used_devices u where u.sold_entry = o.id and u.item_id = sl.item_id) then raise exception 'E_USED_RETURN'; end if;
  if p_qty is null or p_qty <= 0 then raise exception 'E_RETURN_QTY'; end if;
  select * into it from public.items where id = sl.item_id and shop_id = s for update;
  if p_restock and it.deleted_at is not null then raise exception 'E_NOT_FOUND'; end if;
  amt := p_qty * sl.price;
  perform set_config('app.branch', o.branch_id::text, true);

  -- البيع الآجل بيتخصم من حساب العميل بس (ما ياخدش كاش على حاجة ما دفعهاش)، والكاش من خزنة فرع البيع أو رصيد للعميل المعروف
  select max(l.party_id::text)::uuid into cust from public.journal_lines l join public.accounts a on a.id = l.account_id where l.entry_id = o.id and a.kind = 'receivable';
  if cust is not null then
    if p_cashbox is not null then raise exception 'E_RETURN_CREDIT'; end if;
  elsif p_cashbox is not null then
    cb := public.ledger_cashbox(p_cashbox);
    if cb.branch_id is distinct from o.branch_id then raise exception 'E_BAD_BRANCH'; end if;
  else
    select c.id into cust from public.customers c where c.id = sl.customer_id and c.deleted_at is null;
    if cust is null and amt > 0 then raise exception 'E_BAD_INPUT'; end if;
  end if;

  -- الضريبة من قيد البيع نفسه (مش النسبة الحالية): نصيب تراكمي من نفس نوع الإيراد، فآخر مرتجع بيقفلها بالقرش
  rev := public.ledger_acc(public.item_rev_code(it.kind));
  select coalesce(sum(l.qty * l.price), 0) into gross from public.sale_lines l join public.items i on i.id = l.item_id
    where l.entry_id = o.id and public.item_rev_code(i.kind) = public.item_rev_code(it.kind);
  select coalesce(sum(l.credit), 0) into net from public.journal_lines l where l.entry_id = o.id and l.account_id = rev;
  -- نوع الصنف اتغيّر قبل ما يتمنع تغييره: الإيراد مش في نفس الحساب
  if amt > 0 and (net <= 0 or net > gross or (gross > net and not exists (
      select 1 from public.journal_lines l join public.accounts a on a.id = l.account_id where l.entry_id = o.id and a.kind = 'tax' and l.credit >= gross - net))) then raise exception 'E_BAD_INPUT'; end if;
  select coalesce(sum(r.qty * r.price), 0),
         coalesce(sum((select sum(l.debit) from public.journal_lines l join public.accounts a on a.id = l.account_id where l.entry_id = r.entry_id and a.kind = 'tax')), 0)
    into back, vat_back
  from public.sale_lines r join public.sale_lines b on b.id = r.return_of join public.items i on i.id = b.item_id
  where b.entry_id = o.id and not exists (select 1 from public.journal_entries x where x.reverses_id = r.entry_id)
    and public.item_rev_code(i.kind) = public.item_rev_code(it.kind);
  v := 0;
  if gross > net then
    -- أقرب قرش بأعداد صحيحة (numeric عشان المبالغ الكبيرة ما تفيضش)
    v := div((gross - net)::numeric * (back + amt) * 2 + gross, 2 * gross::numeric)::bigint - vat_back;
    v := least(greatest(v, 0), amt);
  end if;

  -- التكلفة زي ما خرجت في البيع نفسه، بنصيب تراكمي من اللي رجع المخزون فعلًا
  if it.kind <> 'service' and p_restock then
    select coalesce(-sum(m.qty), 0), coalesce(-sum(m.value), 0) into sold, sold_cost from public.stock_moves m where m.entry_id = o.id and m.item_id = sl.item_id;
    -- بيع من غير تكلفة (بيتسوى وقت الشراء): تكلفته مش معروفة من البيع، فبيترجع من غير فاتورة
    if sold <= 0 or exists (select 1 from public.uncosted_sales u where u.entry_id = o.id and u.item_id = sl.item_id and u.deleted_at is null) then raise exception 'E_RETURN_UNCOSTED'; end if;
    select coalesce(sum(m.qty), 0), coalesce(sum(m.value), 0) into item_back, cost_back
      from public.stock_moves m join public.sale_lines r on r.entry_id = m.entry_id and r.item_id = m.item_id join public.sale_lines b on b.id = r.return_of
      where b.entry_id = o.id and m.item_id = sl.item_id and not exists (select 1 from public.journal_entries x where x.reverses_id = r.entry_id);
    cost := greatest(0, div(sold_cost::numeric * (item_back + p_qty), sold::numeric)::bigint - 0);
  end if;
  if amt = 0 and cost = 0 then raise exception 'E_BAD_AMOUNT'; end if;

  e := gen_random_uuid();
  insert into public.journal_entries(id, shop_id, source_type, source_id, memo, idem_key, created_by)
  values (e, s, 'sale_return', sl.item_id, left(trim(p_reason), 300), p_id, auth.uid());
  insert into public.sale_lines(shop_id, entry_id, item_id, name, qty, price, seq, customer_id, return_of)
  values (s, e, sl.item_id, sl.name, p_qty, sl.price, 1, coalesce(cust, sl.customer_id), sl.id);
  if amt > 0 then
    if amt > v then insert into public.journal_lines(shop_id, entry_id, account_id, debit, credit) values (s, e, rev, amt - v, 0); end if;
    if v > 0 then insert into public.journal_lines(shop_id, entry_id, account_id, debit, credit) values (s, e, public.ledger_acc('vat_payable'), v, 0); end if;
    if cb.id is not null then
      insert into public.journal_lines(shop_id, entry_id, account_id, debit, credit) values (s, e, cb.id, 0, amt);
    else
      insert into public.journal_lines(shop_id, entry_id, account_id, party_type, party_id, debit, credit) values (s, e, public.ledger_acc('ar'), 'customer', cust, 0, amt);
    end if;
  end if;
  -- السليم بيرجع المخزون، والتالف تكلفته بتفضل مصروف (زي sale_return)
  if it.kind <> 'service' and p_restock then
    if cost > 0 then
      insert into public.journal_lines(shop_id, entry_id, account_id, debit, credit) values
        (s, e, public.ledger_acc('inventory'), cost, 0), (s, e, public.ledger_acc('cogs'), 0, cost);
    end if;
    insert into public.stock_moves(shop_id, item_id, entry_id, qty, value) values (s, sl.item_id, e, p_qty, cost);
  end if;
  return e;
end $$;
revoke execute on function public.sale_line_return(uuid, uuid, integer, uuid, boolean, text) from public, anon;
grant execute on function public.sale_line_return(uuid, uuid, integer, uuid, boolean, text) to authenticated;

-- reverse_entry: (src: 0070_perm_matrix.sql) + بيع رجع منه حاجة ما يتلغيش قبل ما المرتجع نفسه يتلغي (الفلوس ما ترجعش مرتين)
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
  -- C3: كلمة السر الرئيسية (لو صاحب المحل حددها)
  perform public.master_require();
  if nullif(trim(p_reason), '') is null then raise exception 'E_REASON_REQUIRED'; end if;
  select * into o from public.journal_entries where id = p_entry and shop_id = public.current_shop_id() for update;
  if not found then raise exception 'E_NOT_FOUND'; end if;
  perform public.entry_require(o.id);
  if o.source_type in ('reversal', 'cost_adjust') or exists (select 1 from public.journal_entries where reverses_id = o.id) then
    raise exception 'E_ALREADY_REVERSED';
  end if;
  if o.source_type = 'sale' and exists (select 1 from public.sale_lines sl where sl.entry_id = o.id and public.sale_line_returned(sl.id) > 0) then
    raise exception 'E_HAS_RETURNS';
  end if;
  select jsonb_agg(public.ledger_line(account_id, credit, debit, party_type, party_id)) into lines
  from public.journal_lines where entry_id = o.id;
  -- العكس بيتسجل في نفس فرع القيد الأصلي
  perform set_config('app.branch', o.branch_id::text, true);
  e := public.ledger_post('reversal', o.source_id, p_reason, lines, o.device_id, null, o.id);
  for mv in select * from public.stock_moves where entry_id = o.id loop
    perform 1 from public.items where id = mv.item_id for update;
    if (select coalesce(sum(qty), 0) from public.stock_moves where item_id = mv.item_id and branch_id = mv.branch_id) - mv.qty < 0 then
      raise exception 'E_STOCK';
    end if;
    insert into public.stock_moves(shop_id, item_id, entry_id, qty, value, branch_id) values (mv.shop_id, mv.item_id, e, -mv.qty, -mv.value, mv.branch_id);
  end loop;
  for mv in select distinct item_id, branch_id from public.stock_moves where entry_id = o.id loop
    perform public.ledger_settle_item(mv.item_id, o.device_id, mv.branch_id);
  end loop;
  insert into public.audit_log(shop_id, actor_id, action, entity, entity_id, before, after)
  values (o.shop_id, auth.uid(), 'reverse_entry', 'journal_entries', o.id, to_jsonb(o), jsonb_build_object('reversal_id', e, 'reason', p_reason));
  return e;
end $function$;
