-- جوالك / Gawalak: ترقية مشروع Supabase لآخر نسخة، الجزء 5 من 5 (الملفات 0060_sale_lines.sql لـ 0061_attendance.sql).
-- بيتولد تلقائيًا: npm run db:setup-file. ما تعدّلوش بإيدك.
-- شغّل الأجزاء بالترتيب في SQL Editor (كل جزء لوحده: New query ← الصق ← Run): upgrade_part_1.sql ثم upgrade_part_2.sql ثم upgrade_part_3.sql ثم upgrade_part_4.sql ثم upgrade_part_5.sql.
-- آمن تشغّل أي جزء أكتر من مرة: اللي اتطبق قبل كده بيتخطى. ولو ملف فشل، اللي قبله بيفضل، وصلّح السبب وشغّل نفس الجزء تاني.
-- لو لقى ملف أحدث موجود وأقدم منه ناقص بيقف (E_UPGRADE_GAP). ولو جزء قبله لسه ما اتطبقش بيقف (E_UPGRADE_ORDER). الاتنين من غير تغيير.
-- ملفات الجزء ده: 0060_sale_lines.sql, 0061_attendance.sql

-- سجل الترقية (للنظام بس، من غير أي بيانات محلات)
create table if not exists public.app_migrations (version text primary key, applied_at timestamptz not null default now(), how text not null);
alter table public.app_migrations enable row level security;
revoke all on public.app_migrations from anon, authenticated;

-- 1) الملفات اللي موجودة فعلًا (من البصمة) بتتسجل، وأي فجوة بتوقف كل حاجة
do $chk$
declare
  first_missing text;
  later_present text;
