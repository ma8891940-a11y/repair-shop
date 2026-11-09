-- ============================================================
-- 0031: رأس مال الشريك بأنواعه، وحقوق الملكية في الوضع المالي (ملاحظات صاحب المشروع على البند 5)
-- رأس مال الشريك حقوق ملكية، مش دين على المحل، ومش إيراد ولا ربح:
--   أ) فلوس دخلت دلوقتي: الخزنة مدين، ورأس مال الشريك دائن.
--   ب) بضاعة: المخزون مدين (وحركة مخزون بالكمية والتكلفة)، ورأس مال الشريك دائن.
--   ج) معدات: "أصول ثابتة" مدين، ورأس مال الشريك دائن (وبتدخل في قيمة المحل).
--   د) رأس مال قديم (قبل البرنامج): رصيد افتتاحي من غير ما يلمس الخزن: جزء من رأس المال الافتتاحي بيتنقل للشريك.
-- كل حركة بتاريخها (النهارده أو قبل كده). وزيادة رأس المال أو سحب جزء منه بعدين بنفس الطريقة.
-- الوضع المالي: "عليا للناس" فيها الموردين والمرتبات بس (ومعاهم عربون العملاء لأنه فلوس لناس من بره)، وحقوق الملكية في قسم لوحده.
-- ============================================================

alter table public.accounts drop constraint if exists accounts_kind_check;
alter table public.accounts add constraint accounts_kind_check check (kind = any (array[
  'cash', 'receivable', 'advances', 'inventory', 'payable', 'salaries', 'capital', 'drawings', 'revenue', 'cogs', 'expense', 'shortage', 'overage',
  'partner_capital', 'partner_current', 'retained', 'fixed_asset']));

create or replace function public.ensure_partner_accounts(p_shop uuid) returns void
language sql security definer set search_path = public as $$
  insert into public.accounts(shop_id, code, type, kind) values
    (p_shop, 'partners_capital', 'equity', 'partner_capital'),
    (p_shop, 'partners_current', 'equity', 'partner_current'),
    (p_shop, 'retained', 'equity', 'retained'),
    (p_shop, 'fixed_assets', 'asset', 'fixed_asset')
  on conflict (shop_id, code) where code is not null do nothing
$$;
revoke execute on function public.ensure_partner_accounts(uuid) from public, anon, authenticated;
do $$
declare s uuid;
begin
  perform set_config('warsha.system', 'on', true);
  for s in select id from public.shops loop perform public.ensure_partner_accounts(s); end loop;
  perform set_config('warsha.system', 'off', true);
end $$;

