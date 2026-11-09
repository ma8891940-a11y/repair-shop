-- ============================================================
-- 0029: الشركاء (البند 5)
-- - كل شريك: الاسم، ورأس ماله، ونسبته من صافي الربح (بالـ 0.01%: من 0 لـ 10000)، وتاريخ دخوله. ومجموع النسب ≤ 100%.
-- - حسابين لكل محل (حقوق ملكية): "رأس مال الشركاء" و"جاري الشركاء"، وكل سطر عليهم باسم الشريك.
--   - إيداع رأس مال: الخزنة مدين، ورأس مال الشريك دائن.
--   - سحب شريك: جاري الشريك (أو رأس ماله) مدين، والخزنة دائن. **مش مصروف**، فما بيقللش الربح.
--   - توزيع الأرباح لفترة: صافي الربح (الإيرادات − المصروفات) × نسبة كل شريك، بيتنقل من "أرباح محتجزة" لجاري الشريك.
--     الباقي (لو النسب أقل من 100%) بيفضل للمحل. والقسمة أعداد صحيحة بالقروش (من غير كسور).
--     ممنوع توزيع نفس الفترة مرتين (إلا لو التوزيع القديم اتلغى بقيد عكسي). والخسارة بتتوزع بنفس الطريقة.
-- - الشريك بيدخل توزيع الفترة لو تاريخ دخوله قبل نهايتها.
-- ============================================================

alter table public.journal_entries drop constraint if exists journal_entries_source_type_check;
alter table public.journal_entries add constraint journal_entries_source_type_check check (source_type = any (array[
  'payment', 'delivery', 'purchase', 'supplier_payment', 'part_use', 'sale', 'expense', 'salary', 'salary_payment', 'advance',
  'advance_settle', 'capital', 'drawing', 'transfer', 'drawer_close', 'reversal', 'cost_adjust',
  'write_off', 'supplier_return', 'sale_return', 'opening', 'partner_capital', 'partner_withdrawal', 'profit_distribution']));
alter table public.accounts drop constraint if exists accounts_kind_check;
alter table public.accounts add constraint accounts_kind_check check (kind = any (array[
  'cash', 'receivable', 'advances', 'inventory', 'payable', 'salaries', 'capital', 'drawings', 'revenue', 'cogs', 'expense', 'shortage', 'overage',
  'partner_capital', 'partner_current', 'retained']));
alter table public.journal_lines drop constraint if exists journal_lines_party_type_check;
alter table public.journal_lines add constraint journal_lines_party_type_check check (party_type = any (array['customer', 'supplier', 'employee', 'partner']));

-- ---------- الشركاء ----------
create table if not exists public.partners (
  id uuid primary key,
  shop_id uuid not null references public.shops(id),
  name text not null check (length(trim(name)) between 1 and 120),
  phone text check (phone is null or length(phone) <= 20),
  share_bp integer not null check (share_bp between 0 and 10000),
  joined_on date not null default current_date,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);
alter table public.partners enable row level security;
revoke all on public.partners from public, anon, authenticated;
grant select, insert, update on public.partners to authenticated;
drop policy if exists partners_select on public.partners;
drop policy if exists partners_insert on public.partners;
drop policy if exists partners_update on public.partners;
create policy partners_select on public.partners for select to authenticated using (shop_id = public.current_shop_id() and public.current_app_role() = 'owner');
create policy partners_insert on public.partners for insert to authenticated with check (shop_id = public.current_shop_id() and public.current_app_role() = 'owner');
create policy partners_update on public.partners for update to authenticated using (shop_id = public.current_shop_id() and public.current_app_role() = 'owner') with check (shop_id = public.current_shop_id());
drop trigger if exists set_updated_at on public.partners;
create trigger set_updated_at before update on public.partners for each row execute function public.tg_set_updated_at();
drop trigger if exists block_delete on public.partners;
create trigger block_delete before delete on public.partners for each row execute function public.tg_block_delete();
drop trigger if exists a_force_shop_id on public.partners;
create trigger a_force_shop_id before insert or update on public.partners for each row execute function public.tg_force_shop_id();
drop trigger if exists zz_audit on public.partners;
create trigger zz_audit after insert or update on public.partners for each row execute function public.tg_audit();

