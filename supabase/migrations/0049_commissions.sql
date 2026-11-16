-- 0049: C5: عمولات الفنيين (كانت مؤجلة وصاحب المشروع طلبها بالاسم يوم 2026-11-15)، والمكافآت والجزاءات.
-- قاعدة العمولة: نسبة من المصنعية (التكلفة النهائية − تكلفة القطع) أو مبلغ ثابت لكل إصلاح، لكل فني أو لكل نوع عطل (المسار).
-- العمولة بتتقيّد لوحدها وقت التسليم: مصروف المرتبات ← مستحقات الموظفين (باسم الفني)، فبتظهر في كشف حساب الفني وبتتصرف بـ "صرف مرتب".
-- لو الجهاز اشتغل عليه أكتر من فني: كل فني بياخد عمولته (النسبة بتتقسم على عددهم، والثابت كامل لكل واحد).
-- المكافأة والجزاء قيود برضه (الجزاء بيقلل المستحق). كله أعداد صحيحة بالقروش، والنسبة بـ basis points (10000 = 100%).

alter table public.journal_entries drop constraint if exists journal_entries_source_type_check;
alter table public.journal_entries add constraint journal_entries_source_type_check check (source_type = any (array[
  'payment', 'delivery', 'purchase', 'supplier_payment', 'part_use', 'sale', 'expense', 'salary', 'salary_payment', 'advance', 'advance_settle',
  'capital', 'drawing', 'transfer', 'drawer_close', 'reversal', 'cost_adjust', 'write_off', 'supplier_return', 'sale_return', 'opening',
  'partner_capital', 'partner_withdrawal', 'profit_distribution', 'netting', 'stock_transfer', 'commission', 'bonus', 'penalty']));

create table public.commission_rules (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references public.shops(id),
  technician_id uuid references public.profiles(id),
  route_id uuid references public.routes(id),
  mode text not null check (mode in ('percent', 'fixed')),
  value bigint not null check ((mode = 'percent' and value between 1 and 10000) or (mode = 'fixed' and value between 1 and 2000000000)),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);
-- قاعدة واحدة شغالة لكل (فني، نوع عطل)
create unique index commission_rules_one on public.commission_rules(shop_id, coalesce(technician_id, '00000000-0000-0000-0000-000000000000'::uuid), coalesce(route_id, '00000000-0000-0000-0000-000000000000'::uuid)) where deleted_at is null;
alter table public.commission_rules enable row level security;
create trigger set_updated_at before update on public.commission_rules for each row execute function public.tg_set_updated_at();
create trigger block_delete before delete on public.commission_rules for each row execute function public.tg_block_delete();
create trigger a_force_shop_id before insert or update on public.commission_rules for each row execute function public.tg_force_shop_id();
create trigger zz_audit after insert or update on public.commission_rules for each row execute function public.tg_audit();
-- صاحب المحل بس (القواعد فيها نسب فلوس)
create policy commission_rules_select on public.commission_rules for select to authenticated using (shop_id = public.current_shop_id() and public.current_app_role() = 'owner');
create policy commission_rules_insert on public.commission_rules for insert to authenticated with check (shop_id = public.current_shop_id() and public.current_app_role() = 'owner');
create policy commission_rules_update on public.commission_rules for update to authenticated using (shop_id = public.current_shop_id() and public.current_app_role() = 'owner');
grant select, insert, update on public.commission_rules to authenticated;

-- الفنيين اللي اشتغلوا على الجهاز: خطوات المسار اللي خلصت، وإلا آخر فني غيّر حالته
create or replace function public.device_technicians(p_device uuid) returns uuid[]
language sql stable security definer set search_path = public as $$
  select coalesce(
    (select array_agg(distinct s.technician_id order by s.technician_id) from public.repair_steps s
      where s.device_id = p_device and s.status = 'done' and s.technician_id is not null and s.deleted_at is null),
    (select array[l.changed_by] from public.status_log l join public.profiles p on p.id = l.changed_by
      where l.device_id = p_device and p.role = 'technician' order by l.created_at desc limit 1),
    array[]::uuid[])
$$;
revoke execute on function public.device_technicians(uuid) from public, anon, authenticated;

-- أنسب قاعدة: الفني + نوع العطل، ثم الفني، ثم نوع العطل، ثم العامة
create or replace function public.commission_rule_for(p_shop uuid, p_tech uuid, p_route uuid) returns public.commission_rules
language sql stable security definer set search_path = public as $$
  select r.* from public.commission_rules r
  where r.shop_id = p_shop and r.deleted_at is null
    and (r.technician_id is null or r.technician_id = p_tech) and (r.route_id is null or r.route_id = p_route)
  order by (r.technician_id is not null) desc, (r.route_id is not null) desc limit 1
