-- المرحلة 3: الفلوس بدفتر قيود مزدوج (docs/phase-3-ledger.md)
--
-- القواعد:
-- - كل حركة فلوس = قيد (journal_entries) فيه سطرين أو أكتر (journal_lines)، ومجموع المدين = مجموع الدائن بالظبط.
-- - الأرصدة مش متخزنة في أي مكان: كلها بتتحسب من سطور القيود.
-- - القيد ما بيتعدلش ولا بيتحذف أبدًا (حتى من SQL). الغلط بيتصلح بقيد عكسي مربوط بالأصلي.
-- - كل العمليات بدوال جوه قاعدة البيانات (كل دالة transaction واحدة): يا كله يتسجل يا ولا حاجة.
-- - المبالغ بالقروش أعداد صحيحة (bigint في الجمع).
-- - المخزون: الكمية والقيمة بتتحسب من حركات المخزون، والتكلفة بالمتوسط المرجّح.

-- ============================================================
-- 1) الحسابات
-- ============================================================
create type public.account_type as enum ('asset', 'liability', 'equity', 'revenue', 'expense');

create table public.accounts (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references public.shops(id),
  code text,                       -- للحسابات الأساسية (ar, ap, inventory, ...). الحسابات المضافة code = null
  name text,                       -- اسم مكتوب لحساب مضاف. الأساسية بتتترجم في الواجهة من code
  type public.account_type not null,
  kind text not null check (kind in ('cash', 'receivable', 'advances', 'inventory', 'payable', 'salaries', 'capital', 'drawings', 'revenue', 'cogs', 'expense', 'shortage', 'overage')),
  method text,                     -- للخزن: طريقة الدفع (cash, wallet, instapay, ...)
  holder_id uuid references public.profiles(id), -- للخزن: الموظف المسؤول عن الدرج
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  check (code is not null or nullif(trim(name), '') is not null),
  check ((kind = 'cash') = (method is not null)),
  check (holder_id is null or kind = 'cash')
);
create unique index accounts_code on public.accounts(shop_id, code) where code is not null;
create index accounts_shop on public.accounts(shop_id, kind);

-- الطرف الطبيعي للحساب: الأصول والمصروفات مدينة، والباقي دائن
create or replace function public.account_sign(t public.account_type) returns integer
language sql immutable as $$ select case when t in ('asset', 'expense') then 1 else -1 end $$;