-- مجموع نسب الشركاء الساريين ≤ 100%
create or replace function public.tg_partners_share() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  perform pg_advisory_xact_lock(hashtext('partners:' || new.shop_id::text));
  -- الشريك اللي ليه أو عليه فلوس ما بيتحذفش (سوّي حسابه الأول)
  if tg_op = 'UPDATE' and old.deleted_at is null and new.deleted_at is not null
     and exists (select 1 from public.journal_lines l where l.party_type = 'partner' and l.party_id = new.id group by l.party_id having sum(l.credit - l.debit) <> 0) then
    raise exception 'E_HAS_BALANCE';
  end if;
  if (select coalesce(sum(share_bp), 0) from public.partners where shop_id = new.shop_id and deleted_at is null) > 10000 then
    raise exception 'E_SHARE_OVER_100';
  end if;
  return null;
end $$;
drop trigger if exists zz_partners_share on public.partners;
create constraint trigger zz_partners_share after insert or update on public.partners deferrable initially immediate for each row execute function public.tg_partners_share();

-- ---------- الحسابات ----------
create or replace function public.ensure_partner_accounts(p_shop uuid) returns void
language sql security definer set search_path = public as $$
  insert into public.accounts(shop_id, code, type, kind) values
    (p_shop, 'partners_capital', 'equity', 'partner_capital'),
    (p_shop, 'partners_current', 'equity', 'partner_current'),
    (p_shop, 'retained', 'equity', 'retained')
  on conflict (shop_id, code) where code is not null do nothing
$$;
revoke execute on function public.ensure_partner_accounts(uuid) from public, anon, authenticated;
create or replace function public.tg_shop_partner_accounts() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  perform set_config('warsha.system', 'on', true);
  perform public.ensure_partner_accounts(new.id);
  perform set_config('warsha.system', 'off', true);
  return null;
end $$;
drop trigger if exists zz_shop_partner_accounts on public.shops;
create trigger zz_shop_partner_accounts after insert on public.shops for each row execute function public.tg_shop_partner_accounts();
do $$
declare s uuid;
begin
  perform set_config('warsha.system', 'on', true);
  for s in select id from public.shops loop perform public.ensure_partner_accounts(s); end loop;
  perform set_config('warsha.system', 'off', true);
end $$;

