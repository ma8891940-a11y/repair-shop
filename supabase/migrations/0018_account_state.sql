-- المرحلة 6 (تكملة): حالة الحساب للواجهة
-- مدير التسويق والمحل الموقوف ملهمش محل في الصلاحيات العادية (current_shop_id فاضي)،
-- فالواجهة محتاجة تعرف هي فين: ملف المستخدم نفسه، واسم المحل، والدور، وهل المحل موقوف، وهل هو مشرف المنصة.
-- الدالة بترجّع بيانات المستخدم نفسه ومحله بس، ومفيهاش أي بيانات أجهزة أو عملاء أو فلوس.
create or replace function public.my_account() returns jsonb
language sql stable security definer set search_path = public as $$
  select jsonb_build_object(
    'profile', (select jsonb_build_object('id', p.id, 'shop_id', p.shop_id, 'full_name', p.full_name, 'email', p.email, 'role', p.role::text, 'deleted_at', p.deleted_at)
                from public.profiles p where p.id = auth.uid()),
    'shop', (select jsonb_build_object('id', s.id, 'name', s.name, 'theme', s.theme, 'locale', s.locale, 'suspended', s.suspended_at is not null)
             from public.profiles p join public.shops s on s.id = p.shop_id where p.id = auth.uid() and p.deleted_at is null),
    'is_admin', public.is_platform_admin())
$$;
revoke all on function public.my_account() from public, anon;
grant execute on function public.my_account() to authenticated;
