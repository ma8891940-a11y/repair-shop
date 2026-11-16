-- 0053: C8: بوابة عميل الجملة (اختيارية): للمحلات اللي بتورّد لمحلات تانية.
-- كل عميل جملة ليه رابط خاص (token عشوائي 128 bit): بيشوف كشف حسابه هو بس (الرصيد والحركات من الدفتر)،
-- وبيبعت طلبية من أصناف الكتالوج، والطلبية بتوصل للمحل يراجعها. من غير أي بيانات لعملاء تانيين ولا تكلفة.

alter table public.customers add column if not exists portal_token text unique check (portal_token is null or length(portal_token) = 32);

create table public.wholesale_orders (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references public.shops(id),
  customer_id uuid not null references public.customers(id),
  lines jsonb not null check (jsonb_typeof(lines) = 'array' and jsonb_array_length(lines) between 1 and 50),
  note text check (note is null or length(note) <= 500),
  status text not null default 'new' check (status in ('new', 'seen', 'done', 'cancelled')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);
create index wholesale_orders_customer on public.wholesale_orders(customer_id, created_at desc);
alter table public.wholesale_orders enable row level security;
create trigger set_updated_at before update on public.wholesale_orders for each row execute function public.tg_set_updated_at();
create trigger block_delete before delete on public.wholesale_orders for each row execute function public.tg_block_delete();
create trigger zz_audit after insert or update on public.wholesale_orders for each row execute function public.tg_audit();
-- المحل (صاحب المحل والاستقبال) بيشوف الطلبيات ويغيّر حالتها بس. الإضافة من البوابة بس
create policy wholesale_orders_select on public.wholesale_orders for select to authenticated
  using (shop_id = public.current_shop_id() and public.current_app_role() in ('owner', 'reception'));
create policy wholesale_orders_update on public.wholesale_orders for update to authenticated
  using (shop_id = public.current_shop_id() and public.current_app_role() in ('owner', 'reception'));
grant select, update (status, updated_at) on public.wholesale_orders to authenticated;

-- فتح وقفل البوابة لعميل (القفل بيلغي الرابط القديم)
create or replace function public.set_portal(p_customer uuid, p_on boolean) returns text
language plpgsql security definer set search_path = public, extensions, pg_temp as $$
declare s uuid := public.current_shop_id(); t text := case when p_on then encode(gen_random_bytes(16), 'hex') end;
begin
  perform public.ledger_require(array['owner', 'reception']::public.app_role[]);
  perform public.perm_require('customers', 'edit');
  if not exists (select 1 from public.customers where id = p_customer and shop_id = s and deleted_at is null) then raise exception 'E_NOT_FOUND'; end if;
  update public.customers set portal_token = t where id = p_customer;
  return t;
end $$;
revoke execute on function public.set_portal(uuid, boolean) from public, anon;
grant execute on function public.set_portal(uuid, boolean) to authenticated;

create or replace function public.portal_customer(p_token text) returns public.customers
language sql stable security definer set search_path = public as $$
  select c.* from public.customers c join public.shops s on s.id = c.shop_id and s.deleted_at is null and s.suspended_at is null
  where p_token is not null and length(p_token) = 32 and c.portal_token = p_token and c.deleted_at is null
$$;
revoke execute on function public.portal_customer(text) from public, anon, authenticated;

-- البوابة للعميل: المحل، واسمه، ورصيده، وحركاته (من حسابات العملاء في الدفتر)، وطلبياته، وأصناف الكتالوج
create or replace function public.public_portal(p_token text) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare c public.customers := public.portal_customer(p_token);
begin
  if c.id is null then return null; end if;
  return jsonb_build_object(
    'shop', (select jsonb_build_object('name', sh.name, 'phone', sh.phone, 'currency', sh.currency,
               'logo', (select b.logo_color from public.shop_branding b where b.shop_id = sh.id and b.deleted_at is null)) from public.shops sh where sh.id = c.shop_id),
    'customer', jsonb_build_object('name', c.name),
    'balance', (select coalesce(sum(l.debit - l.credit), 0)::bigint from public.journal_lines l join public.accounts a on a.id = l.account_id
                where l.shop_id = c.shop_id and l.party_type = 'customer' and l.party_id = c.id and a.kind = 'receivable'),
    'entries', coalesce((select jsonb_agg(x order by x->>'at' desc) from (
        select jsonb_build_object('at', e.occurred_at, 'type', e.source_type, 'no', e.entry_no, 'debit', sum(l.debit), 'credit', sum(l.credit)) x
        from public.journal_lines l join public.journal_entries e on e.id = l.entry_id join public.accounts a on a.id = l.account_id
        where l.shop_id = c.shop_id and l.party_type = 'customer' and l.party_id = c.id and a.kind = 'receivable'
        group by e.id order by e.occurred_at desc limit 100) q), '[]'::jsonb),
    'orders', coalesce((select jsonb_agg(jsonb_build_object('id', o.id, 'at', o.created_at, 'status', o.status, 'lines', o.lines, 'note', o.note) order by o.created_at desc)
                        from (select * from public.wholesale_orders w where w.customer_id = c.id and w.deleted_at is null order by w.created_at desc limit 20) o), '[]'::jsonb),
    'items', coalesce((select jsonb_agg(jsonb_build_object('id', i.id, 'name', i.name, 'price', i.sale_price) order by i.name)
                       from public.items i where i.shop_id = c.shop_id and i.in_catalog and i.deleted_at is null and i.kind <> 'used' and i.sale_price is not null), '[]'::jsonb));
end $$;
revoke execute on function public.public_portal(text) from public;
grant execute on function public.public_portal(text) to anon, authenticated;

-- طلبية من البوابة: أصناف الكتالوج بس، والكمية من 1 لـ 10000، ولحد 20 طلبية في اليوم للعميل
create or replace function public.portal_order(p_token text, p_lines jsonb, p_note text default null) returns uuid
language plpgsql security definer set search_path = public as $$
declare c public.customers := public.portal_customer(p_token); l jsonb; out jsonb := '[]'::jsonb; it public.items; q int; id uuid := gen_random_uuid();
begin
  if c.id is null then raise exception 'E_NOT_FOUND'; end if;
  if jsonb_typeof(p_lines) <> 'array' or jsonb_array_length(p_lines) not between 1 and 50 then raise exception 'E_BAD_INPUT'; end if;
  if (select count(*) from public.wholesale_orders w where w.customer_id = c.id and w.created_at > now() - interval '1 day') >= 20 then raise exception 'E_TOO_MANY'; end if;
  for l in select * from jsonb_array_elements(p_lines) loop
    select * into it from public.items i where i.id = (l ->> 'item')::uuid and i.shop_id = c.shop_id and i.in_catalog and i.deleted_at is null and i.kind <> 'used';
    if it.id is null then raise exception 'E_NOT_FOUND'; end if;
    q := (l ->> 'qty')::int;
    if q is null or q < 1 or q > 10000 then raise exception 'E_BAD_AMOUNT'; end if;
    out := out || jsonb_build_array(jsonb_build_object('item', it.id, 'name', it.name, 'qty', q));
  end loop;
  perform set_config('warsha.system', 'on', true);
  insert into public.wholesale_orders(id, shop_id, customer_id, lines, note) values (id, c.shop_id, c.id, out, nullif(trim(left(p_note, 500)), ''));
  perform set_config('warsha.system', 'off', true);
  return id;
exception when invalid_text_representation then raise exception 'E_BAD_INPUT';
end $$;
revoke execute on function public.portal_order(text, jsonb, text) from public;
grant execute on function public.portal_order(text, jsonb, text) to anon, authenticated;
