-- التتبع برقم الطلب وآخر 4 أرقام: رقم الطلب بيتكرر بين المحلات، وممكن عميلين في محلين يشتركوا في آخر 4 أرقام.
-- قبل كده كان بيرجّع أحدث جهاز (ممكن يبقى جهاز محل تاني). دلوقتي لو فيه أكتر من جهاز مطابق، ما بيرجّعش أي واحد،
-- وبيطلب من العميل يمسح الـ QR (الرمز السري فريد). وده بيحمي كمان الموافقة على التكلفة من إنها توصل لجهاز غلط.
create or replace function public.tracking_find(p_order text, p_last4 text, p_token text)
returns public.devices
language plpgsql stable security definer set search_path = public as $$
declare d public.devices; n int;
begin
  if p_token is not null and length(p_token) >= 16 then
    select * into d from public.devices where tracking_token = p_token and deleted_at is null;
    if found and (p_order is null or d.order_no = trim(p_order)) then return d; end if;
    return null;
  end if;
  if p_order is null or p_last4 is null or p_last4 !~ '^[0-9]{4}$' then return null; end if;
  select count(*) into n
  from public.devices dv join public.customers c on c.id = dv.customer_id
  where dv.order_no = trim(p_order) and right(c.phone, 4) = p_last4 and dv.deleted_at is null;
  if n > 1 then raise exception 'E_TRACK_AMBIGUOUS'; end if;
  select dv.* into d
  from public.devices dv join public.customers c on c.id = dv.customer_id
  where dv.order_no = trim(p_order) and right(c.phone, 4) = p_last4 and dv.deleted_at is null;
  if found then return d; end if;
  return null;
end $$;
revoke execute on function public.tracking_find(text, text, text) from public, anon, authenticated;