begin
  if not exists (select 1 from public.app_migrations where version = '0001_phase1.sql') and (to_regclass('public.shops') is not null) then
    insert into public.app_migrations(version, how) values ('0001_phase1.sql', 'found: table shops');
  end if;
  if not exists (select 1 from public.app_migrations where version = '0002_storage.sql') and (exists (select 1 from pg_policies where policyname = 'device_photos_read')) then
    insert into public.app_migrations(version, how) values ('0002_storage.sql', 'found: policy device_photos_read');
  end if;
  if not exists (select 1 from public.app_migrations where version = '0003_shop_profile_realtime.sql') and (exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'shops' and column_name = 'country')) then
    insert into public.app_migrations(version, how) values ('0003_shop_profile_realtime.sql', 'found: column shops.country');
  end if;
  if not exists (select 1 from public.app_migrations where version = '0004_error_codes.sql') and (exists (select 1 from pg_proc p where p.pronamespace = 'public'::regnamespace and p.proname = 'tg_block_delete' and position('raise exception ''E_HARD_DELETE'';' in p.prosrc) > 0)) then
    insert into public.app_migrations(version, how) values ('0004_error_codes.sql', 'found: function tg_block_delete');
  end if;
  if not exists (select 1 from public.app_migrations where version = '0005_device_passcode.sql') and (to_regclass('public.device_passcodes') is not null) then
    insert into public.app_migrations(version, how) values ('0005_device_passcode.sql', 'found: table device_passcodes');
  end if;
  if not exists (select 1 from public.app_migrations where version = '0006_invite_name.sql') and (exists (select 1 from pg_proc p where p.pronamespace = 'public'::regnamespace and p.proname = 'my_pending_invite' and position('select s.name, i.role, i.full_name' in p.prosrc) > 0)) then
    insert into public.app_migrations(version, how) values ('0006_invite_name.sql', 'found: function my_pending_invite');
  end if;
  if not exists (select 1 from public.app_migrations where version = '0007_phase2_customer.sql') and (to_regclass('public.tracking_attempts') is not null) then
    insert into public.app_migrations(version, how) values ('0007_phase2_customer.sql', 'found: table tracking_attempts');
  end if;
  if not exists (select 1 from public.app_migrations where version = '0008_ledger.sql') and (to_regclass('public.accounts') is not null) then
    insert into public.app_migrations(version, how) values ('0008_ledger.sql', 'found: table accounts');
  end if;
  if not exists (select 1 from public.app_migrations where version = '0009_tracking_guess_limit.sql') and (exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'tracking_attempts' and column_name = 'guess')) then
    insert into public.app_migrations(version, how) values ('0009_tracking_guess_limit.sql', 'found: column tracking_attempts.guess');
  end if;
  if not exists (select 1 from public.app_migrations where version = '0010_default_cashboxes.sql') and (exists (select 1 from pg_proc p where p.pronamespace = 'public'::regnamespace and p.proname = 'ensure_ledger_accounts' and position('select unnest(array[''cash'', ''wallet'', ''instapay'', ''bank_transfer'', ''card''])' in p.prosrc) > 0)) then
    insert into public.app_migrations(version, how) values ('0010_default_cashboxes.sql', 'found: function ensure_ledger_accounts');
  end if;
  if not exists (select 1 from public.app_migrations where version = '0011_finance_drilldown.sql') and (exists (select 1 from pg_proc p where p.pronamespace = 'public'::regnamespace and p.proname = 'cashbox_daily' and position('select l.account_id, (date_trunc(''day'', e.occurred_at at time zone ''Africa/Cairo''))::date, sum(l.debit - l.credit)::bigint' in p.prosrc) > 0)) then
    insert into public.app_migrations(version, how) values ('0011_finance_drilldown.sql', 'found: function cashbox_daily');
  end if;
  if not exists (select 1 from public.app_migrations where version = '0012_spec_completion.sql') and (to_regclass('public.purchases') is not null) then
    insert into public.app_migrations(version, how) values ('0012_spec_completion.sql', 'found: table purchases');
  end if;
  if not exists (select 1 from public.app_migrations where version = '0013_tracking_ambiguous.sql') and (exists (select 1 from pg_proc p where p.pronamespace = 'public'::regnamespace and p.proname = 'tracking_find' and position('declare d public.devices; n int;' in p.prosrc) > 0)) then
    insert into public.app_migrations(version, how) values ('0013_tracking_ambiguous.sql', 'found: function tracking_find');
  end if;
  if not exists (select 1 from public.app_migrations where version = '0014_technicians.sql') and (to_regclass('public.specialties') is not null) then
    insert into public.app_migrations(version, how) values ('0014_technicians.sql', 'found: table specialties');
  end if;
  if not exists (select 1 from public.app_migrations where version = '0015_offline_backup.sql') and (to_regclass('public.shop_backups') is not null) then
    insert into public.app_migrations(version, how) values ('0015_offline_backup.sql', 'found: table shop_backups');
  end if;
  if not exists (select 1 from public.app_migrations where version = '0016_shop_identity.sql') and (to_regclass('public.shop_branding') is not null) then
    insert into public.app_migrations(version, how) values ('0016_shop_identity.sql', 'found: table shop_branding');
  end if;
  if not exists (select 1 from public.app_migrations where version = '0017_growth.sql') and (to_regclass('public.plans') is not null) then
    insert into public.app_migrations(version, how) values ('0017_growth.sql', 'found: table plans');
  end if;
  if not exists (select 1 from public.app_migrations where version = '0018_account_state.sql') and (exists (select 1 from pg_proc p where p.pronamespace = 'public'::regnamespace and p.proname = 'my_account' and position('''profile'', (select jsonb_build_object(''id'', p.id, ''shop_id'', p.shop_id, ''full_name'', p.full_name, ''email'', p.email, ''role'', p.role::text, ''deleted_at'', p.deleted_at)' in p.prosrc) > 0)) then
    insert into public.app_migrations(version, how) values ('0018_account_state.sql', 'found: function my_account');
  end if;
  if not exists (select 1 from public.app_migrations where version = '0019_extras.sql') and (to_regclass('public.issue_presets') is not null) then
    insert into public.app_migrations(version, how) values ('0019_extras.sql', 'found: table issue_presets');
  end if;
  if not exists (select 1 from public.app_migrations where version = '0020_admin_paging.sql') and (exists (select 1 from pg_proc p where p.pronamespace = 'public'::regnamespace and p.proname = 'admin_shops' and position('declare q text := nullif(trim(coalesce(p_search, '''')), '''');' in p.prosrc) > 0)) then
    insert into public.app_migrations(version, how) values ('0020_admin_paging.sql', 'found: function admin_shops');
  end if;
  if not exists (select 1 from public.app_migrations where version = '0021_spec_rules.sql') and (exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'routes' and column_name = 'warranty_days')) then
    insert into public.app_migrations(version, how) values ('0021_spec_rules.sql', 'found: column routes.warranty_days');
  end if;
  if not exists (select 1 from public.app_migrations where version = '0023_restore.sql') and (exists (select 1 from pg_proc p where p.pronamespace = 'public'::regnamespace and p.proname = 'restoring' and position('select coalesce(current_setting(''warsha.restore'', true), '''') = ''on''' in p.prosrc) > 0)) then
    insert into public.app_migrations(version, how) values ('0023_restore.sql', 'found: function restoring');
  end if;
  if not exists (select 1 from public.app_migrations where version = '0024_signout.sql') and (exists (select 1 from pg_proc p where p.pronamespace = 'public'::regnamespace and p.proname = 'end_my_session' and position('sid := nullif(auth.jwt() ->> ''session_id'', '''')::uuid;' in p.prosrc) > 0)) then
    insert into public.app_migrations(version, how) values ('0024_signout.sql', 'found: function end_my_session');
  end if;
  if not exists (select 1 from public.app_migrations where version = '0025_integrity.sql') and (exists (select 1 from pg_proc p where p.pronamespace = 'public'::regnamespace and p.proname = 'integrity_report' and position('declare s uuid := public.current_shop_id(); out jsonb := ''[]''::jsonb; r record; inv bigint; mv bigint;' in p.prosrc) > 0)) then
    insert into public.app_migrations(version, how) values ('0025_integrity.sql', 'found: function integrity_report');
  end if;
  if not exists (select 1 from public.app_migrations where version = '0026_edit_delete.sql') and (exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'profiles' and column_name = 'can_correct')) then
    insert into public.app_migrations(version, how) values ('0026_edit_delete.sql', 'found: column profiles.can_correct');
  end if;
  if not exists (select 1 from public.app_migrations where version = '0027_inventory.sql') and (exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'items' and column_name = 'category')) then
    insert into public.app_migrations(version, how) values ('0027_inventory.sql', 'found: column items.category');
  end if;
  if not exists (select 1 from public.app_migrations where version = '0028_opening.sql') and (exists (select 1 from pg_proc p where p.pronamespace = 'public'::regnamespace and p.proname = 'opening_balance' and position('cap uuid := public.ledger_acc(''capital'');' in p.prosrc) > 0)) then
    insert into public.app_migrations(version, how) values ('0028_opening.sql', 'found: function opening_balance');
  end if;
  if not exists (select 1 from public.app_migrations where version = '0029_partners.sql') and (to_regclass('public.partners') is not null) then
    insert into public.app_migrations(version, how) values ('0029_partners.sql', 'found: table partners');
  end if;
  if not exists (select 1 from public.app_migrations where version = '0030_party_links.sql') and (to_regclass('public.party_links') is not null) then
    insert into public.app_migrations(version, how) values ('0030_party_links.sql', 'found: table party_links');
  end if;
  if not exists (select 1 from public.app_migrations where version = '0031_partner_capital.sql') and (exists (select 1 from pg_proc p where p.pronamespace = 'public'::regnamespace and p.proname = 'ensure_partner_accounts' and position('(p_shop, ''retained'', ''equity'', ''retained''),' in p.prosrc) > 0)) then
    insert into public.app_migrations(version, how) values ('0031_partner_capital.sql', 'found: function ensure_partner_accounts');
  end if;
  if not exists (select 1 from public.app_migrations where version = '0032_lists.sql') and (to_regclass('public.shop_lists') is not null) then
    insert into public.app_migrations(version, how) values ('0032_lists.sql', 'found: table shop_lists');
  end if;
  if not exists (select 1 from public.app_migrations where version = '0033_assistant.sql') and (exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'ai_usage' and column_name = 'area')) then
    insert into public.app_migrations(version, how) values ('0033_assistant.sql', 'found: column ai_usage.area');
  end if;
  if not exists (select 1 from public.app_migrations where version = '0034_branches.sql') and (to_regclass('public.branches') is not null) then
    insert into public.app_migrations(version, how) values ('0034_branches.sql', 'found: table branches');
  end if;
  if not exists (select 1 from public.app_migrations where version = '0035_lists_everywhere.sql') and (exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'devices' and column_name = 'device_type')) then
    insert into public.app_migrations(version, how) values ('0035_lists_everywhere.sql', 'found: column devices.device_type');
  end if;
  if not exists (select 1 from public.app_migrations where version = '0036_roles.sql') and (to_regclass('public.roles') is not null) then
    insert into public.app_migrations(version, how) values ('0036_roles.sql', 'found: table roles');
  end if;
  if not exists (select 1 from public.app_migrations where version = '0037_item_details.sql') and (to_regclass('public.uncosted_sales') is not null) then
    insert into public.app_migrations(version, how) values ('0037_item_details.sql', 'found: table uncosted_sales');
  end if;
  if not exists (select 1 from public.app_migrations where version = '0038_roles_grant.sql') and (exists (select 1 from pg_policies where policyname = 'staff_entries_select')) then
    insert into public.app_migrations(version, how) values ('0038_roles_grant.sql', 'found: policy staff_entries_select');
  end if;
  if not exists (select 1 from public.app_migrations where version = '0039_payment_plans.sql') and (to_regclass('public.payment_plans') is not null) then
    insert into public.app_migrations(version, how) values ('0039_payment_plans.sql', 'found: table payment_plans');
  end if;
  if not exists (select 1 from public.app_migrations where version = '0040_branch_books.sql') and (exists (select 1 from pg_proc p where p.pronamespace = 'public'::regnamespace and p.proname = 'branch_lines_raw' and position('declare s uuid := public.current_shop_id(); inv uuid;' in p.prosrc) > 0)) then
    insert into public.app_migrations(version, how) values ('0040_branch_books.sql', 'found: function branch_lines_raw');
  end if;
  if not exists (select 1 from public.app_migrations where version = '0041_analytics.sql') and (to_regclass('public.branch_goals') is not null) then
    insert into public.app_migrations(version, how) values ('0041_analytics.sql', 'found: table branch_goals');
  end if;
  if not exists (select 1 from public.app_migrations where version = '0042_app_brand.sql') and (exists (select 1 from pg_proc p where p.pronamespace = 'public'::regnamespace and p.proname = 'public_app_brand' and position('''name'', left(nullif(trim(s.extras -> ''app'' ->> ''name''), ''''), 40),' in p.prosrc) > 0)) then
    insert into public.app_migrations(version, how) values ('0042_app_brand.sql', 'found: function public_app_brand');
  end if;
  if not exists (select 1 from public.app_migrations where version = '0043_printing.sql') and (to_regclass('public.printers') is not null) then
    insert into public.app_migrations(version, how) values ('0043_printing.sql', 'found: table printers');
  end if;
  if not exists (select 1 from public.app_migrations where version = '0044_capture.sql') and (to_regclass('public.photo_upload_sessions') is not null) then
    insert into public.app_migrations(version, how) values ('0044_capture.sql', 'found: table photo_upload_sessions');
  end if;
  if not exists (select 1 from public.app_migrations where version = '0045_checklists.sql') and (to_regclass('public.check_templates') is not null) then
    insert into public.app_migrations(version, how) values ('0045_checklists.sql', 'found: table check_templates');
  end if;
  if not exists (select 1 from public.app_migrations where version = '0046_master.sql') and (to_regclass('public.shop_secrets') is not null) then
    insert into public.app_migrations(version, how) values ('0046_master.sql', 'found: table shop_secrets');
  end if;
  if not exists (select 1 from public.app_migrations where version = '0047_mfa.sql') and (exists (select 1 from pg_proc p where p.pronamespace = 'public'::regnamespace and p.proname = 'mfa_ok' and position('select coalesce(auth.jwt() ->> ''aal'', ''aal1'') = ''aal2''' in p.prosrc) > 0)) then
    insert into public.app_migrations(version, how) values ('0047_mfa.sql', 'found: function mfa_ok');
  end if;
  if not exists (select 1 from public.app_migrations where version = '0048_used.sql') and (to_regclass('public.used_devices') is not null) then
    insert into public.app_migrations(version, how) values ('0048_used.sql', 'found: table used_devices');
  end if;
  if not exists (select 1 from public.app_migrations where version = '0049_commissions.sql') and (to_regclass('public.commission_rules') is not null) then
    insert into public.app_migrations(version, how) values ('0049_commissions.sql', 'found: table commission_rules');
  end if;
  if not exists (select 1 from public.app_migrations where version = '0050_insights.sql') and (exists (select 1 from pg_proc p where p.pronamespace = 'public'::regnamespace and p.proname = 'faults_by_model' and position('select d.brand, d.model, r.code, r.name,' in p.prosrc) > 0)) then
    insert into public.app_migrations(version, how) values ('0050_insights.sql', 'found: function faults_by_model');
  end if;
  if not exists (select 1 from public.app_migrations where version = '0051_demo.sql') and (to_regclass('public.demo_rows') is not null) then
    insert into public.app_migrations(version, how) values ('0051_demo.sql', 'found: table demo_rows');
  end if;
  if not exists (select 1 from public.app_migrations where version = '0052_catalog.sql') and (exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'shops' and column_name = 'catalog_token')) then
    insert into public.app_migrations(version, how) values ('0052_catalog.sql', 'found: column shops.catalog_token');
  end if;
  if not exists (select 1 from public.app_migrations where version = '0053_portal.sql') and (to_regclass('public.wholesale_orders') is not null) then
    insert into public.app_migrations(version, how) values ('0053_portal.sql', 'found: table wholesale_orders');
  end if;
  if not exists (select 1 from public.app_migrations where version = '0054_telegram.sql') and (to_regclass('public.shop_telegram') is not null) then
    insert into public.app_migrations(version, how) values ('0054_telegram.sql', 'found: table shop_telegram');
  end if;
  if not exists (select 1 from public.app_migrations where version = '0055_eta_placeholder.sql') and (to_regclass('public.eta_settings') is not null) then
    insert into public.app_migrations(version, how) values ('0055_eta_placeholder.sql', 'found: table eta_settings');
  end if;
  if not exists (select 1 from public.app_migrations where version = '0056_branch_features.sql') and (exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'commission_rules' and column_name = 'branch_id')) then
    insert into public.app_migrations(version, how) values ('0056_branch_features.sql', 'found: column commission_rules.branch_id');
  end if;
  if not exists (select 1 from public.app_migrations where version = '0057_categories.sql') and (to_regclass('public.categories') is not null) then
    insert into public.app_migrations(version, how) values ('0057_categories.sql', 'found: table categories');
  end if;
  if not exists (select 1 from public.app_migrations where version = '0058_web_push.sql') and (to_regclass('public.push_subscriptions') is not null) then
    insert into public.app_migrations(version, how) values ('0058_web_push.sql', 'found: table push_subscriptions');
  end if;
  if not exists (select 1 from public.app_migrations where version = '0059_counters_branch.sql') and (exists (select 1 from pg_policies where policyname = 'counters_select_branch')) then
    insert into public.app_migrations(version, how) values ('0059_counters_branch.sql', 'found: policy counters_select_branch');
  end if;
  if not exists (select 1 from public.app_migrations where version = '0060_sale_lines.sql') and (to_regclass('public.sale_lines') is not null) then
    insert into public.app_migrations(version, how) values ('0060_sale_lines.sql', 'found: table sale_lines');
  end if;
  if not exists (select 1 from public.app_migrations where version = '0061_attendance.sql') and (to_regclass('public.attendance') is not null) then
    insert into public.app_migrations(version, how) values ('0061_attendance.sql', 'found: table attendance');
  end if;
  insert into public.app_migrations(version, how) select v, 'inferred' from unnest(array['0022_security_review.sql']::text[]) v
    where v < (select max(version) from public.app_migrations) on conflict (version) do nothing;
  select min(v) into first_missing from unnest(array['0001_phase1.sql', '0002_storage.sql', '0003_shop_profile_realtime.sql', '0004_error_codes.sql', '0005_device_passcode.sql', '0006_invite_name.sql', '0007_phase2_customer.sql', '0008_ledger.sql', '0009_tracking_guess_limit.sql', '0010_default_cashboxes.sql', '0011_finance_drilldown.sql', '0012_spec_completion.sql', '0013_tracking_ambiguous.sql', '0014_technicians.sql', '0015_offline_backup.sql', '0016_shop_identity.sql', '0017_growth.sql', '0018_account_state.sql', '0019_extras.sql', '0020_admin_paging.sql', '0021_spec_rules.sql', '0022_security_review.sql', '0023_restore.sql', '0024_signout.sql', '0025_integrity.sql', '0026_edit_delete.sql', '0027_inventory.sql', '0028_opening.sql', '0029_partners.sql', '0030_party_links.sql', '0031_partner_capital.sql', '0032_lists.sql', '0033_assistant.sql', '0034_branches.sql', '0035_lists_everywhere.sql', '0036_roles.sql', '0037_item_details.sql', '0038_roles_grant.sql', '0039_payment_plans.sql', '0040_branch_books.sql', '0041_analytics.sql', '0042_app_brand.sql', '0043_printing.sql', '0044_capture.sql', '0045_checklists.sql', '0046_master.sql', '0047_mfa.sql', '0048_used.sql', '0049_commissions.sql', '0050_insights.sql', '0051_demo.sql', '0052_catalog.sql', '0053_portal.sql', '0054_telegram.sql', '0055_eta_placeholder.sql', '0056_branch_features.sql', '0057_categories.sql', '0058_web_push.sql', '0059_counters_branch.sql', '0060_sale_lines.sql', '0061_attendance.sql']) v where v not in (select version from public.app_migrations);
  select max(version) into later_present from public.app_migrations where first_missing is not null and version > first_missing;
  if later_present is not null then raise exception 'E_UPGRADE_GAP: % موجود، بس % ناقص قبله. ابعت الرسالة دي للمطوّر.', later_present, first_missing; end if;
