-- لوحة المشرف: المحلات على صفحات (50 في المرة) وبحث بالاسم، بدل ما كلهم يتجابوا مرة واحدة.
-- ليه: Supabase بيرجّع أقصى 1000 صف في الطلب، وحساب الأجهزة والموظفين لكل المحلات مرة واحدة كان تقيل.
-- الحسابات دلوقتي بتتعمل للمحلات اللي في الصفحة بس. ومفيش أي بيانات عملاء زي الأول.
drop function if exists public.admin_shops();

create or replace function public.admin_shops(p_search text default null, p_limit integer default 50, p_offset integer default 0)
returns table(id uuid, name text, created_at timestamptz, plan text, suspended boolean, staff integer, devices integer, devices_month integer, last_activity timestamptz, total integer)
language plpgsql stable security definer set search_path = public as $$
#variable_conflict use_column
declare q text := nullif(trim(coalesce(p_search, '')), '');
begin
  if not public.is_platform_admin() then raise exception 'E_FORBIDDEN'; end if;
  return query
  with matched as (
    select s.* from public.shops s
    where q is null or s.name ilike '%' || replace(replace(replace(q, '\', '\\'), '%', '\%'), '_', '\_') || '%'
  ), page as (
    select * from matched order by created_at desc, id limit greatest(1, least(coalesce(p_limit, 50), 200)) offset greatest(0, coalesce(p_offset, 0))
  )
  select s.id, s.name, s.created_at, s.plan_code, s.suspended_at is not null,
         (select count(*)::int from public.profiles p where p.shop_id = s.id and p.deleted_at is null),
         (select count(*)::int from public.devices d where d.shop_id = s.id and d.deleted_at is null),
         (select count(*)::int from public.devices d where d.shop_id = s.id and d.received_at >= date_trunc('month', now())),
         (select max(a.created_at) from public.audit_log a where a.shop_id = s.id),
         (select count(*)::int from matched)
  from page s order by s.created_at desc, s.id;
end $$;
revoke execute on function public.admin_shops(text, integer, integer) from public, anon;
grant execute on function public.admin_shops(text, integer, integer) to authenticated;
