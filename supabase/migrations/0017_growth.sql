-- المرحلة 6: النمو
--
-- 1) دور "مدير التسويق" (marketing): بيشوف فيديوهات الإصلاح بس. مش معدود موظف في المحل في أي صلاحية تانية
--    (current_shop_id بيرجّع فاضي ليه)، فما بيشوفش أجهزة ولا عملاء ولا فلوس.
-- 2) فيديوهات الإصلاح: الفني بيرفع، ومدير التسويق بيراجع، والمقبول بيزوّد نقاط الفني. من غير بيانات العميل.
-- 3) تقييم العميل للجهاز بعد التسليم (من صفحة التتبع)، وبيتحسب للفني اللي قفله.
-- 4) مجتمع الفنيين: مشترك بين المحلات (مقصود)، ومن غير بيانات عملاء: أي نص فيه رقم موبايل أو IMEI بيترفض. والمشرف بيخفي.
-- 5) الخطط والحدود: كل محل على خطة (مجانية افتراضيًا)، والحد بيتطبق في قاعدة البيانات.
-- 6) لوحة المشرف (صاحب المنصة بس): المحلات واستخدامها من غير بيانات عملاء، وتغيير الخطة، والإيقاف، ومراجعة المجتمع.
-- 7) عداد استخدام المساعد الذكي (الحد اليومي من الخطة). الأسئلة نفسها ما بتتخزنش.
--
-- ملحوظة: القيمة الجديدة في enum بتتستخدم كنص (::text) في الملف ده، عشان الملف يشتغل في transaction واحدة.

alter type public.app_role add value if not exists 'marketing';

-- ============================================================
-- الخطط
-- ============================================================
create table public.plans (
  code text primary key,
  max_devices_month integer,  -- null = من غير حد
  max_staff integer,
  ai_daily integer not null default 0,
  max_videos integer,
  sort integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);
insert into public.plans(code, max_devices_month, max_staff, ai_daily, max_videos, sort) values
  ('free', 300, 5, 20, 50, 1),
  ('pro', null, null, 200, null, 2)
on conflict (code) do nothing;
alter table public.plans enable row level security;
revoke all on public.plans from public, anon, authenticated;
create policy plans_read on public.plans for select to authenticated using (true);
grant select on public.plans to authenticated;

alter table public.shops add column if not exists plan_code text not null default 'free' references public.plans(code);
alter table public.shops add column if not exists suspended_at timestamptz;

-- ============================================================
-- المشرفين (صاحب المنصة)
-- ============================================================
create table public.platform_admins (
  user_id uuid primary key references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);
alter table public.platform_admins enable row level security;
revoke all on public.platform_admins from public, anon, authenticated;

create or replace function public.is_platform_admin() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.platform_admins where user_id = auth.uid() and deleted_at is null)
$$;

-- ============================================================
-- المحل الحالي: مدير التسويق والمحل الموقوف ملهمش محل في الصلاحيات العادية
-- ============================================================
create or replace function public.current_shop_id() returns uuid
language sql stable security definer set search_path = public as $$
  select p.shop_id from public.profiles p join public.shops s on s.id = p.shop_id
  where p.id = auth.uid() and p.deleted_at is null and p.role::text <> 'marketing' and s.suspended_at is null
$$;
-- محل مدير التسويق (للفيديوهات بس)
create or replace function public.marketing_shop_id() returns uuid
language sql stable security definer set search_path = public as $$
  select p.shop_id from public.profiles p join public.shops s on s.id = p.shop_id
  where p.id = auth.uid() and p.deleted_at is null and p.role::text = 'marketing' and s.suspended_at is null
$$;
-- أي حد في المحل (لأي دور، ومنهم التسويق) — للفيديوهات والمجتمع
create or replace function public.member_shop_id() returns uuid
language sql stable security definer set search_path = public as $$
  select p.shop_id from public.profiles p join public.shops s on s.id = p.shop_id
  where p.id = auth.uid() and p.deleted_at is null and s.suspended_at is null
$$;
create or replace function public.member_role() returns text
language sql stable security definer set search_path = public as $$
  select p.role::text from public.profiles p where p.id = auth.uid() and p.deleted_at is null
