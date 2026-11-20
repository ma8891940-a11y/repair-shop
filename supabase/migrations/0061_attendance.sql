-- 0061: R1 الحضور والانصراف (من دراسة المنافسين v2)
--
-- - كل موظف (وصاحب المحل) بيسجّل حضوره وانصرافه بنفسه، في فرعه الشغال (op_branch).
-- - صاحب المحل بس بيصلّح سجل (وقت حضور أو انصراف غلط أو منسي)، أو يضيف سجل، أو يلغيه. لازم سبب، وكله في سجل النشاط.
-- - القراية: كل واحد يشوف سجله هو. وصاحب المحل، واللي معاه "الفريق ← يشوف"، يشوفوا الكل في فروعهم.
-- - التأخير بيتحسب في التقرير بس، من ميعاد بداية الشغل والسماح في إعدادات المحل (extras.attendance.start وgrace_min).
-- - مفيش أي فلوس هنا. الجزاءات والمكافآت ليها شاشتها ودوالها في المرتبات (staff_bonus/staff_penalty).

create table public.attendance (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references public.shops(id),
  branch_id uuid references public.branches(id),
  profile_id uuid not null references public.profiles(id),
  clock_in timestamptz not null,
  clock_out timestamptz,
  note text check (length(note) <= 300),
  fixed_by uuid references public.profiles(id),
  fix_reason text check (length(fix_reason) <= 300),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  check (clock_out is null or clock_out > clock_in),
  check (clock_out is null or clock_out - clock_in <= interval '24 hours')
);
-- سجل مفتوح واحد بس لكل موظف
create unique index attendance_open on public.attendance(profile_id) where clock_out is null and deleted_at is null;
create index attendance_shop_in on public.attendance(shop_id, clock_in);
alter table public.attendance enable row level security;
create trigger set_updated_at before update on public.attendance for each row execute function public.tg_set_updated_at();
create trigger block_delete before delete on public.attendance for each row execute function public.tg_block_delete();
create trigger zz_audit after insert or update on public.attendance for each row execute function public.tg_audit();
create policy attendance_select on public.attendance for select to authenticated
  using (shop_id = public.current_shop_id() and deleted_at is null
         and (profile_id = auth.uid() or public.current_app_role() = 'owner' or ((select public.has_perm('staff', 'view')) and public.can_branch(branch_id))));
revoke all on public.attendance from public, anon, authenticated;
grant select on public.attendance to authenticated;

-- ---------- الموظف نفسه ----------
create or replace function public.clock_in(p_id uuid, p_note text default null) returns uuid
language plpgsql security definer set search_path = public as $$
declare s uuid := public.current_shop_id(); me uuid := auth.uid();
begin
  if s is null or me is null then raise exception 'E_FORBIDDEN'; end if;
  -- نفس الطلب مرتين (النت قطع ورجع): نفس السجل
  if exists (select 1 from public.attendance where id = p_id and profile_id = me) then return p_id; end if;
  if exists (select 1 from public.attendance where profile_id = me and clock_out is null and deleted_at is null) then raise exception 'E_ALREADY_IN'; end if;
  insert into public.attendance(id, shop_id, branch_id, profile_id, clock_in, note)
  values (p_id, s, public.op_branch(), me, now(), nullif(trim(left(p_note, 300)), ''));
  return p_id;
end $$;
revoke execute on function public.clock_in(uuid, text) from public, anon;
grant execute on function public.clock_in(uuid, text) to authenticated;

create or replace function public.clock_out(p_note text default null) returns uuid
language plpgsql security definer set search_path = public as $$
declare me uuid := auth.uid(); a public.attendance;
begin
  if public.current_shop_id() is null or me is null then raise exception 'E_FORBIDDEN'; end if;
  select * into a from public.attendance where profile_id = me and clock_out is null and deleted_at is null for update;
  if a.id is null then raise exception 'E_NOT_IN'; end if;
  -- أكتر من 24 ساعة: نسي ينصرف، وصاحب المحل يصلّح السجل
  if now() - a.clock_in > interval '24 hours' then raise exception 'E_OPEN_TOO_LONG'; end if;
  update public.attendance set clock_out = now(), note = coalesce(nullif(trim(left(p_note, 300)), ''), note) where id = a.id;
  return a.id;
end $$;
revoke execute on function public.clock_out(text) from public, anon;
grant execute on function public.clock_out(text) to authenticated;

-- ---------- التقرير ----------
-- الدقايق والتأخير بيتحسبوا هنا (أعداد صحيحة)، والواجهة بتعرضهم بس
create or replace function public.attendance_rows(p_from timestamptz, p_to timestamptz, p_branch uuid default null, p_me boolean default false)
returns table(id uuid, profile_id uuid, full_name text, branch_id uuid, clock_in timestamptz, clock_out timestamptz, minutes integer, late_minutes integer, note text, fix_reason text)
language plpgsql stable security definer set search_path = public as $$
#variable_conflict use_column
declare s uuid := public.current_shop_id(); r public.app_role := public.current_app_role(); me uuid := auth.uid();
  st text; grace integer; all_staff boolean;
