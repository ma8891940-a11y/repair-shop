-- 0051: C7: بيانات تجريبية اختيارية: "جرّب ببيانات تجريبية" و"امسح بيانات التجربة".
-- التحميل لمحل جديد فاضي بس، وكل العمليات بدوال البرنامج نفسها (القيود متوازنة زي الشغل الحقيقي).
-- المسح ما بيحذفش حاجة (الحذف الفعلي ممنوع، والقيود ما بتتحذفش): كل قيد تجريبي بيتعكس بقيد عكسي،
-- والعملاء والأجهزة والأصناف والموردين التجريبيين بيتأرشفوا (soft delete). بعد المسح كل الأرصدة بترجع صفر.

create table public.demo_rows (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references public.shops(id),
  entity text not null check (entity in ('customers', 'suppliers', 'items', 'devices', 'journal_entries')),
  row_id uuid not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);
create index demo_rows_shop on public.demo_rows(shop_id, entity);
alter table public.demo_rows enable row level security;
create trigger set_updated_at before update on public.demo_rows for each row execute function public.tg_set_updated_at();
create trigger block_delete before delete on public.demo_rows for each row execute function public.tg_block_delete();
-- مفيش سياسات: من الدوال بس

create or replace function public.demo_state() returns text
language sql stable security definer set search_path = public as $$
  select case
    when not exists (select 1 from public.demo_rows d where d.shop_id = public.current_shop_id()) then 'none'
    when exists (select 1 from public.demo_rows d where d.shop_id = public.current_shop_id() and d.deleted_at is null) then 'loaded'
    else 'cleared' end
$$;
revoke execute on function public.demo_state() from public, anon;
grant execute on function public.demo_state() to authenticated;

create or replace function public.load_demo() returns void
language plpgsql security definer set search_path = public as $$
declare
  s uuid := public.current_shop_id();
  cash uuid; sup uuid := gen_random_uuid();
  screen uuid := gen_random_uuid(); battery uuid := gen_random_uuid(); port uuid := gen_random_uuid();
  cover uuid := gen_random_uuid(); glass uuid := gen_random_uuid();
  c uuid[] := array[gen_random_uuid(), gen_random_uuid(), gen_random_uuid(), gen_random_uuid()];
  d uuid[] := array[gen_random_uuid(), gen_random_uuid(), gen_random_uuid(), gen_random_uuid(), gen_random_uuid()];
  st text;
