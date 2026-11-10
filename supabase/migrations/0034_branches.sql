-- =====================================================================
-- B. الفروع (قرار صاحب المشروع 2026-11-08)
-- - كل محل ليه "الفرع الرئيسي"، وكل البيانات الحالية بتتنقل له (والأرصدة زي ما هي بالظبط).
-- - لكل فرع: خزن ومخزون وأجهزة وموظفين ودرج، وبادئة لأرقام الطلبات.
-- - الدفتر واحد للمحل، وكل قيد مربوط بفرع. وحركات المخزون بفرعها (المتوسط المرجّح لكل فرع).
-- - الموظف مربوط بفرع أو أكتر (RLS). صاحب المحل بيشوف كل الفروع.
-- - الفرع الشغال بيتبعت مع كل طلب في الهيدر x-branch-id (وبيتراجع إن الموظف ليه الفرع ده).
-- - المحل اللي ليه فرع واحد: مفيش أي حاجة بتتغير (رقم الطلب زي ما هو 2026-0042).
-- =====================================================================

-- ---------- الجداول ----------
create table public.branches (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references public.shops(id),
  name text not null check (length(trim(name)) between 1 and 80),
  -- بادئة رقم الطلب (حروف إنجليزي كبيرة وأرقام). الرئيسي من غير بادئة عشان الأرقام القديمة تفضل زي ما هي
  prefix text not null default '' check (prefix ~ '^[A-Z0-9]{0,4}$'),
  is_main boolean not null default false,
  phone text check (phone is null or length(phone) <= 40),
  address text check (address is null or length(address) <= 200),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  constraint branches_prefix_needed check (is_main or prefix <> '')
);
create unique index branches_one_main on public.branches(shop_id) where is_main and deleted_at is null;
create unique index branches_prefix_uq on public.branches(shop_id, prefix) where deleted_at is null;
create unique index branches_name_uq on public.branches(shop_id, lower(trim(name))) where deleted_at is null;

-- الموظف ← فروعه. الموظف اللي مالوش صفوف هنا = الفرع الرئيسي بس (المحل اللي ليه فرع واحد ما يحتاجش يختار)
create table public.staff_branches (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references public.shops(id),
  profile_id uuid not null references public.profiles(id),
  branch_id uuid not null references public.branches(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);
create unique index staff_branches_uq on public.staff_branches(profile_id, branch_id) where deleted_at is null;

alter table public.staff_invites add column branch_ids uuid[] not null default '{}';

do $$
declare t text;
begin
  foreach t in array array['branches', 'staff_branches'] loop
    execute format('alter table public.%I enable row level security', t);
    execute format('create trigger set_updated_at before update on public.%I for each row execute function public.tg_set_updated_at()', t);
    execute format('create trigger block_delete before delete on public.%I for each row execute function public.tg_block_delete()', t);
    execute format('create trigger zz_audit after insert or update on public.%I for each row execute function public.tg_audit()', t);
  end loop;
end $$;

-- ---------- دوال الفروع ----------
create or replace function public.main_branch(p_shop uuid) returns uuid
language sql stable security definer set search_path = public as $$
  select id from public.branches where shop_id = p_shop and is_main and deleted_at is null
$$;

-- الفروع اللي المستخدم الحالي يشتغل فيها
create or replace function public.my_branch_ids() returns uuid[]
language sql stable security definer set search_path = public as $$
  select case
    when public.current_app_role() = 'owner' then
      array(select b.id from public.branches b where b.shop_id = public.current_shop_id() and b.deleted_at is null order by b.is_main desc, b.created_at)
    else coalesce(
      nullif(array(select sb.branch_id from public.staff_branches sb join public.branches b on b.id = sb.branch_id and b.deleted_at is null
                   where sb.profile_id = auth.uid() and sb.deleted_at is null and sb.shop_id = public.current_shop_id()
                   order by b.is_main desc, b.created_at), '{}'),
      array[public.main_branch(public.current_shop_id())])
  end
$$;

create or replace function public.can_branch(p uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select p is not null and p = any (public.my_branch_ids())
$$;

-- فرع العملية الحالية:
-- 1) app.branch: بتحطه دوال البرنامج نفسها (الخزنة المختارة، أو فرع القيد الأصلي في التصحيح)
-- 2) الهيدر x-branch-id من التطبيق (لو الموظف ليه الفرع ده)
-- 3) الافتراضي: الرئيسي لو ليه، وإلا أول فرع ليه
create or replace function public.op_branch() returns uuid
language plpgsql stable security definer set search_path = public as $$
declare g text := nullif(current_setting('app.branch', true), ''); h text; mine uuid[];
begin
  if g is not null then return g::uuid; end if;
  mine := public.my_branch_ids();
  begin
    h := nullif(current_setting('request.headers', true), '')::json ->> 'x-branch-id';
  exception when others then h := null;
  end;
  if h ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' and h::uuid = any (mine) then return h::uuid; end if;
  return coalesce((select x from unnest(mine) x where x = public.main_branch(public.current_shop_id())), mine[1]);
end $$;

-- بيثبّت فرع العملية لآخر الـ transaction (لو لسه ما اتحددش)
create or replace function public.pin_branch(p uuid) returns void
language plpgsql security definer set search_path = public as $$
begin
  if p is not null and nullif(current_setting('app.branch', true), '') is null then
    perform set_config('app.branch', p::text, true);
  end if;
end $$;

revoke execute on function public.main_branch(uuid), public.op_branch(), public.pin_branch(uuid) from public, anon, authenticated;
revoke execute on function public.my_branch_ids(), public.can_branch(uuid) from public, anon;
grant execute on function public.my_branch_ids(), public.can_branch(uuid) to authenticated;

-- ---------- الفرع الرئيسي لكل محل (الموجود والجديد) ----------
insert into public.branches(shop_id, name, is_main)
select s.id, 'الفرع الرئيسي', true from public.shops s
where not exists (select 1 from public.branches b where b.shop_id = s.id and b.is_main and b.deleted_at is null);

create or replace function public.tg_shop_main_branch() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  insert into public.branches(shop_id, name, is_main) values (new.id, 'الفرع الرئيسي', true);
  return null;
end $$;
-- a_: لازم يشتغل قبل zz_shop_ledger (الخزن الأساسية بتتعمل في الفرع الرئيسي)
create trigger a_shop_main_branch after insert on public.shops for each row execute function public.tg_shop_main_branch();

-- ---------- عمود الفرع ----------
alter table public.devices add column branch_id uuid references public.branches(id);
alter table public.devices add column transfer_to uuid references public.branches(id);
alter table public.devices add column transfer_at timestamptz;
alter table public.devices add column transfer_by uuid references public.profiles(id);
alter table public.accounts add column branch_id uuid references public.branches(id);
alter table public.journal_entries add column branch_id uuid references public.branches(id);
alter table public.stock_moves add column branch_id uuid references public.branches(id);
alter table public.order_counters add column branch_id uuid references public.branches(id);

-- النقل: كل الموجود ← الفرع الرئيسي. القيود والمخزون ما بيتعدلوش عادي، فالحماية بتتقفل لحظة النقل بس (وفي نفس الـ transaction)
alter table public.devices disable trigger user;
alter table public.accounts disable trigger user;
alter table public.journal_entries disable trigger user;
alter table public.stock_moves disable trigger user;
alter table public.order_counters disable trigger user;
update public.devices set branch_id = public.main_branch(shop_id) where branch_id is null;
update public.accounts set branch_id = public.main_branch(shop_id) where branch_id is null and kind = 'cash';
update public.journal_entries set branch_id = public.main_branch(shop_id) where branch_id is null;
update public.stock_moves set branch_id = public.main_branch(shop_id) where branch_id is null;
update public.order_counters set branch_id = public.main_branch(shop_id) where branch_id is null;
alter table public.devices enable trigger user;
alter table public.accounts enable trigger user;
alter table public.journal_entries enable trigger user;
alter table public.stock_moves enable trigger user;
alter table public.order_counters enable trigger user;

alter table public.devices alter column branch_id set not null;
alter table public.journal_entries alter column branch_id set not null;
alter table public.stock_moves alter column branch_id set not null;
alter table public.order_counters alter column branch_id set not null;
alter table public.accounts add constraint accounts_branch_cash check ((kind = 'cash') = (branch_id is not null));
alter table public.order_counters drop constraint order_counters_shop_id_year_key;
alter table public.order_counters add constraint order_counters_branch_year unique (shop_id, branch_id, year);
create index devices_branch on public.devices(shop_id, branch_id);
create index entries_branch on public.journal_entries(shop_id, branch_id);
create index moves_item_branch on public.stock_moves(item_id, branch_id);

-- ---------- الافتراضي والتأكد ----------
-- الجهاز والخزنة: الفرع الشغال (ولازم يكون من فروع الموظف)
create or replace function public.tg_branch_default() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if TG_TABLE_NAME = 'accounts' and new.kind <> 'cash' then
    new.branch_id := null;
    return new;
  end if;
  if new.branch_id is null then
    if public.restoring() or auth.uid() is null or public.current_shop_id() is distinct from new.shop_id or new.code is not null then
      new.branch_id := public.main_branch(new.shop_id);
    else
      new.branch_id := public.op_branch();
    end if;
  end if;
  -- (وقت الاسترجاع: الفرع ممكن يكون اتقفل قبل كده، وصفوفه القديمة بترجع زي ما هي)
  if not exists (select 1 from public.branches b where b.id = new.branch_id and b.shop_id = new.shop_id and (b.deleted_at is null or public.restoring())) then
    raise exception 'E_BAD_BRANCH';
  end if;
  return new;