$$;

-- الصف الجديد بياخد محل المستخدم (لأي دور، ومنهم التسويق). الصلاحيات (RLS) هي اللي بتمنع التسويق من الجداول
create or replace function public.tg_force_shop_id() returns trigger
language plpgsql security definer set search_path = public as $$
declare s uuid := coalesce(public.current_shop_id(), public.member_shop_id());
begin
  if current_setting('warsha.system', true) = 'on' then
    return new;
  end if;
  if s is null then
    if tg_op = 'UPDATE' and auth.uid() is null and new.shop_id = old.shop_id then
      return new;
    end if;
    raise exception 'E_NO_SHOP';
  end if;
  if tg_op = 'INSERT' then
    new.shop_id := s;
  elsif new.shop_id is distinct from old.shop_id then
    raise exception 'E_SHOP_CHANGE';
  end if;
  return new;
end $$;

-- ============================================================
-- حدود الخطة
-- ============================================================
create or replace function public.shop_plan(p_shop uuid) returns public.plans
language sql stable security definer set search_path = public as $$
  select pl.* from public.shops s join public.plans pl on pl.code = s.plan_code where s.id = p_shop
$$;

create or replace function public.tg_plan_devices() returns trigger
language plpgsql security definer set search_path = public as $$
declare pl public.plans := public.shop_plan(new.shop_id); n int;
begin
  if pl.max_devices_month is not null then
    select count(*) into n from public.devices
     where shop_id = new.shop_id and received_at >= date_trunc('month', now() at time zone 'Africa/Cairo') at time zone 'Africa/Cairo';
    if n >= pl.max_devices_month then raise exception 'E_PLAN_LIMIT'; end if;
  end if;
  return new;
end $$;
create trigger zz_plan_devices before insert on public.devices for each row execute function public.tg_plan_devices();

create or replace function public.tg_plan_staff() returns trigger
language plpgsql security definer set search_path = public as $$
declare pl public.plans := public.shop_plan(new.shop_id); n int;
begin
  if pl.max_staff is not null then
    select (select count(*) from public.profiles where shop_id = new.shop_id and deleted_at is null)
         + (select count(*) from public.staff_invites where shop_id = new.shop_id and accepted_at is null and deleted_at is null) into n;
    if n >= pl.max_staff then raise exception 'E_PLAN_LIMIT'; end if;
  end if;
  return new;
end $$;
create trigger zz_plan_staff before insert on public.staff_invites for each row execute function public.tg_plan_staff();

-- استخدام المحل وحدود خطته (صاحب المحل)
create or replace function public.plan_usage() returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare s uuid := public.current_shop_id(); pl public.plans;
begin
  if public.current_app_role() is distinct from 'owner' then raise exception 'E_FORBIDDEN'; end if;
  pl := public.shop_plan(s);
  return jsonb_build_object(
    'plan', pl.code, 'max_devices_month', pl.max_devices_month, 'max_staff', pl.max_staff, 'ai_daily', pl.ai_daily, 'max_videos', pl.max_videos,
    'devices_month', (select count(*) from public.devices where shop_id = s and received_at >= date_trunc('month', now() at time zone 'Africa/Cairo') at time zone 'Africa/Cairo'),
    'staff', (select count(*) from public.profiles where shop_id = s and deleted_at is null),
    'ai_today', (select count(*) from public.ai_usage where shop_id = s and created_at >= date_trunc('day', now() at time zone 'Africa/Cairo') at time zone 'Africa/Cairo'),
    'videos', (select count(*) from public.repair_videos where shop_id = s and deleted_at is null));
end $$;

-- ============================================================
-- فيديوهات الإصلاح
-- ============================================================
create table public.repair_videos (
  id uuid primary key,
  shop_id uuid not null references public.shops(id),
  technician_id uuid not null references public.profiles(id),
  device_id uuid references public.devices(id),
  title text not null check (length(trim(title)) between 1 and 120),
  description text check (description is null or length(description) <= 1000),
  storage_path text not null,
  status text not null default 'pending' check (status in ('pending', 'approved', 'rejected')),
  points integer not null default 0 check (points between 0 and 100),
  review_note text check (review_note is null or length(review_note) <= 500),
  reviewed_by uuid references public.profiles(id),
  reviewed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);
