-- 0058: Web Push: إشعارات على الجهاز حتى والبرنامج مقفول (N المرحلة التانية)
--
-- - مجاني: خدمات الإشعارات بتاعة المتصفحات (Chrome/Edge/Firefox/Safari) مجانية، ومفيش أي خدمة مدفوعة.
-- - كل مستخدم بيفعّلها لجهازه من الإعدادات ← التنبيهات. الاشتراك بتاع الجهاز (endpoint + المفاتيح العامة) بيتحفظ هنا،
--   وصاحبه بس اللي يشوفه. الكتابة من الدوال بس.
-- - الإشعارات نفسها هي نفس اللي في الجرس (my_notifications) بنفس الصلاحيات بالظبط: الفني ما يوصلوش أقساط ولا فلوس.
-- - كل إشعار بيتبعت مرة واحدة بس لكل مستخدم (push_sent)، وما بيتبعتش لو المستخدم قراه في البرنامج.
-- - التوقيت: من الساعة كام لحد الساعة كام (بتوقيت القاهرة) من الإعدادات. برّه الوقت ده الإشعارات بتستنى.
-- - الإرسال من Edge Function اسمها push بمفاتيح VAPID في أسرار Supabase (التشفير جوه الدالة، مش هنا).
-- - زرار "اتقرا" في الإشعار بيشتغل بـ token عشوائي لمرة واحدة (push_ack) من غير تسجيل دخول.
-- - الاشتراكات خاصة بالجهاز، فما بتدخلش في النسخة الاحتياطية (بعد الاسترجاع كل واحد بيفعّل من جهازه تاني).

create table public.push_subscriptions (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references public.shops(id),
  profile_id uuid not null references auth.users(id),
  endpoint text not null check (length(endpoint) between 12 and 1000 and endpoint like 'https://%'),
  p256dh text not null check (p256dh ~ '^[A-Za-z0-9_-]{80,100}$'),
  auth text not null check (auth ~ '^[A-Za-z0-9_-]{16,44}$'),
  locale text not null default 'ar' check (locale in ('ar', 'en')),
  user_agent text check (length(user_agent) <= 300),
  fails integer not null default 0,
  last_ok_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);
create unique index push_subscriptions_endpoint on public.push_subscriptions(endpoint) where deleted_at is null;
create index push_subscriptions_profile on public.push_subscriptions(profile_id) where deleted_at is null;

create table public.push_sent (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references public.shops(id),
  profile_id uuid not null references auth.users(id),
  key text not null check (length(key) <= 120),
  ack_token text not null unique,
  acked_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  unique (profile_id, key)
);

alter table public.push_subscriptions enable row level security;
alter table public.push_sent enable row level security;
create trigger set_updated_at before update on public.push_subscriptions for each row execute function public.tg_set_updated_at();
create trigger set_updated_at before update on public.push_sent for each row execute function public.tg_set_updated_at();
create trigger block_delete before delete on public.push_subscriptions for each row execute function public.tg_block_delete();
create trigger block_delete before delete on public.push_sent for each row execute function public.tg_block_delete();

-- كل واحد يشوف أجهزته هو بس (في محله). الكتابة من الدوال بس
create policy push_subs_select on public.push_subscriptions for select to authenticated
  using (profile_id = auth.uid() and shop_id = public.current_shop_id() and deleted_at is null);
create policy push_sent_select on public.push_sent for select to authenticated
  using (profile_id = auth.uid() and shop_id = public.current_shop_id());
grant select on public.push_subscriptions, public.push_sent to authenticated;

-- ---------- التوقيت (الإعدادات ← التنبيهات) ----------
-- من/لحد بتوقيت القاهرة (0-24). الافتراضي من 9 الصبح لـ 9 بالليل. من = لحد يعني طول اليوم
create or replace function public.push_window(p_shop uuid) returns int[]
language sql stable security definer set search_path = public as $$
  select array[
    least(greatest(coalesce((s.extras -> 'reminders' ->> 'push_from')::int, 9), 0), 24),
    least(greatest(coalesce((s.extras -> 'reminders' ->> 'push_to')::int, 21), 0), 24)]
  from public.shops s where s.id = p_shop
$$;
revoke execute on function public.push_window(uuid) from public, anon, authenticated;

