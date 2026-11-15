-- 0042: U4: هوية صاحب المحل في التطبيق (shops.extras.app = {name, logo, accent}).
-- رابط الدخول الخاص بالمحل (#/?shop=رقم المحل) بيجيب الاسم واللوجو واللون بس، من غير تسجيل دخول.
-- مفيش أي بيانات تانية عن المحل أو عملائه بتطلع من هنا.
create or replace function public.public_app_brand(p_shop uuid) returns jsonb
language sql stable security definer set search_path = public as $$
  select jsonb_build_object(
    'name', left(nullif(trim(s.extras -> 'app' ->> 'name'), ''), 40),
    'logo', case when (s.extras -> 'app' ->> 'logo') like 'data:image/%' and length(s.extras -> 'app' ->> 'logo') <= 400000 then s.extras -> 'app' ->> 'logo' end,
    'accent', case when (s.extras -> 'app' ->> 'accent') ~ '^#[0-9a-fA-F]{6}$' then s.extras -> 'app' ->> 'accent' end)
  from public.shops s where s.id = p_shop and s.suspended_at is null and s.deleted_at is null
$$;
revoke execute on function public.public_app_brand(uuid) from public;
grant execute on function public.public_app_brand(uuid) to anon, authenticated;