alter table public.repair_videos enable row level security;
revoke all on public.repair_videos from public, anon, authenticated;
-- الفني بيشوف فيديوهاته، وصاحب المحل ومدير التسويق بيشوفوا فيديوهات المحل كلها
create policy videos_select on public.repair_videos for select to authenticated using (
  shop_id = public.member_shop_id() and (technician_id = auth.uid() or public.member_role() in ('owner', 'marketing')));
grant select on public.repair_videos to authenticated;
create trigger set_updated_at before update on public.repair_videos for each row execute function public.tg_set_updated_at();
create trigger block_delete before delete on public.repair_videos for each row execute function public.tg_block_delete();
create trigger zz_audit after insert or update on public.repair_videos for each row execute function public.tg_audit();

-- الفني (أو صاحب المحل) بيضيف فيديو بعد ما يرفعه في Storage
create or replace function public.add_video(p_id uuid, p_title text, p_path text, p_device uuid default null, p_description text default null) returns uuid
language plpgsql security definer set search_path = public as $$
declare s uuid := public.member_shop_id(); pl public.plans;
begin
  if public.member_role() not in ('technician', 'owner') then raise exception 'E_FORBIDDEN'; end if;
  if p_path is null or split_part(p_path, '/', 1) <> s::text then raise exception 'E_BAD_INPUT'; end if;
  if p_device is not null and not exists (select 1 from public.devices where id = p_device and shop_id = s) then raise exception 'E_NOT_FOUND'; end if;
  if public.has_private_data(coalesce(p_title, '') || ' ' || coalesce(p_description, '')) then raise exception 'E_PRIVATE_DATA'; end if;
  pl := public.shop_plan(s);
  if pl.max_videos is not null and (select count(*) from public.repair_videos where shop_id = s and deleted_at is null) >= pl.max_videos then raise exception 'E_PLAN_LIMIT'; end if;
  insert into public.repair_videos(id, shop_id, technician_id, device_id, title, description, storage_path)
  values (p_id, s, auth.uid(), p_device, trim(p_title), nullif(trim(p_description), ''), p_path)
  on conflict (id) do nothing;
  return p_id;
end $$;

-- مدير التسويق (أو صاحب المحل) بيراجع: موافقة بنقاط للفني، أو رفض
create or replace function public.review_video(p_video uuid, p_approve boolean, p_points integer default 10, p_note text default null) returns void
language plpgsql security definer set search_path = public as $$
declare v public.repair_videos;
begin
  if public.member_role() not in ('marketing', 'owner') then raise exception 'E_FORBIDDEN'; end if;
  select * into v from public.repair_videos where id = p_video and shop_id = public.member_shop_id() and deleted_at is null for update;
  if not found then raise exception 'E_NOT_FOUND'; end if;
  if p_points < 0 or p_points > 100 then raise exception 'E_BAD_INPUT'; end if;
  update public.repair_videos set status = case when p_approve then 'approved' else 'rejected' end,
    points = case when p_approve then p_points else 0 end, review_note = nullif(trim(p_note), ''), reviewed_by = auth.uid(), reviewed_at = now()
  where id = v.id;
end $$;

-- Storage للفيديوهات: خاص بكل محل
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('repair-videos', 'repair-videos', false, 104857600, array['video/mp4', 'video/webm', 'video/quicktime'])
on conflict (id) do nothing;
create policy videos_upload on storage.objects for insert to authenticated
  with check (bucket_id = 'repair-videos' and (storage.foldername(name))[1] = public.member_shop_id()::text and public.member_role() in ('technician', 'owner'));
create policy videos_read on storage.objects for select to authenticated
  using (bucket_id = 'repair-videos' and (storage.foldername(name))[1] = public.member_shop_id()::text and public.member_role() in ('technician', 'owner', 'marketing'));

-- ============================================================
-- تقييمات العملاء
-- ============================================================
create table public.device_ratings (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references public.shops(id),
  device_id uuid not null unique references public.devices(id),
  technician_id uuid references public.profiles(id),
  stars integer not null check (stars between 1 and 5),
  comment text check (comment is null or length(comment) <= 500),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);
