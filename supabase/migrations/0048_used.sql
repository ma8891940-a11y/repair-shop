-- 0048: C4: الأجهزة المستعملة: شراء وبيع بالـ IMEI، وبيانات البائع (لصاحب المحل بس)، وربح كل جهاز.
-- الجهاز المستعمل = صنف في المخزون نوعه 'used' وكميته 1 بتكلفته هو. فالشراء قيد متوازن (مخزون ← الخزنة)،
-- والبيع بـ record_sale نفسها (تكلفة البضاعة المباعة بتطلع لوحدها)، والربح = سعر البيع − سعر الشرا.
-- البيع من شاشة المستعمل بس (عشان سعر الجهاز يتسجل عليه)، وما ينفعش يتباع مرتين ولا يبقى رصيده أكتر من 1.
-- رقم البطاقة في Vault (مشفّر)، وصورة البطاقة في Storage خاص، والاتنين لصاحب المحل بس، وكل فتح بيتسجل.

alter table public.items drop constraint items_kind_check;
alter table public.items add constraint items_kind_check check (kind in ('part', 'accessory', 'used'));

create table public.used_devices (
  id uuid primary key,
  shop_id uuid not null references public.shops(id),
  branch_id uuid references public.branches(id),
  item_id uuid not null unique references public.items(id),
  imei text not null check (imei ~ '^[0-9]{14,17}$'),
  brand text not null check (length(trim(brand)) between 1 and 60),
  model text not null check (length(trim(model)) between 1 and 80),
  storage text check (storage is null or length(storage) <= 30),
  color text check (color is null or length(color) <= 30),
  condition text check (condition is null or length(condition) <= 500),
  buy_price bigint not null check (buy_price > 0 and buy_price <= 2000000000),
  buy_entry uuid not null references public.journal_entries(id),
  seller_name text not null check (length(trim(seller_name)) between 2 and 120),
  seller_phone text check (seller_phone is null or seller_phone ~ '^[0-9+]{7,16}$'),
  seller_nid_secret uuid,
  seller_photo text check (seller_photo is null or length(seller_photo) <= 300),
  sold_entry uuid references public.journal_entries(id),
  sold_price bigint check (sold_price is null or sold_price >= 0),
  sold_customer uuid references public.customers(id),
  sold_at timestamptz,
  created_by uuid references public.profiles(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);
create index used_devices_imei on public.used_devices(shop_id, imei);
alter table public.used_devices enable row level security;
create trigger set_updated_at before update on public.used_devices for each row execute function public.tg_set_updated_at();
create trigger block_delete before delete on public.used_devices for each row execute function public.tg_block_delete();
create trigger zz_audit after insert or update on public.used_devices for each row execute function public.tg_audit();
-- مفيش قراية مباشرة للجدول (فيه بيانات البائع): القايمة من used_devices_list والبيانات من seller_info

-- صنف مستعمل: الرصيد ما بيخرجش برا 0..1، والبيع من البيع العادي ممنوع (لازم من شاشة المستعمل)
create or replace function public.tg_used_stock() returns trigger
language plpgsql security definer set search_path = public as $$
declare k text; total bigint;
begin
  select kind into k from public.items where id = new.item_id;
  if k is distinct from 'used' then return new; end if;
  if new.qty < 0 and current_setting('app.uncosted', true) = 'on' and current_setting('app.used_sale', true) is distinct from 'on' then
    raise exception 'E_USED_SELL_HERE';
  end if;
  select coalesce(sum(qty), 0) into total from public.stock_moves where item_id = new.item_id;
  if total < 0 or total > 1 then raise exception 'E_STOCK'; end if;
  return new;
end $$;
create constraint trigger zz_used_stock after insert on public.stock_moves deferrable initially immediate
  for each row execute function public.tg_used_stock();

-- شراء جهاز مستعمل (اللي معاه صلاحية المشتريات)
create or replace function public.buy_used_device(p_id uuid, p_device jsonb, p_cashbox uuid, p_seller jsonb, p_note text default null)
returns uuid
language plpgsql security definer set search_path = public, extensions, pg_temp as $$
declare
  s uuid := public.current_shop_id();
  e uuid;
  it uuid := gen_random_uuid();
  v_imei text := regexp_replace(coalesce(p_device ->> 'imei', ''), '[^0-9]', '', 'g');
  cost bigint := (p_device ->> 'buy_price')::bigint;
  ask bigint := nullif(p_device ->> 'sale_price', '')::bigint;
  nid text := nullif(regexp_replace(coalesce(p_seller ->> 'nid', ''), '[^0-9]', '', 'g'), '');
  sec uuid;
  b uuid;
begin
  perform public.grant_require('purchases', 'add');
  e := public.ledger_idem(p_id);
  if e is not null then return e; end if;
  if length(v_imei) not between 14 and 17 then raise exception 'E_BAD_IMEI'; end if;
  if cost is null or cost <= 0 then raise exception 'E_BAD_AMOUNT'; end if;
  if ask is not null and (ask < 0 or ask > 2000000000) then raise exception 'E_BAD_AMOUNT'; end if;
  if nid is not null and length(nid) <> 14 then raise exception 'E_BAD_NID'; end if;
  if nullif(trim(p_seller ->> 'name'), '') is null then raise exception 'E_BAD_INPUT'; end if;
  -- نفس الجهاز لسه في المخزون؟
  if exists (select 1 from public.used_devices u join public.stock_moves m on m.item_id = u.item_id
             where u.shop_id = s and u.imei = v_imei and u.deleted_at is null group by u.id having sum(m.qty) > 0) then
    raise exception 'E_USED_IN_STOCK';
  end if;
  perform public.ledger_amount(cost);
  insert into public.items(id, shop_id, kind, name, sku, sale_price)
  values (it, s, 'used', left(trim(p_device ->> 'brand') || ' ' || trim(p_device ->> 'model') || ' · ' || right(v_imei, 4), 160), v_imei, ask);
  e := public.ledger_post('purchase', p_id, p_note, jsonb_build_array(
    public.ledger_line(public.ledger_acc('inventory'), cost, 0),
    public.ledger_line((public.ledger_cashbox(p_cashbox)).id, 0, cost)), null, p_id);
  select branch_id into b from public.journal_entries where id = e;
  insert into public.stock_moves(shop_id, item_id, entry_id, qty, value, branch_id) values (s, it, e, 1, cost, b);
  if nid is not null then sec := vault.create_secret(nid, 'used-seller-' || p_id::text, 'رقم بطاقة بائع جهاز مستعمل'); end if;
  insert into public.used_devices(id, shop_id, branch_id, item_id, imei, brand, model, storage, color, condition, buy_price, buy_entry,
                                  seller_name, seller_phone, seller_nid_secret, created_by)
  values (p_id, s, b, it, v_imei, trim(p_device ->> 'brand'), trim(p_device ->> 'model'), nullif(trim(p_device ->> 'storage'), ''), nullif(trim(p_device ->> 'color'), ''),
          nullif(trim(p_device ->> 'condition'), ''), cost, e, trim(p_seller ->> 'name'), nullif(regexp_replace(coalesce(p_seller ->> 'phone', ''), '[^0-9+]', '', 'g'), ''), sec, auth.uid());
  return e;
end $$;
revoke execute on function public.buy_used_device(uuid, jsonb, uuid, jsonb, text) from public, anon;
grant execute on function public.buy_used_device(uuid, jsonb, uuid, jsonb, text) to authenticated;

-- بيع جهاز مستعمل (من شاشة المستعمل): نفس البيع العادي بسطر واحد، وسعره بيتسجل على الجهاز
create or replace function public.sell_used_device(p_id uuid, p_used uuid, p_price bigint, p_cashbox uuid default null, p_customer uuid default null, p_note text default null)
returns uuid
language plpgsql security definer set search_path = public as $$
declare u public.used_devices; e uuid;
begin
  select * into u from public.used_devices where id = p_used and shop_id = public.current_shop_id() and deleted_at is null for update;
  if not found then raise exception 'E_NOT_FOUND'; end if;
  e := public.ledger_idem(p_id);
  if e is not null then return e; end if;
  perform set_config('app.used_sale', 'on', true);
  e := public.record_sale(p_id, jsonb_build_array(jsonb_build_object('item', u.item_id, 'qty', 1, 'price', p_price)), p_cashbox, p_customer, p_note);
  perform set_config('app.used_sale', 'off', true);
  update public.used_devices set sold_entry = e, sold_price = p_price, sold_customer = p_customer, sold_at = now() where id = u.id;
  return e;
end $$;
revoke execute on function public.sell_used_device(uuid, uuid, bigint, uuid, uuid, text) from public, anon;
grant execute on function public.sell_used_device(uuid, uuid, bigint, uuid, uuid, text) to authenticated;

-- القايمة: الحالة من المخزون والقيود (مش متخزّنة)، والربح لصاحب المحل واللي معاه "مبالغ المخزون"
create or replace function public.used_devices_list()
returns table(id uuid, item_id uuid, imei text, brand text, model text, storage text, color text, condition text, branch_id uuid,
              status text, bought_at timestamptz, buy_price bigint, sale_price integer, sold_price bigint, sold_at timestamptz, profit bigint, has_seller_id boolean)
language plpgsql stable security definer set search_path = public as $$
declare amounts boolean := public.current_app_role() = 'owner' or public.has_perm('inventory', 'amounts');
begin
  if public.current_app_role() is null or public.current_app_role() = 'technician' then raise exception 'E_FORBIDDEN'; end if;
  return query
  select u.id, u.item_id, u.imei, u.brand, u.model, u.storage, u.color, u.condition, u.branch_id,
    case when q.qty > 0 then 'in_stock'
         when u.sold_entry is not null and not exists (select 1 from public.journal_entries r where r.reverses_id = u.sold_entry) then 'sold'
         else 'cancelled' end,
    u.created_at,
    case when amounts then u.buy_price end,
    i.sale_price,
    u.sold_price,
    u.sold_at,
    case when amounts and u.sold_price is not null and q.qty = 0 and not exists (select 1 from public.journal_entries r where r.reverses_id = u.sold_entry) then u.sold_price - u.buy_price end,
    u.seller_nid_secret is not null or u.seller_photo is not null
  from public.used_devices u
  join public.items i on i.id = u.item_id
  cross join lateral (select coalesce(sum(m.qty), 0)::bigint qty from public.stock_moves m where m.item_id = u.item_id) q
  where u.shop_id = public.current_shop_id() and u.deleted_at is null and (public.all_my_branches() or public.can_branch(u.branch_id))
  order by u.created_at desc;
end $$;
revoke execute on function public.used_devices_list() from public, anon;
grant execute on function public.used_devices_list() to authenticated;

-- بيانات البائع: صاحب المحل بس، وكل فتح بيتسجل في سجل النشاط
create or replace function public.seller_info(p_used uuid)
returns table(seller_name text, seller_phone text, nid text, photo text)
language plpgsql security definer set search_path = public as $$
declare u public.used_devices;
begin
  perform public.ledger_require(array['owner']::public.app_role[]);
  select * into u from public.used_devices where id = p_used and shop_id = public.current_shop_id() and deleted_at is null;
  if not found then raise exception 'E_NOT_FOUND'; end if;
  insert into public.audit_log(shop_id, actor_id, action, entity, entity_id, after)
  values (u.shop_id, auth.uid(), 'seller_viewed', 'used_devices', u.id, '{}'::jsonb);
  return query select u.seller_name, u.seller_phone,
    (select d.decrypted_secret::text from vault.decrypted_secrets d where d.id = u.seller_nid_secret), u.seller_photo;
end $$;
revoke execute on function public.seller_info(uuid) from public, anon;
grant execute on function public.seller_info(uuid) to authenticated;

-- صورة البطاقة: مسار في Storage تحت فولدر الجهاز، واللي اشترى الجهاز أو صاحب المحل بيسجلها مرة واحدة
create or replace function public.set_seller_photo(p_used uuid, p_path text) returns void
language plpgsql security definer set search_path = public as $$
declare u public.used_devices;
begin
  select * into u from public.used_devices where id = p_used and shop_id = public.current_shop_id() and deleted_at is null for update;
  if not found then raise exception 'E_NOT_FOUND'; end if;
  if u.created_by is distinct from auth.uid() and public.current_app_role() <> 'owner' then raise exception 'E_FORBIDDEN'; end if;
  if u.seller_photo is not null then raise exception 'E_RECEIPT_IMMUTABLE'; end if;
  if p_path not like u.shop_id::text || '/' || u.id::text || '/%' then raise exception 'E_PHOTO_PATH'; end if;
  update public.used_devices set seller_photo = p_path where id = u.id;
end $$;
revoke execute on function public.set_seller_photo(uuid, text) from public, anon;
grant execute on function public.set_seller_photo(uuid, text) to authenticated;

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('seller-ids', 'seller-ids', false, 5242880, array['image/jpeg', 'image/png', 'image/webp'])
on conflict (id) do nothing;
-- الرفع: اللي بيشتري (صلاحية المشتريات) جوه فولدر المحل. القراية: صاحب المحل بس
create policy seller_ids_upload on storage.objects for insert to authenticated
  with check (bucket_id = 'seller-ids' and (storage.foldername(name))[1] = public.current_shop_id()::text and public.has_perm('purchases', 'add'));
create policy seller_ids_read on storage.objects for select to authenticated
  using (bucket_id = 'seller-ids' and (storage.foldername(name))[1] = public.current_shop_id()::text and public.current_app_role() = 'owner');

-- النسخة الاحتياطية والاسترجاع: (src: 0045) + used_devices (من غير رقم البطاقة وصورتها)
create or replace function public.backup_snapshot(p_shop uuid) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare
  res jsonb := jsonb_build_object('format', 'warsha-backup', 'version', 1, 'generated_at', now(), 'shop_id', p_shop);
  t text;
  rows jsonb;
begin
  foreach t in array array['shops', 'branches', 'staff_branches', 'shop_branding', 'profiles', 'customers', 'devices', 'device_costs', 'status_log', 'device_notes', 'device_photos', 'device_checks',
                           'quote_decisions', 'message_templates', 'message_log', 'accounts', 'journal_entries', 'journal_lines', 'payments', 'drawer_closings',
                           'suppliers', 'items', 'stock_moves', 'uncosted_sales', 'payment_plans', 'plan_installments', 'branch_goals', 'printers', 'print_templates', 'check_templates', 'used_devices', 'purchases', 'labor_rates', 'specialties', 'staff_specialties', 'routes', 'repair_steps',
                           'repair_videos', 'device_ratings', 'issue_presets', 'partners', 'profit_distributions', 'party_links', 'shop_lists', 'audit_log'] loop
    execute format('select coalesce(jsonb_agg(to_jsonb(x)), ''[]''::jsonb) from public.%I x where x.shop_id = $1', t) into rows using p_shop;
    res := res || jsonb_build_object(t, rows);
  end loop;
  select coalesce(jsonb_agg(jsonb_build_object('device_id', device_id, 'kind', kind, 'erased_at', erased_at)), '[]'::jsonb)
    into rows from public.device_passcodes where shop_id = p_shop;
  return res || jsonb_build_object('device_passcodes', rows);
end $$;

-- restore_backup: (src: 0045_checklists.sql) + used_devices
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