create or replace function public.push_window_open(p_shop uuid, p_at timestamptz) returns boolean
language plpgsql stable security definer set search_path = public as $$
declare w int[] := public.push_window(p_shop); h int := extract(hour from p_at at time zone 'Africa/Cairo')::int;
begin
  if w is null then return false; end if;
  if w[1] = w[2] or (w[1] = 0 and w[2] = 24) then return true; end if;
  if w[1] < w[2] then return h >= w[1] and h < w[2]; end if;
  -- بيعدّي نص الليل (مثلًا من 20 لـ 2)
  return h >= w[1] or h < w[2];
end $$;
revoke execute on function public.push_window_open(uuid, timestamptz) from public, anon, authenticated;

-- ---------- الاشتراك (من الجهاز نفسه) ----------
create or replace function public.save_push_subscription(p_endpoint text, p_p256dh text, p_auth text, p_locale text default 'ar', p_user_agent text default null)
returns uuid
language plpgsql security definer set search_path = public as $$
declare s uuid := public.current_shop_id(); me uuid := auth.uid(); rid uuid;
begin
  if s is null or me is null then raise exception 'E_FORBIDDEN'; end if;
  if p_endpoint is null or p_endpoint !~ '^https://[^/@\s]+\.[^/@\s]+/' or length(p_endpoint) > 1000
     or coalesce(p_p256dh, '') !~ '^[A-Za-z0-9_-]{80,100}$' or coalesce(p_auth, '') !~ '^[A-Za-z0-9_-]{16,44}$' then
    raise exception 'E_BAD_INPUT';
  end if;
  -- نفس المتصفح بقى لمستخدم تاني (حد خرج وحد دخل): الاشتراك بينتقل لللي داخل دلوقتي بس
  select id into rid from public.push_subscriptions where endpoint = p_endpoint and deleted_at is null for update;
  if rid is not null then
    update public.push_subscriptions set shop_id = s, profile_id = me, p256dh = p_p256dh, auth = p_auth,
      locale = case when p_locale = 'en' then 'en' else 'ar' end, user_agent = left(p_user_agent, 300), fails = 0
    where id = rid;
  else
    rid := gen_random_uuid();
    insert into public.push_subscriptions(id, shop_id, profile_id, endpoint, p256dh, auth, locale, user_agent)
    values (rid, s, me, p_endpoint, p_p256dh, p_auth, case when p_locale = 'en' then 'en' else 'ar' end, left(p_user_agent, 300));
  end if;
  -- 10 أجهزة بالكتير لكل مستخدم (الأقدم بيتشال)
  update public.push_subscriptions set deleted_at = now()
   where profile_id = me and deleted_at is null
     and id not in (select id from public.push_subscriptions where profile_id = me and deleted_at is null order by updated_at desc limit 10);
  return rid;
end $$;
revoke execute on function public.save_push_subscription(text, text, text, text, text) from public, anon;
grant execute on function public.save_push_subscription(text, text, text, text, text) to authenticated;

create or replace function public.remove_push_subscription(p_endpoint text) returns void
language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'E_FORBIDDEN'; end if;
  update public.push_subscriptions set deleted_at = now() where endpoint = p_endpoint and profile_id = auth.uid() and deleted_at is null;
end $$;
revoke execute on function public.remove_push_subscription(text) from public, anon;
grant execute on function public.remove_push_subscription(text) to authenticated;

-- ---------- الإرسال (Edge Function push بمفتاح السيرفر بس) ----------
-- بيرجّع الإشعارات الجديدة لكل جهاز مشترك (لو التوقيت مفتوح)، وبيسجّلها إنها اتبعتت عشان ما تتكررش.
-- لكل مستخدم: الإشعارات بتتحسب بصلاحياته هو بالظبط (نفس دالة الجرس وهو داخل).
create or replace function public.push_due(p_now timestamptz default now())
returns table(sub_id uuid, endpoint text, p256dh text, auth text, locale text, key text, kind text, args jsonb, link text, token text)
language plpgsql security definer set search_path = public, extensions, pg_temp as $$
#variable_conflict use_column
declare
  u record;
  old_claims text := current_setting('request.jwt.claims', true);
  old_sub text := current_setting('request.jwt.claim.sub', true);