-- ---------- توزيعات الأرباح (عشان نفس الفترة ما تتوزعش مرتين) ----------
create table if not exists public.profit_distributions (
  id uuid primary key,
  shop_id uuid not null references public.shops(id),
  period_from timestamptz not null,
  period_to timestamptz not null check (period_to > period_from),
  profit bigint not null,
  entry_id uuid not null unique references public.journal_entries(id),
  created_by uuid references public.profiles(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);
alter table public.profit_distributions enable row level security;
revoke all on public.profit_distributions from public, anon, authenticated;
grant select on public.profit_distributions to authenticated;
drop policy if exists distributions_select on public.profit_distributions;
create policy distributions_select on public.profit_distributions for select to authenticated using (shop_id = public.current_shop_id() and public.current_app_role() = 'owner');
drop trigger if exists block_delete on public.profit_distributions;
create trigger block_delete before delete on public.profit_distributions for each row execute function public.tg_block_delete();
-- ---------- إيداع رأس مال شريك ----------
create or replace function public.partner_deposit(p_id uuid, p_partner uuid, p_cashbox uuid, p_amount bigint, p_note text default null) returns uuid
language plpgsql security definer set search_path = public as $$
declare cb public.accounts; e uuid;
begin
  perform public.ledger_require(array['owner']::public.app_role[]);
  e := public.ledger_idem(p_id);
  if e is not null then return e; end if;
  perform public.ledger_amount(p_amount);
  cb := public.ledger_cashbox(p_cashbox);
  if not exists (select 1 from public.partners where id = p_partner and shop_id = cb.shop_id and deleted_at is null) then raise exception 'E_NOT_FOUND'; end if;
  return public.ledger_post('partner_capital', p_partner, p_note, jsonb_build_array(
    public.ledger_line(cb.id, p_amount, 0),
    public.ledger_line(public.ledger_acc('partners_capital'), 0, p_amount, 'partner', p_partner)), null, p_id);
end $$;

-- ---------- سحب شريك (مش مصروف): من جاريه، أو من رأس ماله ----------
create or replace function public.partner_withdraw(p_id uuid, p_partner uuid, p_cashbox uuid, p_amount bigint, p_note text default null, p_from_capital boolean default false) returns uuid
language plpgsql security definer set search_path = public as $$
declare cb public.accounts; e uuid;
begin
  perform public.ledger_require(array['owner']::public.app_role[]);
  e := public.ledger_idem(p_id);
  if e is not null then return e; end if;
  perform public.ledger_amount(p_amount);
  cb := public.ledger_cashbox(p_cashbox);
  if not exists (select 1 from public.partners where id = p_partner and shop_id = cb.shop_id) then raise exception 'E_NOT_FOUND'; end if;
  return public.ledger_post('partner_withdrawal', p_partner, p_note, jsonb_build_array(
    public.ledger_line(public.ledger_acc(case when p_from_capital then 'partners_capital' else 'partners_current' end), p_amount, 0, 'partner', p_partner),
    public.ledger_line(cb.id, 0, p_amount)), null, p_id);
end $$;

-- صافي الربح لفترة (الإيرادات − المصروفات) من القيود
create or replace function public.period_profit(p_shop uuid, p_from timestamptz, p_to timestamptz) returns bigint
language sql stable security definer set search_path = public as $$
  select coalesce(sum(l.credit - l.debit), 0)::bigint
  from public.journal_lines l join public.accounts a on a.id = l.account_id join public.journal_entries e on e.id = l.entry_id
  where e.shop_id = p_shop and a.type in ('revenue', 'expense') and e.occurred_at >= p_from and e.occurred_at < p_to
$$;
revoke execute on function public.period_profit(uuid, timestamptz, timestamptz) from public, anon, authenticated;

-- معاينة التوزيع: الربح ونصيب كل شريك (من غير ما يتسجل حاجة)
create or replace function public.profit_split(p_from timestamptz, p_to timestamptz) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare s uuid := public.current_shop_id(); pr bigint;
begin
  perform public.ledger_require(array['owner']::public.app_role[]);
  if p_to <= p_from then raise exception 'E_BAD_INPUT'; end if;
  pr := public.period_profit(s, p_from, p_to);
  return jsonb_build_object(
    'profit', pr,
    'overlap', exists (select 1 from public.profit_distributions d where d.shop_id = s and d.period_from < p_to and d.period_to > p_from
                        and not exists (select 1 from public.journal_entries r where r.reverses_id = d.entry_id)),
    'shares', coalesce((select jsonb_agg(jsonb_build_object('partner', p.id, 'name', p.name, 'share_bp', p.share_bp,
                 'amount', (pr * p.share_bp / 10000)::bigint) order by p.share_bp desc, p.name)
               from public.partners p where p.shop_id = s and p.deleted_at is null and p.joined_on <= ((p_to - interval '1 microsecond') at time zone 'Africa/Cairo')::date), '[]'::jsonb));
end $$;

-- التوزيع نفسه
create or replace function public.distribute_profit(p_id uuid, p_from timestamptz, p_to timestamptz) returns uuid
language plpgsql security definer set search_path = public as $$
declare s uuid := public.current_shop_id(); e uuid; sp jsonb; x jsonb; total bigint := 0; amt bigint; lines jsonb := '[]'::jsonb; pr bigint;
begin
  perform public.ledger_require(array['owner']::public.app_role[]);
  e := public.ledger_idem(p_id);
  if e is not null then return e; end if;
  perform pg_advisory_xact_lock(hashtext('distribute:' || s::text));
  sp := public.profit_split(p_from, p_to);
  if (sp ->> 'overlap')::boolean then raise exception 'E_PERIOD_DISTRIBUTED'; end if;
  pr := (sp ->> 'profit')::bigint;
  for x in select * from jsonb_array_elements(sp -> 'shares') loop
    amt := (x ->> 'amount')::bigint;
    if amt = 0 then continue; end if;
    total := total + amt;
    lines := lines || jsonb_build_array(public.ledger_line(public.ledger_acc('partners_current'), greatest(-amt, 0), greatest(amt, 0), 'partner', (x ->> 'partner')::uuid));
  end loop;
  if total = 0 then raise exception 'E_NOTHING_TO_DISTRIBUTE'; end if;
  lines := lines || jsonb_build_array(public.ledger_line(public.ledger_acc('retained'), greatest(total, 0), greatest(-total, 0)));
  e := public.ledger_post('profit_distribution', null, to_char(p_from at time zone 'Africa/Cairo', 'YYYY-MM-DD') || ' → ' || to_char((p_to - interval '1 second') at time zone 'Africa/Cairo', 'YYYY-MM-DD'), lines, null, p_id);
  insert into public.profit_distributions(id, shop_id, period_from, period_to, profit, entry_id, created_by) values (p_id, s, p_from, p_to, pr, e, auth.uid());
  return e;
end $$;

-- أرصدة الشركاء: رأس المال، والجاري، والإجمالي (اللي ليه عند المحل)
create or replace function public.partner_balances() returns table(id uuid, name text, phone text, share_bp integer, joined_on date, capital bigint, current bigint, total bigint)
language plpgsql stable security definer set search_path = public as $$
begin
  perform public.ledger_require(array['owner']::public.app_role[]);
  return query
  select p.id, p.name, p.phone, p.share_bp, p.joined_on,
         coalesce(sum(l.credit - l.debit) filter (where a.kind = 'partner_capital'), 0)::bigint,
         coalesce(sum(l.credit - l.debit) filter (where a.kind = 'partner_current'), 0)::bigint,
         coalesce(sum(l.credit - l.debit), 0)::bigint
  from public.partners p
  left join public.journal_lines l on l.party_type = 'partner' and l.party_id = p.id
  left join public.accounts a on a.id = l.account_id
  where p.shop_id = public.current_shop_id() and p.deleted_at is null
  group by p.id
  order by p.share_bp desc, p.name;
end $$;

do $$
declare f text;
begin
  foreach f in array array['partner_deposit(uuid, uuid, uuid, bigint, text)', 'partner_withdraw(uuid, uuid, uuid, bigint, text, boolean)',
    'profit_split(timestamptz, timestamptz)', 'distribute_profit(uuid, timestamptz, timestamptz)', 'partner_balances()'] loop
    execute format('revoke execute on function public.%s from public, anon', f);
    execute format('grant execute on function public.%s to authenticated', f);
  end loop;
end $$;

-- (0029) نفس ledger_post من 0008، والفرق: حسابات الشركاء لازم يبقى معاها الشريك
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
    -- العملاء والموردين والموظفين والشركاء لازم يبقى معاهم الطرف
    if a.kind in ('receivable', 'payable', 'advances', 'salaries', 'partner_capital', 'partner_current') and (l ->> 'party_id') is null then raise exception 'E_BAD_INPUT'; end if;
    insert into public.journal_lines(shop_id, entry_id, account_id, party_type, party_id, debit, credit)
    values (s, e, a.id, l ->> 'party_type', (l ->> 'party_id')::uuid, ld, lc);
    d := d + ld;
    c := c + lc;
  end loop;
  if d <> c or d = 0 then raise exception 'E_UNBALANCED'; end if;
  return e;
end $$;

-- (0029) نفس statement من 0008، والفرق: كشف حساب الشريك
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
  elsif p_kind = 'partner' then
    -- (0029) كشف الشريك: رأس ماله وحسابه الجاري. الرصيد = اللي ليه عند المحل
    select array_agg(id) into accs from public.accounts where shop_id = s and kind in ('partner_capital', 'partner_current');
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

-- (0029) نفس integrity_report من 0025، والفرق: سطور الشركاء من غير الشريك بتظهر كمشكلة
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
           where l.shop_id = s and a.kind in ('receivable', 'payable', 'advances', 'salaries', 'partner_capital', 'partner_current') and l.party_id is null group by l.entry_id, e.entry_no loop
    out := out || jsonb_build_array(jsonb_build_object('kind', 'party_missing', 'amount', r.amt, 'entry_id', r.entry_id, 'entry_no', r.entry_no));
  end loop;
  -- 7) كل سطر في نفس محل القيد
  for r in select l.entry_id, e.entry_no from public.journal_lines l join public.journal_entries e on e.id = l.entry_id where e.shop_id = s and l.shop_id <> e.shop_id group by 1, 2 loop
    out := out || jsonb_build_array(jsonb_build_object('kind', 'shop_mismatch', 'amount', 0, 'entry_id', r.entry_id, 'entry_no', r.entry_no));
  end loop;
  return out;
