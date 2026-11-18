-- 0059: U6 (مراجعة عزل الفروع): ترقيم الطلبات لكل فرع
--
-- اختبار U6 (tests/db/u6.test.ts) لقى إن موظف فرع بيقدر يقرا عدّاد أرقام طلبات الفرع التاني (order_counters)،
-- وده بيكشف عدد شغل الفرع التاني في السنة. البرنامج نفسه ما بيقراش الجدول ده خالص (الترقيم جوه قاعدة البيانات)،
-- فالقراية بقت لفروع الموظف بس (صاحب المحل بيشوف الكل زي الأول).
drop policy if exists counters_select on public.order_counters;
create policy counters_select_branch on public.order_counters for select to authenticated
  using (shop_id = public.current_shop_id() and (branch_id is null or branch_id in (select unnest(public.my_branch_ids()))));