alter table public.device_ratings enable row level security;
revoke all on public.device_ratings from public, anon, authenticated;
create policy ratings_select on public.device_ratings for select to authenticated using (shop_id = public.current_shop_id() and public.current_app_role() in ('owner', 'reception'));
grant select on public.device_ratings to authenticated;
create trigger ratings_immutable before update or delete on public.device_ratings for each row execute function public.tg_ledger_immutable();

-- حالة التقييم في صفحة التتبع (بالرمز السري بس)
create or replace function public.rating_state(p_token text) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare d public.devices;
begin
  select * into d from public.devices where tracking_token = p_token and deleted_at is null;
  if not found then return jsonb_build_object('can_rate', false); end if;
  return jsonb_build_object('can_rate', d.status = 'delivered' and not exists (select 1 from public.device_ratings r where r.device_id = d.id),
                            'stars', (select stars from public.device_ratings r where r.device_id = d.id));
end $$;

-- العميل بيقيّم مرة واحدة بعد التسليم. التقييم بيتحسب للفني اللي قفل الجهاز
create or replace function public.rate_device(p_token text, p_stars integer, p_comment text default null) returns void
language plpgsql security definer set search_path = public as $$
declare d public.devices; k text := public.tracking_guard(null); t uuid;
begin
  if p_stars is null or p_stars < 1 or p_stars > 5 then raise exception 'E_BAD_INPUT'; end if;
  select * into d from public.devices where tracking_token = p_token and deleted_at is null;
  if not found then
    insert into public.tracking_attempts(client_key, order_no, success) values (k, null, false);
    return;
  end if;
  if d.status <> 'delivered' then raise exception 'E_BAD_TRANSITION'; end if;
  if exists (select 1 from public.device_ratings where device_id = d.id) then raise exception 'E_ALREADY_RATED'; end if;
  select s.technician_id into t from public.repair_steps s where s.device_id = d.id and s.status = 'done' and s.technician_id is not null order by s.step_no desc limit 1;
  insert into public.device_ratings(shop_id, device_id, technician_id, stars, comment)
  values (d.shop_id, d.id, t, p_stars, nullif(trim(left(p_comment, 500)), ''));
end $$;

-- ============================================================
-- المجتمع (مشترك بين المحلات، ومن غير بيانات عملاء)
-- ============================================================
-- نص فيه رقم موبايل أو IMEI أو أي رقم طويل = ممكن يكون بيانات عميل
create or replace function public.has_private_data(p text) returns boolean
language sql immutable as $$
  select coalesce(p, '') ~ '(\+?\d[\d\s-]{7,}\d)' or coalesce(p, '') ~ '[٠-٩]{8,}'
$$;

create table public.community_posts (
  id uuid primary key,
  shop_id uuid not null references public.shops(id),  -- محل الكاتب (المنشور نفسه مشترك)
  author_id uuid not null references public.profiles(id),
  parent_id uuid references public.community_posts(id), -- رد على منشور
  title text check (title is null or length(title) between 1 and 160),
  body text not null check (length(trim(body)) between 1 and 4000),
  tags text[] not null default '{}',
  hidden_at timestamptz,
  hidden_by uuid,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);
create index community_posts_parent on public.community_posts(parent_id, created_at);
alter table public.community_posts enable row level security;
revoke all on public.community_posts from public, anon, authenticated;
create policy community_select on public.community_posts for select to authenticated using (
  deleted_at is null and (hidden_at is null or author_id = auth.uid() or public.is_platform_admin()) and public.member_shop_id() is not null);
grant select on public.community_posts to authenticated;
create trigger set_updated_at before update on public.community_posts for each row execute function public.tg_set_updated_at();
create trigger block_delete before delete on public.community_posts for each row execute function public.tg_block_delete();

create table public.community_reports (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references public.shops(id),
  post_id uuid not null references public.community_posts(id),
  reporter_id uuid not null references public.profiles(id),
  reason text check (reason is null or length(reason) <= 300),
  resolved_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  unique (post_id, reporter_id)
);
alter table public.community_reports enable row level security;
revoke all on public.community_reports from public, anon, authenticated;