-- ============================================================
-- 2) القيود
-- ============================================================
create table public.journal_entries (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references public.shops(id),
  entry_no bigint generated always as identity,
  occurred_at timestamptz not null default now(),
  source_type text not null check (source_type in ('payment', 'delivery', 'purchase', 'supplier_payment', 'part_use', 'sale', 'expense', 'salary', 'salary_payment', 'advance', 'advance_settle', 'capital', 'drawing', 'transfer', 'drawer_close', 'reversal')),
  source_id uuid,
  device_id uuid references public.devices(id),
  memo text check (length(memo) <= 500),
  idem_key uuid unique,            -- رقم العملية من التطبيق: نفس العملية لو اتبعتت مرتين ما تتسجلش مرتين
  reverses_id uuid unique references public.journal_entries(id),
  created_by uuid references public.profiles(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);
create index journal_entries_shop_time on public.journal_entries(shop_id, occurred_at);
create index journal_entries_source on public.journal_entries(source_type, source_id);

create table public.journal_lines (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references public.shops(id),
  entry_id uuid not null references public.journal_entries(id),
  account_id uuid not null references public.accounts(id),
  party_type text check (party_type in ('customer', 'supplier', 'employee')),
  party_id uuid,
  debit bigint not null default 0 check (debit >= 0 and debit <= 100000000000),
  credit bigint not null default 0 check (credit >= 0 and credit <= 100000000000),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  check ((debit > 0) <> (credit > 0)),
  check ((party_type is null) = (party_id is null))
);
create index journal_lines_entry on public.journal_lines(entry_id);
create index journal_lines_account on public.journal_lines(account_id);
create index journal_lines_party on public.journal_lines(party_type, party_id);

-- ============================================================
-- 3) الموردين والأصناف والمخزون والدفعات والدرج
-- ============================================================
create table public.suppliers (
  id uuid primary key,
  shop_id uuid not null references public.shops(id),
  name text not null check (length(trim(name)) between 1 and 120),
  phone text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

create table public.items (
  id uuid primary key,
  shop_id uuid not null references public.shops(id),
  kind text not null check (kind in ('part', 'accessory')),
  name text not null check (length(trim(name)) between 1 and 160),
  sku text,
  sale_price integer check (sale_price is null or sale_price between 0 and 2000000000),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

create table public.stock_moves (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references public.shops(id),
  item_id uuid not null references public.items(id),
  entry_id uuid not null references public.journal_entries(id),
  qty integer not null check (qty <> 0),
  value bigint not null,           -- القيمة بالقروش (موجبة للداخل وسالبة للخارج)
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);
create index stock_moves_item on public.stock_moves(item_id);

create table public.payments (
  id uuid primary key,
  shop_id uuid not null references public.shops(id),
  customer_id uuid not null references public.customers(id),
  device_id uuid references public.devices(id),
  cashbox_id uuid not null references public.accounts(id),
  method text not null,
  amount bigint not null check (amount > 0),
  entry_id uuid not null unique references public.journal_entries(id),
  created_by uuid references public.profiles(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);
create index payments_device on public.payments(device_id);

create table public.drawer_closings (
  id uuid primary key,
  shop_id uuid not null references public.shops(id),
  cashbox_id uuid not null references public.accounts(id),
  expected bigint not null,
  counted bigint not null check (counted >= 0),
  diff bigint not null,
  entry_id uuid references public.journal_entries(id),
  note text,
  closed_by uuid references public.profiles(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

-- ============================================================
-- 4) الحماية: ما بيتعدلش، وما بيتحذفش، والقيد لازم يتوازن
-- ============================================================
create or replace function public.tg_ledger_immutable() returns trigger
language plpgsql as $$
begin
  raise exception 'E_LEDGER_IMMUTABLE';
end $$;

do $$
declare t text;
begin
  foreach t in array array['journal_entries', 'journal_lines', 'stock_moves', 'payments', 'drawer_closings'] loop
    execute format('create trigger ledger_immutable before update or delete on public.%I for each row execute function public.tg_ledger_immutable()', t);
    execute format('create trigger ledger_no_truncate before truncate on public.%I for each statement execute function public.tg_ledger_immutable()', t);
  end loop;
  foreach t in array array['accounts', 'suppliers', 'items'] loop
    execute format('create trigger set_updated_at before update on public.%I for each row execute function public.tg_set_updated_at()', t);
    execute format('create trigger block_delete before delete on public.%I for each row execute function public.tg_block_delete()', t);
    execute format('create trigger a_force_shop_id before insert or update on public.%I for each row execute function public.tg_force_shop_id()', t);
  end loop;
  foreach t in array array['accounts', 'suppliers', 'items', 'journal_entries', 'payments', 'drawer_closings'] loop
    execute format('create trigger zz_audit after insert or update on public.%I for each row execute function public.tg_audit()', t);
  end loop;
end $$;

-- التوازن بيتراجع في آخر الـ transaction (deferred): أي قيد مش متوازن = الـ transaction كلها بتتلغي
-- security definer: الفحص بيحصل في آخر العملية بصلاحيات المستخدم، والمستخدم (زي الاستقبال) ما بيشوفش السطور
create or replace function public.tg_entry_balanced() returns trigger
language plpgsql security definer set search_path = public as $$
declare d bigint; c bigint; n int;
begin
  select coalesce(sum(debit), 0), coalesce(sum(credit), 0), count(*) into d, c, n from public.journal_lines where entry_id = new.entry_id;
  if n < 2 or d <> c then
    raise exception 'E_UNBALANCED';
  end if;
  return null;
end $$;
create constraint trigger entry_balanced after insert on public.journal_lines
  deferrable initially deferred for each row execute function public.tg_entry_balanced();

-- ============================================================
-- 5) الحسابات الأساسية لكل محل
-- ============================================================
create or replace function public.ensure_ledger_accounts(p_shop uuid) returns void
language plpgsql security definer set search_path = public as $$
declare m text;
begin
  insert into public.accounts(shop_id, code, type, kind)
  select p_shop, v.code, v.type::public.account_type, v.kind from (values
    ('ar', 'asset', 'receivable'), ('advances', 'asset', 'advances'), ('inventory', 'asset', 'inventory'),
    ('ap', 'liability', 'payable'), ('salaries_payable', 'liability', 'salaries'),
    ('capital', 'equity', 'capital'), ('drawings', 'equity', 'drawings'),
    ('rev_repair', 'revenue', 'revenue'), ('rev_parts', 'revenue', 'revenue'), ('rev_accessories', 'revenue', 'revenue'), ('overage', 'revenue', 'overage'),
    ('cogs', 'expense', 'cogs'), ('shortage', 'expense', 'shortage'),
    ('exp_salaries', 'expense', 'expense'), ('exp_rent', 'expense', 'expense'), ('exp_electricity', 'expense', 'expense'),
    ('exp_internet', 'expense', 'expense'), ('exp_purchases', 'expense', 'expense')
  ) as v(code, type, kind)
  on conflict (shop_id, code) where code is not null do nothing;
  -- خزنة لكل طريقة دفع مفعّلة في المحل
  for m in select unnest(payment_methods) from public.shops where id = p_shop loop
    insert into public.accounts(shop_id, code, type, kind, method)
    values (p_shop, 'cash_' || m, 'asset', 'cash', m)
    on conflict (shop_id, code) where code is not null do nothing;
  end loop;
end $$;
revoke execute on function public.ensure_ledger_accounts(uuid) from public, anon, authenticated;

-- إضافة الحسابات بتحصل من غير مستخدم (trigger على المحل)، فبنعدّي force_shop_id بإعداد مؤقت
create or replace function public.tg_force_shop_id() returns trigger
language plpgsql security definer set search_path = public as $$
declare s uuid := public.current_shop_id();
begin
  if current_setting('warsha.system', true) = 'on' then
    return new;
  end if;
  if s is null then
    if tg_op = 'UPDATE' and auth.uid() is null and new.shop_id = old.shop_id then
      return new;
    end if;
    raise exception 'E_NO_SHOP';
  end if;
  if tg_op = 'INSERT' then
    new.shop_id := s;
  elsif new.shop_id is distinct from old.shop_id then
    raise exception 'E_SHOP_CHANGE';
  end if;
  return new;
end $$;

create or replace function public.tg_shop_ledger() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  perform set_config('warsha.system', 'on', true);
  perform public.ensure_ledger_accounts(new.id);
  perform set_config('warsha.system', 'off', true);
  return null;
end $$;
create trigger zz_shop_ledger after insert or update of payment_methods on public.shops
  for each row execute function public.tg_shop_ledger();

-- المحلات الموجودة قبل كده
do $$
declare s uuid;
begin
  perform set_config('warsha.system', 'on', true);
  for s in select id from public.shops loop
    perform public.ensure_ledger_accounts(s);
  end loop;
  perform set_config('warsha.system', 'off', true);
end $$;

-- ============================================================
-- 6) تسجيل قيد (داخلية: الدوال بس هي اللي بتناديها)
-- ============================================================
-- p_lines: [{"account": uuid, "debit": n, "credit": n, "party_type": "...", "party_id": uuid}]
create or replace function public.ledger_post(
  p_source_type text, p_source_id uuid, p_memo text, p_lines jsonb,
  p_device uuid default null, p_idem uuid default null, p_reverses uuid default null
) returns uuid
language plpgsql security definer set search_path = public as $$
declare
  s uuid := public.current_shop_id();
  e uuid := gen_random_uuid();
  l jsonb;
  a public.accounts;
  d bigint := 0;
  c bigint := 0;
  ld bigint;
  lc bigint;
begin
  if s is null then raise exception 'E_NO_SHOP'; end if;
  if jsonb_typeof(p_lines) <> 'array' or jsonb_array_length(p_lines) < 2 then raise exception 'E_UNBALANCED'; end if;
  insert into public.journal_entries(id, shop_id, source_type, source_id, device_id, memo, idem_key, reverses_id, created_by)
  values (e, s, p_source_type, p_source_id, p_device, nullif(trim(p_memo), ''), p_idem, p_reverses, auth.uid());
  for l in select * from jsonb_array_elements(p_lines) loop
    select * into a from public.accounts where id = (l ->> 'account')::uuid and shop_id = s and deleted_at is null;
    if not found then raise exception 'E_BAD_ACCOUNT'; end if;
    ld := coalesce((l ->> 'debit')::bigint, 0);
    lc := coalesce((l ->> 'credit')::bigint, 0);
    if ld < 0 or lc < 0 or (ld > 0) = (lc > 0) then raise exception 'E_BAD_AMOUNT'; end if;
    -- العملاء والموردين والموظفين لازم يبقى معاهم الطرف
    if a.kind in ('receivable', 'payable', 'advances', 'salaries') and (l ->> 'party_id') is null then raise exception 'E_BAD_INPUT'; end if;
    insert into public.journal_lines(shop_id, entry_id, account_id, party_type, party_id, debit, credit)
    values (s, e, a.id, l ->> 'party_type', (l ->> 'party_id')::uuid, ld, lc);
    d := d + ld;
    c := c + lc;
  end loop;
  if d <> c or d = 0 then raise exception 'E_UNBALANCED'; end if;
  return e;
end $$;
revoke execute on function public.ledger_post(text, uuid, text, jsonb, uuid, uuid, uuid) from public, anon, authenticated;

-- أدوات صغيرة للدوال
create or replace function public.ledger_require(p_roles public.app_role[]) returns void
language plpgsql stable security definer set search_path = public as $$
begin
  if public.current_app_role() is null or not (public.current_app_role() = any(p_roles)) then
    raise exception 'E_FORBIDDEN';
  end if;
end $$;

create or replace function public.ledger_acc(p_code text) returns uuid
language sql stable security definer set search_path = public as $$
  select id from public.accounts where shop_id = public.current_shop_id() and code = p_code and deleted_at is null
$$;

create or replace function public.ledger_amount(p bigint) returns bigint
language plpgsql immutable as $$
begin
  if p is null or p <= 0 or p > 100000000000 then raise exception 'E_BAD_AMOUNT'; end if;
  return p;
end $$;

-- خزنة شغالة في المحل
create or replace function public.ledger_cashbox(p uuid) returns public.accounts
language plpgsql stable security definer set search_path = public as $$
declare a public.accounts;
begin
  select * into a from public.accounts where id = p and shop_id = public.current_shop_id() and kind = 'cash' and active and deleted_at is null;
  if not found then raise exception 'E_BAD_ACCOUNT'; end if;
  return a;
end $$;

create or replace function public.ledger_idem(p uuid) returns uuid
language sql stable security definer set search_path = public as $$
  select id from public.journal_entries where idem_key = p and shop_id = public.current_shop_id()
$$;

create or replace function public.ledger_line(p_acc uuid, p_debit bigint, p_credit bigint, p_party_type text default null, p_party uuid default null) returns jsonb
language sql immutable as $$
  select jsonb_strip_nulls(jsonb_build_object('account', p_acc, 'debit', p_debit, 'credit', p_credit, 'party_type', p_party_type, 'party_id', p_party))
$$;

-- رصيد حساب (اختياري: لطرف معيّن، ولحد وقت معيّن)
create or replace function public.ledger_balance(p_acc uuid, p_party uuid default null, p_before timestamptz default null) returns bigint
language sql stable security definer set search_path = public as $$
  select coalesce(sum((l.debit - l.credit) * public.account_sign(a.type)), 0)::bigint
  from public.journal_lines l
  join public.accounts a on a.id = l.account_id
  join public.journal_entries e on e.id = l.entry_id
  where l.account_id = p_acc and (p_party is null or l.party_id = p_party) and (p_before is null or e.occurred_at < p_before)
$$;

do $$
declare f text;
begin
  foreach f in array array['ledger_require(public.app_role[])', 'ledger_acc(text)', 'ledger_cashbox(uuid)', 'ledger_idem(uuid)', 'ledger_balance(uuid, uuid, timestamptz)'] loop
    execute format('revoke execute on function public.%s from public, anon, authenticated', f);
  end loop;
end $$;

-- ============================================================
-- 7) العمليات
-- ============================================================

-- دفعة من عميل (على جهاز أو من غير جهاز): تدخل الخزنة وتقلل دين العميل
create or replace function public.record_payment(p_id uuid, p_customer uuid, p_cashbox uuid, p_amount bigint, p_device uuid default null, p_method text default null, p_note text default null)
returns uuid
language plpgsql security definer set search_path = public as $$
declare
  cb public.accounts;
  e uuid;
  dev public.devices;
begin
  perform public.ledger_require(array['owner', 'reception']::public.app_role[]);
  e := public.ledger_idem(p_id);
  if e is not null then return e; end if;
  perform public.ledger_amount(p_amount);
  cb := public.ledger_cashbox(p_cashbox);
  if not exists (select 1 from public.customers where id = p_customer and shop_id = cb.shop_id and deleted_at is null) then raise exception 'E_NOT_FOUND'; end if;
  if p_device is not null then
    select * into dev from public.devices where id = p_device and shop_id = cb.shop_id and deleted_at is null;
    if not found or dev.customer_id <> p_customer then raise exception 'E_CROSS_SHOP'; end if;
  end if;
  e := public.ledger_post('payment', p_id, p_note, jsonb_build_array(
    public.ledger_line(cb.id, p_amount, 0),
    public.ledger_line(public.ledger_acc('ar'), 0, p_amount, 'customer', p_customer)
  ), p_device, p_id);
  insert into public.payments(id, shop_id, customer_id, device_id, cashbox_id, method, amount, entry_id, created_by)
  values (p_id, cb.shop_id, p_customer, p_device, cb.id, coalesce(p_method, cb.method), p_amount, e, auth.uid());
  return e;
end $$;

-- قيد عكسي: بيعكس كل سطور القيد الأصلي (وحركات المخزون لو فيه)، ومربوط بيه، وبيتسجل في السجل باسم مين وليه
create or replace function public.reverse_entry(p_entry uuid, p_reason text)
returns uuid
language plpgsql security definer set search_path = public as $$
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
  insert into public.audit_log(shop_id, actor_id, action, entity, entity_id, before, after)
  values (o.shop_id, auth.uid(), 'reverse_entry', 'journal_entries', o.id, to_jsonb(o), jsonb_build_object('reversal_id', e, 'reason', p_reason));
  return e;
end $$;

-- تحويل بين خزنتين بقيد واحد
create or replace function public.transfer_cash(p_id uuid, p_from uuid, p_to uuid, p_amount bigint, p_note text default null)
returns uuid
language plpgsql security definer set search_path = public as $$
declare a public.accounts; b public.accounts; e uuid;
begin
  perform public.ledger_require(array['owner']::public.app_role[]);
  e := public.ledger_idem(p_id);
  if e is not null then return e; end if;
  perform public.ledger_amount(p_amount);
  a := public.ledger_cashbox(p_from);
  b := public.ledger_cashbox(p_to);
  if a.id = b.id then raise exception 'E_SAME_CASHBOX'; end if;
  if public.ledger_balance(a.id) < p_amount then raise exception 'E_INSUFFICIENT'; end if;
  return public.ledger_post('transfer', p_id, p_note, jsonb_build_array(public.ledger_line(b.id, p_amount, 0), public.ledger_line(a.id, 0, p_amount)), null, p_id);
end $$;

-- مصروف: يخرج من الخزنة المختارة
create or replace function public.record_expense(p_id uuid, p_account uuid, p_cashbox uuid, p_amount bigint, p_note text default null)
returns uuid
language plpgsql security definer set search_path = public as $$
declare cb public.accounts; e uuid;
begin
  perform public.ledger_require(array['owner']::public.app_role[]);
  e := public.ledger_idem(p_id);
  if e is not null then return e; end if;
  perform public.ledger_amount(p_amount);
  cb := public.ledger_cashbox(p_cashbox);
  if not exists (select 1 from public.accounts where id = p_account and shop_id = cb.shop_id and kind = 'expense' and active and deleted_at is null) then raise exception 'E_BAD_ACCOUNT'; end if;
  return public.ledger_post('expense', p_id, p_note, jsonb_build_array(public.ledger_line(p_account, p_amount, 0), public.ledger_line(cb.id, 0, p_amount)), null, p_id);
end $$;

-- رأس مال داخل، أو سحب صاحب المحل (السحب بيقلل رأس المال، مش مصروف)
create or replace function public.owner_capital(p_id uuid, p_cashbox uuid, p_amount bigint, p_note text default null)
returns uuid
language plpgsql security definer set search_path = public as $$
declare cb public.accounts; e uuid;
begin
  perform public.ledger_require(array['owner']::public.app_role[]);
  e := public.ledger_idem(p_id);
  if e is not null then return e; end if;
  perform public.ledger_amount(p_amount);
  cb := public.ledger_cashbox(p_cashbox);
  return public.ledger_post('capital', p_id, p_note, jsonb_build_array(public.ledger_line(cb.id, p_amount, 0), public.ledger_line(public.ledger_acc('capital'), 0, p_amount)), null, p_id);
end $$;

create or replace function public.owner_drawing(p_id uuid, p_cashbox uuid, p_amount bigint, p_note text default null)
returns uuid
language plpgsql security definer set search_path = public as $$
declare cb public.accounts; e uuid;
begin
  perform public.ledger_require(array['owner']::public.app_role[]);
  e := public.ledger_idem(p_id);
  if e is not null then return e; end if;
  perform public.ledger_amount(p_amount);
  cb := public.ledger_cashbox(p_cashbox);
  return public.ledger_post('drawing', p_id, p_note, jsonb_build_array(public.ledger_line(public.ledger_acc('drawings'), p_amount, 0), public.ledger_line(cb.id, 0, p_amount)), null, p_id);
end $$;

-- الموظفين: مرتب مستحق، صرف مرتب، سلفة، خصم سلفة من المرتب
create or replace function public.ledger_employee(p uuid) returns void
language plpgsql stable security definer set search_path = public as $$
begin
  if not exists (select 1 from public.profiles where id = p and shop_id = public.current_shop_id()) then raise exception 'E_NOT_FOUND'; end if;
end $$;
revoke execute on function public.ledger_employee(uuid) from public, anon, authenticated;

create or replace function public.accrue_salary(p_id uuid, p_employee uuid, p_amount bigint, p_note text default null)
returns uuid
language plpgsql security definer set search_path = public as $$
declare e uuid;
begin
  perform public.ledger_require(array['owner']::public.app_role[]);
  e := public.ledger_idem(p_id);
  if e is not null then return e; end if;
  perform public.ledger_amount(p_amount);
  perform public.ledger_employee(p_employee);
  return public.ledger_post('salary', p_id, p_note, jsonb_build_array(
    public.ledger_line(public.ledger_acc('exp_salaries'), p_amount, 0),
    public.ledger_line(public.ledger_acc('salaries_payable'), 0, p_amount, 'employee', p_employee)), null, p_id);
end $$;

create or replace function public.pay_salary(p_id uuid, p_employee uuid, p_cashbox uuid, p_amount bigint, p_note text default null)
returns uuid
language plpgsql security definer set search_path = public as $$
declare cb public.accounts; e uuid;
begin
  perform public.ledger_require(array['owner']::public.app_role[]);
  e := public.ledger_idem(p_id);
  if e is not null then return e; end if;
  perform public.ledger_amount(p_amount);
  perform public.ledger_employee(p_employee);
  cb := public.ledger_cashbox(p_cashbox);
  return public.ledger_post('salary_payment', p_id, p_note, jsonb_build_array(
    public.ledger_line(public.ledger_acc('salaries_payable'), p_amount, 0, 'employee', p_employee),
    public.ledger_line(cb.id, 0, p_amount)), null, p_id);
end $$;

create or replace function public.give_advance(p_id uuid, p_employee uuid, p_cashbox uuid, p_amount bigint, p_note text default null)
returns uuid
language plpgsql security definer set search_path = public as $$
declare cb public.accounts; e uuid;
begin
  perform public.ledger_require(array['owner']::public.app_role[]);
  e := public.ledger_idem(p_id);
  if e is not null then return e; end if;
  perform public.ledger_amount(p_amount);
  perform public.ledger_employee(p_employee);
  cb := public.ledger_cashbox(p_cashbox);
  return public.ledger_post('advance', p_id, p_note, jsonb_build_array(
    public.ledger_line(public.ledger_acc('advances'), p_amount, 0, 'employee', p_employee),
    public.ledger_line(cb.id, 0, p_amount)), null, p_id);
end $$;

create or replace function public.settle_advance(p_id uuid, p_employee uuid, p_amount bigint, p_note text default null)
returns uuid
language plpgsql security definer set search_path = public as $$
declare e uuid;
begin
  perform public.ledger_require(array['owner']::public.app_role[]);
  e := public.ledger_idem(p_id);
  if e is not null then return e; end if;
  perform public.ledger_amount(p_amount);
  perform public.ledger_employee(p_employee);
  return public.ledger_post('advance_settle', p_id, p_note, jsonb_build_array(
    public.ledger_line(public.ledger_acc('salaries_payable'), p_amount, 0, 'employee', p_employee),
    public.ledger_line(public.ledger_acc('advances'), 0, p_amount, 'employee', p_employee)), null, p_id);
end $$;

-- ---------- المخزون ----------
-- الكمية والقيمة الحالية لصنف (من حركاته)
create or replace function public.item_stock(p_item uuid, out qty bigint, out value bigint)
language sql stable security definer set search_path = public as $$
  select coalesce(sum(m.qty), 0)::bigint, coalesce(sum(m.value), 0)::bigint from public.stock_moves m where m.item_id = p_item
$$;
revoke execute on function public.item_stock(uuid) from public, anon, authenticated;

-- تكلفة خروج n من صنف بالمتوسط المرجّح. لو خرج كل الموجود بتطلع القيمة كلها بالظبط (من غير ما يفضل كسور)
create or replace function public.ledger_issue_cost(p_qty bigint, p_value bigint, n bigint) returns bigint
language sql immutable as $$
  select case when n = p_qty then p_value else (p_value * n + p_qty / 2) / p_qty end
$$;

-- شراء قطع أو إكسسوارات من مورد: نقدي (من خزنة) أو آجل (على المورد)
-- p_lines: [{"item": uuid, "qty": n, "unit_cost": n}]
create or replace function public.record_purchase(p_id uuid, p_supplier uuid, p_lines jsonb, p_cashbox uuid default null, p_note text default null)
returns uuid
language plpgsql security definer set search_path = public as $$
declare
  s uuid := public.current_shop_id();
  l jsonb;
  total bigint := 0;
  q bigint;
  u bigint;
  e uuid;
  credit_line jsonb;
begin
  perform public.ledger_require(array['owner']::public.app_role[]);
  e := public.ledger_idem(p_id);
  if e is not null then return e; end if;
  if not exists (select 1 from public.suppliers where id = p_supplier and shop_id = s and deleted_at is null) then raise exception 'E_NOT_FOUND'; end if;
  if jsonb_typeof(p_lines) <> 'array' or jsonb_array_length(p_lines) = 0 then raise exception 'E_BAD_INPUT'; end if;
  for l in select * from jsonb_array_elements(p_lines) loop
    q := (l ->> 'qty')::bigint;
    u := (l ->> 'unit_cost')::bigint;
    if q is null or q <= 0 or q > 100000 or u is null or u < 0 then raise exception 'E_BAD_AMOUNT'; end if;
    if not exists (select 1 from public.items where id = (l ->> 'item')::uuid and shop_id = s and deleted_at is null) then raise exception 'E_NOT_FOUND'; end if;
    total := total + q * u;
  end loop;
  perform public.ledger_amount(total);
  credit_line := case when p_cashbox is null
    then public.ledger_line(public.ledger_acc('ap'), 0, total, 'supplier', p_supplier)
    else public.ledger_line((public.ledger_cashbox(p_cashbox)).id, 0, total) end;
  e := public.ledger_post('purchase', p_id, p_note, jsonb_build_array(public.ledger_line(public.ledger_acc('inventory'), total, 0), credit_line), null, p_id);
  for l in select * from jsonb_array_elements(p_lines) loop
    insert into public.stock_moves(shop_id, item_id, entry_id, qty, value)
    values (s, (l ->> 'item')::uuid, e, (l ->> 'qty')::int, (l ->> 'qty')::bigint * (l ->> 'unit_cost')::bigint);
  end loop;
  return e;
end $$;

create or replace function public.pay_supplier(p_id uuid, p_supplier uuid, p_cashbox uuid, p_amount bigint, p_note text default null)
returns uuid
language plpgsql security definer set search_path = public as $$
declare cb public.accounts; e uuid;
begin
  perform public.ledger_require(array['owner']::public.app_role[]);
  e := public.ledger_idem(p_id);
  if e is not null then return e; end if;
  perform public.ledger_amount(p_amount);
  cb := public.ledger_cashbox(p_cashbox);
  if not exists (select 1 from public.suppliers where id = p_supplier and shop_id = cb.shop_id and deleted_at is null) then raise exception 'E_NOT_FOUND'; end if;
  return public.ledger_post('supplier_payment', p_id, p_note, jsonb_build_array(
    public.ledger_line(public.ledger_acc('ap'), p_amount, 0, 'supplier', p_supplier),
    public.ledger_line(cb.id, 0, p_amount)), null, p_id);
end $$;

-- خروج صنف من المخزون (داخلية): بيرجّع التكلفة
create or replace function public.ledger_issue(p_item uuid, p_qty bigint, p_entry uuid) returns bigint
language plpgsql security definer set search_path = public as $$
declare st record; cost bigint;
begin
  perform 1 from public.items where id = p_item and shop_id = public.current_shop_id() and deleted_at is null for update;
  if not found then raise exception 'E_NOT_FOUND'; end if;
  select * into st from public.item_stock(p_item);
  if p_qty <= 0 or st.qty < p_qty then raise exception 'E_STOCK'; end if;
  cost := public.ledger_issue_cost(st.qty, st.value, p_qty);
  insert into public.stock_moves(shop_id, item_id, entry_id, qty, value) values (public.current_shop_id(), p_item, p_entry, -p_qty, -cost);
  return cost;
end $$;
revoke execute on function public.ledger_issue(uuid, bigint, uuid) from public, anon, authenticated;

-- قطعة اتركبت في جهاز: تخرج من المخزون كتكلفة على الجهاز (الفني يقدر يسجلها من غير ما يشوف السعر)
create or replace function public.use_part(p_id uuid, p_device uuid, p_item uuid, p_qty integer default 1)
returns uuid
language plpgsql security definer set search_path = public as $$
declare
  e uuid;
  cost bigint;
  inv uuid := public.ledger_acc('inventory');
  cg uuid := public.ledger_acc('cogs');
begin
  perform public.ledger_require(array['owner', 'technician']::public.app_role[]);
  e := public.ledger_idem(p_id);
  if e is not null then return e; end if;
  if not exists (select 1 from public.devices where id = p_device and shop_id = public.current_shop_id() and deleted_at is null and status <> 'delivered') then raise exception 'E_NOT_FOUND'; end if;
  -- القيد محتاج يتعمل الأول عشان حركة المخزون تتربط بيه، والتوازن بيتراجع في آخر العملية
  e := gen_random_uuid();
  insert into public.journal_entries(id, shop_id, source_type, source_id, device_id, idem_key, created_by)
  values (e, public.current_shop_id(), 'part_use', p_item, p_device, p_id, auth.uid());
  cost := public.ledger_issue(p_item, p_qty, e);
  if cost > 0 then
    insert into public.journal_lines(shop_id, entry_id, account_id, debit, credit) values
      (public.current_shop_id(), e, cg, cost, 0),
      (public.current_shop_id(), e, inv, 0, cost);
  else
    raise exception 'E_BAD_AMOUNT';  -- صنف من غير تكلفة: لازم يتشتري بسعر الأول
  end if;
  return e;
end $$;

-- بيع قطع أو إكسسوارات على الكاونتر
-- p_lines: [{"item": uuid, "qty": n, "price": n}]
create or replace function public.record_sale(p_id uuid, p_lines jsonb, p_cashbox uuid default null, p_customer uuid default null, p_note text default null)
returns uuid
language plpgsql security definer set search_path = public as $$
declare
  s uuid := public.current_shop_id();
  e uuid := gen_random_uuid();
  l jsonb;
  it public.items;
  q bigint; p bigint; cost bigint;
  rev_parts bigint := 0; rev_acc bigint := 0; total_cost bigint := 0;
  debit_acc uuid; pt text; pid uuid;
begin
  perform public.ledger_require(array['owner', 'reception']::public.app_role[]);
  if public.ledger_idem(p_id) is not null then return public.ledger_idem(p_id); end if;
  -- البيع بالآجل لصاحب المحل بس
  if p_cashbox is null and (p_customer is null or public.current_app_role() <> 'owner') then raise exception 'E_BAD_INPUT'; end if;
  if p_customer is not null and not exists (select 1 from public.customers where id = p_customer and shop_id = s and deleted_at is null) then raise exception 'E_NOT_FOUND'; end if;
  if jsonb_typeof(p_lines) <> 'array' or jsonb_array_length(p_lines) = 0 then raise exception 'E_BAD_INPUT'; end if;
  insert into public.journal_entries(id, shop_id, source_type, source_id, memo, idem_key, created_by)
  values (e, s, 'sale', p_id, nullif(trim(p_note), ''), p_id, auth.uid());
  for l in select * from jsonb_array_elements(p_lines) loop
    select * into it from public.items where id = (l ->> 'item')::uuid and shop_id = s and deleted_at is null;
    if not found then raise exception 'E_NOT_FOUND'; end if;
    q := (l ->> 'qty')::bigint;
    p := (l ->> 'price')::bigint;
    if q is null or q <= 0 or p is null or p < 0 then raise exception 'E_BAD_AMOUNT'; end if;
    cost := public.ledger_issue(it.id, q, e);
    total_cost := total_cost + cost;
    if it.kind = 'part' then rev_parts := rev_parts + q * p; else rev_acc := rev_acc + q * p; end if;
  end loop;
  perform public.ledger_amount(rev_parts + rev_acc);
  if p_cashbox is null then
    debit_acc := public.ledger_acc('ar'); pt := 'customer'; pid := p_customer;
  else
    debit_acc := (public.ledger_cashbox(p_cashbox)).id;
  end if;
  insert into public.journal_lines(shop_id, entry_id, account_id, party_type, party_id, debit, credit)
  values (s, e, debit_acc, pt, pid, rev_parts + rev_acc, 0);
  if rev_parts > 0 then insert into public.journal_lines(shop_id, entry_id, account_id, debit, credit) values (s, e, public.ledger_acc('rev_parts'), 0, rev_parts); end if;
  if rev_acc > 0 then insert into public.journal_lines(shop_id, entry_id, account_id, debit, credit) values (s, e, public.ledger_acc('rev_accessories'), 0, rev_acc); end if;
  if total_cost > 0 then
    insert into public.journal_lines(shop_id, entry_id, account_id, debit, credit) values
      (s, e, public.ledger_acc('cogs'), total_cost, 0), (s, e, public.ledger_acc('inventory'), 0, total_cost);
  end if;
  if p_cashbox is not null and p_customer is not null then
    null; -- البيع النقدي لعميل معروف ما بيأثرش على رصيده
  end if;
  return e;
end $$;

-- ---------- الدرج ----------
-- الخزن اللي أقدر أقفلها، بالمتوقع فيها (الاستقبال: الخزن اللي هو مسؤول عنها بس)
create or replace function public.my_drawers()
returns table(id uuid, code text, name text, method text, expected bigint)
language plpgsql stable security definer set search_path = public as $$
begin
  perform public.ledger_require(array['owner', 'reception']::public.app_role[]);
  return query
  select a.id, a.code, a.name, a.method, public.ledger_balance(a.id)
  from public.accounts a
  where a.shop_id = public.current_shop_id() and a.kind = 'cash' and a.active and a.deleted_at is null
    and (public.current_app_role() = 'owner' or a.holder_id = auth.uid())
  order by a.created_at;
end $$;

-- تقفيل الدرج: المتوقع من النظام والفعلي، والفرق بيتسجل قيد عجز أو زيادة باسم الموظف
create or replace function public.close_drawer(p_id uuid, p_cashbox uuid, p_counted bigint, p_note text default null)
returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  cb public.accounts;
  exp bigint;
  d bigint;
  e uuid;
  r public.drawer_closings;
begin
  perform public.ledger_require(array['owner', 'reception']::public.app_role[]);
  select * into r from public.drawer_closings where id = p_id and shop_id = public.current_shop_id();
  if found then return jsonb_build_object('expected', r.expected, 'counted', r.counted, 'diff', r.diff); end if;
  cb := public.ledger_cashbox(p_cashbox);
  if public.current_app_role() <> 'owner' and cb.holder_id is distinct from auth.uid() then raise exception 'E_FORBIDDEN'; end if;
  if p_counted is null or p_counted < 0 or p_counted > 100000000000 then raise exception 'E_BAD_AMOUNT'; end if;
  perform 1 from public.accounts where id = cb.id for update;  -- ما يحصلش تقفيلين في نفس اللحظة
  exp := public.ledger_balance(cb.id);
  d := p_counted - exp;
  if d < 0 then
    e := public.ledger_post('drawer_close', p_id, p_note, jsonb_build_array(public.ledger_line(public.ledger_acc('shortage'), -d, 0), public.ledger_line(cb.id, 0, -d)), null, p_id);
  elsif d > 0 then
    e := public.ledger_post('drawer_close', p_id, p_note, jsonb_build_array(public.ledger_line(cb.id, d, 0), public.ledger_line(public.ledger_acc('overage'), 0, d)), null, p_id);
  end if;
  insert into public.drawer_closings(id, shop_id, cashbox_id, expected, counted, diff, entry_id, note, closed_by)
  values (p_id, cb.shop_id, cb.id, exp, p_counted, d, e, nullif(trim(p_note), ''), auth.uid());
  return jsonb_build_object('expected', exp, 'counted', p_counted, 'diff', d);
end $$;

-- ---------- الحسابات المضافة ----------
create or replace function public.add_account(p_id uuid, p_kind text, p_name text, p_method text default null, p_holder uuid default null)
returns uuid
language plpgsql security definer set search_path = public as $$
begin
  perform public.ledger_require(array['owner']::public.app_role[]);
  if p_kind not in ('cash', 'expense') or nullif(trim(p_name), '') is null or length(p_name) > 80 then raise exception 'E_BAD_INPUT'; end if;
  if p_kind = 'cash' and (p_method is null or not public.valid_payment_methods(array[p_method])) then raise exception 'E_BAD_INPUT'; end if;
  if p_holder is not null and not exists (select 1 from public.profiles where id = p_holder and shop_id = public.current_shop_id() and deleted_at is null) then raise exception 'E_NOT_FOUND'; end if;
  insert into public.accounts(id, shop_id, name, type, kind, method, holder_id)
  values (p_id, public.current_shop_id(), trim(p_name), case when p_kind = 'cash' then 'asset' else 'expense' end::public.account_type, p_kind,
          case when p_kind = 'cash' then p_method end, case when p_kind = 'cash' then p_holder end);
  return p_id;
end $$;

-- تعديل خزنة أو بند مصروف: الاسم، والمسؤول، والتفعيل. النوع والطريقة ما بيتغيروش
create or replace function public.update_account(p_id uuid, p_name text default null, p_holder uuid default null, p_active boolean default null, p_clear_holder boolean default false)
returns void
language plpgsql security definer set search_path = public as $$
declare a public.accounts;
begin
  perform public.ledger_require(array['owner']::public.app_role[]);
  select * into a from public.accounts where id = p_id and shop_id = public.current_shop_id() and deleted_at is null;
  if not found or a.kind not in ('cash', 'expense') then raise exception 'E_BAD_ACCOUNT'; end if;
  if p_holder is not null and not exists (select 1 from public.profiles where id = p_holder and shop_id = a.shop_id and deleted_at is null) then raise exception 'E_NOT_FOUND'; end if;
  if p_active = false and a.kind = 'cash' and public.ledger_balance(a.id) <> 0 then raise exception 'E_CASHBOX_NOT_EMPTY'; end if;
  update public.accounts set
    name = coalesce(nullif(trim(p_name), ''), name),
    holder_id = case when p_clear_holder then null when a.kind = 'cash' then coalesce(p_holder, holder_id) else null end,
    active = coalesce(p_active, active)
  where id = a.id;
end $$;

-- ============================================================
-- 8) ربط الأجهزة: منع التسليم قبل السداد، وتسجيل الإيراد عند التسليم
-- ============================================================
create or replace function public.device_paid(p_device uuid) returns bigint
language sql stable security definer set search_path = public as $$
  select coalesce(sum(p.amount), 0)::bigint from public.payments p
  where p.device_id = p_device and not exists (select 1 from public.journal_entries r where r.reverses_id = p.entry_id)
