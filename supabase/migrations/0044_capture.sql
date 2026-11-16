-- 0044: C1: صور الاستلام من موبايل الفني بالـ QR، وصور الاستلام في صفحة التتبع.
-- الفكرة: الاستقبال بيفتح "جلسة رفع" للجهاز (token عشوائي 128 bit، صالح 30 دقيقة، وأقصى 6 صور للجهاز زي ما هو).
-- الموبايل بيفتح الرابط من غير تسجيل دخول، وبيرفع الصورة على Storage ومعاها الـ token في header (x-upload-token)،
-- وسياسة Storage بتتأكد إن الجلسة شغالة وإن المسار جوه فولدر نفس المحل ونفس الجهاز. بعدها الصورة بتتسجل على الجهاز.
-- صفحة التتبع: صور الاستلام بتظهر لصاحب رابط التتبع بس (header x-track-token = tracking_token بتاع الجهاز).

create table public.photo_upload_sessions (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references public.shops(id),
  device_id uuid not null references public.devices(id),
  token text not null unique check (length(token) = 32),
  expires_at timestamptz not null,
  created_by uuid references public.profiles(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);
create index photo_upload_sessions_device on public.photo_upload_sessions(device_id);
alter table public.photo_upload_sessions enable row level security;
create trigger set_updated_at before update on public.photo_upload_sessions for each row execute function public.tg_set_updated_at();
create trigger block_delete before delete on public.photo_upload_sessions for each row execute function public.tg_block_delete();
-- القراية لموظفين نفس المحل اللي بيرفعوا صور بس؛ الإنشاء من الدالة بس (مفيش سياسة إضافة)
create policy upload_sessions_select on public.photo_upload_sessions for select to authenticated
  using (shop_id = public.current_shop_id() and public.current_app_role() in ('owner', 'reception'));
grant select on public.photo_upload_sessions to authenticated;

-- uploaded_by: من الجلسة لما الرفع جاي من الموبايل من غير تسجيل دخول
create or replace function public.tg_photo_limit() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  perform pg_advisory_xact_lock(hashtext(new.device_id::text));
  if (select count(*) from public.device_photos where device_id = new.device_id and deleted_at is null) >= 6 then
    raise exception 'E_PHOTO_LIMIT';
  end if;
  if new.storage_path not like new.shop_id::text || '/' || new.device_id::text || '/%' then
    raise exception 'E_PHOTO_PATH';
  end if;
  new.uploaded_by := coalesce(auth.uid(), case when current_setting('warsha.system', true) = 'on' then new.uploaded_by end);
  return new;
end $$;

-- فتح جلسة رفع (الاستقبال أو صاحب المحل، لجهاز في نفس المحل لسه ما اتسلمش)
create or replace function public.start_photo_upload(p_device uuid)
returns table(token text, expires_at timestamptz)
-- extensions: فيها gen_random_bytes على Supabase
language plpgsql security definer set search_path = public, extensions, pg_temp as $$
declare d public.devices; t text := encode(gen_random_bytes(16), 'hex'); e timestamptz := now() + interval '30 minutes';
begin
  if public.current_app_role() not in ('owner', 'reception') then raise exception 'E_FORBIDDEN'; end if;
  select * into d from public.devices where id = p_device and shop_id = public.current_shop_id() and deleted_at is null;
  if d.id is null then raise exception 'E_NOT_FOUND'; end if;
  if d.status = 'delivered' then raise exception 'E_DELIVERED'; end if;
  -- الجلسات القديمة لنفس الجهاز بتتقفل (رابط واحد شغال في نفس الوقت)
  update public.photo_upload_sessions s set deleted_at = now() where s.device_id = d.id and s.deleted_at is null;
  insert into public.photo_upload_sessions(shop_id, device_id, token, expires_at, created_by)
  values (d.shop_id, d.id, t, e, auth.uid());
  return query select t, e;
end $$;
revoke execute on function public.start_photo_upload(uuid) from public, anon;
grant execute on function public.start_photo_upload(uuid) to authenticated;

-- الجلسة الشغالة من الـ token (داخلي)
create or replace function public.photo_session_by(p_token text) returns public.photo_upload_sessions
language sql stable security definer set search_path = public as $$
  select s.* from public.photo_upload_sessions s
  join public.devices d on d.id = s.device_id and d.deleted_at is null and d.status <> 'delivered'
  join public.shops sh on sh.id = s.shop_id and sh.deleted_at is null and sh.suspended_at is null
  where s.token = p_token and s.deleted_at is null and s.expires_at > now()
$$;
revoke execute on function public.photo_session_by(text) from public, anon, authenticated;

-- اللي الموبايل محتاجه يعرضه: اسم المحل، ورقم الطلب، والموديل، وعدد الصور، والمسار. من غير أي بيانات للعميل.
create or replace function public.photo_session(p_token text)
returns table(shop_name text, order_no text, brand text, model text, photos integer, max_photos integer, expires_at timestamptz, folder text)
language plpgsql stable security definer set search_path = public as $$
declare s public.photo_upload_sessions := public.photo_session_by(p_token);
begin
  if s.id is null then return; end if;
  return query
  select sh.name, d.order_no, d.brand, d.model,
    (select count(*)::integer from public.device_photos p where p.device_id = d.id and p.deleted_at is null),
    6, s.expires_at, s.shop_id::text || '/' || s.device_id::text
  from public.devices d join public.shops sh on sh.id = d.shop_id where d.id = s.device_id;
end $$;
revoke execute on function public.photo_session(text) from public;
grant execute on function public.photo_session(text) to anon, authenticated;

-- سياسة Storage: الرفع بـ token الجلسة في الـ header، جوه فولدر نفس الجهاز، وقبل ما يوصل للحد
create or replace function public.photo_upload_allowed(p_name text) returns boolean
language plpgsql stable security definer set search_path = public as $$
declare
  tok text := nullif(current_setting('request.headers', true), '')::json ->> 'x-upload-token';
  s public.photo_upload_sessions;
begin
  if tok is null then return false; end if;
  s := public.photo_session_by(tok);
  if s.id is null then return false; end if;
  return p_name like s.shop_id::text || '/' || s.device_id::text || '/%'
    and p_name ~ '^[0-9a-f-]{36}/[0-9a-f-]{36}/[0-9a-f-]{36}\.jpg$'
    and (select count(*) from public.device_photos p where p.device_id = s.device_id and p.deleted_at is null) < 6;
exception when others then return false;
end $$;
revoke execute on function public.photo_upload_allowed(text) from public;
grant execute on function public.photo_upload_allowed(text) to anon, authenticated;

create policy device_photos_session_upload on storage.objects for insert to anon, authenticated
  with check (bucket_id = 'device-photos' and public.photo_upload_allowed(name));

-- بعد الرفع: الصورة بتتسجل على الجهاز (لازم تكون اترفعت فعلًا في Storage)
create or replace function public.add_session_photo(p_token text, p_path text) returns uuid
language plpgsql security definer set search_path = public as $$
declare s public.photo_upload_sessions := public.photo_session_by(p_token); pid uuid := gen_random_uuid();
begin
  if s.id is null then raise exception 'E_UPLOAD_EXPIRED'; end if;
  if p_path not like s.shop_id::text || '/' || s.device_id::text || '/%' then raise exception 'E_PHOTO_PATH'; end if;
  if not exists (select 1 from storage.objects o where o.bucket_id = 'device-photos' and o.name = p_path) then raise exception 'E_NOT_FOUND'; end if;
  if exists (select 1 from public.device_photos p where p.storage_path = p_path) then
    return (select p.id from public.device_photos p where p.storage_path = p_path);
  end if;
  perform set_config('warsha.system', 'on', true);
  insert into public.device_photos(id, shop_id, device_id, storage_path, uploaded_by) values (pid, s.shop_id, s.device_id, p_path, s.created_by);
  perform set_config('warsha.system', 'off', true);
  return pid;
end $$;
revoke execute on function public.add_session_photo(text, text) from public;
grant execute on function public.add_session_photo(text, text) to anon, authenticated;

-- صفحة التتبع: مسارات صور الاستلام لصاحب رابط التتبع
create or replace function public.tracking_photos(p_token text) returns setof text
language sql stable security definer set search_path = public as $$
  select p.storage_path from public.devices d
  join public.shops sh on sh.id = d.shop_id and sh.deleted_at is null and sh.suspended_at is null
  join public.device_photos p on p.device_id = d.id and p.deleted_at is null
  where p_token is not null and length(p_token) >= 16 and d.tracking_token = p_token and d.deleted_at is null
  order by p.created_at limit 6
$$;
revoke execute on function public.tracking_photos(text) from public;
grant execute on function public.tracking_photos(text) to anon, authenticated;

create or replace function public.track_photo_allowed(p_name text) returns boolean
language plpgsql stable security definer set search_path = public as $$
declare tok text := nullif(current_setting('request.headers', true), '')::json ->> 'x-track-token';
begin
  if tok is null or length(tok) < 16 then return false; end if;
  return exists (select 1 from public.tracking_photos(tok) x where x = p_name);
exception when others then return false;
end $$;
revoke execute on function public.track_photo_allowed(text) from public;
grant execute on function public.track_photo_allowed(text) to anon, authenticated;

create policy device_photos_track_read on storage.objects for select to anon
  using (bucket_id = 'device-photos' and public.track_photo_allowed(name));
