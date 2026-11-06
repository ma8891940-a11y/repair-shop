-- ورشة / Warsha: بيانات تجريبية للتجربة على طول.
-- شغّله بعد supabase/setup_all.sql (SQL Editor ← New query ← الصق ← Run).
-- آمن تشغّله أكتر من مرة: لو المحل التجريبي موجود، الملف ما بيعملش حاجة.
--
-- الحسابات (كلمة السر لكلهم: Warsha#2026):
--   owner@warsha.demo      صاحب المحل
--   reception@warsha.demo  موظفة الاستقبال (مسؤولة عن كاش الدرج)
--   tech@warsha.demo       الفني
--
-- كل العمليات المالية بتتسجل بدوال البرنامج نفسها، فالقيود متوازنة زي ما تكون اتعملت من الشاشات.
-- البيانات كلها وهمية (أسماء وأرقام موبايل مش حقيقية).

do $seed$
declare
  pw text := 'Warsha#2026';
  owner_id uuid := 'a0000000-0000-4000-8000-000000000001';
  rec_id uuid := 'a0000000-0000-4000-8000-000000000002';
  tech_id uuid := 'a0000000-0000-4000-8000-000000000003';
  shop uuid;
  u record;
  cust uuid[] := array[]::uuid[];
  sup uuid[] := array[]::uuid[];
  item_screen uuid := gen_random_uuid();
  item_battery uuid := gen_random_uuid();
  item_port uuid := gen_random_uuid();
  item_case uuid := gen_random_uuid();
  item_glass uuid := gen_random_uuid();
  item_cable uuid := gen_random_uuid();
  cash uuid; wallet uuid; instapay uuid;
  dev uuid;
  i int;
  st text;
  path text[];
  names text[] := array['أحمد علي','منى سمير','كريم حسن','سارة فتحي','محمود عادل','نورا إبراهيم','عمر خالد','هبة مصطفى','يوسف طارق','دينا شريف','مصطفى رمضان','ريم عصام'];
  brands text[] := array['Samsung','iPhone','Xiaomi','Oppo','Realme','Infinix','Vivo','Honor','Huawei','Tecno'];
  models text[] := array['A54','13 Pro','Redmi Note 12','A78','C55','Hot 30','Y36','X8','Nova 9','Spark 10'];
  issues text[] := array['شاشة مكسورة','البطارية بتفصل','مش بيشحن','الصوت واطي','الكاميرا مش شغالة','وقع في مية','بيعلّق','الشبكة بتقطع'];
  -- 20 جهاز بحالات مختلفة
  statuses text[] := array['received','received','inspecting','inspecting','awaiting_approval','awaiting_approval','awaiting_part','in_repair','in_repair','in_repair',
                           'repaired','ready','ready','ready','delivered','delivered','delivered','delivered','unrepairable','warranty_return'];
  costs int[] := array[0,0,0,0,85000,120000,65000,45000,150000,30000,55000,95000,140000,40000,175000,60000,35000,110000,0,0];
begin
  if exists (select 1 from auth.users where id = owner_id) then
    raise notice 'البيانات التجريبية موجودة بالفعل';
    return;
  end if;

  -- المستخدمين (كلمة السر متشفّرة bcrypt زي Supabase Auth بالظبط)
  for u in select * from (values (owner_id, 'owner@warsha.demo'), (rec_id, 'reception@warsha.demo'), (tech_id, 'tech@warsha.demo')) as x(id, email) loop
    insert into auth.users (instance_id, id, aud, role, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at,
                            confirmation_token, email_change, email_change_token_new, recovery_token)
    values ('00000000-0000-0000-0000-000000000000', u.id, 'authenticated', 'authenticated', u.email, crypt(pw, gen_salt('bf')), now(),
            '{"provider":"email","providers":["email"]}', '{}', now(), now(), '', '', '', '');
    insert into auth.identities (id, user_id, provider_id, identity_data, provider, last_sign_in_at, created_at, updated_at)
    values (gen_random_uuid(), u.id, u.id::text, jsonb_build_object('sub', u.id::text, 'email', u.email, 'email_verified', true), 'email', now(), now(), now());
  end loop;

  -- صاحب المحل بيعمل المحل
  perform set_config('request.jwt.claims', jsonb_build_object('sub', owner_id, 'role', 'authenticated')::text, true);
  shop := (public.bootstrap_account('محمود حسن', 'ورشة التجربة')).shop_id;
  update public.shops set phone = '01000000000', address = 'شارع التحرير، الدقي، الجيزة',
    payment_methods = array['cash', 'wallet', 'instapay', 'card'], setup_completed_at = now() where id = shop;
  insert into public.staff_invites(shop_id, email, full_name, role) values
    (shop, 'reception@warsha.demo', 'سارة محمد', 'reception'), (shop, 'tech@warsha.demo', 'كريم عبد الله', 'technician');

  perform set_config('request.jwt.claims', jsonb_build_object('sub', rec_id, 'role', 'authenticated')::text, true);
  perform public.bootstrap_account('سارة محمد');
  perform set_config('request.jwt.claims', jsonb_build_object('sub', tech_id, 'role', 'authenticated')::text, true);
  perform public.bootstrap_account('كريم عبد الله');

  -- من هنا صاحب المحل
  perform set_config('request.jwt.claims', jsonb_build_object('sub', owner_id, 'role', 'authenticated')::text, true);
  select id into cash from public.accounts where shop_id = shop and code = 'cash_cash';
  select id into wallet from public.accounts where shop_id = shop and code = 'cash_wallet';
  select id into instapay from public.accounts where shop_id = shop and code = 'cash_instapay';
  perform public.update_account(cash, p_holder => rec_id);

  -- العملاء (12) والموردين (3) والأصناف (6)
  for i in 1..array_length(names, 1) loop
    cust := cust || gen_random_uuid();
    insert into public.customers(id, shop_id, name, phone, area) values (cust[i], shop, names[i], '0101000' || lpad(i::text, 4, '0'), (array['الدقي','المهندسين','فيصل','الهرم'])[1 + i % 4]);
  end loop;
  for i in 1..3 loop
    sup := sup || gen_random_uuid();
    insert into public.suppliers(id, shop_id, name, phone) values (sup[i], shop, (array['مورد الشاشات','مورد البطاريات','مورد الإكسسوارات'])[i], '0122000' || lpad(i::text, 4, '0'));
  end loop;
  insert into public.items(id, shop_id, kind, name, sale_price) values
    (item_screen, shop, 'part', 'شاشة Samsung A54', 120000), (item_battery, shop, 'part', 'بطارية iPhone 13', 90000),
    (item_port, shop, 'part', 'سوكت شحن Type-C', 15000), (item_case, shop, 'accessory', 'جراب سيليكون', 7500),
    (item_glass, shop, 'accessory', 'اسكرينة 9D', 5000), (item_cable, shop, 'accessory', 'كابل شحن سريع', 12000);

  -- يوم كامل من الفلوس: رأس مال، مشتريات نقدي وآجل، مصروفات، مرتبات، تحويل
  perform public.owner_capital(gen_random_uuid(), cash, 3000000, 'رأس مال البداية');
  perform public.owner_capital(gen_random_uuid(), wallet, 500000, 'رأس مال (فودافون كاش)');
  perform public.record_purchase(gen_random_uuid(), sup[1], jsonb_build_array(jsonb_build_object('item', item_screen, 'qty', 5, 'unit_cost', 70000)), null, 'فاتورة 1021 (آجل)');
  perform public.record_purchase(gen_random_uuid(), sup[2], jsonb_build_array(jsonb_build_object('item', item_battery, 'qty', 4, 'unit_cost', 45000), jsonb_build_object('item', item_port, 'qty', 10, 'unit_cost', 4000)), cash, 'نقدي');
  perform public.record_purchase(gen_random_uuid(), sup[3], jsonb_build_array(jsonb_build_object('item', item_case, 'qty', 30, 'unit_cost', 2500), jsonb_build_object('item', item_glass, 'qty', 40, 'unit_cost', 1500), jsonb_build_object('item', item_cable, 'qty', 15, 'unit_cost', 5000)), null, 'آجل');
  perform public.pay_supplier(gen_random_uuid(), sup[1], cash, 150000, 'دفعة من الحساب');
  perform public.record_expense(gen_random_uuid(), (select id from public.accounts where shop_id = shop and code = 'exp_rent'), cash, 600000, 'إيجار الشهر');
  perform public.record_expense(gen_random_uuid(), (select id from public.accounts where shop_id = shop and code = 'exp_electricity'), wallet, 85000, 'فاتورة الكهرباء');
  perform public.record_expense(gen_random_uuid(), (select id from public.accounts where shop_id = shop and code = 'exp_internet'), wallet, 35000, 'باقة الإنترنت');
  perform public.accrue_salary(gen_random_uuid(), tech_id, 600000, 'مرتب الشهر');
  perform public.accrue_salary(gen_random_uuid(), rec_id, 450000, 'مرتب الشهر');
  perform public.give_advance(gen_random_uuid(), tech_id, cash, 100000, 'سلفة');
  perform public.pay_salary(gen_random_uuid(), rec_id, cash, 450000, 'صرف المرتب');
  perform public.transfer_cash(gen_random_uuid(), cash, instapay, 200000, 'إيداع');

  -- 20 جهاز
  for i in 1..20 loop
    dev := gen_random_uuid();
    perform set_config('request.jwt.claims', jsonb_build_object('sub', rec_id, 'role', 'authenticated')::text, true);
    insert into public.devices(id, shop_id, customer_id, brand, model, imei, issue, accessories, cosmetic_condition)
    values (dev, shop, cust[1 + (i - 1) % 12], brands[1 + (i - 1) % 10], models[1 + (i - 1) % 10],
            case when i % 3 = 0 then null else '35' || lpad((123456789012 + i * 7919)::text, 13, '0') end,
            issues[1 + (i - 1) % 8], case when i % 2 = 0 then array['sim'] else array[]::text[] end, case when i % 4 = 0 then 'خدوش خفيفة' end);
    insert into public.device_costs(id, shop_id, device_id, estimated_cost) values (gen_random_uuid(), shop, dev, nullif(costs[i], 0));
    st := statuses[i];
    path := case st
      when 'received' then array[]::text[]
      when 'inspecting' then array['inspecting']
      when 'awaiting_approval' then array['inspecting', 'awaiting_approval']
      when 'awaiting_part' then array['inspecting', 'awaiting_part']
      when 'in_repair' then array['inspecting', 'in_repair']
      when 'repaired' then array['inspecting', 'in_repair', 'repaired']
      when 'ready' then array['inspecting', 'in_repair', 'repaired', 'ready']
      when 'delivered' then array['inspecting', 'in_repair', 'repaired', 'ready']
      when 'unrepairable' then array['inspecting', 'unrepairable']
      when 'warranty_return' then array['inspecting', 'in_repair', 'repaired', 'ready'] end;
    -- الفني بيشتغل على الأجهزة
    perform set_config('request.jwt.claims', jsonb_build_object('sub', tech_id, 'role', 'authenticated')::text, true);
    for j in 1..coalesce(array_length(path, 1), 0) loop
      update public.devices set status = path[j]::public.device_status where id = dev;
      if path[j] = 'in_repair' and i in (9, 15) then
        perform public.use_part(gen_random_uuid(), dev, item_screen, 1);
      elsif path[j] = 'in_repair' and i = 16 then
        perform public.use_part(gen_random_uuid(), dev, item_battery, 1);
      end if;
    end loop;
    -- الاستقبال: عربون، والتكلفة النهائية، والدفع، والتسليم
    perform set_config('request.jwt.claims', jsonb_build_object('sub', rec_id, 'role', 'authenticated')::text, true);
    if st in ('in_repair', 'ready') and costs[i] > 0 then
      perform public.record_payment(gen_random_uuid(), cust[1 + (i - 1) % 12], cash, 20000, dev, null, 'عربون');
    end if;
    if st in ('ready', 'delivered', 'warranty_return', 'repaired') and costs[i] > 0 then
      update public.device_costs set final_cost = costs[i] where device_id = dev;
    end if;
    if st in ('delivered', 'warranty_return') then
      if st = 'warranty_return' then
        update public.device_costs set final_cost = 70000 where device_id = dev;
      end if;
      perform public.record_payment(gen_random_uuid(), cust[1 + (i - 1) % 12], case when i % 2 = 0 then wallet else cash end,
        (select final_cost from public.device_costs where device_id = dev) - public.device_paid(dev), dev);
      update public.devices set status = 'delivered' where id = dev;
      if st = 'warranty_return' then
        update public.devices set status = 'warranty_return' where id = dev;
      end if;
    end if;
    if st = 'unrepairable' then
      update public.device_costs set final_cost = 0 where device_id = dev;
      update public.devices set status = 'delivered' where id = dev;
    end if;
  end loop;

  -- جهاز اتسلّم بالآجل (صاحب المحل): العميل عليه فلوس
  perform set_config('request.jwt.claims', jsonb_build_object('sub', owner_id, 'role', 'authenticated')::text, true);
  select d.id into dev from public.devices d join public.device_costs c on c.device_id = d.id
   where d.shop_id = shop and d.status = 'ready' and c.final_cost > 0 order by d.order_no limit 1;
  perform public.deliver_on_credit(dev);

  -- بيع إكسسوارات على الكاونتر، وبيع آجل لعميل
  perform set_config('request.jwt.claims', jsonb_build_object('sub', rec_id, 'role', 'authenticated')::text, true);
  perform public.record_sale(gen_random_uuid(), jsonb_build_array(jsonb_build_object('item', item_case, 'qty', 3, 'price', 7500), jsonb_build_object('item', item_glass, 'qty', 2, 'price', 5000)), cash);
  perform public.record_sale(gen_random_uuid(), jsonb_build_array(jsonb_build_object('item', item_cable, 'qty', 1, 'price', 12000)), wallet);
  perform set_config('request.jwt.claims', jsonb_build_object('sub', owner_id, 'role', 'authenticated')::text, true);
  perform public.record_sale(gen_random_uuid(), jsonb_build_array(jsonb_build_object('item', item_port, 'qty', 1, 'price', 15000)), null, cust[3], 'بيع آجل');

  -- آخر اليوم: الاستقبال بتقفل الدرج بعجز 10 جنيه
  perform set_config('request.jwt.claims', jsonb_build_object('sub', rec_id, 'role', 'authenticated')::text, true);
  perform public.close_drawer(gen_random_uuid(), cash, public.ledger_balance(cash) - 1000, 'تقفيل آخر اليوم');

  perform set_config('request.jwt.claims', '', true);
  raise notice 'اتعملت البيانات التجريبية: ورشة التجربة (كلمة السر Warsha#2026)';
end
$seed$;