create or replace function public.community_post(p_id uuid, p_body text, p_title text default null, p_parent uuid default null, p_tags text[] default '{}') returns uuid
language plpgsql security definer set search_path = public as $$
declare s uuid := public.member_shop_id();
begin
  if s is null or public.member_role() = 'marketing' then raise exception 'E_FORBIDDEN'; end if;
  if public.has_private_data(coalesce(p_title, '') || ' ' || coalesce(p_body, '')) then raise exception 'E_PRIVATE_DATA'; end if;
  if p_parent is not null and not exists (select 1 from public.community_posts where id = p_parent and parent_id is null and deleted_at is null and hidden_at is null) then
    raise exception 'E_NOT_FOUND';
  end if;
  insert into public.community_posts(id, shop_id, author_id, parent_id, title, body, tags)
  values (p_id, s, auth.uid(), p_parent, case when p_parent is null then nullif(trim(p_title), '') end, trim(p_body), coalesce(p_tags, '{}'))
  on conflict (id) do nothing;
  return p_id;
end $$;

create or replace function public.community_report(p_post uuid, p_reason text default null) returns void
language plpgsql security definer set search_path = public as $$
begin
  if public.member_shop_id() is null then raise exception 'E_FORBIDDEN'; end if;
  insert into public.community_reports(shop_id, post_id, reporter_id, reason) values (public.member_shop_id(), p_post, auth.uid(), nullif(trim(p_reason), ''))
  on conflict (post_id, reporter_id) do nothing;
end $$;

-- المنشورات مع اسم الكاتب الأول بس واسم محله (من غير أي بيانات عملاء)
create or replace function public.community_feed(p_parent uuid default null, p_limit integer default 50)
returns table(id uuid, parent_id uuid, title text, body text, tags text[], author text, shop text, created_at timestamptz, replies integer, mine boolean, hidden boolean)
language plpgsql stable security definer set search_path = public as $$
#variable_conflict use_column
begin
  if public.member_shop_id() is null then raise exception 'E_FORBIDDEN'; end if;
  return query
  select c.id, c.parent_id, c.title, c.body, c.tags, split_part(p.full_name, ' ', 1), s.name, c.created_at,
         (select count(*)::int from public.community_posts r where r.parent_id = c.id and r.deleted_at is null and r.hidden_at is null),
         c.author_id = auth.uid(), c.hidden_at is not null
  from public.community_posts c join public.profiles p on p.id = c.author_id join public.shops s on s.id = c.shop_id
  where c.deleted_at is null and (c.hidden_at is null or c.author_id = auth.uid() or public.is_platform_admin())
    and ((p_parent is null and c.parent_id is null) or c.parent_id = p_parent or (p_parent is not null and c.id = p_parent))
  order by case when c.id = p_parent then 0 else 1 end, c.created_at desc
  limit least(greatest(p_limit, 1), 200);
end $$;

-- ============================================================
-- المساعد الذكي: عداد بس (الأسئلة ما بتتخزنش)
-- ============================================================
create table public.ai_usage (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references public.shops(id),
  user_id uuid not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);
create index ai_usage_shop_time on public.ai_usage(shop_id, created_at);
alter table public.ai_usage enable row level security;
revoke all on public.ai_usage from public, anon, authenticated;

-- بتتنادى من الـ Edge Function قبل أي سؤال: بتسجل الاستخدام وبترفض لو الحد اليومي خلص
create or replace function public.ai_take() returns jsonb
language plpgsql security definer set search_path = public as $$
declare s uuid := public.member_shop_id(); pl public.plans; n int;
begin
  if s is null or public.member_role() not in ('owner', 'reception', 'technician') then raise exception 'E_FORBIDDEN'; end if;
  pl := public.shop_plan(s);
  select count(*) into n from public.ai_usage where shop_id = s and created_at >= date_trunc('day', now() at time zone 'Africa/Cairo') at time zone 'Africa/Cairo';
  if n >= pl.ai_daily then raise exception 'E_PLAN_LIMIT'; end if;
  insert into public.ai_usage(shop_id, user_id) values (s, auth.uid());
  return jsonb_build_object('left', pl.ai_daily - n - 1);
end $$;

