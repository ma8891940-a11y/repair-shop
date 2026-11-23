-- ============================================================
-- 0063: R7 الشيكات (تحت التحصيل وبميعاد)
-- - شيك من عميل: بيقلل اللي على العميل، وبيدخل حساب "شيكات تحت التحصيل" (أصل) لحد ما يتصرف في خزنة (بنك).
-- - شيك لمورد: بيقلل اللي للمورد، وبيدخل "شيكات مستحقة الدفع" (التزام) لحد ما يتصرف من خزنة.
-- - الشيك اللي اترفض (أو اتلغى قبل الصرف): الدين بيرجع للعميل أو المورد زي ما كان.
-- - كل خطوة قيد متوازن، والقيود ما بتتعدلش. الإلغاء بقيد عكسي ممنوع لقيود الشيكات: الرفض هو الطريقة الوحيدة.
-- - صاحب المحل أو اللي معاه "المالية ← يضيف"، وفي فروعه بس.
-- ============================================================

alter table public.accounts drop constraint if exists accounts_kind_check;
alter table public.accounts add constraint accounts_kind_check check (kind = any (array[
  'cash', 'receivable', 'advances', 'inventory', 'payable', 'salaries', 'capital', 'drawings', 'revenue', 'cogs', 'expense', 'shortage', 'overage',
  'partner_capital', 'partner_current', 'retained', 'fixed_asset', 'tax', 'cheque_in', 'cheque_out']));

alter table public.journal_entries drop constraint if exists journal_entries_source_type_check;
alter table public.journal_entries add constraint journal_entries_source_type_check check (source_type = any (array[
  'payment', 'delivery', 'purchase', 'supplier_payment', 'part_use', 'sale', 'expense', 'salary', 'salary_payment', 'advance', 'advance_settle',
  'capital', 'drawing', 'transfer', 'drawer_close', 'reversal', 'cost_adjust', 'write_off', 'supplier_return', 'sale_return', 'opening',
  'partner_capital', 'partner_withdrawal', 'profit_distribution', 'netting', 'stock_transfer', 'commission', 'bonus', 'penalty', 'vat_payment',
  'cheque_in', 'cheque_out', 'cheque_clear', 'cheque_bounce']));

-- حسابات الشيكات لكل المحلات الموجودة (warsha.system: الترقية من SQL Editor من غير مستخدم)
do $chq$
begin
  perform set_config('warsha.system', 'on', true);
  insert into public.accounts(shop_id, code, type, kind)
  select sh.id, v.code, v.type::public.account_type, v.kind from public.shops sh
  cross join (values ('cheques_in', 'asset', 'cheque_in'), ('cheques_out', 'liability', 'cheque_out')) as v(code, type, kind)
  on conflict (shop_id, code) where code is not null do nothing;
  perform set_config('warsha.system', 'off', true);
end $chq$;