$$;
revoke execute on function public.commission_rule_for(uuid, uuid, uuid) from public, anon, authenticated;

-- تكلفة القطع اللي اتركبت في الجهاز (بعد أي عكس)
create or replace function public.device_parts_cost(p_device uuid) returns bigint
language sql stable security definer set search_path = public as $$
  select coalesce(-sum(m.value), 0)::bigint from public.stock_moves m join public.journal_entries e on e.id = m.entry_id
  where e.device_id = p_device and e.source_type in ('part_use', 'reversal')
$$;
revoke execute on function public.device_parts_cost(uuid) from public, anon, authenticated;

-- حساب العمولات لجهاز (من غير تسجيل): لكل فني المبلغ
create or replace function public.commission_preview(p_device uuid) returns table(technician_id uuid, amount bigint)
language plpgsql stable security definer set search_path = public as $$
declare d public.devices; techs uuid[]; n int; base bigint; r public.commission_rules; t uuid; share bigint;
begin
  select * into d from public.devices where id = p_device;
  if d.id is null then return; end if;
  techs := public.device_technicians(p_device);
  n := coalesce(array_length(techs, 1), 0);
  if n = 0 then return; end if;
  base := greatest(coalesce((select c.final_cost from public.device_costs c where c.device_id = p_device and c.deleted_at is null), 0) - public.device_parts_cost(p_device), 0);
  foreach t in array techs loop
    r := public.commission_rule_for(d.shop_id, t, d.route_id);
    continue when r.id is null;
    share := case when r.mode = 'fixed' then r.value else (base / n) * r.value / 10000 end;
    if share > 0 then technician_id := t; amount := share; return next; end if;
  end loop;
end $$;
revoke execute on function public.commission_preview(uuid) from public, anon, authenticated;

-- وقت التسليم: قيد عمولة لكل فني (مرة واحدة لكل جهاز وفني)
create or replace function public.tg_commission() returns trigger
language plpgsql security definer set search_path = public as $$
declare x record; k uuid;
begin
  if public.restoring() then return new; end if;
  if new.status <> 'delivered' or old.status = 'delivered' then return new; end if;
  for x in select * from public.commission_preview(new.id) loop
    k := md5(new.id::text || ':' || x.technician_id::text || ':commission')::uuid;
    continue when exists (select 1 from public.journal_entries j where j.idem_key = k);
    perform public.ledger_post('commission', new.id, new.order_no, jsonb_build_array(
      public.ledger_line(public.ledger_acc('exp_salaries'), x.amount, 0),
      public.ledger_line(public.ledger_acc('salaries_payable'), 0, x.amount, 'employee', x.technician_id)), new.id, k);
  end loop;
  return new;
end $$;
create trigger zz_commission after update of status on public.devices for each row execute function public.tg_commission();

-- مكافأة وجزاء (صاحب المحل)
create or replace function public.staff_bonus(p_id uuid, p_employee uuid, p_amount bigint, p_note text default null) returns uuid
language plpgsql security definer set search_path = public as $$
declare e uuid;
begin
  perform public.ledger_require(array['owner']::public.app_role[]);
  e := public.ledger_idem(p_id);
  if e is not null then return e; end if;
  perform public.ledger_amount(p_amount);
  perform public.ledger_employee(p_employee);
  return public.ledger_post('bonus', p_id, p_note, jsonb_build_array(
    public.ledger_line(public.ledger_acc('exp_salaries'), p_amount, 0),
    public.ledger_line(public.ledger_acc('salaries_payable'), 0, p_amount, 'employee', p_employee)), null, p_id);
end $$;
create or replace function public.staff_penalty(p_id uuid, p_employee uuid, p_amount bigint, p_note text default null) returns uuid
language plpgsql security definer set search_path = public as $$
declare e uuid;
begin
  perform public.ledger_require(array['owner']::public.app_role[]);
  e := public.ledger_idem(p_id);
  if e is not null then return e; end if;
  if nullif(trim(p_note), '') is null then raise exception 'E_REASON_REQUIRED'; end if;
  perform public.ledger_amount(p_amount);
  perform public.ledger_employee(p_employee);
  return public.ledger_post('penalty', p_id, p_note, jsonb_build_array(
    public.ledger_line(public.ledger_acc('salaries_payable'), p_amount, 0, 'employee', p_employee),
    public.ledger_line(public.ledger_acc('exp_salaries'), 0, p_amount)), null, p_id);
end $$;
revoke execute on function public.staff_bonus(uuid, uuid, bigint, text), public.staff_penalty(uuid, uuid, bigint, text) from public, anon;
grant execute on function public.staff_bonus(uuid, uuid, bigint, text), public.staff_penalty(uuid, uuid, bigint, text) to authenticated;

