-- 0081: (19) فاتورة صيانة ثابتة: رقم مستقل وتاريخ إصدار لكل تسليم، والبيانات زي ما كانت وقت الإصدار.
-- - بتتعمل أول مرة الفاتورة تتطلب بعد التسليم، وبعدها نفس الفاتورة دايمًا (إعادة الطباعة ما بتغيّرش حاجة).
-- - مربوطة بقيد التسليم: لو اتلغى، الفاتورة بتبان ملغية (reversed)، والتسليم الجديد ليه رقم جديد. مرتجع الضمان بيرجع بنفس فاتورته.
-- - المبلغ والضريبة من القيد نفسه. المدفوع والباقي مش جوه الفاتورة (بيتغيّروا)، والشاشة بتقراهم لحظتها.
create table public.repair_invoices (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references public.shops(id),
  branch_id uuid not null references public.branches(id),
  device_id uuid not null references public.devices(id),
  entry_id uuid not null unique references public.journal_entries(id),
  prefix text not null default '',
  year integer not null,
  seq integer not null check (seq > 0),
  invoice_no text not null,
  issued_at timestamptz not null default now(),
  issued_by uuid references public.profiles(id),
  data jsonb not null check (jsonb_typeof(data) = 'object'),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  -- الترقيم بالبادئة مش بالفرع: بادئة اتنقلت لفرع تاني بتكمّل نفس الترقيم
  unique (shop_id, prefix, year, seq),
  unique (shop_id, invoice_no)
);
create index repair_invoices_device on public.repair_invoices(device_id);
alter table public.repair_invoices enable row level security;
revoke all on public.repair_invoices from public, anon, authenticated;
grant select on public.repair_invoices to authenticated;
create trigger set_updated_at before update on public.repair_invoices for each row execute function public.tg_set_updated_at();
create trigger block_delete before delete on public.repair_invoices for each row execute function public.tg_block_delete();
create trigger ledger_immutable before update or delete on public.repair_invoices for each row execute function public.tg_ledger_immutable();
create trigger ledger_no_truncate before truncate on public.repair_invoices for each statement execute function public.tg_ledger_immutable();
-- فيها اسم العميل والمبلغ: مبالغ الأجهزة + الجهاز نفسه باين (فرعه دلوقتي). الفني لأ. وسجل النشاط فيه الرقم بس
create policy repair_invoices_select on public.repair_invoices for select to authenticated
  using (shop_id = (select public.current_shop_id()) and (select public.current_app_role()) in ('owner', 'reception')
         and (select public.has_perm('devices', 'amounts')) and exists (select 1 from public.devices d where d.id = device_id));

-- p_issue = false: اقرا الموجودة بس (null لو لسه ما صدرتش)
create or replace function public.repair_invoice(p_device uuid, p_issue boolean default true) returns jsonb
language plpgsql security definer set search_path = public as $$
declare s uuid := public.current_shop_id(); d public.devices; e public.journal_entries; inv public.repair_invoices; y integer; n integer; pre text; gross bigint; vat bigint;
begin
  perform public.ledger_require(array['owner', 'reception']::public.app_role[]);
  select * into d from public.devices where id = p_device and shop_id = s and deleted_at is null;
  if not found then raise exception 'E_NOT_FOUND'; end if;
  perform public.device_require(d.id, 'amounts');
  if p_issue then select * into d from public.devices where id = d.id for update; end if;
  select * into e from public.journal_entries j where j.shop_id = s and j.source_type = 'delivery' and j.source_id = d.id
    and not exists (select 1 from public.journal_entries x where x.reverses_id = j.id) order by j.occurred_at desc limit 1;
  if e.id is not null then select * into inv from public.repair_invoices where entry_id = e.id; end if;
  if inv.id is null then
    if not p_issue then return null; end if;
    -- لسه ما اتسلّمش، أو اتسلّم من غير تكلفة: مفيش فاتورة
    if e.id is null then raise exception 'E_NO_INVOICE'; end if;
    -- الجهاز راجع ضمان: قطع الضمان ما تدخلش فاتورة التسليم الأول
    if d.status <> 'delivered' then raise exception 'E_NO_INVOICE'; end if;
    select coalesce(sum(l.credit), 0), coalesce(sum(l.credit) filter (where a.kind = 'tax'), 0) into gross, vat
      from public.journal_lines l join public.accounts a on a.id = l.account_id where l.entry_id = e.id and a.kind in ('revenue', 'tax');
    y := extract(year from (now() at time zone 'Africa/Cairo'))::int;
    -- رقم ورا رقم من غير فجوات ولا تكرار للبادئة والسنة
    select coalesce(b.prefix, '') into pre from public.branches b where b.id = e.branch_id;
    perform pg_advisory_xact_lock(hashtextextended('repair_invoice:' || s || ':' || pre || ':' || y, 0));
    select coalesce(max(seq), 0) + 1 into n from public.repair_invoices where shop_id = s and prefix = pre and year = y;
    insert into public.repair_invoices(shop_id, branch_id, device_id, entry_id, prefix, year, seq, invoice_no, issued_by, data)
    values (s, e.branch_id, d.id, e.id, pre, y, n, concat_ws('-', nullif(pre, ''), 'F', y, lpad(n::text, greatest(4, length(n::text)), '0')), auth.uid(), jsonb_build_object(
      'order_no', d.order_no, 'brand', d.brand, 'model', d.model, 'imei', d.imei, 'issue', d.issue, 'received_at', d.received_at, 'delivered_at', e.occurred_at, 'warranty_until', d.warranty_until,
      'customer', (select c.name from public.customers c where c.id = d.customer_id), 'phone', (select c.phone from public.customers c where c.id = d.customer_id),
      'parts', coalesce((select jsonb_agg(jsonb_build_object('name', x.name, 'qty', x.qty) order by x.name) from public.device_parts(d.id) x), '[]'::jsonb),
      'total', gross, 'vat', vat, 'net', gross - vat,
      'vat_no', case when vat > 0 then (select nullif(trim(sh.extras -> 'vat' ->> 'reg_no'), '') from public.shops sh where sh.id = s) end,
      'currency', (select sh.currency from public.shops sh where sh.id = s)))
    returning * into inv;
    insert into public.audit_log(shop_id, actor_id, action, entity, entity_id, after)
    values (s, auth.uid(), 'insert', 'repair_invoices', inv.id, jsonb_build_object('invoice_no', inv.invoice_no, 'order_no', d.order_no));
  end if;
  return inv.data || jsonb_build_object('id', inv.id, 'invoice_no', inv.invoice_no, 'issued_at', inv.issued_at, 'branch_id', inv.branch_id, 'device_id', inv.device_id);
