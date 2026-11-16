-- 0057: K: تصفح التصنيفات (طلب صاحب المشروع بفيديو 2026-11-16، بتصميم البرنامج نفسه من غير نسخ):
-- تصنيفات بمستويين (رئيسي وفرعي) في قسمين: المنتجات والخدمات، لكل تصنيف أيقونة من أيقونات البرنامج وترتيب.
-- كل صنف ممكن يتربط بتصنيف (items.category_id)، والتصنيفات النصية القديمة بتتحول لوحدها لتصنيفات (من غير ما حاجة تضيع)،
-- والنص القديم بيفضل متزامن عشان الفلاتر والتقارير القديمة.
-- الخدمات (فحص، تنظيف، سوفت وير، نقل بيانات...) = صنف نوعه 'service': بيتباع من غير مخزون ولا تكلفة، وإيراده "إيراد الصيانة".

create table public.categories (
  id uuid primary key,
  shop_id uuid not null references public.shops(id),
  parent_id uuid references public.categories(id),
  section text not null default 'products' check (section in ('products', 'services')),
  name text not null check (length(trim(name)) between 1 and 60),
  icon text check (icon is null or icon ~ '^[a-z0-9_]{1,30}$'),
  sort integer not null default 100,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);
create index categories_shop on public.categories(shop_id, parent_id) where deleted_at is null;
create unique index categories_name on public.categories(shop_id, coalesce(parent_id, '00000000-0000-0000-0000-000000000000'::uuid), lower(trim(name))) where deleted_at is null;
alter table public.categories enable row level security;
create trigger set_updated_at before update on public.categories for each row execute function public.tg_set_updated_at();
create trigger block_delete before delete on public.categories for each row execute function public.tg_block_delete();
create trigger a_force_shop_id before insert or update on public.categories for each row execute function public.tg_force_shop_id();
create trigger zz_audit after insert or update on public.categories for each row execute function public.tg_audit();
create policy categories_select on public.categories for select to authenticated using (shop_id = public.current_shop_id());
-- إضافة وتعديل التصنيفات: صاحب المحل، واللي معاه "إضافة صنف جديد"
create policy categories_insert on public.categories for insert to authenticated
  with check (shop_id = public.current_shop_id() and (public.current_app_role() = 'owner' or public.has_perm('item_create', 'add')));
create policy categories_update on public.categories for update to authenticated
  using (shop_id = public.current_shop_id() and (public.current_app_role() = 'owner' or public.has_perm('item_create', 'add')));
grant select, insert, update on public.categories to authenticated;

-- مستويين بس، والفرعي في نفس قسم الرئيسي ونفس المحل
create or replace function public.tg_category_tree() returns trigger
language plpgsql security definer set search_path = public as $$
declare p public.categories;
begin
  if new.parent_id is null then return new; end if;
  if new.parent_id = new.id then raise exception 'E_BAD_INPUT'; end if;
  select * into p from public.categories where id = new.parent_id;
  if p.id is null or p.shop_id <> new.shop_id or p.deleted_at is not null then raise exception 'E_NOT_FOUND'; end if;
  if p.parent_id is not null then raise exception 'E_CATEGORY_DEPTH'; end if;
  new.section := p.section;
  return new;
end $$;
create trigger b_category_tree before insert or update on public.categories for each row execute function public.tg_category_tree();

-- التصنيف اللي فيه أصناف أو تصنيفات فرعية ما بيتأرشفش (انقل اللي فيه الأول)
create or replace function public.tg_category_archive() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if new.deleted_at is not null and old.deleted_at is null then
    if exists (select 1 from public.categories c where c.parent_id = new.id and c.deleted_at is null)
       or exists (select 1 from public.items i where i.category_id = new.id and i.deleted_at is null) then
      raise exception 'E_CATEGORY_NOT_EMPTY';
    end if;
  end if;
  return new;
end $$;
create trigger c_category_archive before update on public.categories for each row execute function public.tg_category_archive();

