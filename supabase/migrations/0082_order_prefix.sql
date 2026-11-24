-- 0082: (35ج) بادئة فرع اتعاد استخدامها كانت بتكرّر رقم الطلب والاستلام بيقف.
-- - save_branch بيرفض بادئة اتستخدمت قبل كده في المحل (أجهزة أو فواتير)، حتى لو فرعها اتقفل أو غيّر بادئته.
-- - المحلات اللي وقعت فيها خلاص: العدّاد بيعدّي الأرقام المستخدمة. (وبيغطي جهاز اتنقل لفرع تاني قبل استرجاع نسخة.)
-- - الرقم بعد 9999 بيكمّل بخانات أكتر (lpad كانت بتقصّه وتكرّره).

-- tg_device_defaults: (src: 0034_branches.sql)
create or replace function public.tg_device_defaults() returns trigger
language plpgsql security definer set search_path = public as $$
declare
  y integer := extract(year from (now() at time zone 'Africa/Cairo'))::integer;
  n integer;
  pre text;
begin
  -- وقت الاسترجاع: الصف راجع زي ما هو من النسخة (src: 0023)
  if public.restoring() then return new; end if;
  select b.prefix into pre from public.branches b where b.id = new.branch_id;
  insert into public.order_counters(shop_id, branch_id, year, last_value)
  values (new.shop_id, new.branch_id, y, 1)
  on conflict (shop_id, branch_id, year) do update set last_value = public.order_counters.last_value + 1
  returning last_value into n;
  -- الرئيسي: 2026-0042 زي الأول. فرع تاني: B2-2026-0001
  loop
    new.order_no := concat_ws('-', nullif(pre, ''), y, lpad(n::text, greatest(4, length(n::text)), '0'));
    exit when not exists (select 1 from public.devices d where d.shop_id = new.shop_id and d.order_no = new.order_no);
    n := n + 1;
  end loop;
  update public.order_counters set last_value = n where shop_id = new.shop_id and branch_id = new.branch_id and year = y and last_value <> n;
  new.status := 'received';
  new.received_by := auth.uid();
  new.received_at := now();
  new.delivered_at := null;
  return new;
end $$;

create or replace function public.prefix_used(p_shop uuid, p_prefix text) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.devices where shop_id = p_shop and order_no ~ ('^' || p_prefix || '-[0-9]{4}-[0-9]+$'))
      or exists (select 1 from public.repair_invoices where shop_id = p_shop and prefix = p_prefix)
$$;
revoke execute on function public.prefix_used(uuid, text) from public, anon, authenticated;

-- save_branch: (src: 0034_branches.sql) + E_PREFIX_USED
create or replace function public.save_branch(p_id uuid, p_name text, p_prefix text, p_phone text default null, p_address text default null) returns uuid
language plpgsql security definer set search_path = public as $$
declare s uuid := public.current_shop_id(); b public.branches; pre text := upper(trim(coalesce(p_prefix, ''))); m text; nm text := trim(coalesce(p_name, ''));
begin
  perform public.ledger_require(array['owner']::public.app_role[]);
  if nm = '' or length(nm) > 80 then raise exception 'E_BAD_INPUT'; end if;
  select * into b from public.branches where id = p_id and shop_id = s for update;
  if found then
    if b.deleted_at is not null then raise exception 'E_NOT_FOUND'; end if;
    if b.is_main then pre := b.prefix; end if; -- الرئيسي: أرقامه زي ما هي
    if pre !~ '^[A-Z0-9]{1,4}$' and not b.is_main then raise exception 'E_BAD_PREFIX'; end if;
    if exists (select 1 from public.branches x where x.shop_id = s and x.deleted_at is null and x.id <> b.id and x.prefix = pre) then raise exception 'E_DUP_PREFIX'; end if;
    if pre <> b.prefix and public.prefix_used(s, pre) then raise exception 'E_PREFIX_USED'; end if;
    if exists (select 1 from public.branches x where x.shop_id = s and x.deleted_at is null and x.id <> b.id and lower(trim(x.name)) = lower(nm)) then raise exception 'E_DUP_NAME'; end if;
    update public.branches set name = nm, prefix = pre, phone = nullif(trim(p_phone), ''), address = nullif(trim(p_address), '') where id = b.id;
    return b.id;
  end if;
  if pre !~ '^[A-Z0-9]{1,4}$' then raise exception 'E_BAD_PREFIX'; end if;
  if exists (select 1 from public.branches x where x.shop_id = s and x.deleted_at is null and x.prefix = pre) then raise exception 'E_DUP_PREFIX'; end if;
  if public.prefix_used(s, pre) then raise exception 'E_PREFIX_USED'; end if;
  if exists (select 1 from public.branches x where x.shop_id = s and x.deleted_at is null and lower(trim(x.name)) = lower(nm)) then raise exception 'E_DUP_NAME'; end if;
  insert into public.branches(id, shop_id, name, prefix, phone, address) values (p_id, s, nm, pre, nullif(trim(p_phone), ''), nullif(trim(p_address), ''));
  for m in select unnest(array['cash']) union select unnest(payment_methods) from public.shops where id = s loop
    insert into public.accounts(shop_id, name, type, kind, method, branch_id) values (s, nm, 'asset', 'cash', m, p_id);
  end loop;
  return p_id;
end $$;