end $$;
revoke execute on function public.repair_invoice(uuid, boolean) from public, anon;
grant execute on function public.repair_invoice(uuid, boolean) to authenticated;

-- كل فواتير الجهاز (والملغي منها باين)
create or replace function public.repair_invoices_of(p_device uuid) returns jsonb
language plpgsql stable security definer set search_path = public as $$
begin
  perform public.ledger_require(array['owner', 'reception']::public.app_role[]);
  if not exists (select 1 from public.devices where id = p_device and shop_id = public.current_shop_id()) then raise exception 'E_NOT_FOUND'; end if;
  perform public.device_require(p_device, 'amounts');
  return coalesce((select jsonb_agg(v.data || jsonb_build_object('id', v.id, 'invoice_no', v.invoice_no, 'issued_at', v.issued_at,
      'reversed', exists (select 1 from public.journal_entries x where x.reverses_id = v.entry_id)) order by v.issued_at, v.seq)
    from public.repair_invoices v where v.device_id = p_device), '[]'::jsonb);
end $$;
revoke execute on function public.repair_invoices_of(uuid) from public, anon;
grant execute on function public.repair_invoices_of(uuid) to authenticated;

-- backup_snapshot: (src: 0080_stock_count.sql) + فواتير الصيانة
create or replace function public.backup_snapshot(p_shop uuid) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare
  res jsonb := jsonb_build_object('format', 'warsha-backup', 'version', 1, 'generated_at', now(), 'shop_id', p_shop);
  t text;
  rows jsonb;
begin
  foreach t in array array['shops', 'branches', 'staff_branches', 'attendance', 'shop_branding', 'profiles', 'customers', 'devices', 'device_costs', 'status_log', 'device_notes', 'device_photos', 'device_checks',
                           'quote_decisions', 'message_templates', 'message_log', 'accounts', 'journal_entries', 'journal_lines', 'repair_invoices', 'sale_lines', 'cheques', 'payments', 'drawer_closings',
                           'suppliers', 'categories', 'items', 'purchase_orders', 'purchase_order_lines', 'stock_counts', 'stock_count_lines', 'stock_moves', 'uncosted_sales', 'payment_plans', 'plan_installments', 'branch_goals', 'printers', 'print_templates', 'check_templates', 'used_devices', 'commission_rules', 'purchases', 'labor_rates', 'specialties', 'staff_specialties', 'routes', 'repair_steps',
                           'repair_videos', 'device_ratings', 'issue_presets', 'partners', 'profit_distributions', 'party_links', 'shop_lists', 'audit_log'] loop
    execute format('select coalesce(jsonb_agg(to_jsonb(x)), ''[]''::jsonb) from public.%I x where x.shop_id = $1', t) into rows using p_shop;
    res := res || jsonb_build_object(t, rows);
  end loop;
  select coalesce(jsonb_agg(jsonb_build_object('device_id', device_id, 'kind', kind, 'erased_at', erased_at)), '[]'::jsonb)
    into rows from public.device_passcodes where shop_id = p_shop;
  return res || jsonb_build_object('device_passcodes', rows);
end $$;

-- restore_backup: (src: 0080_stock_count.sql) + فواتير الصيانة
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
                       'quote_decisions', 'repair_steps', 'repair_videos', 'device_ratings', 'journal_entries', 'journal_lines', 'repair_invoices', 'sale_lines', 'cheques', 'profit_distributions', 'payments',
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
     or exists (select 1 from public.stock_counts where shop_id = s and status = 'open')
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