-- الأصناف: التصنيف والخدمة
alter table public.items add column if not exists category_id uuid references public.categories(id);
alter table public.items drop constraint items_kind_check;
alter table public.items add constraint items_kind_check check (kind in ('part', 'accessory', 'used', 'service'));

-- اسم التصنيف بيتنسخ في النص القديم (الفلاتر والتصدير والتقارير)
-- والعكس: صنف بتصنيف نصي بس (الاستيراد من Excel، أو البرامج القديمة) بيتربط بتصنيف بنفس الاسم، ولو مش موجود بيتعمل تصنيف رئيسي
create or replace function public.tg_item_category_text() returns trigger
language plpgsql security definer set search_path = public as $$
declare cid uuid;
begin
  if new.category_id is not null and (tg_op = 'INSERT' or new.category_id is distinct from old.category_id) then
    select c.name into new.category from public.categories c where c.id = new.category_id and c.shop_id = new.shop_id;
    if new.category is null then raise exception 'E_NOT_FOUND'; end if;
  elsif new.category_id is null and nullif(trim(new.category), '') is not null
        and (tg_op = 'INSERT' or new.category is distinct from old.category) and not public.restoring() then
    select c.id into cid from public.categories c
     where c.shop_id = new.shop_id and c.deleted_at is null and lower(trim(c.name)) = lower(trim(new.category))
     order by (c.parent_id is null), c.created_at limit 1;
    if cid is null then
      cid := gen_random_uuid();
      insert into public.categories(id, shop_id, name, icon) values (cid, new.shop_id, left(trim(new.category), 60), 'box');
    end if;
    new.category_id := cid;
    new.category := trim(new.category);
  end if;
  return new;
end $$;
create trigger b_item_category_text before insert or update of category_id, category on public.items for each row execute function public.tg_item_category_text();
create or replace function public.tg_category_rename() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if new.name is distinct from old.name then
    perform set_config('warsha.system', 'on', true);
    update public.items set category = new.name where category_id = new.id;
    perform set_config('warsha.system', 'off', true);
  end if;
  return new;
end $$;
create trigger d_category_rename after update of name on public.categories for each row execute function public.tg_category_rename();

-- نقل البيانات: كل تصنيف نصي قديم (في الأصناف أو في قايمة "تصنيفات الأصناف") بقى تصنيف رئيسي، والأصناف اتربطت بيه
create or replace function public.categories_from_text() returns integer
language plpgsql security definer set search_path = public as $mig$
declare r record; cid uuid; n int := 0;
begin
  perform set_config('warsha.restore', 'on', true);
  perform set_config('warsha.system', 'on', true);
  for r in
    select distinct x.shop_id, trim(x.name) as name from (
      select shop_id, category as name from public.items where category is not null and length(trim(category)) > 0 and deleted_at is null
      union select shop_id, value from public.shop_lists where list = 'item_categories' and deleted_at is null
    ) x
  loop
    select id into cid from public.categories c where c.shop_id = r.shop_id and c.parent_id is null and lower(trim(c.name)) = lower(r.name) and c.deleted_at is null;
    if cid is null then
      cid := gen_random_uuid();
      insert into public.categories(id, shop_id, name, icon) values (cid, r.shop_id, left(r.name, 60), 'box');
      n := n + 1;
    end if;
    update public.items set category_id = cid where shop_id = r.shop_id and category_id is null and lower(trim(category)) = lower(r.name);
  end loop;
  perform set_config('warsha.restore', 'off', true);
  perform set_config('warsha.system', 'off', true);
  return n;
end $mig$;
revoke execute on function public.categories_from_text() from public, anon, authenticated;
select public.categories_from_text();