$$;
revoke execute on function public.device_paid(uuid) from public, anon, authenticated;

create or replace function public.tg_device_paid_guard() returns trigger
language plpgsql security definer set search_path = public as $$
declare fc integer;
begin
  if new.status = 'delivered' and old.status is distinct from 'delivered' then
    select final_cost into fc from public.device_costs where device_id = new.id and deleted_at is null;
    if coalesce(fc, 0) > public.device_paid(new.id) and coalesce(current_setting('warsha.credit_ok', true), '') <> new.id::text then
      raise exception 'E_UNPAID';
    end if;
  end if;
  return new;
end $$;
create trigger zy_device_paid before update on public.devices for each row execute function public.tg_device_paid_guard();

-- عند التسليم: الإيراد بيتسجل، ودين العميل بالتكلفة (والدفعات اللي قبل كده بتصفّيه). مرة واحدة بس لكل جهاز
create or replace function public.tg_device_revenue() returns trigger
language plpgsql security definer set search_path = public as $$
declare fc integer;
begin
  if new.status = 'delivered' and old.status is distinct from 'delivered'
     and not exists (select 1 from public.journal_entries e where e.source_type = 'delivery' and e.source_id = new.id
                     and not exists (select 1 from public.journal_entries r where r.reverses_id = e.id)) then
    select final_cost into fc from public.device_costs where device_id = new.id and deleted_at is null;
    if coalesce(fc, 0) > 0 then
      perform public.ledger_post('delivery', new.id, new.order_no, jsonb_build_array(
        public.ledger_line(public.ledger_acc('ar'), fc, 0, 'customer', new.customer_id),
        public.ledger_line(public.ledger_acc('rev_repair'), 0, fc)), new.id);
    end if;
  end if;
  return null;