-- ============================================================
-- تقرير الفنيين: + متوسط التقييم + نقاط الفيديوهات
-- ============================================================
drop function if exists public.tech_report(timestamptz, timestamptz);
create or replace function public.tech_report(p_from timestamptz, p_to timestamptz)
returns table(tech_id uuid, name text, devices integer, steps integer, avg_minutes integer, returns integer, return_rate integer, revenue bigint, rating numeric, ratings integer, points integer)
language plpgsql stable security definer set search_path = public as $$
#variable_conflict use_column
declare s uuid := public.current_shop_id();
begin
  perform public.ledger_require(array['owner']::public.app_role[]);
  return query
  with closed as (
    select distinct on (x.device_id) x.device_id, x.technician_id, x.finished_at
    from public.repair_steps x where x.shop_id = s and x.status = 'done' and x.technician_id is not null
    order by x.device_id, x.step_no desc
  )
  select p.id, p.full_name,
    (select count(*)::int from closed c where c.technician_id = p.id and c.finished_at >= p_from and c.finished_at < p_to),
    (select count(*)::int from public.repair_steps x where x.technician_id = p.id and x.status = 'done' and x.finished_at >= p_from and x.finished_at < p_to),
    (select round(avg(extract(epoch from x.finished_at - x.started_at) / 60))::int from public.repair_steps x
      where x.technician_id = p.id and x.status = 'done' and x.started_at is not null and x.finished_at >= p_from and x.finished_at < p_to),
    (select count(*)::int from public.devices d where d.return_of_tech = p.id and d.updated_at >= p_from and d.updated_at < p_to),
    case when (select count(*) from closed c where c.technician_id = p.id) = 0 then 0
         else ((select count(*) from public.devices d where d.return_of_tech = p.id) * 100 / (select count(*) from closed c where c.technician_id = p.id))::int end,
    (select coalesce(sum(l.debit), 0)::bigint from closed c
       join public.journal_entries e on e.source_type = 'delivery' and e.source_id = c.device_id and e.occurred_at >= p_from and e.occurred_at < p_to
         and not exists (select 1 from public.journal_entries r where r.reverses_id = e.id)
       join public.journal_lines l on l.entry_id = e.id and l.debit > 0
     where c.technician_id = p.id),
    (select round(avg(r.stars)::numeric, 1) from public.device_ratings r where r.technician_id = p.id),
    (select count(*)::int from public.device_ratings r where r.technician_id = p.id),
    (select coalesce(sum(v.points), 0)::int from public.repair_videos v where v.technician_id = p.id and v.status = 'approved' and v.deleted_at is null)
  from public.profiles p
  where p.shop_id = s and p.role = 'technician' and p.deleted_at is null
  order by 3 desc, 2;
end $$;

-- ============================================================
-- لوحة المشرف (صاحب المنصة بس): من غير أي بيانات عملاء
-- ============================================================
create or replace function public.admin_shops()
returns table(id uuid, name text, created_at timestamptz, plan text, suspended boolean, staff integer, devices integer, devices_month integer, last_activity timestamptz)
language plpgsql stable security definer set search_path = public as $$
#variable_conflict use_column
begin
  if not public.is_platform_admin() then raise exception 'E_FORBIDDEN'; end if;
  return query
  select s.id, s.name, s.created_at, s.plan_code, s.suspended_at is not null,
         (select count(*)::int from public.profiles p where p.shop_id = s.id and p.deleted_at is null),
         (select count(*)::int from public.devices d where d.shop_id = s.id and d.deleted_at is null),
         (select count(*)::int from public.devices d where d.shop_id = s.id and d.received_at >= date_trunc('month', now())),
         (select max(a.created_at) from public.audit_log a where a.shop_id = s.id)
  from public.shops s order by s.created_at desc;
end $$;

create or replace function public.admin_set_plan(p_shop uuid, p_plan text) returns void
language plpgsql security definer set search_path = public as $$
begin
  if not public.is_platform_admin() then raise exception 'E_FORBIDDEN'; end if;
  if not exists (select 1 from public.plans where code = p_plan) then raise exception 'E_NOT_FOUND'; end if;
  perform set_config('warsha.system', 'on', true);
  update public.shops set plan_code = p_plan where id = p_shop;
  perform set_config('warsha.system', 'off', true);
  insert into public.audit_log(shop_id, actor_id, action, entity, entity_id, after) values (p_shop, auth.uid(), 'admin_set_plan', 'shops', p_shop, jsonb_build_object('plan', p_plan));