end $chk$;

-- 2) الأجزاء اللي قبل الجزء ده لازم تكون اتطبقت
do $ord$
declare
  files text[] := array['0001_phase1.sql', '0002_storage.sql', '0003_shop_profile_realtime.sql', '0004_error_codes.sql', '0005_device_passcode.sql', '0006_invite_name.sql', '0007_phase2_customer.sql', '0008_ledger.sql', '0009_tracking_guess_limit.sql', '0010_default_cashboxes.sql', '0011_finance_drilldown.sql', '0012_spec_completion.sql', '0013_tracking_ambiguous.sql', '0014_technicians.sql', '0015_offline_backup.sql', '0016_shop_identity.sql', '0017_growth.sql', '0018_account_state.sql', '0019_extras.sql', '0020_admin_paging.sql', '0021_spec_rules.sql', '0022_security_review.sql', '0023_restore.sql', '0024_signout.sql', '0025_integrity.sql', '0026_edit_delete.sql', '0027_inventory.sql', '0028_opening.sql', '0029_partners.sql', '0030_party_links.sql', '0031_partner_capital.sql', '0032_lists.sql', '0033_assistant.sql', '0034_branches.sql', '0035_lists_everywhere.sql', '0036_roles.sql', '0037_item_details.sql', '0038_roles_grant.sql', '0039_payment_plans.sql', '0040_branch_books.sql', '0041_analytics.sql', '0042_app_brand.sql', '0043_printing.sql', '0044_capture.sql', '0045_checklists.sql', '0046_master.sql', '0047_mfa.sql', '0048_used.sql', '0049_commissions.sql', '0050_insights.sql', '0051_demo.sql', '0052_catalog.sql', '0053_portal.sql', '0054_telegram.sql', '0055_eta_placeholder.sql', '0056_branch_features.sql', '0057_categories.sql', '0058_web_push.sql', '0059_counters_branch.sql', '0060_sale_lines.sql', '0061_attendance.sql'];
  parts int[] := array[1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 3, 3, 3, 3, 3, 3, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 5, 5];
  miss text;