end $$;
create trigger zz_device_revenue after update on public.devices for each row execute function public.tg_device_revenue();

-- بعد ما الإيراد يتسجل، التكلفة النهائية ما بتتغيرش (التصحيح بقيد عكسي)
create or replace function public.tg_cost_locked() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if new.final_cost is distinct from old.final_cost and exists (
    select 1 from public.journal_entries e where e.source_type = 'delivery' and e.source_id = new.device_id
      and not exists (select 1 from public.journal_entries r where r.reverses_id = e.id)) then
    raise exception 'E_COST_LOCKED';
  end if;
  return new;
end $$;
create trigger zy_cost_locked before update on public.device_costs for each row execute function public.tg_cost_locked();

-- التسليم بالآجل (صاحب المحل بس): الباقي بيفضل دين على العميل
create or replace function public.deliver_on_credit(p_device uuid) returns void
language plpgsql security definer set search_path = public as $$
begin
  perform public.ledger_require(array['owner']::public.app_role[]);
  perform set_config('warsha.credit_ok', p_device::text, true);
  update public.devices set status = 'delivered' where id = p_device and shop_id = public.current_shop_id();
  if not found then raise exception 'E_NOT_FOUND'; end if;
  perform set_config('warsha.credit_ok', '', true);
end $$;

