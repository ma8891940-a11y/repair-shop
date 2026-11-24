-- 0080: (29) الجرد الدوري لفرع: رصيد بداية الجرد، والعد صنف صنف، وكشف الفروق، والاعتماد بقيد واحد.
-- - العد لوحده ما بيعملش تسوية. الفرق = المعدود − رصيد النظام لحظة عدّ الصنف، فالبيع بعد العد ما يلخبطش الفرق.
-- - اللي ما اتعدّش ما بيتسواش. المستعمل (IMEI) والخدمات مش في الجرد.
-- - العد بصلاحية "يعدّل" في المخزون، والاعتماد بصلاحية "المبالغ" و"يحذف" (زي الهالك).
alter table public.journal_entries drop constraint if exists journal_entries_source_type_check;
alter table public.journal_entries add constraint journal_entries_source_type_check check (source_type = any (array[
  'payment', 'delivery', 'purchase', 'supplier_payment', 'part_use', 'sale', 'expense', 'salary', 'salary_payment', 'advance', 'advance_settle',
  'capital', 'drawing', 'transfer', 'drawer_close', 'reversal', 'cost_adjust', 'write_off', 'supplier_return', 'sale_return', 'opening',
  'partner_capital', 'partner_withdrawal', 'profit_distribution', 'netting', 'stock_transfer', 'commission', 'bonus', 'penalty', 'vat_payment',
  'cheque_in', 'cheque_out', 'cheque_clear', 'cheque_bounce', 'stock_count']));