end $$;
-- الأجهزة ما فيهاش code: نسخة منفصلة عشان new.code
create or replace function public.tg_device_branch_default() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if new.branch_id is null then
    if public.restoring() or auth.uid() is null or public.current_shop_id() is distinct from new.shop_id then
      new.branch_id := public.main_branch(new.shop_id);
    else
      new.branch_id := public.op_branch();
    end if;
  end if;
  -- (وقت الاسترجاع: الفرع ممكن يكون اتقفل قبل كده، وصفوفه القديمة بترجع زي ما هي)
  if not exists (select 1 from public.branches b where b.id = new.branch_id and b.shop_id = new.shop_id and (b.deleted_at is null or public.restoring())) then
    raise exception 'E_BAD_BRANCH';
  end if;
  if not public.restoring() and auth.uid() is not null and not public.can_branch(new.branch_id) then raise exception 'E_FORBIDDEN'; end if;
  new.transfer_to := null;
  new.transfer_at := null;
  new.transfer_by := null;
  return new;
end $$;
-- b_: بعد a_force_shop_id وقبل device_defaults (رقم الطلب بيتحسب من الفرع)
create trigger b_branch_default before insert on public.devices for each row execute function public.tg_device_branch_default();
create trigger b_branch_default before insert on public.accounts for each row execute function public.tg_branch_default();

-- فرع الجهاز بيتغيّر من النقل بس (بعت/استلام)
create or replace function public.tg_device_branch_guard() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if (new.branch_id is distinct from old.branch_id or new.transfer_to is distinct from old.transfer_to
      or new.transfer_at is distinct from old.transfer_at or new.transfer_by is distinct from old.transfer_by)
     and not public.restoring() and current_setting('app.device_move', true) is distinct from 'on' then
    raise exception 'E_BRANCH_MOVE';
  end if;
  return new;
end $$;
create trigger b_device_branch_guard before update on public.devices for each row execute function public.tg_device_branch_guard();

-- فرع الخزنة ما بيتغيرش بعد ما اتعملت (رصيدها بتاع الفرع ده)
create or replace function public.tg_account_branch_guard() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if new.branch_id is distinct from old.branch_id and not public.restoring() then raise exception 'E_BRANCH_MOVE'; end if;
  return new;
end $$;
create trigger b_account_branch_guard before update on public.accounts for each row execute function public.tg_account_branch_guard();

-- القيد: الفرع المثبّت للعملية (الخزنة أو التصحيح)، وإلا فرع الجهاز، وإلا الفرع الشغال
create or replace function public.tg_entry_branch() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if new.branch_id is null then
    new.branch_id := coalesce(
      nullif(current_setting('app.branch', true), '')::uuid,
      (select d.branch_id from public.devices d where d.id = new.device_id),
      case when public.current_shop_id() = new.shop_id then public.op_branch() end,
      public.main_branch(new.shop_id));
  end if;
  if not exists (select 1 from public.branches b where b.id = new.branch_id and b.shop_id = new.shop_id) then raise exception 'E_BAD_BRANCH'; end if;
  return new;
end $$;
create trigger b_entry_branch before insert on public.journal_entries for each row execute function public.tg_entry_branch();

-- حركة المخزون: فرع قيدها (إلا التحويل بين الفروع وعكسه: كل حركة بفرعها)
create or replace function public.tg_move_branch() returns trigger
language plpgsql security definer set search_path = public as $$
declare eb uuid; st text;
begin
  select e.branch_id, e.source_type into eb, st from public.journal_entries e where e.id = new.entry_id;
  if new.branch_id is null then new.branch_id := eb; end if;
  if new.branch_id is distinct from eb and st not in ('stock_transfer', 'reversal') and not public.restoring() then raise exception 'E_BAD_BRANCH'; end if;
  if not exists (select 1 from public.branches b where b.id = new.branch_id and b.shop_id = new.shop_id) then raise exception 'E_BAD_BRANCH'; end if;
  return new;
end $$;
create trigger b_move_branch before insert on public.stock_moves for each row execute function public.tg_move_branch();

-- سطر خزنة لازم يكون من فرع القيد (إلا تحويل الفلوس بين الفروع وعكسه)
create or replace function public.tg_line_branch() returns trigger
language plpgsql security definer set search_path = public as $$
declare ab uuid; eb uuid; st text; rv uuid;
begin
  select a.branch_id into ab from public.accounts a where a.id = new.account_id and a.kind = 'cash';
  if ab is null or public.restoring() then return new; end if;
  select e.branch_id, e.source_type, e.reverses_id into eb, st, rv from public.journal_entries e where e.id = new.entry_id;
  if ab is distinct from eb and st <> 'transfer'
     and not (st = 'reversal' and exists (select 1 from public.journal_entries o where o.id = rv and o.source_type = 'transfer')) then
    raise exception 'E_BRANCH_CASHBOX';
  end if;
  return new;
end $$;
create trigger b_line_branch before insert on public.journal_lines for each row execute function public.tg_line_branch();

-- ---------- أنواع القيود: تحويل بضاعة بين الفروع ----------
alter table public.journal_entries drop constraint if exists journal_entries_source_type_check;
alter table public.journal_entries add constraint journal_entries_source_type_check check (source_type = any (array[
  'payment', 'delivery', 'purchase', 'supplier_payment', 'part_use', 'sale', 'expense', 'salary', 'salary_payment', 'advance',
  'advance_settle', 'capital', 'drawing', 'transfer', 'drawer_close', 'reversal', 'cost_adjust',
  'write_off', 'supplier_return', 'sale_return', 'opening', 'partner_capital', 'partner_withdrawal', 'profit_distribution', 'netting',
  'stock_transfer']));

-- ---------- رقم الطلب: بادئة الفرع ----------
CREATE OR REPLACE FUNCTION public.tg_device_defaults()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
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
  new.order_no := case when coalesce(pre, '') = '' then '' else pre || '-' end || y::text || '-' || lpad(n::text, 4, '0');
  new.status := 'received';
  new.received_by := auth.uid();
  new.received_at := now();
  new.delivered_at := null;
  return new;
end $function$;

-- ---------- المخزون لكل فرع ----------
create or replace function public.item_stock_at(p_item uuid, p_branch uuid, out qty bigint, out value bigint)
language sql stable security definer set search_path = public as $$
  select coalesce(sum(m.qty), 0)::bigint, coalesce(sum(m.value), 0)::bigint from public.stock_moves m where m.item_id = p_item and m.branch_id = p_branch
$$;
create or replace function public.item_stock(p_item uuid, out qty bigint, out value bigint)
language sql stable security definer set search_path = public as $$
  select * from public.item_stock_at(p_item, public.op_branch())
$$;
revoke execute on function public.item_stock(uuid), public.item_stock_at(uuid, uuid) from public, anon, authenticated;

-- الخروج من المخزون: من فرع القيد نفسه، بالمتوسط المرجّح بتاع الفرع ده
create or replace function public.ledger_issue(p_item uuid, p_qty bigint, p_entry uuid) returns bigint
language plpgsql security definer set search_path = public as $$
declare st record; cost bigint; b uuid;
begin
  perform 1 from public.items where id = p_item and shop_id = public.current_shop_id() and deleted_at is null for update;
  if not found then raise exception 'E_NOT_FOUND'; end if;
  select e.branch_id into b from public.journal_entries e where e.id = p_entry;
  select * into st from public.item_stock_at(p_item, b);
  if p_qty <= 0 or st.qty < p_qty then raise exception 'E_STOCK'; end if;
  cost := public.ledger_issue_cost(st.qty, st.value, p_qty);
  insert into public.stock_moves(shop_id, item_id, entry_id, qty, value, branch_id) values (public.current_shop_id(), p_item, p_entry, -p_qty, -cost, b);
  return cost;
end $$;
revoke execute on function public.ledger_issue(uuid, bigint, uuid) from public, anon, authenticated;

-- تسوية صنف في فرع: لو كميته صفر وفيه قيمة باقية، أو قيمته بالسالب، الفرق بيروح تكلفة البضاعة
drop function if exists public.ledger_settle_item(uuid, uuid);
create or replace function public.ledger_settle_item(p_item uuid, p_device uuid default null, p_branch uuid default null) returns void
language plpgsql security definer set search_path = public as $$
declare st record; v bigint; e uuid; b uuid; old text := current_setting('app.branch', true);
begin
  b := coalesce(p_branch, nullif(old, '')::uuid, (select d.branch_id from public.devices d where d.id = p_device), public.op_branch());
  select * into st from public.item_stock_at(p_item, b);
  if not ((st.qty = 0 and st.value <> 0) or (st.qty > 0 and st.value < 0)) then return; end if;
  v := st.value;
  perform set_config('app.branch', b::text, true);
  e := public.ledger_post('cost_adjust', p_item, 'فرق تكلفة مخزون',
    case when v > 0 then jsonb_build_array(public.ledger_line(public.ledger_acc('cogs'), v, 0), public.ledger_line(public.ledger_acc('inventory'), 0, v))
         else jsonb_build_array(public.ledger_line(public.ledger_acc('inventory'), -v, 0), public.ledger_line(public.ledger_acc('cogs'), 0, -v)) end,
    p_device);
  insert into public.stock_moves(shop_id, item_id, entry_id, qty, value, branch_id) values (public.current_shop_id(), p_item, e, 0, -v, b);
  perform set_config('app.branch', coalesce(old, ''), true);
end $$;
revoke execute on function public.ledger_settle_item(uuid, uuid, uuid) from public, anon, authenticated;