-- فلوس الجهاز: التكلفة، والمدفوع، والباقي، والدفعات (لصاحب المحل والاستقبال)
create or replace function public.device_money(p_device uuid) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare fc integer; paid bigint;
begin
  perform public.ledger_require(array['owner', 'reception']::public.app_role[]);
  if not exists (select 1 from public.devices where id = p_device and shop_id = public.current_shop_id()) then raise exception 'E_NOT_FOUND'; end if;
  select final_cost into fc from public.device_costs where device_id = p_device and deleted_at is null;
  paid := public.device_paid(p_device);
  return jsonb_build_object(
    'final', fc, 'paid', paid, 'due', greatest(coalesce(fc, 0) - paid, 0),
    'payments', coalesce((select jsonb_agg(jsonb_build_object(
        'id', p.id, 'amount', p.amount, 'method', p.method, 'created_at', p.created_at, 'entry_id', p.entry_id,
        'by', (select full_name from public.profiles where id = p.created_by),
        'reversed', exists (select 1 from public.journal_entries r where r.reverses_id = p.entry_id)) order by p.created_at)
      from public.payments p where p.device_id = p_device), '[]'::jsonb),
    'parts_cost', case when public.current_app_role() = 'owner' then (
      select coalesce(sum(l.debit), 0) from public.journal_lines l join public.journal_entries e on e.id = l.entry_id
      where e.device_id = p_device and e.source_type in ('part_use', 'reversal') and l.account_id = public.ledger_acc('cogs')) - (
      select coalesce(sum(l.credit), 0) from public.journal_lines l join public.journal_entries e on e.id = l.entry_id
      where e.device_id = p_device and e.source_type = 'reversal' and l.account_id = public.ledger_acc('cogs')) end
  );