begin
  select min(v) into miss from unnest(files) v where v < '0060_sale_lines.sql' and v not in (select version from public.app_migrations);
  if miss is not null then raise exception 'E_UPGRADE_ORDER: الملف % لسه ما اتطبقش. شغّل upgrade_part_%.sql الأول، وبعدين الجزء ده (5).', miss, parts[array_position(files, miss)]; end if;
end $ord$;

-- 3) ملفات الجزء 5 بالترتيب، كل ملف في transaction لوحده
-- ============================== 0060_sale_lines.sql ==============================
begin;
do $run$ begin
  if exists (select 1 from public.app_migrations where version = '0060_sale_lines.sql') then return; end if;
  execute $m0060$
-- 0060: 6ب فاتورة البيع: سطور كل بيع زي ما اتباع (الصنف، والاسم وقتها، والكمية، والسعر بالقروش)
--
-- قبل كده القيد كان فيه إجمالي البيع بس، فلو البيع فيه أكتر من صنف، سعر كل صنف ما كانش متخزّن.
-- - الجدول للإضافة بس: بيتكتب جوه record_sale في نفس الـ transaction بتاع القيد، وما بيتعدلش ولا بيتحذف.
-- - القراية بنفس صلاحيات القيد نفسه (اللي يشوف القيد يشوف سطوره)، والفني ما بيشوفش.
-- - الفاتورة من sale_invoice: صاحب المحل، أو اللي معاه صلاحية البيع في فرع القيد. المبالغ من سطور القيد (الدفتر)، والسطور للعرض بس.
-- - اسم العميل وتليفونه في الفاتورة لمين يشوف العملاء بس.
-- - البيع القديم (قبل الملف ده): الفاتورة بالإجمالي من الدفتر، والأصناف من حركة المخزون من غير سعر كل صنف.