-- الخزنة: لازم تكون في فرع من فروع الموظف، وبتحدد فرع العملية (أول خزنة في العملية)
create or replace function public.ledger_cashbox(p uuid) returns public.accounts
language plpgsql security definer set search_path = public as $$
declare a public.accounts;
begin
  select * into a from public.accounts where id = p and shop_id = public.current_shop_id() and kind = 'cash' and active and deleted_at is null;
  if not found then raise exception 'E_BAD_ACCOUNT'; end if;
  if not public.can_branch(a.branch_id) then raise exception 'E_FORBIDDEN'; end if;
  perform public.pin_branch(a.branch_id);
  return a;
end $$;
revoke execute on function public.ledger_cashbox(uuid) from public, anon, authenticated;

-- ---------- RLS ----------
create policy branches_select on public.branches for select to authenticated
  using (shop_id = public.current_shop_id());
create policy staff_branches_select on public.staff_branches for select to authenticated
  using (shop_id = public.current_shop_id() and (public.current_app_role() = 'owner' or profile_id = auth.uid()));
grant select on public.branches, public.staff_branches to authenticated;

-- الأجهزة: فروع الموظف بس (والجهاز اللي في الطريق لفرعه)
drop policy if exists devices_select on public.devices;
create policy devices_select on public.devices for select to authenticated
  using (shop_id = public.current_shop_id()
         and (branch_id in (select unnest(public.my_branch_ids())) or transfer_to in (select unnest(public.my_branch_ids())))
         and (public.current_app_role() <> 'technician' or public.tech_can_see(id)));
drop policy if exists devices_insert on public.devices;
create policy devices_insert on public.devices for insert to authenticated
  with check (shop_id = public.current_shop_id() and public.current_app_role() in ('owner','reception') and branch_id in (select unnest(public.my_branch_ids())));
drop policy if exists devices_update on public.devices;
create policy devices_update on public.devices for update to authenticated
  using (shop_id = public.current_shop_id() and branch_id in (select unnest(public.my_branch_ids())))
  with check (shop_id = public.current_shop_id());

-- الخزن: الاستقبال بيشوف خزن فروعه بس
drop policy if exists accounts_select on public.accounts;
create policy accounts_select on public.accounts for select to authenticated using (
  shop_id = public.current_shop_id() and (public.current_app_role() = 'owner'
    or (public.current_app_role() = 'reception' and kind = 'cash' and branch_id in (select unnest(public.my_branch_ids())))));

-- ---------- إدارة الفروع (صاحب المحل) ----------
-- إضافة أو تعديل فرع. الفرع الجديد بيتعمله خزنة لكل طريقة دفع في المحل
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
    if exists (select 1 from public.branches x where x.shop_id = s and x.deleted_at is null and x.id <> b.id and lower(trim(x.name)) = lower(nm)) then raise exception 'E_DUP_NAME'; end if;
    update public.branches set name = nm, prefix = pre, phone = nullif(trim(p_phone), ''), address = nullif(trim(p_address), '') where id = b.id;
    return b.id;
  end if;
  if pre !~ '^[A-Z0-9]{1,4}$' then raise exception 'E_BAD_PREFIX'; end if;
  if exists (select 1 from public.branches x where x.shop_id = s and x.deleted_at is null and x.prefix = pre) then raise exception 'E_DUP_PREFIX'; end if;
  if exists (select 1 from public.branches x where x.shop_id = s and x.deleted_at is null and lower(trim(x.name)) = lower(nm)) then raise exception 'E_DUP_NAME'; end if;
  insert into public.branches(id, shop_id, name, prefix, phone, address) values (p_id, s, nm, pre, nullif(trim(p_phone), ''), nullif(trim(p_address), ''));
  for m in select unnest(array['cash']) union select unnest(payment_methods) from public.shops where id = s loop
    insert into public.accounts(shop_id, name, type, kind, method, branch_id) values (s, nm, 'asset', 'cash', m, p_id);
  end loop;
  return p_id;
end $$;

-- قفل فرع (soft delete): مش الرئيسي، ومن غير أجهزة مفتوحة ولا فلوس في خزنه ولا مخزون
create or replace function public.archive_branch(p_id uuid) returns void
language plpgsql security definer set search_path = public as $$
declare s uuid := public.current_shop_id(); b public.branches;
begin
  perform public.ledger_require(array['owner']::public.app_role[]);
  select * into b from public.branches where id = p_id and shop_id = s and deleted_at is null for update;
  if not found then raise exception 'E_NOT_FOUND'; end if;
  if b.is_main then raise exception 'E_MAIN_BRANCH'; end if;
  if exists (select 1 from public.devices d where (d.branch_id = p_id or d.transfer_to = p_id) and d.deleted_at is null and d.status not in ('delivered', 'unrepairable')) then raise exception 'E_HAS_OPEN_DEVICES'; end if;
  if exists (select 1 from public.journal_lines l join public.accounts a on a.id = l.account_id where a.branch_id = p_id group by a.id having sum(l.debit - l.credit) <> 0) then raise exception 'E_HAS_BALANCE'; end if;
  if exists (select 1 from public.stock_moves m where m.branch_id = p_id group by m.item_id having sum(m.qty) <> 0 or sum(m.value) <> 0) then raise exception 'E_HAS_STOCK'; end if;
  update public.accounts set active = false where branch_id = p_id;
  update public.staff_branches set deleted_at = now() where branch_id = p_id and deleted_at is null;
  update public.branches set deleted_at = now() where id = p_id;
end $$;

-- فروع الموظف (صاحب المحل بيشوف كل الفروع دايمًا)
create or replace function public.set_staff_branches(p_profile uuid, p_branches uuid[]) returns void
language plpgsql security definer set search_path = public as $$
declare s uuid := public.current_shop_id(); before uuid[];
begin
  perform public.ledger_require(array['owner']::public.app_role[]);
  if not exists (select 1 from public.profiles where id = p_profile and shop_id = s and deleted_at is null and role <> 'owner') then raise exception 'E_NOT_FOUND'; end if;
  if coalesce(array_length(p_branches, 1), 0) = 0 then raise exception 'E_BAD_INPUT'; end if;
  if exists (select 1 from unnest(p_branches) x where not exists (select 1 from public.branches b where b.id = x and b.shop_id = s and b.deleted_at is null)) then raise exception 'E_BAD_BRANCH'; end if;
  before := array(select branch_id from public.staff_branches where profile_id = p_profile and deleted_at is null);
  update public.staff_branches set deleted_at = now() where profile_id = p_profile and deleted_at is null and branch_id <> all (p_branches);
  insert into public.staff_branches(shop_id, profile_id, branch_id)
  select s, p_profile, x from unnest(p_branches) x
  where not exists (select 1 from public.staff_branches sb where sb.profile_id = p_profile and sb.branch_id = x and sb.deleted_at is null);
  insert into public.audit_log(shop_id, actor_id, action, entity, entity_id, before, after)
  values (s, auth.uid(), 'staff_branches', 'profiles', p_profile, jsonb_build_object('branches', before), jsonb_build_object('branches', p_branches));
end $$;

-- ---------- بين الفروع ----------
-- تحويل بضاعة: بتخرج من فرع بالمتوسط المرجّح بتاعه وتدخل الفرع التاني بنفس القيمة. حساب المخزون زي ما هو (القيد بيتقابل)
create or replace function public.transfer_stock(p_id uuid, p_item uuid, p_qty integer, p_from uuid, p_to uuid, p_note text default null) returns uuid
language plpgsql security definer set search_path = public as $$
declare s uuid := public.current_shop_id(); e uuid; cost bigint; inv uuid := public.ledger_acc('inventory');
begin
  perform public.ledger_require(array['owner']::public.app_role[]);
  e := public.ledger_idem(p_id);
  if e is not null then return e; end if;
  if p_from is null or p_to is null or p_from = p_to or coalesce(p_qty, 0) <= 0 then raise exception 'E_BAD_INPUT'; end if;
  if not exists (select 1 from public.branches where id = p_from and shop_id = s and deleted_at is null)
     or not exists (select 1 from public.branches where id = p_to and shop_id = s and deleted_at is null) then raise exception 'E_BAD_BRANCH'; end if;
  perform set_config('app.branch', p_from::text, true);
  e := gen_random_uuid();
  insert into public.journal_entries(id, shop_id, source_type, source_id, memo, idem_key, created_by, branch_id)
  values (e, s, 'stock_transfer', p_item, nullif(trim(p_note), ''), p_id, auth.uid(), p_from);
  cost := public.ledger_issue(p_item, p_qty, e);
  if cost <= 0 then raise exception 'E_BAD_AMOUNT'; end if;
  insert into public.stock_moves(shop_id, item_id, entry_id, qty, value, branch_id) values (s, p_item, e, p_qty, cost, p_to);
  insert into public.journal_lines(shop_id, entry_id, account_id, debit, credit) values (s, e, inv, cost, 0), (s, e, inv, 0, cost);
  perform public.ledger_settle_item(p_item, null, p_from);
  insert into public.audit_log(shop_id, actor_id, action, entity, entity_id, after)
  values (s, auth.uid(), 'stock_transfer', 'items', p_item, jsonb_build_object('qty', p_qty, 'from', p_from, 'to', p_to, 'value', cost, 'entry', e));
  return e;
end $$;