end $$;

-- ============================================================
-- 9) التقارير (صاحب المحل بس)
-- ============================================================
-- الوضع المالي للفترة [p_from, p_to)
create or replace function public.financial_position(p_from timestamptz, p_to timestamptz) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare
  s uuid := public.current_shop_id();
  res jsonb;
begin
  perform public.ledger_require(array['owner']::public.app_role[]);
  with bal as (
    select a.id, a.code, a.name, a.type, a.kind, a.method, l.party_type, l.party_id,
           coalesce(sum((l.debit - l.credit) * public.account_sign(a.type)), 0)::bigint as b
    from public.accounts a
    left join public.journal_lines l on l.account_id = a.id
    where a.shop_id = s
    group by a.id, l.party_type, l.party_id
  ),
  acc as (select id, code, name, type, kind, method, sum(b)::bigint as b from bal group by id, code, name, type, kind, method),
  per as (
    select coalesce(sum(case when a.type = 'revenue' then l.credit - l.debit else 0 end), 0)::bigint as revenue,
           coalesce(sum(case when a.type = 'expense' then l.debit - l.credit else 0 end), 0)::bigint as expenses
    from public.journal_lines l join public.accounts a on a.id = l.account_id join public.journal_entries e on e.id = l.entry_id
    where l.shop_id = s and e.occurred_at >= p_from and e.occurred_at < p_to
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
      coalesce(sum(greatest(b, 0)) filter (where kind in ('receivable', 'advances')), 0)::bigint as receivables,
      (coalesce(sum(greatest(b, 0)) filter (where kind in ('payable', 'salaries')), 0)
        + coalesce(sum(greatest(-b, 0)) filter (where kind in ('receivable', 'advances')), 0)
        + coalesce(sum(greatest(-b, 0)) filter (where kind = 'inventory'), 0))::bigint as payables,
      coalesce(sum(greatest(-b, 0)) filter (where kind in ('payable', 'salaries')), 0)::bigint as payables_debit,
      coalesce(sum(greatest(b, 0)) filter (where kind = 'inventory'), 0)::bigint as inventory
    from bal
  ),
  days as (
    select (date_trunc('day', e.occurred_at at time zone 'Africa/Cairo'))::date as day,
           coalesce(sum(case when a.type = 'revenue' then l.credit - l.debit else 0 end), 0)::bigint as revenue,
           coalesce(sum(case when a.type = 'expense' then l.debit - l.credit else 0 end), 0)::bigint as expenses
    from public.journal_lines l join public.accounts a on a.id = l.account_id join public.journal_entries e on e.id = l.entry_id
    where l.shop_id = s and e.occurred_at >= p_from and e.occurred_at < p_to and a.type in ('revenue', 'expense')
    group by 1
  )
  select jsonb_build_object(
    'cash', p.cash,
    'receivables', p.receivables + p.payables_debit,
    'payables', p.payables,
    'inventory', p.inventory,
    'revenue', per.revenue,
    'expenses', per.expenses,
    'profit', per.revenue - per.expenses,
    'net_worth', p.cash + p.receivables + p.payables_debit + p.inventory - p.payables,
    'equation', jsonb_build_object('assets', eq.assets, 'liabilities', eq.liabilities, 'equity', eq.equity, 'earnings', eq.earnings),
    'debits', tot.d, 'credits', tot.c, 'unbalanced_entries', unb.n,
    'balanced', tot.d = tot.c and unb.n = 0 and eq.assets = eq.liabilities + eq.equity + eq.earnings,
    'cashboxes', coalesce((select jsonb_agg(jsonb_build_object('id', a.id, 'code', a.code, 'name', a.name, 'method', a.method, 'balance', a.b) order by a.code nulls last, a.name)
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
         and not exists (select 1 from public.journal_entries r where r.reverses_id = p2.entry_id)
       group by p2.method) m), '{}'::jsonb),
    'delivered', (select count(*) from public.devices d where d.shop_id = s and d.delivered_at >= p_from and d.delivered_at < p_to),
    'closings', coalesce((select jsonb_agg(jsonb_build_object('cashbox', dc.cashbox_id, 'expected', dc.expected, 'counted', dc.counted, 'diff', dc.diff, 'at', dc.created_at,
       'by', (select full_name from public.profiles where id = dc.closed_by)) order by dc.created_at)
       from public.drawer_closings dc where dc.shop_id = s and dc.created_at >= p_from and dc.created_at < p_to), '[]'::jsonb)
  ) into res
  from parts p, per, tot, unb, eq;
  return res;
