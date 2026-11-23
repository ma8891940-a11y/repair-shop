-- ============================================================
-- 0067: بند 2 من qa-37: ضغطتين متزامنتين على الحفظ = عملية واحدة من غير خطأ.
-- - كل دوال الفلوس بتبدأ بـ ledger_idem(رقم العملية): لو اتسجلت قبل كده بترجع نفس القيد.
-- - المشكلة: طلبين في نفس اللحظة الاتنين بيعدّوا الفحص، والتاني بيقع بـ unique violation على idem_key
--   (البيانات سليمة، بس المستخدم بيشوف خطأ والطابور بتاع "من غير نت" بيعيد).
-- - الحل: قفل قصير على رقم العملية لحد آخر الـ transaction. الطلب التاني بيستنى، وبعدين بيلاقي القيد ويرجّعه.
-- ============================================================

-- ledger_idem: (src: 0008_ledger.sql) + قفل على رقم العملية (volatile بدل stable عشان القفل)
create or replace function public.ledger_idem(p uuid) returns uuid
language plpgsql volatile security definer set search_path = public as $$
declare r uuid;
begin
  if p is null then return null; end if;
  perform pg_advisory_xact_lock(hashtextextended(p::text, 0));
  select id into r from public.journal_entries where idem_key = p and shop_id = public.current_shop_id();
  return r;
end $$;
revoke execute on function public.ledger_idem(uuid) from public, anon, authenticated;
