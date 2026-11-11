-- 0039: N (المرحلة الأولى): مواعيد التحصيل وخطط التقسيط ومركز الإشعارات.
-- - خطة لعميل (ليا: هو عليه للمحل) أو لمورد (عليا: المحل عليه للمورد): قسط واحد = "ميعاد تحصيل"، أو كذا قسط بجدول.
-- - المدفوع ما بيتخزنش: بيتحسب من القيود (زي كل الأرصدة). كل اللي بيقلل رصيد الطرف بعد ما الخطة اتعملت
--   (دفعة، أو مرتجع، أو مقاصة) بيتوزع على خطط الطرف بالأقدم، وجوه الخطة على الأقساط بالترتيب:
--   الزيادة بتغطي القسط اللي بعده، والنقص بيفضل على نفس القسط. الخطة بتتقفل لوحدها لما تتغطى كلها.
-- - الإشعارات بتتحسب وقت ما تتطلب (مفيش مهام في الخلفية): أقساط متأخرة، وأقساط قربت، وأجهزة جاهزة من 10 أيام،
--   وأصناف ناقصة، وبيعات محتاجة تسوية. كل مستخدم بيشوف اللي ليه صلاحيته بس، و"اتقرا" بيتحفظ له هو.

create table public.payment_plans (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references public.shops(id),
  branch_id uuid references public.branches(id),
  party_type text not null check (party_type in ('customer', 'supplier')),
  party_id uuid not null,
  title text check (title is null or length(title) <= 120),
  total bigint not null check (total > 0),
  note text check (note is null or length(note) <= 500),
  created_by uuid references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);
create index payment_plans_party on public.payment_plans(shop_id, party_type, party_id) where deleted_at is null;