end $$;

-- حركات خزنة أو كشف حساب (عميل/مورد/موظف) بالرصيد بعد كل حركة
-- p_kind: 'cashbox' (p_id = الخزنة) أو 'customer' / 'supplier' / 'employee' (p_id = الطرف)
create or replace function public.statement(p_kind text, p_id uuid, p_from timestamptz, p_to timestamptz) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare
  s uuid := public.current_shop_id();
  accs uuid[];
  opening bigint;
  res jsonb;
begin
  perform public.ledger_require(array['owner']::public.app_role[]);
  if p_kind = 'cashbox' then
    select array_agg(id) into accs from public.accounts where id = p_id and shop_id = s and kind = 'cash';
  elsif p_kind = 'customer' then
    select array_agg(id) into accs from public.accounts where shop_id = s and kind = 'receivable';
  elsif p_kind = 'supplier' then
    select array_agg(id) into accs from public.accounts where shop_id = s and kind = 'payable';
  elsif p_kind = 'employee' then
    select array_agg(id) into accs from public.accounts where shop_id = s and kind in ('advances', 'salaries');
  else
    raise exception 'E_BAD_INPUT';
  end if;
  if accs is null then raise exception 'E_NOT_FOUND'; end if;
  -- الرصيد: للخزنة والعميل والسلف = مدين − دائن. للمورد والمرتبات = دائن − مدين (الطرف الطبيعي)
  select coalesce(sum((l.debit - l.credit) * public.account_sign(a.type)), 0) into opening
  from public.journal_lines l join public.accounts a on a.id = l.account_id join public.journal_entries e on e.id = l.entry_id
  where l.account_id = any(accs) and (p_kind = 'cashbox' or l.party_id = p_id) and e.occurred_at < p_from;
  with mv as (
    select e.id as entry_id, e.entry_no, e.occurred_at, e.source_type, e.source_id, e.device_id, e.memo, e.reverses_id,
           d.order_no, p.full_name as by_name, a.code as account_code,
           ((l.debit - l.credit) * public.account_sign(a.type))::bigint as amount
    from public.journal_lines l
    join public.accounts a on a.id = l.account_id
    join public.journal_entries e on e.id = l.entry_id
    left join public.devices d on d.id = e.device_id
    left join public.profiles p on p.id = e.created_by
    where l.account_id = any(accs) and (p_kind = 'cashbox' or l.party_id = p_id) and e.occurred_at >= p_from and e.occurred_at < p_to
  ),
  mv2 as (select mv.*, opening + sum(amount) over (order by occurred_at, entry_no rows unbounded preceding) as running from mv)
  select jsonb_build_object('opening', opening, 'moves', coalesce(jsonb_agg(jsonb_build_object(
      'entry_id', entry_id, 'entry_no', entry_no, 'at', occurred_at, 'source_type', source_type, 'source_id', source_id,
      'device_id', device_id, 'order_no', order_no, 'memo', memo, 'by', by_name, 'account', account_code, 'amount', amount,
      'reversed', exists (select 1 from public.journal_entries r where r.reverses_id = entry_id), 'reverses', reverses_id,
      'balance', running) order by occurred_at, entry_no), '[]'::jsonb))
  into res from mv2;
  return res;
