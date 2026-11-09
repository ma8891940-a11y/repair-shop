-- ============================================================
-- 0028: جرد المحل أول مرة والأرصدة الافتتاحية (البند 4)
-- كل رصيد افتتاحي قيد متوازن (source_type = 'opening') قصاده "رأس المال" (حقوق ملكية):
--   - المخزون: المخزون مدين بالكمية × التكلفة، ورأس المال دائن (وحركة مخزون بنفس القيمة).
--   - الخزنة: الخزنة مدين، ورأس المال دائن.
--   - دين على عميل: العملاء مدين (للعميل)، ورأس المال دائن. ولو المحل هو اللي عليه للعميل (عربون مثلًا): العكس.
--   - دين لمورد: رأس المال مدين، والموردين دائن (للمورد). ولو المورد هو اللي عليه: العكس.
-- فالدفتر بيقفل متوازن دايمًا، وصافي "رأس المال الافتتاحي" = الأصول - الالتزامات.
-- أي رصيد غلط بيتصحح بقيد عكسي زي أي عملية. ونفس الرقم (p_id) لو اتبعت مرتين ما بيتسجلش مرتين.
-- ============================================================

alter table public.journal_entries drop constraint if exists journal_entries_source_type_check;
alter table public.journal_entries add constraint journal_entries_source_type_check check (source_type = any (array[
  'payment', 'delivery', 'purchase', 'supplier_payment', 'part_use', 'sale', 'expense', 'salary', 'salary_payment', 'advance',
  'advance_settle', 'capital', 'drawing', 'transfer', 'drawer_close', 'reversal', 'cost_adjust',
  'write_off', 'supplier_return', 'sale_return', 'opening']));

create or replace function public.opening_balance(p_id uuid, p_kind text, p_ref uuid, p_amount bigint default null, p_lines jsonb default null)
returns uuid
language plpgsql security definer set search_path = public as $$
declare
  s uuid := public.current_shop_id();
  e uuid;
  cap uuid := public.ledger_acc('capital');
  l jsonb; q bigint; u bigint; total bigint := 0;
  lines jsonb;
  memo text;
begin
  perform public.ledger_require(array['owner']::public.app_role[]);
  e := public.ledger_idem(p_id);
  if e is not null then return e; end if;
  if p_kind = 'stock' then
    if jsonb_typeof(p_lines) <> 'array' or jsonb_array_length(p_lines) = 0 then raise exception 'E_BAD_INPUT'; end if;
    for l in select * from jsonb_array_elements(p_lines) loop
      q := (l ->> 'qty')::bigint;
      u := (l ->> 'unit_cost')::bigint;
      if q is null or q <= 0 or q > 100000 or u is null or u < 0 then raise exception 'E_BAD_AMOUNT'; end if;
      if not exists (select 1 from public.items where id = (l ->> 'item')::uuid and shop_id = s and deleted_at is null) then raise exception 'E_NOT_FOUND'; end if;
      total := total + q * u;
    end loop;
    perform public.ledger_amount(total);
    e := public.ledger_post('opening', null, 'stock', jsonb_build_array(public.ledger_line(public.ledger_acc('inventory'), total, 0), public.ledger_line(cap, 0, total)), null, p_id);
    for l in select * from jsonb_array_elements(p_lines) loop
      insert into public.stock_moves(shop_id, item_id, entry_id, qty, value)
      values (s, (l ->> 'item')::uuid, e, (l ->> 'qty')::int, (l ->> 'qty')::bigint * (l ->> 'unit_cost')::bigint);
    end loop;
    return e;
  end if;
  if p_amount is null or p_amount = 0 then raise exception 'E_BAD_AMOUNT'; end if;
  perform public.ledger_amount(abs(p_amount));
  if p_kind = 'cash' then
    if p_amount < 0 then raise exception 'E_BAD_AMOUNT'; end if;
    lines := jsonb_build_array(public.ledger_line((public.ledger_cashbox(p_ref)).id, p_amount, 0), public.ledger_line(cap, 0, p_amount));
  elsif p_kind = 'customer' then
    if not exists (select 1 from public.customers where id = p_ref and shop_id = s and deleted_at is null) then raise exception 'E_NOT_FOUND'; end if;
    -- موجب = العميل عليه للمحل. سالب = المحل عليه للعميل
    lines := jsonb_build_array(
      public.ledger_line(public.ledger_acc('ar'), greatest(p_amount, 0), greatest(-p_amount, 0), 'customer', p_ref),
      public.ledger_line(cap, greatest(-p_amount, 0), greatest(p_amount, 0)));
  elsif p_kind = 'supplier' then
    if not exists (select 1 from public.suppliers where id = p_ref and shop_id = s and deleted_at is null) then raise exception 'E_NOT_FOUND'; end if;
    -- موجب = المحل عليه للمورد. سالب = المورد عليه للمحل
    lines := jsonb_build_array(
      public.ledger_line(public.ledger_acc('ap'), greatest(-p_amount, 0), greatest(p_amount, 0), 'supplier', p_ref),
      public.ledger_line(cap, greatest(p_amount, 0), greatest(-p_amount, 0)));
  else
    raise exception 'E_BAD_INPUT';
  end if;
  memo := p_kind;
  return public.ledger_post('opening', p_ref, memo, lines, null, p_id);
end $$;
revoke execute on function public.opening_balance(uuid, text, uuid, bigint, jsonb) from public, anon;
grant execute on function public.opening_balance(uuid, text, uuid, bigint, jsonb) to authenticated;

-- ملخص الأرصدة الافتتاحية (الساري بس، من غير الملغي): كل نوع لوحده، وصافي رأس المال، والدفتر متوازن ولا لأ
create or replace function public.opening_summary() returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare s uuid := public.current_shop_id(); res jsonb;
begin
  perform public.ledger_require(array['owner']::public.app_role[]);
  with en as (
    select e.id, e.memo from public.journal_entries e
    where e.shop_id = s and e.source_type = 'opening' and not exists (select 1 from public.journal_entries r where r.reverses_id = e.id)
  ), ln as (
    select en.memo, a.code, a.kind, l.debit, l.credit from en join public.journal_lines l on l.entry_id = en.id join public.accounts a on a.id = l.account_id
  )
  select jsonb_build_object(
    'stock', coalesce((select sum(debit - credit) from ln where kind = 'inventory'), 0),
    'stock_items', (select count(distinct m.item_id) from public.stock_moves m join en on en.id = m.entry_id),
    'cash', coalesce((select sum(debit - credit) from ln where kind = 'cash'), 0),
    'receivables', coalesce((select sum(debit - credit) from ln where kind = 'receivable'), 0),
    'payables', coalesce((select sum(credit - debit) from ln where kind = 'payable'), 0),
    'capital', coalesce((select sum(credit - debit) from ln where code = 'capital'), 0),
    'entries', (select count(*) from en),
    'balanced', coalesce((select sum(debit) = sum(credit) from ln), true),
    'done', coalesce((select (extras ->> 'opening_done')::boolean from public.shops where id = s), false)
  ) into res;
  return res;
end $$;
revoke execute on function public.opening_summary() from public, anon;
grant execute on function public.opening_summary() to authenticated;
