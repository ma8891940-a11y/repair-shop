-- الدعوة بترجّع كمان الاسم اللي صاحب المحل كتبه، عشان الموظف ينضم بيه
drop function if exists public.my_pending_invite();
create function public.my_pending_invite()
returns table(shop_name text, role public.app_role, full_name text)
language sql stable security definer set search_path = public as $$
  select s.name, i.role, i.full_name
  from public.staff_invites i
  join public.shops s on s.id = i.shop_id
  join auth.users u on u.id = auth.uid()
  where lower(i.email) = lower(u.email) and i.accepted_at is null and i.deleted_at is null
  order by i.created_at desc limit 1
$$;
revoke execute on function public.my_pending_invite() from public, anon;
grant execute on function public.my_pending_invite() to authenticated;
