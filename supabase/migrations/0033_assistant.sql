-- ============================================================
-- 0033: المساعد الذكي في البرنامج كله (S3)
--
-- الإعدادات في shops.extras -> 'assistant' (صاحب المحل بيغيّرها من الإعدادات ← المساعد):
--   enabled  : المساعد كله شغال ولا لأ (الافتراضي شغال)
--   areas    : كل مكان لوحده. المالية مقفولة افتراضيًا (فيها تنبيه عن الطبقة المجانية)
--   staff    : مين من الموظفين يستخدمه (الاستقبال، والفني). صاحب المحل دايمًا
--   daily    : حد يومي للمحل (أقل من حد الخطة أو زيه)
--
-- القواعد دي بتتأكد هنا في قاعدة البيانات (مش في الشاشة بس): الـ Edge Function بتنادي
-- ai_take_area قبل أي سؤال، ولو المكان مقفول أو الموظف مش مسموح له أو الحد خلص بترفض.
-- السؤال والإجابة ما بيتخزنوش. اللي بيتسجل: المحل، والمستخدم، والمكان، والوقت بس.
-- ============================================================

alter table public.ai_usage add column if not exists area text not null default 'tech';

-- الأماكن، ومين يقدر يستخدم كل واحد حسب دوره (فوق إعدادات صاحب المحل)
--   tech      : تلميحات التشخيص للجهاز            (كل الموظفين)
--   intake    : اقتراحات وقت الاستلام               (صاحب المحل والاستقبال)
--   inventory : اقتراحات الشراء                    (صاحب المحل)
--   finance   : أسئلة المالية والملخص الأسبوعي      (صاحب المحل)
--   customers : مسودة رسالة واتساب                  (صاحب المحل والاستقبال)
--   reports   : ملخص مكتوب للتقارير                 (صاحب المحل)
--   screen    : الزرار العايم (شرح الشاشة)          (كل الموظفين)
create or replace function public.assistant_area_roles(p_area text) returns text[]
language sql immutable set search_path = public as $$
  select case p_area
    when 'tech' then array['owner', 'reception', 'technician']
    when 'screen' then array['owner', 'reception', 'technician']
    when 'intake' then array['owner', 'reception']
    when 'customers' then array['owner', 'reception']
    when 'inventory' then array['owner']
    when 'finance' then array['owner']
    when 'reports' then array['owner']
    else array[]::text[] end
$$;
revoke all on function public.assistant_area_roles(text) from public, anon, authenticated;

-- الإعدادات بعد الافتراضي (نفس الافتراضي في src/lib/assistantSettings.ts، وفيه اختبار بيقارنهم)
create or replace function public.assistant_settings(s uuid) returns jsonb
language sql stable security definer set search_path = public as $$
  select jsonb_build_object(
    'enabled', coalesce((a ->> 'enabled')::boolean, true),
    'areas', jsonb_build_object(
      'tech', coalesce((a -> 'areas' ->> 'tech')::boolean, true),
      'intake', coalesce((a -> 'areas' ->> 'intake')::boolean, true),
      'inventory', coalesce((a -> 'areas' ->> 'inventory')::boolean, true),
      'finance', coalesce((a -> 'areas' ->> 'finance')::boolean, false),
      'customers', coalesce((a -> 'areas' ->> 'customers')::boolean, true),
      'reports', coalesce((a -> 'areas' ->> 'reports')::boolean, true),
      'screen', coalesce((a -> 'areas' ->> 'screen')::boolean, true)),
    'staff', jsonb_build_object(
      'reception', coalesce((a -> 'staff' ->> 'reception')::boolean, true),
      'technician', coalesce((a -> 'staff' ->> 'technician')::boolean, true)),
    'daily', case when jsonb_typeof(a -> 'daily') = 'number' and (a ->> 'daily')::numeric >= 0 then floor((a ->> 'daily')::numeric)::int else null end)
  from (select coalesce(extras -> 'assistant', '{}'::jsonb) a from public.shops where id = s) x
$$;
revoke all on function public.assistant_settings(uuid) from public, anon, authenticated;

-- بتتنادى من الـ Edge Function قبل أي سؤال: الصلاحية، والإعدادات، والحد اليومي، وبتسجل الاستخدام
create or replace function public.ai_take_area(p_area text) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  s uuid := public.member_shop_id();
  r text := public.member_role();
  st jsonb;
  pl public.plans;
  lim int;
  n int;
