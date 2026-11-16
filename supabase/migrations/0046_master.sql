-- 0046: C3: كلمة سر رئيسية للعمليات الحساسة (اختيارية، صاحب المحل بيحددها).
-- لو اتحددت: القيد العكسي وتعديل الفلوس (edit_entry بيعكس الأول)، والحذف (soft_delete)، والخصم الكبير عن التكلفة التقديرية
-- محتاجين الكلمة دي. اللي بيكتبها بياخد "فتح" لمدة 5 دقايق على حسابه هو بس.
-- الكلمة متخزّنة hash (bcrypt) ومحدش يقدر يقراها (ولا صاحب المحل)، و5 محاولات غلط في ربع ساعة بتقفل المحاولة.
-- ومش في النسخة الاحتياطية (المحل المسترجع بيحدد كلمته من جديد).

create table public.shop_secrets (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null unique references public.shops(id),
  master_hash text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);
create table public.master_unlocks (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references public.shops(id),
  user_id uuid not null references public.profiles(id),
  expires_at timestamptz not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);
create index master_unlocks_user on public.master_unlocks(user_id, expires_at);
create table public.master_attempts (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references public.shops(id),
  user_id uuid not null references public.profiles(id),
  success boolean not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);
create index master_attempts_user on public.master_attempts(user_id, created_at);
-- مفيش أي سياسة: الجداول دي بتتقري وتتكتب من الدوال بس
alter table public.shop_secrets enable row level security;
alter table public.master_unlocks enable row level security;
alter table public.master_attempts enable row level security;
create trigger set_updated_at before update on public.shop_secrets for each row execute function public.tg_set_updated_at();
create trigger set_updated_at before update on public.master_unlocks for each row execute function public.tg_set_updated_at();
create trigger set_updated_at before update on public.master_attempts for each row execute function public.tg_set_updated_at();
create trigger block_delete before delete on public.shop_secrets for each row execute function public.tg_block_delete();
create trigger block_delete before delete on public.master_unlocks for each row execute function public.tg_block_delete();
create trigger block_delete before delete on public.master_attempts for each row execute function public.tg_block_delete();

create or replace function public.has_master_password() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.shop_secrets x where x.shop_id = public.current_shop_id() and x.master_hash is not null and x.deleted_at is null)
$$;
revoke execute on function public.has_master_password() from public, anon;
grant execute on function public.has_master_password() to authenticated;

-- صاحب المحل بيحدد الكلمة أو يغيّرها أو يشيلها (p_new فاضي). لو فيه كلمة قديمة لازم تتكتب صح.
-- بترجّع 'set' أو 'removed' أو 'wrong' (الغلط ما بيرميش خطأ، عشان المحاولة الغلط تتسجل وما تتلغيش مع الخطأ)
create or replace function public.set_master_password(p_old text, p_new text) returns text
-- extensions: فيها crypt وgen_salt على Supabase
language plpgsql security definer set search_path = public, extensions, pg_temp as $$
declare s uuid := public.current_shop_id(); h text; n text := nullif(p_new, '');
begin
  perform public.ledger_require(array['owner']::public.app_role[]);
  if n is not null and (length(n) < 6 or length(n) > 72) then raise exception 'E_MASTER_SHORT'; end if;
  select master_hash into h from public.shop_secrets where shop_id = s and deleted_at is null;
  if h is not null then
    if public.master_locked() then raise exception 'E_MASTER_LOCKED'; end if;
    if p_old is null or crypt(p_old, h) <> h then
      insert into public.master_attempts(shop_id, user_id, success) values (s, auth.uid(), false);
      return 'wrong';
    end if;
  end if;
  insert into public.shop_secrets(shop_id, master_hash) values (s, case when n is null then null else crypt(n, gen_salt('bf', 8)) end)
  on conflict (shop_id) do update set master_hash = excluded.master_hash, deleted_at = null;
  -- أي "فتح" قديم بيتقفل
  update public.master_unlocks set deleted_at = now() where shop_id = s and deleted_at is null;
  insert into public.audit_log(shop_id, actor_id, action, entity, entity_id, after)
  values (s, auth.uid(), case when n is null then 'master_removed' else 'master_set' end, 'shop_secrets', s, '{}'::jsonb);
  return case when n is null then 'removed' else 'set' end;
