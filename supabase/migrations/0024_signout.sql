-- 0024: الخروج من غير أخطاء لما الجلسة تكون منتهية أو المستخدم اتحذف
--
-- الواجهة كانت بتنادي /auth/v1/logout، وده بيرجع 403 لو المستخدم اتحذف أو الجلسة اتلغت من السيرفر،
-- والمتصفح بيكتب الخطأ في الـ console. دلوقتي الواجهة بتنادي الدالة دي (بترجع نجاح دايمًا)، وبعدها بتمسح
-- الجلسة من الجهاز بس.
--
-- end_my_session: بتلغي الجلسة الحالية بس (والـ refresh tokens بتاعتها) لو لسه موجودة. لو مش موجودة: مفيش حاجة.
create or replace function public.end_my_session() returns void
language plpgsql security definer set search_path = public as $$
declare sid uuid;
begin
  begin
    sid := nullif(auth.jwt() ->> 'session_id', '')::uuid;
  exception when others then
    sid := null;
  end;
  if sid is null or auth.uid() is null then return; end if;
  begin
    delete from auth.sessions where id = sid and user_id = auth.uid();
  exception when insufficient_privilege or undefined_table then
    -- لو صلاحيات المشروع ما بتسمحش: الجلسة بتتمسح من الجهاز بس (زي "الخروج من الجهاز ده")
    null;
  end;
end $$;
revoke execute on function public.end_my_session() from public, anon;
grant execute on function public.end_my_session() to authenticated;