begin
  drop table if exists pg_temp._push_new;
  create temp table _push_new(profile_id uuid, key text, kind text, args jsonb, link text, token text) on commit drop;
  for u in
    select distinct ps.profile_id, ps.shop_id
      from public.push_subscriptions ps
      join public.profiles p on p.id = ps.profile_id and p.shop_id = ps.shop_id and p.deleted_at is null
      join public.shops sh on sh.id = ps.shop_id and sh.suspended_at is null
     where ps.deleted_at is null and public.push_window_open(ps.shop_id, p_now)
  loop
    -- نفس صلاحيات المستخدم: كأنه داخل (aal2 لأنه فعّل الاشتراك وهو داخل بالتحقق بخطوتين لو مفعّل)
    perform set_config('request.jwt.claims', jsonb_build_object('sub', u.profile_id, 'role', 'authenticated', 'aal', 'aal2')::text, true);
    perform set_config('request.jwt.claim.sub', u.profile_id::text, true);
    begin
      insert into _push_new
      select u.profile_id, n.key, n.kind, n.args, n.link, encode(gen_random_bytes(16), 'hex')
        from public.my_notifications() n
       where not exists (select 1 from public.push_sent x where x.profile_id = u.profile_id and x.key = n.key)
         and not exists (select 1 from public.notification_reads r where r.profile_id = u.profile_id and r.key = n.key and r.deleted_at is null)
       limit 50;
    exception when others then
      -- مستخدم اتقفل أو اتشالت صلاحيته: ما يوصلوش حاجة
      null;
    end;
  end loop;
  perform set_config('request.jwt.claims', coalesce(old_claims, ''), true);
  perform set_config('request.jwt.claim.sub', coalesce(old_sub, ''), true);

  insert into public.push_sent(shop_id, profile_id, key, ack_token)
  select p.shop_id, n.profile_id, n.key, n.token from _push_new n join public.profiles p on p.id = n.profile_id
  on conflict (profile_id, key) do nothing;

  return query
  select ps.id, ps.endpoint, ps.p256dh, ps.auth, ps.locale, n.key, n.kind, n.args, n.link, n.token
    from _push_new n
    join public.push_subscriptions ps on ps.profile_id = n.profile_id and ps.deleted_at is null
   order by ps.id, n.key;
end $$;
revoke execute on function public.push_due(timestamptz) from public, anon, authenticated;
grant execute on function public.push_due(timestamptz) to service_role;

-- نتيجة الإرسال: الجهاز اللي لغى الاشتراك (404/410) أو فشل 5 مرات ورا بعض بيتشال
create or replace function public.push_result(p_rows jsonb) returns integer
language plpgsql security definer set search_path = public as $$
declare r jsonb; n int := 0; st int;
begin
  if jsonb_typeof(p_rows) <> 'array' or jsonb_array_length(p_rows) > 5000 then raise exception 'E_BAD_INPUT'; end if;
  for r in select * from jsonb_array_elements(p_rows) loop
    st := coalesce((r ->> 'status')::int, 0);
    if st between 200 and 299 then
      update public.push_subscriptions set fails = 0, last_ok_at = now() where id = (r ->> 'sub_id')::uuid;
    elsif st in (404, 410) or coalesce((r ->> 'gone')::boolean, false) then
      update public.push_subscriptions set deleted_at = now() where id = (r ->> 'sub_id')::uuid and deleted_at is null;
      n := n + 1;
    else
      update public.push_subscriptions set fails = fails + 1, deleted_at = case when fails + 1 >= 5 then now() else deleted_at end
       where id = (r ->> 'sub_id')::uuid and deleted_at is null;
    end if;
  end loop;
  return n;
end $$;
revoke execute on function public.push_result(jsonb) from public, anon, authenticated;
grant execute on function public.push_result(jsonb) to service_role;

-- ---------- زرار "اتقرا" من الإشعار نفسه (من غير تسجيل دخول) ----------
-- token عشوائي 128 بت لإشعار واحد، بيشتغل مرة واحدة وفي خلال 7 أيام. بيعلّم الإشعار مقروء في الجرس بس.
create or replace function public.push_ack(p_token text) returns boolean
language plpgsql security definer set search_path = public as $$
declare x public.push_sent;
begin
  if p_token is null or p_token !~ '^[0-9a-f]{32}$' then return false; end if;
  update public.push_sent set acked_at = now()
   where ack_token = p_token and acked_at is null and deleted_at is null and created_at > now() - interval '7 days'
  returning * into x;
  if x.id is null then return false; end if;
  insert into public.notification_reads(shop_id, profile_id, key) values (x.shop_id, x.profile_id, x.key)
  on conflict (profile_id, key) do nothing;
  return true;
end $$;
revoke execute on function public.push_ack(text) from public;
grant execute on function public.push_ack(text) to anon, authenticated;