-- جهاز "في الطريق للفرع": بيتبعت من فرعه، والفرع التاني بيستلمه (أو بيتلغي)
create or replace function public.send_device(p_device uuid, p_to uuid) returns void
language plpgsql security definer set search_path = public as $$
declare s uuid := public.current_shop_id(); d public.devices;
begin
  perform public.ledger_require(array['owner', 'reception']::public.app_role[]);
  select * into d from public.devices where id = p_device and shop_id = s and deleted_at is null for update;
  if not found or not public.can_branch(d.branch_id) then raise exception 'E_NOT_FOUND'; end if;
  if d.status = 'delivered' then raise exception 'E_DELIVERED'; end if;
  if d.transfer_to is not null then raise exception 'E_IN_TRANSIT'; end if;
  if p_to = d.branch_id or not exists (select 1 from public.branches where id = p_to and shop_id = s and deleted_at is null) then raise exception 'E_BAD_BRANCH'; end if;
  perform set_config('app.device_move', 'on', true);
  update public.devices set transfer_to = p_to, transfer_at = now(), transfer_by = auth.uid() where id = d.id;
  perform set_config('app.device_move', 'off', true);
  insert into public.audit_log(shop_id, actor_id, action, entity, entity_id, before, after)
  values (s, auth.uid(), 'device_send', 'devices', d.id, jsonb_build_object('branch', d.branch_id), jsonb_build_object('to', p_to));
end $$;

create or replace function public.receive_device(p_device uuid) returns void
language plpgsql security definer set search_path = public as $$
declare s uuid := public.current_shop_id(); d public.devices;
begin
  perform public.ledger_require(array['owner', 'reception']::public.app_role[]);
  select * into d from public.devices where id = p_device and shop_id = s and deleted_at is null for update;
  if not found or d.transfer_to is null then raise exception 'E_NOT_FOUND'; end if;
  if not public.can_branch(d.transfer_to) then raise exception 'E_FORBIDDEN'; end if;
  perform set_config('app.device_move', 'on', true);
  update public.devices set branch_id = d.transfer_to, transfer_to = null, transfer_at = null, transfer_by = null where id = d.id;
  perform set_config('app.device_move', 'off', true);
  insert into public.audit_log(shop_id, actor_id, action, entity, entity_id, before, after)
  values (s, auth.uid(), 'device_receive', 'devices', d.id, jsonb_build_object('branch', d.branch_id), jsonb_build_object('branch', d.transfer_to));
end $$;

create or replace function public.cancel_device_transfer(p_device uuid) returns void
language plpgsql security definer set search_path = public as $$
declare s uuid := public.current_shop_id(); d public.devices;
begin
  perform public.ledger_require(array['owner', 'reception']::public.app_role[]);
  select * into d from public.devices where id = p_device and shop_id = s and deleted_at is null for update;
  if not found or d.transfer_to is null then raise exception 'E_NOT_FOUND'; end if;
  if not (public.can_branch(d.branch_id) or public.can_branch(d.transfer_to)) then raise exception 'E_FORBIDDEN'; end if;
  perform set_config('app.device_move', 'on', true);
  update public.devices set transfer_to = null, transfer_at = null, transfer_by = null where id = d.id;
  perform set_config('app.device_move', 'off', true);
  insert into public.audit_log(shop_id, actor_id, action, entity, entity_id, before, after)
  values (s, auth.uid(), 'device_transfer_cancel', 'devices', d.id, jsonb_build_object('to', d.transfer_to), null);
end $$;

-- مخزون صنف في كل فرع (للتحويل وشاشة المخزون)
create or replace function public.item_branch_stock(p_item uuid) returns table(branch_id uuid, qty bigint, value bigint)
language sql stable security definer set search_path = public as $$
  select b.id, coalesce(sum(m.qty), 0)::bigint, coalesce(sum(m.value), 0)::bigint
  from public.branches b left join public.stock_moves m on m.branch_id = b.id and m.item_id = p_item
  where b.shop_id = public.current_shop_id() and b.deleted_at is null and b.id = any (public.my_branch_ids())
    and public.current_app_role() in ('owner', 'reception', 'technician')
  group by b.id
$$;

revoke execute on function public.save_branch(uuid, text, text, text, text), public.archive_branch(uuid), public.set_staff_branches(uuid, uuid[]),
  public.transfer_stock(uuid, uuid, integer, uuid, uuid, text), public.send_device(uuid, uuid), public.receive_device(uuid),
  public.cancel_device_transfer(uuid), public.item_branch_stock(uuid) from public, anon;
grant execute on function public.save_branch(uuid, text, text, text, text), public.archive_branch(uuid), public.set_staff_branches(uuid, uuid[]),
  public.transfer_stock(uuid, uuid, integer, uuid, uuid, text), public.send_device(uuid, uuid), public.receive_device(uuid),
  public.cancel_device_transfer(uuid), public.item_branch_stock(uuid) to authenticated;


-- قايمة الأجهزة: الفرع، والجهاز اللي في الطريق لفرع (أعمدة جديدة في الآخر)
create or replace view public.devices_list with (security_invoker = true) as
select d.id, d.shop_id, d.order_no, d.brand, d.model, d.imei, d.color, d.status,
       d.received_at, d.delivered_at, d.customer_id, d.deleted_at,
       c.name as customer_name, c.phone as customer_phone,
       dc.estimated_cost, dc.final_cost, d.warranty_until,
       d.branch_id, d.transfer_to
from public.devices d
left join public.customers c on c.id = d.customer_id
left join public.device_costs dc on dc.device_id = d.id and dc.deleted_at is null;

-- ---------- دوال موجودة اتعدّلت للفروع ----------
-- bootstrap_account: (src: 0004_error_codes.sql)
create or replace function public.bootstrap_account(p_full_name text, p_shop_name text default null)
returns public.profiles
language plpgsql security definer set search_path = public as $$
declare
  uid uuid := auth.uid();
  em text;
  confirmed timestamptz;
  inv public.staff_invites;
  new_shop uuid;
  p public.profiles;
begin
  if uid is null then raise exception 'E_AUTH_REQUIRED'; end if;
  select * into p from public.profiles where id = uid;
  if found then
    if p.deleted_at is not null then raise exception 'E_SUSPENDED'; end if;
    return p;
  end if;

  select lower(u.email), u.email_confirmed_at into em, confirmed from auth.users u where u.id = uid;
  if em is null then raise exception 'E_UNKNOWN_USER'; end if;

  select * into inv from public.staff_invites
   where lower(email) = em and accepted_at is null and deleted_at is null
   order by created_at desc limit 1;

  if found then
    -- الانضمام بدعوة محتاج إيميل متأكَّد منه، عشان محدش ينتحل إيميل موظف
    if confirmed is null then raise exception 'E_EMAIL_UNCONFIRMED'; end if;
    insert into public.profiles(id, shop_id, full_name, email, role)
    values (uid, inv.shop_id, coalesce(nullif(trim(p_full_name), ''), inv.full_name), em, inv.role)
    returning * into p;
    update public.staff_invites set accepted_at = now() where id = inv.id;
    -- فروع الموظف من الدعوة (لو فاضية: الفرع الرئيسي بس)
    insert into public.staff_branches(shop_id, profile_id, branch_id)
    select inv.shop_id, uid, b.id from public.branches b where b.shop_id = inv.shop_id and b.deleted_at is null and b.id = any (inv.branch_ids);
    insert into public.audit_log(shop_id, actor_id, action, entity, entity_id, after)
    values (inv.shop_id, uid, 'join', 'profiles', uid, to_jsonb(p));
    return p;
  end if;

  new_shop := gen_random_uuid();
  insert into public.shops(id, shop_id, name)
  values (new_shop, new_shop, coalesce(nullif(trim(p_shop_name), ''), 'محل الصيانة'));
  insert into public.profiles(id, shop_id, full_name, email, role)
  values (uid, new_shop, coalesce(nullif(trim(p_full_name), ''), em), em, 'owner')
  returning * into p;
  insert into public.audit_log(shop_id, actor_id, action, entity, entity_id, after)
  values (new_shop, uid, 'create_shop', 'shops', new_shop, jsonb_build_object('name', p_shop_name));
  return p;
end $$;

-- reverse_entry: (src: 0026_edit_delete.sql)
CREATE OR REPLACE FUNCTION public.reverse_entry(p_entry uuid, p_reason text)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  o public.journal_entries;
  e uuid;
  lines jsonb;
  mv record;
begin
  if public.current_app_role() is null or not public.can_correct() then raise exception 'E_FORBIDDEN'; end if;
  if nullif(trim(p_reason), '') is null then raise exception 'E_REASON_REQUIRED'; end if;
  select * into o from public.journal_entries where id = p_entry and shop_id = public.current_shop_id() for update;
  if not found then raise exception 'E_NOT_FOUND'; end if;
  if o.source_type in ('reversal', 'cost_adjust') or exists (select 1 from public.journal_entries where reverses_id = o.id) then
    raise exception 'E_ALREADY_REVERSED';
  end if;
  select jsonb_agg(public.ledger_line(account_id, credit, debit, party_type, party_id)) into lines
  from public.journal_lines where entry_id = o.id;
  -- العكس بيتسجل في نفس فرع القيد الأصلي
  perform set_config('app.branch', o.branch_id::text, true);
  e := public.ledger_post('reversal', o.source_id, p_reason, lines, o.device_id, null, o.id);
  for mv in select * from public.stock_moves where entry_id = o.id loop
    perform 1 from public.items where id = mv.item_id for update;
    if (select coalesce(sum(qty), 0) from public.stock_moves where item_id = mv.item_id and branch_id = mv.branch_id) - mv.qty < 0 then
      raise exception 'E_STOCK';
    end if;
    insert into public.stock_moves(shop_id, item_id, entry_id, qty, value, branch_id) values (mv.shop_id, mv.item_id, e, -mv.qty, -mv.value, mv.branch_id);
  end loop;
  for mv in select distinct item_id, branch_id from public.stock_moves where entry_id = o.id loop
    perform public.ledger_settle_item(mv.item_id, o.device_id, mv.branch_id);
  end loop;
  insert into public.audit_log(shop_id, actor_id, action, entity, entity_id, before, after)
  values (o.shop_id, auth.uid(), 'reverse_entry', 'journal_entries', o.id, to_jsonb(o), jsonb_build_object('reversal_id', e, 'reason', p_reason));
  return e;