begin
  if s is null or me is null then raise exception 'E_FORBIDDEN'; end if;
  if p_from is null or p_to is null or p_to <= p_from or p_to - p_from > interval '400 days' then raise exception 'E_BAD_INPUT'; end if;
  all_staff := not p_me and (r = 'owner' or public.has_perm('staff', 'view'));
  if not p_me and not all_staff then raise exception 'E_FORBIDDEN'; end if;
  select sh.extras -> 'attendance' ->> 'start', coalesce((sh.extras -> 'attendance' ->> 'grace_min')::int, 15)
    into st, grace from public.shops sh where sh.id = s;
  if st !~ '^([01][0-9]|2[0-3]):[0-5][0-9]$' then st := null; end if;
  return query
  select a.id, a.profile_id, p.full_name, a.branch_id, a.clock_in, a.clock_out,
         case when a.clock_out is null then null else (extract(epoch from a.clock_out - a.clock_in) / 60)::int end,
         case when st is null then 0
              else greatest(0, (extract(epoch from (a.clock_in at time zone 'Africa/Cairo') - ((a.clock_in at time zone 'Africa/Cairo')::date + st::time)) / 60)::int - grace) end,
         a.note, a.fix_reason
  from public.attendance a join public.profiles p on p.id = a.profile_id
  where a.shop_id = s and a.deleted_at is null and a.clock_in >= p_from and a.clock_in < p_to
    and (case when p_me then a.profile_id = me
              else (r = 'owner' or public.can_branch(a.branch_id)) and (p_branch is null or a.branch_id = p_branch) end)
  order by a.clock_in desc;
end $$;
revoke execute on function public.attendance_rows(timestamptz, timestamptz, uuid, boolean) from public, anon;
grant execute on function public.attendance_rows(timestamptz, timestamptz, uuid, boolean) to authenticated;

create or replace function public.my_attendance(p_from timestamptz, p_to timestamptz)
returns table(id uuid, profile_id uuid, full_name text, branch_id uuid, clock_in timestamptz, clock_out timestamptz, minutes integer, late_minutes integer, note text, fix_reason text)
language sql stable security definer set search_path = public as $$
  select * from public.attendance_rows(p_from, p_to, null, true)
$$;
revoke execute on function public.my_attendance(timestamptz, timestamptz) from public, anon;
grant execute on function public.my_attendance(timestamptz, timestamptz) to authenticated;

create or replace function public.attendance_report(p_from timestamptz, p_to timestamptz, p_branch uuid default null)
returns table(id uuid, profile_id uuid, full_name text, branch_id uuid, clock_in timestamptz, clock_out timestamptz, minutes integer, late_minutes integer, note text, fix_reason text)
language sql stable security definer set search_path = public as $$
  select * from public.attendance_rows(p_from, p_to, p_branch, false)
$$;
revoke execute on function public.attendance_report(timestamptz, timestamptz, uuid) from public, anon;
grant execute on function public.attendance_report(timestamptz, timestamptz, uuid) to authenticated;

-- ---------- صاحب المحل بس: تصليح، أو إضافة، أو إلغاء (بسبب، وفي سجل النشاط) ----------
create or replace function public.attendance_fix(p_id uuid, p_in timestamptz, p_out timestamptz, p_reason text) returns void
language plpgsql security definer set search_path = public as $$
declare s uuid := public.current_shop_id();
begin
  perform public.ledger_require(array['owner']::public.app_role[]);
  if coalesce(trim(p_reason), '') = '' then raise exception 'E_REASON_REQUIRED'; end if;
  if p_in is null or (p_out is not null and (p_out <= p_in or p_out - p_in > interval '24 hours')) then raise exception 'E_BAD_INPUT'; end if;
  update public.attendance set clock_in = p_in, clock_out = p_out, fixed_by = auth.uid(), fix_reason = left(trim(p_reason), 300)
   where id = p_id and shop_id = s and deleted_at is null;
  if not found then raise exception 'E_NOT_FOUND'; end if;
end $$;
revoke execute on function public.attendance_fix(uuid, timestamptz, timestamptz, text) from public, anon;
grant execute on function public.attendance_fix(uuid, timestamptz, timestamptz, text) to authenticated;

