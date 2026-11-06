-- حد المحاولات على رقم الطلب: بيعدّ التخمينات المختلفة بس
--
-- المشكلة: رقم الطلب (زي 2026-0001) بيتكرر بين المحلات. لو القفل بيعدّ كل محاولة غلط،
-- عميل بيغلط في كتابة رقمه في محل، ممكن يقفل نفس الرقم على عميل في محل تاني.
-- الحل: القفل بيعدّ آخر 4 أرقام *المختلفة* اللي اتجربت على رقم الطلب ده (5 في 15 دقيقة).
-- العميل اللي بيكرر نفس الغلطة ما بيقفلش حاجة، واللي بيخمّن أرقام كتير بيتقفل بعد 5.
-- التخمين بيتخزن hash، مش الأرقام نفسها.

alter table public.tracking_attempts add column if not exists guess text;

create or replace function public.tracking_guess(p_order text, p_last4 text) returns text
language sql immutable set search_path = public, extensions as $$
  select case when p_order is null or p_last4 is null then null
    else encode(digest(upper(trim(p_order)) || ':' || trim(p_last4), 'sha256'), 'hex') end
$$;

create or replace function public.tracking_guard(p_order text) returns text
language plpgsql security definer set search_path = public as $$
declare k text := public.tracking_client_key();
begin
  if (select count(*) from public.tracking_attempts where client_key = k and not success and created_at > now() - interval '15 minutes') >= 10
     or (p_order is not null and (select count(distinct guess) from public.tracking_attempts
           where order_no = trim(p_order) and not success and guess is not null and created_at > now() - interval '15 minutes') >= 5) then
    raise exception 'E_RATE_LIMIT';
  end if;
  return k;
end $$;

create or replace function public.get_tracking(p_order text default null, p_last4 text default null, p_token text default null)
returns table(
  order_no text, status public.device_status, brand text, model text, received_at timestamptz,
  updated_at timestamptz, estimated_cost integer, final_cost integer, technician text,
  shop_name text, shop_phone text, shop_logo text, currency text, warranty_until timestamptz,
  can_decide boolean, decision text
)
language plpgsql security definer set search_path = public as $$
declare
  k text := public.tracking_guard(p_order);
  d public.devices;
begin
  d := public.tracking_find(p_order, p_last4, p_token);
  if d.id is null then
    -- مش بنرمي خطأ هنا عشان المحاولة الغلط تفضل متسجلة (الخطأ بيلغي التسجيل). النتيجة الفاضية = مش موجود
    insert into public.tracking_attempts(client_key, order_no, success, guess) values (k, trim(p_order), false, public.tracking_guess(p_order, p_last4));
    return;
  end if;
  insert into public.tracking_attempts(shop_id, client_key, order_no, success) values (d.shop_id, k, d.order_no, true);
  return query
  select d.order_no, d.status, d.brand, d.model, d.received_at,
    coalesce((select max(l.created_at) from public.status_log l where l.device_id = d.id), d.updated_at),
    dc.estimated_cost, dc.final_cost,
    -- اسم الفني: آخر فني غيّر الحالة (الاسم الأول بس)
    (select split_part(p.full_name, ' ', 1) from public.status_log l join public.profiles p on p.id = l.changed_by
       where l.device_id = d.id and p.role = 'technician' order by l.created_at desc limit 1),
    s.name, s.phone, s.logo_path, s.currency, d.warranty_until,
    d.status = 'awaiting_approval' and not exists (
      select 1 from public.quote_decisions q where q.device_id = d.id and q.created_at > coalesce(
        (select max(l.created_at) from public.status_log l where l.device_id = d.id and l.new_status = 'awaiting_approval'), d.received_at)),
    (select q.decision from public.quote_decisions q where q.device_id = d.id order by q.created_at desc limit 1)
  from public.shops s
  left join public.device_costs dc on dc.device_id = d.id and dc.deleted_at is null
  where s.id = d.shop_id;
end $$;

create or replace function public.decide_quote(p_decision text, p_order text default null, p_last4 text default null, p_token text default null)
returns public.device_status
language plpgsql security definer set search_path = public as $$
declare
  k text := public.tracking_guard(p_order);
  d public.devices;
  amt integer;
  next_status public.device_status;
begin
  if p_decision not in ('approved', 'rejected') then raise exception 'E_BAD_INPUT'; end if;
  d := public.tracking_find(p_order, p_last4, p_token);
  if d.id is null then
    insert into public.tracking_attempts(client_key, order_no, success, guess) values (k, trim(p_order), false, public.tracking_guess(p_order, p_last4));
    return null;
  end if;
  if d.status <> 'awaiting_approval' then raise exception 'E_BAD_TRANSITION'; end if;
  select coalesce(final_cost, estimated_cost) into amt from public.device_costs where device_id = d.id and deleted_at is null;
  insert into public.quote_decisions(shop_id, device_id, decision, amount, client_key) values (d.shop_id, d.id, p_decision, amt, k);
  next_status := case when p_decision = 'approved' then 'in_repair'::public.device_status else 'unrepairable'::public.device_status end;
  update public.devices set status = next_status where id = d.id;
  insert into public.audit_log(shop_id, actor_id, action, entity, entity_id, after)
  values (d.shop_id, null, 'customer_' || p_decision, 'devices', d.id, jsonb_build_object('amount', amt, 'order_no', d.order_no));
  return next_status;
end $$;

revoke execute on function public.get_tracking(text, text, text) from public;
revoke execute on function public.decide_quote(text, text, text, text) from public;
grant execute on function public.get_tracking(text, text, text) to anon, authenticated;
grant execute on function public.decide_quote(text, text, text, text) to anon, authenticated;
revoke execute on function public.tracking_guard(text) from public, anon, authenticated;
revoke execute on function public.tracking_guess(text, text) from public, anon, authenticated;