end $function$;

-- backup_snapshot: (src: 0032_lists.sql)
create or replace function public.backup_snapshot(p_shop uuid) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare
  res jsonb := jsonb_build_object('format', 'warsha-backup', 'version', 1, 'generated_at', now(), 'shop_id', p_shop);
  t text;
  rows jsonb;
begin
  foreach t in array array['shops', 'branches', 'staff_branches', 'shop_branding', 'profiles', 'customers', 'devices', 'device_costs', 'status_log', 'device_notes', 'device_photos', 'device_checks',
                           'quote_decisions', 'message_templates', 'message_log', 'accounts', 'journal_entries', 'journal_lines', 'payments', 'drawer_closings',
                           'suppliers', 'items', 'stock_moves', 'purchases', 'labor_rates', 'specialties', 'staff_specialties', 'routes', 'repair_steps',
                           'repair_videos', 'device_ratings', 'issue_presets', 'partners', 'profit_distributions', 'party_links', 'shop_lists', 'audit_log'] loop
    execute format('select coalesce(jsonb_agg(to_jsonb(x)), ''[]''::jsonb) from public.%I x where x.shop_id = $1', t) into rows using p_shop;
    res := res || jsonb_build_object(t, rows);
  end loop;
  select coalesce(jsonb_agg(jsonb_build_object('device_id', device_id, 'kind', kind, 'erased_at', erased_at)), '[]'::jsonb)
    into rows from public.device_passcodes where shop_id = p_shop;
  return res || jsonb_build_object('device_passcodes', rows);
end $$;

-- restore_backup: (src: 0032_lists.sql)
create or replace function public.restore_backup(p_data jsonb) returns jsonb
-- extensions: فيها gen_random_bytes على Supabase
language plpgsql security definer set search_path = public, extensions, pg_temp as $$
declare
  s uuid := public.current_shop_id();
  me uuid := auth.uid();
  old_shop uuid;
  old_owner uuid;
  sh jsonb;
  t text;
  r jsonb;
  rows jsonb;
  n int;
  bad int;
  counts jsonb := '{}'::jsonb;
  -- بالترتيب ده عشان كل صف يلاقي اللي بيشاور عليه
  tabs text[] := array['branches', 'profiles', 'staff_branches', 'shop_branding', 'accounts', 'customers', 'suppliers', 'party_links', 'partners', 'specialties', 'staff_specialties', 'routes', 'labor_rates',
                       'issue_presets', 'shop_lists', 'message_templates', 'items', 'devices', 'device_costs', 'status_log', 'device_notes', 'device_checks',
                       'quote_decisions', 'repair_steps', 'repair_videos', 'device_ratings', 'journal_entries', 'journal_lines', 'profit_distributions', 'payments',
                       'purchases', 'stock_moves', 'drawer_closings', 'message_log', 'audit_log'];
  -- الجداول دي ليها نسخة اتعملت مع التسجيل: بتتطابق بالكود (أو المفتاح) وبتاخد قيم النسخة
  keyed text[] := array['branches', 'accounts', 'routes', 'specialties', 'message_templates', 'labor_rates', 'shop_branding'];
begin
  perform public.ledger_require(array['owner']::public.app_role[]);
  if s is null or me is null then raise exception 'E_FORBIDDEN'; end if;
  if p_data is null or p_data->>'format' is distinct from 'warsha-backup' or coalesce((p_data->>'version')::int, 0) <> 1 then
    raise exception 'E_BACKUP_FORMAT';
  end if;
  old_shop := (p_data->>'shop_id')::uuid;
  if old_shop is null or old_shop = s then raise exception 'E_BACKUP_FORMAT'; end if;

  -- محل جديد فاضي بس
  if exists (select 1 from public.devices where shop_id = s) or exists (select 1 from public.customers where shop_id = s)
     or exists (select 1 from public.journal_entries where shop_id = s) or exists (select 1 from public.items where shop_id = s)
     or exists (select 1 from public.suppliers where shop_id = s) or exists (select 1 from public.payments where shop_id = s)
     or exists (select 1 from public.purchases where shop_id = s) or exists (select 1 from public.drawer_closings where shop_id = s)
     or exists (select 1 from public.stock_moves where shop_id = s)
     or exists (select 1 from public.profiles where shop_id = s and id <> me) then
    raise exception 'E_RESTORE_NOT_EMPTY';
  end if;

  perform set_config('warsha.restore', 'on', true);
  drop table if exists pg_temp._rmap;
  create temp table _rmap(old uuid primary key, new uuid not null) on commit drop;
  insert into _rmap values (old_shop, s);

  -- 1) بيانات المحل نفسه (من غير الخطة والإيقاف واللوجو اللي في Storage)
  sh := p_data->'shops'->0;
  if sh is not null then
    update public.shops set
      name = coalesce(sh->>'name', name), phone = sh->>'phone', address = sh->>'address',
      receipt_terms = coalesce(sh->>'receipt_terms', receipt_terms), warranty_days = coalesce((sh->>'warranty_days')::int, warranty_days),
      country = coalesce(sh->>'country', country), currency = coalesce(sh->>'currency', currency),
      payment_methods = coalesce(array(select jsonb_array_elements_text(sh->'payment_methods')), payment_methods),
      theme = coalesce(sh->>'theme', theme), locale = coalesce(sh->>'locale', locale),
      default_margin_pct = coalesce((sh->>'default_margin_pct')::int, default_margin_pct),
      extras = coalesce(sh->'extras', extras), max_discount_pct = coalesce((sh->>'max_discount_pct')::int, max_discount_pct)
    where id = s;
  end if;

  -- 2) الـ ids الجديدة
  -- صاحب المحل في النسخة = اللي بيسترجع دلوقتي
  select (x->>'id')::uuid into old_owner from jsonb_array_elements(coalesce(p_data->'profiles', '[]')) x
   where x->>'role' = 'owner' order by x->>'created_at' limit 1;
  if old_owner is not null then insert into _rmap values (old_owner, me) on conflict do nothing; end if;
  insert into _rmap select (x->>'id')::uuid, coalesce((select a.id from public.accounts a where a.shop_id = s and a.code = x->>'code' and x->>'code' is not null), gen_random_uuid())
    from jsonb_array_elements(coalesce(p_data->'accounts', '[]')) x on conflict do nothing;
  -- الفرع الرئيسي في النسخة = الفرع الرئيسي للمحل الجديد
  insert into _rmap select (x->>'id')::uuid, public.main_branch(s)
    from jsonb_array_elements(coalesce(p_data->'branches', '[]')) x where (x->>'is_main')::boolean and x->>'deleted_at' is null on conflict do nothing;
  insert into _rmap select (x->>'id')::uuid, coalesce((select a.id from public.routes a where a.shop_id = s and a.code = x->>'code' and x->>'code' is not null), gen_random_uuid())
    from jsonb_array_elements(coalesce(p_data->'routes', '[]')) x on conflict do nothing;
  insert into _rmap select (x->>'id')::uuid, coalesce((select a.id from public.specialties a where a.shop_id = s and a.code = x->>'code' and x->>'code' is not null), gen_random_uuid())
    from jsonb_array_elements(coalesce(p_data->'specialties', '[]')) x on conflict do nothing;
  insert into _rmap select (x->>'id')::uuid, coalesce((select a.id from public.message_templates a where a.shop_id = s and a.key = x->>'key'), gen_random_uuid())
    from jsonb_array_elements(coalesce(p_data->'message_templates', '[]')) x on conflict do nothing;
  insert into _rmap select (x->>'id')::uuid, coalesce((select a.id from public.labor_rates a where a.shop_id = s and a.deleted_at is null and lower(trim(a.issue)) = lower(trim(x->>'issue')) and x->>'deleted_at' is null), gen_random_uuid())
    from jsonb_array_elements(coalesce(p_data->'labor_rates', '[]')) x on conflict do nothing;
  insert into _rmap select (x->>'id')::uuid, coalesce((select a.id from public.shop_branding a where a.shop_id = s), gen_random_uuid())
    from jsonb_array_elements(coalesce(p_data->'shop_branding', '[]')) x on conflict do nothing;
  foreach t in array tabs loop
    insert into _rmap select (x->>'id')::uuid, gen_random_uuid() from jsonb_array_elements(coalesce(p_data->t, '[]')) x where x ? 'id' on conflict do nothing;
  end loop;

  -- 3) الصفوف نفسها بالترتيب
  foreach t in array tabs loop
    rows := '[]'::jsonb;
    for r in select public.restore_remap(x) from jsonb_array_elements(coalesce(p_data->t, '[]')) x loop
      if t = 'profiles' then
        -- صاحب المحل موجود أصلًا. الباقيين موظفين سابقين (من غير حساب دخول)
        continue when (r->>'id')::uuid = me;
        r := r || jsonb_build_object('deleted_at', coalesce(r->>'deleted_at', now()::text));
      elsif t = 'devices' then
        -- كود التتبع (الـ QR) بيفضل زي ما هو، إلا لو مستخدم في المشروع ده (المحل الأصلي لسه هنا)
        if exists (select 1 from public.devices d where d.tracking_token = r->>'tracking_token') then
          r := r || jsonb_build_object('tracking_token', encode(gen_random_bytes(12), 'hex'));
        end if;
      elsif t = 'journal_entries' then
        if r->>'idem_key' is not null and exists (select 1 from public.journal_entries j where j.idem_key = (r->>'idem_key')::uuid) then
          r := r || jsonb_build_object('idem_key', gen_random_uuid());
        end if;
      elsif t = 'accounts' and r->>'kind' = 'cash' and r->>'branch_id' is null then
        -- نسخة من قبل الفروع: الخزن كلها في الفرع الرئيسي
        r := r || jsonb_build_object('branch_id', public.main_branch(s));
      elsif t = 'shop_branding' then
        -- اللوجو الملون والحراري جوه الصف نفسه. الملف الأصلي في Storage مش جوه النسخة
        r := r || jsonb_build_object('logo_path', null);
      end if;
      if t = any (keyed) and exists (select 1 from _rmap m where m.new = (r->>'id')::uuid and m.old <> m.new)
         and (t <> 'shop_branding' or exists (select 1 from public.shop_branding b where b.id = (r->>'id')::uuid)) then
        -- موجود من التسجيل: بياخد قيم النسخة
        execute format('select count(*) from public.%I where id = $1', t) into n using (r->>'id')::uuid;
        if n > 0 then
          execute format('update public.%1$I x set (%2$s) = (select %2$s from jsonb_populate_record(null::public.%1$I, $1)) where x.id = $2', t,
            (select string_agg(quote_ident(c.column_name), ', ' order by c.ordinal_position) from information_schema.columns c
              where c.table_schema = 'public' and c.table_name = t and c.column_name not in ('id', 'shop_id')))
            using r, (r->>'id')::uuid;
          continue;
        end if;
      end if;
      rows := rows || jsonb_build_array(r);
    end loop;
    if jsonb_array_length(rows) > 0 then
      -- overriding system value: أرقام القيود (entry_no) بترجع زي ما هي
      execute format('insert into public.%1$I overriding system value select * from jsonb_populate_recordset(null::public.%1$I, $1)', t) using rows;
    end if;
    counts := counts || jsonb_build_object(t, jsonb_array_length(coalesce(p_data->t, '[]')));
  end loop;

  -- 4) عدّاد أرقام الطلبات: من آخر رقم راجع في كل سنة
  -- (لكل فرع: الرقم ممكن يبقى قبله بادئة الفرع B2-2026-0001)
  insert into public.order_counters(shop_id, branch_id, year, last_value)
  select s, branch_id, (regexp_match(order_no, '(\d{4})-(\d+)$'))[1]::int, max((regexp_match(order_no, '(\d{4})-(\d+)$'))[2]::int)
    from public.devices where shop_id = s and order_no ~ '\d{4}-\d+$' group by 2, 3
  on conflict (shop_id, branch_id, year) do update set last_value = greatest(public.order_counters.last_value, excluded.last_value);

  -- 5) التأكد: كل قيد متوازن، ورصيد كل حساب = رصيده في النسخة بالظبط
  select count(*) into bad from (
    select entry_id from public.journal_lines where shop_id = s group by entry_id having sum(debit) <> sum(credit)) x;
  if bad > 0 then raise exception 'E_RESTORE_UNBALANCED'; end if;
  select count(*) into bad from (
    select m.new acc, sum((l->>'debit')::bigint - (l->>'credit')::bigint) b
      from jsonb_array_elements(coalesce(p_data->'journal_lines', '[]')) l join _rmap m on m.old = (l->>'account_id')::uuid group by m.new
  ) x full join (select account_id, sum(debit - credit) b from public.journal_lines where shop_id = s group by account_id) y on y.account_id = x.acc
  where coalesce(x.b, 0) <> coalesce(y.b, 0);
  if bad > 0 then raise exception 'E_RESTORE_MISMATCH'; end if;
  -- وعدد الصفوف في كل جدول (الحسابات والقوالب اللي اتعملت مع التسجيل ممكن تزيد عن النسخة، مش تقل)
  foreach t in array tabs loop
    execute format('select count(*) from public.%I where shop_id = $1', t) into n using s;
    if n < jsonb_array_length(coalesce(p_data->t, '[]')) - (case when t = 'profiles' and old_owner is not null then 1 else 0 end) then
      raise exception 'E_RESTORE_MISMATCH';
    end if;
  end loop;

  perform set_config('warsha.restore', 'off', true);
  insert into public.audit_log(shop_id, actor_id, action, entity, entity_id, after)
  values (s, me, 'backup_restore', 'shops', s, jsonb_build_object('from_shop', old_shop, 'generated_at', p_data->>'generated_at', 'counts', counts));
  return jsonb_build_object('restored', true, 'counts', counts);