create or replace function public.attendance_add(p_id uuid, p_profile uuid, p_in timestamptz, p_out timestamptz, p_reason text) returns uuid
language plpgsql security definer set search_path = public as $$
declare s uuid := public.current_shop_id(); b uuid;
begin
  perform public.ledger_require(array['owner']::public.app_role[]);
  if exists (select 1 from public.attendance where id = p_id and shop_id = s) then return p_id; end if;
  if coalesce(trim(p_reason), '') = '' then raise exception 'E_REASON_REQUIRED'; end if;
  if p_in is null or p_out is null or p_out <= p_in or p_out - p_in > interval '24 hours' then raise exception 'E_BAD_INPUT'; end if;
  if not exists (select 1 from public.profiles where id = p_profile and shop_id = s) then raise exception 'E_NOT_FOUND'; end if;
  -- فرع الموظف (أول فرع ليه، أو الرئيسي)
  b := coalesce((select sb.branch_id from public.staff_branches sb where sb.profile_id = p_profile and sb.deleted_at is null order by sb.created_at limit 1), public.main_branch(s));
  insert into public.attendance(id, shop_id, branch_id, profile_id, clock_in, clock_out, fixed_by, fix_reason)
  values (p_id, s, b, p_profile, p_in, p_out, auth.uid(), left(trim(p_reason), 300));
  return p_id;
end $$;
revoke execute on function public.attendance_add(uuid, uuid, timestamptz, timestamptz, text) from public, anon;
grant execute on function public.attendance_add(uuid, uuid, timestamptz, timestamptz, text) to authenticated;

create or replace function public.attendance_void(p_id uuid, p_reason text) returns void
language plpgsql security definer set search_path = public as $$
begin
  perform public.ledger_require(array['owner']::public.app_role[]);
  if coalesce(trim(p_reason), '') = '' then raise exception 'E_REASON_REQUIRED'; end if;
  update public.attendance set deleted_at = now(), fixed_by = auth.uid(), fix_reason = left(trim(p_reason), 300)
   where id = p_id and shop_id = public.current_shop_id() and deleted_at is null;
  if not found then raise exception 'E_NOT_FOUND'; end if;
end $$;
revoke execute on function public.attendance_void(uuid, text) from public, anon;
grant execute on function public.attendance_void(uuid, text) to authenticated;


-- ---------- النسخة الاحتياطية والاسترجاع ----------
-- backup_snapshot: (src: 0060_sale_lines.sql) + attendance
create or replace function public.backup_snapshot(p_shop uuid) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare
  res jsonb := jsonb_build_object('format', 'warsha-backup', 'version', 1, 'generated_at', now(), 'shop_id', p_shop);
  t text;
  rows jsonb;
begin
  foreach t in array array['shops', 'branches', 'staff_branches', 'attendance', 'shop_branding', 'profiles', 'customers', 'devices', 'device_costs', 'status_log', 'device_notes', 'device_photos', 'device_checks',
                           'quote_decisions', 'message_templates', 'message_log', 'accounts', 'journal_entries', 'journal_lines', 'sale_lines', 'payments', 'drawer_closings',
                           'suppliers', 'categories', 'items', 'stock_moves', 'uncosted_sales', 'payment_plans', 'plan_installments', 'branch_goals', 'printers', 'print_templates', 'check_templates', 'used_devices', 'commission_rules', 'purchases', 'labor_rates', 'specialties', 'staff_specialties', 'routes', 'repair_steps',
                           'repair_videos', 'device_ratings', 'issue_presets', 'partners', 'profit_distributions', 'party_links', 'shop_lists', 'audit_log'] loop
    execute format('select coalesce(jsonb_agg(to_jsonb(x)), ''[]''::jsonb) from public.%I x where x.shop_id = $1', t) into rows using p_shop;
    res := res || jsonb_build_object(t, rows);
  end loop;
  select coalesce(jsonb_agg(jsonb_build_object('device_id', device_id, 'kind', kind, 'erased_at', erased_at)), '[]'::jsonb)
    into rows from public.device_passcodes where shop_id = p_shop;
  return res || jsonb_build_object('device_passcodes', rows);
end $$;

-- restore_backup: (src: 0060_sale_lines.sql) + attendance (بعد الموظفين والفروع)
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
  tabs text[] := array['branches', 'profiles', 'staff_branches', 'attendance', 'shop_branding', 'accounts', 'customers', 'suppliers', 'party_links', 'partners', 'specialties', 'staff_specialties', 'routes', 'labor_rates',
                       'issue_presets', 'commission_rules', 'shop_lists', 'message_templates', 'categories', 'items', 'devices', 'device_costs', 'status_log', 'device_notes', 'device_checks',
                       'quote_decisions', 'repair_steps', 'repair_videos', 'device_ratings', 'journal_entries', 'journal_lines', 'sale_lines', 'profit_distributions', 'payments',
                       'purchases', 'stock_moves', 'uncosted_sales', 'used_devices', 'payment_plans', 'plan_installments', 'branch_goals', 'printers', 'print_templates', 'check_templates', 'drawer_closings', 'message_log', 'audit_log'];
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
      elsif t = 'used_devices' then
        -- رقم بطاقة البائع (في Vault) وصورتها (في Storage) مش جوه النسخة
        r := r || jsonb_build_object('seller_nid_secret', null, 'seller_photo', null);
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
