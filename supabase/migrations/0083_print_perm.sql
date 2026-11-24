-- 0083: (50.1) صلاحية "قوالب الطباعة" (print_templates ← يعدّل)، مقفولة لكل الأدوار ما عدا صاحب المحل. الفني عمره ما ياخدها.
-- الموظف بيها: قوالب وطابعات فروعه بس. قالب المحل كله (من غير فرع) لصاحب المحل أو اللي معاه كل الفروع. القراية زي ما هي.

-- perm_sections: (src: 0038_roles_grant.sql) + print_templates
create or replace function public.perm_sections() returns text[]
language sql immutable as $$
  select array['devices', 'intake', 'customers', 'technicians', 'inventory', 'item_create', 'sales', 'purchases', 'cashbox', 'expenses', 'finance', 'partners', 'reports', 'staff', 'settings', 'print_templates', 'audit']
$$;

create or replace function public.can_edit_print(p_branch uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select coalesce(public.current_app_role() = 'owner'
    or (public.current_app_role() = 'reception' and public.has_perm('print_templates', 'edit')
        and case when p_branch is null then public.all_my_branches() else public.can_branch(p_branch) end), false)
$$;
revoke execute on function public.can_edit_print(uuid) from public, anon;
grant execute on function public.can_edit_print(uuid) to authenticated;

drop policy printers_insert on public.printers;
drop policy printers_update on public.printers;
drop policy templates_insert on public.print_templates;
drop policy templates_update on public.print_templates;
create policy printers_insert on public.printers for insert to authenticated with check (shop_id = public.current_shop_id() and public.can_edit_print(branch_id));
create policy printers_update on public.printers for update to authenticated using (shop_id = public.current_shop_id() and public.can_edit_print(branch_id));
create policy templates_insert on public.print_templates for insert to authenticated with check (shop_id = public.current_shop_id() and public.can_edit_print(branch_id));
create policy templates_update on public.print_templates for update to authenticated using (shop_id = public.current_shop_id() and public.can_edit_print(branch_id));