create table public.stock_counts (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references public.shops(id),
  branch_id uuid not null references public.branches(id),
  status text not null default 'open' check (status in ('open', 'posted', 'cancelled')),
  note text check (note is null or length(note) <= 300),
  entry_id uuid references public.journal_entries(id),
  closed_at timestamptz,
  closed_by uuid references public.profiles(id),
  created_by uuid references public.profiles(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  check ((status = 'open') = (closed_at is null))
);
-- جرد مفتوح واحد لكل فرع
create unique index stock_counts_open on public.stock_counts(branch_id) where status = 'open' and deleted_at is null;
create table public.stock_count_lines (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references public.shops(id),
  count_id uuid not null references public.stock_counts(id),
  item_id uuid not null references public.items(id),
  opening_qty bigint not null,
  system_qty bigint,
  counted_qty bigint check (counted_qty is null or (counted_qty >= 0 and counted_qty <= 1000000)),
  counted_at timestamptz,
  counted_by uuid references public.profiles(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  unique (count_id, item_id),
  check ((counted_qty is null) = (system_qty is null))
);
do $$
declare t text;
begin
  foreach t in array array['stock_counts', 'stock_count_lines'] loop
    execute format('alter table public.%I enable row level security', t);
    execute format('revoke all on public.%I from public, anon, authenticated', t);
    execute format('grant select on public.%I to authenticated', t);
    execute format('create trigger set_updated_at before update on public.%I for each row execute function public.tg_set_updated_at()', t);
    execute format('create trigger block_delete before delete on public.%I for each row execute function public.tg_block_delete()', t);
  end loop;
end $$;
create trigger zz_audit after insert or update on public.stock_counts for each row execute function public.tg_audit();
create trigger zz_audit after update on public.stock_count_lines for each row execute function public.tg_audit();
create policy stock_counts_select on public.stock_counts for select to authenticated
  using (shop_id = (select public.current_shop_id()) and ((select public.current_app_role()) = 'owner'
         or ((select public.current_app_role()) = 'reception' and (select public.has_perm('inventory', 'edit')) and public.can_branch(branch_id))));
create policy stock_count_lines_select on public.stock_count_lines for select to authenticated
  using (shop_id = (select public.current_shop_id()) and exists (select 1 from public.stock_counts c where c.id = count_id));

-- الجرد لو الموظف ليه فرعه (والقفل عليه لو p_lock)
create or replace function public.stock_count_get(p_count uuid, p_open boolean) returns public.stock_counts
language plpgsql security definer set search_path = public as $$
declare c public.stock_counts;
begin
  select * into c from public.stock_counts where id = p_count and shop_id = public.current_shop_id() and deleted_at is null for update;
  if not found or (public.current_app_role() <> 'owner' and not public.can_branch(c.branch_id)) then raise exception 'E_NOT_FOUND'; end if;
  if p_open and c.status <> 'open' then raise exception 'E_COUNT_CLOSED'; end if;
  return c;
end $$;
revoke execute on function public.stock_count_get(uuid, boolean) from public, anon, authenticated;

create or replace function public.start_stock_count(p_id uuid, p_note text default null) returns uuid
language plpgsql security definer set search_path = public as $$
declare s uuid := public.current_shop_id(); b uuid;
begin
  perform public.grant_require('inventory', 'edit');
  perform public.ledger_idem(p_id);
  if exists (select 1 from public.stock_counts where id = p_id) then
    return (public.stock_count_get(p_id, false)).id;
  end if;
  b := public.op_branch();
  begin
    insert into public.stock_counts(id, shop_id, branch_id, note, created_by) values (p_id, s, b, left(nullif(trim(p_note), ''), 300), auth.uid());
  exception when unique_violation then raise exception 'E_COUNT_OPEN';
  end;
  insert into public.stock_count_lines(shop_id, count_id, item_id, opening_qty)
  select s, p_id, i.id, coalesce((select sum(m.qty) from public.stock_moves m where m.item_id = i.id and m.branch_id = b), 0)
  from public.items i where i.shop_id = s and i.deleted_at is null and i.kind in ('part', 'accessory');
  return p_id;
end $$;

-- p_counted = null: مسح العد. صنف اتضاف بعد بداية الجرد بيتعدّ عادي
create or replace function public.save_stock_count(p_count uuid, p_item uuid, p_counted bigint) returns void
language plpgsql security definer set search_path = public as $$
declare s uuid := public.current_shop_id(); c public.stock_counts; q bigint;
begin
  perform public.grant_require('inventory', 'edit');
  c := public.stock_count_get(p_count, true);
  if p_counted is not null and (p_counted < 0 or p_counted > 1000000) then raise exception 'E_BAD_QTY'; end if;
  -- قفل الصنف: بيع في نفس اللحظة يبقى قبل العد أو بعده
  perform 1 from public.items where id = p_item and shop_id = s and deleted_at is null and kind in ('part', 'accessory') for update;
  if not found then raise exception 'E_NOT_FOUND'; end if;
  select st.qty into q from public.item_stock_at(p_item, c.branch_id) st;
  insert into public.stock_count_lines(shop_id, count_id, item_id, opening_qty) values (s, c.id, p_item, q) on conflict (count_id, item_id) do nothing;
  update public.stock_count_lines set counted_qty = p_counted, system_qty = case when p_counted is not null then q end,
         counted_at = case when p_counted is not null then now() end, counted_by = case when p_counted is not null then auth.uid() end
  where count_id = c.id and item_id = p_item;
end $$;

create or replace function public.cancel_stock_count(p_count uuid) returns void
language plpgsql security definer set search_path = public as $$
declare c public.stock_counts;
begin
  perform public.grant_require('inventory', 'edit');
  c := public.stock_count_get(p_count, false);
  if c.status = 'cancelled' then return; end if;
  if c.status = 'posted' then raise exception 'E_COUNT_CLOSED'; end if;
  update public.stock_counts set status = 'cancelled', closed_at = now(), closed_by = auth.uid() where id = c.id;
end $$;

-- الاعتماد: النقص بيخرج بمتوسط تكلفته، والزيادة بتدخل بآخر تكلفة، والفرق في "هالك المخزون". من غير فروق: بيتقفل من غير قيد
create or replace function public.post_stock_count(p_id uuid, p_count uuid, p_reason text) returns uuid
language plpgsql security definer set search_path = public as $$
declare s uuid := public.current_shop_id(); c public.stock_counts; l record; e uuid; diff bigint; cost bigint; net bigint := 0; gross bigint := 0; n int := 0;
begin
  perform public.grant_require('inventory', 'amounts');
  perform public.grant_require('inventory', 'delete');
  e := public.ledger_idem(p_id);
  if e is not null then return e; end if;
  c := public.stock_count_get(p_count, false);
  if c.status = 'posted' then return c.entry_id; end if;
  if c.status <> 'open' then raise exception 'E_COUNT_CLOSED'; end if;
  if nullif(trim(p_reason), '') is null then raise exception 'E_REASON_REQUIRED'; end if;
  if not exists (select 1 from public.stock_count_lines where count_id = c.id and counted_qty is not null) then raise exception 'E_COUNT_EMPTY'; end if;
  if exists (select 1 from public.stock_count_lines where count_id = c.id and counted_qty <> system_qty) then
    perform set_config('app.branch', c.branch_id::text, true);
    e := gen_random_uuid();
    insert into public.journal_entries(id, shop_id, source_type, source_id, memo, idem_key, created_by, branch_id)
    values (e, s, 'stock_count', c.id, left(trim(p_reason), 300), p_id, auth.uid(), c.branch_id);
    -- بترتيب ثابت (زي أي عملية بتقفل أكتر من صنف) عشان ما يحصلش انتظار متبادل بين جردين
    for l in select * from public.stock_count_lines where count_id = c.id and counted_qty <> system_qty order by item_id loop
      perform 1 from public.items where id = l.item_id for update;
      diff := l.counted_qty - l.system_qty;
      if diff < 0 then
        cost := public.ledger_issue(l.item_id, -diff, e);
        net := net + cost;
      else
        cost := public.item_last_cost(l.item_id) * diff;
        -- زيادة في صنف تكلفته مش معروفة: بتتسجل من "تسوية مخزون" بتكلفتها
        if cost <= 0 then raise exception 'E_COUNT_COST'; end if;
        insert into public.stock_moves(shop_id, item_id, entry_id, qty, value, branch_id) values (s, l.item_id, e, diff, cost, c.branch_id);
        net := net - cost;
      end if;
      gross := gross + cost;
      n := n + 1;
    end loop;
    if gross = 0 then raise exception 'E_COUNT_COST'; end if;
    -- الزيادة والنقص كل واحد بسطره (القيد بيبان منه الاتنين حتى لو صافيهم صفر)
    if (gross + net) / 2 > 0 then
      insert into public.journal_lines(shop_id, entry_id, account_id, debit, credit) values
        (s, e, public.ledger_acc('wastage'), (gross + net) / 2, 0), (s, e, public.ledger_acc('inventory'), 0, (gross + net) / 2);
    end if;
    if (gross - net) / 2 > 0 then
      insert into public.journal_lines(shop_id, entry_id, account_id, debit, credit) values
        (s, e, public.ledger_acc('inventory'), (gross - net) / 2, 0), (s, e, public.ledger_acc('wastage'), 0, (gross - net) / 2);
    end if;
  end if;
  update public.stock_counts set status = 'posted', closed_at = now(), closed_by = auth.uid(), entry_id = e where id = c.id;
  insert into public.audit_log(shop_id, actor_id, action, entity, entity_id, after)
  values (s, auth.uid(), 'stock_count_post', 'stock_counts', c.id, jsonb_build_object('items', n, 'shortage', (gross + net) / 2, 'surplus', (gross - net) / 2, 'reason', left(trim(p_reason), 300), 'entry', e));
  return e;
end $$;

-- كشف الفروق: القيمة (بالتكلفة) لأصحاب "المبالغ" بس
create or replace function public.stock_count_sheet(p_count uuid) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare c public.stock_counts; m boolean := public.has_perm('inventory', 'amounts');
begin
  perform public.grant_require('inventory', 'edit');
  select * into c from public.stock_counts where id = p_count and shop_id = public.current_shop_id() and deleted_at is null;
  if not found or (public.current_app_role() <> 'owner' and not public.can_branch(c.branch_id)) then raise exception 'E_NOT_FOUND'; end if;
  return jsonb_build_object('id', c.id, 'branch_id', c.branch_id, 'status', c.status, 'note', c.note, 'started_at', c.created_at, 'closed_at', c.closed_at, 'entry', c.entry_id,
    'lines', coalesce((select jsonb_agg(jsonb_build_object('item', l.item_id, 'name', i.name, 'opening', l.opening_qty, 'system', l.system_qty, 'counted', l.counted_qty, 'diff', l.counted_qty - l.system_qty,
        'counted_at', l.counted_at, 'value', case when m and l.counted_qty is not null then (l.counted_qty - l.system_qty) * public.item_last_cost(l.item_id) end) order by i.name, i.id)
      from public.stock_count_lines l join public.items i on i.id = l.item_id where l.count_id = c.id), '[]'::jsonb));
end $$;
do $$
declare f text;
begin
  foreach f in array array['start_stock_count(uuid, text)', 'save_stock_count(uuid, uuid, bigint)', 'cancel_stock_count(uuid)', 'post_stock_count(uuid, uuid, text)', 'stock_count_sheet(uuid)'] loop
    execute format('revoke execute on function public.%s from public, anon', f);
    execute format('grant execute on function public.%s to authenticated', f);
  end loop;
end $$;

-- entry_section: (src: 0075_delete_by_section.sql) + قيد الجرد تبع المخزون
create or replace function public.entry_section(p_source text) returns text
language sql immutable as $$
  select case
    when p_source in ('sale', 'sale_return') then 'sales'
    when p_source in ('payment', 'transfer', 'drawer_close') then 'cashbox'
    when p_source = 'expense' then 'expenses'
    when p_source in ('purchase', 'supplier_payment', 'supplier_return') then 'purchases'
    when p_source in ('write_off', 'stock_transfer', 'stock_count') then 'inventory'
    when p_source in ('part_use', 'delivery') then 'devices'
    else 'finance' end
$$;

-- backup_snapshot: (src: 0079_purchase_orders.sql) + الجرد
create or replace function public.backup_snapshot(p_shop uuid) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare
  res jsonb := jsonb_build_object('format', 'warsha-backup', 'version', 1, 'generated_at', now(), 'shop_id', p_shop);
  t text;
  rows jsonb;
begin
  foreach t in array array['shops', 'branches', 'staff_branches', 'attendance', 'shop_branding', 'profiles', 'customers', 'devices', 'device_costs', 'status_log', 'device_notes', 'device_photos', 'device_checks',
                           'quote_decisions', 'message_templates', 'message_log', 'accounts', 'journal_entries', 'journal_lines', 'sale_lines', 'cheques', 'payments', 'drawer_closings',
                           'suppliers', 'categories', 'items', 'purchase_orders', 'purchase_order_lines', 'stock_counts', 'stock_count_lines', 'stock_moves', 'uncosted_sales', 'payment_plans', 'plan_installments', 'branch_goals', 'printers', 'print_templates', 'check_templates', 'used_devices', 'commission_rules', 'purchases', 'labor_rates', 'specialties', 'staff_specialties', 'routes', 'repair_steps',
                           'repair_videos', 'device_ratings', 'issue_presets', 'partners', 'profit_distributions', 'party_links', 'shop_lists', 'audit_log'] loop
    execute format('select coalesce(jsonb_agg(to_jsonb(x)), ''[]''::jsonb) from public.%I x where x.shop_id = $1', t) into rows using p_shop;
    res := res || jsonb_build_object(t, rows);
  end loop;
  select coalesce(jsonb_agg(jsonb_build_object('device_id', device_id, 'kind', kind, 'erased_at', erased_at)), '[]'::jsonb)
    into rows from public.device_passcodes where shop_id = p_shop;
  return res || jsonb_build_object('device_passcodes', rows);
end $$;

-- restore_backup: (src: 0079_purchase_orders.sql) + الجرد
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
                       'purchases', 'purchase_orders', 'purchase_order_lines', 'stock_counts', 'stock_count_lines', 'stock_moves', 'uncosted_sales', 'used_devices', 'payment_plans', 'plan_installments', 'branch_goals', 'printers', 'print_templates', 'check_templates', 'drawer_closings', 'message_log', 'audit_log'];
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
     or exists (select 1 from public.attendance where shop_id = s and deleted_at is null)
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
