-- استكمال قواعد من المواصفات (مراجعة شاملة 2026-11-07)
-- 1) مدة ضمان لكل نوع عطل (مسار)، ولو مش متحددة بتاخد مدة الضمان بتاعة المحل.
-- 2) حذف (أرشفة) جهاز أو عميل: صاحب المحل بس. ("أي عملية حساسة زي حذف جهاز تحتاج إذن صاحب المحل")
-- 3) خصم كبير: الاستقبال ما يقدرش ينزّل التكلفة عن التقديرية بأكتر من نسبة يحددها صاحب المحل (افتراضي 20%)
--    من غير صاحب المحل. وكل تعديل في الأسعار بيتسجل في سجل النشاط زي الأول.

-- ============================================================
-- 1) الضمان لكل نوع عطل
-- ============================================================
alter table public.routes add column if not exists warranty_days integer check (warranty_days is null or warranty_days between 0 and 3650);

create or replace function public.tg_device_warranty() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if new.status = 'delivered' and old.status is distinct from 'delivered' then
    if new.warranty_days is null then
      -- مدة ضمان نوع العطل (المسار)، وإلا مدة ضمان المحل
      select coalesce(r.warranty_days, s.warranty_days) into new.warranty_days
      from public.shops s left join public.routes r on r.id = new.route_id and r.deleted_at is null
      where s.id = new.shop_id;
    end if;
    new.warranty_until := now() + make_interval(days => coalesce(new.warranty_days, 0));
  end if;
  if new.tracking_token is distinct from old.tracking_token then
    raise exception 'E_RECEIPT_IMMUTABLE';
  end if;
  return new;
end $$;

-- ============================================================
-- 2) الأرشفة (soft delete) لصاحب المحل بس
-- ============================================================
create or replace function public.tg_owner_soft_delete() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if new.deleted_at is distinct from old.deleted_at
     and auth.uid() is not null
     and coalesce(current_setting('warsha.system', true), '') <> 'on'
     and public.current_app_role() is distinct from 'owner' then
    raise exception 'E_OWNER_APPROVAL';
  end if;
  return new;
end $$;
drop trigger if exists a_owner_soft_delete on public.devices;
create trigger a_owner_soft_delete before update on public.devices for each row execute function public.tg_owner_soft_delete();
drop trigger if exists a_owner_soft_delete on public.customers;
create trigger a_owner_soft_delete before update on public.customers for each row execute function public.tg_owner_soft_delete();

-- ============================================================
-- 3) الخصم الكبير محتاج صاحب المحل
-- ============================================================
alter table public.shops add column if not exists max_discount_pct integer not null default 20 check (max_discount_pct between 0 and 100);

create or replace function public.tg_cost_discount() returns trigger
language plpgsql security definer set search_path = public as $$
declare pct integer; est integer;
begin
  if auth.uid() is null or coalesce(current_setting('warsha.system', true), '') = 'on' or public.current_app_role() = 'owner' then
    return new;
  end if;
  select max_discount_pct into pct from public.shops where id = new.shop_id;
  pct := coalesce(pct, 20);
  -- التكلفة التقديرية نفسها ما تنزلش بخصم كبير
  if tg_op = 'UPDATE' and old.estimated_cost > 0 and new.estimated_cost is distinct from old.estimated_cost
     and coalesce(new.estimated_cost, 0)::bigint * 100 < old.estimated_cost::bigint * (100 - pct) then
    raise exception 'E_OWNER_APPROVAL';
  end if;
  -- التكلفة النهائية مقارنة بالتقديرية (أعداد صحيحة بس، من غير كسور)
  est := case when tg_op = 'UPDATE' then coalesce(old.estimated_cost, new.estimated_cost) else new.estimated_cost end;
  if new.final_cost is not null and est > 0
     and (tg_op = 'INSERT' or new.final_cost is distinct from old.final_cost)
     and new.final_cost::bigint * 100 < est::bigint * (100 - pct) then
    raise exception 'E_OWNER_APPROVAL';
  end if;
  return new;
end $$;
drop trigger if exists a_cost_discount on public.device_costs;
create trigger a_cost_discount before insert or update on public.device_costs for each row execute function public.tg_cost_discount();

-- ============================================================
-- 4) تذكيرات تسويقية بموافقة العميل ("صيانة من 6 شهور")
-- ============================================================
alter table public.message_templates drop constraint if exists message_templates_key_check;
alter table public.message_templates add constraint message_templates_key_check
  check (key in ('received', 'status', 'approval', 'ready', 'reminder', 'delivered', 'debt', 'marketing'));

-- العملاء اللي وافقوا على التذكيرات، وآخر جهاز ليهم اتسلّم من 6 شهور أو أكتر (لحد سنة)،
-- وما اتبعتلهمش تذكير تسويقي من وقت التسليم ده. للاستقبال وصاحب المحل بس.
create or replace function public.marketing_due(p_days integer default 180)
returns table(device_id uuid, order_no text, brand text, model text, issue text, delivered_at timestamptz,
              customer_id uuid, customer_name text, phone text, tracking_token text)
language plpgsql stable security definer set search_path = public as $$
#variable_conflict use_column
declare s uuid := public.current_shop_id(); days integer := greatest(30, least(coalesce(p_days, 180), 720));
begin
  if public.current_app_role() not in ('owner', 'reception') then raise exception 'E_FORBIDDEN'; end if;
  return query
  with last_dev as (
    select distinct on (d.customer_id) d.*
    from public.devices d
    where d.shop_id = s and d.deleted_at is null and d.status = 'delivered' and d.delivered_at is not null
    order by d.customer_id, d.delivered_at desc
  )
  select d.id, d.order_no, d.brand, d.model, d.issue, d.delivered_at, c.id, c.name, c.phone, d.tracking_token
  from last_dev d join public.customers c on c.id = d.customer_id and c.deleted_at is null
  where c.marketing_ok
    and d.delivered_at <= now() - make_interval(days => days)
    and d.delivered_at > now() - make_interval(days => days + 365)
    and not exists (select 1 from public.message_log m where m.customer_id = c.id and m.template_key = 'marketing' and m.created_at >= d.delivered_at and m.deleted_at is null)
  order by d.delivered_at
  limit 200;
end $$;
revoke execute on function public.marketing_due(integer) from public, anon;
grant execute on function public.marketing_due(integer) to authenticated;