begin
  perform public.ledger_require(array['owner']::public.app_role[]);
  if public.demo_state() <> 'none' then raise exception 'E_DEMO_USED'; end if;
  -- محل جديد فاضي بس (عشان التجربة ما تتلخبطش مع شغل حقيقي)
  if exists (select 1 from public.devices where shop_id = s) or exists (select 1 from public.customers where shop_id = s)
     or exists (select 1 from public.items where shop_id = s) or exists (select 1 from public.journal_entries where shop_id = s) then
    raise exception 'E_DEMO_NOT_EMPTY';
  end if;
  select id into cash from public.accounts where shop_id = s and code = 'cash_cash' and deleted_at is null;
  perform public.owner_capital(gen_random_uuid(), cash, 2000000, 'رأس مال تجريبي');

  insert into public.suppliers(id, shop_id, name, phone) values (sup, s, 'مورد قطع الغيار (تجربة)', '01000000901');
  insert into public.items(id, shop_id, kind, name, sale_price) values
    (screen, s, 'part', 'شاشة Samsung A52 (تجربة)', 150000), (battery, s, 'part', 'بطارية iPhone 11 (تجربة)', 90000),
    (port, s, 'part', 'سوكت شحن Type-C (تجربة)', 25000), (cover, s, 'accessory', 'جراب سيليكون (تجربة)', 15000),
    (glass, s, 'accessory', 'سكرينة زجاج (تجربة)', 10000);
  perform public.record_purchase(gen_random_uuid(), sup, jsonb_build_array(
    jsonb_build_object('item', screen, 'qty', 4, 'unit_cost', 90000), jsonb_build_object('item', battery, 'qty', 5, 'unit_cost', 45000),
    jsonb_build_object('item', port, 'qty', 10, 'unit_cost', 8000), jsonb_build_object('item', cover, 'qty', 20, 'unit_cost', 5000),
    jsonb_build_object('item', glass, 'qty', 30, 'unit_cost', 2500)), cash, 'شرا تجريبي');

  insert into public.customers(id, shop_id, name, phone, area) values
    (c[1], s, 'أحمد التجربة', '01000000001', 'المعادي'), (c[2], s, 'منى التجربة', '01000000002', 'مدينة نصر'),
    (c[3], s, 'كريم التجربة', '01000000003', 'الدقي'), (c[4], s, 'سارة التجربة', '01000000004', 'شبرا');
  insert into public.devices(id, shop_id, customer_id, brand, model, issue, accessories) values
    (d[1], s, c[1], 'Samsung', 'Galaxy A52', 'الشاشة مكسورة واللمس مش شغال', array['charger']),
    (d[2], s, c[2], 'Apple', 'iPhone 11', 'البطارية بتفصل بسرعة', array[]::text[]),
    (d[3], s, c[3], 'Xiaomi', 'Redmi Note 12', 'مش بيشحن', array['case']),
    (d[4], s, c[4], 'Oppo', 'A57', 'الكاميرا الخلفية مش بتفتح', array[]::text[]),
    (d[5], s, c[1], 'Realme', 'C55', 'الصوت واطي في المكالمات', array[]::text[]);
  insert into public.device_costs(shop_id, device_id, estimated_cost) values
    (s, d[1], 250000), (s, d[2], 150000), (s, d[3], 60000), (s, d[4], 120000), (s, d[5], 40000);

  -- جهاز 1: اتصلح بشاشة واتسلّم واتدفع
  foreach st in array array['inspecting', 'in_repair'] loop update public.devices set status = st::public.device_status where id = d[1]; end loop;
  perform public.use_part(gen_random_uuid(), d[1], screen, 1);
  foreach st in array array['repaired', 'ready'] loop update public.devices set status = st::public.device_status where id = d[1]; end loop;
  update public.device_costs set final_cost = 250000 where device_id = d[1];
  perform public.record_payment(gen_random_uuid(), c[1], cash, 250000, d[1]);
  update public.devices set status = 'delivered' where id = d[1];
  -- جهاز 2: بطارية واتصلح وجاهز، ودفع عربون
  foreach st in array array['inspecting', 'in_repair'] loop update public.devices set status = st::public.device_status where id = d[2]; end loop;
  perform public.use_part(gen_random_uuid(), d[2], battery, 1);
  foreach st in array array['repaired', 'ready'] loop update public.devices set status = st::public.device_status where id = d[2]; end loop;
  update public.device_costs set final_cost = 150000 where device_id = d[2];
  perform public.record_payment(gen_random_uuid(), c[2], cash, 50000, d[2]);
  -- جهاز 3: جاري الصيانة، وجهاز 4: مستني موافقة العميل، وجهاز 5: لسه مستلم
  foreach st in array array['inspecting', 'in_repair'] loop update public.devices set status = st::public.device_status where id = d[3]; end loop;
  foreach st in array array['inspecting', 'awaiting_approval'] loop update public.devices set status = st::public.device_status where id = d[4]; end loop;
  -- بيع إكسسوارات
  perform public.record_sale(gen_random_uuid(), jsonb_build_array(jsonb_build_object('item', cover, 'qty', 2, 'price', 15000), jsonb_build_object('item', glass, 'qty', 3, 'price', 10000)), cash);

  -- كل اللي اتعمل في العملية دي (نفس الوقت بالظبط) = بيانات تجربة
  insert into public.demo_rows(shop_id, entity, row_id)
  select s, 'journal_entries', id from public.journal_entries where shop_id = s and created_at = now()
  union all select s, 'customers', unnest(c)
  union all select s, 'devices', unnest(d)
  union all select s, 'items', unnest(array[screen, battery, port, cover, glass])
  union all select s, 'suppliers', sup;
end $$;
revoke execute on function public.load_demo() from public, anon;
grant execute on function public.load_demo() to authenticated;

create or replace function public.clear_demo() returns integer
language plpgsql security definer set search_path = public as $$
declare s uuid := public.current_shop_id(); e record; n int := 0;
begin
  perform public.ledger_require(array['owner']::public.app_role[]);
  if public.demo_state() <> 'loaded' then raise exception 'E_NOT_FOUND'; end if;
  -- كل قيد تجريبي بيتعكس، من الأحدث للأقدم (البيع قبل الشرا)
  for e in select j.id from public.journal_entries j join public.demo_rows r on r.row_id = j.id and r.entity = 'journal_entries' and r.shop_id = s
           where not exists (select 1 from public.journal_entries x where x.reverses_id = j.id) and j.source_type <> 'reversal'
           order by j.entry_no desc loop
    perform public.reverse_entry(e.id, 'مسح بيانات التجربة');
    n := n + 1;
  end loop;
  perform set_config('warsha.system', 'on', true);
  update public.devices set deleted_at = now() where shop_id = s and deleted_at is null and id in (select row_id from public.demo_rows where shop_id = s and entity = 'devices');
  update public.customers set deleted_at = now() where shop_id = s and deleted_at is null and id in (select row_id from public.demo_rows where shop_id = s and entity = 'customers');
  update public.items set deleted_at = now() where shop_id = s and deleted_at is null and id in (select row_id from public.demo_rows where shop_id = s and entity = 'items');
  update public.suppliers set deleted_at = now() where shop_id = s and deleted_at is null and id in (select row_id from public.demo_rows where shop_id = s and entity = 'suppliers');
  perform set_config('warsha.system', 'off', true);
  update public.demo_rows set deleted_at = now() where shop_id = s and deleted_at is null;
  insert into public.audit_log(shop_id, actor_id, action, entity, entity_id, after)
  values (s, auth.uid(), 'demo_cleared', 'demo_rows', s, jsonb_build_object('reversed', n));
  return n;
end $$;
revoke execute on function public.clear_demo() from public, anon;
grant execute on function public.clear_demo() to authenticated;