-- ---------- الجدول ----------
create table public.cheques (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references public.shops(id),
  branch_id uuid references public.branches(id),
  direction text not null check (direction in ('in', 'out')),
  party_type text not null check (party_type in ('customer', 'supplier')),
  party_id uuid not null,
  cheque_no text not null check (length(trim(cheque_no)) between 1 and 40),
  bank text check (bank is null or length(bank) <= 80),
  due_date date not null,
  amount bigint not null check (amount > 0 and amount <= 100000000000),
  status text not null default 'pending' check (status in ('pending', 'cleared', 'bounced')),
  entry_id uuid not null references public.journal_entries(id),
  settle_entry_id uuid references public.journal_entries(id),
  settled_at timestamptz,
  note text check (note is null or length(note) <= 300),
  created_by uuid references public.profiles(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  check ((direction = 'in') = (party_type = 'customer')),
  check ((status = 'pending') = (settle_entry_id is null))
);
create index cheques_due on public.cheques(shop_id, status, due_date) where deleted_at is null;
alter table public.cheques enable row level security;
create policy cheques_select on public.cheques for select to authenticated
  using (shop_id = (select public.current_shop_id()) and ((select public.current_app_role()) = 'owner' or (public.has_perm('finance', 'view') and public.can_branch(branch_id))));
-- الكتابة من الدوال بس
revoke all on public.cheques from public, anon, authenticated;
grant select on public.cheques to authenticated;
create trigger set_updated_at before update on public.cheques for each row execute function public.tg_set_updated_at();
create trigger block_delete before delete on public.cheques for each row execute function public.tg_block_delete();
create trigger zz_audit after insert or update on public.cheques for each row execute function public.tg_audit();

-- ---------- الصلاحية ----------
create or replace function public.cheque_require() returns void
language plpgsql stable security definer set search_path = public as $$
begin
  if public.current_app_role() = 'owner' then return; end if;
  perform public.grant_require('finance', 'add');
end $$;
revoke execute on function public.cheque_require() from public, anon, authenticated;

-- ---------- استلام شيك من عميل ----------
create or replace function public.cheque_receive(p_id uuid, p_customer uuid, p_no text, p_bank text, p_due date, p_amount bigint, p_note text default null)
returns uuid
language plpgsql security definer set search_path = public as $$
declare s uuid := public.current_shop_id(); e uuid;
begin
  perform public.cheque_require();
  if exists (select 1 from public.cheques where id = p_id) then return p_id; end if;
  perform public.ledger_amount(p_amount);
  if coalesce(trim(p_no), '') = '' or p_due is null then raise exception 'E_BAD_INPUT'; end if;
  if not exists (select 1 from public.customers where id = p_customer and shop_id = s and deleted_at is null) then raise exception 'E_NOT_FOUND'; end if;
  e := public.ledger_post('cheque_in', p_id, nullif(trim(p_note), ''), jsonb_build_array(
    public.ledger_line(public.ledger_acc('cheques_in'), p_amount, 0, 'customer', p_customer),
    public.ledger_line(public.ledger_acc('ar'), 0, p_amount, 'customer', p_customer)), null, p_id);
  insert into public.cheques(id, shop_id, branch_id, direction, party_type, party_id, cheque_no, bank, due_date, amount, entry_id, note, created_by)
  values (p_id, s, public.op_branch(), 'in', 'customer', p_customer, trim(p_no), nullif(trim(p_bank), ''), p_due, p_amount, e, nullif(trim(p_note), ''), auth.uid());
  return p_id;
end $$;

-- ---------- شيك لمورد ----------
create or replace function public.cheque_issue(p_id uuid, p_supplier uuid, p_no text, p_bank text, p_due date, p_amount bigint, p_note text default null)
returns uuid
language plpgsql security definer set search_path = public as $$
declare s uuid := public.current_shop_id(); e uuid;
begin
  perform public.cheque_require();
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

-- الشيك نفسه (مقفول للتعديل)، في المحل وفروع المستخدم
create or replace function public.cheque_lock(p_cheque uuid) returns public.cheques
language plpgsql security definer set search_path = public as $$
declare c public.cheques;
begin
  select * into c from public.cheques where id = p_cheque and shop_id = public.current_shop_id() and deleted_at is null for update;
  if not found then raise exception 'E_NOT_FOUND'; end if;
  if public.current_app_role() <> 'owner' and not public.can_branch(c.branch_id) then raise exception 'E_FORBIDDEN'; end if;
  -- الصرف والرفض بيتسجلوا في فرع الشيك نفسه (مش الفرع المفتوح على الشاشة)، وخزنة فرع تاني بتترفض (E_BRANCH_CASHBOX)
  perform public.pin_branch(c.branch_id);
  return c;
end $$;
revoke execute on function public.cheque_lock(uuid) from public, anon, authenticated;

-- ---------- الصرف: الفلوس دخلت أو خرجت من الخزنة (البنك غالبًا) ----------
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
  if c.direction = 'in' then
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

-- ---------- الرفض (أو الإلغاء قبل الصرف): الدين بيرجع زي ما كان ----------
create or replace function public.cheque_bounce(p_op uuid, p_cheque uuid, p_reason text)
returns uuid
language plpgsql security definer set search_path = public as $$
declare c public.cheques; e uuid;
begin
  perform public.cheque_require();
  e := public.ledger_idem(p_op);
  if e is not null then return e; end if;
  if coalesce(trim(p_reason), '') = '' then raise exception 'E_REASON_REQUIRED'; end if;
  c := public.cheque_lock(p_cheque);
  if c.status <> 'pending' then raise exception 'E_CHEQUE_DONE'; end if;
  if c.direction = 'in' then
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

-- قيود الشيكات ما بتتلغيش بقيد عكسي (حالة الشيك كانت هتفضل غلط): الرفض بس
create or replace function public.tg_no_cheque_reversal() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if new.reverses_id is not null and exists (
    select 1 from public.journal_entries o where o.id = new.reverses_id and o.source_type in ('cheque_in', 'cheque_out', 'cheque_clear', 'cheque_bounce')) then
    raise exception 'E_CHEQUE_REVERSAL';
  end if;
  return new;
end $$;
create trigger a_no_cheque_reversal before insert on public.journal_entries for each row execute function public.tg_no_cheque_reversal();

-- ---------- القايمة (بأسماء العملاء والموردين) ----------
create or replace function public.cheques_list(p_status text default null, p_branch uuid default null) returns table (
  id uuid, direction text, party_type text, party_id uuid, party_name text, cheque_no text, bank text, due_date date,
  amount bigint, status text, branch_id uuid, settled_at timestamptz, note text, created_at timestamptz)
language plpgsql stable security definer set search_path = public as $$
declare s uuid := public.current_shop_id();
begin
  perform public.grant_require('finance', 'view');
  if not public.all_my_branches() and (p_branch is null or not public.can_branch(p_branch)) then p_branch := public.op_branch(); end if;
  return query
  select c.id, c.direction, c.party_type, c.party_id, coalesce(cu.name, sp.name), c.cheque_no, c.bank, c.due_date,
         c.amount, c.status, c.branch_id, c.settled_at, c.note, c.created_at
  from public.cheques c
  left join public.customers cu on c.party_type = 'customer' and cu.id = c.party_id
  left join public.suppliers sp on c.party_type = 'supplier' and sp.id = c.party_id
  where c.shop_id = s and c.deleted_at is null
    and (p_status is null or c.status = p_status)
    and (p_branch is null or c.branch_id = p_branch)
  order by (c.status = 'pending') desc, c.due_date, c.created_at;
end $$;

revoke execute on function public.cheque_receive(uuid, uuid, text, text, date, bigint, text) from public, anon;
revoke execute on function public.cheque_issue(uuid, uuid, text, text, date, bigint, text) from public, anon;
revoke execute on function public.cheque_clear(uuid, uuid, uuid) from public, anon;
revoke execute on function public.cheque_bounce(uuid, uuid, text) from public, anon;
revoke execute on function public.cheques_list(text, uuid) from public, anon;
grant execute on function public.cheque_receive(uuid, uuid, text, text, date, bigint, text) to authenticated;
grant execute on function public.cheque_issue(uuid, uuid, text, text, date, bigint, text) to authenticated;
grant execute on function public.cheque_clear(uuid, uuid, uuid) to authenticated;
grant execute on function public.cheque_bounce(uuid, uuid, text) to authenticated;
grant execute on function public.cheques_list(text, uuid) to authenticated;
revoke execute on function public.tg_no_cheque_reversal() from public, anon, authenticated;


-- ---------- الدوال اللي اتعدلت ----------
-- ensure_ledger_accounts: (src: 0062_vat.sql) + الشيكات
create or replace function public.ensure_ledger_accounts(p_shop uuid) returns void
language plpgsql security definer set search_path = public as $$
declare m text;
begin
  insert into public.accounts(shop_id, code, type, kind)
  select p_shop, v.code, v.type::public.account_type, v.kind from (values
    ('ar', 'asset', 'receivable'), ('advances', 'asset', 'advances'), ('inventory', 'asset', 'inventory'),
    ('ap', 'liability', 'payable'), ('salaries_payable', 'liability', 'salaries'), ('vat_payable', 'liability', 'tax'),
    ('cheques_in', 'asset', 'cheque_in'), ('cheques_out', 'liability', 'cheque_out'),
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

-- financial_position: (src: 0062_vat.sql) + الشيكات
create or replace function public.financial_position(p_from timestamptz, p_to timestamptz, p_branch uuid default null) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare
  s uuid := public.current_shop_id();
  res jsonb;
begin
  perform public.grant_require('finance', 'view');
  -- الموظف: فروعه بس (لو مش معاه كل الفروع)
  if not public.all_my_branches() and (p_branch is null or not public.can_branch(p_branch)) then p_branch := public.op_branch(); end if;
  with bal as (
    select a.id, a.code, a.name, a.type, a.kind, a.method, l.party_type, l.party_id,
           coalesce(sum((l.debit - l.credit) * public.account_sign(a.type)), 0)::bigint as b
    from public.accounts a
    -- B: فرع واحد: الخزن بتاعته (كل حركاتها)، وباقي الحسابات من قيود الفرع ده
    left join public.journal_lines l on l.account_id = a.id
      and (p_branch is null or a.kind = 'cash' or exists (select 1 from public.journal_entries be where be.id = l.entry_id and be.branch_id = p_branch))
    where a.shop_id = s and (p_branch is null or a.kind <> 'cash' or a.branch_id = p_branch)
    group by a.id, l.party_type, l.party_id
  ),
  -- المعادلة والتوازن دايمًا للمحل كله (الدفتر واحد)
  bal_all as (
    select a.type, coalesce(sum((l.debit - l.credit) * public.account_sign(a.type)), 0)::bigint as b
    from public.accounts a left join public.journal_lines l on l.account_id = a.id
    where a.shop_id = s group by a.id, a.type
  ),
  eq_all as (
    select coalesce(sum(b) filter (where type = 'asset'), 0)::bigint as assets,
           coalesce(sum(b) filter (where type = 'liability'), 0)::bigint as liabilities,
           coalesce(sum(b) filter (where type = 'equity'), 0)::bigint as equity,
           (coalesce(sum(b) filter (where type = 'revenue'), 0) - coalesce(sum(b) filter (where type = 'expense'), 0))::bigint as earnings
    from bal_all
  ),
  acc as (select id, code, name, type, kind, method, sum(b)::bigint as b from bal group by id, code, name, type, kind, method),
  per as (
    select coalesce(sum(case when a.type = 'revenue' then l.credit - l.debit else 0 end), 0)::bigint as revenue,
           coalesce(sum(case when a.type = 'expense' then l.debit - l.credit else 0 end), 0)::bigint as expenses
    from public.journal_lines l join public.accounts a on a.id = l.account_id join public.journal_entries e on e.id = l.entry_id
    where l.shop_id = s and e.occurred_at >= p_from and e.occurred_at < p_to and (p_branch is null or e.branch_id = p_branch)
  ),
  tot as (
    select coalesce(sum(debit), 0)::bigint as d, coalesce(sum(credit), 0)::bigint as c from public.journal_lines where shop_id = s
  ),
  unb as (
    select count(*)::int as n from (
      select e.id from public.journal_entries e left join public.journal_lines l on l.entry_id = e.id
      where e.shop_id = s group by e.id having coalesce(sum(l.debit), 0) <> coalesce(sum(l.credit), 0) or count(l.id) < 2) x
  ),
  eq as (
    select coalesce(sum(b) filter (where type = 'asset'), 0)::bigint as assets,
           coalesce(sum(b) filter (where type = 'liability'), 0)::bigint as liabilities,
           coalesce(sum(b) filter (where type = 'equity'), 0)::bigint as equity,
           (coalesce(sum(b) filter (where type = 'revenue'), 0) - coalesce(sum(b) filter (where type = 'expense'), 0))::bigint as earnings
    from acc
  ),
  parts as (
    select
      coalesce(sum(b) filter (where kind = 'cash'), 0)::bigint as cash,
      coalesce(sum(greatest(b, 0)) filter (where kind in ('receivable', 'advances', 'cheque_in')), 0)::bigint as receivables,
      (coalesce(sum(greatest(b, 0)) filter (where kind in ('payable', 'salaries', 'tax', 'cheque_out')), 0)
        + coalesce(sum(greatest(-b, 0)) filter (where kind in ('receivable', 'advances', 'cheque_in')), 0)
        + coalesce(sum(greatest(-b, 0)) filter (where kind = 'inventory'), 0))::bigint as payables,
      coalesce(sum(greatest(-b, 0)) filter (where kind in ('payable', 'salaries', 'tax', 'cheque_out')), 0)::bigint as payables_debit,
      coalesce(sum(greatest(b, 0)) filter (where kind = 'inventory'), 0)::bigint as inventory,
      coalesce(sum(b) filter (where kind = 'fixed_asset'), 0)::bigint as fixed_assets,
      -- أرباح اتوزعت على الشركاء ولسه ما اتسحبتش (حقوق ملكية، مش دين من بره)
      coalesce(sum(greatest(b, 0)) filter (where kind = 'partner_current'), 0)::bigint as partners_due
    from bal
  ),
  days as (
    select (date_trunc('day', e.occurred_at at time zone 'Africa/Cairo'))::date as day,
           coalesce(sum(case when a.type = 'revenue' then l.credit - l.debit else 0 end), 0)::bigint as revenue,
           coalesce(sum(case when a.type = 'expense' then l.debit - l.credit else 0 end), 0)::bigint as expenses
    from public.journal_lines l join public.accounts a on a.id = l.account_id join public.journal_entries e on e.id = l.entry_id
    where l.shop_id = s and e.occurred_at >= p_from and e.occurred_at < p_to and a.type in ('revenue', 'expense') and (p_branch is null or e.branch_id = p_branch)
    group by 1
  )
  select jsonb_build_object(
    'cash', p.cash,
    'receivables', p.receivables + p.payables_debit,
    'payables', p.payables,
    -- مخزون فرع: قيمة حركاته (التحويل بين الفروع بيتقابل في حساب المخزون نفسه)
    'inventory', case when p_branch is null then p.inventory else (select coalesce(sum(m.value), 0)::bigint from public.stock_moves m where m.shop_id = s and m.branch_id = p_branch) end,
    'revenue', per.revenue,
    'expenses', per.expenses,
    'profit', per.revenue - per.expenses,
    'fixed_assets', p.fixed_assets,
    'cheques_in', coalesce((select sum(b) from acc where kind = 'cheque_in'), 0),
    'cheques_out', coalesce((select sum(b) from acc where kind = 'cheque_out'), 0),
    -- الضريبة على المحل كله (مش الفرع المختار)
    'vat_due', (select coalesce(sum(l.credit - l.debit), 0)::bigint from public.journal_lines l join public.accounts a on a.id = l.account_id where l.shop_id = s and a.kind = 'tax'),
    'partners_due', p.partners_due,
    -- قيمة المحل = الأصول − الالتزامات اللي لناس من بره بس (رأس مال الشركاء وأرباحهم حقوق ملكية، فما بتقللهاش)
    'net_worth', p.cash + p.receivables + p.payables_debit + p.fixed_assets - p.payables
      + case when p_branch is null then p.inventory else (select coalesce(sum(m.value), 0)::bigint from public.stock_moves m where m.shop_id = s and m.branch_id = p_branch) end,
    'branch', p_branch,
    -- حقوق الملكية بالتفصيل (من أول يوم): رأس مال صاحب المحل، والسحوبات، ورأس مال وجاري كل شريك، والأرباح المحتجزة
    'equity_parts', jsonb_build_object(
      'owner_capital', coalesce((select b from acc where code = 'capital'), 0),
      'drawings', -coalesce((select b from acc where code = 'drawings'), 0),
      'retained', eq.earnings + coalesce((select b from acc where code = 'retained'), 0),
      'partners', coalesce((select jsonb_agg(jsonb_build_object('id', pt.id, 'name', pt.name, 'share_bp', pt.share_bp,
          'capital', coalesce((select sum(b.b) from bal b where b.kind = 'partner_capital' and b.party_id = pt.id), 0),
          'current', coalesce((select sum(b.b) from bal b where b.kind = 'partner_current' and b.party_id = pt.id), 0)) order by pt.share_bp desc, pt.name)
        from public.partners pt where pt.shop_id = s and (pt.deleted_at is null or exists (select 1 from bal b where b.party_id = pt.id and b.b <> 0))), '[]'::jsonb)),
    'equation', jsonb_build_object('assets', eq_all.assets, 'liabilities', eq_all.liabilities, 'equity', eq_all.equity, 'earnings', eq_all.earnings),
    'debits', tot.d, 'credits', tot.c, 'unbalanced_entries', unb.n,
    'balanced', tot.d = tot.c and unb.n = 0 and eq_all.assets = eq_all.liabilities + eq_all.equity + eq_all.earnings,
    'cashboxes', coalesce((select jsonb_agg(jsonb_build_object('id', a.id, 'code', a.code, 'name', a.name, 'method', a.method, 'balance', a.b,
         'branch_id', (select x.branch_id from public.accounts x where x.id = a.id)) order by a.code nulls last, a.name)
       from acc a where a.kind = 'cash'), '[]'::jsonb),
    'top_customers', coalesce((select jsonb_agg(x order by (x ->> 'balance')::bigint desc) from (
       select jsonb_build_object('id', b.party_id, 'name', c.name, 'balance', sum(b.b)) as x
       from bal b join public.customers c on c.id = b.party_id where b.kind = 'receivable' and b.party_type = 'customer'
       group by b.party_id, c.name having sum(b.b) > 0 order by sum(b.b) desc limit 5) t), '[]'::jsonb),
    'top_suppliers', coalesce((select jsonb_agg(x order by (x ->> 'balance')::bigint desc) from (
       select jsonb_build_object('id', b.party_id, 'name', sp.name, 'balance', sum(b.b)) as x
       from bal b join public.suppliers sp on sp.id = b.party_id where b.kind = 'payable' and b.party_type = 'supplier'
       group by b.party_id, sp.name having sum(b.b) > 0 order by sum(b.b) desc limit 5) t), '[]'::jsonb),
    'daily', coalesce((select jsonb_agg(jsonb_build_object('day', day, 'revenue', revenue, 'expenses', expenses, 'profit', revenue - expenses) order by day) from days), '[]'::jsonb),
    'by_method', coalesce((select jsonb_object_agg(method, total) from (
       select p2.method, sum(p2.amount)::bigint as total from public.payments p2
       where p2.shop_id = s and p2.created_at >= p_from and p2.created_at < p_to
         and (p_branch is null or exists (select 1 from public.journal_entries pe where pe.id = p2.entry_id and pe.branch_id = p_branch))
         and not exists (select 1 from public.journal_entries r where r.reverses_id = p2.entry_id)
       group by p2.method) m), '{}'::jsonb),
    'delivered', (select count(*) from public.devices d where d.shop_id = s and d.delivered_at >= p_from and d.delivered_at < p_to and (p_branch is null or d.branch_id = p_branch)),
    'closings', coalesce((select jsonb_agg(jsonb_build_object('cashbox', dc.cashbox_id, 'expected', dc.expected, 'counted', dc.counted, 'diff', dc.diff, 'at', dc.created_at,
       'by', (select full_name from public.profiles where id = dc.closed_by)) order by dc.created_at)
       from public.drawer_closings dc where dc.shop_id = s and dc.created_at >= p_from and dc.created_at < p_to
         and (p_branch is null or exists (select 1 from public.accounts ca where ca.id = dc.cashbox_id and ca.branch_id = p_branch))), '[]'::jsonb)
  ) into res
  from parts p, per, tot, unb, eq, eq_all;
  return res;
end $$;

-- backup_snapshot: (src: 0061_attendance.sql) + cheques
create or replace function public.backup_snapshot(p_shop uuid) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare
  res jsonb := jsonb_build_object('format', 'warsha-backup', 'version', 1, 'generated_at', now(), 'shop_id', p_shop);
  t text;
  rows jsonb;
begin
  foreach t in array array['shops', 'branches', 'staff_branches', 'attendance', 'shop_branding', 'profiles', 'customers', 'devices', 'device_costs', 'status_log', 'device_notes', 'device_photos', 'device_checks',
                           'quote_decisions', 'message_templates', 'message_log', 'accounts', 'journal_entries', 'journal_lines', 'sale_lines', 'cheques', 'payments', 'drawer_closings',
                           'suppliers', 'categories', 'items', 'stock_moves', 'uncosted_sales', 'payment_plans', 'plan_installments', 'branch_goals', 'printers', 'print_templates', 'check_templates', 'used_devices', 'commission_rules', 'purchases', 'labor_rates', 'specialties', 'staff_specialties', 'routes', 'repair_steps',
                           'repair_videos', 'device_ratings', 'issue_presets', 'partners', 'profit_distributions', 'party_links', 'shop_lists', 'audit_log'] loop
    execute format('select coalesce(jsonb_agg(to_jsonb(x)), ''[]''::jsonb) from public.%I x where x.shop_id = $1', t) into rows using p_shop;
    res := res || jsonb_build_object(t, rows);
  end loop;
  select coalesce(jsonb_agg(jsonb_build_object('device_id', device_id, 'kind', kind, 'erased_at', erased_at)), '[]'::jsonb)
    into rows from public.device_passcodes where shop_id = p_shop;
  return res || jsonb_build_object('device_passcodes', rows);
end $$;

-- restore_backup: (src: 0061_attendance.sql) + cheques (بعد القيود)
create or replace function public.restore_backup(p_data jsonb) returns jsonb
-- extensions: فيها gen_random_bytes على Supabase
language plpgsql security definer set search_path = public, extensions, pg_temp as $$
declare
  s uuid := public.current_shop_id();
  me uuid := auth.uid();
  old_shop uuid;
  old_owner uuid;
  sh jsonb;
  t text;
  r jsonb;
  rows jsonb;
  n int;
  bad int;
  counts jsonb := '{}'::jsonb;
  -- بالترتيب ده عشان كل صف يلاقي اللي بيشاور عليه
  tabs text[] := array['branches', 'profiles', 'staff_branches', 'attendance', 'shop_branding', 'accounts', 'customers', 'suppliers', 'party_links', 'partners', 'specialties', 'staff_specialties', 'routes', 'labor_rates',
                       'issue_presets', 'commission_rules', 'shop_lists', 'message_templates', 'categories', 'items', 'devices', 'device_costs', 'status_log', 'device_notes', 'device_checks',
                       'quote_decisions', 'repair_steps', 'repair_videos', 'device_ratings', 'journal_entries', 'journal_lines', 'sale_lines', 'cheques', 'profit_distributions', 'payments',
                       'purchases', 'stock_moves', 'uncosted_sales', 'used_devices', 'payment_plans', 'plan_installments', 'branch_goals', 'printers', 'print_templates', 'check_templates', 'drawer_closings', 'message_log', 'audit_log'];
  -- الجداول دي ليها نسخة اتعملت مع التسجيل: بتتطابق بالكود (أو المفتاح) وبتاخد قيم النسخة
  keyed text[] := array['branches', 'accounts', 'routes', 'specialties', 'message_templates', 'labor_rates', 'shop_branding'];
begin
  perform public.ledger_require(array['owner']::public.app_role[]);
  if s is null or me is null then raise exception 'E_FORBIDDEN'; end if;
  if p_data is null or p_data->>'format' is distinct from 'warsha-backup' or coalesce((p_data->>'version')::int, 0) <> 1 then
    raise exception 'E_BACKUP_FORMAT';
  end if;
  old_shop := (p_data->>'shop_id')::uuid;
  if old_shop is null or old_shop = s then raise exception 'E_BACKUP_FORMAT'; end if;

  -- محل جديد فاضي بس
  if exists (select 1 from public.devices where shop_id = s) or exists (select 1 from public.customers where shop_id = s)
     or exists (select 1 from public.journal_entries where shop_id = s) or exists (select 1 from public.items where shop_id = s)
     or exists (select 1 from public.suppliers where shop_id = s) or exists (select 1 from public.payments where shop_id = s)
     or exists (select 1 from public.purchases where shop_id = s) or exists (select 1 from public.drawer_closings where shop_id = s)
     or exists (select 1 from public.stock_moves where shop_id = s)
     or exists (select 1 from public.profiles where shop_id = s and id <> me) then
    raise exception 'E_RESTORE_NOT_EMPTY';
  end if;

  perform set_config('warsha.restore', 'on', true);
  drop table if exists pg_temp._rmap;
  create temp table _rmap(old uuid primary key, new uuid not null) on commit drop;
  insert into _rmap values (old_shop, s);

  -- 1) بيانات المحل نفسه (من غير الخطة والإيقاف واللوجو اللي في Storage)
  sh := p_data->'shops'->0;
  if sh is not null then
    update public.shops set
      name = coalesce(sh->>'name', name), phone = sh->>'phone', address = sh->>'address',
      receipt_terms = coalesce(sh->>'receipt_terms', receipt_terms), warranty_days = coalesce((sh->>'warranty_days')::int, warranty_days),
      country = coalesce(sh->>'country', country), currency = coalesce(sh->>'currency', currency),
      payment_methods = coalesce(array(select jsonb_array_elements_text(sh->'payment_methods')), payment_methods),
      theme = coalesce(sh->>'theme', theme), locale = coalesce(sh->>'locale', locale),
      default_margin_pct = coalesce((sh->>'default_margin_pct')::int, default_margin_pct),
      extras = coalesce(sh->'extras', extras), max_discount_pct = coalesce((sh->>'max_discount_pct')::int, max_discount_pct)
    where id = s;
  end if;

  -- 2) الـ ids الجديدة
  -- صاحب المحل في النسخة = اللي بيسترجع دلوقتي
  select (x->>'id')::uuid into old_owner from jsonb_array_elements(coalesce(p_data->'profiles', '[]')) x
   where x->>'role' = 'owner' order by x->>'created_at' limit 1;
  if old_owner is not null then insert into _rmap values (old_owner, me) on conflict do nothing; end if;
  insert into _rmap select (x->>'id')::uuid, coalesce((select a.id from public.accounts a where a.shop_id = s and a.code = x->>'code' and x->>'code' is not null), gen_random_uuid())
    from jsonb_array_elements(coalesce(p_data->'accounts', '[]')) x on conflict do nothing;
  -- الفرع الرئيسي في النسخة = الفرع الرئيسي للمحل الجديد
  insert into _rmap select (x->>'id')::uuid, public.main_branch(s)
    from jsonb_array_elements(coalesce(p_data->'branches', '[]')) x where (x->>'is_main')::boolean and x->>'deleted_at' is null on conflict do nothing;
  insert into _rmap select (x->>'id')::uuid, coalesce((select a.id from public.routes a where a.shop_id = s and a.code = x->>'code' and x->>'code' is not null), gen_random_uuid())
    from jsonb_array_elements(coalesce(p_data->'routes', '[]')) x on conflict do nothing;
  insert into _rmap select (x->>'id')::uuid, coalesce((select a.id from public.specialties a where a.shop_id = s and a.code = x->>'code' and x->>'code' is not null), gen_random_uuid())
    from jsonb_array_elements(coalesce(p_data->'specialties', '[]')) x on conflict do nothing;
  insert into _rmap select (x->>'id')::uuid, coalesce((select a.id from public.message_templates a where a.shop_id = s and a.key = x->>'key'), gen_random_uuid())
    from jsonb_array_elements(coalesce(p_data->'message_templates', '[]')) x on conflict do nothing;
  insert into _rmap select (x->>'id')::uuid, coalesce((select a.id from public.labor_rates a where a.shop_id = s and a.deleted_at is null and lower(trim(a.issue)) = lower(trim(x->>'issue')) and x->>'deleted_at' is null), gen_random_uuid())
    from jsonb_array_elements(coalesce(p_data->'labor_rates', '[]')) x on conflict do nothing;
  insert into _rmap select (x->>'id')::uuid, coalesce((select a.id from public.shop_branding a where a.shop_id = s), gen_random_uuid())
    from jsonb_array_elements(coalesce(p_data->'shop_branding', '[]')) x on conflict do nothing;
  foreach t in array tabs loop
    insert into _rmap select (x->>'id')::uuid, gen_random_uuid() from jsonb_array_elements(coalesce(p_data->t, '[]')) x where x ? 'id' on conflict do nothing;
  end loop;

  -- 3) الصفوف نفسها بالترتيب
  foreach t in array tabs loop
    rows := '[]'::jsonb;
    for r in select public.restore_remap(x) from jsonb_array_elements(coalesce(p_data->t, '[]')) x loop
      if t = 'profiles' then
        -- صاحب المحل موجود أصلًا. الباقيين موظفين سابقين (من غير حساب دخول)
        continue when (r->>'id')::uuid = me;
        r := r || jsonb_build_object('deleted_at', coalesce(r->>'deleted_at', now()::text));
      elsif t = 'devices' then
        -- كود التتبع (الـ QR) بيفضل زي ما هو، إلا لو مستخدم في المشروع ده (المحل الأصلي لسه هنا)
        if exists (select 1 from public.devices d where d.tracking_token = r->>'tracking_token') then
          r := r || jsonb_build_object('tracking_token', encode(gen_random_bytes(12), 'hex'));
        end if;
      elsif t = 'journal_entries' then
        if r->>'idem_key' is not null and exists (select 1 from public.journal_entries j where j.idem_key = (r->>'idem_key')::uuid) then
          r := r || jsonb_build_object('idem_key', gen_random_uuid());
        end if;
      elsif t = 'accounts' and r->>'kind' = 'cash' and r->>'branch_id' is null then
        -- نسخة من قبل الفروع: الخزن كلها في الفرع الرئيسي
        r := r || jsonb_build_object('branch_id', public.main_branch(s));
      elsif t = 'used_devices' then
        -- رقم بطاقة البائع (في Vault) وصورتها (في Storage) مش جوه النسخة
        r := r || jsonb_build_object('seller_nid_secret', null, 'seller_photo', null);
      elsif t = 'shop_branding' then
        -- اللوجو الملون والحراري جوه الصف نفسه. الملف الأصلي في Storage مش جوه النسخة
        r := r || jsonb_build_object('logo_path', null);
      end if;
      if t = any (keyed) and exists (select 1 from _rmap m where m.new = (r->>'id')::uuid and m.old <> m.new)
         and (t <> 'shop_branding' or exists (select 1 from public.shop_branding b where b.id = (r->>'id')::uuid)) then
        -- موجود من التسجيل: بياخد قيم النسخة
        execute format('select count(*) from public.%I where id = $1', t) into n using (r->>'id')::uuid;
        if n > 0 then
          execute format('update public.%1$I x set (%2$s) = (select %2$s from jsonb_populate_record(null::public.%1$I, $1)) where x.id = $2', t,
            (select string_agg(quote_ident(c.column_name), ', ' order by c.ordinal_position) from information_schema.columns c
              where c.table_schema = 'public' and c.table_name = t and c.column_name not in ('id', 'shop_id')))
            using r, (r->>'id')::uuid;
          continue;
        end if;
      end if;
      rows := rows || jsonb_build_array(r);
    end loop;
    if jsonb_array_length(rows) > 0 then
      -- overriding system value: أرقام القيود (entry_no) بترجع زي ما هي
      execute format('insert into public.%1$I overriding system value select * from jsonb_populate_recordset(null::public.%1$I, $1)', t) using rows;
    end if;
    counts := counts || jsonb_build_object(t, jsonb_array_length(coalesce(p_data->t, '[]')));
  end loop;

  -- 4) عدّاد أرقام الطلبات: من آخر رقم راجع في كل سنة
  -- (لكل فرع: الرقم ممكن يبقى قبله بادئة الفرع B2-2026-0001)
  insert into public.order_counters(shop_id, branch_id, year, last_value)
  select s, branch_id, (regexp_match(order_no, '(\d{4})-(\d+)$'))[1]::int, max((regexp_match(order_no, '(\d{4})-(\d+)$'))[2]::int)
    from public.devices where shop_id = s and order_no ~ '\d{4}-\d+$' group by 2, 3
  on conflict (shop_id, branch_id, year) do update set last_value = greatest(public.order_counters.last_value, excluded.last_value);

  -- 5) التأكد: كل قيد متوازن، ورصيد كل حساب = رصيده في النسخة بالظبط
  select count(*) into bad from (
    select entry_id from public.journal_lines where shop_id = s group by entry_id having sum(debit) <> sum(credit)) x;
  if bad > 0 then raise exception 'E_RESTORE_UNBALANCED'; end if;
  select count(*) into bad from (
    select m.new acc, sum((l->>'debit')::bigint - (l->>'credit')::bigint) b
      from jsonb_array_elements(coalesce(p_data->'journal_lines', '[]')) l join _rmap m on m.old = (l->>'account_id')::uuid group by m.new
  ) x full join (select account_id, sum(debit - credit) b from public.journal_lines where shop_id = s group by account_id) y on y.account_id = x.acc
  where coalesce(x.b, 0) <> coalesce(y.b, 0);
  if bad > 0 then raise exception 'E_RESTORE_MISMATCH'; end if;
  -- وعدد الصفوف في كل جدول (الحسابات والقوالب اللي اتعملت مع التسجيل ممكن تزيد عن النسخة، مش تقل)
  foreach t in array tabs loop
    execute format('select count(*) from public.%I where shop_id = $1', t) into n using s;
    if n < jsonb_array_length(coalesce(p_data->t, '[]')) - (case when t = 'profiles' and old_owner is not null then 1 else 0 end) then
      raise exception 'E_RESTORE_MISMATCH';
    end if;
  end loop;

  perform set_config('warsha.restore', 'off', true);
  insert into public.audit_log(shop_id, actor_id, action, entity, entity_id, after)
  values (s, me, 'backup_restore', 'shops', s, jsonb_build_object('from_shop', old_shop, 'generated_at', p_data->>'generated_at', 'counts', counts));
  return jsonb_build_object('restored', true, 'counts', counts);
end $$;
