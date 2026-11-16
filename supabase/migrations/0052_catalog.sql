-- 0052: C8: كتالوج أونلاين من المخزون (إكسسوارات وقطع وأجهزة مستعملة)، برابط عام يتشارك على واتساب وفيسبوك.
-- صاحب المحل بيفتحه (token عشوائي 128 bit) وبيختار الأصناف اللي تظهر. الكتالوج بيعرض الاسم والسعر و"متوفر" بس:
-- من غير تكلفة ولا كميات ولا IMEI ولا أي بيانات عملاء. القفل بيلغي الرابط القديم.

alter table public.shops add column if not exists catalog_token text unique check (catalog_token is null or length(catalog_token) = 32);
alter table public.items add column if not exists in_catalog boolean not null default false;

-- فتح وقفل الكتالوج (صاحب المحل): بيرجّع الـ token الجديد أو null
create or replace function public.set_catalog(p_on boolean) returns text
language plpgsql security definer set search_path = public, extensions, pg_temp as $$
declare s uuid := public.current_shop_id(); t text := case when p_on then encode(gen_random_bytes(16), 'hex') end;
begin
  perform public.ledger_require(array['owner']::public.app_role[]);
  perform set_config('warsha.system', 'on', true);
  update public.shops set catalog_token = t where id = s;
  perform set_config('warsha.system', 'off', true);
  return t;
end $$;
revoke execute on function public.set_catalog(boolean) from public, anon;
grant execute on function public.set_catalog(boolean) to authenticated;

create or replace function public.catalog_shop(p_token text) returns uuid
language sql stable security definer set search_path = public as $$
  select s.id from public.shops s where p_token is not null and length(p_token) = 32 and s.catalog_token = p_token and s.deleted_at is null and s.suspended_at is null
$$;
revoke execute on function public.catalog_shop(text) from public, anon, authenticated;

-- الكتالوج للزائر: المحل (الاسم والتليفون واللوجو الملون) والأصناف المختارة
create or replace function public.public_catalog(p_token text) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare s uuid := public.catalog_shop(p_token);
begin
  if s is null then return null; end if;
  return jsonb_build_object(
    'shop', (select jsonb_build_object('name', sh.name, 'phone', sh.phone, 'currency', sh.currency,
               'logo', (select b.logo_color from public.shop_branding b where b.shop_id = sh.id and b.deleted_at is null)) from public.shops sh where sh.id = s),
    'items', coalesce((
      select jsonb_agg(x order by x->>'kind', x->>'name') from (
        select jsonb_build_object('id', i.id, 'name', i.name, 'kind', i.kind, 'price', i.sale_price, 'image', i.image_path,
                 'in_stock', coalesce((select sum(m.qty) from public.stock_moves m where m.item_id = i.id), 0) > 0,
                 'details', case when i.kind = 'used' then (select jsonb_build_object('brand', u.brand, 'model', u.model, 'storage', u.storage, 'color', u.color, 'condition', u.condition)
                                                             from public.used_devices u where u.item_id = i.id) end) x
        from public.items i
        where i.shop_id = s and i.in_catalog and i.deleted_at is null and i.sale_price is not null
          -- المستعمل اللي اتباع ما بيظهرش
          and (i.kind <> 'used' or coalesce((select sum(m.qty) from public.stock_moves m where m.item_id = i.id), 0) > 0)
        limit 500) q), '[]'::jsonb));
end $$;
revoke execute on function public.public_catalog(text) from public;
grant execute on function public.public_catalog(text) to anon, authenticated;

-- صور الأصناف في الكتالوج: لصاحب رابط الكتالوج بس، وللأصناف المختارة بس (header x-catalog-token)
create or replace function public.catalog_image_allowed(p_name text) returns boolean
language plpgsql stable security definer set search_path = public as $$
declare tok text := nullif(current_setting('request.headers', true), '')::json ->> 'x-catalog-token'; s uuid;
begin
  s := public.catalog_shop(tok);
  if s is null then return false; end if;
  return exists (select 1 from public.items i where i.shop_id = s and i.in_catalog and i.deleted_at is null and i.image_path = p_name);
exception when others then return false;
end $$;
revoke execute on function public.catalog_image_allowed(text) from public;
grant execute on function public.catalog_image_allowed(text) to anon, authenticated;
create policy item_images_catalog_read on storage.objects for select to anon
  using (bucket_id = 'item-images' and public.catalog_image_allowed(name));