end $$;
revoke execute on function public.set_master_password(text, text) from public, anon;
grant execute on function public.set_master_password(text, text) to authenticated;

-- 5 محاولات غلط في آخر ربع ساعة للمستخدم ده
create or replace function public.master_locked() returns boolean
language sql stable security definer set search_path = public as $$
  select (select count(*) from public.master_attempts a where a.user_id = auth.uid() and not a.success and a.created_at > now() - interval '15 minutes') >= 5
$$;
revoke execute on function public.master_locked() from public, anon, authenticated;

-- أي موظف في المحل بيكتب الكلمة (صاحب المحل بيكتبها على جهاز الموظف وقت العملية) ← فتح 5 دقايق لحسابه.
-- بترجّع {status: ok | wrong | none, until}. الغلط ما بيرميش خطأ، عشان المحاولة الغلط تتسجل
create or replace function public.verify_master(p_password text) returns jsonb
language plpgsql security definer set search_path = public, extensions, pg_temp as $$
declare s uuid := public.current_shop_id(); h text; e timestamptz := now() + interval '5 minutes';
begin
  if s is null or auth.uid() is null then raise exception 'E_FORBIDDEN'; end if;
  select master_hash into h from public.shop_secrets where shop_id = s and deleted_at is null;
  if h is null then return jsonb_build_object('status', 'none'); end if;
  if public.master_locked() then raise exception 'E_MASTER_LOCKED'; end if;
  if p_password is null or crypt(p_password, h) <> h then
    insert into public.master_attempts(shop_id, user_id, success) values (s, auth.uid(), false);
    return jsonb_build_object('status', 'wrong');
  end if;
  insert into public.master_attempts(shop_id, user_id, success) values (s, auth.uid(), true);
  insert into public.master_unlocks(shop_id, user_id, expires_at) values (s, auth.uid(), e);
  return jsonb_build_object('status', 'ok', 'until', e);
end $$;
revoke execute on function public.verify_master(text) from public, anon;
grant execute on function public.verify_master(text) to authenticated;

create or replace function public.master_unlocked() returns boolean
language sql stable security definer set search_path = public as $$
  select not public.has_master_password() or exists (
    select 1 from public.master_unlocks u where u.user_id = auth.uid() and u.shop_id = public.current_shop_id() and u.deleted_at is null and u.expires_at > now())
$$;
revoke execute on function public.master_unlocked() from public, anon;
grant execute on function public.master_unlocked() to authenticated;

create or replace function public.master_require() returns void
language plpgsql stable security definer set search_path = public as $$
begin
  if not public.master_unlocked() then raise exception 'E_MASTER_REQUIRED'; end if;
end $$;
revoke execute on function public.master_require() from public, anon, authenticated;

-- الخصم الكبير: لو فيه كلمة سر رئيسية، لازم تتكتب (حتى لصاحب المحل). من غيرها: زي الأول (صاحب المحل بس)
create or replace function public.tg_cost_discount() returns trigger
language plpgsql security definer set search_path = public as $$
declare pct integer; est integer; big boolean := false;
begin
  if auth.uid() is null or coalesce(current_setting('warsha.system', true), '') = 'on' then
    return new;
  end if;
  select max_discount_pct into pct from public.shops where id = new.shop_id;
  pct := coalesce(pct, 20);
  -- التكلفة التقديرية نفسها ما تنزلش بخصم كبير
  if tg_op = 'UPDATE' and old.estimated_cost > 0 and new.estimated_cost is distinct from old.estimated_cost
     and coalesce(new.estimated_cost, 0)::bigint * 100 < old.estimated_cost::bigint * (100 - pct) then
    big := true;
  end if;
  -- التكلفة النهائية مقارنة بالتقديرية (أعداد صحيحة بس، من غير كسور)
  est := case when tg_op = 'UPDATE' then coalesce(old.estimated_cost, new.estimated_cost) else new.estimated_cost end;
  if new.final_cost is not null and est > 0
     and (tg_op = 'INSERT' or new.final_cost is distinct from old.final_cost)
     and new.final_cost::bigint * 100 < est::bigint * (100 - pct) then
    big := true;
  end if;
  if not big then return new; end if;
  if public.has_master_password() then
    if not public.master_unlocked() then raise exception 'E_MASTER_REQUIRED'; end if;
    return new;
  end if;
  if public.current_app_role() = 'owner' then return new; end if;
  raise exception 'E_OWNER_APPROVAL';