end $$;

-- (0029) نفس opening_balance من 0028، والفرق: رأس مال الشريك في الجرد
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
  elsif p_kind = 'partner' then
    -- (0029) رأس مال شريك وقت الجرد: جزء من رأس المال الافتتاحي بيتنقل لحساب الشريك
    if p_amount < 0 then raise exception 'E_BAD_AMOUNT'; end if;
    if not exists (select 1 from public.partners where id = p_ref and shop_id = s and deleted_at is null) then raise exception 'E_NOT_FOUND'; end if;
    lines := jsonb_build_array(public.ledger_line(cap, p_amount, 0), public.ledger_line(public.ledger_acc('partners_capital'), 0, p_amount, 'partner', p_ref));
  else
    raise exception 'E_BAD_INPUT';
  end if;
  memo := p_kind;
  return public.ledger_post('opening', p_ref, memo, lines, null, p_id);
end $$;

-- (0029) النسخة الاحتياطية والاسترجاع: نفس 0019 و0023، والفرق إن الشركاء وتوزيعات الأرباح بقوا جوه النسخة
create or replace function public.backup_snapshot(p_shop uuid) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare
  res jsonb := jsonb_build_object('format', 'warsha-backup', 'version', 1, 'generated_at', now(), 'shop_id', p_shop);
  t text;
  rows jsonb;