end $$;

-- الأصناف بالكمية (والتكلفة والقيمة لصاحب المحل بس)
create or replace function public.items_stock() returns table(id uuid, kind text, name text, sku text, sale_price integer, qty bigint, avg_cost bigint, value bigint)
language plpgsql stable security definer set search_path = public as $$
declare r public.app_role := public.current_app_role();
begin
  if r is null then raise exception 'E_FORBIDDEN'; end if;
  return query
  select i.id, i.kind, i.name, i.sku,
         case when r = 'technician' then null else i.sale_price end,
         coalesce(st.q, 0)::bigint,
         case when r = 'owner' and coalesce(st.q, 0) > 0 then (st.v / st.q)::bigint end,
         case when r = 'owner' then coalesce(st.v, 0)::bigint end
  from public.items i
  left join (select m.item_id, sum(m.qty) as q, sum(m.value) as v from public.stock_moves m group by m.item_id) st on st.item_id = i.id
  where i.shop_id = public.current_shop_id() and i.deleted_at is null
  order by i.kind, i.name;
end $$;

-- ============================================================
-- 10) الصلاحيات
-- ============================================================
alter table public.accounts enable row level security;
alter table public.journal_entries enable row level security;
alter table public.journal_lines enable row level security;
alter table public.suppliers enable row level security;
alter table public.items enable row level security;
alter table public.stock_moves enable row level security;
alter table public.payments enable row level security;
alter table public.drawer_closings enable row level security;

revoke all on public.accounts, public.journal_entries, public.journal_lines, public.suppliers, public.items,
  public.stock_moves, public.payments, public.drawer_closings from public, anon, authenticated;

-- الحسابات: صاحب المحل كلها، والاستقبال الخزن بس (أسماءها، من غير أرصدة)
create policy accounts_select on public.accounts for select to authenticated using (
  shop_id = public.current_shop_id() and (public.current_app_role() = 'owner' or (public.current_app_role() = 'reception' and kind = 'cash')));
grant select on public.accounts to authenticated;

-- القيود والسطور والمخزون: صاحب المحل بس. ومحدش بيكتب فيهم مباشرة (الدوال بس)
create policy entries_select on public.journal_entries for select to authenticated using (shop_id = public.current_shop_id() and public.current_app_role() = 'owner');
create policy lines_select on public.journal_lines for select to authenticated using (shop_id = public.current_shop_id() and public.current_app_role() = 'owner');
create policy moves_select on public.stock_moves for select to authenticated using (shop_id = public.current_shop_id() and public.current_app_role() = 'owner');
grant select on public.journal_entries, public.journal_lines, public.stock_moves to authenticated;

-- الدفعات: صاحب المحل والاستقبال يشوفوها
create policy payments_select on public.payments for select to authenticated using (shop_id = public.current_shop_id() and public.current_app_role() in ('owner', 'reception'));
grant select on public.payments to authenticated;

-- تقفيل الدرج: صاحب المحل الكل، والاستقبال بتاعه بس
create policy closings_select on public.drawer_closings for select to authenticated using (
  shop_id = public.current_shop_id() and (public.current_app_role() = 'owner' or closed_by = auth.uid()));
grant select on public.drawer_closings to authenticated;

-- الموردين: صاحب المحل بس
create policy suppliers_all on public.suppliers for select to authenticated using (shop_id = public.current_shop_id() and public.current_app_role() = 'owner');
create policy suppliers_insert on public.suppliers for insert to authenticated with check (shop_id = public.current_shop_id() and public.current_app_role() = 'owner');
create policy suppliers_update on public.suppliers for update to authenticated using (shop_id = public.current_shop_id() and public.current_app_role() = 'owner') with check (shop_id = public.current_shop_id());
grant select, insert, update on public.suppliers to authenticated;

-- الأصناف: صاحب المحل بيضيف ويعدّل، والاستقبال بيشوف (الفني من items_stock من غير أسعار)
create policy items_select on public.items for select to authenticated using (shop_id = public.current_shop_id() and public.current_app_role() in ('owner', 'reception'));
create policy items_insert on public.items for insert to authenticated with check (shop_id = public.current_shop_id() and public.current_app_role() = 'owner');
create policy items_update on public.items for update to authenticated using (shop_id = public.current_shop_id() and public.current_app_role() = 'owner') with check (shop_id = public.current_shop_id());
grant select, insert, update on public.items to authenticated;

-- الدوال: للمستخدمين المسجلين بس (وكل دالة بتتأكد من الدور جواها)
do $$
declare f text;
begin
  foreach f in array array[
    'record_payment(uuid, uuid, uuid, bigint, uuid, text, text)', 'reverse_entry(uuid, text)', 'transfer_cash(uuid, uuid, uuid, bigint, text)',
    'record_expense(uuid, uuid, uuid, bigint, text)', 'owner_capital(uuid, uuid, bigint, text)', 'owner_drawing(uuid, uuid, bigint, text)',
    'accrue_salary(uuid, uuid, bigint, text)', 'pay_salary(uuid, uuid, uuid, bigint, text)', 'give_advance(uuid, uuid, uuid, bigint, text)',
    'settle_advance(uuid, uuid, bigint, text)', 'record_purchase(uuid, uuid, jsonb, uuid, text)', 'pay_supplier(uuid, uuid, uuid, bigint, text)',
    'use_part(uuid, uuid, uuid, integer)', 'record_sale(uuid, jsonb, uuid, uuid, text)', 'my_drawers()', 'close_drawer(uuid, uuid, bigint, text)',
    'add_account(uuid, text, text, text, uuid)', 'update_account(uuid, text, uuid, boolean, boolean)', 'deliver_on_credit(uuid)',
    'device_money(uuid)', 'financial_position(timestamptz, timestamptz)', 'statement(text, uuid, timestamptz, timestamptz)', 'items_stock()'
  ] loop
    execute format('revoke execute on function public.%s from public, anon', f);
    execute format('grant execute on function public.%s to authenticated', f);
  end loop;
end $$;