end $$;

-- reverse_entry: (src: 0034) + كلمة السر الرئيسية
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
  -- C3: كلمة السر الرئيسية (لو صاحب المحل حددها)
  perform public.master_require();
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

-- soft_delete: (src: 0026) + كلمة السر الرئيسية
create or replace function public.soft_delete(p_kind text, p_id uuid, p_reason text default null) returns void
language plpgsql security definer set search_path = public as $$
declare s uuid := public.current_shop_id(); before jsonb; tbl text;
begin
  if public.current_app_role() is null or not public.can_correct() then raise exception 'E_FORBIDDEN'; end if;
  -- C3: كلمة السر الرئيسية (لو صاحب المحل حددها)
  perform public.master_require();
  if p_kind = 'customer' then
    tbl := 'customers';
    select to_jsonb(c) into before from public.customers c where id = p_id and shop_id = s and deleted_at is null for update;
    if before is null then raise exception 'E_NOT_FOUND'; end if;
    if exists (select 1 from public.journal_lines l where l.party_id = p_id and l.shop_id = s group by l.account_id having sum(l.debit - l.credit) <> 0) then raise exception 'E_HAS_BALANCE'; end if;
    if exists (select 1 from public.devices d where d.customer_id = p_id and d.deleted_at is null and d.status not in ('delivered', 'unrepairable')) then raise exception 'E_HAS_OPEN_DEVICES'; end if;
  elsif p_kind = 'supplier' then
    tbl := 'suppliers';
    select to_jsonb(x) into before from public.suppliers x where id = p_id and shop_id = s and deleted_at is null for update;
    if before is null then raise exception 'E_NOT_FOUND'; end if;
    if exists (select 1 from public.journal_lines l where l.party_id = p_id and l.shop_id = s group by l.account_id having sum(l.debit - l.credit) <> 0) then raise exception 'E_HAS_BALANCE'; end if;
  elsif p_kind = 'item' then
    tbl := 'items';
    select to_jsonb(x) into before from public.items x where id = p_id and shop_id = s and deleted_at is null for update;
    if before is null then raise exception 'E_NOT_FOUND'; end if;
    if (select coalesce(sum(qty), 0) <> 0 or coalesce(sum(value), 0) <> 0 from public.stock_moves where item_id = p_id) then raise exception 'E_HAS_STOCK'; end if;
  elsif p_kind = 'device' then
    tbl := 'devices';
    select to_jsonb(x) into before from public.devices x where id = p_id and shop_id = s and deleted_at is null for update;
    if before is null then raise exception 'E_NOT_FOUND'; end if;
    if exists (select 1 from public.journal_entries e where e.device_id = p_id and not exists (select 1 from public.journal_entries r where r.reverses_id = e.id) and e.source_type not in ('reversal', 'cost_adjust')) then
      raise exception 'E_HAS_MONEY';
    end if;
  else
    raise exception 'E_BAD_INPUT';
  end if;
  perform set_config('warsha.system', 'on', true);
  execute format('update public.%I set deleted_at = now(), updated_at = now() where id = $1', tbl) using p_id;
  perform set_config('warsha.system', 'off', true);
  insert into public.audit_log(shop_id, actor_id, action, entity, entity_id, before, after)
  values (s, auth.uid(), 'soft_delete', tbl, p_id, before, jsonb_build_object('reason', nullif(trim(p_reason), '')));
end $$;