create table public.plan_installments (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references public.shops(id),
  plan_id uuid not null references public.payment_plans(id),
  seq integer not null check (seq between 1 and 120),
  due_date date not null,
  amount bigint not null check (amount > 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  unique (plan_id, seq)
);

create table public.notification_reads (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references public.shops(id),
  profile_id uuid not null references auth.users(id),
  key text not null check (length(key) <= 120),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  unique (profile_id, key)
);

alter table public.payment_plans enable row level security;
alter table public.plan_installments enable row level security;
alter table public.notification_reads enable row level security;
create trigger set_updated_at before update on public.payment_plans for each row execute function public.tg_set_updated_at();
create trigger set_updated_at before update on public.plan_installments for each row execute function public.tg_set_updated_at();
create trigger set_updated_at before update on public.notification_reads for each row execute function public.tg_set_updated_at();
create trigger block_delete before delete on public.payment_plans for each row execute function public.tg_block_delete();
create trigger block_delete before delete on public.plan_installments for each row execute function public.tg_block_delete();
create trigger block_delete before delete on public.notification_reads for each row execute function public.tg_block_delete();
create trigger zz_audit after insert or update on public.payment_plans for each row execute function public.tg_audit();

-- القراية: صاحب المحل، أو اللي معاه "يشوف" في الوضع المالي (مش الفني). الكتابة من الدوال بس
create policy plans_select on public.payment_plans for select to authenticated
  using (shop_id = public.current_shop_id() and (public.current_app_role() = 'owner' or (public.current_app_role() = 'reception' and (select public.has_perm('finance', 'view')))));
create policy installments_select on public.plan_installments for select to authenticated
  using (shop_id = public.current_shop_id() and (public.current_app_role() = 'owner' or (public.current_app_role() = 'reception' and (select public.has_perm('finance', 'view')))));
create policy reads_select on public.notification_reads for select to authenticated using (profile_id = auth.uid());
grant select on public.payment_plans, public.plan_installments, public.notification_reads to authenticated;

-- كام يوم قبل الميعاد بيبان "قرب" (الإعدادات ← التنبيهات، الافتراضي 3)
create or replace function public.reminder_days() returns integer
language sql stable security definer set search_path = public as $$
  select least(greatest(coalesce((select (s.extras -> 'reminders' ->> 'days')::int from public.shops s where s.id = public.current_shop_id()), 3), 0), 30)
$$;
revoke execute on function public.reminder_days() from public, anon;
grant execute on function public.reminder_days() to authenticated;

-- اللي اتدفع للطرف من وقت معيّن: كل اللي قلّل رصيده (من غير القيود اللي اتلغت ولا قيود الإلغاء نفسها)
create or replace function public.party_paid_since(p_type text, p_party uuid, p_since timestamptz) returns bigint
language sql stable security definer set search_path = public as $$
  select coalesce(sum(case when p_type = 'customer' then l.credit else l.debit end), 0)::bigint
  from public.journal_lines l
  join public.accounts a on a.id = l.account_id and a.kind = case when p_type = 'customer' then 'receivable' else 'payable' end
  join public.journal_entries e on e.id = l.entry_id
  where l.shop_id = public.current_shop_id() and l.party_id = p_party and e.created_at >= p_since
    and e.reverses_id is null and not exists (select 1 from public.journal_entries r where r.reverses_id = e.id)
$$;
revoke execute on function public.party_paid_since(text, uuid, timestamptz) from public, anon, authenticated;

-- الخطط بحالتها: المدفوع والباقي والقسط الجاي والمتأخر، وكل قسط مغطّي قد إيه
create or replace function public.plans_overview(p_party_type text default null, p_party uuid default null)
returns table(plan_id uuid, party_type text, party_id uuid, party_name text, title text, total bigint, paid bigint, remaining bigint,
              next_due date, next_amount bigint, overdue bigint, status text, created_at timestamptz, installments jsonb)
language plpgsql stable security definer set search_path = public as $$
#variable_conflict use_column
declare s uuid := public.current_shop_id(); today date := (now() at time zone 'Africa/Cairo')::date; soon integer := public.reminder_days();
begin
  perform public.grant_require('finance', 'view');
  return query
  with pl as (
    select p.*, min(p.created_at) over (partition by p.party_type, p.party_id) first_at,
           coalesce(sum(p.total) over (partition by p.party_type, p.party_id order by p.created_at, p.id rows between unbounded preceding and 1 preceding), 0) before_total
    from public.payment_plans p
    where p.shop_id = s and p.deleted_at is null
      and (p_party_type is null or p.party_type = p_party_type) and (p_party is null or p.party_id = p_party)
  ), pool as (
    select distinct x.party_type, x.party_id, public.party_paid_since(x.party_type, x.party_id, x.first_at) amount from pl x
  ), paid as (
    select pl.*, least(pl.total, greatest(0, po.amount - pl.before_total))::bigint got
    from pl join pool po on po.party_type = pl.party_type and po.party_id = pl.party_id
  ), inst as (
    select i.plan_id, i.seq, i.due_date, i.amount,
           least(i.amount, greatest(0, pd.got - coalesce(sum(i.amount) over (partition by i.plan_id order by i.seq rows between unbounded preceding and 1 preceding), 0)))::bigint covered
    from public.plan_installments i join paid pd on pd.id = i.plan_id
    where i.deleted_at is null
  )
  select pd.id, pd.party_type, pd.party_id,
         coalesce((select c.name from public.customers c where pd.party_type = 'customer' and c.id = pd.party_id),
                  (select sp.name from public.suppliers sp where pd.party_type = 'supplier' and sp.id = pd.party_id)),
         pd.title, pd.total, pd.got, pd.total - pd.got,
         (select min(x.due_date) from inst x where x.plan_id = pd.id and x.covered < x.amount),
         (select x.amount - x.covered from inst x where x.plan_id = pd.id and x.covered < x.amount order by x.seq limit 1),
         coalesce((select sum(x.amount - x.covered) from inst x where x.plan_id = pd.id and x.covered < x.amount and x.due_date < today), 0)::bigint,
         case when pd.got >= pd.total then 'done'
              when exists (select 1 from inst x where x.plan_id = pd.id and x.covered < x.amount and x.due_date < today) then 'overdue'
              when exists (select 1 from inst x where x.plan_id = pd.id and x.covered < x.amount and x.due_date <= today + soon) then 'due_soon'
              else 'open' end,
         pd.created_at,
         coalesce((select jsonb_agg(jsonb_build_object('seq', x.seq, 'due', x.due_date, 'amount', x.amount, 'covered', x.covered,
                     'status', case when x.covered >= x.amount then 'paid' when x.due_date < today then 'overdue' when x.due_date <= today + soon then 'due_soon' else 'upcoming' end)
                     order by x.seq) from inst x where x.plan_id = pd.id), '[]'::jsonb)
  from paid pd
  order by (pd.got >= pd.total), (select min(x.due_date) from inst x where x.plan_id = pd.id and x.covered < x.amount) nulls last, pd.created_at;
end $$;
revoke execute on function public.plans_overview(text, uuid) from public, anon;
grant execute on function public.plans_overview(text, uuid) to authenticated;

-- خطة جديدة: p_rows = [{due: 'YYYY-MM-DD', amount: قروش}] (قسط واحد = ميعاد تحصيل). الإجمالي = مجموع الأقساط
create or replace function public.save_plan(p_id uuid, p_party_type text, p_party uuid, p_rows jsonb, p_title text default null, p_note text default null) returns uuid
language plpgsql security definer set search_path = public as $$
declare s uuid := public.current_shop_id(); r jsonb; n integer := 0; tot bigint := 0; a bigint; d date;
begin
  perform public.grant_require('finance', 'add');
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
revoke execute on function public.save_plan(uuid, text, uuid, jsonb, text, text) from public, anon;
grant execute on function public.save_plan(uuid, text, uuid, jsonb, text, text) to authenticated;

-- إلغاء الخطة (مش حذف: بتتعلّم ملغية وبتفضل في سجل النشاط). الفلوس والقيود ما بتتأثرش
create or replace function public.cancel_plan(p_id uuid) returns void
language plpgsql security definer set search_path = public as $$
begin
  perform public.grant_require('finance', 'delete');
  update public.payment_plans set deleted_at = now() where id = p_id and shop_id = public.current_shop_id() and deleted_at is null;
  if not found then raise exception 'E_NOT_FOUND'; end if;
end $$;
revoke execute on function public.cancel_plan(uuid) from public, anon;
grant execute on function public.cancel_plan(uuid) to authenticated;

-- ---------- مركز الإشعارات ----------
-- key ثابت لكل إشعار (عشان "اتقرا" يفضل)، وkind + args بيتحولوا لجملة في الواجهة بلغة البرنامج
create or replace function public.my_notifications()
returns table(key text, kind text, args jsonb, link text, at timestamptz, read boolean)
language plpgsql stable security definer set search_path = public as $$
#variable_conflict use_column
declare s uuid := public.current_shop_id(); r public.app_role := public.current_app_role(); uid uuid := auth.uid();
  today date := (now() at time zone 'Africa/Cairo')::date;
begin
  if r is null then raise exception 'E_FORBIDDEN'; end if;
  -- أقساط متأخرة أو قربت (مين يشوف الوضع المالي)
  if r = 'owner' or (r = 'reception' and public.has_perm('finance', 'view')) then
    return query
    select 'inst:' || i.id::text || ':' || (case when i.due_date < today then 'late' else 'soon' end),
           case when i.due_date < today then 'overdue' else 'due_soon' end,
           jsonb_build_object('name', o.party_name, 'amount', (x ->> 'amount')::bigint - (x ->> 'covered')::bigint, 'due', i.due_date, 'party_type', o.party_type),
           '/finance/' || o.party_type || '/' || o.party_id::text,
           (i.due_date::timestamp at time zone 'Africa/Cairo'),
           false
    from public.plans_overview() o
    cross join lateral jsonb_array_elements(o.installments) x
    join public.plan_installments i on i.plan_id = o.plan_id and i.seq = (x ->> 'seq')::int and i.deleted_at is null
    where x ->> 'status' in ('overdue', 'due_soon');
  end if;
  -- أجهزة جاهزة من 10 أيام أو أكتر ومحدش استلمها (مين يشوف الأجهزة، في فروعه)
  if r <> 'technician' and public.has_perm('devices', 'view') then
    return query
    select 'ready:' || d.id::text, 'ready_old', jsonb_build_object('order', d.order_no, 'days', (today - (sl.at at time zone 'Africa/Cairo')::date)), '/devices/' || d.id::text, sl.at, false
    from public.devices d
    cross join lateral (select max(l.created_at) at from public.status_log l where l.device_id = d.id and l.new_status = 'ready' and l.deleted_at is null) sl
    where d.shop_id = s and d.deleted_at is null and d.status = 'ready' and public.can_branch(d.branch_id)
      and sl.at is not null and sl.at < now() - interval '10 days';
  end if;
  -- أصناف وصلت للحد الأدنى، وبيعات من غير رصيد لسه محتاجة تسوية
  if r <> 'technician' and public.has_perm('inventory', 'view') then
    return query
    select 'short:' || st.id::text || ':' || st.qty::text, 'short', jsonb_build_object('name', st.name, 'qty', st.qty), '/inventory', now(), false
    from public.items_stock() st where st.short;
    return query
    select 'unsettled:' || st.id::text || ':' || st.unsettled::text, 'unsettled', jsonb_build_object('name', st.name, 'qty', st.unsettled), '/inventory', now(), false
    from public.items_stock() st where st.unsettled > 0;
  end if;
end $$;
-- نفس القايمة ومعاها "اتقرا" لكل مستخدم
create or replace function public.notifications_feed()
returns table(key text, kind text, args jsonb, link text, at timestamptz, read boolean)
language sql stable security definer set search_path = public as $$
  select n.key, n.kind, n.args, n.link, n.at, exists (select 1 from public.notification_reads nr where nr.profile_id = auth.uid() and nr.key = n.key and nr.deleted_at is null)
  from public.my_notifications() n
  order by 6, 5 desc
  limit 200
$$;
revoke execute on function public.notifications_feed() from public, anon;
grant execute on function public.notifications_feed() to authenticated;
revoke execute on function public.my_notifications() from public, anon;
grant execute on function public.my_notifications() to authenticated;

create or replace function public.mark_notifications_read(p_keys text[]) returns void
language plpgsql security definer set search_path = public as $$
declare s uuid := public.current_shop_id();
begin
  if s is null or auth.uid() is null then raise exception 'E_FORBIDDEN'; end if;
  if coalesce(array_length(p_keys, 1), 0) > 200 then raise exception 'E_BAD_INPUT'; end if;
  insert into public.notification_reads(shop_id, profile_id, key)
  select s, auth.uid(), k from unnest(p_keys) k where length(k) between 1 and 120
  on conflict (profile_id, key) do nothing;
end $$;
revoke execute on function public.mark_notifications_read(text[]) from public, anon;
grant execute on function public.mark_notifications_read(text[]) to authenticated;

-- ---------- النسخة الاحتياطية والاسترجاع: الخطط والأقساط ----------
-- backup_snapshot: (src: 0037_item_details.sql) + payment_plans وplan_installments
create or replace function public.backup_snapshot(p_shop uuid) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare
  res jsonb := jsonb_build_object('format', 'warsha-backup', 'version', 1, 'generated_at', now(), 'shop_id', p_shop);
  t text;
  rows jsonb;
begin
  foreach t in array array['shops', 'branches', 'staff_branches', 'shop_branding', 'profiles', 'customers', 'devices', 'device_costs', 'status_log', 'device_notes', 'device_photos', 'device_checks',
                           'quote_decisions', 'message_templates', 'message_log', 'accounts', 'journal_entries', 'journal_lines', 'payments', 'drawer_closings',
                           'suppliers', 'items', 'stock_moves', 'uncosted_sales', 'payment_plans', 'plan_installments', 'purchases', 'labor_rates', 'specialties', 'staff_specialties', 'routes', 'repair_steps',
                           'repair_videos', 'device_ratings', 'issue_presets', 'partners', 'profit_distributions', 'party_links', 'shop_lists', 'audit_log'] loop
    execute format('select coalesce(jsonb_agg(to_jsonb(x)), ''[]''::jsonb) from public.%I x where x.shop_id = $1', t) into rows using p_shop;
    res := res || jsonb_build_object(t, rows);
  end loop;
  select coalesce(jsonb_agg(jsonb_build_object('device_id', device_id, 'kind', kind, 'erased_at', erased_at)), '[]'::jsonb)
    into rows from public.device_passcodes where shop_id = p_shop;
  return res || jsonb_build_object('device_passcodes', rows);
end $$;

-- restore_backup: (src: 0037_item_details.sql) + payment_plans وplan_installments
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
  tabs text[] := array['branches', 'profiles', 'staff_branches', 'shop_branding', 'accounts', 'customers', 'suppliers', 'party_links', 'partners', 'specialties', 'staff_specialties', 'routes', 'labor_rates',
                       'issue_presets', 'shop_lists', 'message_templates', 'items', 'devices', 'device_costs', 'status_log', 'device_notes', 'device_checks',
                       'quote_decisions', 'repair_steps', 'repair_videos', 'device_ratings', 'journal_entries', 'journal_lines', 'profit_distributions', 'payments',
                       'purchases', 'stock_moves', 'uncosted_sales', 'payment_plans', 'plan_installments', 'drawer_closings', 'message_log', 'audit_log'];
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

