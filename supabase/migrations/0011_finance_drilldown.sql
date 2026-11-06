-- تفاصيل أرقام شاشة "الوضع المالي" (صاحب المحل بس): كل رقم بيتفتح لتفاصيله

-- كل الأرصدة لنوع معيّن: customers (ليّا)، suppliers (عليّا)، employees (سلف ومرتبات)
create or replace function public.party_balances(p_kind text)
returns table(party_type text, party_id uuid, name text, account text, balance bigint)
language plpgsql stable security definer set search_path = public as $$
declare s uuid := public.current_shop_id();
begin
  perform public.ledger_require(array['owner']::public.app_role[]);
  if p_kind not in ('customers', 'suppliers', 'employees') then raise exception 'E_BAD_INPUT'; end if;
  return query
  select l.party_type, l.party_id,
         coalesce(c.name, sp.name, p.full_name) as name, a.code,
         sum((l.debit - l.credit) * public.account_sign(a.type))::bigint
  from public.journal_lines l
  join public.accounts a on a.id = l.account_id
  left join public.customers c on l.party_type = 'customer' and c.id = l.party_id
  left join public.suppliers sp on l.party_type = 'supplier' and sp.id = l.party_id
  left join public.profiles p on l.party_type = 'employee' and p.id = l.party_id
  where l.shop_id = s and l.party_id is not null
    and ((p_kind = 'customers' and a.kind = 'receivable') or (p_kind = 'suppliers' and a.kind = 'payable') or (p_kind = 'employees' and a.kind in ('advances', 'salaries')))
  group by l.party_type, l.party_id, c.name, sp.name, p.full_name, a.code
  having sum((l.debit - l.credit) * public.account_sign(a.type)) <> 0
  order by 5 desc;
end $$;

-- الإيرادات والمصروفات لكل بند في الفترة
create or replace function public.pl_breakdown(p_from timestamptz, p_to timestamptz)
returns table(account_id uuid, code text, name text, type public.account_type, amount bigint)
language plpgsql stable security definer set search_path = public as $$
begin
  perform public.ledger_require(array['owner']::public.app_role[]);
  return query
  select a.id, a.code, a.name, a.type,
         sum(case when a.type = 'revenue' then l.credit - l.debit else l.debit - l.credit end)::bigint
  from public.journal_lines l
  join public.accounts a on a.id = l.account_id
  join public.journal_entries e on e.id = l.entry_id
  where l.shop_id = public.current_shop_id() and a.type in ('revenue', 'expense') and e.occurred_at >= p_from and e.occurred_at < p_to
  group by a.id
  having sum(l.debit - l.credit) <> 0
  order by a.type desc, 5 desc;
end $$;

-- صافي حركة كل خزنة يوم بيوم في الفترة (للـ sparkline)
create or replace function public.cashbox_daily(p_from timestamptz, p_to timestamptz)
returns table(cashbox uuid, day date, net bigint)
language plpgsql stable security definer set search_path = public as $$
begin
  perform public.ledger_require(array['owner']::public.app_role[]);
  return query
  select l.account_id, (date_trunc('day', e.occurred_at at time zone 'Africa/Cairo'))::date, sum(l.debit - l.credit)::bigint
  from public.journal_lines l
  join public.accounts a on a.id = l.account_id and a.kind = 'cash'
  join public.journal_entries e on e.id = l.entry_id
  where l.shop_id = public.current_shop_id() and e.occurred_at >= p_from and e.occurred_at < p_to
  group by 1, 2
  order by 2;
end $$;

do $$
declare f text;
begin
  foreach f in array array['party_balances(text)', 'pl_breakdown(timestamptz, timestamptz)', 'cashbox_daily(timestamptz, timestamptz)'] loop
    execute format('revoke execute on function public.%s from public, anon', f);
    execute format('grant execute on function public.%s to authenticated', f);
  end loop;
end $$;

-- تحديث لحظي: أي قيد جديد بيحدّث شاشة الوضع المالي (والـ RLS بيخلي صاحب المحل بس يستقبله)
do $$
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    begin
      alter publication supabase_realtime add table public.journal_entries, public.payments;
    exception when duplicate_object then null;
    end;
  end if;
end $$;

-- قالب واتساب جديد: تذكير العميل المدين بالمبلغ اللي عليه
alter table public.message_templates drop constraint if exists message_templates_key_check;
alter table public.message_templates add constraint message_templates_key_check
  check (key in ('received', 'status', 'approval', 'ready', 'reminder', 'delivered', 'debt'));