-- نفس ledger_post (0029) بتاريخ محدد للعملية (للحركات اللي حصلت قبل النهارده)
create or replace function public.ledger_post_at(
  p_at timestamptz, p_source_type text, p_source_id uuid, p_memo text, p_lines jsonb,
  p_device uuid default null, p_idem uuid default null
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
  insert into public.journal_entries(id, shop_id, occurred_at, source_type, source_id, device_id, memo, idem_key, created_by)
  values (e, s, p_at, p_source_type, p_source_id, p_device, nullif(trim(p_memo), ''), p_idem, auth.uid());
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
revoke execute on function public.ledger_post_at(timestamptz, text, uuid, text, jsonb, uuid, uuid) from public, anon, authenticated;

-- تاريخ العملية: اليوم اللي اتكتب (بتوقيت القاهرة، الساعة 12 الضهر) أو دلوقتي لو النهارده. ممنوع تاريخ في المستقبل
create or replace function public.ledger_day_at(p_date date) returns timestamptz
language plpgsql stable set search_path = public as $$
declare today date := (now() at time zone 'Africa/Cairo')::date;
begin
  if p_date is null or p_date = today then return now(); end if;
  if p_date > today or p_date < date '2000-01-01' then raise exception 'E_BAD_DATE'; end if;
  return (p_date + time '12:00') at time zone 'Africa/Cairo';
end $$;
revoke execute on function public.ledger_day_at(date) from public, anon, authenticated;

-- رأس مال داخل من شريك: p_kind = cash | goods | equipment | old
create or replace function public.partner_capital_in(p_id uuid, p_partner uuid, p_kind text, p_amount bigint default null, p_date date default null,
  p_cashbox uuid default null, p_lines jsonb default null, p_note text default null) returns uuid
language plpgsql security definer set search_path = public as $$
declare s uuid := public.current_shop_id(); e uuid; at timestamptz; l jsonb; q bigint; u bigint; total bigint := 0; debit_line jsonb; memo text;
begin
  perform public.ledger_require(array['owner']::public.app_role[]);
  e := public.ledger_idem(p_id);
  if e is not null then return e; end if;
  if not exists (select 1 from public.partners where id = p_partner and shop_id = s and deleted_at is null) then raise exception 'E_NOT_FOUND'; end if;
  at := public.ledger_day_at(p_date);
  memo := coalesce(nullif(trim(p_note), ''), p_kind);
  if p_kind = 'goods' then
    if jsonb_typeof(p_lines) <> 'array' or jsonb_array_length(p_lines) = 0 then raise exception 'E_BAD_INPUT'; end if;
    for l in select * from jsonb_array_elements(p_lines) loop
      q := (l ->> 'qty')::bigint;
      u := (l ->> 'unit_cost')::bigint;
      if q is null or q <= 0 or q > 100000 or u is null or u < 0 then raise exception 'E_BAD_AMOUNT'; end if;
      if not exists (select 1 from public.items where id = (l ->> 'item')::uuid and shop_id = s and deleted_at is null) then raise exception 'E_NOT_FOUND'; end if;
      total := total + q * u;
    end loop;
    perform public.ledger_amount(total);
    debit_line := public.ledger_line(public.ledger_acc('inventory'), total, 0);
  else
    perform public.ledger_amount(p_amount);
    total := p_amount;
    if p_kind = 'cash' then
      debit_line := public.ledger_line((public.ledger_cashbox(p_cashbox)).id, total, 0);
    elsif p_kind = 'equipment' then
      debit_line := public.ledger_line(public.ledger_acc('fixed_assets'), total, 0);
    elsif p_kind = 'old' then
      -- رأس مال قديم: الأصول نفسها اتسجلت في الجرد قصاد رأس المال، فهنا جزء منه بيتنقل للشريك بس
      debit_line := public.ledger_line(public.ledger_acc('capital'), total, 0);
    else
      raise exception 'E_BAD_INPUT';
    end if;
  end if;
  e := public.ledger_post_at(at, case when p_kind = 'old' then 'opening' else 'partner_capital' end, p_partner, memo, jsonb_build_array(
    debit_line, public.ledger_line(public.ledger_acc('partners_capital'), 0, total, 'partner', p_partner)), null, p_id);
  if p_kind = 'goods' then
    for l in select * from jsonb_array_elements(p_lines) loop
      insert into public.stock_moves(shop_id, item_id, entry_id, qty, value) values (s, (l ->> 'item')::uuid, e, (l ->> 'qty')::int, (l ->> 'qty')::bigint * (l ->> 'unit_cost')::bigint);
    end loop;
  end if;
  return e;
end $$;

-- سحب من الشريك بتاريخ: من رأس ماله (تخفيض رأس المال) أو من أرباحه (الجاري). مش مصروف
create or replace function public.partner_capital_out(p_id uuid, p_partner uuid, p_cashbox uuid, p_amount bigint, p_date date default null,
  p_from_capital boolean default true, p_note text default null) returns uuid
language plpgsql security definer set search_path = public as $$
declare e uuid; cb public.accounts;
begin
  perform public.ledger_require(array['owner']::public.app_role[]);
  e := public.ledger_idem(p_id);
  if e is not null then return e; end if;
  perform public.ledger_amount(p_amount);
  cb := public.ledger_cashbox(p_cashbox);
  if not exists (select 1 from public.partners where id = p_partner and shop_id = cb.shop_id) then raise exception 'E_NOT_FOUND'; end if;
  return public.ledger_post_at(public.ledger_day_at(p_date), 'partner_withdrawal', p_partner, p_note, jsonb_build_array(
    public.ledger_line(public.ledger_acc(case when p_from_capital then 'partners_capital' else 'partners_current' end), p_amount, 0, 'partner', p_partner),
    public.ledger_line(cb.id, 0, p_amount)), null, p_id);
end $$;

do $$
declare f text;
begin
  foreach f in array array['partner_capital_in(uuid, uuid, text, bigint, date, uuid, jsonb, text)', 'partner_capital_out(uuid, uuid, uuid, bigint, date, boolean, text)'] loop
    execute format('revoke execute on function public.%s from public, anon', f);
    execute format('grant execute on function public.%s to authenticated', f);
  end loop;
end $$;

-- (0031) نفس financial_position من 0008، والفرق: الأصول الثابتة، و"أرباح مستحقة للشركاء" لوحدها، وتفاصيل حقوق الملكية
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
    'fixed_assets', p.fixed_assets,
    'partners_due', p.partners_due,
    -- قيمة المحل = الأصول − الالتزامات اللي لناس من بره بس (رأس مال الشركاء وأرباحهم حقوق ملكية، فما بتقللهاش)
    'net_worth', p.cash + p.receivables + p.payables_debit + p.inventory + p.fixed_assets - p.payables,
    -- حقوق الملكية بالتفصيل (من أول يوم): رأس مال صاحب المحل، والسحوبات، ورأس مال وجاري كل شريك، والأرباح المحتجزة
    'equity_parts', jsonb_build_object(
      'owner_capital', coalesce((select b from acc where code = 'capital'), 0),
      'drawings', -coalesce((select b from acc where code = 'drawings'), 0),
      'retained', eq.earnings + coalesce((select b from acc where code = 'retained'), 0),
      'partners', coalesce((select jsonb_agg(jsonb_build_object('id', pt.id, 'name', pt.name, 'share_bp', pt.share_bp,
          'capital', coalesce((select sum(b.b) from bal b where b.kind = 'partner_capital' and b.party_id = pt.id), 0),
          'current', coalesce((select sum(b.b) from bal b where b.kind = 'partner_current' and b.party_id = pt.id), 0)) order by pt.share_bp desc, pt.name)
        from public.partners pt where pt.shop_id = s and (pt.deleted_at is null or exists (select 1 from bal b where b.party_id = pt.id and b.b <> 0))), '[]'::jsonb)),
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
