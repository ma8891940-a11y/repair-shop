-- جوالك / Gawalak: ترقية مشروع Supabase لآخر نسخة، الجزء 4 من 4 (الملفات 0041_analytics.sql لـ 0060_sale_lines.sql).
-- بيتولد تلقائيًا: npm run db:setup-file. ما تعدّلوش بإيدك.
-- شغّل الأجزاء بالترتيب في SQL Editor (كل جزء لوحده: New query ← الصق ← Run): upgrade_part_1.sql ثم upgrade_part_2.sql ثم upgrade_part_3.sql ثم upgrade_part_4.sql.
-- آمن تشغّل أي جزء أكتر من مرة: اللي اتطبق قبل كده بيتخطى. ولو ملف فشل، اللي قبله بيفضل، وصلّح السبب وشغّل نفس الجزء تاني.
-- لو لقى ملف أحدث موجود وأقدم منه ناقص بيقف (E_UPGRADE_GAP). ولو جزء قبله لسه ما اتطبقش بيقف (E_UPGRADE_ORDER). الاتنين من غير تغيير.
-- ملفات الجزء ده: 0041_analytics.sql, 0042_app_brand.sql, 0043_printing.sql, 0044_capture.sql, 0045_checklists.sql, 0046_master.sql, 0047_mfa.sql, 0048_used.sql, 0049_commissions.sql, 0050_insights.sql, 0051_demo.sql, 0052_catalog.sql, 0053_portal.sql, 0054_telegram.sql, 0055_eta_placeholder.sql, 0056_branch_features.sql, 0057_categories.sql, 0058_web_push.sql, 0059_counters_branch.sql, 0060_sale_lines.sql

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
  insert into public.app_migrations(version, how) select v, 'inferred' from unnest(array['0022_security_review.sql']::text[]) v
    where v < (select max(version) from public.app_migrations) on conflict (version) do nothing;
  select min(v) into first_missing from unnest(array['0001_phase1.sql', '0002_storage.sql', '0003_shop_profile_realtime.sql', '0004_error_codes.sql', '0005_device_passcode.sql', '0006_invite_name.sql', '0007_phase2_customer.sql', '0008_ledger.sql', '0009_tracking_guess_limit.sql', '0010_default_cashboxes.sql', '0011_finance_drilldown.sql', '0012_spec_completion.sql', '0013_tracking_ambiguous.sql', '0014_technicians.sql', '0015_offline_backup.sql', '0016_shop_identity.sql', '0017_growth.sql', '0018_account_state.sql', '0019_extras.sql', '0020_admin_paging.sql', '0021_spec_rules.sql', '0022_security_review.sql', '0023_restore.sql', '0024_signout.sql', '0025_integrity.sql', '0026_edit_delete.sql', '0027_inventory.sql', '0028_opening.sql', '0029_partners.sql', '0030_party_links.sql', '0031_partner_capital.sql', '0032_lists.sql', '0033_assistant.sql', '0034_branches.sql', '0035_lists_everywhere.sql', '0036_roles.sql', '0037_item_details.sql', '0038_roles_grant.sql', '0039_payment_plans.sql', '0040_branch_books.sql', '0041_analytics.sql', '0042_app_brand.sql', '0043_printing.sql', '0044_capture.sql', '0045_checklists.sql', '0046_master.sql', '0047_mfa.sql', '0048_used.sql', '0049_commissions.sql', '0050_insights.sql', '0051_demo.sql', '0052_catalog.sql', '0053_portal.sql', '0054_telegram.sql', '0055_eta_placeholder.sql', '0056_branch_features.sql', '0057_categories.sql', '0058_web_push.sql', '0059_counters_branch.sql', '0060_sale_lines.sql']) v where v not in (select version from public.app_migrations);
  select max(version) into later_present from public.app_migrations where first_missing is not null and version > first_missing;
  if later_present is not null then raise exception 'E_UPGRADE_GAP: % موجود، بس % ناقص قبله. ابعت الرسالة دي للمطوّر.', later_present, first_missing; end if;
end $chk$;

-- 2) الأجزاء اللي قبل الجزء ده لازم تكون اتطبقت
do $ord$
declare
  files text[] := array['0001_phase1.sql', '0002_storage.sql', '0003_shop_profile_realtime.sql', '0004_error_codes.sql', '0005_device_passcode.sql', '0006_invite_name.sql', '0007_phase2_customer.sql', '0008_ledger.sql', '0009_tracking_guess_limit.sql', '0010_default_cashboxes.sql', '0011_finance_drilldown.sql', '0012_spec_completion.sql', '0013_tracking_ambiguous.sql', '0014_technicians.sql', '0015_offline_backup.sql', '0016_shop_identity.sql', '0017_growth.sql', '0018_account_state.sql', '0019_extras.sql', '0020_admin_paging.sql', '0021_spec_rules.sql', '0022_security_review.sql', '0023_restore.sql', '0024_signout.sql', '0025_integrity.sql', '0026_edit_delete.sql', '0027_inventory.sql', '0028_opening.sql', '0029_partners.sql', '0030_party_links.sql', '0031_partner_capital.sql', '0032_lists.sql', '0033_assistant.sql', '0034_branches.sql', '0035_lists_everywhere.sql', '0036_roles.sql', '0037_item_details.sql', '0038_roles_grant.sql', '0039_payment_plans.sql', '0040_branch_books.sql', '0041_analytics.sql', '0042_app_brand.sql', '0043_printing.sql', '0044_capture.sql', '0045_checklists.sql', '0046_master.sql', '0047_mfa.sql', '0048_used.sql', '0049_commissions.sql', '0050_insights.sql', '0051_demo.sql', '0052_catalog.sql', '0053_portal.sql', '0054_telegram.sql', '0055_eta_placeholder.sql', '0056_branch_features.sql', '0057_categories.sql', '0058_web_push.sql', '0059_counters_branch.sql', '0060_sale_lines.sql'];
  parts int[] := array[1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 3, 3, 3, 3, 3, 3, 3, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4];
  miss text;
begin
  select min(v) into miss from unnest(files) v where v < '0041_analytics.sql' and v not in (select version from public.app_migrations);
  if miss is not null then raise exception 'E_UPGRADE_ORDER: الملف % لسه ما اتطبقش. شغّل upgrade_part_%.sql الأول، وبعدين الجزء ده (4).', miss, parts[array_position(files, miss)]; end if;
end $ord$;

-- 3) ملفات الجزء 4 بالترتيب، كل ملف في transaction لوحده
-- ============================== 0041_analytics.sql ==============================
begin;
do $run$ begin
  if exists (select 1 from public.app_migrations where version = '0041_analytics.sql') then return; end if;
  execute $m0041$
-- 0041: U3: الأداء والتحليلات لكل فرع وللمحل كله، وأهداف شهرية لكل فرع.
-- كل رقم محسوب من القيود (بنسبة الفروع من 0040) ومن الأجهزة وحركات المخزون. من غير أي ذكاء اصطناعي.

create table public.branch_goals (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references public.shops(id),
  branch_id uuid not null references public.branches(id),
  month date not null check (extract(day from month) = 1),
  metric text not null check (metric in ('revenue', 'profit')),
  target bigint not null check (target > 0 and target <= 100000000000),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);
create unique index branch_goals_uq on public.branch_goals(branch_id, month, metric) where deleted_at is null;
alter table public.branch_goals enable row level security;
create trigger set_updated_at before update on public.branch_goals for each row execute function public.tg_set_updated_at();
create trigger block_delete before delete on public.branch_goals for each row execute function public.tg_block_delete();
create trigger zz_audit after insert or update on public.branch_goals for each row execute function public.tg_audit();
create policy goals_select on public.branch_goals for select to authenticated
  using (shop_id = public.current_shop_id() and (public.current_app_role() = 'owner' or (public.current_app_role() = 'reception' and (select public.has_perm('reports', 'view')) and public.can_branch(branch_id))));
grant select on public.branch_goals to authenticated;

-- هدف الشهر (صاحب المحل بس). 0 أو أقل ← بيتشال
create or replace function public.save_goal(p_branch uuid, p_month date, p_metric text, p_target bigint) returns void
language plpgsql security definer set search_path = public as $$
declare s uuid := public.current_shop_id(); m date := date_trunc('month', p_month)::date;
begin
  perform public.ledger_require(array['owner']::public.app_role[]);
  if p_metric not in ('revenue', 'profit') then raise exception 'E_BAD_INPUT'; end if;
  if not exists (select 1 from public.branches where id = p_branch and shop_id = s and deleted_at is null) then raise exception 'E_BAD_BRANCH'; end if;
  update public.branch_goals set deleted_at = now() where branch_id = p_branch and month = m and metric = p_metric and deleted_at is null;
  if coalesce(p_target, 0) > 0 then
    perform public.ledger_amount(p_target);
    insert into public.branch_goals(shop_id, branch_id, month, metric, target) values (s, p_branch, m, p_metric, p_target);
  end if;
end $$;
revoke execute on function public.save_goal(uuid, date, text, bigint) from public, anon;
grant execute on function public.save_goal(uuid, date, text, bigint) to authenticated;

-- المؤشرات لكل فرع في فترة (والمجموع بيتحسب في الواجهة من نفس الأرقام الخام، عشان النسب تطلع صح).
-- كل المبالغ بالقروش، والمدد بالدقايق، والنسب بتتحسب في الواجهة من الأعداد الخام دي.
create or replace function public.branch_kpis(p_from timestamptz, p_to timestamptz)
returns table(branch_id uuid, revenue bigint, cogs bigint, opex bigint, invoices integer, devices_in integer, devices_out integer,
              repair_minutes bigint, returns integer, stock_value bigint, stale_value bigint, stale_items integer,
              receivables bigint, receivables_60 bigint, goal_revenue bigint, goal_profit bigint)
language plpgsql stable security definer set search_path = public as $$
#variable_conflict use_column
declare s uuid := public.current_shop_id(); stale interval := interval '60 days';
begin
  perform public.grant_require('reports', 'view');
  return query
  with br as (
    select b.id from public.branches b where b.shop_id = s and b.deleted_at is null and (public.all_my_branches() or public.can_branch(b.id))
  ), bl as (
    select l.*, a.type, a.kind, a.code from public.branch_lines_raw(p_to) l left join public.accounts a on a.id = l.account_id
  ), money as (
    select bl.branch_id,
      coalesce(-sum(bl.amount) filter (where bl.type = 'revenue' and bl.kind = 'revenue' and bl.occurred_at >= p_from), 0)::bigint rev,
      coalesce(sum(bl.amount) filter (where bl.type = 'expense' and bl.kind = 'cogs' and bl.occurred_at >= p_from), 0)::bigint cg,
      coalesce(sum(bl.amount) filter (where bl.type = 'expense' and bl.kind <> 'cogs' and bl.occurred_at >= p_from), 0)::bigint ox,
      count(distinct bl.entry_id) filter (where bl.source_type in ('sale', 'delivery') and bl.type = 'revenue' and bl.occurred_at >= p_from)::int inv,
      coalesce(sum(bl.amount) filter (where bl.kind = 'receivable'), 0)::bigint ar,
      coalesce(sum(bl.amount) filter (where bl.kind = 'receivable' and bl.occurred_at < now() - interval '60 days'), 0)::bigint ar60
    from bl group by 1
  ), dev as (
    select d.branch_id,
      count(*) filter (where d.received_at >= p_from and d.received_at < p_to)::int din,
      count(*) filter (where d.status = 'delivered' and d.delivered_at >= p_from and d.delivered_at < p_to)::int dout,
      coalesce(sum(extract(epoch from d.delivered_at - d.received_at) / 60) filter (where d.status = 'delivered' and d.delivered_at >= p_from and d.delivered_at < p_to), 0)::bigint mins,
      count(*) filter (where d.status = 'warranty_return' and d.updated_at >= p_from and d.updated_at < p_to)::int ret
    from public.devices d where d.shop_id = s and d.deleted_at is null group by 1
  ), stock as (
    select m.branch_id, m.item_id, sum(m.qty) q, sum(m.value) v,
           max(m.created_at) filter (where m.qty < 0) last_out
    from public.stock_moves m where m.shop_id = s group by 1, 2
  ), st as (
    select x.branch_id, coalesce(sum(x.v) filter (where x.q > 0), 0)::bigint sv,
      coalesce(sum(x.v) filter (where x.q > 0 and coalesce(x.last_out, 'epoch'::timestamptz) < now() - stale), 0)::bigint stv,
      count(*) filter (where x.q > 0 and coalesce(x.last_out, 'epoch'::timestamptz) < now() - stale)::int sti
    from stock x group by 1
  ), g as (
    select gg.branch_id,
      max(gg.target) filter (where gg.metric = 'revenue') gr, max(gg.target) filter (where gg.metric = 'profit') gp
    from public.branch_goals gg where gg.shop_id = s and gg.deleted_at is null and gg.month = date_trunc('month', p_from at time zone 'Africa/Cairo')::date
    group by 1
  )
  select br.id, coalesce(m.rev, 0), coalesce(m.cg, 0), coalesce(m.ox, 0), coalesce(m.inv, 0), coalesce(dv.din, 0), coalesce(dv.dout, 0),
         coalesce(dv.mins, 0), coalesce(dv.ret, 0), coalesce(st.sv, 0), coalesce(st.stv, 0), coalesce(st.sti, 0),
         coalesce(m.ar, 0), coalesce(m.ar60, 0), g.gr, g.gp
  from br left join money m on m.branch_id = br.id left join dev dv on dv.branch_id = br.id left join st on st.branch_id = br.id left join g on g.branch_id = br.id;
end $$;
revoke execute on function public.branch_kpis(timestamptz, timestamptz) from public, anon;
grant execute on function public.branch_kpis(timestamptz, timestamptz) to authenticated;

-- الأصناف الراكدة (فيها رصيد ومحدش باعها من 60 يوم) لكل فرع، للتوصيات
create or replace function public.stale_items(p_days integer default 60)
returns table(branch_id uuid, item_id uuid, name text, qty bigint, value bigint, last_out timestamptz)
language plpgsql stable security definer set search_path = public as $$
#variable_conflict use_column
declare s uuid := public.current_shop_id();
begin
  perform public.grant_require('reports', 'view');
  return query
  select m.branch_id, i.id, i.name, sum(m.qty)::bigint, sum(m.value)::bigint, max(m.created_at) filter (where m.qty < 0)
  from public.stock_moves m join public.items i on i.id = m.item_id and i.deleted_at is null
  where m.shop_id = s and (public.all_my_branches() or public.can_branch(m.branch_id))
  group by m.branch_id, i.id, i.name
  having sum(m.qty) > 0 and coalesce(max(m.created_at) filter (where m.qty < 0), 'epoch'::timestamptz) < now() - make_interval(days => greatest(coalesce(p_days, 60), 1))
  order by 5 desc
  limit 50;
end $$;
revoke execute on function public.stale_items(integer) from public, anon;
grant execute on function public.stale_items(integer) to authenticated;
$m0041$;
  insert into public.app_migrations(version, how) values ('0041_analytics.sql', 'applied');
  raise notice 'applied %', '0041_analytics.sql';
end $run$;
commit;

-- ============================== 0042_app_brand.sql ==============================
begin;
do $run$ begin
  if exists (select 1 from public.app_migrations where version = '0042_app_brand.sql') then return; end if;
  execute $m0042$