-- الشجرة بالعدد: الأصناف (وأصناف الفرعي جوه الرئيسي)، واللي متوفر منها في الفرع (أو كل الفروع)
create or replace function public.category_tree(p_branch uuid default null)
returns table(id uuid, parent_id uuid, section text, name text, icon text, sort integer, items bigint, in_stock bigint)
language plpgsql stable security definer set search_path = public as $$
#variable_conflict use_column
declare s uuid := public.current_shop_id();
begin
  if s is null then raise exception 'E_FORBIDDEN'; end if;
  return query
  with st as (
    select m.item_id, sum(m.qty) q from public.stock_moves m
    where m.shop_id = s and (p_branch is null or m.branch_id = p_branch) and (public.all_my_branches() or public.can_branch(m.branch_id))
    group by m.item_id
  ), it as (
    select i.id, i.category_id, (i.kind = 'service' or coalesce(st.q, 0) > 0) avail
    from public.items i left join st on st.item_id = i.id
    where i.shop_id = s and i.deleted_at is null and i.category_id is not null
      and (i.kind <> 'used' or coalesce(st.q, 0) > 0)
  )
  select c.id, c.parent_id, c.section, c.name, c.icon, c.sort,
    (select count(*) from it where it.category_id = c.id or it.category_id in (select k.id from public.categories k where k.parent_id = c.id and k.deleted_at is null))::bigint,
    (select count(*) from it where it.avail and (it.category_id = c.id or it.category_id in (select k.id from public.categories k where k.parent_id = c.id and k.deleted_at is null)))::bigint
  from public.categories c
  where c.shop_id = s and c.deleted_at is null
  order by c.section, c.parent_id nulls first, c.sort, c.name;
end $$;
revoke execute on function public.category_tree(uuid) from public, anon;
grant execute on function public.category_tree(uuid) to authenticated;

-- ترتيب التصنيفات بالسحب (صاحب المحل)
create or replace function public.reorder_categories(p_ids uuid[]) returns void
language plpgsql security definer set search_path = public as $$
declare i int;
begin
  perform public.ledger_require(array['owner']::public.app_role[]);
  if coalesce(array_length(p_ids, 1), 0) > 200 then raise exception 'E_BAD_INPUT'; end if;
  for i in 1 .. coalesce(array_length(p_ids, 1), 0) loop
    update public.categories set sort = i * 10 where id = p_ids[i] and shop_id = public.current_shop_id();
  end loop;
end $$;
revoke execute on function public.reorder_categories(uuid[]) from public, anon;
grant execute on function public.reorder_categories(uuid[]) to authenticated;

-- التصنيفات الجاهزة (اختياري، صاحب المحل): بتتضاف بس لو اسمها مش موجود
create or replace function public.seed_categories(p_tree jsonb) returns integer
language plpgsql security definer set search_path = public as $$
declare s uuid := public.current_shop_id(); top jsonb; sub jsonb; tid uuid; n int := 0; i int := 0; j int;
begin
  perform public.ledger_require(array['owner']::public.app_role[]);
  if jsonb_typeof(p_tree) <> 'array' or jsonb_array_length(p_tree) > 30 then raise exception 'E_BAD_INPUT'; end if;
  for top in select * from jsonb_array_elements(p_tree) loop
    i := i + 1;
    select id into tid from public.categories where shop_id = s and parent_id is null and lower(trim(name)) = lower(trim(top ->> 'name')) and deleted_at is null;
    if tid is null then
      tid := gen_random_uuid();
      insert into public.categories(id, shop_id, section, name, icon, sort) values (tid, s, coalesce(top ->> 'section', 'products'), top ->> 'name', top ->> 'icon', i * 10);
      n := n + 1;
    end if;
    j := 0;
    for sub in select * from jsonb_array_elements(coalesce(top -> 'children', '[]'::jsonb)) loop
      j := j + 1;
      if jsonb_array_length(coalesce(top -> 'children', '[]'::jsonb)) > 60 then raise exception 'E_BAD_INPUT'; end if;
      if not exists (select 1 from public.categories where shop_id = s and parent_id = tid and lower(trim(name)) = lower(trim(sub ->> 'name')) and deleted_at is null) then
        insert into public.categories(id, shop_id, parent_id, name, icon, sort) values (gen_random_uuid(), s, tid, sub ->> 'name', sub ->> 'icon', j * 10);
        n := n + 1;
      end if;
    end loop;
  end loop;
  return n;
end $$;
revoke execute on function public.seed_categories(jsonb) from public, anon;
grant execute on function public.seed_categories(jsonb) to authenticated;