end $$;

-- ---------- المخزون في الشاشات: الفرع الشغال، أو كل الفروع (صاحب المحل) ----------
drop function if exists public.items_stock();
create or replace function public.items_stock(p_all boolean default false) returns table(id uuid, kind text, name text, sku text, sale_price integer, qty bigint, avg_cost bigint, value bigint, min_qty integer, supplier_id uuid, short boolean, category text, barcode text, image_path text)
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
         i.category, i.barcode, i.image_path
  from public.items i
  left join (select m.item_id, sum(m.qty) as q, sum(m.value) as v from public.stock_moves m where everywhere or m.branch_id = b group by m.item_id) st on st.item_id = i.id
  where i.shop_id = public.current_shop_id() and i.deleted_at is null
  order by i.kind, i.name;
end $$;
revoke execute on function public.items_stock(boolean) from public, anon;
grant execute on function public.items_stock(boolean) to authenticated;

-- ---------- الوضع المالي لفرع (التقارير بفلتر الفرع) ----------
-- financial_position: (src: 0031_partner_capital.sql)
drop function if exists public.financial_position(timestamptz, timestamptz);
create or replace function public.financial_position(p_from timestamptz, p_to timestamptz, p_branch uuid default null) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare
  s uuid := public.current_shop_id();
  res jsonb;