-- 0042: U4: هوية صاحب المحل في التطبيق (shops.extras.app = {name, logo, accent}).
-- رابط الدخول الخاص بالمحل (#/?shop=رقم المحل) بيجيب الاسم واللوجو واللون بس، من غير تسجيل دخول.
-- مفيش أي بيانات تانية عن المحل أو عملائه بتطلع من هنا.
create or replace function public.public_app_brand(p_shop uuid) returns jsonb
language sql stable security definer set search_path = public as $$
  select jsonb_build_object(
    'name', left(nullif(trim(s.extras -> 'app' ->> 'name'), ''), 40),
    'logo', case when (s.extras -> 'app' ->> 'logo') like 'data:image/%' and length(s.extras -> 'app' ->> 'logo') <= 400000 then s.extras -> 'app' ->> 'logo' end,
    'accent', case when (s.extras -> 'app' ->> 'accent') ~ '^#[0-9a-fA-F]{6}$' then s.extras -> 'app' ->> 'accent' end)
  from public.shops s where s.id = p_shop and s.suspended_at is null and s.deleted_at is null
$$;
revoke execute on function public.public_app_brand(uuid) from public;
grant execute on function public.public_app_brand(uuid) to anon, authenticated;
$m0042$;
  insert into public.app_migrations(version, how) values ('0042_app_brand.sql', 'applied');
  raise notice 'applied %', '0042_app_brand.sql';
end $run$;
commit;

-- ============================== 0043_printing.sql ==============================
begin;
do $run$ begin
  if exists (select 1 from public.app_migrations where version = '0043_printing.sql') then return; end if;
  execute $m0043$
-- 0043: U5: الطابعات ومصمم الطباعة.
-- المتصفح ما بيقدرش يعرض الطابعات المتوصلة، فكل طابعة "ملف" بمقاسها وهوامشها، والطباعة بتفتح نافذة الطباعة على المقاس الصح.
-- القالب بيتحكم في الشكل بس (الخانات وترتيبها وحجم الخط والمحاذاة). الأرقام والبيانات دايمًا من البرنامج.

create table public.printers (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references public.shops(id),
  branch_id uuid references public.branches(id),
  name text not null check (length(trim(name)) between 1 and 60),
  kind text not null check (kind in ('thermal58', 'thermal80', 'label', 'a4', 'a5', 'dot')),
  model text check (model is null or length(model) <= 60),
  width_mm integer not null check (width_mm between 20 and 300),
  height_mm integer check (height_mm is null or height_mm between 10 and 450),
  margin_mm integer not null default 3 check (margin_mm between 0 and 30),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

create table public.print_templates (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references public.shops(id),
  branch_id uuid references public.branches(id),
  doc text not null check (doc in ('sticker', 'receipt', 'receipt-a4', 'invoice', 'label', 'sale', 'statement', 'barcode', 'voucher')),
  printer_id uuid references public.printers(id),
  name text not null check (length(trim(name)) between 1 and 60),
  blocks jsonb not null check (jsonb_typeof(blocks) = 'array' and jsonb_array_length(blocks) <= 60),
  is_default boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);
-- افتراضي واحد لكل نوع ورقة في كل فرع (أو للمحل كله لو مفيش فرع)
create unique index print_templates_default on public.print_templates(shop_id, doc, coalesce(branch_id, '00000000-0000-0000-0000-000000000000'::uuid)) where is_default and deleted_at is null;

alter table public.printers enable row level security;
alter table public.print_templates enable row level security;
create trigger set_updated_at before update on public.printers for each row execute function public.tg_set_updated_at();
create trigger set_updated_at before update on public.print_templates for each row execute function public.tg_set_updated_at();
create trigger block_delete before delete on public.printers for each row execute function public.tg_block_delete();
create trigger block_delete before delete on public.print_templates for each row execute function public.tg_block_delete();
create trigger a_force_shop_id before insert or update on public.printers for each row execute function public.tg_force_shop_id();
create trigger a_force_shop_id before insert or update on public.print_templates for each row execute function public.tg_force_shop_id();
create trigger zz_audit after insert or update on public.printers for each row execute function public.tg_audit();
create trigger zz_audit after insert or update on public.print_templates for each row execute function public.tg_audit();

-- القراية للمحل كله (كل اللي بيطبع محتاج القالب)، والتعديل لصاحب المحل بس
create policy printers_select on public.printers for select to authenticated using (shop_id = public.current_shop_id());
create policy printers_insert on public.printers for insert to authenticated with check (shop_id = public.current_shop_id() and public.current_app_role() = 'owner');
create policy printers_update on public.printers for update to authenticated using (shop_id = public.current_shop_id() and public.current_app_role() = 'owner');
create policy templates_select on public.print_templates for select to authenticated using (shop_id = public.current_shop_id());
create policy templates_insert on public.print_templates for insert to authenticated with check (shop_id = public.current_shop_id() and public.current_app_role() = 'owner');
create policy templates_update on public.print_templates for update to authenticated using (shop_id = public.current_shop_id() and public.current_app_role() = 'owner');
grant select, insert, update on public.printers, public.print_templates to authenticated;
$m0043$;
  insert into public.app_migrations(version, how) values ('0043_printing.sql', 'applied');
  raise notice 'applied %', '0043_printing.sql';
end $run$;
commit;

-- ============================== 0044_capture.sql ==============================
begin;
do $run$ begin
  if exists (select 1 from public.app_migrations where version = '0044_capture.sql') then return; end if;
  execute $m0044$
-- 0044: C1: صور الاستلام من موبايل الفني بالـ QR، وصور الاستلام في صفحة التتبع.
-- الفكرة: الاستقبال بيفتح "جلسة رفع" للجهاز (token عشوائي 128 bit، صالح 30 دقيقة، وأقصى 6 صور للجهاز زي ما هو).
-- الموبايل بيفتح الرابط من غير تسجيل دخول، وبيرفع الصورة على Storage ومعاها الـ token في header (x-upload-token)،
-- وسياسة Storage بتتأكد إن الجلسة شغالة وإن المسار جوه فولدر نفس المحل ونفس الجهاز. بعدها الصورة بتتسجل على الجهاز.
-- صفحة التتبع: صور الاستلام بتظهر لصاحب رابط التتبع بس (header x-track-token = tracking_token بتاع الجهاز).

create table public.photo_upload_sessions (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references public.shops(id),
  device_id uuid not null references public.devices(id),
  token text not null unique check (length(token) = 32),
  expires_at timestamptz not null,
  created_by uuid references public.profiles(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);
create index photo_upload_sessions_device on public.photo_upload_sessions(device_id);
alter table public.photo_upload_sessions enable row level security;
create trigger set_updated_at before update on public.photo_upload_sessions for each row execute function public.tg_set_updated_at();
create trigger block_delete before delete on public.photo_upload_sessions for each row execute function public.tg_block_delete();
-- القراية لموظفين نفس المحل اللي بيرفعوا صور بس؛ الإنشاء من الدالة بس (مفيش سياسة إضافة)
create policy upload_sessions_select on public.photo_upload_sessions for select to authenticated
  using (shop_id = public.current_shop_id() and public.current_app_role() in ('owner', 'reception'));
grant select on public.photo_upload_sessions to authenticated;

-- uploaded_by: من الجلسة لما الرفع جاي من الموبايل من غير تسجيل دخول
create or replace function public.tg_photo_limit() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  perform pg_advisory_xact_lock(hashtext(new.device_id::text));
  if (select count(*) from public.device_photos where device_id = new.device_id and deleted_at is null) >= 6 then
    raise exception 'E_PHOTO_LIMIT';
  end if;
  if new.storage_path not like new.shop_id::text || '/' || new.device_id::text || '/%' then
    raise exception 'E_PHOTO_PATH';
  end if;
  new.uploaded_by := coalesce(auth.uid(), case when current_setting('warsha.system', true) = 'on' then new.uploaded_by end);
  return new;
end $$;

-- فتح جلسة رفع (الاستقبال أو صاحب المحل، لجهاز في نفس المحل لسه ما اتسلمش)
create or replace function public.start_photo_upload(p_device uuid)
returns table(token text, expires_at timestamptz)
-- extensions: فيها gen_random_bytes على Supabase
language plpgsql security definer set search_path = public, extensions, pg_temp as $$
declare d public.devices; t text := encode(gen_random_bytes(16), 'hex'); e timestamptz := now() + interval '30 minutes';
begin
  if public.current_app_role() not in ('owner', 'reception') then raise exception 'E_FORBIDDEN'; end if;
  select * into d from public.devices where id = p_device and shop_id = public.current_shop_id() and deleted_at is null;
  if d.id is null then raise exception 'E_NOT_FOUND'; end if;
  if d.status = 'delivered' then raise exception 'E_DELIVERED'; end if;
  -- الجلسات القديمة لنفس الجهاز بتتقفل (رابط واحد شغال في نفس الوقت)
  update public.photo_upload_sessions s set deleted_at = now() where s.device_id = d.id and s.deleted_at is null;
  insert into public.photo_upload_sessions(shop_id, device_id, token, expires_at, created_by)
  values (d.shop_id, d.id, t, e, auth.uid());
  return query select t, e;
end $$;
revoke execute on function public.start_photo_upload(uuid) from public, anon;
grant execute on function public.start_photo_upload(uuid) to authenticated;

-- الجلسة الشغالة من الـ token (داخلي)
create or replace function public.photo_session_by(p_token text) returns public.photo_upload_sessions
language sql stable security definer set search_path = public as $$
  select s.* from public.photo_upload_sessions s
  join public.devices d on d.id = s.device_id and d.deleted_at is null and d.status <> 'delivered'
  join public.shops sh on sh.id = s.shop_id and sh.deleted_at is null and sh.suspended_at is null
  where s.token = p_token and s.deleted_at is null and s.expires_at > now()
$$;
revoke execute on function public.photo_session_by(text) from public, anon, authenticated;

-- اللي الموبايل محتاجه يعرضه: اسم المحل، ورقم الطلب، والموديل، وعدد الصور، والمسار. من غير أي بيانات للعميل.
create or replace function public.photo_session(p_token text)
returns table(shop_name text, order_no text, brand text, model text, photos integer, max_photos integer, expires_at timestamptz, folder text)
language plpgsql stable security definer set search_path = public as $$
declare s public.photo_upload_sessions := public.photo_session_by(p_token);
begin
  if s.id is null then return; end if;
  return query
  select sh.name, d.order_no, d.brand, d.model,
    (select count(*)::integer from public.device_photos p where p.device_id = d.id and p.deleted_at is null),
    6, s.expires_at, s.shop_id::text || '/' || s.device_id::text
  from public.devices d join public.shops sh on sh.id = d.shop_id where d.id = s.device_id;
end $$;
revoke execute on function public.photo_session(text) from public;
grant execute on function public.photo_session(text) to anon, authenticated;

-- سياسة Storage: الرفع بـ token الجلسة في الـ header، جوه فولدر نفس الجهاز، وقبل ما يوصل للحد
create or replace function public.photo_upload_allowed(p_name text) returns boolean
language plpgsql stable security definer set search_path = public as $$
declare
  tok text := nullif(current_setting('request.headers', true), '')::json ->> 'x-upload-token';
  s public.photo_upload_sessions;
begin
  if tok is null then return false; end if;
  s := public.photo_session_by(tok);
  if s.id is null then return false; end if;
  return p_name like s.shop_id::text || '/' || s.device_id::text || '/%'
    and p_name ~ '^[0-9a-f-]{36}/[0-9a-f-]{36}/[0-9a-f-]{36}\.jpg$'
    and (select count(*) from public.device_photos p where p.device_id = s.device_id and p.deleted_at is null) < 6;
exception when others then return false;
end $$;
revoke execute on function public.photo_upload_allowed(text) from public;
grant execute on function public.photo_upload_allowed(text) to anon, authenticated;

create policy device_photos_session_upload on storage.objects for insert to anon, authenticated
  with check (bucket_id = 'device-photos' and public.photo_upload_allowed(name));

-- بعد الرفع: الصورة بتتسجل على الجهاز (لازم تكون اترفعت فعلًا في Storage)
create or replace function public.add_session_photo(p_token text, p_path text) returns uuid
language plpgsql security definer set search_path = public as $$
declare s public.photo_upload_sessions := public.photo_session_by(p_token); pid uuid := gen_random_uuid();
begin
  if s.id is null then raise exception 'E_UPLOAD_EXPIRED'; end if;
  if p_path not like s.shop_id::text || '/' || s.device_id::text || '/%' then raise exception 'E_PHOTO_PATH'; end if;
  if not exists (select 1 from storage.objects o where o.bucket_id = 'device-photos' and o.name = p_path) then raise exception 'E_NOT_FOUND'; end if;
  if exists (select 1 from public.device_photos p where p.storage_path = p_path) then
    return (select p.id from public.device_photos p where p.storage_path = p_path);
  end if;
  perform set_config('warsha.system', 'on', true);
  insert into public.device_photos(id, shop_id, device_id, storage_path, uploaded_by) values (pid, s.shop_id, s.device_id, p_path, s.created_by);
  perform set_config('warsha.system', 'off', true);
  return pid;
end $$;
revoke execute on function public.add_session_photo(text, text) from public;
grant execute on function public.add_session_photo(text, text) to anon, authenticated;

-- صفحة التتبع: مسارات صور الاستلام لصاحب رابط التتبع
create or replace function public.tracking_photos(p_token text) returns setof text
language sql stable security definer set search_path = public as $$
  select p.storage_path from public.devices d
  join public.shops sh on sh.id = d.shop_id and sh.deleted_at is null and sh.suspended_at is null
  join public.device_photos p on p.device_id = d.id and p.deleted_at is null
  where p_token is not null and length(p_token) >= 16 and d.tracking_token = p_token and d.deleted_at is null
  order by p.created_at limit 6
$$;
revoke execute on function public.tracking_photos(text) from public;
grant execute on function public.tracking_photos(text) to anon, authenticated;

create or replace function public.track_photo_allowed(p_name text) returns boolean
language plpgsql stable security definer set search_path = public as $$
declare tok text := nullif(current_setting('request.headers', true), '')::json ->> 'x-track-token';
begin
  if tok is null or length(tok) < 16 then return false; end if;
  return exists (select 1 from public.tracking_photos(tok) x where x = p_name);
exception when others then return false;
end $$;
revoke execute on function public.track_photo_allowed(text) from public;
grant execute on function public.track_photo_allowed(text) to anon, authenticated;

create policy device_photos_track_read on storage.objects for select to anon
  using (bucket_id = 'device-photos' and public.track_photo_allowed(name));
$m0044$;
  insert into public.app_migrations(version, how) values ('0044_capture.sql', 'applied');
  raise notice 'applied %', '0044_capture.sql';
end $run$;
commit;

-- ============================== 0045_checklists.sql ==============================
begin;
do $run$ begin
  if exists (select 1 from public.app_migrations where version = '0045_checklists.sql') then return; end if;
  execute $m0045$
-- 0045: C2: قوايم فحص لكل ماركة يعدّلها صاحب المحل، وتوقيع العميل وقت التسليم، وورقة فحص مطبوعة.
-- القالب الجاهز لكل ماركة في الكود (src/lib/checks.ts)، وصاحب المحل لو عدّل بيتحفظ هنا.
-- الفحص بيتحفظ زي ما هو (بند ← شغال/عطلان/مش متاح)، ومعاه أسماء البنود اللي كتبها صاحب المحل (labels)،
-- عشان الورقة المطبوعة القديمة تفضل زي ما هي حتى لو القالب اتغير بعدين.

create table public.check_templates (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references public.shops(id),
  brand text not null check (brand in ('general', 'apple', 'samsung', 'xiaomi', 'oppo', 'realme')),
  items jsonb not null check (jsonb_typeof(items) = 'array' and jsonb_array_length(items) between 1 and 40),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);
create unique index check_templates_brand on public.check_templates(shop_id, brand) where deleted_at is null;
alter table public.check_templates enable row level security;
create trigger set_updated_at before update on public.check_templates for each row execute function public.tg_set_updated_at();
create trigger block_delete before delete on public.check_templates for each row execute function public.tg_block_delete();
create trigger a_force_shop_id before insert or update on public.check_templates for each row execute function public.tg_force_shop_id();
create trigger zz_audit after insert or update on public.check_templates for each row execute function public.tg_audit();
-- القراية للمحل كله (اللي بيفحص محتاج القالب)، والتعديل لصاحب المحل بس
create policy check_templates_select on public.check_templates for select to authenticated using (shop_id = public.current_shop_id());
create policy check_templates_insert on public.check_templates for insert to authenticated with check (shop_id = public.current_shop_id() and public.current_app_role() = 'owner');
create policy check_templates_update on public.check_templates for update to authenticated using (shop_id = public.current_shop_id() and public.current_app_role() = 'owner');
grant select, insert, update on public.check_templates to authenticated;

-- أسماء البنود اللي كتبها صاحب المحل، محفوظة مع الفحص نفسه
alter table public.device_checks add column if not exists labels jsonb not null default '{}'::jsonb check (jsonb_typeof(labels) = 'object');

-- توقيع العميل وقت التسليم (صورة PNG صغيرة زي توقيع الاستلام). بيتكتب مرة واحدة وما بيتغيرش
alter table public.devices add column if not exists delivery_signature text
  check (delivery_signature is null or (delivery_signature like 'data:image/png;base64,%' and length(delivery_signature) < 300000));

create or replace function public.tg_delivery_signature() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if new.delivery_signature is not distinct from old.delivery_signature then return new; end if;
  if public.restoring() then return new; end if;
  -- مرة واحدة بس، ومع التسليم أو بعده، ومن الاستقبال أو صاحب المحل
  if old.delivery_signature is not null then raise exception 'E_RECEIPT_IMMUTABLE'; end if;
  if new.status <> 'delivered' then raise exception 'E_NOT_DELIVERED'; end if;
  if public.current_app_role() not in ('owner', 'reception') then raise exception 'E_FORBIDDEN'; end if;
  return new;
end $$;
create trigger zz_delivery_signature before update of delivery_signature on public.devices
  for each row execute function public.tg_delivery_signature();

-- النسخة الاحتياطية والاسترجاع: (src: 0039) + أهداف الفروع والطابعات وقوالب الطباعة (U3/U5، كانوا ناقصين) وقوالب الفحص
create or replace function public.backup_snapshot(p_shop uuid) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare
  res jsonb := jsonb_build_object('format', 'warsha-backup', 'version', 1, 'generated_at', now(), 'shop_id', p_shop);
  t text;
  rows jsonb;
begin
  foreach t in array array['shops', 'branches', 'staff_branches', 'shop_branding', 'profiles', 'customers', 'devices', 'device_costs', 'status_log', 'device_notes', 'device_photos', 'device_checks',
                           'quote_decisions', 'message_templates', 'message_log', 'accounts', 'journal_entries', 'journal_lines', 'payments', 'drawer_closings',
                           'suppliers', 'items', 'stock_moves', 'uncosted_sales', 'payment_plans', 'plan_installments', 'branch_goals', 'printers', 'print_templates', 'check_templates', 'purchases', 'labor_rates', 'specialties', 'staff_specialties', 'routes', 'repair_steps',
                           'repair_videos', 'device_ratings', 'issue_presets', 'partners', 'profit_distributions', 'party_links', 'shop_lists', 'audit_log'] loop
    execute format('select coalesce(jsonb_agg(to_jsonb(x)), ''[]''::jsonb) from public.%I x where x.shop_id = $1', t) into rows using p_shop;
    res := res || jsonb_build_object(t, rows);
  end loop;
  select coalesce(jsonb_agg(jsonb_build_object('device_id', device_id, 'kind', kind, 'erased_at', erased_at)), '[]'::jsonb)
    into rows from public.device_passcodes where shop_id = p_shop;
  return res || jsonb_build_object('device_passcodes', rows);
end $$;

-- restore_backup: (src: 0039_payment_plans.sql) + branch_goals وprinters وprint_templates وcheck_templates
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
                       'purchases', 'stock_moves', 'uncosted_sales', 'payment_plans', 'plan_installments', 'branch_goals', 'printers', 'print_templates', 'check_templates', 'drawer_closings', 'message_log', 'audit_log'];
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
$m0045$;
  insert into public.app_migrations(version, how) values ('0045_checklists.sql', 'applied');
  raise notice 'applied %', '0045_checklists.sql';
end $run$;
commit;

-- ============================== 0046_master.sql ==============================
begin;
do $run$ begin
  if exists (select 1 from public.app_migrations where version = '0046_master.sql') then return; end if;
  execute $m0046$
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
$m0046$;
  insert into public.app_migrations(version, how) values ('0046_master.sql', 'applied');
  raise notice 'applied %', '0046_master.sql';
end $run$;
commit;

-- ============================== 0047_mfa.sql ==============================
begin;
do $run$ begin
  if exists (select 1 from public.app_migrations where version = '0047_mfa.sql') then return; end if;
  execute $m0047$
-- 0047: C3: التحقق بخطوتين (2FA) لصاحب المحل، اختياري، بتطبيق زي Google Authenticator (TOTP مجاني جوه Supabase Auth).
-- الحماية في قاعدة البيانات: أي حساب فعّل 2FA ما يوصلش لبيانات المحل إلا لو الدخول عدّى الخطوة التانية (aal2).
-- يعني لو كلمة السر اتسرقت لوحدها، البيانات ما تتفتحش.

create or replace function public.mfa_ok() returns boolean
language sql stable security definer set search_path = public as $$
  select coalesce(auth.jwt() ->> 'aal', 'aal1') = 'aal2'
    or not exists (select 1 from auth.mfa_factors f where f.user_id = auth.uid() and f.status::text = 'verified')
$$;
revoke execute on function public.mfa_ok() from public, anon;
grant execute on function public.mfa_ok() to authenticated;

-- current_shop_id: (src: 0017_growth.sql) + 2FA
create or replace function public.current_shop_id() returns uuid
language sql stable security definer set search_path = public as $$
  select p.shop_id from public.profiles p join public.shops s on s.id = p.shop_id
  where p.id = auth.uid() and p.deleted_at is null and p.role::text <> 'marketing' and s.suspended_at is null and public.mfa_ok()
$$;
$m0047$;
  insert into public.app_migrations(version, how) values ('0047_mfa.sql', 'applied');
  raise notice 'applied %', '0047_mfa.sql';
end $run$;
commit;

-- ============================== 0048_used.sql ==============================
begin;
do $run$ begin
  if exists (select 1 from public.app_migrations where version = '0048_used.sql') then return; end if;
  execute $m0048$
-- 0048: C4: الأجهزة المستعملة: شراء وبيع بالـ IMEI، وبيانات البائع (لصاحب المحل بس)، وربح كل جهاز.
-- الجهاز المستعمل = صنف في المخزون نوعه 'used' وكميته 1 بتكلفته هو. فالشراء قيد متوازن (مخزون ← الخزنة)،
-- والبيع بـ record_sale نفسها (تكلفة البضاعة المباعة بتطلع لوحدها)، والربح = سعر البيع − سعر الشرا.
-- البيع من شاشة المستعمل بس (عشان سعر الجهاز يتسجل عليه)، وما ينفعش يتباع مرتين ولا يبقى رصيده أكتر من 1.
-- رقم البطاقة في Vault (مشفّر)، وصورة البطاقة في Storage خاص، والاتنين لصاحب المحل بس، وكل فتح بيتسجل.

alter table public.items drop constraint items_kind_check;
alter table public.items add constraint items_kind_check check (kind in ('part', 'accessory', 'used'));

create table public.used_devices (
  id uuid primary key,
  shop_id uuid not null references public.shops(id),
  branch_id uuid references public.branches(id),
  item_id uuid not null unique references public.items(id),
  imei text not null check (imei ~ '^[0-9]{14,17}$'),
  brand text not null check (length(trim(brand)) between 1 and 60),
  model text not null check (length(trim(model)) between 1 and 80),
  storage text check (storage is null or length(storage) <= 30),
  color text check (color is null or length(color) <= 30),
  condition text check (condition is null or length(condition) <= 500),
  buy_price bigint not null check (buy_price > 0 and buy_price <= 2000000000),
  buy_entry uuid not null references public.journal_entries(id),
  seller_name text not null check (length(trim(seller_name)) between 2 and 120),
  seller_phone text check (seller_phone is null or seller_phone ~ '^[0-9+]{7,16}$'),
  seller_nid_secret uuid,
  seller_photo text check (seller_photo is null or length(seller_photo) <= 300),
  sold_entry uuid references public.journal_entries(id),
  sold_price bigint check (sold_price is null or sold_price >= 0),
  sold_customer uuid references public.customers(id),
  sold_at timestamptz,
  created_by uuid references public.profiles(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);
create index used_devices_imei on public.used_devices(shop_id, imei);
alter table public.used_devices enable row level security;
create trigger set_updated_at before update on public.used_devices for each row execute function public.tg_set_updated_at();
create trigger block_delete before delete on public.used_devices for each row execute function public.tg_block_delete();
create trigger zz_audit after insert or update on public.used_devices for each row execute function public.tg_audit();
-- مفيش قراية مباشرة للجدول (فيه بيانات البائع): القايمة من used_devices_list والبيانات من seller_info

-- صنف مستعمل: الرصيد ما بيخرجش برا 0..1، والبيع من البيع العادي ممنوع (لازم من شاشة المستعمل)
create or replace function public.tg_used_stock() returns trigger
language plpgsql security definer set search_path = public as $$
declare k text; total bigint;
begin
  select kind into k from public.items where id = new.item_id;
  if k is distinct from 'used' then return new; end if;
  if new.qty < 0 and current_setting('app.uncosted', true) = 'on' and current_setting('app.used_sale', true) is distinct from 'on' then
    raise exception 'E_USED_SELL_HERE';
  end if;
  select coalesce(sum(qty), 0) into total from public.stock_moves where item_id = new.item_id;
  if total < 0 or total > 1 then raise exception 'E_STOCK'; end if;
  return new;
end $$;
create constraint trigger zz_used_stock after insert on public.stock_moves deferrable initially immediate
  for each row execute function public.tg_used_stock();

-- شراء جهاز مستعمل (اللي معاه صلاحية المشتريات)
create or replace function public.buy_used_device(p_id uuid, p_device jsonb, p_cashbox uuid, p_seller jsonb, p_note text default null)
returns uuid
language plpgsql security definer set search_path = public, extensions, pg_temp as $$
declare
  s uuid := public.current_shop_id();
  e uuid;
  it uuid := gen_random_uuid();
  v_imei text := regexp_replace(coalesce(p_device ->> 'imei', ''), '[^0-9]', '', 'g');
  cost bigint := (p_device ->> 'buy_price')::bigint;
  ask bigint := nullif(p_device ->> 'sale_price', '')::bigint;
  nid text := nullif(regexp_replace(coalesce(p_seller ->> 'nid', ''), '[^0-9]', '', 'g'), '');
  sec uuid;
  b uuid;
begin
  perform public.grant_require('purchases', 'add');
  e := public.ledger_idem(p_id);
  if e is not null then return e; end if;
  if length(v_imei) not between 14 and 17 then raise exception 'E_BAD_IMEI'; end if;
  if cost is null or cost <= 0 then raise exception 'E_BAD_AMOUNT'; end if;
  if ask is not null and (ask < 0 or ask > 2000000000) then raise exception 'E_BAD_AMOUNT'; end if;
  if nid is not null and length(nid) <> 14 then raise exception 'E_BAD_NID'; end if;
  if nullif(trim(p_seller ->> 'name'), '') is null then raise exception 'E_BAD_INPUT'; end if;
  -- نفس الجهاز لسه في المخزون؟
  if exists (select 1 from public.used_devices u join public.stock_moves m on m.item_id = u.item_id
             where u.shop_id = s and u.imei = v_imei and u.deleted_at is null group by u.id having sum(m.qty) > 0) then
    raise exception 'E_USED_IN_STOCK';
  end if;
  perform public.ledger_amount(cost);
  insert into public.items(id, shop_id, kind, name, sku, sale_price)
  values (it, s, 'used', left(trim(p_device ->> 'brand') || ' ' || trim(p_device ->> 'model') || ' · ' || right(v_imei, 4), 160), v_imei, ask);
  e := public.ledger_post('purchase', p_id, p_note, jsonb_build_array(
    public.ledger_line(public.ledger_acc('inventory'), cost, 0),
    public.ledger_line((public.ledger_cashbox(p_cashbox)).id, 0, cost)), null, p_id);
  select branch_id into b from public.journal_entries where id = e;
  insert into public.stock_moves(shop_id, item_id, entry_id, qty, value, branch_id) values (s, it, e, 1, cost, b);
  if nid is not null then sec := vault.create_secret(nid, 'used-seller-' || p_id::text, 'رقم بطاقة بائع جهاز مستعمل'); end if;
  insert into public.used_devices(id, shop_id, branch_id, item_id, imei, brand, model, storage, color, condition, buy_price, buy_entry,
                                  seller_name, seller_phone, seller_nid_secret, created_by)
  values (p_id, s, b, it, v_imei, trim(p_device ->> 'brand'), trim(p_device ->> 'model'), nullif(trim(p_device ->> 'storage'), ''), nullif(trim(p_device ->> 'color'), ''),
          nullif(trim(p_device ->> 'condition'), ''), cost, e, trim(p_seller ->> 'name'), nullif(regexp_replace(coalesce(p_seller ->> 'phone', ''), '[^0-9+]', '', 'g'), ''), sec, auth.uid());
  return e;
end $$;
revoke execute on function public.buy_used_device(uuid, jsonb, uuid, jsonb, text) from public, anon;
grant execute on function public.buy_used_device(uuid, jsonb, uuid, jsonb, text) to authenticated;

-- بيع جهاز مستعمل (من شاشة المستعمل): نفس البيع العادي بسطر واحد، وسعره بيتسجل على الجهاز
create or replace function public.sell_used_device(p_id uuid, p_used uuid, p_price bigint, p_cashbox uuid default null, p_customer uuid default null, p_note text default null)
returns uuid
language plpgsql security definer set search_path = public as $$
declare u public.used_devices; e uuid;
begin
  select * into u from public.used_devices where id = p_used and shop_id = public.current_shop_id() and deleted_at is null for update;
  if not found then raise exception 'E_NOT_FOUND'; end if;
  e := public.ledger_idem(p_id);
  if e is not null then return e; end if;
  perform set_config('app.used_sale', 'on', true);
  e := public.record_sale(p_id, jsonb_build_array(jsonb_build_object('item', u.item_id, 'qty', 1, 'price', p_price)), p_cashbox, p_customer, p_note);
  perform set_config('app.used_sale', 'off', true);
  update public.used_devices set sold_entry = e, sold_price = p_price, sold_customer = p_customer, sold_at = now() where id = u.id;
  return e;
end $$;
revoke execute on function public.sell_used_device(uuid, uuid, bigint, uuid, uuid, text) from public, anon;
grant execute on function public.sell_used_device(uuid, uuid, bigint, uuid, uuid, text) to authenticated;

-- القايمة: الحالة من المخزون والقيود (مش متخزّنة)، والربح لصاحب المحل واللي معاه "مبالغ المخزون"
create or replace function public.used_devices_list()
returns table(id uuid, item_id uuid, imei text, brand text, model text, storage text, color text, condition text, branch_id uuid,
              status text, bought_at timestamptz, buy_price bigint, sale_price integer, sold_price bigint, sold_at timestamptz, profit bigint, has_seller_id boolean)
language plpgsql stable security definer set search_path = public as $$
declare amounts boolean := public.current_app_role() = 'owner' or public.has_perm('inventory', 'amounts');
begin
  if public.current_app_role() is null or public.current_app_role() = 'technician' then raise exception 'E_FORBIDDEN'; end if;
  return query
  select u.id, u.item_id, u.imei, u.brand, u.model, u.storage, u.color, u.condition, u.branch_id,
    case when q.qty > 0 then 'in_stock'
         when u.sold_entry is not null and not exists (select 1 from public.journal_entries r where r.reverses_id = u.sold_entry) then 'sold'
         else 'cancelled' end,
    u.created_at,
    case when amounts then u.buy_price end,
    i.sale_price,
    u.sold_price,
    u.sold_at,
    case when amounts and u.sold_price is not null and q.qty = 0 and not exists (select 1 from public.journal_entries r where r.reverses_id = u.sold_entry) then u.sold_price - u.buy_price end,
    u.seller_nid_secret is not null or u.seller_photo is not null
  from public.used_devices u
  join public.items i on i.id = u.item_id
  cross join lateral (select coalesce(sum(m.qty), 0)::bigint qty from public.stock_moves m where m.item_id = u.item_id) q
  where u.shop_id = public.current_shop_id() and u.deleted_at is null and (public.all_my_branches() or public.can_branch(u.branch_id))
  order by u.created_at desc;
end $$;
revoke execute on function public.used_devices_list() from public, anon;
grant execute on function public.used_devices_list() to authenticated;

-- بيانات البائع: صاحب المحل بس، وكل فتح بيتسجل في سجل النشاط
create or replace function public.seller_info(p_used uuid)
returns table(seller_name text, seller_phone text, nid text, photo text)
language plpgsql security definer set search_path = public as $$
declare u public.used_devices;
begin
  perform public.ledger_require(array['owner']::public.app_role[]);
  select * into u from public.used_devices where id = p_used and shop_id = public.current_shop_id() and deleted_at is null;
  if not found then raise exception 'E_NOT_FOUND'; end if;
  insert into public.audit_log(shop_id, actor_id, action, entity, entity_id, after)
  values (u.shop_id, auth.uid(), 'seller_viewed', 'used_devices', u.id, '{}'::jsonb);
  return query select u.seller_name, u.seller_phone,
    (select d.decrypted_secret::text from vault.decrypted_secrets d where d.id = u.seller_nid_secret), u.seller_photo;
end $$;
revoke execute on function public.seller_info(uuid) from public, anon;
grant execute on function public.seller_info(uuid) to authenticated;

-- صورة البطاقة: مسار في Storage تحت فولدر الجهاز، واللي اشترى الجهاز أو صاحب المحل بيسجلها مرة واحدة
create or replace function public.set_seller_photo(p_used uuid, p_path text) returns void
language plpgsql security definer set search_path = public as $$
declare u public.used_devices;
begin
  select * into u from public.used_devices where id = p_used and shop_id = public.current_shop_id() and deleted_at is null for update;
  if not found then raise exception 'E_NOT_FOUND'; end if;
  if u.created_by is distinct from auth.uid() and public.current_app_role() <> 'owner' then raise exception 'E_FORBIDDEN'; end if;
  if u.seller_photo is not null then raise exception 'E_RECEIPT_IMMUTABLE'; end if;
  if p_path not like u.shop_id::text || '/' || u.id::text || '/%' then raise exception 'E_PHOTO_PATH'; end if;
  update public.used_devices set seller_photo = p_path where id = u.id;
end $$;
revoke execute on function public.set_seller_photo(uuid, text) from public, anon;
grant execute on function public.set_seller_photo(uuid, text) to authenticated;

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('seller-ids', 'seller-ids', false, 5242880, array['image/jpeg', 'image/png', 'image/webp'])
on conflict (id) do nothing;
-- الرفع: اللي بيشتري (صلاحية المشتريات) جوه فولدر المحل. القراية: صاحب المحل بس
create policy seller_ids_upload on storage.objects for insert to authenticated
  with check (bucket_id = 'seller-ids' and (storage.foldername(name))[1] = public.current_shop_id()::text and public.has_perm('purchases', 'add'));
create policy seller_ids_read on storage.objects for select to authenticated
  using (bucket_id = 'seller-ids' and (storage.foldername(name))[1] = public.current_shop_id()::text and public.current_app_role() = 'owner');

-- النسخة الاحتياطية والاسترجاع: (src: 0045) + used_devices (من غير رقم البطاقة وصورتها)
create or replace function public.backup_snapshot(p_shop uuid) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare
  res jsonb := jsonb_build_object('format', 'warsha-backup', 'version', 1, 'generated_at', now(), 'shop_id', p_shop);
  t text;
  rows jsonb;
begin
  foreach t in array array['shops', 'branches', 'staff_branches', 'shop_branding', 'profiles', 'customers', 'devices', 'device_costs', 'status_log', 'device_notes', 'device_photos', 'device_checks',
                           'quote_decisions', 'message_templates', 'message_log', 'accounts', 'journal_entries', 'journal_lines', 'payments', 'drawer_closings',
                           'suppliers', 'items', 'stock_moves', 'uncosted_sales', 'payment_plans', 'plan_installments', 'branch_goals', 'printers', 'print_templates', 'check_templates', 'used_devices', 'purchases', 'labor_rates', 'specialties', 'staff_specialties', 'routes', 'repair_steps',
                           'repair_videos', 'device_ratings', 'issue_presets', 'partners', 'profit_distributions', 'party_links', 'shop_lists', 'audit_log'] loop
    execute format('select coalesce(jsonb_agg(to_jsonb(x)), ''[]''::jsonb) from public.%I x where x.shop_id = $1', t) into rows using p_shop;
    res := res || jsonb_build_object(t, rows);
  end loop;
  select coalesce(jsonb_agg(jsonb_build_object('device_id', device_id, 'kind', kind, 'erased_at', erased_at)), '[]'::jsonb)
    into rows from public.device_passcodes where shop_id = p_shop;
  return res || jsonb_build_object('device_passcodes', rows);
end $$;

-- restore_backup: (src: 0045_checklists.sql) + used_devices
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
$m0048$;
  insert into public.app_migrations(version, how) values ('0048_used.sql', 'applied');
  raise notice 'applied %', '0048_used.sql';
end $run$;
commit;

-- ============================== 0049_commissions.sql ==============================
begin;
do $run$ begin
  if exists (select 1 from public.app_migrations where version = '0049_commissions.sql') then return; end if;
  execute $m0049$
-- 0049: C5: عمولات الفنيين (كانت مؤجلة وصاحب المشروع طلبها بالاسم يوم 2026-11-15)، والمكافآت والجزاءات.
-- قاعدة العمولة: نسبة من المصنعية (التكلفة النهائية − تكلفة القطع) أو مبلغ ثابت لكل إصلاح، لكل فني أو لكل نوع عطل (المسار).
-- العمولة بتتقيّد لوحدها وقت التسليم: مصروف المرتبات ← مستحقات الموظفين (باسم الفني)، فبتظهر في كشف حساب الفني وبتتصرف بـ "صرف مرتب".
-- لو الجهاز اشتغل عليه أكتر من فني: كل فني بياخد عمولته (النسبة بتتقسم على عددهم، والثابت كامل لكل واحد).
-- المكافأة والجزاء قيود برضه (الجزاء بيقلل المستحق). كله أعداد صحيحة بالقروش، والنسبة بـ basis points (10000 = 100%).

alter table public.journal_entries drop constraint if exists journal_entries_source_type_check;
alter table public.journal_entries add constraint journal_entries_source_type_check check (source_type = any (array[
  'payment', 'delivery', 'purchase', 'supplier_payment', 'part_use', 'sale', 'expense', 'salary', 'salary_payment', 'advance', 'advance_settle',
  'capital', 'drawing', 'transfer', 'drawer_close', 'reversal', 'cost_adjust', 'write_off', 'supplier_return', 'sale_return', 'opening',
  'partner_capital', 'partner_withdrawal', 'profit_distribution', 'netting', 'stock_transfer', 'commission', 'bonus', 'penalty']));

create table public.commission_rules (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references public.shops(id),
  technician_id uuid references public.profiles(id),
  route_id uuid references public.routes(id),
  mode text not null check (mode in ('percent', 'fixed')),
  value bigint not null check ((mode = 'percent' and value between 1 and 10000) or (mode = 'fixed' and value between 1 and 2000000000)),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);
-- قاعدة واحدة شغالة لكل (فني، نوع عطل)
create unique index commission_rules_one on public.commission_rules(shop_id, coalesce(technician_id, '00000000-0000-0000-0000-000000000000'::uuid), coalesce(route_id, '00000000-0000-0000-0000-000000000000'::uuid)) where deleted_at is null;
alter table public.commission_rules enable row level security;
create trigger set_updated_at before update on public.commission_rules for each row execute function public.tg_set_updated_at();
create trigger block_delete before delete on public.commission_rules for each row execute function public.tg_block_delete();
create trigger a_force_shop_id before insert or update on public.commission_rules for each row execute function public.tg_force_shop_id();
create trigger zz_audit after insert or update on public.commission_rules for each row execute function public.tg_audit();
-- صاحب المحل بس (القواعد فيها نسب فلوس)
create policy commission_rules_select on public.commission_rules for select to authenticated using (shop_id = public.current_shop_id() and public.current_app_role() = 'owner');
create policy commission_rules_insert on public.commission_rules for insert to authenticated with check (shop_id = public.current_shop_id() and public.current_app_role() = 'owner');
create policy commission_rules_update on public.commission_rules for update to authenticated using (shop_id = public.current_shop_id() and public.current_app_role() = 'owner');
grant select, insert, update on public.commission_rules to authenticated;

-- الفنيين اللي اشتغلوا على الجهاز: خطوات المسار اللي خلصت، وإلا آخر فني غيّر حالته
create or replace function public.device_technicians(p_device uuid) returns uuid[]
language sql stable security definer set search_path = public as $$
  select coalesce(
    (select array_agg(distinct s.technician_id order by s.technician_id) from public.repair_steps s
      where s.device_id = p_device and s.status = 'done' and s.technician_id is not null and s.deleted_at is null),
    (select array[l.changed_by] from public.status_log l join public.profiles p on p.id = l.changed_by
      where l.device_id = p_device and p.role = 'technician' order by l.created_at desc limit 1),
    array[]::uuid[])
$$;
revoke execute on function public.device_technicians(uuid) from public, anon, authenticated;

-- أنسب قاعدة: الفني + نوع العطل، ثم الفني، ثم نوع العطل، ثم العامة
create or replace function public.commission_rule_for(p_shop uuid, p_tech uuid, p_route uuid) returns public.commission_rules
language sql stable security definer set search_path = public as $$
  select r.* from public.commission_rules r
  where r.shop_id = p_shop and r.deleted_at is null
    and (r.technician_id is null or r.technician_id = p_tech) and (r.route_id is null or r.route_id = p_route)
  order by (r.technician_id is not null) desc, (r.route_id is not null) desc limit 1
$$;
revoke execute on function public.commission_rule_for(uuid, uuid, uuid) from public, anon, authenticated;

-- تكلفة القطع اللي اتركبت في الجهاز (بعد أي عكس)
create or replace function public.device_parts_cost(p_device uuid) returns bigint
language sql stable security definer set search_path = public as $$
  select coalesce(-sum(m.value), 0)::bigint from public.stock_moves m join public.journal_entries e on e.id = m.entry_id
  where e.device_id = p_device and e.source_type in ('part_use', 'reversal')
$$;
revoke execute on function public.device_parts_cost(uuid) from public, anon, authenticated;

-- حساب العمولات لجهاز (من غير تسجيل): لكل فني المبلغ
create or replace function public.commission_preview(p_device uuid) returns table(technician_id uuid, amount bigint)
language plpgsql stable security definer set search_path = public as $$
declare d public.devices; techs uuid[]; n int; base bigint; r public.commission_rules; t uuid; share bigint;
begin
  select * into d from public.devices where id = p_device;
  if d.id is null then return; end if;
  techs := public.device_technicians(p_device);
  n := coalesce(array_length(techs, 1), 0);
  if n = 0 then return; end if;
  base := greatest(coalesce((select c.final_cost from public.device_costs c where c.device_id = p_device and c.deleted_at is null), 0) - public.device_parts_cost(p_device), 0);
  foreach t in array techs loop
    r := public.commission_rule_for(d.shop_id, t, d.route_id);
    continue when r.id is null;
    share := case when r.mode = 'fixed' then r.value else (base / n) * r.value / 10000 end;
    if share > 0 then technician_id := t; amount := share; return next; end if;
  end loop;
end $$;
revoke execute on function public.commission_preview(uuid) from public, anon, authenticated;

-- وقت التسليم: قيد عمولة لكل فني (مرة واحدة لكل جهاز وفني)
create or replace function public.tg_commission() returns trigger
language plpgsql security definer set search_path = public as $$
declare x record; k uuid;
begin
  if public.restoring() then return new; end if;
  if new.status <> 'delivered' or old.status = 'delivered' then return new; end if;
  for x in select * from public.commission_preview(new.id) loop
    k := md5(new.id::text || ':' || x.technician_id::text || ':commission')::uuid;
    continue when exists (select 1 from public.journal_entries j where j.idem_key = k);
    perform public.ledger_post('commission', new.id, new.order_no, jsonb_build_array(
      public.ledger_line(public.ledger_acc('exp_salaries'), x.amount, 0),
      public.ledger_line(public.ledger_acc('salaries_payable'), 0, x.amount, 'employee', x.technician_id)), new.id, k);
  end loop;
  return new;
end $$;
create trigger zz_commission after update of status on public.devices for each row execute function public.tg_commission();

-- مكافأة وجزاء (صاحب المحل)
create or replace function public.staff_bonus(p_id uuid, p_employee uuid, p_amount bigint, p_note text default null) returns uuid
language plpgsql security definer set search_path = public as $$
declare e uuid;
begin
  perform public.ledger_require(array['owner']::public.app_role[]);
  e := public.ledger_idem(p_id);
  if e is not null then return e; end if;
  perform public.ledger_amount(p_amount);
  perform public.ledger_employee(p_employee);
  return public.ledger_post('bonus', p_id, p_note, jsonb_build_array(
    public.ledger_line(public.ledger_acc('exp_salaries'), p_amount, 0),
    public.ledger_line(public.ledger_acc('salaries_payable'), 0, p_amount, 'employee', p_employee)), null, p_id);
end $$;
create or replace function public.staff_penalty(p_id uuid, p_employee uuid, p_amount bigint, p_note text default null) returns uuid
language plpgsql security definer set search_path = public as $$
declare e uuid;
begin
  perform public.ledger_require(array['owner']::public.app_role[]);
  e := public.ledger_idem(p_id);
  if e is not null then return e; end if;
  if nullif(trim(p_note), '') is null then raise exception 'E_REASON_REQUIRED'; end if;
  perform public.ledger_amount(p_amount);
  perform public.ledger_employee(p_employee);
  return public.ledger_post('penalty', p_id, p_note, jsonb_build_array(
    public.ledger_line(public.ledger_acc('salaries_payable'), p_amount, 0, 'employee', p_employee),
    public.ledger_line(public.ledger_acc('exp_salaries'), 0, p_amount)), null, p_id);
end $$;
revoke execute on function public.staff_bonus(uuid, uuid, bigint, text), public.staff_penalty(uuid, uuid, bigint, text) from public, anon;
grant execute on function public.staff_bonus(uuid, uuid, bigint, text), public.staff_penalty(uuid, uuid, bigint, text) to authenticated;

-- تقرير العمولات لكل فني في الفترة (من القيود، مش متخزّن): الأجهزة، والعمولات، والمكافآت، والجزاءات، والمصروف، والرصيد الحالي
create or replace function public.commissions_report(p_from timestamptz, p_to timestamptz)
returns table(technician_id uuid, full_name text, devices bigint, commission bigint, bonus bigint, penalty bigint, paid bigint, balance bigint)
language plpgsql stable security definer set search_path = public as $$
begin
  perform public.ledger_require(array['owner']::public.app_role[]);
  return query
  with l as (
    select jl.party_id pid, e.source_type st, e.reverses_id, e.id eid, e.device_id dev, e.occurred_at occ, jl.debit, jl.credit
    from public.journal_lines jl join public.journal_entries e on e.id = jl.entry_id join public.accounts a on a.id = jl.account_id
    where jl.shop_id = public.current_shop_id() and a.code = 'salaries_payable' and jl.party_type = 'employee'
  ), rev as (
    -- العكس بيتحسب على نوع القيد الأصلي
    select l.*, coalesce(o.source_type, l.st) kind from l left join public.journal_entries o on o.id = l.reverses_id
  )
  select p.id, p.full_name,
    (select count(distinct r.dev) from rev r where r.pid = p.id and r.kind = 'commission' and r.reverses_id is null and r.occ >= p_from and r.occ < p_to)::bigint,
    coalesce(sum(case when r.kind = 'commission' and r.occ >= p_from and r.occ < p_to then r.credit - r.debit end), 0)::bigint,
    coalesce(sum(case when r.kind = 'bonus' and r.occ >= p_from and r.occ < p_to then r.credit - r.debit end), 0)::bigint,
    coalesce(sum(case when r.kind = 'penalty' and r.occ >= p_from and r.occ < p_to then r.debit - r.credit end), 0)::bigint,
    coalesce(sum(case when r.kind = 'salary_payment' and r.occ >= p_from and r.occ < p_to then r.debit - r.credit end), 0)::bigint,
    coalesce(sum(r.credit - r.debit), 0)::bigint
  from public.profiles p
  left join rev r on r.pid = p.id
  where p.shop_id = public.current_shop_id() and p.role = 'technician'
  group by p.id, p.full_name
  order by 4 desc, p.full_name;
end $$;
revoke execute on function public.commissions_report(timestamptz, timestamptz) from public, anon;
grant execute on function public.commissions_report(timestamptz, timestamptz) to authenticated;

-- النسخة الاحتياطية والاسترجاع: (src: 0048) + commission_rules
create or replace function public.backup_snapshot(p_shop uuid) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare
  res jsonb := jsonb_build_object('format', 'warsha-backup', 'version', 1, 'generated_at', now(), 'shop_id', p_shop);
  t text;
  rows jsonb;
begin
  foreach t in array array['shops', 'branches', 'staff_branches', 'shop_branding', 'profiles', 'customers', 'devices', 'device_costs', 'status_log', 'device_notes', 'device_photos', 'device_checks',
                           'quote_decisions', 'message_templates', 'message_log', 'accounts', 'journal_entries', 'journal_lines', 'payments', 'drawer_closings',
                           'suppliers', 'items', 'stock_moves', 'uncosted_sales', 'payment_plans', 'plan_installments', 'branch_goals', 'printers', 'print_templates', 'check_templates', 'used_devices', 'commission_rules', 'purchases', 'labor_rates', 'specialties', 'staff_specialties', 'routes', 'repair_steps',
                           'repair_videos', 'device_ratings', 'issue_presets', 'partners', 'profit_distributions', 'party_links', 'shop_lists', 'audit_log'] loop
    execute format('select coalesce(jsonb_agg(to_jsonb(x)), ''[]''::jsonb) from public.%I x where x.shop_id = $1', t) into rows using p_shop;
    res := res || jsonb_build_object(t, rows);
  end loop;
  select coalesce(jsonb_agg(jsonb_build_object('device_id', device_id, 'kind', kind, 'erased_at', erased_at)), '[]'::jsonb)
    into rows from public.device_passcodes where shop_id = p_shop;
  return res || jsonb_build_object('device_passcodes', rows);
end $$;

-- restore_backup: (src: 0048_used.sql) + commission_rules
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
                       'issue_presets', 'commission_rules', 'shop_lists', 'message_templates', 'items', 'devices', 'device_costs', 'status_log', 'device_notes', 'device_checks',
                       'quote_decisions', 'repair_steps', 'repair_videos', 'device_ratings', 'journal_entries', 'journal_lines', 'profit_distributions', 'payments',
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
$m0049$;
  insert into public.app_migrations(version, how) values ('0049_commissions.sql', 'applied');
  raise notice 'applied %', '0049_commissions.sql';
end $run$;
commit;

-- ============================== 0050_insights.sql ==============================
begin;
do $run$ begin
  if exists (select 1 from public.app_migrations where version = '0050_insights.sql') then return; end if;
  execute $m0050$
-- 0050: C6: تحليلات إضافية: أكتر الأعطال لكل موديل، والقطع اللي بتاكل الربح، والصرف لتوقع نفاد المخزون.
-- (متوسط وقت الإصلاح لكل فني موجود أصلًا في tech_report.) كله محسوب من البيانات والقيود، ومن غير بيانات عملاء.

-- أكتر الأعطال لكل موديل: نوع العطل (المسار) لو متحدد، وإلا وصف العطل زي ما اتكتب
create or replace function public.faults_by_model(p_from timestamptz, p_to timestamptz, p_branch uuid default null)
returns table(brand text, model text, route_code text, route_name text, issue text, devices integer, returns integer)
language plpgsql stable security definer set search_path = public as $$
#variable_conflict use_column
begin
  perform public.grant_require('reports', 'view');
  return query
  select d.brand, d.model, r.code, r.name,
    case when d.route_id is null then lower(trim(left(d.issue, 80))) end,
    count(*)::int,
    count(*) filter (where d.priority = 'warranty' or d.return_of_tech is not null)::int
  from public.devices d left join public.routes r on r.id = d.route_id
  where d.shop_id = public.current_shop_id() and d.deleted_at is null and d.received_at >= p_from and d.received_at < p_to
    and (p_branch is null or d.branch_id = p_branch) and (public.all_my_branches() or public.can_branch(d.branch_id))
  group by d.brand, d.model, r.code, r.name, case when d.route_id is null then lower(trim(left(d.issue, 80))) end
  order by 6 desc, 1, 2 limit 40;
end $$;
revoke execute on function public.faults_by_model(timestamptz, timestamptz, uuid) from public, anon;
grant execute on function public.faults_by_model(timestamptz, timestamptz, uuid) to authenticated;

-- القطع اللي بتاكل الربح: لكل قطعة اتركبت في أجهزة اتسلّمت في الفترة: تكلفتها، وإيراد الأجهزة دي، ونسبتها (صاحب المحل)
create or replace function public.parts_profit(p_from timestamptz, p_to timestamptz)
returns table(item_id uuid, name text, uses bigint, devices bigint, cost bigint, revenue bigint)
language plpgsql stable security definer set search_path = public as $$
#variable_conflict use_column
begin
  perform public.ledger_require(array['owner']::public.app_role[]);
  return query
  with used as (
    select m.item_id, e.device_id, (-m.qty)::bigint q, (-m.value)::bigint v
    from public.stock_moves m join public.journal_entries e on e.id = m.entry_id
    join public.devices d on d.id = e.device_id
    where e.shop_id = public.current_shop_id() and e.source_type = 'part_use' and m.qty < 0
      and not exists (select 1 from public.journal_entries x where x.reverses_id = e.id)
      and d.status = 'delivered' and d.delivered_at >= p_from and d.delivered_at < p_to and d.deleted_at is null
  ), per as (
    select u.item_id, sum(u.q)::bigint uses, count(distinct u.device_id)::bigint devs, sum(u.v)::bigint cost from used u group by u.item_id
  )
  select p.item_id, i.name, p.uses, p.devs, p.cost,
    (select coalesce(sum(c.final_cost), 0)::bigint from public.device_costs c
      where c.deleted_at is null and c.device_id in (select distinct u.device_id from used u where u.item_id = p.item_id))
  from per p join public.items i on i.id = p.item_id
  order by p.cost desc limit 30;
end $$;
revoke execute on function public.parts_profit(timestamptz, timestamptz) from public, anon;
grant execute on function public.parts_profit(timestamptz, timestamptz) to authenticated;

-- الصرف الفعلي في آخر 30 يوم (بيع + قطع اتركبت، من غير التحويلات بين الفروع والهالك والمعكوس)
create or replace function public.items_usage30() returns table(item_id uuid, used bigint)
language plpgsql stable security definer set search_path = public as $$
#variable_conflict use_column
begin
  perform public.grant_require('reports', 'view', true);
  return query
  select m.item_id, (-sum(m.qty))::bigint
  from public.stock_moves m join public.journal_entries e on e.id = m.entry_id
  where e.shop_id = public.current_shop_id() and m.qty < 0 and e.source_type in ('sale', 'part_use')
    and e.occurred_at >= now() - interval '30 days'
    and not exists (select 1 from public.journal_entries r where r.reverses_id = e.id)
  group by m.item_id;
end $$;
revoke execute on function public.items_usage30() from public, anon;
grant execute on function public.items_usage30() to authenticated;
$m0050$;
  insert into public.app_migrations(version, how) values ('0050_insights.sql', 'applied');
  raise notice 'applied %', '0050_insights.sql';
end $run$;
commit;

-- ============================== 0051_demo.sql ==============================
begin;
do $run$ begin
  if exists (select 1 from public.app_migrations where version = '0051_demo.sql') then return; end if;
  execute $m0051$
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
$m0051$;
  insert into public.app_migrations(version, how) values ('0051_demo.sql', 'applied');
  raise notice 'applied %', '0051_demo.sql';
end $run$;
commit;

-- ============================== 0052_catalog.sql ==============================
begin;
do $run$ begin
  if exists (select 1 from public.app_migrations where version = '0052_catalog.sql') then return; end if;
  execute $m0052$
-- 0052: C8: كتالوج أونلاين من المخزون (إكسسوارات وقطع وأجهزة مستعملة)، برابط عام يتشارك على واتساب وفيسبوك.
-- صاحب المحل بيفتحه (token عشوائي 128 bit) وبيختار الأصناف اللي تظهر. الكتالوج بيعرض الاسم والسعر و"متوفر" بس:
-- من غير تكلفة ولا كميات ولا IMEI ولا أي بيانات عملاء. القفل بيلغي الرابط القديم.

alter table public.shops add column if not exists catalog_token text unique check (catalog_token is null or length(catalog_token) = 32);
alter table public.items add column if not exists in_catalog boolean not null default false;

-- فتح وقفل الكتالوج (صاحب المحل): بيرجّع الـ token الجديد أو null
create or replace function public.set_catalog(p_on boolean) returns text
language plpgsql security definer set search_path = public, extensions, pg_temp as $$
declare s uuid := public.current_shop_id(); t text := case when p_on then encode(gen_random_bytes(16), 'hex') end;
begin
  perform public.ledger_require(array['owner']::public.app_role[]);
  perform set_config('warsha.system', 'on', true);
  update public.shops set catalog_token = t where id = s;
  perform set_config('warsha.system', 'off', true);
  return t;
end $$;
revoke execute on function public.set_catalog(boolean) from public, anon;
grant execute on function public.set_catalog(boolean) to authenticated;

create or replace function public.catalog_shop(p_token text) returns uuid
language sql stable security definer set search_path = public as $$
  select s.id from public.shops s where p_token is not null and length(p_token) = 32 and s.catalog_token = p_token and s.deleted_at is null and s.suspended_at is null
$$;
revoke execute on function public.catalog_shop(text) from public, anon, authenticated;

-- الكتالوج للزائر: المحل (الاسم والتليفون واللوجو الملون) والأصناف المختارة
create or replace function public.public_catalog(p_token text) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare s uuid := public.catalog_shop(p_token);
begin
  if s is null then return null; end if;
  return jsonb_build_object(
    'shop', (select jsonb_build_object('name', sh.name, 'phone', sh.phone, 'currency', sh.currency,
               'logo', (select b.logo_color from public.shop_branding b where b.shop_id = sh.id and b.deleted_at is null)) from public.shops sh where sh.id = s),
    'items', coalesce((
      select jsonb_agg(x order by x->>'kind', x->>'name') from (
        select jsonb_build_object('id', i.id, 'name', i.name, 'kind', i.kind, 'price', i.sale_price, 'image', i.image_path,
                 'in_stock', coalesce((select sum(m.qty) from public.stock_moves m where m.item_id = i.id), 0) > 0,
                 'details', case when i.kind = 'used' then (select jsonb_build_object('brand', u.brand, 'model', u.model, 'storage', u.storage, 'color', u.color, 'condition', u.condition)
                                                             from public.used_devices u where u.item_id = i.id) end) x
        from public.items i
        where i.shop_id = s and i.in_catalog and i.deleted_at is null and i.sale_price is not null
          -- المستعمل اللي اتباع ما بيظهرش
          and (i.kind <> 'used' or coalesce((select sum(m.qty) from public.stock_moves m where m.item_id = i.id), 0) > 0)
        limit 500) q), '[]'::jsonb));
end $$;
revoke execute on function public.public_catalog(text) from public;
grant execute on function public.public_catalog(text) to anon, authenticated;

-- صور الأصناف في الكتالوج: لصاحب رابط الكتالوج بس، وللأصناف المختارة بس (header x-catalog-token)
create or replace function public.catalog_image_allowed(p_name text) returns boolean
language plpgsql stable security definer set search_path = public as $$
declare tok text := nullif(current_setting('request.headers', true), '')::json ->> 'x-catalog-token'; s uuid;
begin
  s := public.catalog_shop(tok);
  if s is null then return false; end if;
  return exists (select 1 from public.items i where i.shop_id = s and i.in_catalog and i.deleted_at is null and i.image_path = p_name);
exception when others then return false;
end $$;
revoke execute on function public.catalog_image_allowed(text) from public;
grant execute on function public.catalog_image_allowed(text) to anon, authenticated;
create policy item_images_catalog_read on storage.objects for select to anon
  using (bucket_id = 'item-images' and public.catalog_image_allowed(name));
$m0052$;
  insert into public.app_migrations(version, how) values ('0052_catalog.sql', 'applied');
  raise notice 'applied %', '0052_catalog.sql';
end $run$;
commit;

-- ============================== 0053_portal.sql ==============================
begin;
do $run$ begin
  if exists (select 1 from public.app_migrations where version = '0053_portal.sql') then return; end if;
  execute $m0053$
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
$m0053$;
  insert into public.app_migrations(version, how) values ('0053_portal.sql', 'applied');
  raise notice 'applied %', '0053_portal.sql';
end $run$;
commit;

-- ============================== 0054_telegram.sql ==============================
begin;
do $run$ begin
  if exists (select 1 from public.app_migrations where version = '0054_telegram.sql') then return; end if;
  execute $m0054$
-- 0054: C8: إشعارات تيليجرام لصاحب المحل (مجانية واختيارية)، جنب إشعارات البرنامج.
-- صاحب المحل بيعمل بوت من @BotFather (مجاني) ويكتب الـ token ورقم المحادثة. الـ token متخزّن مشفّر في Vault وما بيرجعش للشاشة أبدًا.
-- الرسايل فيها رقم الطلب والموديل والحالة والمبلغ بس، من غير اسم العميل ولا تليفونه (تيليجرام خدمة برا المحل).
-- الإرسال من قاعدة البيانات بـ pg_net (مجاني في Supabase): بيتبعت بعد ما العملية تتحفظ، ولو العملية اتلغت ما بيتبعتش.

-- (في Supabase: Database ← Extensions ← pg_net. لو مش متاحة، الإشعارات بس اللي مش هتشتغل)
do $$ begin
  if exists (select 1 from pg_available_extensions where name = 'pg_net') then
    create extension if not exists pg_net with schema extensions;
  end if;
end $$;

create table public.shop_telegram (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null unique references public.shops(id),
  chat_id text not null check (chat_id ~ '^(-?[0-9]{5,16}|@[A-Za-z0-9_]{5,32})$'),
  token_secret uuid not null,
  events text[] not null default array['intake', 'ready', 'delivered']::text[]
    check (events <@ array['intake', 'ready', 'delivered', 'payment']::text[]),
  enabled boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);
alter table public.shop_telegram enable row level security;
create trigger set_updated_at before update on public.shop_telegram for each row execute function public.tg_set_updated_at();
create trigger block_delete before delete on public.shop_telegram for each row execute function public.tg_block_delete();
-- مفيش سياسات: من الدوال بس (فيه مرجع للـ token)

create or replace function public.set_telegram(p_token text, p_chat text, p_events text[]) returns void
language plpgsql security definer set search_path = public as $$
declare s uuid := public.current_shop_id(); cur public.shop_telegram; tok text := nullif(trim(p_token), ''); sec uuid;
begin
  perform public.ledger_require(array['owner']::public.app_role[]);
  select * into cur from public.shop_telegram where shop_id = s;
  if tok is not null and tok !~ '^[0-9]{5,12}:[A-Za-z0-9_-]{30,64}$' then raise exception 'E_BAD_TOKEN'; end if;
  if tok is null and cur.id is null then raise exception 'E_BAD_TOKEN'; end if;
  if tok is not null then
    if cur.id is null then sec := vault.create_secret(tok, 'telegram-' || s::text, 'Telegram bot token');
    else perform vault.update_secret(cur.token_secret, tok); sec := cur.token_secret; end if;
  else sec := cur.token_secret; end if;
  insert into public.shop_telegram(shop_id, chat_id, token_secret, events, enabled)
  values (s, trim(p_chat), sec, coalesce(p_events, array['intake', 'ready', 'delivered']), true)
  on conflict (shop_id) do update set chat_id = excluded.chat_id, token_secret = excluded.token_secret, events = excluded.events, enabled = true, deleted_at = null;
  insert into public.audit_log(shop_id, actor_id, action, entity, entity_id, after)
  values (s, auth.uid(), 'telegram_set', 'shop_telegram', s, jsonb_build_object('events', p_events));
end $$;
create or replace function public.disable_telegram() returns void
language plpgsql security definer set search_path = public as $$
begin
  perform public.ledger_require(array['owner']::public.app_role[]);
  update public.shop_telegram set enabled = false where shop_id = public.current_shop_id();
end $$;
-- الحالة من غير الـ token
create or replace function public.telegram_status() returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare t public.shop_telegram;
begin
  perform public.ledger_require(array['owner']::public.app_role[]);
  select * into t from public.shop_telegram where shop_id = public.current_shop_id() and deleted_at is null;
  if t.id is null then return jsonb_build_object('configured', false); end if;
  return jsonb_build_object('configured', true, 'enabled', t.enabled, 'chat', t.chat_id, 'events', to_jsonb(t.events));
end $$;
revoke execute on function public.set_telegram(text, text, text[]), public.disable_telegram(), public.telegram_status() from public, anon;
grant execute on function public.set_telegram(text, text, text[]), public.disable_telegram(), public.telegram_status() to authenticated;

-- الإرسال (داخلي)
create or replace function public.telegram_send(p_shop uuid, p_event text, p_text text) returns bigint
language plpgsql security definer set search_path = public, extensions, pg_temp as $$
declare t public.shop_telegram; tok text;
begin
  select * into t from public.shop_telegram where shop_id = p_shop and enabled and deleted_at is null;
  if t.id is null or not (p_event = 'test' or p_event = any (t.events)) then return null; end if;
  select d.decrypted_secret into tok from vault.decrypted_secrets d where d.id = t.token_secret;
  if tok is null then return null; end if;
  return net.http_post(
    url := 'https://api.telegram.org/bot' || tok || '/sendMessage',
    body := jsonb_build_object('chat_id', t.chat_id, 'text', left(p_text, 3500), 'disable_web_page_preview', true),
    headers := '{"Content-Type": "application/json"}'::jsonb);
exception when others then
  -- الإشعار ما يوقفش الشغل أبدًا
  return null;
end $$;
revoke execute on function public.telegram_send(uuid, text, text) from public, anon, authenticated;

create or replace function public.telegram_test() returns boolean
language plpgsql security definer set search_path = public as $$
begin
  perform public.ledger_require(array['owner']::public.app_role[]);
  return public.telegram_send(public.current_shop_id(), 'test', 'جوالك: رسالة تجربة. الإشعارات شغالة.') is not null;
end $$;
revoke execute on function public.telegram_test() from public, anon;
grant execute on function public.telegram_test() to authenticated;

-- الأحداث: استلام جهاز، وجاهز، واتسلّم (من غير بيانات العميل)
create or replace function public.tg_telegram_device() returns trigger
language plpgsql security definer set search_path = public as $$
declare ev text; txt text; amt bigint;
begin
  if public.restoring() then return new; end if;
  if not exists (select 1 from public.shop_telegram t where t.shop_id = new.shop_id and t.enabled) then return new; end if;
  if tg_op = 'INSERT' then
    ev := 'intake'; txt := 'جهاز جديد ' || coalesce(new.order_no, '') || ': ' || new.brand || ' ' || new.model || ' (' || left(coalesce(new.issue, ''), 80) || ')';
  elsif new.status is distinct from old.status and new.status = 'ready' then
    ev := 'ready'; txt := 'جاهز للتسليم ' || coalesce(new.order_no, '') || ': ' || new.brand || ' ' || new.model;
  elsif new.status is distinct from old.status and new.status = 'delivered' then
    select c.final_cost into amt from public.device_costs c where c.device_id = new.id and c.deleted_at is null;
    ev := 'delivered'; txt := 'اتسلّم ' || coalesce(new.order_no, '') || ': ' || new.brand || ' ' || new.model || coalesce(' · ' || to_char(amt / 100.0, 'FM999,999,990.00'), '');
  else
    return new;
  end if;
  perform public.telegram_send(new.shop_id, ev, txt);
  return new;
end $$;
create trigger zz_telegram after insert or update of status on public.devices for each row execute function public.tg_telegram_device();
$m0054$;
  insert into public.app_migrations(version, how) values ('0054_telegram.sql', 'applied');
  raise notice 'applied %', '0054_telegram.sql';
end $run$;
commit;

-- ============================== 0055_eta_placeholder.sql ==============================
begin;
do $run$ begin
  if exists (select 1 from public.app_migrations where version = '0055_eta_placeholder.sql') then return; end if;
  execute $m0055$
-- 0055: مكان الفاتورة الإلكترونية لمصلحة الضرائب (ETA) في قاعدة البيانات بس (قرار صاحب المشروع: مش دلوقتي).
-- مفيش أي إرسال ولا شاشة. لما ييجي وقتها: المطلوب مكتوب في PROGRESS.md (التسجيل في المنظومة، وشهادة التوقيع،
-- وClient ID/Secret في أسرار Supabase مش هنا، وأكواد الأصناف GS1/EGS).

create table public.eta_settings (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null unique references public.shops(id),
  taxpayer_id text check (taxpayer_id is null or taxpayer_id ~ '^[0-9]{9}$'),
  activity_code text check (activity_code is null or activity_code ~ '^[0-9]{4}$'),
  branch_code text check (branch_code is null or length(branch_code) <= 20),
  environment text not null default 'preprod' check (environment in ('preprod', 'prod')),
  enabled boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);
alter table public.eta_settings enable row level security;
create trigger set_updated_at before update on public.eta_settings for each row execute function public.tg_set_updated_at();
create trigger block_delete before delete on public.eta_settings for each row execute function public.tg_block_delete();
create trigger a_force_shop_id before insert or update on public.eta_settings for each row execute function public.tg_force_shop_id();
create policy eta_settings_owner on public.eta_settings for all to authenticated
  using (shop_id = public.current_shop_id() and public.current_app_role() = 'owner')
  with check (shop_id = public.current_shop_id() and public.current_app_role() = 'owner');
grant select, insert, update on public.eta_settings to authenticated;

-- كود الصنف في المنظومة (GS1 أو EGS)، وحالة إرسال كل فاتورة بعدين
alter table public.items add column if not exists eta_code text check (eta_code is null or length(eta_code) <= 40);

create table public.eta_documents (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references public.shops(id),
  entry_id uuid not null references public.journal_entries(id),
  uuid_eta text,
  status text not null default 'draft' check (status in ('draft', 'submitted', 'valid', 'invalid', 'cancelled')),
  response jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);
alter table public.eta_documents enable row level security;
create trigger set_updated_at before update on public.eta_documents for each row execute function public.tg_set_updated_at();
create trigger block_delete before delete on public.eta_documents for each row execute function public.tg_block_delete();
create policy eta_documents_owner on public.eta_documents for select to authenticated
  using (shop_id = public.current_shop_id() and public.current_app_role() = 'owner');
grant select on public.eta_documents to authenticated;
$m0055$;
  insert into public.app_migrations(version, how) values ('0055_eta_placeholder.sql', 'applied');
  raise notice 'applied %', '0055_eta_placeholder.sql';
end $run$;
commit;

-- ============================== 0056_branch_features.sql ==============================
begin;
do $run$ begin
  if exists (select 1 from public.app_migrations where version = '0056_branch_features.sql') then return; end if;
  execute $m0056$
-- 0056: الميزات الجديدة (C1-C8) بالفروع: كل فرع ليه بياناته وحساباته، وعرض "كل الفروع" المجمّع لصاحب المحل،
-- والموظف ما بيشوفش غير فرعه. لو المحل فرع واحد، كل ده بيشتغل على الفرع الرئيسي من غير ما يبان.
-- (الصور وسجل الـ IMEI والفحص تبع الجهاز، والجهاز أصلًا معزول بالفرع من 0034.)

-- ========== الأجهزة المستعملة ==========
-- البيع في فرع الجهاز نفسه، وبخزنة من نفس الفرع
create or replace function public.sell_used_device(p_id uuid, p_used uuid, p_price bigint, p_cashbox uuid default null, p_customer uuid default null, p_note text default null)
returns uuid
language plpgsql security definer set search_path = public as $$
declare u public.used_devices; e uuid; cb uuid;
begin
  select * into u from public.used_devices where id = p_used and shop_id = public.current_shop_id() and deleted_at is null for update;
  if not found then raise exception 'E_NOT_FOUND'; end if;
  if not public.can_branch(u.branch_id) then raise exception 'E_FORBIDDEN'; end if;
  e := public.ledger_idem(p_id);
  if e is not null then return e; end if;
  if p_cashbox is not null then
    select branch_id into cb from public.accounts where id = p_cashbox and shop_id = u.shop_id;
    if cb is distinct from u.branch_id then raise exception 'E_BAD_BRANCH'; end if;
  end if;
  perform set_config('app.branch', u.branch_id::text, true);
  perform set_config('app.used_sale', 'on', true);
  e := public.record_sale(p_id, jsonb_build_array(jsonb_build_object('item', u.item_id, 'qty', 1, 'price', p_price)), p_cashbox, p_customer, p_note);
  perform set_config('app.used_sale', 'off', true);
  update public.used_devices set sold_entry = e, sold_price = p_price, sold_customer = p_customer, sold_at = now() where id = u.id;
  return e;
end $$;

drop function if exists public.used_devices_list();
create or replace function public.used_devices_list(p_branch uuid default null)
returns table(id uuid, item_id uuid, imei text, brand text, model text, storage text, color text, condition text, branch_id uuid,
              status text, bought_at timestamptz, buy_price bigint, sale_price integer, sold_price bigint, sold_at timestamptz, profit bigint, has_seller_id boolean)
language plpgsql stable security definer set search_path = public as $$
declare amounts boolean := public.current_app_role() = 'owner' or public.has_perm('inventory', 'amounts');
begin
  if public.current_app_role() is null or public.current_app_role() = 'technician' then raise exception 'E_FORBIDDEN'; end if;
  return query
  select u.id, u.item_id, u.imei, u.brand, u.model, u.storage, u.color, u.condition, u.branch_id,
    case when q.qty > 0 then 'in_stock'
         when u.sold_entry is not null and not exists (select 1 from public.journal_entries r where r.reverses_id = u.sold_entry) then 'sold'
         else 'cancelled' end,
    u.created_at,
    case when amounts then u.buy_price end,
    i.sale_price,
    u.sold_price,
    u.sold_at,
    case when amounts and u.sold_price is not null and q.qty = 0 and not exists (select 1 from public.journal_entries r where r.reverses_id = u.sold_entry) then u.sold_price - u.buy_price end,
    u.seller_nid_secret is not null or u.seller_photo is not null
  from public.used_devices u
  join public.items i on i.id = u.item_id
  cross join lateral (select coalesce(sum(m.qty), 0)::bigint qty from public.stock_moves m where m.item_id = u.item_id) q
  where u.shop_id = public.current_shop_id() and u.deleted_at is null
    and (public.all_my_branches() or public.can_branch(u.branch_id))
    and (p_branch is null or u.branch_id = p_branch)
  order by u.created_at desc;
end $$;
revoke execute on function public.used_devices_list(uuid) from public, anon;
grant execute on function public.used_devices_list(uuid) to authenticated;

-- ========== العمولات ==========
-- قاعدة لفرع معيّن (اختياري)
alter table public.commission_rules add column if not exists branch_id uuid references public.branches(id);
drop index if exists public.commission_rules_one;
create unique index commission_rules_one on public.commission_rules(shop_id,
  coalesce(technician_id, '00000000-0000-0000-0000-000000000000'::uuid), coalesce(route_id, '00000000-0000-0000-0000-000000000000'::uuid),
  coalesce(branch_id, '00000000-0000-0000-0000-000000000000'::uuid)) where deleted_at is null;

drop function if exists public.commission_rule_for(uuid, uuid, uuid);
create or replace function public.commission_rule_for(p_shop uuid, p_tech uuid, p_route uuid, p_branch uuid) returns public.commission_rules
language sql stable security definer set search_path = public as $$
  select r.* from public.commission_rules r
  where r.shop_id = p_shop and r.deleted_at is null
    and (r.technician_id is null or r.technician_id = p_tech) and (r.route_id is null or r.route_id = p_route)
    and (r.branch_id is null or r.branch_id = p_branch)
  order by (r.technician_id is not null) desc, (r.route_id is not null) desc, (r.branch_id is not null) desc limit 1
$$;
revoke execute on function public.commission_rule_for(uuid, uuid, uuid, uuid) from public, anon, authenticated;

create or replace function public.commission_preview(p_device uuid) returns table(technician_id uuid, amount bigint)
language plpgsql stable security definer set search_path = public as $$
declare d public.devices; techs uuid[]; n int; base bigint; r public.commission_rules; t uuid; share bigint;
begin
  select * into d from public.devices where id = p_device;
  if d.id is null then return; end if;
  techs := public.device_technicians(p_device);
  n := coalesce(array_length(techs, 1), 0);
  if n = 0 then return; end if;
  base := greatest(coalesce((select c.final_cost from public.device_costs c where c.device_id = p_device and c.deleted_at is null), 0) - public.device_parts_cost(p_device), 0);
  foreach t in array techs loop
    r := public.commission_rule_for(d.shop_id, t, d.route_id, d.branch_id);
    continue when r.id is null;
    share := case when r.mode = 'fixed' then r.value else (base / n) * r.value / 10000 end;
    if share > 0 then technician_id := t; amount := share; return next; end if;
  end loop;
end $$;

-- العمولة بتتقيّد في فرع الجهاز
create or replace function public.tg_commission() returns trigger
language plpgsql security definer set search_path = public as $$
declare x record; k uuid;
begin
  if public.restoring() then return new; end if;
  if new.status <> 'delivered' or old.status = 'delivered' then return new; end if;
  for x in select * from public.commission_preview(new.id) loop
    k := md5(new.id::text || ':' || x.technician_id::text || ':commission')::uuid;
    continue when exists (select 1 from public.journal_entries j where j.idem_key = k);
    perform set_config('app.branch', new.branch_id::text, true);
    perform public.ledger_post('commission', new.id, new.order_no, jsonb_build_array(
      public.ledger_line(public.ledger_acc('exp_salaries'), x.amount, 0),
      public.ledger_line(public.ledger_acc('salaries_payable'), 0, x.amount, 'employee', x.technician_id)), new.id, k);
  end loop;
  return new;
end $$;

drop function if exists public.commissions_report(timestamptz, timestamptz);
create or replace function public.commissions_report(p_from timestamptz, p_to timestamptz, p_branch uuid default null)
returns table(technician_id uuid, full_name text, devices bigint, commission bigint, bonus bigint, penalty bigint, paid bigint, balance bigint)
language plpgsql stable security definer set search_path = public as $$
begin
  perform public.ledger_require(array['owner']::public.app_role[]);
  return query
  with l as (
    select jl.party_id pid, e.source_type st, e.reverses_id, e.id eid, e.device_id dev, e.occurred_at occ, jl.debit, jl.credit
    from public.journal_lines jl join public.journal_entries e on e.id = jl.entry_id join public.accounts a on a.id = jl.account_id
    where jl.shop_id = public.current_shop_id() and a.code = 'salaries_payable' and jl.party_type = 'employee'
      and (p_branch is null or e.branch_id = p_branch)
  ), rev as (
    select l.*, coalesce(o.source_type, l.st) kind from l left join public.journal_entries o on o.id = l.reverses_id
  )
  select p.id, p.full_name,
    (select count(distinct r.dev) from rev r where r.pid = p.id and r.kind = 'commission' and r.reverses_id is null and r.occ >= p_from and r.occ < p_to)::bigint,
    coalesce(sum(case when r.kind = 'commission' and r.occ >= p_from and r.occ < p_to then r.credit - r.debit end), 0)::bigint,
    coalesce(sum(case when r.kind = 'bonus' and r.occ >= p_from and r.occ < p_to then r.credit - r.debit end), 0)::bigint,
    coalesce(sum(case when r.kind = 'penalty' and r.occ >= p_from and r.occ < p_to then r.debit - r.credit end), 0)::bigint,
    coalesce(sum(case when r.kind = 'salary_payment' and r.occ >= p_from and r.occ < p_to then r.debit - r.credit end), 0)::bigint,
    coalesce(sum(r.credit - r.debit), 0)::bigint
  from public.profiles p
  left join rev r on r.pid = p.id
  where p.shop_id = public.current_shop_id() and p.role = 'technician'
  group by p.id, p.full_name
  order by 4 desc, p.full_name;
end $$;
revoke execute on function public.commissions_report(timestamptz, timestamptz, uuid) from public, anon;
grant execute on function public.commissions_report(timestamptz, timestamptz, uuid) to authenticated;

-- ========== قوايم الفحص: قالب للفرع بيكسب قالب المحل ==========
alter table public.check_templates add column if not exists branch_id uuid references public.branches(id);
drop index if exists public.check_templates_brand;
create unique index check_templates_brand on public.check_templates(shop_id, brand, coalesce(branch_id, '00000000-0000-0000-0000-000000000000'::uuid)) where deleted_at is null;

-- ========== الكتالوج: رابط لكل فرع (التوفر من مخزون الفرع) + رابط كل الفروع ==========
alter table public.branches add column if not exists catalog_token text unique check (catalog_token is null or length(catalog_token) = 32);

drop function if exists public.set_catalog(boolean);
create or replace function public.set_catalog(p_on boolean, p_branch uuid default null) returns text
language plpgsql security definer set search_path = public, extensions, pg_temp as $$
declare s uuid := public.current_shop_id(); t text := case when p_on then encode(gen_random_bytes(16), 'hex') end;
begin
  perform public.ledger_require(array['owner']::public.app_role[]);
  if p_branch is null then
    perform set_config('warsha.system', 'on', true);
    update public.shops set catalog_token = t where id = s;
    perform set_config('warsha.system', 'off', true);
  else
    if not exists (select 1 from public.branches where id = p_branch and shop_id = s and deleted_at is null) then raise exception 'E_BAD_BRANCH'; end if;
    update public.branches set catalog_token = t where id = p_branch;
  end if;
  return t;
end $$;
revoke execute on function public.set_catalog(boolean, uuid) from public, anon;
grant execute on function public.set_catalog(boolean, uuid) to authenticated;

-- المحل والفرع (null = كل الفروع) من الـ token
create or replace function public.catalog_target(p_token text) returns table(shop_id uuid, branch_id uuid)
language sql stable security definer set search_path = public as $$
  select s.id, null::uuid from public.shops s
   where p_token is not null and length(p_token) = 32 and s.catalog_token = p_token and s.deleted_at is null and s.suspended_at is null
  union all
  select s.id, b.id from public.branches b join public.shops s on s.id = b.shop_id
   where p_token is not null and length(p_token) = 32 and b.catalog_token = p_token and b.deleted_at is null and s.deleted_at is null and s.suspended_at is null
  limit 1
$$;
revoke execute on function public.catalog_target(text) from public, anon, authenticated;

create or replace function public.catalog_shop(p_token text) returns uuid
language sql stable security definer set search_path = public as $$
  select shop_id from public.catalog_target(p_token)
$$;

create or replace function public.public_catalog(p_token text) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare s uuid; b uuid; multi boolean;
begin
  select shop_id, branch_id into s, b from public.catalog_target(p_token);
  if s is null then return null; end if;
  multi := (select count(*) from public.branches x where x.shop_id = s and x.deleted_at is null) > 1;
  return jsonb_build_object(
    'shop', (select jsonb_build_object(
               'name', sh.name,
               -- فرع معيّن: اسمه وتليفونه (لو المحل فروع)
               'branch', case when b is not null and multi then (select br.name from public.branches br where br.id = b) end,
               'phone', coalesce(case when b is not null then (select nullif(br.phone, '') from public.branches br where br.id = b) end, sh.phone),
               'currency', sh.currency,
               'logo', (select x.logo_color from public.shop_branding x where x.shop_id = sh.id and x.deleted_at is null)) from public.shops sh where sh.id = s),
    'items', coalesce((
      select jsonb_agg(x order by x->>'kind', x->>'name') from (
        select jsonb_build_object('id', i.id, 'name', i.name, 'kind', i.kind, 'price', i.sale_price, 'image', i.image_path,
                 'in_stock', coalesce((select sum(m.qty) from public.stock_moves m where m.item_id = i.id and (b is null or m.branch_id = b)), 0) > 0,
                 'details', case when i.kind = 'used' then (select jsonb_build_object('brand', u.brand, 'model', u.model, 'storage', u.storage, 'color', u.color, 'condition', u.condition)
                                                             from public.used_devices u where u.item_id = i.id) end) x
        from public.items i
        where i.shop_id = s and i.in_catalog and i.deleted_at is null and i.sale_price is not null
          and (i.kind <> 'used' or coalesce((select sum(m.qty) from public.stock_moves m where m.item_id = i.id and (b is null or m.branch_id = b)), 0) > 0)
        limit 500) q), '[]'::jsonb));
end $$;

-- ========== بوابة الجملة: البوابة ممكن تبقى لفرع (كشف حساب الفرع وطلبياته) ==========
alter table public.customers add column if not exists portal_branch uuid references public.branches(id);
alter table public.wholesale_orders add column if not exists branch_id uuid references public.branches(id);

drop function if exists public.set_portal(uuid, boolean);
create or replace function public.set_portal(p_customer uuid, p_on boolean, p_branch uuid default null) returns text
language plpgsql security definer set search_path = public, extensions, pg_temp as $$
declare s uuid := public.current_shop_id(); t text := case when p_on then encode(gen_random_bytes(16), 'hex') end; b uuid := p_branch;
begin
  perform public.ledger_require(array['owner', 'reception']::public.app_role[]);
  perform public.perm_require('customers', 'edit');
  if not exists (select 1 from public.customers where id = p_customer and shop_id = s and deleted_at is null) then raise exception 'E_NOT_FOUND'; end if;
  -- الموظف اللي مش معاه كل الفروع: البوابة لفرعه هو بس
  if not public.all_my_branches() then b := public.op_branch(); end if;
  if b is not null and not exists (select 1 from public.branches where id = b and shop_id = s and deleted_at is null) then raise exception 'E_BAD_BRANCH'; end if;
  update public.customers set portal_token = t, portal_branch = case when p_on then b end where id = p_customer;
  return t;
end $$;
revoke execute on function public.set_portal(uuid, boolean, uuid) from public, anon;
grant execute on function public.set_portal(uuid, boolean, uuid) to authenticated;

create or replace function public.public_portal(p_token text) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare c public.customers := public.portal_customer(p_token); b uuid; multi boolean;
begin
  if c.id is null then return null; end if;
  b := c.portal_branch;
  multi := (select count(*) from public.branches x where x.shop_id = c.shop_id and x.deleted_at is null) > 1;
  return jsonb_build_object(
    'shop', (select jsonb_build_object('name', sh.name, 'currency', sh.currency,
               'branch', case when b is not null and multi then (select br.name from public.branches br where br.id = b) end,
               'phone', coalesce(case when b is not null then (select nullif(br.phone, '') from public.branches br where br.id = b) end, sh.phone),
               'logo', (select x.logo_color from public.shop_branding x where x.shop_id = sh.id and x.deleted_at is null)) from public.shops sh where sh.id = c.shop_id),
    'customer', jsonb_build_object('name', c.name),
    'balance', (select coalesce(sum(l.debit - l.credit), 0)::bigint from public.journal_lines l join public.accounts a on a.id = l.account_id join public.journal_entries e on e.id = l.entry_id
                where l.shop_id = c.shop_id and l.party_type = 'customer' and l.party_id = c.id and a.kind = 'receivable' and (b is null or e.branch_id = b)),
    'entries', coalesce((select jsonb_agg(x order by x->>'at' desc) from (
        select jsonb_build_object('at', e.occurred_at, 'type', e.source_type, 'no', e.entry_no, 'debit', sum(l.debit), 'credit', sum(l.credit)) x
        from public.journal_lines l join public.journal_entries e on e.id = l.entry_id join public.accounts a on a.id = l.account_id
        where l.shop_id = c.shop_id and l.party_type = 'customer' and l.party_id = c.id and a.kind = 'receivable' and (b is null or e.branch_id = b)
        group by e.id order by e.occurred_at desc limit 100) q), '[]'::jsonb),
    'orders', coalesce((select jsonb_agg(jsonb_build_object('id', o.id, 'at', o.created_at, 'status', o.status, 'lines', o.lines, 'note', o.note) order by o.created_at desc)
                        from (select * from public.wholesale_orders w where w.customer_id = c.id and w.deleted_at is null and (b is null or w.branch_id = b) order by w.created_at desc limit 20) o), '[]'::jsonb),
    'items', coalesce((select jsonb_agg(jsonb_build_object('id', i.id, 'name', i.name, 'price', i.sale_price) order by i.name)
                       from public.items i where i.shop_id = c.shop_id and i.in_catalog and i.deleted_at is null and i.kind <> 'used' and i.sale_price is not null), '[]'::jsonb));
end $$;

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
  insert into public.wholesale_orders(id, shop_id, customer_id, branch_id, lines, note) values (id, c.shop_id, c.id, c.portal_branch, out, nullif(trim(left(p_note, 500)), ''));
  perform set_config('warsha.system', 'off', true);
  return id;
exception when invalid_text_representation then raise exception 'E_BAD_INPUT';
end $$;

-- الطلبيات: الموظف بيشوف طلبيات فرعه بس (وطلبيات "كل الفروع" لصاحب كل الفروع)
drop policy if exists wholesale_orders_select on public.wholesale_orders;
drop policy if exists wholesale_orders_update on public.wholesale_orders;
create policy wholesale_orders_select on public.wholesale_orders for select to authenticated
  using (shop_id = public.current_shop_id() and public.current_app_role() in ('owner', 'reception')
         and (public.all_my_branches() or public.can_branch(branch_id)));
create policy wholesale_orders_update on public.wholesale_orders for update to authenticated
  using (shop_id = public.current_shop_id() and public.current_app_role() in ('owner', 'reception')
         and (public.all_my_branches() or public.can_branch(branch_id)));

-- ========== التحليلات بالفرع ==========
drop function if exists public.parts_profit(timestamptz, timestamptz);
create or replace function public.parts_profit(p_from timestamptz, p_to timestamptz, p_branch uuid default null)
returns table(item_id uuid, name text, uses bigint, devices bigint, cost bigint, revenue bigint)
language plpgsql stable security definer set search_path = public as $$
#variable_conflict use_column
begin
  perform public.ledger_require(array['owner']::public.app_role[]);
  return query
  with used as (
    select m.item_id, e.device_id, (-m.qty)::bigint q, (-m.value)::bigint v
    from public.stock_moves m join public.journal_entries e on e.id = m.entry_id
    join public.devices d on d.id = e.device_id
    where e.shop_id = public.current_shop_id() and e.source_type = 'part_use' and m.qty < 0
      and not exists (select 1 from public.journal_entries x where x.reverses_id = e.id)
      and d.status = 'delivered' and d.delivered_at >= p_from and d.delivered_at < p_to and d.deleted_at is null
      and (p_branch is null or d.branch_id = p_branch)
  ), per as (
    select u.item_id, sum(u.q)::bigint uses, count(distinct u.device_id)::bigint devs, sum(u.v)::bigint cost from used u group by u.item_id
  )
  select p.item_id, i.name, p.uses, p.devs, p.cost,
    (select coalesce(sum(c.final_cost), 0)::bigint from public.device_costs c
      where c.deleted_at is null and c.device_id in (select distinct u.device_id from used u where u.item_id = p.item_id))
  from per p join public.items i on i.id = p.item_id
  order by p.cost desc limit 30;
end $$;
revoke execute on function public.parts_profit(timestamptz, timestamptz, uuid) from public, anon;
grant execute on function public.parts_profit(timestamptz, timestamptz, uuid) to authenticated;

drop function if exists public.items_usage30();
create or replace function public.items_usage30(p_branch uuid default null) returns table(item_id uuid, used bigint)
language plpgsql stable security definer set search_path = public as $$
#variable_conflict use_column
begin
  perform public.grant_require('reports', 'view');
  return query
  select m.item_id, (-sum(m.qty))::bigint
  from public.stock_moves m join public.journal_entries e on e.id = m.entry_id
  where e.shop_id = public.current_shop_id() and m.qty < 0 and e.source_type in ('sale', 'part_use')
    and e.occurred_at >= now() - interval '30 days'
    and not exists (select 1 from public.journal_entries r where r.reverses_id = e.id)
    and (public.all_my_branches() or public.can_branch(m.branch_id))
    and (p_branch is null or m.branch_id = p_branch)
  group by m.item_id;
end $$;
revoke execute on function public.items_usage30(uuid) from public, anon;
grant execute on function public.items_usage30(uuid) to authenticated;

-- ========== تيليجرام: اسم الفرع في الرسالة لو المحل فروع ==========
create or replace function public.tg_telegram_device() returns trigger
language plpgsql security definer set search_path = public as $$
declare ev text; txt text; amt bigint; br text;
begin
  if public.restoring() then return new; end if;
  if not exists (select 1 from public.shop_telegram t where t.shop_id = new.shop_id and t.enabled) then return new; end if;
  if (select count(*) from public.branches x where x.shop_id = new.shop_id and x.deleted_at is null) > 1 then
    select ' [' || b.name || ']' into br from public.branches b where b.id = new.branch_id;
  end if;
  if tg_op = 'INSERT' then
    ev := 'intake'; txt := 'جهاز جديد ' || coalesce(new.order_no, '') || ': ' || new.brand || ' ' || new.model || ' (' || left(coalesce(new.issue, ''), 80) || ')';
  elsif new.status is distinct from old.status and new.status = 'ready' then
    ev := 'ready'; txt := 'جاهز للتسليم ' || coalesce(new.order_no, '') || ': ' || new.brand || ' ' || new.model;
  elsif new.status is distinct from old.status and new.status = 'delivered' then
    select c.final_cost into amt from public.device_costs c where c.device_id = new.id and c.deleted_at is null;
    ev := 'delivered'; txt := 'اتسلّم ' || coalesce(new.order_no, '') || ': ' || new.brand || ' ' || new.model || coalesce(' · ' || to_char(amt / 100.0, 'FM999,999,990.00'), '');
  else
    return new;
  end if;
  perform public.telegram_send(new.shop_id, ev, txt || coalesce(br, ''));
  return new;
end $$;
$m0056$;
  insert into public.app_migrations(version, how) values ('0056_branch_features.sql', 'applied');
  raise notice 'applied %', '0056_branch_features.sql';
end $run$;
commit;

-- ============================== 0057_categories.sql ==============================
begin;
do $run$ begin
  if exists (select 1 from public.app_migrations where version = '0057_categories.sql') then return; end if;
  execute $m0057$
-- 0057: K: تصفح التصنيفات (طلب صاحب المشروع بفيديو 2026-11-16، بتصميم البرنامج نفسه من غير نسخ):
-- تصنيفات بمستويين (رئيسي وفرعي) في قسمين: المنتجات والخدمات، لكل تصنيف أيقونة من أيقونات البرنامج وترتيب.
-- كل صنف ممكن يتربط بتصنيف (items.category_id)، والتصنيفات النصية القديمة بتتحول لوحدها لتصنيفات (من غير ما حاجة تضيع)،
-- والنص القديم بيفضل متزامن عشان الفلاتر والتقارير القديمة.
-- الخدمات (فحص، تنظيف، سوفت وير، نقل بيانات...) = صنف نوعه 'service': بيتباع من غير مخزون ولا تكلفة، وإيراده "إيراد الصيانة".

create table public.categories (
  id uuid primary key,
  shop_id uuid not null references public.shops(id),
  parent_id uuid references public.categories(id),
  section text not null default 'products' check (section in ('products', 'services')),
  name text not null check (length(trim(name)) between 1 and 60),
  icon text check (icon is null or icon ~ '^[a-z0-9_]{1,30}$'),
  sort integer not null default 100,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);
create index categories_shop on public.categories(shop_id, parent_id) where deleted_at is null;
create unique index categories_name on public.categories(shop_id, coalesce(parent_id, '00000000-0000-0000-0000-000000000000'::uuid), lower(trim(name))) where deleted_at is null;
alter table public.categories enable row level security;
create trigger set_updated_at before update on public.categories for each row execute function public.tg_set_updated_at();
create trigger block_delete before delete on public.categories for each row execute function public.tg_block_delete();
create trigger a_force_shop_id before insert or update on public.categories for each row execute function public.tg_force_shop_id();
create trigger zz_audit after insert or update on public.categories for each row execute function public.tg_audit();
create policy categories_select on public.categories for select to authenticated using (shop_id = public.current_shop_id());
-- إضافة وتعديل التصنيفات: صاحب المحل، واللي معاه "إضافة صنف جديد"
create policy categories_insert on public.categories for insert to authenticated
  with check (shop_id = public.current_shop_id() and (public.current_app_role() = 'owner' or public.has_perm('item_create', 'add')));
create policy categories_update on public.categories for update to authenticated
  using (shop_id = public.current_shop_id() and (public.current_app_role() = 'owner' or public.has_perm('item_create', 'add')));
grant select, insert, update on public.categories to authenticated;

-- مستويين بس، والفرعي في نفس قسم الرئيسي ونفس المحل
create or replace function public.tg_category_tree() returns trigger
language plpgsql security definer set search_path = public as $$
declare p public.categories;
begin
  if new.parent_id is null then return new; end if;
  if new.parent_id = new.id then raise exception 'E_BAD_INPUT'; end if;
  select * into p from public.categories where id = new.parent_id;
  if p.id is null or p.shop_id <> new.shop_id or p.deleted_at is not null then raise exception 'E_NOT_FOUND'; end if;
  if p.parent_id is not null then raise exception 'E_CATEGORY_DEPTH'; end if;
  new.section := p.section;
  return new;
end $$;
create trigger b_category_tree before insert or update on public.categories for each row execute function public.tg_category_tree();

-- التصنيف اللي فيه أصناف أو تصنيفات فرعية ما بيتأرشفش (انقل اللي فيه الأول)
create or replace function public.tg_category_archive() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if new.deleted_at is not null and old.deleted_at is null then
    if exists (select 1 from public.categories c where c.parent_id = new.id and c.deleted_at is null)
       or exists (select 1 from public.items i where i.category_id = new.id and i.deleted_at is null) then
      raise exception 'E_CATEGORY_NOT_EMPTY';
    end if;
  end if;
  return new;
end $$;
create trigger c_category_archive before update on public.categories for each row execute function public.tg_category_archive();

-- الأصناف: التصنيف والخدمة
alter table public.items add column if not exists category_id uuid references public.categories(id);
alter table public.items drop constraint items_kind_check;
alter table public.items add constraint items_kind_check check (kind in ('part', 'accessory', 'used', 'service'));

-- اسم التصنيف بيتنسخ في النص القديم (الفلاتر والتصدير والتقارير)
-- والعكس: صنف بتصنيف نصي بس (الاستيراد من Excel، أو البرامج القديمة) بيتربط بتصنيف بنفس الاسم، ولو مش موجود بيتعمل تصنيف رئيسي
create or replace function public.tg_item_category_text() returns trigger
language plpgsql security definer set search_path = public as $$
declare cid uuid;
begin
  if new.category_id is not null and (tg_op = 'INSERT' or new.category_id is distinct from old.category_id) then
    select c.name into new.category from public.categories c where c.id = new.category_id and c.shop_id = new.shop_id;
    if new.category is null then raise exception 'E_NOT_FOUND'; end if;
  elsif new.category_id is null and nullif(trim(new.category), '') is not null
        and (tg_op = 'INSERT' or new.category is distinct from old.category) and not public.restoring() then
    select c.id into cid from public.categories c
     where c.shop_id = new.shop_id and c.deleted_at is null and lower(trim(c.name)) = lower(trim(new.category))
     order by (c.parent_id is null), c.created_at limit 1;
    if cid is null then
      cid := gen_random_uuid();
      insert into public.categories(id, shop_id, name, icon) values (cid, new.shop_id, left(trim(new.category), 60), 'box');
    end if;
    new.category_id := cid;
    new.category := trim(new.category);
  end if;
  return new;
end $$;
create trigger b_item_category_text before insert or update of category_id, category on public.items for each row execute function public.tg_item_category_text();
create or replace function public.tg_category_rename() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if new.name is distinct from old.name then
    perform set_config('warsha.system', 'on', true);
    update public.items set category = new.name where category_id = new.id;
    perform set_config('warsha.system', 'off', true);
  end if;
  return new;
end $$;
create trigger d_category_rename after update of name on public.categories for each row execute function public.tg_category_rename();

-- نقل البيانات: كل تصنيف نصي قديم (في الأصناف أو في قايمة "تصنيفات الأصناف") بقى تصنيف رئيسي، والأصناف اتربطت بيه
create or replace function public.categories_from_text() returns integer
language plpgsql security definer set search_path = public as $mig$
declare r record; cid uuid; n int := 0;
begin
  perform set_config('warsha.restore', 'on', true);
  perform set_config('warsha.system', 'on', true);
  for r in
    select distinct x.shop_id, trim(x.name) as name from (
      select shop_id, category as name from public.items where category is not null and length(trim(category)) > 0 and deleted_at is null
      union select shop_id, value from public.shop_lists where list = 'item_categories' and deleted_at is null
    ) x
  loop
    select id into cid from public.categories c where c.shop_id = r.shop_id and c.parent_id is null and lower(trim(c.name)) = lower(r.name) and c.deleted_at is null;
    if cid is null then
      cid := gen_random_uuid();
      insert into public.categories(id, shop_id, name, icon) values (cid, r.shop_id, left(r.name, 60), 'box');
      n := n + 1;
    end if;
    update public.items set category_id = cid where shop_id = r.shop_id and category_id is null and lower(trim(category)) = lower(r.name);
  end loop;
  perform set_config('warsha.restore', 'off', true);
  perform set_config('warsha.system', 'off', true);
  return n;
end $mig$;
revoke execute on function public.categories_from_text() from public, anon, authenticated;
select public.categories_from_text();

-- الشجرة بالعدد: الأصناف (وأصناف الفرعي جوه الرئيسي)، واللي متوفر منها في الفرع (أو كل الفروع)
create or replace function public.category_tree(p_branch uuid default null)
returns table(id uuid, parent_id uuid, section text, name text, icon text, sort integer, items bigint, in_stock bigint)
language plpgsql stable security definer set search_path = public as $$
#variable_conflict use_column
declare s uuid := public.current_shop_id();
begin
  if s is null then raise exception 'E_FORBIDDEN'; end if;
  return query
  with st as (
    select m.item_id, sum(m.qty) q from public.stock_moves m
    where m.shop_id = s and (p_branch is null or m.branch_id = p_branch) and (public.all_my_branches() or public.can_branch(m.branch_id))
    group by m.item_id
  ), it as (
    select i.id, i.category_id, (i.kind = 'service' or coalesce(st.q, 0) > 0) avail
    from public.items i left join st on st.item_id = i.id
    where i.shop_id = s and i.deleted_at is null and i.category_id is not null
      and (i.kind <> 'used' or coalesce(st.q, 0) > 0)
  )
  select c.id, c.parent_id, c.section, c.name, c.icon, c.sort,
    (select count(*) from it where it.category_id = c.id or it.category_id in (select k.id from public.categories k where k.parent_id = c.id and k.deleted_at is null))::bigint,
    (select count(*) from it where it.avail and (it.category_id = c.id or it.category_id in (select k.id from public.categories k where k.parent_id = c.id and k.deleted_at is null)))::bigint
  from public.categories c
  where c.shop_id = s and c.deleted_at is null
  order by c.section, c.parent_id nulls first, c.sort, c.name;
end $$;
revoke execute on function public.category_tree(uuid) from public, anon;
grant execute on function public.category_tree(uuid) to authenticated;

-- ترتيب التصنيفات بالسحب (صاحب المحل)
create or replace function public.reorder_categories(p_ids uuid[]) returns void
language plpgsql security definer set search_path = public as $$
declare i int;
begin
  perform public.ledger_require(array['owner']::public.app_role[]);
  if coalesce(array_length(p_ids, 1), 0) > 200 then raise exception 'E_BAD_INPUT'; end if;
  for i in 1 .. coalesce(array_length(p_ids, 1), 0) loop
    update public.categories set sort = i * 10 where id = p_ids[i] and shop_id = public.current_shop_id();
  end loop;
end $$;
revoke execute on function public.reorder_categories(uuid[]) from public, anon;
grant execute on function public.reorder_categories(uuid[]) to authenticated;

-- التصنيفات الجاهزة (اختياري، صاحب المحل): بتتضاف بس لو اسمها مش موجود
create or replace function public.seed_categories(p_tree jsonb) returns integer
language plpgsql security definer set search_path = public as $$
declare s uuid := public.current_shop_id(); top jsonb; sub jsonb; tid uuid; n int := 0; i int := 0; j int;
begin
  perform public.ledger_require(array['owner']::public.app_role[]);
  if jsonb_typeof(p_tree) <> 'array' or jsonb_array_length(p_tree) > 30 then raise exception 'E_BAD_INPUT'; end if;
  for top in select * from jsonb_array_elements(p_tree) loop
    i := i + 1;
    select id into tid from public.categories where shop_id = s and parent_id is null and lower(trim(name)) = lower(trim(top ->> 'name')) and deleted_at is null;
    if tid is null then
      tid := gen_random_uuid();
      insert into public.categories(id, shop_id, section, name, icon, sort) values (tid, s, coalesce(top ->> 'section', 'products'), top ->> 'name', top ->> 'icon', i * 10);
      n := n + 1;
    end if;
    j := 0;
    for sub in select * from jsonb_array_elements(coalesce(top -> 'children', '[]'::jsonb)) loop
      j := j + 1;
      if jsonb_array_length(coalesce(top -> 'children', '[]'::jsonb)) > 60 then raise exception 'E_BAD_INPUT'; end if;
      if not exists (select 1 from public.categories where shop_id = s and parent_id = tid and lower(trim(name)) = lower(trim(sub ->> 'name')) and deleted_at is null) then
        insert into public.categories(id, shop_id, parent_id, name, icon, sort) values (gen_random_uuid(), s, tid, sub ->> 'name', sub ->> 'icon', j * 10);
        n := n + 1;
      end if;
    end loop;
  end loop;
  return n;
end $$;
revoke execute on function public.seed_categories(jsonb) from public, anon;
grant execute on function public.seed_categories(jsonb) to authenticated;

-- create_item: (src: 0038_roles_grant.sql) + الخدمة
create or replace function public.create_item(
  p_id uuid, p_kind text, p_name text, p_item_type text default null, p_brand text default null, p_model text default null,
  p_quality text default null, p_color text default null, p_sale_price integer default null, p_qty integer default null, p_unit_cost bigint default null,
  p_stock_id uuid default null
) returns uuid
language plpgsql security definer set search_path = public as $$
declare s uuid := public.current_shop_id(); nm text := trim(coalesce(p_name, ''));
begin
  perform public.ledger_require(array['owner', 'reception']::public.app_role[]);
  perform public.perm_require('item_create', 'add');
  if exists (select 1 from public.items where id = p_id and shop_id = s) then return p_id; end if;
  if p_kind not in ('part', 'accessory', 'service') or nm = '' or length(nm) > 160 then raise exception 'E_BAD_INPUT'; end if;
  if p_sale_price is not null and (p_sale_price < 0 or p_sale_price > 2000000000) then raise exception 'E_BAD_AMOUNT'; end if;
  insert into public.items(id, shop_id, kind, name, item_type, brand, model, quality, color, sale_price)
  values (p_id, s, p_kind, nm, nullif(trim(p_item_type), ''), nullif(trim(p_brand), ''), nullif(trim(p_model), ''), nullif(trim(p_quality), ''), nullif(trim(p_color), ''), p_sale_price);
  if coalesce(p_qty, 0) > 0 then
    if p_unit_cost is null or p_unit_cost <= 0 then raise exception 'E_BAD_AMOUNT'; end if;
    perform public.stock_in(coalesce(p_stock_id, gen_random_uuid()), p_id, p_qty, p_unit_cost, 'stock');
  end if;
  return p_id;
end $$;

-- record_sale: (src: 0037_item_details.sql) + الخدمات
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

-- النسخة الاحتياطية والاسترجاع: (src: 0049) + categories (قبل الأصناف)
create or replace function public.backup_snapshot(p_shop uuid) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare
  res jsonb := jsonb_build_object('format', 'warsha-backup', 'version', 1, 'generated_at', now(), 'shop_id', p_shop);
  t text;
  rows jsonb;
begin
  foreach t in array array['shops', 'branches', 'staff_branches', 'shop_branding', 'profiles', 'customers', 'devices', 'device_costs', 'status_log', 'device_notes', 'device_photos', 'device_checks',
                           'quote_decisions', 'message_templates', 'message_log', 'accounts', 'journal_entries', 'journal_lines', 'payments', 'drawer_closings',
                           'suppliers', 'categories', 'items', 'stock_moves', 'uncosted_sales', 'payment_plans', 'plan_installments', 'branch_goals', 'printers', 'print_templates', 'check_templates', 'used_devices', 'commission_rules', 'purchases', 'labor_rates', 'specialties', 'staff_specialties', 'routes', 'repair_steps',
                           'repair_videos', 'device_ratings', 'issue_presets', 'partners', 'profit_distributions', 'party_links', 'shop_lists', 'audit_log'] loop
    execute format('select coalesce(jsonb_agg(to_jsonb(x)), ''[]''::jsonb) from public.%I x where x.shop_id = $1', t) into rows using p_shop;
    res := res || jsonb_build_object(t, rows);
  end loop;
  select coalesce(jsonb_agg(jsonb_build_object('device_id', device_id, 'kind', kind, 'erased_at', erased_at)), '[]'::jsonb)
    into rows from public.device_passcodes where shop_id = p_shop;
  return res || jsonb_build_object('device_passcodes', rows);
end $$;

-- restore_backup: (src: 0049_commissions.sql) + categories
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
                       'quote_decisions', 'repair_steps', 'repair_videos', 'device_ratings', 'journal_entries', 'journal_lines', 'profit_distributions', 'payments',
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
$m0057$;
  insert into public.app_migrations(version, how) values ('0057_categories.sql', 'applied');
  raise notice 'applied %', '0057_categories.sql';
end $run$;
commit;

-- ============================== 0058_web_push.sql ==============================
begin;
do $run$ begin
  if exists (select 1 from public.app_migrations where version = '0058_web_push.sql') then return; end if;
  execute $m0058$
-- 0058: Web Push: إشعارات على الجهاز حتى والبرنامج مقفول (N المرحلة التانية)
--
-- - مجاني: خدمات الإشعارات بتاعة المتصفحات (Chrome/Edge/Firefox/Safari) مجانية، ومفيش أي خدمة مدفوعة.
-- - كل مستخدم بيفعّلها لجهازه من الإعدادات ← التنبيهات. الاشتراك بتاع الجهاز (endpoint + المفاتيح العامة) بيتحفظ هنا،
--   وصاحبه بس اللي يشوفه. الكتابة من الدوال بس.
-- - الإشعارات نفسها هي نفس اللي في الجرس (my_notifications) بنفس الصلاحيات بالظبط: الفني ما يوصلوش أقساط ولا فلوس.
-- - كل إشعار بيتبعت مرة واحدة بس لكل مستخدم (push_sent)، وما بيتبعتش لو المستخدم قراه في البرنامج.
-- - التوقيت: من الساعة كام لحد الساعة كام (بتوقيت القاهرة) من الإعدادات. برّه الوقت ده الإشعارات بتستنى.
-- - الإرسال من Edge Function اسمها push بمفاتيح VAPID في أسرار Supabase (التشفير جوه الدالة، مش هنا).
-- - زرار "اتقرا" في الإشعار بيشتغل بـ token عشوائي لمرة واحدة (push_ack) من غير تسجيل دخول.
-- - الاشتراكات خاصة بالجهاز، فما بتدخلش في النسخة الاحتياطية (بعد الاسترجاع كل واحد بيفعّل من جهازه تاني).

create table public.push_subscriptions (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references public.shops(id),
  profile_id uuid not null references auth.users(id),
  endpoint text not null check (length(endpoint) between 12 and 1000 and endpoint like 'https://%'),
  p256dh text not null check (p256dh ~ '^[A-Za-z0-9_-]{80,100}$'),
  auth text not null check (auth ~ '^[A-Za-z0-9_-]{16,44}$'),
  locale text not null default 'ar' check (locale in ('ar', 'en')),
  user_agent text check (length(user_agent) <= 300),
  fails integer not null default 0,
  last_ok_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);
create unique index push_subscriptions_endpoint on public.push_subscriptions(endpoint) where deleted_at is null;
create index push_subscriptions_profile on public.push_subscriptions(profile_id) where deleted_at is null;

create table public.push_sent (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references public.shops(id),
  profile_id uuid not null references auth.users(id),
  key text not null check (length(key) <= 120),
  ack_token text not null unique,
  acked_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  unique (profile_id, key)
);

alter table public.push_subscriptions enable row level security;
alter table public.push_sent enable row level security;
create trigger set_updated_at before update on public.push_subscriptions for each row execute function public.tg_set_updated_at();
create trigger set_updated_at before update on public.push_sent for each row execute function public.tg_set_updated_at();
create trigger block_delete before delete on public.push_subscriptions for each row execute function public.tg_block_delete();
create trigger block_delete before delete on public.push_sent for each row execute function public.tg_block_delete();

-- كل واحد يشوف أجهزته هو بس (في محله). الكتابة من الدوال بس
create policy push_subs_select on public.push_subscriptions for select to authenticated
  using (profile_id = auth.uid() and shop_id = public.current_shop_id() and deleted_at is null);
create policy push_sent_select on public.push_sent for select to authenticated
  using (profile_id = auth.uid() and shop_id = public.current_shop_id());
grant select on public.push_subscriptions, public.push_sent to authenticated;

-- ---------- التوقيت (الإعدادات ← التنبيهات) ----------
-- من/لحد بتوقيت القاهرة (0-24). الافتراضي من 9 الصبح لـ 9 بالليل. من = لحد يعني طول اليوم
create or replace function public.push_window(p_shop uuid) returns int[]
language sql stable security definer set search_path = public as $$
  select array[
    least(greatest(coalesce((s.extras -> 'reminders' ->> 'push_from')::int, 9), 0), 24),
    least(greatest(coalesce((s.extras -> 'reminders' ->> 'push_to')::int, 21), 0), 24)]
  from public.shops s where s.id = p_shop
$$;
revoke execute on function public.push_window(uuid) from public, anon, authenticated;

create or replace function public.push_window_open(p_shop uuid, p_at timestamptz) returns boolean
language plpgsql stable security definer set search_path = public as $$
declare w int[] := public.push_window(p_shop); h int := extract(hour from p_at at time zone 'Africa/Cairo')::int;
begin
  if w is null then return false; end if;
  if w[1] = w[2] or (w[1] = 0 and w[2] = 24) then return true; end if;
  if w[1] < w[2] then return h >= w[1] and h < w[2]; end if;
  -- بيعدّي نص الليل (مثلًا من 20 لـ 2)
  return h >= w[1] or h < w[2];
end $$;
revoke execute on function public.push_window_open(uuid, timestamptz) from public, anon, authenticated;

-- ---------- الاشتراك (من الجهاز نفسه) ----------
create or replace function public.save_push_subscription(p_endpoint text, p_p256dh text, p_auth text, p_locale text default 'ar', p_user_agent text default null)
returns uuid
language plpgsql security definer set search_path = public as $$
declare s uuid := public.current_shop_id(); me uuid := auth.uid(); rid uuid;
begin
  if s is null or me is null then raise exception 'E_FORBIDDEN'; end if;
  if p_endpoint is null or p_endpoint !~ '^https://[^/@\s]+\.[^/@\s]+/' or length(p_endpoint) > 1000
     or coalesce(p_p256dh, '') !~ '^[A-Za-z0-9_-]{80,100}$' or coalesce(p_auth, '') !~ '^[A-Za-z0-9_-]{16,44}$' then
    raise exception 'E_BAD_INPUT';
  end if;
  -- نفس المتصفح بقى لمستخدم تاني (حد خرج وحد دخل): الاشتراك بينتقل لللي داخل دلوقتي بس
  select id into rid from public.push_subscriptions where endpoint = p_endpoint and deleted_at is null for update;
  if rid is not null then
    update public.push_subscriptions set shop_id = s, profile_id = me, p256dh = p_p256dh, auth = p_auth,
      locale = case when p_locale = 'en' then 'en' else 'ar' end, user_agent = left(p_user_agent, 300), fails = 0
    where id = rid;
  else
    rid := gen_random_uuid();
    insert into public.push_subscriptions(id, shop_id, profile_id, endpoint, p256dh, auth, locale, user_agent)
    values (rid, s, me, p_endpoint, p_p256dh, p_auth, case when p_locale = 'en' then 'en' else 'ar' end, left(p_user_agent, 300));
  end if;
  -- 10 أجهزة بالكتير لكل مستخدم (الأقدم بيتشال)
  update public.push_subscriptions set deleted_at = now()
   where profile_id = me and deleted_at is null
     and id not in (select id from public.push_subscriptions where profile_id = me and deleted_at is null order by updated_at desc limit 10);
  return rid;
end $$;
revoke execute on function public.save_push_subscription(text, text, text, text, text) from public, anon;
grant execute on function public.save_push_subscription(text, text, text, text, text) to authenticated;

create or replace function public.remove_push_subscription(p_endpoint text) returns void
language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'E_FORBIDDEN'; end if;
  update public.push_subscriptions set deleted_at = now() where endpoint = p_endpoint and profile_id = auth.uid() and deleted_at is null;
end $$;
revoke execute on function public.remove_push_subscription(text) from public, anon;
grant execute on function public.remove_push_subscription(text) to authenticated;

-- ---------- الإرسال (Edge Function push بمفتاح السيرفر بس) ----------
-- بيرجّع الإشعارات الجديدة لكل جهاز مشترك (لو التوقيت مفتوح)، وبيسجّلها إنها اتبعتت عشان ما تتكررش.
-- لكل مستخدم: الإشعارات بتتحسب بصلاحياته هو بالظبط (نفس دالة الجرس وهو داخل).
create or replace function public.push_due(p_now timestamptz default now())
returns table(sub_id uuid, endpoint text, p256dh text, auth text, locale text, key text, kind text, args jsonb, link text, token text)
language plpgsql security definer set search_path = public, extensions, pg_temp as $$
#variable_conflict use_column
declare
  u record;
  old_claims text := current_setting('request.jwt.claims', true);
  old_sub text := current_setting('request.jwt.claim.sub', true);
begin
  drop table if exists pg_temp._push_new;
  create temp table _push_new(profile_id uuid, key text, kind text, args jsonb, link text, token text) on commit drop;
  for u in
    select distinct ps.profile_id, ps.shop_id
      from public.push_subscriptions ps
      join public.profiles p on p.id = ps.profile_id and p.shop_id = ps.shop_id and p.deleted_at is null
      join public.shops sh on sh.id = ps.shop_id and sh.suspended_at is null
     where ps.deleted_at is null and public.push_window_open(ps.shop_id, p_now)
  loop
    -- نفس صلاحيات المستخدم: كأنه داخل (aal2 لأنه فعّل الاشتراك وهو داخل بالتحقق بخطوتين لو مفعّل)
    perform set_config('request.jwt.claims', jsonb_build_object('sub', u.profile_id, 'role', 'authenticated', 'aal', 'aal2')::text, true);
    perform set_config('request.jwt.claim.sub', u.profile_id::text, true);
    begin
      insert into _push_new
      select u.profile_id, n.key, n.kind, n.args, n.link, encode(gen_random_bytes(16), 'hex')
        from public.my_notifications() n
       where not exists (select 1 from public.push_sent x where x.profile_id = u.profile_id and x.key = n.key)
         and not exists (select 1 from public.notification_reads r where r.profile_id = u.profile_id and r.key = n.key and r.deleted_at is null)
       limit 50;
    exception when others then
      -- مستخدم اتقفل أو اتشالت صلاحيته: ما يوصلوش حاجة
      null;
    end;
  end loop;
  perform set_config('request.jwt.claims', coalesce(old_claims, ''), true);
  perform set_config('request.jwt.claim.sub', coalesce(old_sub, ''), true);

  insert into public.push_sent(shop_id, profile_id, key, ack_token)
  select p.shop_id, n.profile_id, n.key, n.token from _push_new n join public.profiles p on p.id = n.profile_id
  on conflict (profile_id, key) do nothing;

  return query
  select ps.id, ps.endpoint, ps.p256dh, ps.auth, ps.locale, n.key, n.kind, n.args, n.link, n.token
    from _push_new n
    join public.push_subscriptions ps on ps.profile_id = n.profile_id and ps.deleted_at is null
   order by ps.id, n.key;
end $$;
revoke execute on function public.push_due(timestamptz) from public, anon, authenticated;
grant execute on function public.push_due(timestamptz) to service_role;

-- نتيجة الإرسال: الجهاز اللي لغى الاشتراك (404/410) أو فشل 5 مرات ورا بعض بيتشال
create or replace function public.push_result(p_rows jsonb) returns integer
language plpgsql security definer set search_path = public as $$
declare r jsonb; n int := 0; st int;
begin
  if jsonb_typeof(p_rows) <> 'array' or jsonb_array_length(p_rows) > 5000 then raise exception 'E_BAD_INPUT'; end if;
  for r in select * from jsonb_array_elements(p_rows) loop
    st := coalesce((r ->> 'status')::int, 0);
    if st between 200 and 299 then
      update public.push_subscriptions set fails = 0, last_ok_at = now() where id = (r ->> 'sub_id')::uuid;
    elsif st in (404, 410) or coalesce((r ->> 'gone')::boolean, false) then
      update public.push_subscriptions set deleted_at = now() where id = (r ->> 'sub_id')::uuid and deleted_at is null;
      n := n + 1;
    else
      update public.push_subscriptions set fails = fails + 1, deleted_at = case when fails + 1 >= 5 then now() else deleted_at end
       where id = (r ->> 'sub_id')::uuid and deleted_at is null;
    end if;
  end loop;
  return n;
end $$;
revoke execute on function public.push_result(jsonb) from public, anon, authenticated;
grant execute on function public.push_result(jsonb) to service_role;

-- ---------- زرار "اتقرا" من الإشعار نفسه (من غير تسجيل دخول) ----------
-- token عشوائي 128 بت لإشعار واحد، بيشتغل مرة واحدة وفي خلال 7 أيام. بيعلّم الإشعار مقروء في الجرس بس.
create or replace function public.push_ack(p_token text) returns boolean
language plpgsql security definer set search_path = public as $$
declare x public.push_sent;
begin
  if p_token is null or p_token !~ '^[0-9a-f]{32}$' then return false; end if;
  update public.push_sent set acked_at = now()
   where ack_token = p_token and acked_at is null and deleted_at is null and created_at > now() - interval '7 days'
  returning * into x;
  if x.id is null then return false; end if;
  insert into public.notification_reads(shop_id, profile_id, key) values (x.shop_id, x.profile_id, x.key)
  on conflict (profile_id, key) do nothing;
  return true;
end $$;
revoke execute on function public.push_ack(text) from public;
grant execute on function public.push_ack(text) to anon, authenticated;
$m0058$;
  insert into public.app_migrations(version, how) values ('0058_web_push.sql', 'applied');
  raise notice 'applied %', '0058_web_push.sql';
end $run$;
commit;

-- ============================== 0059_counters_branch.sql ==============================
begin;
do $run$ begin
  if exists (select 1 from public.app_migrations where version = '0059_counters_branch.sql') then return; end if;
  execute $m0059$
-- 0059: U6 (مراجعة عزل الفروع): ترقيم الطلبات لكل فرع
--
-- اختبار U6 (tests/db/u6.test.ts) لقى إن موظف فرع بيقدر يقرا عدّاد أرقام طلبات الفرع التاني (order_counters)،
-- وده بيكشف عدد شغل الفرع التاني في السنة. البرنامج نفسه ما بيقراش الجدول ده خالص (الترقيم جوه قاعدة البيانات)،
-- فالقراية بقت لفروع الموظف بس (صاحب المحل بيشوف الكل زي الأول).
drop policy if exists counters_select on public.order_counters;
create policy counters_select_branch on public.order_counters for select to authenticated
  using (shop_id = public.current_shop_id() and (branch_id is null or branch_id in (select unnest(public.my_branch_ids()))));
$m0059$;
  insert into public.app_migrations(version, how) values ('0059_counters_branch.sql', 'applied');
  raise notice 'applied %', '0059_counters_branch.sql';
end $run$;
commit;

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

select 4 as part, 4 as parts, count(*) as applied_files, max(version) as latest,
  case when '0060_sale_lines.sql' in (select version from public.app_migrations) then
    'خلص: المشروع على آخر نسخة'
  else 'فيه ملف ما اتطبقش' end as status
from public.app_migrations;
