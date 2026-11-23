-- بيانات حقيقية قبل الترقية (test-upgrade.sh): محلين، لكل واحد صاحب محل وعميل ومورد وصنف ورأس مال وشراء وبيع وجهاز.
-- كل حاجة بدوال البرنامج نفسها وكأن صاحب المحل هو اللي بيعمل. وبعدها الترقية بتشتغل من غير مستخدم (زي SQL Editor).
do $seed$
declare
  n int;
  u uuid; sh uuid; cash uuid; cust uuid; sup uuid; item uuid; dev uuid;
begin
  for n in 1..2 loop
    u := gen_random_uuid();
    insert into auth.users(id, email, email_confirmed_at) values (u, 'seed-' || n || '-' || u || '@upgrade.test', now());
    perform set_config('request.jwt.claims', json_build_object('sub', u, 'role', 'authenticated')::text, true);
    -- كل محل بفرعه (الفرع المتثبّت من المحل اللي قبله ما يفضلش)
    perform set_config('app.branch', '', true);
    sh := (public.bootstrap_account('صاحب ' || n, 'محل الترقية ' || n)).shop_id;
    select id into cash from public.accounts where shop_id = sh and code = 'cash_cash';
    cust := gen_random_uuid(); sup := gen_random_uuid(); item := gen_random_uuid(); dev := gen_random_uuid();
    insert into public.customers(id, shop_id, name, phone) values (cust, gen_random_uuid(), 'عميل ' || n, '0101000000' || n);
    insert into public.suppliers(id, shop_id, name) values (sup, gen_random_uuid(), 'مورد ' || n);
    insert into public.items(id, shop_id, kind, name, sale_price) values (item, gen_random_uuid(), 'accessory', 'جراب ' || n, 11400);
    perform public.owner_capital(gen_random_uuid(), cash, 1000000);
    perform public.record_purchase(gen_random_uuid(), sup, jsonb_build_array(jsonb_build_object('item', item, 'qty', 5, 'unit_cost', 3000)), cash);
    perform public.record_sale(gen_random_uuid(), jsonb_build_array(jsonb_build_object('item', item, 'qty', 2, 'price', 11400)), cash, cust);
    insert into public.devices(id, customer_id, brand, model, issue) values (dev, cust, 'Samsung', 'A54', 'شاشة');
    perform set_config('request.jwt.claims', '', true);
  end loop;
end $seed$;
