-- ============================================================
-- 0035: قوائم الملء السريع في البرنامج كله (طلب صاحب المشروع 2026-11-10)
-- - قوايم جديدة: أنواع الأجهزة، والأعطال (زراير "+ عطل" في الاستلام)، وقطع الغيار، وأسباب المرتجع (جنب الماركات والموديلات والملحقات
--   والألوان والحالة الشكلية وتصنيفات الأصناف وأسباب الهالك والحالات الفرعية).
-- - الأعطال الجاهزة بالسعر (issue_presets) بقت بنفس الصلاحية.
-- - الإضافة والحذف من أي مكان بيستخدم القايمة، لكل الموظفين في المحل (القايمة واحدة للمحل).
-- - مين يضيف ويحذف: صاحب المحل دايمًا، والأدوار اللي يختارها في shops.extras.lists_edit (مثلًا ["reception"]).
-- - الحذف ناعم وبيخفي البند من الاختيار بس: البيانات القديمة متخزنة بالقيمة (نص)، فما بتتغيرش.
-- - كل إضافة وحذف بيتسجلوا في سجل النشاط (zz_audit على shop_lists من 0032).
-- - الصنف في المخزون ليه ماركة (اختياري) من نفس قايمة الماركات.
-- ============================================================

alter table public.shop_lists drop constraint if exists shop_lists_list_check;
alter table public.shop_lists add constraint shop_lists_list_check check (list in (
  'brands', 'models', 'accessories', 'colors', 'conditions', 'item_categories', 'write_off_reasons', 'sub_statuses',
  'device_types', 'issues', 'parts', 'return_reasons'));

-- مين يقدر يضيف أو يحذف من القوايم
create or replace function public.can_edit_lists() returns boolean
language sql stable security definer set search_path = public as $$
  select coalesce(public.current_app_role() = 'owner'
    or exists (select 1 from public.shops s where s.id = public.current_shop_id()
               and coalesce(s.extras -> 'lists_edit', '[]'::jsonb) ? public.current_app_role()::text), false)
$$;
revoke execute on function public.can_edit_lists() from public, anon;
grant execute on function public.can_edit_lists() to authenticated;

drop policy if exists lists_insert on public.shop_lists;
drop policy if exists lists_update on public.shop_lists;
create policy lists_insert on public.shop_lists for insert to authenticated
  with check (shop_id = public.current_shop_id() and public.can_edit_lists());
create policy lists_update on public.shop_lists for update to authenticated
  using (shop_id = public.current_shop_id() and public.can_edit_lists())
  with check (shop_id = public.current_shop_id());

-- الحذف من القايمة بس (deleted_at)، مش تعديل القيمة: عشان البيانات القديمة اللي اتسجلت بالقيمة تفضل مفهومة
create or replace function public.tg_list_value_fixed() returns trigger
language plpgsql as $$
begin
  if (new.value is distinct from old.value or new.list is distinct from old.list or new.parent is distinct from old.parent) and not public.restoring() then
    raise exception 'E_LIST_VALUE_FIXED';
  end if;
  return new;
end $$;
drop trigger if exists b_list_value_fixed on public.shop_lists;
create trigger b_list_value_fixed before update on public.shop_lists for each row execute function public.tg_list_value_fixed();

-- الأعطال الجاهزة: نفس صلاحية القوايم
drop policy if exists presets_insert on public.issue_presets;
drop policy if exists presets_update on public.issue_presets;
create policy presets_insert on public.issue_presets for insert to authenticated
  with check (shop_id = public.current_shop_id() and public.can_edit_lists());
create policy presets_update on public.issue_presets for update to authenticated
  using (shop_id = public.current_shop_id() and public.can_edit_lists())
  with check (shop_id = public.current_shop_id());

-- نوع الجهاز (اختياري، من قايمة أنواع الأجهزة)
alter table public.devices add column if not exists device_type text check (device_type is null or length(trim(device_type)) between 1 and 60);

-- ماركة الصنف (اختياري)
alter table public.items add column if not exists brand text check (brand is null or length(trim(brand)) between 1 and 60);
create index if not exists items_brand on public.items(shop_id, brand) where deleted_at is null and brand is not null;

-- المخزون بماركة الصنف (نفس 0034 + عمود brand)
drop function if exists public.items_stock(boolean);
create or replace function public.items_stock(p_all boolean default false) returns table(id uuid, kind text, name text, sku text, sale_price integer, qty bigint, avg_cost bigint, value bigint, min_qty integer, supplier_id uuid, short boolean, category text, barcode text, image_path text, brand text)
language plpgsql stable security definer set search_path = public as $$
declare r public.app_role := public.current_app_role(); b uuid := public.op_branch(); everywhere boolean;
begin
  if r is null then raise exception 'E_FORBIDDEN'; end if;
  everywhere := p_all and r = 'owner';
  return query
  select i.id, i.kind, i.name, i.sku,
         case when r = 'technician' then null else i.sale_price end,
         coalesce(st.q, 0)::bigint,
         case when r = 'owner' and coalesce(st.q, 0) > 0 then (st.v / st.q)::bigint end,
         case when r = 'owner' then coalesce(st.v, 0)::bigint end,
         i.min_qty, case when r = 'owner' then i.supplier_id end,
         i.min_qty > 0 and coalesce(st.q, 0) <= i.min_qty,
         i.category, i.barcode, i.image_path, i.brand
  from public.items i
  left join (select m.item_id, sum(m.qty) as q, sum(m.value) as v from public.stock_moves m where everywhere or m.branch_id = b group by m.item_id) st on st.item_id = i.id
  where i.shop_id = public.current_shop_id() and i.deleted_at is null
  order by i.kind, i.name;
end $$;
revoke execute on function public.items_stock(boolean) from public, anon;
grant execute on function public.items_stock(boolean) to authenticated;