-- create_item: (src: 0038_roles_grant.sql) + الخدمة
create or replace function public.create_item(
  p_id uuid, p_kind text, p_name text, p_item_type text default null, p_brand text default null, p_model text default null,
  p_quality text default null, p_color text default null, p_sale_price integer default null, p_qty integer default null, p_unit_cost bigint default null,
  p_stock_id uuid default null
) returns uuid
language plpgsql security definer set search_path = public as $$
declare s uuid := public.current_shop_id(); nm text := trim(coalesce(p_name, ''));
begin
  perform public.ledger_require(array['owner', 'reception']::public.app_role[]);
  perform public.perm_require('item_create', 'add');
  if exists (select 1 from public.items where id = p_id and shop_id = s) then return p_id; end if;
  if p_kind not in ('part', 'accessory', 'service') or nm = '' or length(nm) > 160 then raise exception 'E_BAD_INPUT'; end if;
  if p_sale_price is not null and (p_sale_price < 0 or p_sale_price > 2000000000) then raise exception 'E_BAD_AMOUNT'; end if;
  insert into public.items(id, shop_id, kind, name, item_type, brand, model, quality, color, sale_price)
  values (p_id, s, p_kind, nm, nullif(trim(p_item_type), ''), nullif(trim(p_brand), ''), nullif(trim(p_model), ''), nullif(trim(p_quality), ''), nullif(trim(p_color), ''), p_sale_price);
  if coalesce(p_qty, 0) > 0 then
    if p_unit_cost is null or p_unit_cost <= 0 then raise exception 'E_BAD_AMOUNT'; end if;
    perform public.stock_in(coalesce(p_stock_id, gen_random_uuid()), p_id, p_qty, p_unit_cost, 'stock');
  end if;
  return p_id;
end $$;

-- record_sale: (src: 0037_item_details.sql) + الخدمات
create or replace function public.record_sale(p_id uuid, p_lines jsonb, p_cashbox uuid default null, p_customer uuid default null, p_note text default null)
returns uuid
language plpgsql security definer set search_path = public as $$
declare
  s uuid := public.current_shop_id();
  e uuid := gen_random_uuid();
  l jsonb;
  it public.items;
  q bigint; p bigint; cost bigint;
  rev_parts bigint := 0; rev_acc bigint := 0; rev_srv bigint := 0; total_cost bigint := 0;
  debit_acc uuid; pt text; pid uuid;