begin
  perform public.ledger_require(array['owner']::public.app_role[]);
  with bal as (
    select a.id, a.code, a.name, a.type, a.kind, a.method, l.party_type, l.party_id,
           coalesce(sum((l.debit - l.credit) * public.account_sign(a.type)), 0)::bigint as b
    from public.accounts a
    -- B: فرع واحد: الخزن بتاعته (كل حركاتها)، وباقي الحسابات من قيود الفرع ده
    left join public.journal_lines l on l.account_id = a.id
      and (p_branch is null or a.kind = 'cash' or exists (select 1 from public.journal_entries be where be.id = l.entry_id and be.branch_id = p_branch))
    where a.shop_id = s and (p_branch is null or a.kind <> 'cash' or a.branch_id = p_branch)
    group by a.id, l.party_type, l.party_id
  ),
  -- المعادلة والتوازن دايمًا للمحل كله (الدفتر واحد)
  bal_all as (
    select a.type, coalesce(sum((l.debit - l.credit) * public.account_sign(a.type)), 0)::bigint as b
    from public.accounts a left join public.journal_lines l on l.account_id = a.id
    where a.shop_id = s group by a.id, a.type
  ),
  eq_all as (
    select coalesce(sum(b) filter (where type = 'asset'), 0)::bigint as assets,
           coalesce(sum(b) filter (where type = 'liability'), 0)::bigint as liabilities,
           coalesce(sum(b) filter (where type = 'equity'), 0)::bigint as equity,
           (coalesce(sum(b) filter (where type = 'revenue'), 0) - coalesce(sum(b) filter (where type = 'expense'), 0))::bigint as earnings
    from bal_all
  ),
  acc as (select id, code, name, type, kind, method, sum(b)::bigint as b from bal group by id, code, name, type, kind, method),
  per as (
    select coalesce(sum(case when a.type = 'revenue' then l.credit - l.debit else 0 end), 0)::bigint as revenue,
           coalesce(sum(case when a.type = 'expense' then l.debit - l.credit else 0 end), 0)::bigint as expenses
    from public.journal_lines l join public.accounts a on a.id = l.account_id join public.journal_entries e on e.id = l.entry_id
    where l.shop_id = s and e.occurred_at >= p_from and e.occurred_at < p_to and (p_branch is null or e.branch_id = p_branch)
  ),
  tot as (
    select coalesce(sum(debit), 0)::bigint as d, coalesce(sum(credit), 0)::bigint as c from public.journal_lines where shop_id = s
  ),
  unb as (
    select count(*)::int as n from (
      select e.id from public.journal_entries e left join public.journal_lines l on l.entry_id = e.id
      where e.shop_id = s group by e.id having coalesce(sum(l.debit), 0) <> coalesce(sum(l.credit), 0) or count(l.id) < 2) x
  ),
  eq as (
    select coalesce(sum(b) filter (where type = 'asset'), 0)::bigint as assets,
           coalesce(sum(b) filter (where type = 'liability'), 0)::bigint as liabilities,
           coalesce(sum(b) filter (where type = 'equity'), 0)::bigint as equity,
           (coalesce(sum(b) filter (where type = 'revenue'), 0) - coalesce(sum(b) filter (where type = 'expense'), 0))::bigint as earnings
    from acc
  ),
  parts as (
    select
      coalesce(sum(b) filter (where kind = 'cash'), 0)::bigint as cash,
      coalesce(sum(greatest(b, 0)) filter (where kind in ('receivable', 'advances')), 0)::bigint as receivables,
      (coalesce(sum(greatest(b, 0)) filter (where kind in ('payable', 'salaries')), 0)
        + coalesce(sum(greatest(-b, 0)) filter (where kind in ('receivable', 'advances')), 0)
        + coalesce(sum(greatest(-b, 0)) filter (where kind = 'inventory'), 0))::bigint as payables,
      coalesce(sum(greatest(-b, 0)) filter (where kind in ('payable', 'salaries')), 0)::bigint as payables_debit,
      coalesce(sum(greatest(b, 0)) filter (where kind = 'inventory'), 0)::bigint as inventory,
      coalesce(sum(b) filter (where kind = 'fixed_asset'), 0)::bigint as fixed_assets,
      -- أرباح اتوزعت على الشركاء ولسه ما اتسحبتش (حقوق ملكية، مش دين من بره)
      coalesce(sum(greatest(b, 0)) filter (where kind = 'partner_current'), 0)::bigint as partners_due
    from bal
  ),
  days as (
    select (date_trunc('day', e.occurred_at at time zone 'Africa/Cairo'))::date as day,
           coalesce(sum(case when a.type = 'revenue' then l.credit - l.debit else 0 end), 0)::bigint as revenue,
           coalesce(sum(case when a.type = 'expense' then l.debit - l.credit else 0 end), 0)::bigint as expenses
    from public.journal_lines l join public.accounts a on a.id = l.account_id join public.journal_entries e on e.id = l.entry_id
    where l.shop_id = s and e.occurred_at >= p_from and e.occurred_at < p_to and a.type in ('revenue', 'expense') and (p_branch is null or e.branch_id = p_branch)
    group by 1
  )
  select jsonb_build_object(
    'cash', p.cash,
    'receivables', p.receivables + p.payables_debit,
    'payables', p.payables,
    -- مخزون فرع: قيمة حركاته (التحويل بين الفروع بيتقابل في حساب المخزون نفسه)
    'inventory', case when p_branch is null then p.inventory else (select coalesce(sum(m.value), 0)::bigint from public.stock_moves m where m.shop_id = s and m.branch_id = p_branch) end,
    'revenue', per.revenue,
    'expenses', per.expenses,
    'profit', per.revenue - per.expenses,
    'fixed_assets', p.fixed_assets,
    'partners_due', p.partners_due,
    -- قيمة المحل = الأصول − الالتزامات اللي لناس من بره بس (رأس مال الشركاء وأرباحهم حقوق ملكية، فما بتقللهاش)
    'net_worth', p.cash + p.receivables + p.payables_debit + p.fixed_assets - p.payables
      + case when p_branch is null then p.inventory else (select coalesce(sum(m.value), 0)::bigint from public.stock_moves m where m.shop_id = s and m.branch_id = p_branch) end,
    'branch', p_branch,
    -- حقوق الملكية بالتفصيل (من أول يوم): رأس مال صاحب المحل، والسحوبات، ورأس مال وجاري كل شريك، والأرباح المحتجزة
    'equity_parts', jsonb_build_object(
      'owner_capital', coalesce((select b from acc where code = 'capital'), 0),
      'drawings', -coalesce((select b from acc where code = 'drawings'), 0),
      'retained', eq.earnings + coalesce((select b from acc where code = 'retained'), 0),
      'partners', coalesce((select jsonb_agg(jsonb_build_object('id', pt.id, 'name', pt.name, 'share_bp', pt.share_bp,
          'capital', coalesce((select sum(b.b) from bal b where b.kind = 'partner_capital' and b.party_id = pt.id), 0),
          'current', coalesce((select sum(b.b) from bal b where b.kind = 'partner_current' and b.party_id = pt.id), 0)) order by pt.share_bp desc, pt.name)
        from public.partners pt where pt.shop_id = s and (pt.deleted_at is null or exists (select 1 from bal b where b.party_id = pt.id and b.b <> 0))), '[]'::jsonb)),
    'equation', jsonb_build_object('assets', eq_all.assets, 'liabilities', eq_all.liabilities, 'equity', eq_all.equity, 'earnings', eq_all.earnings),
    'debits', tot.d, 'credits', tot.c, 'unbalanced_entries', unb.n,
    'balanced', tot.d = tot.c and unb.n = 0 and eq_all.assets = eq_all.liabilities + eq_all.equity + eq_all.earnings,
    'cashboxes', coalesce((select jsonb_agg(jsonb_build_object('id', a.id, 'code', a.code, 'name', a.name, 'method', a.method, 'balance', a.b,
         'branch_id', (select x.branch_id from public.accounts x where x.id = a.id)) order by a.code nulls last, a.name)
       from acc a where a.kind = 'cash'), '[]'::jsonb),
    'top_customers', coalesce((select jsonb_agg(x order by (x ->> 'balance')::bigint desc) from (
       select jsonb_build_object('id', b.party_id, 'name', c.name, 'balance', sum(b.b)) as x
       from bal b join public.customers c on c.id = b.party_id where b.kind = 'receivable' and b.party_type = 'customer'
       group by b.party_id, c.name having sum(b.b) > 0 order by sum(b.b) desc limit 5) t), '[]'::jsonb),
    'top_suppliers', coalesce((select jsonb_agg(x order by (x ->> 'balance')::bigint desc) from (
       select jsonb_build_object('id', b.party_id, 'name', sp.name, 'balance', sum(b.b)) as x
       from bal b join public.suppliers sp on sp.id = b.party_id where b.kind = 'payable' and b.party_type = 'supplier'
       group by b.party_id, sp.name having sum(b.b) > 0 order by sum(b.b) desc limit 5) t), '[]'::jsonb),
    'daily', coalesce((select jsonb_agg(jsonb_build_object('day', day, 'revenue', revenue, 'expenses', expenses, 'profit', revenue - expenses) order by day) from days), '[]'::jsonb),
    'by_method', coalesce((select jsonb_object_agg(method, total) from (
       select p2.method, sum(p2.amount)::bigint as total from public.payments p2
       where p2.shop_id = s and p2.created_at >= p_from and p2.created_at < p_to
         and (p_branch is null or exists (select 1 from public.journal_entries pe where pe.id = p2.entry_id and pe.branch_id = p_branch))
         and not exists (select 1 from public.journal_entries r where r.reverses_id = p2.entry_id)
       group by p2.method) m), '{}'::jsonb),
    'delivered', (select count(*) from public.devices d where d.shop_id = s and d.delivered_at >= p_from and d.delivered_at < p_to and (p_branch is null or d.branch_id = p_branch)),
    'closings', coalesce((select jsonb_agg(jsonb_build_object('cashbox', dc.cashbox_id, 'expected', dc.expected, 'counted', dc.counted, 'diff', dc.diff, 'at', dc.created_at,
       'by', (select full_name from public.profiles where id = dc.closed_by)) order by dc.created_at)
       from public.drawer_closings dc where dc.shop_id = s and dc.created_at >= p_from and dc.created_at < p_to
         and (p_branch is null or exists (select 1 from public.accounts ca where ca.id = dc.cashbox_id and ca.branch_id = p_branch))), '[]'::jsonb)
  ) into res
  from parts p, per, tot, unb, eq, eq_all;
  return res;
end $$;
revoke execute on function public.financial_position(timestamptz, timestamptz, uuid) from public, anon;
grant execute on function public.financial_position(timestamptz, timestamptz, uuid) to authenticated;

-- ---------- الشركاء: على المحل كله أو على فرع ----------
-- شريك على فرع: نصيبه من ربح الفرع ده بس. ومجموع النسب في أي فرع (شركاء المحل كله + شركاء الفرع) مايعديش 100%
alter table public.partners add column branch_id uuid references public.branches(id);

create or replace function public.branch_profit(p_shop uuid, p_branch uuid, p_from timestamptz, p_to timestamptz) returns bigint
language sql stable security definer set search_path = public as $$
  select coalesce(sum(l.credit - l.debit), 0)::bigint
  from public.journal_lines l join public.accounts a on a.id = l.account_id join public.journal_entries e on e.id = l.entry_id
  where e.shop_id = p_shop and e.branch_id = p_branch and a.type in ('revenue', 'expense') and e.occurred_at >= p_from and e.occurred_at < p_to
$$;
revoke execute on function public.branch_profit(uuid, uuid, timestamptz, timestamptz) from public, anon, authenticated;

create or replace function public.tg_partners_share() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  perform pg_advisory_xact_lock(hashtext('partners:' || new.shop_id::text));
  -- الشريك اللي ليه أو عليه فلوس ما بيتحذفش (سوّي حسابه الأول)
  if tg_op = 'UPDATE' and old.deleted_at is null and new.deleted_at is not null
     and exists (select 1 from public.journal_lines l where l.party_type = 'partner' and l.party_id = new.id group by l.party_id having sum(l.credit - l.debit) <> 0) then
    raise exception 'E_HAS_BALANCE';
  end if;
  if new.branch_id is not null and not exists (select 1 from public.branches b where b.id = new.branch_id and b.shop_id = new.shop_id) then
    raise exception 'E_BAD_BRANCH';
  end if;
  -- المحل كله
  if (select coalesce(sum(share_bp), 0) from public.partners where shop_id = new.shop_id and deleted_at is null and branch_id is null) > 10000 then
    raise exception 'E_SHARE_OVER_100';
  end if;
  -- كل فرع: شركاء المحل كله + شركاء الفرع
  if exists (
    select 1 from public.branches b
    where b.shop_id = new.shop_id and b.deleted_at is null
      and (select coalesce(sum(p.share_bp), 0) from public.partners p where p.shop_id = new.shop_id and p.deleted_at is null and (p.branch_id is null or p.branch_id = b.id)) > 10000) then
    raise exception 'E_SHARE_OVER_100';
  end if;
  return null;
end $$;

