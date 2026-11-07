-- المراجعة الأمنية الشاملة (2026-11-07)
-- حالة التقييم في صفحة التتبع (rating_state) كانت الدالة العامة الوحيدة من غير حد للمحاولات.
-- دلوقتي زي باقي دوال الصفحة العامة: بعد 10 محاولات غلط من نفس الجهاز في 15 دقيقة بتقفل (E_RATE_LIMIT)،
-- والرمز الغلط بيتسجل كمحاولة فاشلة. والنتيجة زي ما هي: هل يقدر يقيّم، والنجوم لو قيّم، ومفيش أي بيانات تانية.
create or replace function public.rating_state(p_token text) returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare d public.devices; k text := public.tracking_guard(null);
begin
  select * into d from public.devices where tracking_token = p_token and deleted_at is null;
  if not found then
    insert into public.tracking_attempts(client_key, order_no, success) values (k, null, false);
    return jsonb_build_object('can_rate', false);
  end if;
  return jsonb_build_object('can_rate', d.status = 'delivered' and not exists (select 1 from public.device_ratings r where r.device_id = d.id),
                            'stars', (select stars from public.device_ratings r where r.device_id = d.id));
end $$;
revoke execute on function public.rating_state(text) from public;
grant execute on function public.rating_state(text) to anon, authenticated;
