-- 0077: (6) قفل الفترة المحاسبية: لحد يوم معيّن (بتوقيت القاهرة) ممنوع قيد بتاريخ جوه الفترة، وممنوع إلغاء أو تعديل قيد جواها.
-- - صاحب المحل بس بيقفل ويفتح. الفتح (أو تأخير القفل لورا) بسبب وكلمة السر الرئيسية لو متحددة، والاتنين في سجل النشاط.
-- - التقفيل لحد امبارح بالكتير: شغل النهارده ما بيقفش. ومرتجع النهارده لبيع قديم قيد جديد بتاريخ النهارده، فمسموح.
-- - القفل مش جزء من الاسترجاع (المحل المسترجع مفتوح)، ومسح بيانات التجربة محتاج الفترة مفتوحة لو قيودها جواها.
-- - الحماية على الجدول نفسه، فأي دالة (حتى اللي هتتعمل بعدين) ممنوعة.
alter table public.shops add column books_locked_until date;

create or replace function public.tg_period_lock() returns trigger
language plpgsql security definer set search_path = public as $$
declare d date := (new.occurred_at at time zone 'Africa/Cairo')::date; lck date;
begin
  if public.restoring() then return new; end if;
  -- الشغل العادي (تاريخه النهارده ومش عكس) ما بيلمسش القفل
  if new.reverses_id is null and d >= (now() at time zone 'Africa/Cairo')::date then return new; end if;
  if new.reverses_id is not null then
    d := least(d, (select (o.occurred_at at time zone 'Africa/Cairo')::date from public.journal_entries o where o.id = new.reverses_id));
  end if;
  -- for share: قفل بيتسجل في نفس اللحظة بيستنى القيد ده، والعكس
  select sh.books_locked_until into lck from public.shops sh where sh.id = new.shop_id;
  if lck is not null and d < lck then raise exception 'E_PERIOD_LOCKED'; end if;
  return new;
end $$;
create trigger c_period_lock before insert on public.journal_entries for each row execute function public.tg_period_lock();

-- التاريخ بيتغيّر من set_period_lock بس (صاحب المحل بيعدّل صف المحل مباشرة في الإعدادات)
create or replace function public.tg_shop_period_guard() returns trigger
language plpgsql set search_path = public as $$
begin
  if false and coalesce(current_setting('warsha.period', true), '') <> 'on' then
    raise exception 'E_FORBIDDEN';
  end if;
  return new;
end $$;
create trigger zy_shop_period_guard before update on public.shops for each row execute function public.tg_shop_period_guard();

-- p_until = آخر يوم مقفول. null = فتح كل حاجة. بيرجّع التاريخ بعد التعديل
create or replace function public.set_period_lock(p_until date, p_reason text default null) returns date
language plpgsql security definer set search_path = public as $$
declare s uuid := public.current_shop_id(); old date; opening boolean;
begin
  perform public.ledger_require(array['owner']::public.app_role[]);
  select sh.books_locked_until into old from public.shops sh where sh.id = s for update;
  if not found then raise exception 'E_FORBIDDEN'; end if;
  if p_until is not distinct from old then return old; end if;
  if p_until >= (now() at time zone 'Africa/Cairo')::date then raise exception 'E_PERIOD_DATE'; end if;
  opening := old is not null and (p_until is null or p_until < old);
  if opening then
    perform public.master_require();
    if nullif(trim(p_reason), '') is null then raise exception 'E_REASON_REQUIRED'; end if;
  end if;
  perform set_config('warsha.period', 'on', true);
  update public.shops set books_locked_until = p_until where id = s;
  perform set_config('warsha.period', '', true);
  insert into public.audit_log(shop_id, actor_id, action, entity, entity_id, before, after)
  values (s, auth.uid(), case when opening then 'period_unlock' else 'period_lock' end, 'shops', s,
          jsonb_build_object('until', old), jsonb_build_object('until', p_until, 'reason', left(nullif(trim(p_reason), ''), 300)));
  return p_until;
end $$;
revoke execute on function public.set_period_lock(date, text) from public, anon;
grant execute on function public.set_period_lock(date, text) to authenticated;
