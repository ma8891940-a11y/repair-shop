-- 0090: (50.4) نسخ القالب الثابتة: كل حفظ للقالب = نسخة ما بتتعدلش، وكل مستند ليه رقم (فاتورة صيانة، وبيع، وسند) بيتربط أول طباعة
-- بنسخة القالب وبيانات المحل وقتها (الاسم والعنوان واللوجو)، وإعادة الطباعة بنفسها. الستيكر والليبل مش وثايق.
-- بيانات المحل متخزنة مرة واحدة لكل شكل (اللوجو كبير)، والوثايق بتشاور عليها.
create table public.print_template_versions (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references public.shops(id),
  template_id uuid not null references public.print_templates(id),
  version integer not null check (version > 0),
  mode text not null,
  blocks jsonb not null,
  layout jsonb not null,
  created_by uuid references public.profiles(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  unique (template_id, version)
);
create table public.print_identities (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references public.shops(id),
  hash text not null,
  data jsonb not null check (jsonb_typeof(data) = 'object'),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  unique (shop_id, hash)
);
create table public.print_documents (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references public.shops(id),
  doc text not null check (doc in ('invoice', 'sale', 'voucher')),
  -- فاتورة الصيانة: repair_invoices، والبيع والسند: القيد
  ref_id uuid not null,
  -- null = القالب الافتراضي (مفيش قالب محفوظ وقت أول طباعة)
  version_id uuid references public.print_template_versions(id),
  identity_id uuid not null references public.print_identities(id),
  created_by uuid references public.profiles(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  unique (shop_id, doc, ref_id)
);
do $$
declare x text;
begin
  foreach x in array array['print_template_versions', 'print_identities', 'print_documents'] loop
    execute format('alter table public.%I enable row level security', x);
    -- القراية من print_document بس
    execute format('revoke all on public.%I from public, anon, authenticated', x);
    execute format('create trigger ledger_immutable before update or delete on public.%I for each row execute function public.tg_ledger_immutable()', x);
    execute format('create trigger ledger_no_truncate before truncate on public.%I for each statement execute function public.tg_ledger_immutable()', x);
  end loop;
end $$;

-- نسخة للمحتوى الحالي: آخر نسخة لو نفس المحتوى، وإلا نسخة جديدة
create or replace function public.print_template_version(p_template uuid) returns uuid
language plpgsql security definer set search_path = public as $$
declare t public.print_templates; v public.print_template_versions; r uuid;
begin
  perform pg_advisory_xact_lock(hashtextextended('print_template:' || p_template, 0));
  select * into t from public.print_templates where id = p_template;
  if not found then return null; end if;
  select * into v from public.print_template_versions where template_id = t.id order by version desc limit 1;
  if v.id is not null and (v.mode, v.blocks, v.layout) is not distinct from (t.mode, t.blocks, t.layout) then return v.id; end if;
  insert into public.print_template_versions(shop_id, template_id, version, mode, blocks, layout, created_by)
  values (t.shop_id, t.id, coalesce(v.version, 0) + 1, t.mode, t.blocks, t.layout, (select p.id from public.profiles p where p.id = auth.uid())) returning id into r;
  return r;
end $$;
create or replace function public.tg_print_template_version() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  -- الاسترجاع: النسخ راجعة بنفسها (ولو نسخة قديمة من غيرها، بتتعمل أول طباعة)
  if not public.restoring() then perform public.print_template_version(new.id); end if;
  return null;
end $$;
create trigger zz_version after insert or update of mode, blocks, layout on public.print_templates for each row execute function public.tg_print_template_version();
-- القوالب الموجودة: نسخة أولى
select public.print_template_version(id) from public.print_templates;

-- شكل المستند: أول مرة بيتجمّد (نسخة القالب وبيانات المحل)، وبعدها نفسه دايمًا
create or replace function public.print_document(p_doc text, p_ref uuid) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  s uuid := public.current_shop_id(); br uuid; iv public.repair_invoices; e public.journal_entries;
  pd public.print_documents; v public.print_template_versions; i public.print_identities; tpl uuid; ident jsonb; h text;
begin
  perform public.ledger_require(array['owner', 'reception']::public.app_role[]);
  -- نفس صلاحية المستند نفسه
  if p_doc = 'invoice' then
    select * into iv from public.repair_invoices where id = p_ref and shop_id = s;
    if not found then raise exception 'E_NOT_FOUND'; end if;
    perform public.device_require(iv.device_id, 'amounts');
    br := iv.branch_id;
  elsif p_doc in ('sale', 'voucher') then
    select * into e from public.journal_entries where id = p_ref and shop_id = s
      and case when p_doc = 'sale' then source_type = 'sale' else source_type in ('payment', 'capital', 'expense', 'supplier_payment', 'salary_payment', 'advance', 'drawing') end;
    if not found then raise exception 'E_NOT_FOUND'; end if;
    if public.current_app_role() <> 'owner' and not (public.can_branch(e.branch_id)
       and (public.has_perm('finance', 'view') or (p_doc = 'sale' and public.has_perm('sales', 'add')))) then raise exception 'E_FORBIDDEN'; end if;
    if p_doc = 'voucher' and public.private_level() < public.private_entry(e.id) then raise exception 'E_FORBIDDEN'; end if;
    br := e.branch_id;
  else
    raise exception 'E_BAD_INPUT';
  end if;

  perform pg_advisory_xact_lock(hashtextextended('print_document:' || s || ':' || p_doc || ':' || p_ref, 0));
  select * into pd from public.print_documents where shop_id = s and doc = p_doc and ref_id = p_ref;
  if pd.id is null then
    -- قالب الفرع يكسب قالب المحل
    select t.id into tpl from public.print_templates t where t.shop_id = s and t.doc = p_doc and t.is_default and t.deleted_at is null
      and (t.branch_id = br or t.branch_id is null) order by t.branch_id nulls last limit 1;
    select jsonb_build_object('name', sh.name, 'phone', coalesce(nullif(b.phone, ''), sh.phone), 'address', coalesce(nullif(b.address, ''), sh.address),
        'terms', sh.receipt_terms, 'currency', sh.currency, 'name_en', g.name_en, 'tagline', g.tagline, 'phones', coalesce(to_jsonb(g.phones), '[]'::jsonb), 'whatsapp', g.whatsapp,
        'socials', coalesce(g.socials, '{}'::jsonb), 'logo_color', g.logo_color, 'logo_thermal', g.logo_thermal, 'show_powered_by', coalesce(g.show_powered_by, false)) into ident
      from public.shops sh left join public.branches b on b.id = br and (select count(*) from public.branches z where z.shop_id = s and z.deleted_at is null) > 1
      left join public.shop_branding g on g.shop_id = sh.id and g.deleted_at is null where sh.id = s;
    h := encode(sha256(convert_to(ident::text, 'UTF8')), 'hex');
    insert into public.print_identities(shop_id, hash, data) values (s, h, ident) on conflict (shop_id, hash) do nothing;
    select * into i from public.print_identities where shop_id = s and hash = h;
    insert into public.print_documents(shop_id, doc, ref_id, version_id, identity_id, created_by)
    values (s, p_doc, p_ref, case when tpl is not null then public.print_template_version(tpl) end, i.id, auth.uid()) returning * into pd;
  else
    select * into i from public.print_identities where id = pd.identity_id;
  end if;
  select * into v from public.print_template_versions where id = pd.version_id;
  return jsonb_build_object('id', pd.id, 'first_printed_at', pd.created_at, 'shop', i.data,
    'template', case when v.id is not null then jsonb_build_object('version', v.version, 'mode', v.mode, 'blocks', v.blocks, 'layout', v.layout) end);
end $$;
revoke execute on function public.print_template_version(uuid), public.tg_print_template_version() from public, anon, authenticated;
revoke execute on function public.print_document(text, uuid) from public, anon;
grant execute on function public.print_document(text, uuid) to authenticated;

-- backup_snapshot: (src: 0081_repair_invoice.sql) + النسخ والوثايق
create or replace function public.backup_snapshot(p_shop uuid) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare
  res jsonb := jsonb_build_object('format', 'warsha-backup', 'version', 1, 'generated_at', now(), 'shop_id', p_shop);
  t text;
  rows jsonb;
begin
  foreach t in array array['shops', 'branches', 'staff_branches', 'attendance', 'shop_branding', 'profiles', 'customers', 'devices', 'device_costs', 'status_log', 'device_notes', 'device_photos', 'device_checks',
                           'quote_decisions', 'message_templates', 'message_log', 'accounts', 'journal_entries', 'journal_lines', 'repair_invoices', 'sale_lines', 'cheques', 'payments', 'drawer_closings',
                           'suppliers', 'categories', 'items', 'purchase_orders', 'purchase_order_lines', 'stock_counts', 'stock_count_lines', 'stock_moves', 'uncosted_sales', 'payment_plans', 'plan_installments', 'branch_goals', 'printers', 'print_templates', 'print_template_versions', 'print_identities', 'print_documents', 'check_templates', 'used_devices', 'commission_rules', 'purchases', 'labor_rates', 'specialties', 'staff_specialties', 'routes', 'repair_steps',
                           'repair_videos', 'device_ratings', 'issue_presets', 'partners', 'profit_distributions', 'party_links', 'shop_lists', 'audit_log'] loop
    execute format('select coalesce(jsonb_agg(to_jsonb(x)), ''[]''::jsonb) from public.%I x where x.shop_id = $1', t) into rows using p_shop;
    res := res || jsonb_build_object(t, rows);
  end loop;
  select coalesce(jsonb_agg(jsonb_build_object('device_id', device_id, 'kind', kind, 'erased_at', erased_at)), '[]'::jsonb)
    into rows from public.device_passcodes where shop_id = p_shop;
  return res || jsonb_build_object('device_passcodes', rows);
end $$;

-- restore_backup: (src: 0081_repair_invoice.sql) + النسخ والوثايق
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
                       'purchases', 'purchase_orders', 'purchase_order_lines', 'stock_counts', 'stock_count_lines', 'stock_moves', 'uncosted_sales', 'used_devices', 'payment_plans', 'plan_installments', 'branch_goals', 'printers', 'print_templates', 'print_template_versions', 'print_identities', 'print_documents', 'check_templates', 'drawer_closings', 'message_log', 'audit_log'];
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