begin
  perform public.ledger_require(array['owner', 'reception']::public.app_role[]);
  perform public.perm_require('sales', 'add');
  if public.ledger_idem(p_id) is not null then return public.ledger_idem(p_id); end if;
  -- البيع بالآجل لصاحب المحل بس
  if p_cashbox is null and (p_customer is null or public.current_app_role() <> 'owner') then raise exception 'E_BAD_INPUT'; end if;
  if p_customer is not null and not exists (select 1 from public.customers where id = p_customer and shop_id = s and deleted_at is null) then raise exception 'E_NOT_FOUND'; end if;
  if jsonb_typeof(p_lines) <> 'array' or jsonb_array_length(p_lines) = 0 then raise exception 'E_BAD_INPUT'; end if;
  insert into public.journal_entries(id, shop_id, source_type, source_id, memo, idem_key, created_by)
  values (e, s, 'sale', p_id, nullif(trim(p_note), ''), p_id, auth.uid());
  -- البيع بس: لو الإعداد مفتوح، اللي مش موجود بيخرج من غير تكلفة ويتسوى بعدين
  perform set_config('app.uncosted', 'on', true);
  for l in select * from jsonb_array_elements(p_lines) loop
    select * into it from public.items where id = (l ->> 'item')::uuid and shop_id = s and deleted_at is null;
    if not found then raise exception 'E_NOT_FOUND'; end if;
    q := (l ->> 'qty')::bigint;
    p := (l ->> 'price')::bigint;
    if q is null or q <= 0 or p is null or p < 0 then raise exception 'E_BAD_AMOUNT'; end if;
    -- K: الخدمة من غير مخزون ولا تكلفة، وإيرادها إيراد الصيانة
    if it.kind = 'service' then rev_srv := rev_srv + q * p; continue; end if;
    cost := public.ledger_issue(it.id, q, e);
    total_cost := total_cost + cost;
    if it.kind = 'part' then rev_parts := rev_parts + q * p; else rev_acc := rev_acc + q * p; end if;
  end loop;
  perform set_config('app.uncosted', 'off', true);
  perform public.ledger_amount(rev_parts + rev_acc + rev_srv);
  if p_cashbox is null then
    debit_acc := public.ledger_acc('ar'); pt := 'customer'; pid := p_customer;
  else
    debit_acc := (public.ledger_cashbox(p_cashbox)).id;
  end if;
  insert into public.journal_lines(shop_id, entry_id, account_id, party_type, party_id, debit, credit)
  values (s, e, debit_acc, pt, pid, rev_parts + rev_acc + rev_srv, 0);
  if rev_parts > 0 then insert into public.journal_lines(shop_id, entry_id, account_id, debit, credit) values (s, e, public.ledger_acc('rev_parts'), 0, rev_parts); end if;
  if rev_acc > 0 then insert into public.journal_lines(shop_id, entry_id, account_id, debit, credit) values (s, e, public.ledger_acc('rev_accessories'), 0, rev_acc); end if;
  if rev_srv > 0 then insert into public.journal_lines(shop_id, entry_id, account_id, debit, credit) values (s, e, public.ledger_acc('rev_repair'), 0, rev_srv); end if;
  if total_cost > 0 then
    insert into public.journal_lines(shop_id, entry_id, account_id, debit, credit) values
      (s, e, public.ledger_acc('cogs'), total_cost, 0), (s, e, public.ledger_acc('inventory'), 0, total_cost);
  end if;
  if p_cashbox is not null and p_customer is not null then
    null; -- البيع النقدي لعميل معروف ما بيأثرش على رصيده
  end if;
  return e;
end $$;

-- النسخة الاحتياطية والاسترجاع: (src: 0049) + categories (قبل الأصناف)
create or replace function public.backup_snapshot(p_shop uuid) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare
  res jsonb := jsonb_build_object('format', 'warsha-backup', 'version', 1, 'generated_at', now(), 'shop_id', p_shop);
  t text;
  rows jsonb;
begin
  foreach t in array array['shops', 'branches', 'staff_branches', 'shop_branding', 'profiles', 'customers', 'devices', 'device_costs', 'status_log', 'device_notes', 'device_photos', 'device_checks',
                           'quote_decisions', 'message_templates', 'message_log', 'accounts', 'journal_entries', 'journal_lines', 'payments', 'drawer_closings',
                           'suppliers', 'categories', 'items', 'stock_moves', 'uncosted_sales', 'payment_plans', 'plan_installments', 'branch_goals', 'printers', 'print_templates', 'check_templates', 'used_devices', 'commission_rules', 'purchases', 'labor_rates', 'specialties', 'staff_specialties', 'routes', 'repair_steps',
                           'repair_videos', 'device_ratings', 'issue_presets', 'partners', 'profit_distributions', 'party_links', 'shop_lists', 'audit_log'] loop
    execute format('select coalesce(jsonb_agg(to_jsonb(x)), ''[]''::jsonb) from public.%I x where x.shop_id = $1', t) into rows using p_shop;
    res := res || jsonb_build_object(t, rows);
  end loop;
  select coalesce(jsonb_agg(jsonb_build_object('device_id', device_id, 'kind', kind, 'erased_at', erased_at)), '[]'::jsonb)
    into rows from public.device_passcodes where shop_id = p_shop;
  return res || jsonb_build_object('device_passcodes', rows);
end $$;

-- restore_backup: (src: 0049_commissions.sql) + categories
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
                       'issue_presets', 'commission_rules', 'shop_lists', 'message_templates', 'categories', 'items', 'devices', 'device_costs', 'status_log', 'device_notes', 'device_checks',
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