-- التوزيع: شريك المحل كله من ربح المحل، وشريك الفرع من ربح فرعه
create or replace function public.profit_split(p_from timestamptz, p_to timestamptz) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare s uuid := public.current_shop_id(); pr bigint;
begin
  perform public.ledger_require(array['owner']::public.app_role[]);
  if p_to <= p_from then raise exception 'E_BAD_INPUT'; end if;
  pr := public.period_profit(s, p_from, p_to);
  return jsonb_build_object(
    'profit', pr,
    'overlap', exists (select 1 from public.profit_distributions d where d.shop_id = s and d.period_from < p_to and d.period_to > p_from
                        and not exists (select 1 from public.journal_entries r where r.reverses_id = d.entry_id)),
    'shares', coalesce((select jsonb_agg(jsonb_build_object('partner', p.id, 'name', p.name, 'share_bp', p.share_bp, 'branch_id', p.branch_id,
                 'base', case when p.branch_id is null then pr else public.branch_profit(s, p.branch_id, p_from, p_to) end,
                 'amount', ((case when p.branch_id is null then pr else public.branch_profit(s, p.branch_id, p_from, p_to) end) * p.share_bp / 10000)::bigint)
                 order by p.share_bp desc, p.name)
               from public.partners p where p.shop_id = s and p.deleted_at is null and p.joined_on <= ((p_to - interval '1 microsecond') at time zone 'Africa/Cairo')::date), '[]'::jsonb));
end $$;

drop function if exists public.partner_balances();
create or replace function public.partner_balances() returns table(id uuid, name text, phone text, share_bp integer, joined_on date, capital bigint, current bigint, total bigint, branch_id uuid)
language plpgsql stable security definer set search_path = public as $$
begin
  perform public.ledger_require(array['owner']::public.app_role[]);
  return query
  select p.id, p.name, p.phone, p.share_bp, p.joined_on,
         coalesce(sum(l.credit - l.debit) filter (where a.kind = 'partner_capital'), 0)::bigint,
         coalesce(sum(l.credit - l.debit) filter (where a.kind = 'partner_current'), 0)::bigint,
         coalesce(sum(l.credit - l.debit), 0)::bigint,
         p.branch_id
  from public.partners p
  left join public.journal_lines l on l.party_type = 'partner' and l.party_id = p.id
  left join public.accounts a on a.id = l.account_id
  where p.shop_id = public.current_shop_id() and p.deleted_at is null
  group by p.id
  order by p.share_bp desc, p.name;
end $$;
revoke execute on function public.partner_balances() from public, anon;
grant execute on function public.partner_balances() to authenticated;

-- ---------- فلتر الفرع في التقارير (null = كل الفروع) ----------
-- pl_breakdown: (src: 0011_finance_drilldown.sql)
drop function if exists public.pl_breakdown(timestamptz, timestamptz);
create or replace function public.pl_breakdown(p_from timestamptz, p_to timestamptz, p_branch uuid default null)
returns table(account_id uuid, code text, name text, type public.account_type, amount bigint)
language plpgsql stable security definer set search_path = public as $$
begin
  perform public.ledger_require(array['owner']::public.app_role[]);
  return query
  select a.id, a.code, a.name, a.type,
         sum(case when a.type = 'revenue' then l.credit - l.debit else l.debit - l.credit end)::bigint
  from public.journal_lines l
  join public.accounts a on a.id = l.account_id
  join public.journal_entries e on e.id = l.entry_id
  where l.shop_id = public.current_shop_id() and a.type in ('revenue', 'expense') and e.occurred_at >= p_from and e.occurred_at < p_to
    and (p_branch is null or e.branch_id = p_branch)
  group by a.id
  having sum(l.debit - l.credit) <> 0
  order by a.type desc, 5 desc;
end $$;
revoke execute on function public.pl_breakdown(timestamptz, timestamptz, uuid) from public, anon;
grant execute on function public.pl_breakdown(timestamptz, timestamptz, uuid) to authenticated;
-- issue_report: (src: 0014_technicians.sql)
drop function if exists public.issue_report(timestamptz, timestamptz);
create or replace function public.issue_report(p_from timestamptz, p_to timestamptz, p_branch uuid default null)
returns table(route_id uuid, code text, name text, devices integer, revenue bigint, parts bigint, profit bigint)
language plpgsql stable security definer set search_path = public as $$
#variable_conflict use_column
begin
  perform public.ledger_require(array['owner']::public.app_role[]);
  return query
  select r.id, r.code, r.name, count(d.id)::int,
         coalesce(sum(dc.final_cost), 0)::bigint,
         coalesce(sum((select -sum(m.value) from public.stock_moves m join public.journal_entries e on e.id = m.entry_id where e.device_id = d.id and e.source_type in ('part_use', 'reversal'))), 0)::bigint,
         (coalesce(sum(dc.final_cost), 0) - coalesce(sum((select -sum(m.value) from public.stock_moves m join public.journal_entries e on e.id = m.entry_id where e.device_id = d.id and e.source_type in ('part_use', 'reversal'))), 0))::bigint
  from public.devices d
  left join public.routes r on r.id = d.route_id
  left join public.device_costs dc on dc.device_id = d.id and dc.deleted_at is null
  where d.shop_id = public.current_shop_id() and d.status = 'delivered' and d.delivered_at >= p_from and d.delivered_at < p_to and (p_branch is null or d.branch_id = p_branch)
  group by r.id, r.code, r.name
  order by 7 desc;
end $$;
revoke execute on function public.issue_report(timestamptz, timestamptz, uuid) from public, anon;
grant execute on function public.issue_report(timestamptz, timestamptz, uuid) to authenticated;
-- models_report: (src: 0014_technicians.sql)
drop function if exists public.models_report(timestamptz, timestamptz);
create or replace function public.models_report(p_from timestamptz, p_to timestamptz, p_branch uuid default null)
returns table(kind text, label text, devices integer)
language plpgsql stable security definer set search_path = public as $$
#variable_conflict use_column
begin
  perform public.ledger_require(array['owner', 'reception']::public.app_role[]);
  return query
  (select 'model'::text, d.brand || ' ' || d.model, count(*)::int from public.devices d
    where d.shop_id = public.current_shop_id() and d.received_at >= p_from and d.received_at < p_to and d.deleted_at is null and (p_branch is null or d.branch_id = p_branch)
    group by d.brand, d.model order by 3 desc limit 10)
  union all
  (select 'route'::text, coalesce(r.code, r.name, '-'), count(*)::int from public.devices d left join public.routes r on r.id = d.route_id
    where d.shop_id = public.current_shop_id() and d.received_at >= p_from and d.received_at < p_to and d.deleted_at is null and (p_branch is null or d.branch_id = p_branch)
    group by r.code, r.name order by 3 desc limit 10);
end $$;
revoke execute on function public.models_report(timestamptz, timestamptz, uuid) from public, anon;
grant execute on function public.models_report(timestamptz, timestamptz, uuid) to authenticated;
-- inventory_summary: (src: 0027_inventory.sql)
drop function if exists public.inventory_summary(timestamptz, timestamptz);
create or replace function public.inventory_summary(p_from timestamptz, p_to timestamptz, p_branch uuid default null) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare s uuid := public.current_shop_id(); res jsonb;
begin
  perform public.ledger_require(array['owner']::public.app_role[]);
  with en as (
    select e.id, coalesce(o.source_type, e.source_type) t
    from public.journal_entries e left join public.journal_entries o on o.id = e.reverses_id
    where e.shop_id = s and e.occurred_at >= p_from and e.occurred_at < p_to and (p_branch is null or e.branch_id = p_branch)
  ), ln as (
    select en.t, a.code, sum(l.credit - l.debit) cr from en join public.journal_lines l on l.entry_id = en.id join public.accounts a on a.id = l.account_id
    group by en.t, a.code
  )
  select jsonb_build_object(
    'sales', coalesce((select sum(cr) from ln where t in ('sale', 'sale_return') and code in ('rev_parts', 'rev_accessories')), 0),
    'sales_cost', coalesce((select -sum(cr) from ln where t in ('sale', 'sale_return') and code = 'cogs'), 0),
    'wastage', coalesce((select -sum(cr) from ln where code = 'wastage'), 0),
    'return_diff', coalesce((select -sum(cr) from ln where t = 'supplier_return' and code = 'cogs'), 0),
    'cost_adjust', coalesce((select -sum(cr) from ln where t = 'cost_adjust' and code = 'cogs'), 0),
    'parts_used', coalesce((select -sum(cr) from ln where t = 'part_use' and code = 'cogs'), 0),
    'purchases', coalesce((select -sum(cr) from ln where t = 'purchase' and code = 'inventory'), 0),
    'stock_value', (select coalesce(sum(value), 0) from public.stock_moves where shop_id = s and (p_branch is null or branch_id = p_branch)),
    'stock_qty', (select coalesce(sum(qty), 0) from public.stock_moves where shop_id = s and (p_branch is null or branch_id = p_branch)),
    'top', coalesce((select jsonb_agg(x order by x.qty desc) from (
        select i.id, i.name, -sum(m.qty)::bigint qty, -sum(m.value)::bigint cost
        from public.stock_moves m join en on en.id = m.entry_id join public.items i on i.id = m.item_id
        where en.t = 'sale' group by i.id, i.name order by -sum(m.qty) desc limit 10) x), '[]'::jsonb)
  ) into res;
  res := res || jsonb_build_object('profit', (res->>'sales')::bigint - (res->>'sales_cost')::bigint - (res->>'wastage')::bigint - (res->>'return_diff')::bigint - (res->>'cost_adjust')::bigint);
  return res;
end $$;
revoke execute on function public.inventory_summary(timestamptz, timestamptz, uuid) from public, anon;
grant execute on function public.inventory_summary(timestamptz, timestamptz, uuid) to authenticated;