end $$;

create or replace function public.admin_suspend(p_shop uuid, p_suspend boolean) returns void
language plpgsql security definer set search_path = public as $$
begin
  if not public.is_platform_admin() then raise exception 'E_FORBIDDEN'; end if;
  perform set_config('warsha.system', 'on', true);
  update public.shops set suspended_at = case when p_suspend then now() end where id = p_shop;
  perform set_config('warsha.system', 'off', true);
  insert into public.audit_log(shop_id, actor_id, action, entity, entity_id, after) values (p_shop, auth.uid(), case when p_suspend then 'admin_suspend' else 'admin_unsuspend' end, 'shops', p_shop, '{}'::jsonb);
end $$;

create or replace function public.admin_reports()
returns table(post_id uuid, body text, author text, shop text, reports integer, hidden boolean, created_at timestamptz)
language plpgsql stable security definer set search_path = public as $$
#variable_conflict use_column
begin
  if not public.is_platform_admin() then raise exception 'E_FORBIDDEN'; end if;
  return query
  select c.id, c.body, split_part(p.full_name, ' ', 1), s.name, count(r.id)::int, c.hidden_at is not null, c.created_at
  from public.community_reports r join public.community_posts c on c.id = r.post_id
  join public.profiles p on p.id = c.author_id join public.shops s on s.id = c.shop_id
  where r.resolved_at is null
  group by c.id, p.full_name, s.name order by 5 desc, c.created_at desc;
end $$;

create or replace function public.admin_moderate(p_post uuid, p_hide boolean) returns void
language plpgsql security definer set search_path = public as $$
begin
  if not public.is_platform_admin() then raise exception 'E_FORBIDDEN'; end if;
  update public.community_posts set hidden_at = case when p_hide then now() end, hidden_by = case when p_hide then auth.uid() end where id = p_post;
  update public.community_reports set resolved_at = now() where post_id = p_post and resolved_at is null;
end $$;

-- الإيقاف والخطة بيتغيروا من المشرف بس (صاحب المحل ما يقدرش يغيّرهم)
create or replace function public.tg_shop_admin_fields() returns trigger
language plpgsql as $$
begin
  if (new.plan_code is distinct from old.plan_code or new.suspended_at is distinct from old.suspended_at)
     and coalesce(current_setting('warsha.system', true), '') <> 'on' then
    raise exception 'E_FORBIDDEN';
  end if;
  return new;
end $$;
create trigger zy_shop_admin_fields before update on public.shops for each row execute function public.tg_shop_admin_fields();

-- ============================================================
-- الصلاحيات للدوال
-- ============================================================
do $$
declare f text;
begin
  foreach f in array array['marketing_shop_id()', 'shop_plan(uuid)'] loop
    execute format('revoke execute on function public.%s from public, anon, authenticated', f);
  end loop;
  foreach f in array array['is_platform_admin()', 'member_shop_id()', 'member_role()', 'plan_usage()', 'add_video(uuid, text, text, uuid, text)',
                           'review_video(uuid, boolean, integer, text)', 'community_post(uuid, text, text, uuid, text[])', 'community_report(uuid, text)',
                           'community_feed(uuid, integer)', 'ai_take()', 'tech_report(timestamptz, timestamptz)', 'admin_shops()', 'admin_set_plan(uuid, text)',
                           'admin_suspend(uuid, boolean)', 'admin_reports()', 'admin_moderate(uuid, boolean)'] loop
    execute format('revoke execute on function public.%s from public, anon', f);
    execute format('grant execute on function public.%s to authenticated', f);
  end loop;
  -- صفحة التتبع (من غير تسجيل دخول)
  foreach f in array array['rating_state(text)', 'rate_device(text, integer, text)'] loop
    execute format('revoke execute on function public.%s from public', f);
    execute format('grant execute on function public.%s to anon, authenticated', f);
  end loop;
end $$;