-- تقرير العمولات لكل فني في الفترة (من القيود، مش متخزّن): الأجهزة، والعمولات، والمكافآت، والجزاءات، والمصروف، والرصيد الحالي
create or replace function public.commissions_report(p_from timestamptz, p_to timestamptz)
returns table(technician_id uuid, full_name text, devices bigint, commission bigint, bonus bigint, penalty bigint, paid bigint, balance bigint)
language plpgsql stable security definer set search_path = public as $$
begin
  perform public.ledger_require(array['owner']::public.app_role[]);
  return query
  with l as (
    select jl.party_id pid, e.source_type st, e.reverses_id, e.id eid, e.device_id dev, e.occurred_at occ, jl.debit, jl.credit
    from public.journal_lines jl join public.journal_entries e on e.id = jl.entry_id join public.accounts a on a.id = jl.account_id
    where jl.shop_id = public.current_shop_id() and a.code = 'salaries_payable' and jl.party_type = 'employee'
  ), rev as (
    -- العكس بيتحسب على نوع القيد الأصلي
    select l.*, coalesce(o.source_type, l.st) kind from l left join public.journal_entries o on o.id = l.reverses_id
  )
  select p.id, p.full_name,
    (select count(distinct r.dev) from rev r where r.pid = p.id and r.kind = 'commission' and r.reverses_id is null and r.occ >= p_from and r.occ < p_to)::bigint,
    coalesce(sum(case when r.kind = 'commission' and r.occ >= p_from and r.occ < p_to then r.credit - r.debit end), 0)::bigint,
    coalesce(sum(case when r.kind = 'bonus' and r.occ >= p_from and r.occ < p_to then r.credit - r.debit end), 0)::bigint,
    coalesce(sum(case when r.kind = 'penalty' and r.occ >= p_from and r.occ < p_to then r.debit - r.credit end), 0)::bigint,
    coalesce(sum(case when r.kind = 'salary_payment' and r.occ >= p_from and r.occ < p_to then r.debit - r.credit end), 0)::bigint,
    coalesce(sum(r.credit - r.debit), 0)::bigint
  from public.profiles p
  left join rev r on r.pid = p.id
  where p.shop_id = public.current_shop_id() and p.role = 'technician'
  group by p.id, p.full_name
  order by 4 desc, p.full_name;
end $$;
revoke execute on function public.commissions_report(timestamptz, timestamptz) from public, anon;
grant execute on function public.commissions_report(timestamptz, timestamptz) to authenticated;

-- النسخة الاحتياطية والاسترجاع: (src: 0048) + commission_rules
create or replace function public.backup_snapshot(p_shop uuid) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare
  res jsonb := jsonb_build_object('format', 'warsha-backup', 'version', 1, 'generated_at', now(), 'shop_id', p_shop);
  t text;
  rows jsonb;
begin
  foreach t in array array['shops', 'branches', 'staff_branches', 'shop_branding', 'profiles', 'customers', 'devices', 'device_costs', 'status_log', 'device_notes', 'device_photos', 'device_checks',
                           'quote_decisions', 'message_templates', 'message_log', 'accounts', 'journal_entries', 'journal_lines', 'payments', 'drawer_closings',
                           'suppliers', 'items', 'stock_moves', 'uncosted_sales', 'payment_plans', 'plan_installments', 'branch_goals', 'printers', 'print_templates', 'check_templates', 'used_devices', 'commission_rules', 'purchases', 'labor_rates', 'specialties', 'staff_specialties', 'routes', 'repair_steps',
                           'repair_videos', 'device_ratings', 'issue_presets', 'partners', 'profit_distributions', 'party_links', 'shop_lists', 'audit_log'] loop
    execute format('select coalesce(jsonb_agg(to_jsonb(x)), ''[]''::jsonb) from public.%I x where x.shop_id = $1', t) into rows using p_shop;
    res := res || jsonb_build_object(t, rows);
  end loop;
  select coalesce(jsonb_agg(jsonb_build_object('device_id', device_id, 'kind', kind, 'erased_at', erased_at)), '[]'::jsonb)
    into rows from public.device_passcodes where shop_id = p_shop;
  return res || jsonb_build_object('device_passcodes', rows);
end $$;

-- restore_backup: (src: 0048_used.sql) + commission_rules
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
                       'issue_presets', 'commission_rules', 'shop_lists', 'message_templates', 'items', 'devices', 'device_costs', 'status_log', 'device_notes', 'device_checks',
                       'quote_decisions', 'repair_steps', 'repair_videos', 'device_ratings', 'journal_entries', 'journal_lines', 'profit_distributions', 'payments',
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