begin
  foreach t in array array['shops', 'shop_branding', 'profiles', 'customers', 'devices', 'device_costs', 'status_log', 'device_notes', 'device_photos', 'device_checks',
                           'quote_decisions', 'message_templates', 'message_log', 'accounts', 'journal_entries', 'journal_lines', 'payments', 'drawer_closings',
                           'suppliers', 'items', 'stock_moves', 'purchases', 'labor_rates', 'specialties', 'staff_specialties', 'routes', 'repair_steps',
                           'repair_videos', 'device_ratings', 'issue_presets', 'partners', 'profit_distributions', 'audit_log'] loop
    execute format('select coalesce(jsonb_agg(to_jsonb(x)), ''[]''::jsonb) from public.%I x where x.shop_id = $1', t) into rows using p_shop;
    res := res || jsonb_build_object(t, rows);
  end loop;
  select coalesce(jsonb_agg(jsonb_build_object('device_id', device_id, 'kind', kind, 'erased_at', erased_at)), '[]'::jsonb)
    into rows from public.device_passcodes where shop_id = p_shop;
  return res || jsonb_build_object('device_passcodes', rows);
end $$;
revoke execute on function public.backup_snapshot(uuid) from public, anon, authenticated;

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
  tabs text[] := array['profiles', 'shop_branding', 'accounts', 'customers', 'suppliers', 'partners', 'specialties', 'staff_specialties', 'routes', 'labor_rates',
                       'issue_presets', 'message_templates', 'items', 'devices', 'device_costs', 'status_log', 'device_notes', 'device_checks',
                       'quote_decisions', 'repair_steps', 'repair_videos', 'device_ratings', 'journal_entries', 'journal_lines', 'profit_distributions', 'payments',
                       'purchases', 'stock_moves', 'drawer_closings', 'message_log', 'audit_log'];
  -- الجداول دي ليها نسخة اتعملت مع التسجيل: بتتطابق بالكود (أو المفتاح) وبتاخد قيم النسخة
  keyed text[] := array['accounts', 'routes', 'specialties', 'message_templates', 'labor_rates', 'shop_branding'];
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
  insert into public.order_counters(shop_id, year, last_value)
  select s, split_part(order_no, '-', 1)::int, max(split_part(order_no, '-', 2)::int)
    from public.devices where shop_id = s and order_no ~ '^\d{4}-\d+$' group by 2
  on conflict (shop_id, year) do update set last_value = greatest(public.order_counters.last_value, excluded.last_value);

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
revoke execute on function public.restore_backup(jsonb) from public, anon;
grant execute on function public.restore_backup(jsonb) to authenticated;

-- (0029) نفس opening_summary من 0028، والفرق: رأس مال الشركاء في الجرد بيظهر لوحده (والإجمالي زي ما هو)
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
    -- (0029) رأس مال المحل الافتتاحي كله = رأس المال + اللي اتنقل للشركاء
    'capital', coalesce((select sum(credit - debit) from ln where code in ('capital', 'partners_capital')), 0),
    'partners', coalesce((select sum(credit - debit) from ln where code = 'partners_capital'), 0),
    'entries', (select count(*) from en),
    'balanced', coalesce((select sum(debit) = sum(credit) from ln), true),
    'done', coalesce((select (extras ->> 'opening_done')::boolean from public.shops where id = s), false)
  ) into res;
  return res;
end $$;