create table public.sale_lines (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references public.shops(id),
  entry_id uuid not null references public.journal_entries(id),
  item_id uuid not null references public.items(id),
  name text not null check (length(name) <= 200),
  qty bigint not null check (qty > 0),
  price bigint not null check (price >= 0),
  seq integer not null default 0,
  -- العميل في البيع الكاش لعميل معروف (القيد ما بيسجّلوش لأنه ما بيأثرش على رصيده)
  customer_id uuid references public.customers(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);
create index sale_lines_entry on public.sale_lines(entry_id);
alter table public.sale_lines enable row level security;
create trigger set_updated_at before update on public.sale_lines for each row execute function public.tg_set_updated_at();
create trigger block_delete before delete on public.sale_lines for each row execute function public.tg_block_delete();
-- زي سطور القيد: ممنوع التعديل والحذف
create trigger ledger_immutable before update or delete on public.sale_lines for each row execute function public.tg_ledger_immutable();
create trigger ledger_no_truncate before truncate on public.sale_lines for each statement execute function public.tg_ledger_immutable();
-- نفس صلاحيات القيد (RLS بتاع journal_entries بيتطبق جوه الـ exists)
create policy sale_lines_select on public.sale_lines for select to authenticated
  using (shop_id = public.current_shop_id() and exists (select 1 from public.journal_entries e where e.id = entry_id));
revoke all on public.sale_lines from public, anon, authenticated;
grant select on public.sale_lines to authenticated;

-- record_sale: (src: 0057_categories.sql) + سطر لكل صنف في sale_lines
create or replace function public.record_sale(p_id uuid, p_lines jsonb, p_cashbox uuid default null, p_customer uuid default null, p_note text default null)
returns uuid
language plpgsql security definer set search_path = public as $$
declare
  s uuid := public.current_shop_id();
  e uuid := gen_random_uuid();
  l jsonb;
  it public.items;
  q bigint; p bigint; cost bigint;
  rev_parts bigint := 0; rev_acc bigint := 0; rev_srv bigint := 0; total_cost bigint := 0;
  debit_acc uuid; pt text; pid uuid;
  n int := 0;
begin
  perform public.ledger_require(array['owner', 'reception']::public.app_role[]);
  perform public.perm_require('sales', 'add');
  if public.ledger_idem(p_id) is not null then return public.ledger_idem(p_id); end if;
  -- البيع بالآجل لصاحب المحل بس
  if p_cashbox is null and (p_customer is null or public.current_app_role() <> 'owner') then raise exception 'E_BAD_INPUT'; end if;
  if p_customer is not null and not exists (select 1 from public.customers where id = p_customer and shop_id = s and deleted_at is null) then raise exception 'E_NOT_FOUND'; end if;
  if jsonb_typeof(p_lines) <> 'array' or jsonb_array_length(p_lines) = 0 then raise exception 'E_BAD_INPUT'; end if;
  insert into public.journal_entries(id, shop_id, source_type, source_id, memo, idem_key, created_by)
  values (e, s, 'sale', p_id, nullif(trim(p_note), ''), p_id, auth.uid());
  -- البيع بس: لو الإعداد مفتوح، اللي مش موجود بيخرج من غير تكلفة ويتسوى بعدين
  perform set_config('app.uncosted', 'on', true);
  for l in select * from jsonb_array_elements(p_lines) loop
    select * into it from public.items where id = (l ->> 'item')::uuid and shop_id = s and deleted_at is null;
    if not found then raise exception 'E_NOT_FOUND'; end if;
    q := (l ->> 'qty')::bigint;
    p := (l ->> 'price')::bigint;
    if q is null or q <= 0 or p is null or p < 0 then raise exception 'E_BAD_AMOUNT'; end if;
    -- 6ب: سطر البيع زي ما اتباع (الاسم والكمية والسعر) عشان فاتورة البيع
    n := n + 1;
    insert into public.sale_lines(shop_id, entry_id, item_id, name, qty, price, seq, customer_id) values (s, e, it.id, it.name, q, p, n, p_customer);
    -- K: الخدمة من غير مخزون ولا تكلفة، وإيرادها إيراد الصيانة
    if it.kind = 'service' then rev_srv := rev_srv + q * p; continue; end if;
    cost := public.ledger_issue(it.id, q, e);
    total_cost := total_cost + cost;
    if it.kind = 'part' then rev_parts := rev_parts + q * p; else rev_acc := rev_acc + q * p; end if;
  end loop;
  perform set_config('app.uncosted', 'off', true);
  perform public.ledger_amount(rev_parts + rev_acc + rev_srv);
  if p_cashbox is null then
    debit_acc := public.ledger_acc('ar'); pt := 'customer'; pid := p_customer;
  else
    debit_acc := (public.ledger_cashbox(p_cashbox)).id;
  end if;
  insert into public.journal_lines(shop_id, entry_id, account_id, party_type, party_id, debit, credit)
  values (s, e, debit_acc, pt, pid, rev_parts + rev_acc + rev_srv, 0);
  if rev_parts > 0 then insert into public.journal_lines(shop_id, entry_id, account_id, debit, credit) values (s, e, public.ledger_acc('rev_parts'), 0, rev_parts); end if;
  if rev_acc > 0 then insert into public.journal_lines(shop_id, entry_id, account_id, debit, credit) values (s, e, public.ledger_acc('rev_accessories'), 0, rev_acc); end if;
  if rev_srv > 0 then insert into public.journal_lines(shop_id, entry_id, account_id, debit, credit) values (s, e, public.ledger_acc('rev_repair'), 0, rev_srv); end if;
  if total_cost > 0 then
    insert into public.journal_lines(shop_id, entry_id, account_id, debit, credit) values
      (s, e, public.ledger_acc('cogs'), total_cost, 0), (s, e, public.ledger_acc('inventory'), 0, total_cost);
  end if;
  if p_cashbox is not null and p_customer is not null then
    null; -- البيع النقدي لعميل معروف ما بيأثرش على رصيده
  end if;
  return e;
end $$;

-- entry_args: (src: 0026_edit_delete.sql) + سطور البيع من sale_lines لو موجودة
create or replace function public.entry_args(p_entry uuid) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare
  o public.journal_entries;
  cash_in uuid; cash_out uuid; amt bigint; party uuid; acc uuid; res jsonb; pay public.payments; pur public.purchases;
  ls jsonb; rev bigint; cust uuid;
begin
  if public.current_app_role() is null or not public.can_correct() then raise exception 'E_FORBIDDEN'; end if;
  select * into o from public.journal_entries where id = p_entry and shop_id = public.current_shop_id();
  if not found then raise exception 'E_NOT_FOUND'; end if;
  select max(l.account_id::text) filter (where a.kind = 'cash' and l.debit > 0)::uuid,
         max(l.account_id::text) filter (where a.kind = 'cash' and l.credit > 0)::uuid,
         max(l.party_id::text) filter (where l.party_id is not null)::uuid,
         max(l.account_id::text) filter (where a.kind = 'expense' and l.debit > 0)::uuid,
         greatest(sum(l.debit), 0)
    into cash_in, cash_out, party, acc, amt
  from public.journal_lines l join public.accounts a on a.id = l.account_id where l.entry_id = o.id;
  res := jsonb_build_object('source_type', o.source_type, 'entry_no', o.entry_no, 'note', o.memo,
    'reversed', exists (select 1 from public.journal_entries where reverses_id = o.id),
    'editable', o.source_type in ('payment', 'expense', 'transfer', 'capital', 'drawing', 'advance', 'salary', 'salary_payment', 'supplier_payment', 'purchase', 'sale'));
  if o.source_type = 'payment' then
    select * into pay from public.payments where entry_id = o.id;
    res := res || jsonb_build_object('customer', pay.customer_id, 'device', pay.device_id, 'cashbox', pay.cashbox_id, 'method', pay.method, 'amount', pay.amount);
  elsif o.source_type = 'expense' then
    res := res || jsonb_build_object('account', acc, 'cashbox', cash_out, 'amount', amt);
  elsif o.source_type = 'transfer' then
    res := res || jsonb_build_object('from', cash_out, 'to', cash_in, 'amount', amt);
  elsif o.source_type = 'capital' then
    res := res || jsonb_build_object('cashbox', cash_in, 'amount', amt);
  elsif o.source_type = 'drawing' then
    res := res || jsonb_build_object('cashbox', cash_out, 'amount', amt);
  elsif o.source_type in ('advance', 'salary_payment') then
    res := res || jsonb_build_object('employee', party, 'cashbox', cash_out, 'amount', amt);
  elsif o.source_type = 'salary' then
    res := res || jsonb_build_object('employee', party, 'amount', amt);
  elsif o.source_type = 'supplier_payment' then
    res := res || jsonb_build_object('supplier', party, 'cashbox', cash_out, 'amount', amt);
  elsif o.source_type = 'purchase' then
    select * into pur from public.purchases where entry_id = o.id;
    select jsonb_agg(jsonb_build_object('item', m.item_id, 'qty', m.qty, 'unit_cost', m.value / nullif(m.qty, 0)) order by m.created_at) into ls
    from public.stock_moves m where m.entry_id = o.id;
    res := res || jsonb_build_object('supplier', pur.supplier_id, 'cashbox', cash_out, 'lines', coalesce(ls, '[]'::jsonb));
  elsif o.source_type = 'sale' then
    -- سعر البيع: لو صنف واحد بيتحسب من الإيراد، ولو أكتر من صنف بيتاخد سعر الصنف المسجل
    select coalesce(sum(l.credit), 0) into rev from public.journal_lines l join public.accounts a on a.id = l.account_id where l.entry_id = o.id and a.type = 'revenue';
    select max(l.party_id::text) filter (where l.party_type = 'customer')::uuid into cust from public.journal_lines l where l.entry_id = o.id;
    -- 6ب: البيع الجديد بسطوره زي ما اتباع بالظبط. القديم (قبل 0060) زي الأول
    select jsonb_agg(jsonb_build_object('item', sl.item_id, 'qty', sl.qty, 'price', sl.price) order by sl.seq) into ls
    from public.sale_lines sl where sl.entry_id = o.id and sl.deleted_at is null;
    if ls is null then
    select jsonb_agg(jsonb_build_object('item', x.item_id, 'qty', x.q,
             'price', case when x.n = 1 then rev / x.q else coalesce(i.sale_price, 0) end) order by x.first)
      into ls
    from (select m.item_id, -sum(m.qty) q, count(*) over () n, min(m.created_at) first from public.stock_moves m where m.entry_id = o.id group by m.item_id) x
    join public.items i on i.id = x.item_id;
    end if;
    res := res || jsonb_build_object('customer', cust, 'cashbox', cash_in, 'lines', coalesce(ls, '[]'::jsonb));
  end if;
  return res;
end $$;

-- backup_snapshot: (src: 0057_categories.sql) + sale_lines
create or replace function public.backup_snapshot(p_shop uuid) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare
  res jsonb := jsonb_build_object('format', 'warsha-backup', 'version', 1, 'generated_at', now(), 'shop_id', p_shop);
  t text;
  rows jsonb;
begin
  foreach t in array array['shops', 'branches', 'staff_branches', 'shop_branding', 'profiles', 'customers', 'devices', 'device_costs', 'status_log', 'device_notes', 'device_photos', 'device_checks',
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

-- restore_backup: (src: 0057_categories.sql) + sale_lines (بعد القيود والأصناف)
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

-- ---------- فاتورة البيع ----------
-- صاحب المحل، أو الموظف اللي معاه صلاحية البيع (أو يشوف المالية) في فرع القيد. الفني لأ.
create or replace function public.sale_invoice(p_entry uuid) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare
  s uuid := public.current_shop_id(); r public.app_role := public.current_app_role();
  o public.journal_entries; ls jsonb; old boolean := false;
  total bigint; paid bigint; due bigint; cust uuid; cname text; cphone text; rev_no integer;
begin
  if s is null or r is null or r = 'technician' then raise exception 'E_FORBIDDEN'; end if;
  select * into o from public.journal_entries where id = p_entry and shop_id = s and source_type = 'sale';
  if not found then raise exception 'E_NOT_FOUND'; end if;
  if r <> 'owner' and not ((public.has_perm('sales', 'add') or public.has_perm('finance', 'view')) and public.can_branch(o.branch_id)) then
    raise exception 'E_FORBIDDEN';
  end if;
  -- المبالغ من الدفتر: الإجمالي = الإيراد، والمدفوع = اللي دخل الخزنة، والباقي = على العميل
  select coalesce(sum(l.credit) filter (where a.type = 'revenue'), 0),
         coalesce(sum(l.debit) filter (where a.kind = 'cash'), 0),
         coalesce(sum(l.debit) filter (where a.kind = 'receivable'), 0),
         max(l.party_id::text) filter (where l.party_type = 'customer')::uuid
    into total, paid, due, cust
  from public.journal_lines l join public.accounts a on a.id = l.account_id where l.entry_id = o.id;
  select jsonb_agg(jsonb_build_object('name', sl.name, 'qty', sl.qty, 'price', sl.price, 'amount', sl.qty * sl.price) order by sl.seq) into ls
  from public.sale_lines sl where sl.entry_id = o.id and sl.deleted_at is null;
  if ls is null then
    -- بيع قديم: الأصناف والكميات بس (السعر ما كانش متخزّن)
    old := true;
    select jsonb_agg(jsonb_build_object('name', i.name, 'qty', x.q, 'price', null, 'amount', null) order by x.first) into ls
    from (select m.item_id, -sum(m.qty) q, min(m.created_at) first from public.stock_moves m where m.entry_id = o.id group by m.item_id) x
    join public.items i on i.id = x.item_id;
  end if;
  -- البيع الكاش لعميل معروف: العميل من سطور البيع
  cust := coalesce(cust, (select max(sl.customer_id::text)::uuid from public.sale_lines sl where sl.entry_id = o.id));
  -- اسم العميل وتليفونه لمين يشوف العملاء بس (نفس صلاحية جدول العملاء)
  if cust is not null and (r = 'owner' or public.has_perm('customers', 'view') or public.has_perm('intake', 'add')) then
    select c.name, c.phone into cname, cphone from public.customers c where c.id = cust;
  end if;
  select e.entry_no into rev_no from public.journal_entries e where e.reverses_id = o.id;
  return jsonb_build_object('entry_no', o.entry_no, 'at', o.occurred_at, 'memo', o.memo, 'branch_id', o.branch_id,
    'lines', coalesce(ls, '[]'::jsonb), 'legacy', old, 'total', total, 'paid', paid, 'due', due,
    'customer', cname, 'phone', cphone, 'cancelled_by', rev_no);
end $$;
revoke execute on function public.sale_invoice(uuid) from public, anon;
grant execute on function public.sale_invoice(uuid) to authenticated;
$m0060$;
  insert into public.app_migrations(version, how) values ('0060_sale_lines.sql', 'applied');
  raise notice 'applied %', '0060_sale_lines.sql';
end $run$;
commit;

-- ============================== 0061_attendance.sql ==============================
begin;
do $run$ begin
  if exists (select 1 from public.app_migrations where version = '0061_attendance.sql') then return; end if;
  execute $m0061$
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
  -- طلبين في نفس اللحظة (الطابور بيعيد والأول لسه ماشي): نفس الـ id = نفس السجل، وسجل مفتوح تاني = E_ALREADY_IN
  begin
    insert into public.attendance(id, shop_id, branch_id, profile_id, clock_in, note)
    values (p_id, s, public.op_branch(), me, now(), nullif(trim(left(p_note, 300)), ''));
  exception when unique_violation then
    if exists (select 1 from public.attendance where id = p_id and profile_id = me) then return p_id; end if;
    raise exception 'E_ALREADY_IN';
  end;
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
  -- السماح: رقم صحيح من 0 لـ 600، وأي قيمة تانية (فاضية أو بكسر) = 15، عشان إعداد غلط ما يوقّعش التقرير
  select sh.extras -> 'attendance' ->> 'start',
         case when (sh.extras -> 'attendance' ->> 'grace_min') ~ '^[0-9]{1,3}$' then least((sh.extras -> 'attendance' ->> 'grace_min')::int, 600) else 15 end
    into st, grace from public.shops sh where sh.id = s;
  if st !~ '^([01][0-9]|2[0-3]):[0-5][0-9]$' then st := null; end if;
  return query
  select a.id, a.profile_id, p.full_name, a.branch_id, a.clock_in, a.clock_out,
         -- دقايق كاملة (من غير تقريب لفوق)
         case when a.clock_out is null then null else floor(extract(epoch from a.clock_out - a.clock_in) / 60)::int end,
         case when st is null then 0
              else greatest(0, floor(extract(epoch from (a.clock_in at time zone 'Africa/Cairo') - ((a.clock_in at time zone 'Africa/Cairo')::date + st::time)) / 60)::int - grace) end,
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
-- سجلين لنفس الموظف ما يتداخلوش (عشان الساعات ما تتحسبش مرتين). المفتوح لحد دلوقتي
create or replace function public.attendance_overlaps(p_profile uuid, p_in timestamptz, p_out timestamptz, p_except uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.attendance a
    where a.profile_id = p_profile and a.deleted_at is null and a.id is distinct from p_except
      and tstzrange(a.clock_in, coalesce(a.clock_out, greatest(now(), a.clock_in + interval '1 second')), '[)')
          && tstzrange(p_in, coalesce(p_out, greatest(now(), p_in + interval '1 second')), '[)'))
$$;
revoke execute on function public.attendance_overlaps(uuid, timestamptz, timestamptz, uuid) from public, anon, authenticated;
create or replace function public.attendance_fix(p_id uuid, p_in timestamptz, p_out timestamptz, p_reason text) returns void
language plpgsql security definer set search_path = public as $$
declare s uuid := public.current_shop_id(); pr uuid;
begin
  perform public.ledger_require(array['owner']::public.app_role[]);
  if coalesce(trim(p_reason), '') = '' then raise exception 'E_REASON_REQUIRED'; end if;
  if p_in is null or (p_out is not null and (p_out <= p_in or p_out - p_in > interval '24 hours')) then raise exception 'E_BAD_INPUT'; end if;
  select profile_id into pr from public.attendance where id = p_id and shop_id = s and deleted_at is null;
  if pr is null then raise exception 'E_NOT_FOUND'; end if;
  if public.attendance_overlaps(pr, p_in, p_out, p_id) then raise exception 'E_ATT_OVERLAP'; end if;
  -- سيبه مفتوح وهو عنده سجل مفتوح تاني
  if p_out is null and exists (select 1 from public.attendance where profile_id = pr and clock_out is null and deleted_at is null and id <> p_id) then raise exception 'E_ALREADY_IN'; end if;
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
  if public.attendance_overlaps(p_profile, p_in, p_out, null) then raise exception 'E_ATT_OVERLAP'; end if;
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

-- ---------- سرعة الـ RLS: دالة المحل والدور مرة واحدة في الاستعلام، مش مع كل صف ----------
-- current_shop_id() وcurrent_app_role() بيقروا الملف الشخصي (وcurrent_shop_id بيتأكد من التحقق بخطوتين كمان) مع كل صف.
-- مع كتر المحلات، استعلام بسيط كان بيعدّي مهلة الـ 8 ثواني. الحل اللي Supabase بيوصي بيه: (select ...) حوالين الدالة،
-- فبتتحسب مرة واحدة. نفس الشروط بالظبط، والنتيجة نفسها. وآمن يتعاد (السياسة اللي اتلفّت قبل كده بتتخطى).
create or replace function public.rls_wrap(t text) returns text
language plpgsql immutable as $$
begin
  if t is null then return null; end if;
  -- الملفوفة قبل كده (شكلها المحفوظ: SELECT current_shop_id() AS current_shop_id) بتتعلّم الأول عشان ما تتلفّش تاني
  t := regexp_replace(t, 'SELECT (public\.)?(current_shop_id|current_app_role)\(\) AS (current_shop_id|current_app_role)', 'SELECT @@\2@@ AS \3', 'g');
  t := regexp_replace(t, '\m(public\.)?(current_shop_id|current_app_role)\(\)', '(select public.\2())', 'g');
  return regexp_replace(t, '@@(current_shop_id|current_app_role)@@', 'public.\1()', 'g');
end $$;
revoke execute on function public.rls_wrap(text) from public, anon, authenticated;
do $rls$
declare p record; q text; c text;
begin
  for p in select schemaname, tablename, policyname, qual, with_check from pg_policies where schemaname = 'public' loop
    q := public.rls_wrap(p.qual);
    c := public.rls_wrap(p.with_check);
    if q is distinct from p.qual or c is distinct from p.with_check then
      execute format('alter policy %I on %I.%I', p.policyname, p.schemaname, p.tablename)
        || case when p.qual is not null then format(' using (%s)', q) else '' end
        || case when p.with_check is not null then format(' with check (%s)', c) else '' end;
    end if;
  end loop;
end $rls$;


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
$m0061$;
  insert into public.app_migrations(version, how) values ('0061_attendance.sql', 'applied');
  raise notice 'applied %', '0061_attendance.sql';
end $run$;
commit;

select 5 as part, 5 as parts, count(*) as applied_files, max(version) as latest,
  case when '0061_attendance.sql' in (select version from public.app_migrations) then
    'خلص: المشروع على آخر نسخة'
  else 'فيه ملف ما اتطبقش' end as status
from public.app_migrations;