begin
  if s is null or r not in ('owner', 'reception', 'technician') then raise exception 'E_FORBIDDEN'; end if;
  if not (r = any (public.assistant_area_roles(p_area))) then raise exception 'E_FORBIDDEN'; end if;
  st := public.assistant_settings(s);
  if not (st ->> 'enabled')::boolean or not coalesce((st -> 'areas' ->> p_area)::boolean, false) then raise exception 'E_AI_OFF'; end if;
  if r <> 'owner' and not coalesce((st -> 'staff' ->> r)::boolean, false) then raise exception 'E_AI_OFF'; end if;
  pl := public.shop_plan(s);
  lim := least(pl.ai_daily, coalesce((st ->> 'daily')::int, pl.ai_daily));
  -- قفل للمحل ده بس، عشان سؤالين في نفس اللحظة ما يعدّوش الحد
  perform pg_advisory_xact_lock(hashtext('ai_take:' || s::text));
  select count(*) into n from public.ai_usage
    where shop_id = s and created_at >= date_trunc('day', now() at time zone 'Africa/Cairo') at time zone 'Africa/Cairo';
  if n >= lim then raise exception 'E_PLAN_LIMIT'; end if;
  insert into public.ai_usage(shop_id, user_id, area) values (s, auth.uid(), p_area);
  return jsonb_build_object('left', lim - n - 1, 'limit', lim);
end $$;
revoke all on function public.ai_take_area(text) from public, anon;
grant execute on function public.ai_take_area(text) to authenticated;

-- (0033) نفس ai_take من 0017 والفرق: بقت بتمشي على إعدادات المساعد كمان (مكان "التشخيص")
create or replace function public.ai_take() returns jsonb
language plpgsql security definer set search_path = public as $$
declare r jsonb;
begin
  r := public.ai_take_area('tech');
  return jsonb_build_object('left', (r ->> 'left')::int);
end $$;

-- للشاشة: الإعدادات، والمستخدم ده يقدر يستخدم أنهي أماكن، واستخدام النهارده من الحد
create or replace function public.assistant_info() returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare
  s uuid := public.member_shop_id();
  r text := public.member_role();
  st jsonb;
  pl public.plans;
  lim int;
  used int;
  allowed jsonb := '{}'::jsonb;
  a text;
begin
  if s is null then raise exception 'E_FORBIDDEN'; end if;
  st := public.assistant_settings(s);
  pl := public.shop_plan(s);
  lim := least(pl.ai_daily, coalesce((st ->> 'daily')::int, pl.ai_daily));
  select count(*) into used from public.ai_usage
    where shop_id = s and created_at >= date_trunc('day', now() at time zone 'Africa/Cairo') at time zone 'Africa/Cairo';
  foreach a in array array['tech', 'intake', 'inventory', 'finance', 'customers', 'reports', 'screen'] loop
    allowed := allowed || jsonb_build_object(a,
      (st ->> 'enabled')::boolean
      and coalesce((st -> 'areas' ->> a)::boolean, false)
      and r = any (public.assistant_area_roles(a))
      and (r = 'owner' or coalesce((st -> 'staff' ->> r)::boolean, false)));
  end loop;
  return jsonb_build_object('settings', st, 'allowed', allowed, 'used', used, 'limit', lim, 'plan_limit', pl.ai_daily);
end $$;
revoke all on function public.assistant_info() from public, anon;
grant execute on function public.assistant_info() to authenticated;

-- اقتراحات الشراء: اللي خرج من كل صنف آخر 30 يوم (بيع أو اتركب في جهاز)، من غير القيود الملغية. صاحب المحل بس
create or replace function public.items_sold30() returns table(item_id uuid, qty bigint)
language plpgsql stable security definer set search_path = public as $$
begin
  perform public.ledger_require(array['owner']::public.app_role[]);
  return query
  select m.item_id, (-sum(m.qty))::bigint
  from public.stock_moves m
  join public.journal_entries e on e.id = m.entry_id
  where e.shop_id = public.current_shop_id()
    and m.qty < 0
    and e.occurred_at >= now() - interval '30 days'
    and e.reverses_id is null
    and not exists (select 1 from public.journal_entries r where r.reverses_id = e.id)
  group by m.item_id;
end $$;
revoke execute on function public.items_sold30() from public, anon;
grant execute on function public.items_sold30() to authenticated;
