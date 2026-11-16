-- 0047: C3: التحقق بخطوتين (2FA) لصاحب المحل، اختياري، بتطبيق زي Google Authenticator (TOTP مجاني جوه Supabase Auth).
-- الحماية في قاعدة البيانات: أي حساب فعّل 2FA ما يوصلش لبيانات المحل إلا لو الدخول عدّى الخطوة التانية (aal2).
-- يعني لو كلمة السر اتسرقت لوحدها، البيانات ما تتفتحش.

create or replace function public.mfa_ok() returns boolean
language sql stable security definer set search_path = public as $$
  select coalesce(auth.jwt() ->> 'aal', 'aal1') = 'aal2'
    or not exists (select 1 from auth.mfa_factors f where f.user_id = auth.uid() and f.status::text = 'verified')
$$;
revoke execute on function public.mfa_ok() from public, anon;
grant execute on function public.mfa_ok() to authenticated;

-- current_shop_id: (src: 0017_growth.sql) + 2FA
create or replace function public.current_shop_id() returns uuid
language sql stable security definer set search_path = public as $$
  select p.shop_id from public.profiles p join public.shops s on s.id = p.shop_id
  where p.id = auth.uid() and p.deleted_at is null and p.role::text <> 'marketing' and s.suspended_at is null and public.mfa_ok()
$$;
