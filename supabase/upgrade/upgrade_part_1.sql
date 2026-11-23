-- جوالك / Gawalak: ترقية مشروع Supabase لآخر نسخة، الجزء 1 من 6 (الملفات 0001_phase1.sql لـ 0017_growth.sql).
-- بيتولد تلقائيًا: npm run db:setup-file. ما تعدّلوش بإيدك.
-- شغّل الأجزاء بالترتيب في SQL Editor (كل جزء لوحده: New query ← الصق ← Run): upgrade_part_1.sql ثم upgrade_part_2.sql ثم upgrade_part_3.sql ثم upgrade_part_4.sql ثم upgrade_part_5.sql ثم upgrade_part_6.sql.
-- آمن تشغّل أي جزء أكتر من مرة: اللي اتطبق قبل كده بيتخطى. ولو ملف فشل، اللي قبله بيفضل، وصلّح السبب وشغّل نفس الجزء تاني.
-- لو لقى ملف أحدث موجود وأقدم منه ناقص بيقف (E_UPGRADE_GAP). ولو جزء قبله لسه ما اتطبقش بيقف (E_UPGRADE_ORDER). الاتنين من غير تغيير.
-- ملفات الجزء ده: 0001_phase1.sql, 0002_storage.sql, 0003_shop_profile_realtime.sql, 0004_error_codes.sql, 0005_device_passcode.sql, 0006_invite_name.sql, 0007_phase2_customer.sql, 0008_ledger.sql, 0009_tracking_guess_limit.sql, 0010_default_cashboxes.sql, 0011_finance_drilldown.sql, 0012_spec_completion.sql, 0013_tracking_ambiguous.sql, 0014_technicians.sql, 0015_offline_backup.sql, 0016_shop_identity.sql, 0017_growth.sql

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
  if not exists (select 1 from public.app_migrations where version = '0002_storage.sql') and (exists (select 1 from pg_policies where policyname = 'device_photos_upload')) then
    insert into public.app_migrations(version, how) values ('0002_storage.sql', 'found: policy device_photos_upload');
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
  if not exists (select 1 from public.app_migrations where version = '0062_vat.sql') and (exists (select 1 from pg_proc p where p.pronamespace = 'public'::regnamespace and p.proname = 'vat_bp' and position('when (sh.extras -> ''vat'' -> ''enabled'') is distinct from ''true''::jsonb then 0' in p.prosrc) > 0)) then
    insert into public.app_migrations(version, how) values ('0062_vat.sql', 'found: function vat_bp');
  end if;
  if not exists (select 1 from public.app_migrations where version = '0063_cheques.sql') and (to_regclass('public.cheques') is not null) then
    insert into public.app_migrations(version, how) values ('0063_cheques.sql', 'found: table cheques');
  end if;
  if not exists (select 1 from public.app_migrations where version = '0064_day_report.sql') and (exists (select 1 from pg_proc p where p.pronamespace = 'public'::regnamespace and p.proname = 'day_cash_report' and position('if p_branch is null then raise exception ''E_FORBIDDEN''; end if;' in p.prosrc) > 0)) then
    insert into public.app_migrations(version, how) values ('0064_day_report.sql', 'found: function day_cash_report');
  end if;
  if not exists (select 1 from public.app_migrations where version = '0065_cheque_pending.sql') and (exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'cheques' and column_name = 'device_id')) then
    insert into public.app_migrations(version, how) values ('0065_cheque_pending.sql', 'found: column cheques.device_id');
  end if;
  if not exists (select 1 from public.app_migrations where version = '0066_commission_net.sql') and (exists (select 1 from pg_proc p where p.pronamespace = 'public'::regnamespace and p.proname = 'commission_preview' and position('declare d public.devices; techs uuid[]; n int; base bigint; fc bigint; r public.commission_rules; t uuid; share bigint;' in p.prosrc) > 0)) then
    insert into public.app_migrations(version, how) values ('0066_commission_net.sql', 'found: function commission_preview');
  end if;
  if not exists (select 1 from public.app_migrations where version = '0067_idem_lock.sql') and (exists (select 1 from pg_proc p where p.pronamespace = 'public'::regnamespace and p.proname = 'ledger_idem' and position('if p is null then return null; end if;' in p.prosrc) > 0)) then
    insert into public.app_migrations(version, how) values ('0067_idem_lock.sql', 'found: function ledger_idem');
  end if;
  if not exists (select 1 from public.app_migrations where version = '0068_stock_adjust.sql') and (exists (select 1 from pg_proc p where p.pronamespace = 'public'::regnamespace and p.proname = '_stock_in' and position('e := public.ledger_post(''opening'', p_item, left(coalesce(nullif(trim(p_memo), ''''), ''stock''), 300),' in p.prosrc) > 0)) then
    insert into public.app_migrations(version, how) values ('0068_stock_adjust.sql', 'found: function _stock_in');
  end if;
  if not exists (select 1 from public.app_migrations where version = '0069_sale_errors.sql') and (exists (select 1 from pg_proc p where p.pronamespace = 'public'::regnamespace and p.proname = 'record_sale' and position('if coalesce(l ->> ''qty'', '''') !~ ''^[0-9]{1,6}$'' or (l ->> ''qty'')::bigint <= 0 then raise exception ''E_BAD_QTY''; end if;' in p.prosrc) > 0)) then
    insert into public.app_migrations(version, how) values ('0069_sale_errors.sql', 'found: function record_sale');
  end if;
  if not exists (select 1 from public.app_migrations where version = '0070_perm_matrix.sql') and (exists (select 1 from pg_proc p where p.pronamespace = 'public'::regnamespace and p.proname = 'device_reach' and position('select public.current_app_role() = ''owner'' or exists (' in p.prosrc) > 0)) then
    insert into public.app_migrations(version, how) values ('0070_perm_matrix.sql', 'found: function device_reach');
  end if;
  if not exists (select 1 from public.app_migrations where version = '0071_device_children.sql') and (exists (select 1 from pg_policies where policyname = 'perm_upload_sessions_select')) then
    insert into public.app_migrations(version, how) values ('0071_device_children.sql', 'found: policy perm_upload_sessions_select');
  end if;
  if not exists (select 1 from public.app_migrations where version = '0072_sale_line_return.sql') and (exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'sale_lines' and column_name = 'return_of')) then
    insert into public.app_migrations(version, how) values ('0072_sale_line_return.sql', 'found: column sale_lines.return_of');
  end if;
  if not exists (select 1 from public.app_migrations where version = '0073_shop_extras.sql') and (exists (select 1 from pg_proc p where p.pronamespace = 'public'::regnamespace and p.proname = 'set_shop_extras' and position('if p_patch is null or jsonb_typeof(p_patch) <> ''object'' or p_patch = ''{}''::jsonb then raise exception ''E_BAD_INPUT''; end if;' in p.prosrc) > 0)) then
    insert into public.app_migrations(version, how) values ('0073_shop_extras.sql', 'found: function set_shop_extras');
  end if;
  if not exists (select 1 from public.app_migrations where version = '0074_idem_cheque_plan.sql') and (exists (select 1 from pg_proc p where p.pronamespace = 'public'::regnamespace and p.proname = 'cheque_receive' and position('perform public.ledger_idem(p_id);' in p.prosrc) > 0)) then
    insert into public.app_migrations(version, how) values ('0074_idem_cheque_plan.sql', 'found: function cheque_receive');
  end if;
  insert into public.app_migrations(version, how) select v, 'inferred' from unnest(array['0022_security_review.sql']::text[]) v
    where v < (select max(version) from public.app_migrations) on conflict (version) do nothing;
  select min(v) into first_missing from unnest(array['0001_phase1.sql', '0002_storage.sql', '0003_shop_profile_realtime.sql', '0004_error_codes.sql', '0005_device_passcode.sql', '0006_invite_name.sql', '0007_phase2_customer.sql', '0008_ledger.sql', '0009_tracking_guess_limit.sql', '0010_default_cashboxes.sql', '0011_finance_drilldown.sql', '0012_spec_completion.sql', '0013_tracking_ambiguous.sql', '0014_technicians.sql', '0015_offline_backup.sql', '0016_shop_identity.sql', '0017_growth.sql', '0018_account_state.sql', '0019_extras.sql', '0020_admin_paging.sql', '0021_spec_rules.sql', '0022_security_review.sql', '0023_restore.sql', '0024_signout.sql', '0025_integrity.sql', '0026_edit_delete.sql', '0027_inventory.sql', '0028_opening.sql', '0029_partners.sql', '0030_party_links.sql', '0031_partner_capital.sql', '0032_lists.sql', '0033_assistant.sql', '0034_branches.sql', '0035_lists_everywhere.sql', '0036_roles.sql', '0037_item_details.sql', '0038_roles_grant.sql', '0039_payment_plans.sql', '0040_branch_books.sql', '0041_analytics.sql', '0042_app_brand.sql', '0043_printing.sql', '0044_capture.sql', '0045_checklists.sql', '0046_master.sql', '0047_mfa.sql', '0048_used.sql', '0049_commissions.sql', '0050_insights.sql', '0051_demo.sql', '0052_catalog.sql', '0053_portal.sql', '0054_telegram.sql', '0055_eta_placeholder.sql', '0056_branch_features.sql', '0057_categories.sql', '0058_web_push.sql', '0059_counters_branch.sql', '0060_sale_lines.sql', '0061_attendance.sql', '0062_vat.sql', '0063_cheques.sql', '0064_day_report.sql', '0065_cheque_pending.sql', '0066_commission_net.sql', '0067_idem_lock.sql', '0068_stock_adjust.sql', '0069_sale_errors.sql', '0070_perm_matrix.sql', '0071_device_children.sql', '0072_sale_line_return.sql', '0073_shop_extras.sql', '0074_idem_cheque_plan.sql']) v where v not in (select version from public.app_migrations);
  select max(version) into later_present from public.app_migrations where first_missing is not null and version > first_missing;
  if later_present is not null then raise exception 'E_UPGRADE_GAP: % موجود، بس % ناقص قبله. ابعت الرسالة دي للمطوّر.', later_present, first_missing; end if;
end $chk$;

-- 2) الأجزاء اللي قبل الجزء ده لازم تكون اتطبقت
do $ord$
declare
  files text[] := array['0001_phase1.sql', '0002_storage.sql', '0003_shop_profile_realtime.sql', '0004_error_codes.sql', '0005_device_passcode.sql', '0006_invite_name.sql', '0007_phase2_customer.sql', '0008_ledger.sql', '0009_tracking_guess_limit.sql', '0010_default_cashboxes.sql', '0011_finance_drilldown.sql', '0012_spec_completion.sql', '0013_tracking_ambiguous.sql', '0014_technicians.sql', '0015_offline_backup.sql', '0016_shop_identity.sql', '0017_growth.sql', '0018_account_state.sql', '0019_extras.sql', '0020_admin_paging.sql', '0021_spec_rules.sql', '0022_security_review.sql', '0023_restore.sql', '0024_signout.sql', '0025_integrity.sql', '0026_edit_delete.sql', '0027_inventory.sql', '0028_opening.sql', '0029_partners.sql', '0030_party_links.sql', '0031_partner_capital.sql', '0032_lists.sql', '0033_assistant.sql', '0034_branches.sql', '0035_lists_everywhere.sql', '0036_roles.sql', '0037_item_details.sql', '0038_roles_grant.sql', '0039_payment_plans.sql', '0040_branch_books.sql', '0041_analytics.sql', '0042_app_brand.sql', '0043_printing.sql', '0044_capture.sql', '0045_checklists.sql', '0046_master.sql', '0047_mfa.sql', '0048_used.sql', '0049_commissions.sql', '0050_insights.sql', '0051_demo.sql', '0052_catalog.sql', '0053_portal.sql', '0054_telegram.sql', '0055_eta_placeholder.sql', '0056_branch_features.sql', '0057_categories.sql', '0058_web_push.sql', '0059_counters_branch.sql', '0060_sale_lines.sql', '0061_attendance.sql', '0062_vat.sql', '0063_cheques.sql', '0064_day_report.sql', '0065_cheque_pending.sql', '0066_commission_net.sql', '0067_idem_lock.sql', '0068_stock_adjust.sql', '0069_sale_errors.sql', '0070_perm_matrix.sql', '0071_device_children.sql', '0072_sale_line_return.sql', '0073_shop_extras.sql', '0074_idem_cheque_plan.sql'];
  parts int[] := array[1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 3, 3, 3, 3, 3, 3, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 6, 6];
  miss text;
begin
  select min(v) into miss from unnest(files) v where v < '0001_phase1.sql' and v not in (select version from public.app_migrations);
  if miss is not null then raise exception 'E_UPGRADE_ORDER: الملف % لسه ما اتطبقش. شغّل upgrade_part_%.sql الأول، وبعدين الجزء ده (1).', miss, parts[array_position(files, miss)]; end if;
end $ord$;

-- 3) ملفات الجزء 1 بالترتيب، كل ملف في transaction لوحده
-- ============================== 0001_phase1.sql ==============================
begin;
do $run$ begin
  if exists (select 1 from public.app_migrations where version = '0001_phase1.sql') then return; end if;
  execute $m0001$
-- =====================================================================
-- المرحلة 1: الأساس
-- الملف ده بيتشغّل مرة واحدة في Supabase (SQL Editor) على مشروع جديد.
-- القواعد: كل جدول فيه id/shop_id/created_at/updated_at/deleted_at،
-- RLS بتعزل كل محل، الفلوس بالقروش integer، والحذف soft delete بس.
-- =====================================================================

create extension if not exists pgcrypto;

-- ---------- الأنواع ----------
create type public.app_role as enum ('owner', 'reception', 'technician');
create type public.device_status as enum (
  'received', 'inspecting', 'awaiting_approval', 'awaiting_part', 'in_repair',
  'repaired', 'ready', 'delivered', 'warranty_return', 'unrepairable'
);

-- ---------- الجداول ----------
create table public.shops (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null,               -- لنفس المحل = id (عشان القاعدة: كل جدول فيه shop_id)
  name text not null default 'محل الصيانة' check (length(name) between 1 and 120),
  phone text,
  address text,
  receipt_terms text not null default
    'المحل غير مسؤول عن البيانات الموجودة على الجهاز.' || chr(10) ||
    'الأجهزة المتروكة أكثر من 30 يومًا بعد إبلاغ العميل بجاهزيتها لا يتحمل المحل مسؤوليتها.' || chr(10) ||
    'يجب إحضار هذا الإيصال عند الاستلام.',
  warranty_days integer not null default 30 check (warranty_days between 0 and 3650),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  constraint shops_self check (shop_id = id)
);

create table public.profiles (
  id uuid primary key,                 -- = auth.users.id
  shop_id uuid not null references public.shops(id),
  full_name text not null check (length(full_name) between 1 and 120),
  email text not null,
  role public.app_role not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz                -- موظف اتشال = deleted_at فيه قيمة، وبيتمنع من الدخول
);
create unique index profiles_one_shop on public.profiles(id);

-- دعوة موظف: صاحب المحل يكتب الإيميل والدور، والموظف يعمل حساب بنفس الإيميل فيدخل على المحل
create table public.staff_invites (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references public.shops(id),
  email text not null check (email = lower(email) and position('@' in email) > 1),
  full_name text not null check (length(full_name) between 1 and 120),
  role public.app_role not null check (role <> 'owner'),
  accepted_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);
create unique index staff_invites_open on public.staff_invites(lower(email))
  where accepted_at is null and deleted_at is null;

create table public.customers (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references public.shops(id),
  name text not null check (length(name) between 1 and 120),
  phone text not null check (phone ~ '^01[0125][0-9]{8}$'),
  area text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);
create unique index customers_phone_per_shop on public.customers(shop_id, phone) where deleted_at is null;

create table public.order_counters (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references public.shops(id),
  year integer not null,
  last_value integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  unique (shop_id, year)
);

create table public.devices (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references public.shops(id),
  customer_id uuid not null references public.customers(id),
  order_no text not null,
  brand text not null check (length(brand) between 1 and 60),
  model text not null check (length(model) between 1 and 80),
  imei text check (imei ~ '^[0-9]{0,20}$'),
  color text,
  accessories text[] not null default '{}',
  issue text not null check (length(issue) between 1 and 1000),
  cosmetic_condition text,
  status public.device_status not null default 'received',
  received_by uuid references public.profiles(id),
  received_at timestamptz not null default now(),
  delivered_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  unique (shop_id, order_no)
);
create index devices_shop_status on public.devices(shop_id, status) where deleted_at is null;
create index devices_shop_imei on public.devices(shop_id, imei) where deleted_at is null and imei is not null;

-- الأسعار في جدول لوحدها عشان الفني ما يشوفهاش (RLS بتمنعه من الجدول كله)
create table public.device_costs (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references public.shops(id),
  device_id uuid not null unique references public.devices(id),
  estimated_cost integer check (estimated_cost between 0 and 2000000000),  -- بالقروش
  final_cost integer check (final_cost between 0 and 2000000000),          -- بالقروش
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

create table public.device_photos (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references public.shops(id),
  device_id uuid not null references public.devices(id),
  storage_path text not null unique,
  uploaded_by uuid references public.profiles(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

-- ملاحظات داخلية: للفريق بس، ما تظهرش للعميل أبدًا
create table public.device_notes (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references public.shops(id),
  device_id uuid not null references public.devices(id),
  author_id uuid references public.profiles(id),
  body text not null check (length(body) between 1 and 2000),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

create table public.status_log (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references public.shops(id),
  device_id uuid not null references public.devices(id),
  old_status public.device_status,
  new_status public.device_status not null,
  changed_by uuid references public.profiles(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);
create index status_log_device on public.status_log(device_id, created_at);

create table public.audit_log (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references public.shops(id),
  actor_id uuid,
  action text not null,           -- insert / update / status_change / ...
  entity text not null,           -- اسم الجدول
  entity_id uuid,
  before jsonb,
  after jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);
create index audit_log_shop_time on public.audit_log(shop_id, created_at desc);

-- ---------- دوال مساعدة ----------
-- المحل والدور بتوع المستخدم الحالي. security definer عشان تقرا profiles من غير ما RLS تلف حوالين نفسها.
create or replace function public.current_shop_id() returns uuid
language sql stable security definer set search_path = public as $$
  select shop_id from public.profiles where id = auth.uid() and deleted_at is null
$$;

create or replace function public.current_app_role() returns public.app_role
language sql stable security definer set search_path = public as $$
  select role from public.profiles where id = auth.uid() and deleted_at is null
$$;

-- لازم تطابق TRANSITIONS في src/lib/status.ts
create or replace function public.is_valid_transition(old_s public.device_status, new_s public.device_status)
returns boolean language sql immutable as $$
  select case old_s
    when 'received'          then new_s in ('inspecting','unrepairable')
    when 'inspecting'        then new_s in ('awaiting_approval','awaiting_part','in_repair','unrepairable')
    when 'awaiting_approval' then new_s in ('in_repair','awaiting_part','unrepairable')
    when 'awaiting_part'     then new_s in ('in_repair','unrepairable')
    when 'in_repair'         then new_s in ('repaired','awaiting_part','unrepairable')
    when 'repaired'          then new_s in ('ready','in_repair')
    when 'ready'             then new_s in ('delivered')
    when 'delivered'         then new_s in ('warranty_return')
    when 'warranty_return'   then new_s in ('inspecting','in_repair')
    when 'unrepairable'      then new_s in ('delivered')
    else false end
$$;

-- ---------- Triggers عامة ----------
create or replace function public.tg_set_updated_at() returns trigger
language plpgsql as $$
begin
  new.updated_at := now();
  return new;
end $$;

-- أي صف جديد بياخد محل المستخدم الحالي غصب عنه. كده محدش يقدر يكتب في محل تاني.
create or replace function public.tg_force_shop_id() returns trigger
language plpgsql security definer set search_path = public as $$
declare s uuid := public.current_shop_id();
begin
  if s is null then
    raise exception 'المستخدم غير مرتبط بمحل';
  end if;
  if tg_op = 'INSERT' then
    new.shop_id := s;
  elsif new.shop_id is distinct from old.shop_id then
    raise exception 'ممنوع تغيير المحل';
  end if;
  return new;
end $$;

-- الحذف الفعلي ممنوع في كل الجداول (soft delete بس)
create or replace function public.tg_block_delete() returns trigger
language plpgsql as $$
begin
  raise exception 'الحذف الفعلي ممنوع. استخدم deleted_at';
end $$;

-- سجل النشاط: إضافة بس، ممنوع تعديل أو حذف حتى لصاحب المحل
create or replace function public.tg_audit_immutable() returns trigger
language plpgsql as $$
begin
  raise exception 'سجل النشاط لا يمكن تعديله أو حذفه';
end $$;

create or replace function public.tg_audit() returns trigger
language plpgsql security definer set search_path = public as $$
declare
  act text;
  shop uuid;
begin
  if tg_op = 'INSERT' then
    act := 'insert';
  elsif new.deleted_at is not null and old.deleted_at is null then
    act := 'soft_delete';
  else
    act := 'update';
  end if;
  shop := coalesce(new.shop_id, old.shop_id);
  -- تحديث بدون أي تغيير حقيقي (غير updated_at) ما يتسجلش
  if tg_op = 'UPDATE' and (to_jsonb(new) - 'updated_at') = (to_jsonb(old) - 'updated_at') then
    return new;
  end if;
  insert into public.audit_log(shop_id, actor_id, action, entity, entity_id, before, after)
  values (
    shop, auth.uid(), act, tg_table_name, new.id,
    case when tg_op = 'UPDATE' then to_jsonb(old) end,
    to_jsonb(new)
  );
  return new;
end $$;

-- ---------- Triggers خاصة بالأجهزة ----------
-- رقم الطلب التلقائي: سنة-مسلسل (2026-0001) لكل محل، والعداد يبدأ من الأول كل سنة
create or replace function public.tg_device_defaults() returns trigger
language plpgsql security definer set search_path = public as $$
declare
  y integer := extract(year from (now() at time zone 'Africa/Cairo'))::integer;
  n integer;
begin
  insert into public.order_counters(shop_id, year, last_value)
  values (new.shop_id, y, 1)
  on conflict (shop_id, year) do update set last_value = public.order_counters.last_value + 1
  returning last_value into n;
  new.order_no := y::text || '-' || lpad(n::text, 4, '0');
  new.status := 'received';
  new.received_by := auth.uid();
  new.received_at := now();
  new.delivered_at := null;
  return new;
end $$;

create or replace function public.tg_device_guard() returns trigger
language plpgsql security definer set search_path = public as $$
declare
  r public.app_role := public.current_app_role();
  fc integer;
begin
  -- حاجات ما بتتغيرش بعد الاستلام
  if new.order_no is distinct from old.order_no
     or new.received_at is distinct from old.received_at
     or new.received_by is distinct from old.received_by then
    raise exception 'رقم الطلب وبيانات الاستلام ما بتتغيرش';
  end if;

  -- الفني يغيّر الحالة بس
  if r = 'technician' and
     (to_jsonb(new) - 'status' - 'updated_at' - 'delivered_at') <> (to_jsonb(old) - 'status' - 'updated_at' - 'delivered_at') then
    raise exception 'الفني يقدر يغيّر حالة الجهاز بس';
  end if;

  if new.status is distinct from old.status then
    if not public.is_valid_transition(old.status, new.status) then
      raise exception 'انتقال غير مسموح من % إلى %', old.status, new.status;
    end if;
    if new.status = 'delivered' then
      if r = 'technician' then
        raise exception 'الفني لا يسلّم الأجهزة';
      end if;
      select final_cost into fc from public.device_costs where device_id = new.id and deleted_at is null;
      if fc is null then
        raise exception 'لازم تكتب التكلفة النهائية قبل التسليم';
      end if;
      new.delivered_at := now();
    elsif old.status = 'delivered' then
      new.delivered_at := null;  -- رجع ضمان
    end if;
  elsif new.delivered_at is distinct from old.delivered_at then
    raise exception 'تاريخ التسليم بيتحدد تلقائيًا';
  end if;
  return new;
end $$;

-- كل تغيير حالة يتسجل: القديمة والجديدة والموظف والوقت
create or replace function public.tg_device_status_log() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if tg_op = 'INSERT' then
    insert into public.status_log(shop_id, device_id, old_status, new_status, changed_by)
    values (new.shop_id, new.id, null, new.status, auth.uid());
  elsif new.status is distinct from old.status then
    insert into public.status_log(shop_id, device_id, old_status, new_status, changed_by)
    values (new.shop_id, new.id, old.status, new.status, auth.uid());
  end if;
  return null;
end $$;

-- الجهاز والعميل والأسعار لازم يكونوا من نفس المحل
create or replace function public.tg_same_shop_refs() returns trigger
language plpgsql security definer set search_path = public as $$
declare ok boolean;
begin
  if tg_table_name = 'devices' then
    select exists(select 1 from public.customers c where c.id = new.customer_id and c.shop_id = new.shop_id and c.deleted_at is null) into ok;
  else
    select exists(select 1 from public.devices d where d.id = new.device_id and d.shop_id = new.shop_id) into ok;
  end if;
  if not ok then
    raise exception 'المرجع مش موجود في نفس المحل';
  end if;
  return new;
end $$;

-- حد أقصى 6 صور لكل جهاز
create or replace function public.tg_photo_limit() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  perform pg_advisory_xact_lock(hashtext(new.device_id::text));
  if (select count(*) from public.device_photos where device_id = new.device_id and deleted_at is null) >= 6 then
    raise exception 'الحد الأقصى 6 صور لكل جهاز';
  end if;
  if new.storage_path not like new.shop_id::text || '/' || new.device_id::text || '/%' then
    raise exception 'مسار الصورة غير صالح';
  end if;
  new.uploaded_by := auth.uid();
  return new;
end $$;

create or replace function public.tg_note_author() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if tg_op = 'INSERT' then
    new.author_id := auth.uid();
  elsif new.body is distinct from old.body or new.author_id is distinct from old.author_id then
    raise exception 'الملاحظة ما بتتعدلش بعد كتابتها';
  end if;
  return new;
end $$;

-- ممنوع حد يغيّر دوره بنفسه أو يشيل نفسه، وممنوع يبقى فيه أكتر من owner بالتعديل
create or replace function public.tg_profile_guard() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if new.id = auth.uid() and (new.role is distinct from old.role or new.deleted_at is not null) then
    raise exception 'ممنوع تغيّر دورك أو تشيل حسابك بنفسك';
  end if;
  if new.role = 'owner' and old.role <> 'owner' then
    raise exception 'ممنوع تعيين صاحب محل جديد من هنا';
  end if;
  if new.email is distinct from old.email or new.id is distinct from old.id then
    raise exception 'الإيميل ما بيتغيرش من هنا';
  end if;
  return new;
end $$;

-- ---------- ربط الـ Triggers ----------
do $$
declare t text;
begin
  foreach t in array array['shops','profiles','staff_invites','customers','order_counters','devices',
                           'device_costs','device_photos','device_notes','status_log','audit_log'] loop
    execute format('create trigger set_updated_at before update on public.%I for each row execute function public.tg_set_updated_at()', t);
    execute format('create trigger block_delete before delete on public.%I for each row execute function public.tg_block_delete()', t);
  end loop;
  foreach t in array array['customers','devices','device_costs','device_photos','device_notes','staff_invites'] loop
    execute format('create trigger a_force_shop_id before insert or update on public.%I for each row execute function public.tg_force_shop_id()', t);
  end loop;
  foreach t in array array['shops','profiles','staff_invites','customers','devices','device_costs','device_photos','device_notes'] loop
    execute format('create trigger zz_audit after insert or update on public.%I for each row execute function public.tg_audit()', t);
  end loop;
end $$;

create trigger audit_immutable before update on public.audit_log
  for each row execute function public.tg_audit_immutable();
create trigger status_log_immutable before update on public.status_log
  for each row execute function public.tg_audit_immutable();

create trigger device_defaults before insert on public.devices
  for each row execute function public.tg_device_defaults();
create trigger device_guard before update on public.devices
  for each row execute function public.tg_device_guard();
create trigger device_status_log after insert or update on public.devices
  for each row execute function public.tg_device_status_log();
create trigger zz_same_shop before insert or update on public.devices
  for each row execute function public.tg_same_shop_refs();
create trigger zz_same_shop before insert or update on public.device_costs
  for each row execute function public.tg_same_shop_refs();
create trigger zz_same_shop before insert on public.device_photos
  for each row execute function public.tg_same_shop_refs();
create trigger zz_same_shop before insert on public.device_notes
  for each row execute function public.tg_same_shop_refs();
create trigger zz_photo_limit before insert on public.device_photos
  for each row execute function public.tg_photo_limit();
create trigger note_author before insert or update on public.device_notes
  for each row execute function public.tg_note_author();
create trigger profile_guard before update on public.profiles
  for each row execute function public.tg_profile_guard();

-- ---------- أول دخول: إنشاء محل أو الانضمام بدعوة ----------
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
  if uid is null then raise exception 'لازم تسجّل دخول الأول'; end if;
  select * into p from public.profiles where id = uid;
  if found then
    if p.deleted_at is not null then raise exception 'الحساب ده موقوف'; end if;
    return p;
  end if;

  select lower(u.email), u.email_confirmed_at into em, confirmed from auth.users u where u.id = uid;
  if em is null then raise exception 'مستخدم غير معروف'; end if;

  select * into inv from public.staff_invites
   where lower(email) = em and accepted_at is null and deleted_at is null
   order by created_at desc limit 1;

  if found then
    -- الانضمام بدعوة محتاج إيميل متأكَّد منه، عشان محدش ينتحل إيميل موظف
    if confirmed is null then raise exception 'لازم تأكّد الإيميل الأول'; end if;
    insert into public.profiles(id, shop_id, full_name, email, role)
    values (uid, inv.shop_id, coalesce(nullif(trim(p_full_name), ''), inv.full_name), em, inv.role)
    returning * into p;
    update public.staff_invites set accepted_at = now() where id = inv.id;
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

-- قبل أول دخول: هل فيه دعوة للإيميل ده؟ (يرجّع اسم المحل والدور بس)
create or replace function public.my_pending_invite()
returns table(shop_name text, role public.app_role)
language sql stable security definer set search_path = public as $$
  select s.name, i.role
  from public.staff_invites i
  join public.shops s on s.id = i.shop_id
  join auth.users u on u.id = auth.uid()
  where lower(i.email) = lower(u.email) and i.accepted_at is null and i.deleted_at is null
  order by i.created_at desc limit 1
$$;

-- ---------- عرض البحث في الأجهزة ----------
-- security_invoker = الصلاحيات بتاعة المستخدم نفسه (RLS بتشتغل). الفني هيشوف اسم العميل فاضي.
create view public.devices_list with (security_invoker = true) as
select d.id, d.shop_id, d.order_no, d.brand, d.model, d.imei, d.color, d.status,
       d.received_at, d.delivered_at, d.customer_id, d.deleted_at,
       c.name as customer_name, c.phone as customer_phone,
       dc.estimated_cost, dc.final_cost
from public.devices d
left join public.customers c on c.id = d.customer_id
left join public.device_costs dc on dc.device_id = d.id and dc.deleted_at is null;

-- ---------- الصلاحيات و RLS ----------
revoke all on all tables in schema public from anon;
revoke all on all functions in schema public from anon;
revoke delete, truncate on all tables in schema public from authenticated;
grant usage on schema public to authenticated;
grant select on all tables in schema public to authenticated;
grant insert, update on public.shops, public.profiles, public.staff_invites, public.customers,
  public.devices, public.device_costs, public.device_photos, public.device_notes to authenticated;
revoke insert, update on public.audit_log, public.status_log, public.order_counters from authenticated;
revoke execute on function public.bootstrap_account(text, text) from public;
grant execute on function public.bootstrap_account(text, text) to authenticated;
revoke execute on function public.my_pending_invite() from public;
grant execute on function public.my_pending_invite() to authenticated;

alter table public.shops enable row level security;
alter table public.profiles enable row level security;
alter table public.staff_invites enable row level security;
alter table public.customers enable row level security;
alter table public.order_counters enable row level security;
alter table public.devices enable row level security;
alter table public.device_costs enable row level security;
alter table public.device_photos enable row level security;
alter table public.device_notes enable row level security;
alter table public.status_log enable row level security;
alter table public.audit_log enable row level security;

-- المحل
create policy shops_select on public.shops for select to authenticated
  using (id = public.current_shop_id());
create policy shops_update on public.shops for update to authenticated
  using (id = public.current_shop_id() and public.current_app_role() = 'owner')
  with check (id = public.current_shop_id());

-- المستخدمين
create policy profiles_select on public.profiles for select to authenticated
  using (shop_id = public.current_shop_id());
create policy profiles_update on public.profiles for update to authenticated
  using (shop_id = public.current_shop_id() and public.current_app_role() = 'owner')
  with check (shop_id = public.current_shop_id());

create policy invites_all on public.staff_invites for select to authenticated
  using (shop_id = public.current_shop_id() and public.current_app_role() = 'owner');
create policy invites_insert on public.staff_invites for insert to authenticated
  with check (shop_id = public.current_shop_id() and public.current_app_role() = 'owner');
create policy invites_update on public.staff_invites for update to authenticated
  using (shop_id = public.current_shop_id() and public.current_app_role() = 'owner')
  with check (shop_id = public.current_shop_id());

-- العملاء: صاحب المحل والاستقبال بس
create policy customers_select on public.customers for select to authenticated
  using (shop_id = public.current_shop_id() and public.current_app_role() in ('owner','reception'));
create policy customers_insert on public.customers for insert to authenticated
  with check (shop_id = public.current_shop_id() and public.current_app_role() in ('owner','reception'));
create policy customers_update on public.customers for update to authenticated
  using (shop_id = public.current_shop_id() and public.current_app_role() in ('owner','reception'))
  with check (shop_id = public.current_shop_id());

create policy counters_select on public.order_counters for select to authenticated
  using (shop_id = public.current_shop_id());

-- الأجهزة: كل موظفين المحل يشوفوها (الفني من غير أسعار ولا بيانات عميل)
create policy devices_select on public.devices for select to authenticated
  using (shop_id = public.current_shop_id());
create policy devices_insert on public.devices for insert to authenticated
  with check (shop_id = public.current_shop_id() and public.current_app_role() in ('owner','reception'));
create policy devices_update on public.devices for update to authenticated
  using (shop_id = public.current_shop_id())
  with check (shop_id = public.current_shop_id());

-- الأسعار: صاحب المحل والاستقبال بس
create policy costs_select on public.device_costs for select to authenticated
  using (shop_id = public.current_shop_id() and public.current_app_role() in ('owner','reception'));
create policy costs_insert on public.device_costs for insert to authenticated
  with check (shop_id = public.current_shop_id() and public.current_app_role() in ('owner','reception'));
create policy costs_update on public.device_costs for update to authenticated
  using (shop_id = public.current_shop_id() and public.current_app_role() in ('owner','reception'))
  with check (shop_id = public.current_shop_id());

create policy photos_select on public.device_photos for select to authenticated
  using (shop_id = public.current_shop_id());
create policy photos_insert on public.device_photos for insert to authenticated
  with check (shop_id = public.current_shop_id() and public.current_app_role() in ('owner','reception'));
create policy photos_update on public.device_photos for update to authenticated
  using (shop_id = public.current_shop_id() and public.current_app_role() in ('owner','reception'))
  with check (shop_id = public.current_shop_id());

create policy notes_select on public.device_notes for select to authenticated
  using (shop_id = public.current_shop_id());
create policy notes_insert on public.device_notes for insert to authenticated
  with check (shop_id = public.current_shop_id());
create policy notes_update on public.device_notes for update to authenticated
  using (shop_id = public.current_shop_id() and (author_id = auth.uid() or public.current_app_role() = 'owner'))
  with check (shop_id = public.current_shop_id());

create policy status_log_select on public.status_log for select to authenticated
  using (shop_id = public.current_shop_id());

-- سجل النشاط: صاحب المحل بس يقرأ، ومحدش يكتب أو يعدّل أو يحذف (الكتابة من الـ triggers بس)
create policy audit_select on public.audit_log for select to authenticated
  using (shop_id = public.current_shop_id() and public.current_app_role() = 'owner');
$m0001$;
  insert into public.app_migrations(version, how) values ('0001_phase1.sql', 'applied');
  raise notice 'applied %', '0001_phase1.sql';
end $run$;
commit;

-- ============================== 0002_storage.sql ==============================
begin;
do $run$ begin
  if exists (select 1 from public.app_migrations where version = '0002_storage.sql') then return; end if;
  execute $m0002$
-- =====================================================================
-- المرحلة 1: تخزين صور الأجهزة (Supabase Storage)
-- الصور خاصة (private): محدش يشوفها غير موظفين نفس المحل.
-- مسار كل صورة: {shop_id}/{device_id}/{اسم الملف}
-- =====================================================================

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('device-photos', 'device-photos', false, 5242880, array['image/jpeg','image/png','image/webp'])
on conflict (id) do nothing;

create policy device_photos_read on storage.objects for select to authenticated
  using (
    bucket_id = 'device-photos'
    and (storage.foldername(name))[1] = public.current_shop_id()::text
  );

create policy device_photos_upload on storage.objects for insert to authenticated
  with check (
    bucket_id = 'device-photos'
    and (storage.foldername(name))[1] = public.current_shop_id()::text
    and public.current_app_role() in ('owner','reception')
  );
-- مفيش سياسة تعديل أو حذف: الصورة بتفضل محفوظة، والإخفاء بيحصل بـ deleted_at في جدول device_photos.
$m0002$;
  insert into public.app_migrations(version, how) values ('0002_storage.sql', 'applied');
  raise notice 'applied %', '0002_storage.sql';
end $run$;
commit;

-- ============================== 0003_shop_profile_realtime.sql ==============================
begin;
do $run$ begin
  if exists (select 1 from public.app_migrations where version = '0003_shop_profile_realtime.sql') then return; end if;
  execute $m0003$
-- =====================================================================
-- إعدادات المحل من معالج التسجيل + التحديث اللحظي + شعار المحل
-- =====================================================================

alter table public.shops
  add column if not exists country text not null default 'EG' check (country ~ '^[A-Z]{2}$'),
  add column if not exists currency text not null default 'EGP' check (currency ~ '^[A-Z]{3}$'),
  add column if not exists payment_methods text[] not null default array['cash']::text[],
  add column if not exists logo_path text,
  add column if not exists theme text not null default 'dark' check (theme in ('dark', 'light')),
  add column if not exists locale text not null default 'ar' check (locale in ('ar', 'en')),
  add column if not exists setup_completed_at timestamptz;

-- طرق الدفع المسموحة بس
create or replace function public.valid_payment_methods(m text[]) returns boolean
language sql immutable as $$
  select coalesce(array_length(m, 1), 0) between 1 and 6
     and m <@ array['cash','card','bank_transfer','wallet','instapay','installments']::text[]
$$;
alter table public.shops drop constraint if exists shops_payment_methods_valid;
alter table public.shops add constraint shops_payment_methods_valid check (public.valid_payment_methods(payment_methods));

-- التحديث اللحظي للوحة التحكم (Supabase Realtime بيحترم RLS)
do $$
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    begin
      alter publication supabase_realtime add table public.devices, public.device_costs, public.status_log;
    exception when duplicate_object then null;
    end;
  end if;
end $$;

-- شعار المحل: بيظهر على الإيصال وصفحة التتبع، فالقراءة عامة. الرفع لصاحب المحل بس، جوه فولدر محله.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('shop-logos', 'shop-logos', true, 1048576, array['image/png','image/jpeg','image/webp','image/svg+xml'])
on conflict (id) do nothing;

create policy shop_logos_upload on storage.objects for insert to authenticated
  with check (
    bucket_id = 'shop-logos'
    and (storage.foldername(name))[1] = public.current_shop_id()::text
    and public.current_app_role() = 'owner'
  );
$m0003$;
  insert into public.app_migrations(version, how) values ('0003_shop_profile_realtime.sql', 'applied');
  raise notice 'applied %', '0003_shop_profile_realtime.sql';
end $run$;
commit;

-- ============================== 0004_error_codes.sql ==============================
begin;
do $run$ begin
  if exists (select 1 from public.app_migrations where version = '0004_error_codes.sql') then return; end if;
  execute $m0004$
-- =====================================================================
-- المرحلة 1 (تكملة): أكواد أخطاء ثابتة بدل الرسايل العربي
-- التطبيق بيترجم الكود للغة الحالية (errors.db.E_*). نفس الدوال بالظبط، بس الرسالة كود.
-- =====================================================================

create or replace function public.tg_force_shop_id() returns trigger
language plpgsql security definer set search_path = public as $$
declare s uuid := public.current_shop_id();
begin
  if s is null then
    raise exception 'E_NO_SHOP';
  end if;
  if tg_op = 'INSERT' then
    new.shop_id := s;
  elsif new.shop_id is distinct from old.shop_id then
    raise exception 'E_SHOP_CHANGE';
  end if;
  return new;
end $$;

create or replace function public.tg_block_delete() returns trigger
language plpgsql as $$
begin
  raise exception 'E_HARD_DELETE';
end $$;

create or replace function public.tg_audit_immutable() returns trigger
language plpgsql as $$
begin
  raise exception 'E_AUDIT_IMMUTABLE';
end $$;

create or replace function public.tg_device_guard() returns trigger
language plpgsql security definer set search_path = public as $$
declare
  r public.app_role := public.current_app_role();
  fc integer;
begin
  -- حاجات ما بتتغيرش بعد الاستلام
  if new.order_no is distinct from old.order_no
     or new.received_at is distinct from old.received_at
     or new.received_by is distinct from old.received_by then
    raise exception 'E_RECEIPT_IMMUTABLE';
  end if;

  -- الفني يغيّر الحالة بس
  if r = 'technician' and
     (to_jsonb(new) - 'status' - 'updated_at' - 'delivered_at') <> (to_jsonb(old) - 'status' - 'updated_at' - 'delivered_at') then
    raise exception 'E_TECH_STATUS_ONLY';
  end if;

  if new.status is distinct from old.status then
    if not public.is_valid_transition(old.status, new.status) then
      raise exception 'E_BAD_TRANSITION';
    end if;
    if new.status = 'delivered' then
      if r = 'technician' then
        raise exception 'E_TECH_NO_DELIVER';
      end if;
      select final_cost into fc from public.device_costs where device_id = new.id and deleted_at is null;
      if fc is null then
        raise exception 'E_FINAL_COST_REQUIRED';
      end if;
      new.delivered_at := now();
    elsif old.status = 'delivered' then
      new.delivered_at := null;  -- رجع ضمان
    end if;
  elsif new.delivered_at is distinct from old.delivered_at then
    raise exception 'E_DELIVERED_AUTO';
  end if;
  return new;
end $$;

create or replace function public.tg_same_shop_refs() returns trigger
language plpgsql security definer set search_path = public as $$
declare ok boolean;
begin
  if tg_table_name = 'devices' then
    select exists(select 1 from public.customers c where c.id = new.customer_id and c.shop_id = new.shop_id and c.deleted_at is null) into ok;
  else
    select exists(select 1 from public.devices d where d.id = new.device_id and d.shop_id = new.shop_id) into ok;
  end if;
  if not ok then
    raise exception 'E_CROSS_SHOP';
  end if;
  return new;
end $$;

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
  new.uploaded_by := auth.uid();
  return new;
end $$;

create or replace function public.tg_note_author() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if tg_op = 'INSERT' then
    new.author_id := auth.uid();
  elsif new.body is distinct from old.body or new.author_id is distinct from old.author_id then
    raise exception 'E_NOTE_IMMUTABLE';
  end if;
  return new;
end $$;

create or replace function public.tg_profile_guard() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if new.id = auth.uid() and (new.role is distinct from old.role or new.deleted_at is not null) then
    raise exception 'E_SELF_ROLE';
  end if;
  if new.role = 'owner' and old.role <> 'owner' then
    raise exception 'E_NO_NEW_OWNER';
  end if;
  if new.email is distinct from old.email or new.id is distinct from old.id then
    raise exception 'E_EMAIL_IMMUTABLE';
  end if;
  return new;
end $$;

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
$m0004$;
  insert into public.app_migrations(version, how) values ('0004_error_codes.sql', 'applied');
  raise notice 'applied %', '0004_error_codes.sql';
end $run$;
commit;

-- ============================== 0005_device_passcode.sql ==============================
begin;
do $run$ begin
  if exists (select 1 from public.app_migrations where version = '0005_device_passcode.sql') then return; end if;
  execute $m0005$
-- =====================================================================
-- المرحلة 1: كلمة سر / نمط قفل جهاز العميل
-- - القيمة نفسها متخزنة مشفّرة في Supabase Vault (vault.secrets)، مش في جداولنا.
-- - جدولنا فيه نوع القفل ورقم السر في الـ Vault بس.
-- - الحفظ: صاحب المحل والاستقبال (وقت الاستلام).
-- - المشاهدة: صاحب المحل والفني بس، وكل مشاهدة بتتسجل في سجل النشاط.
-- - التسليم بيمسح السر من الـ Vault نهائيًا.
-- =====================================================================

create table public.device_passcodes (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references public.shops(id),
  device_id uuid not null unique references public.devices(id),
  kind text not null check (kind in ('pin', 'pattern')),
  secret_id uuid,             -- رقم السر في vault.secrets (null = اتمسح)
  erased_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

create trigger set_updated_at before update on public.device_passcodes for each row execute function public.tg_set_updated_at();
create trigger block_delete before delete on public.device_passcodes for each row execute function public.tg_block_delete();

alter table public.device_passcodes enable row level security;
-- القراءة المباشرة للجدول (من غير القيمة) لموظفين المحل: عشان يعرفوا إن فيه قفل
create policy passcodes_select on public.device_passcodes for select to authenticated
  using (shop_id = public.current_shop_id());
-- مفيش insert/update/delete مباشر: كله من الدوال تحت
revoke insert, update, delete, truncate on public.device_passcodes from authenticated, anon;
grant select on public.device_passcodes to authenticated;

-- حفظ أو تغيير القفل
create or replace function public.set_device_passcode(p_device_id uuid, p_kind text, p_value text)
returns void
language plpgsql security definer set search_path = public as $$
declare
  shop uuid := public.current_shop_id();
  r public.app_role := public.current_app_role();
  dev public.devices;
  existing public.device_passcodes;
  sid uuid;
begin
  if shop is null then raise exception 'E_NO_SHOP'; end if;
  if r not in ('owner', 'reception') then raise exception 'E_FORBIDDEN'; end if;
  if p_kind not in ('pin', 'pattern') then raise exception 'E_BAD_INPUT'; end if;
  if p_value is null or length(trim(p_value)) = 0 or length(p_value) > 64 then raise exception 'E_BAD_INPUT'; end if;
  select * into dev from public.devices where id = p_device_id and shop_id = shop and deleted_at is null;
  if not found then raise exception 'E_NOT_FOUND'; end if;
  if dev.status = 'delivered' then raise exception 'E_DELIVERED_LOCKED'; end if;

  select * into existing from public.device_passcodes where device_id = p_device_id;
  if found and existing.secret_id is not null then
    perform vault.update_secret(existing.secret_id, p_value);
    update public.device_passcodes set kind = p_kind, erased_at = null where id = existing.id;
  else
    sid := vault.create_secret(p_value, 'device-passcode-' || p_device_id::text, 'device lock');
    if found then
      update public.device_passcodes set kind = p_kind, secret_id = sid, erased_at = null where id = existing.id;
    else
      insert into public.device_passcodes(shop_id, device_id, kind, secret_id) values (shop, p_device_id, p_kind, sid);
    end if;
  end if;
  -- السجل فيه نوع العملية بس، مش القيمة
  insert into public.audit_log(shop_id, actor_id, action, entity, entity_id, after)
  values (shop, auth.uid(), 'passcode_set', 'device_passcodes', p_device_id, jsonb_build_object('kind', p_kind));
end $$;

-- مشاهدة القفل: صاحب المحل والفني بس، وكل مشاهدة بتتسجل
create or replace function public.reveal_device_passcode(p_device_id uuid)
returns table(kind text, value text)
language plpgsql security definer set search_path = public as $$
declare
  shop uuid := public.current_shop_id();
  r public.app_role := public.current_app_role();
  pc public.device_passcodes;
  v text;
begin
  if shop is null then raise exception 'E_NO_SHOP'; end if;
  if r not in ('owner', 'technician') then raise exception 'E_FORBIDDEN'; end if;
  select * into pc from public.device_passcodes where device_id = p_device_id and shop_id = shop and deleted_at is null;
  if not found or pc.secret_id is null then raise exception 'E_NOT_FOUND'; end if;
  select ds.decrypted_secret into v from vault.decrypted_secrets ds where ds.id = pc.secret_id;
  insert into public.audit_log(shop_id, actor_id, action, entity, entity_id, after)
  values (shop, auth.uid(), 'passcode_viewed', 'device_passcodes', p_device_id, jsonb_build_object('kind', pc.kind));
  return query select pc.kind, v;
end $$;

-- عند التسليم: السر بيتمسح من الـ Vault نهائيًا
create or replace function public.tg_erase_passcode_on_delivery() returns trigger
language plpgsql security definer set search_path = public as $$
declare pc public.device_passcodes;
begin
  if new.status = 'delivered' and old.status is distinct from 'delivered' then
    select * into pc from public.device_passcodes where device_id = new.id and secret_id is not null;
    if found then
      delete from vault.secrets where id = pc.secret_id;
      update public.device_passcodes set secret_id = null, erased_at = now() where id = pc.id;
      insert into public.audit_log(shop_id, actor_id, action, entity, entity_id, after)
      values (new.shop_id, auth.uid(), 'passcode_erased', 'device_passcodes', new.id, jsonb_build_object('reason', 'delivered'));
    end if;
  end if;
  return null;
end $$;

create trigger zz_erase_passcode after update on public.devices
  for each row execute function public.tg_erase_passcode_on_delivery();

revoke execute on function public.set_device_passcode(uuid, text, text) from public, anon;
revoke execute on function public.reveal_device_passcode(uuid) from public, anon;
grant execute on function public.set_device_passcode(uuid, text, text) to authenticated;
grant execute on function public.reveal_device_passcode(uuid) to authenticated;
$m0005$;
  insert into public.app_migrations(version, how) values ('0005_device_passcode.sql', 'applied');
  raise notice 'applied %', '0005_device_passcode.sql';
end $run$;
commit;

-- ============================== 0006_invite_name.sql ==============================
begin;
do $run$ begin
  if exists (select 1 from public.app_migrations where version = '0006_invite_name.sql') then return; end if;
  execute $m0006$
-- الدعوة بترجّع كمان الاسم اللي صاحب المحل كتبه، عشان الموظف ينضم بيه
drop function if exists public.my_pending_invite();
create function public.my_pending_invite()
returns table(shop_name text, role public.app_role, full_name text)
language sql stable security definer set search_path = public as $$
  select s.name, i.role, i.full_name
  from public.staff_invites i
  join public.shops s on s.id = i.shop_id
  join auth.users u on u.id = auth.uid()
  where lower(i.email) = lower(u.email) and i.accepted_at is null and i.deleted_at is null
  order by i.created_at desc limit 1
$$;
revoke execute on function public.my_pending_invite() from public, anon;
grant execute on function public.my_pending_invite() to authenticated;
$m0006$;
  insert into public.app_migrations(version, how) values ('0006_invite_name.sql', 'applied');
  raise notice 'applied %', '0006_invite_name.sql';
end $run$;
commit;

-- ============================== 0007_phase2_customer.sql ==============================
begin;
do $run$ begin
  if exists (select 1 from public.app_migrations where version = '0007_phase2_customer.sql') then return; end if;
  execute $m0007$
-- =====================================================================
-- المرحلة 2: العميل
-- - التتبع العام (get_tracking) من غير تسجيل دخول، ومن غير أي بيانات شخصية، مع حد للمحاولات الغلط.
-- - رمز سري لكل جهاز (tracking_token) بيتحط في الـ QR.
-- - الموافقة على التكلفة من صفحة التتبع.
-- - قوالب واتساب يعدّلها صاحب المحل، وسجل الرسايل.
-- - تصنيف العملاء، والفحص السريع عند الاستلام والتسليم، والضمان.
-- =====================================================================

-- ---------- الجهاز: رمز التتبع والضمان ----------
alter table public.devices
  add column if not exists tracking_token text,
  add column if not exists warranty_days integer check (warranty_days between 0 and 3650),
  add column if not exists warranty_until timestamptz;
update public.devices set tracking_token = encode(gen_random_bytes(12), 'hex') where tracking_token is null;
alter table public.devices alter column tracking_token set default encode(gen_random_bytes(12), 'hex');
alter table public.devices alter column tracking_token set not null;
create unique index if not exists devices_tracking_token on public.devices(tracking_token);
create index if not exists devices_order_no on public.devices(order_no);

-- عند التسليم: الضمان بيتحسب من مدة الضمان بتاعة المحل وقتها
create or replace function public.tg_device_warranty() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if new.status = 'delivered' and old.status is distinct from 'delivered' then
    if new.warranty_days is null then
      select s.warranty_days into new.warranty_days from public.shops s where s.id = new.shop_id;
    end if;
    new.warranty_until := now() + make_interval(days => coalesce(new.warranty_days, 0));
  end if;
  if new.tracking_token is distinct from old.tracking_token then
    raise exception 'E_RECEIPT_IMMUTABLE';
  end if;
  return new;
end $$;
create trigger device_warranty before update on public.devices for each row execute function public.tg_device_warranty();

-- ---------- العملاء: التصنيف ----------
alter table public.customers
  add column if not exists category text not null default 'new' check (category in ('new', 'regular', 'vip', 'late')),
  add column if not exists marketing_ok boolean not null default false;

-- ---------- محاولات التتبع (للحد من التخمين) ----------
create table public.tracking_attempts (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid references public.shops(id), -- فاضي لو رقم الطلب مش موجود أصلًا
  client_key text not null,                  -- عنوان الجهاز اللي بيحاول (من هيدر الطلب)
  order_no text,
  success boolean not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);
create index tracking_attempts_key_time on public.tracking_attempts(client_key, created_at desc);
create index tracking_attempts_order_time on public.tracking_attempts(order_no, created_at desc);
alter table public.tracking_attempts enable row level security;
revoke all on public.tracking_attempts from anon, authenticated;
create trigger block_delete before delete on public.tracking_attempts for each row execute function public.tg_block_delete();

-- ---------- قرارات العميل على التكلفة ----------
create table public.quote_decisions (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references public.shops(id),
  device_id uuid not null references public.devices(id),
  decision text not null check (decision in ('approved', 'rejected')),
  amount integer check (amount between 0 and 2000000000), -- بالقروش: التكلفة اللي العميل وافق عليها أو رفضها
  client_key text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);
alter table public.quote_decisions enable row level security;
create policy quote_decisions_select on public.quote_decisions for select to authenticated
  using (shop_id = public.current_shop_id());
revoke insert, update, delete, truncate on public.quote_decisions from anon, authenticated;
grant select on public.quote_decisions to authenticated;
create trigger block_delete before delete on public.quote_decisions for each row execute function public.tg_block_delete();
create trigger immutable before update on public.quote_decisions for each row execute function public.tg_audit_immutable();

-- ---------- قوالب واتساب وسجل الرسايل ----------
create table public.message_templates (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references public.shops(id),
  key text not null check (key in ('received', 'status', 'approval', 'ready', 'reminder', 'delivered')),
  body text not null check (length(body) between 1 and 1000),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  unique (shop_id, key)
);
alter table public.message_templates enable row level security;
create policy templates_select on public.message_templates for select to authenticated using (shop_id = public.current_shop_id());
create policy templates_insert on public.message_templates for insert to authenticated
  with check (shop_id = public.current_shop_id() and public.current_app_role() = 'owner');
create policy templates_update on public.message_templates for update to authenticated
  using (shop_id = public.current_shop_id() and public.current_app_role() = 'owner') with check (shop_id = public.current_shop_id());
grant select, insert, update on public.message_templates to authenticated;

create table public.message_log (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references public.shops(id),
  device_id uuid references public.devices(id),
  customer_id uuid references public.customers(id),
  template_key text not null,
  body text not null,
  sent_by uuid references public.profiles(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);
alter table public.message_log enable row level security;
create policy message_log_select on public.message_log for select to authenticated
  using (shop_id = public.current_shop_id() and public.current_app_role() in ('owner', 'reception'));
create policy message_log_insert on public.message_log for insert to authenticated
  with check (shop_id = public.current_shop_id() and public.current_app_role() in ('owner', 'reception'));
grant select, insert on public.message_log to authenticated;

-- ---------- الفحص السريع ----------
create table public.device_checks (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references public.shops(id),
  device_id uuid not null references public.devices(id),
  stage text not null check (stage in ('intake', 'delivery')),
  items jsonb not null check (jsonb_typeof(items) = 'object'),
  checked_by uuid references public.profiles(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);
create unique index device_checks_one_per_stage on public.device_checks(device_id, stage) where deleted_at is null;
alter table public.device_checks enable row level security;
create policy checks_select on public.device_checks for select to authenticated using (shop_id = public.current_shop_id());
create policy checks_insert on public.device_checks for insert to authenticated with check (shop_id = public.current_shop_id());
create policy checks_update on public.device_checks for update to authenticated using (shop_id = public.current_shop_id()) with check (shop_id = public.current_shop_id());
grant select, insert, update on public.device_checks to authenticated;

create or replace function public.tg_check_author() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  new.checked_by := auth.uid();
  return new;
end $$;

-- الـ triggers العامة للجداول الجديدة
do $$
declare t text;
begin
  foreach t in array array['message_templates','message_log','device_checks'] loop
    execute format('create trigger set_updated_at before update on public.%I for each row execute function public.tg_set_updated_at()', t);
    execute format('create trigger block_delete before delete on public.%I for each row execute function public.tg_block_delete()', t);
    execute format('create trigger a_force_shop_id before insert or update on public.%I for each row execute function public.tg_force_shop_id()', t);
    execute format('create trigger zz_audit after insert or update on public.%I for each row execute function public.tg_audit()', t);
  end loop;
end $$;
create trigger zz_same_shop before insert or update on public.device_checks for each row execute function public.tg_same_shop_refs();
create trigger check_author before insert or update on public.device_checks for each row execute function public.tg_check_author();

-- ---------- حماية المحل: تعديل من غير مستخدم (من دوال التتبع بس) ----------
-- العميل من صفحة التتبع ملوش حساب، فالدالة الموثوقة (security definer) هي اللي بتعدّل.
-- الـ anon ملوش أي صلاحية مباشرة على الجداول، فالاستثناء ده بيشتغل من جوه الدوال بس، وبشرط إن المحل ما يتغيرش.
create or replace function public.tg_force_shop_id() returns trigger
language plpgsql security definer set search_path = public as $$
declare s uuid := public.current_shop_id();
begin
  if s is null then
    if tg_op = 'UPDATE' and auth.uid() is null and new.shop_id = old.shop_id then
      return new;
    end if;
    raise exception 'E_NO_SHOP';
  end if;
  if tg_op = 'INSERT' then
    new.shop_id := s;
  elsif new.shop_id is distinct from old.shop_id then
    raise exception 'E_SHOP_CHANGE';
  end if;
  return new;
end $$;

-- ---------- التتبع العام ----------
create or replace function public.tracking_client_key() returns text
language sql stable as $$
  select coalesce(
    nullif(split_part(coalesce(current_setting('request.headers', true)::json ->> 'x-forwarded-for', ''), ',', 1), ''),
    nullif(current_setting('request.headers', true)::json ->> 'x-real-ip', ''),
    'unknown')
$$;

-- يلاقي الجهاز برقم الطلب + (الرمز السري من الـ QR أو آخر 4 أرقام من موبايل العميل)
create or replace function public.tracking_find(p_order text, p_last4 text, p_token text)
returns public.devices
language plpgsql stable security definer set search_path = public as $$
declare d public.devices;
begin
  if p_token is not null and length(p_token) >= 16 then
    select * into d from public.devices where tracking_token = p_token and deleted_at is null;
    if found and (p_order is null or d.order_no = trim(p_order)) then return d; end if;
    return null;
  end if;
  if p_order is null or p_last4 is null or p_last4 !~ '^[0-9]{4}$' then return null; end if;
  select dv.* into d
  from public.devices dv join public.customers c on c.id = dv.customer_id
  where dv.order_no = trim(p_order) and right(c.phone, 4) = p_last4 and dv.deleted_at is null
  order by dv.received_at desc limit 1;
  if found then return d; end if;
  return null;
end $$;

-- حد المحاولات: 10 غلط في 15 دقيقة لنفس الجهاز، أو 5 غلط لنفس رقم الطلب
create or replace function public.tracking_guard(p_order text) returns text
language plpgsql security definer set search_path = public as $$
declare k text := public.tracking_client_key();
begin
  if (select count(*) from public.tracking_attempts where client_key = k and not success and created_at > now() - interval '15 minutes') >= 10
     or (p_order is not null and (select count(*) from public.tracking_attempts where order_no = trim(p_order) and not success and created_at > now() - interval '15 minutes') >= 5) then
    raise exception 'E_RATE_LIMIT';
  end if;
  return k;
end $$;

create or replace function public.get_tracking(p_order text default null, p_last4 text default null, p_token text default null)
returns table(
  order_no text, status public.device_status, brand text, model text, received_at timestamptz,
  updated_at timestamptz, estimated_cost integer, final_cost integer, technician text,
  shop_name text, shop_phone text, shop_logo text, currency text, warranty_until timestamptz,
  can_decide boolean, decision text
)
language plpgsql security definer set search_path = public as $$
declare
  k text := public.tracking_guard(p_order);
  d public.devices;
begin
  d := public.tracking_find(p_order, p_last4, p_token);
  if d.id is null then
    -- مش بنرمي خطأ هنا عشان المحاولة الغلط تفضل متسجلة (الخطأ بيلغي التسجيل). النتيجة الفاضية = مش موجود
    insert into public.tracking_attempts(client_key, order_no, success) values (k, trim(p_order), false);
    return;
  end if;
  insert into public.tracking_attempts(shop_id, client_key, order_no, success) values (d.shop_id, k, d.order_no, true);
  return query
  select d.order_no, d.status, d.brand, d.model, d.received_at,
    coalesce((select max(l.created_at) from public.status_log l where l.device_id = d.id), d.updated_at),
    dc.estimated_cost, dc.final_cost,
    -- اسم الفني: آخر فني غيّر الحالة (الاسم الأول بس)
    (select split_part(p.full_name, ' ', 1) from public.status_log l join public.profiles p on p.id = l.changed_by
       where l.device_id = d.id and p.role = 'technician' order by l.created_at desc limit 1),
    s.name, s.phone, s.logo_path, s.currency, d.warranty_until,
    d.status = 'awaiting_approval' and not exists (
      select 1 from public.quote_decisions q where q.device_id = d.id and q.created_at > coalesce(
        (select max(l.created_at) from public.status_log l where l.device_id = d.id and l.new_status = 'awaiting_approval'), d.received_at)),
    (select q.decision from public.quote_decisions q where q.device_id = d.id order by q.created_at desc limit 1)
  from public.shops s
  left join public.device_costs dc on dc.device_id = d.id and dc.deleted_at is null
  where s.id = d.shop_id;
end $$;

-- موافقة أو رفض العميل على التكلفة (من صفحة التتبع)
create or replace function public.decide_quote(p_decision text, p_order text default null, p_last4 text default null, p_token text default null)
returns public.device_status
language plpgsql security definer set search_path = public as $$
declare
  k text := public.tracking_guard(p_order);
  d public.devices;
  amt integer;
  next_status public.device_status;
begin
  if p_decision not in ('approved', 'rejected') then raise exception 'E_BAD_INPUT'; end if;
  d := public.tracking_find(p_order, p_last4, p_token);
  if d.id is null then
    insert into public.tracking_attempts(client_key, order_no, success) values (k, trim(p_order), false);
    return null;
  end if;
  if d.status <> 'awaiting_approval' then raise exception 'E_BAD_TRANSITION'; end if;
  select coalesce(final_cost, estimated_cost) into amt from public.device_costs where device_id = d.id and deleted_at is null;
  insert into public.quote_decisions(shop_id, device_id, decision, amount, client_key) values (d.shop_id, d.id, p_decision, amt, k);
  next_status := case when p_decision = 'approved' then 'in_repair'::public.device_status else 'unrepairable'::public.device_status end;
  update public.devices set status = next_status where id = d.id;
  insert into public.audit_log(shop_id, actor_id, action, entity, entity_id, after)
  values (d.shop_id, null, 'customer_' || p_decision, 'devices', d.id, jsonb_build_object('amount', amt, 'order_no', d.order_no));
  return next_status;
end $$;

revoke execute on function public.get_tracking(text, text, text) from public;
revoke execute on function public.decide_quote(text, text, text, text) from public;
revoke execute on function public.tracking_find(text, text, text) from public, anon, authenticated;
revoke execute on function public.tracking_guard(text) from public, anon, authenticated;
grant execute on function public.get_tracking(text, text, text) to anon, authenticated;
grant execute on function public.decide_quote(text, text, text, text) to anon, authenticated;

-- العرض محتاج رمز التتبع للـ QR والطباعة (لموظفين المحل بس، الـ RLS على الأجهزة)
create or replace view public.devices_list with (security_invoker = true) as
select d.id, d.shop_id, d.order_no, d.brand, d.model, d.imei, d.color, d.status,
       d.received_at, d.delivered_at, d.customer_id, d.deleted_at,
       c.name as customer_name, c.phone as customer_phone,
       dc.estimated_cost, dc.final_cost, d.warranty_until
from public.devices d
left join public.customers c on c.id = d.customer_id
left join public.device_costs dc on dc.device_id = d.id and dc.deleted_at is null;
grant select on public.devices_list to authenticated;

-- ---------- الزائر (anon) ملوش أي صلاحية مباشرة على أي جدول ----------
-- Supabase بيدّي anon صلاحيات تلقائية على الجداول الجديدة. الـ RLS بتمنع الصفوف، بس إحنا كمان بنشيل الصلاحية نفسها،
-- والوصول الوحيد للزائر هو دوال التتبع (get_tracking / decide_quote).
revoke all on all tables in schema public from anon;
revoke all on all sequences in schema public from anon;
alter default privileges in schema public revoke all on tables from anon;
alter default privileges in schema public revoke all on sequences from anon;
alter default privileges in schema public revoke execute on functions from anon;
$m0007$;
  insert into public.app_migrations(version, how) values ('0007_phase2_customer.sql', 'applied');
  raise notice 'applied %', '0007_phase2_customer.sql';
end $run$;
commit;

-- ============================== 0008_ledger.sql ==============================
begin;
do $run$ begin
  if exists (select 1 from public.app_migrations where version = '0008_ledger.sql') then return; end if;
  execute $m0008$
-- المرحلة 3: الفلوس بدفتر قيود مزدوج (docs/phase-3-ledger.md)
--
-- القواعد:
-- - كل حركة فلوس = قيد (journal_entries) فيه سطرين أو أكتر (journal_lines)، ومجموع المدين = مجموع الدائن بالظبط.
-- - الأرصدة مش متخزنة في أي مكان: كلها بتتحسب من سطور القيود.
-- - القيد ما بيتعدلش ولا بيتحذف أبدًا (حتى من SQL). الغلط بيتصلح بقيد عكسي مربوط بالأصلي.
-- - كل العمليات بدوال جوه قاعدة البيانات (كل دالة transaction واحدة): يا كله يتسجل يا ولا حاجة.
-- - المبالغ بالقروش أعداد صحيحة (bigint في الجمع).
-- - المخزون: الكمية والقيمة بتتحسب من حركات المخزون، والتكلفة بالمتوسط المرجّح.

-- ============================================================
-- 1) الحسابات
-- ============================================================
create type public.account_type as enum ('asset', 'liability', 'equity', 'revenue', 'expense');

create table public.accounts (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references public.shops(id),
  code text,                       -- للحسابات الأساسية (ar, ap, inventory, ...). الحسابات المضافة code = null
  name text,                       -- اسم مكتوب لحساب مضاف. الأساسية بتتترجم في الواجهة من code
  type public.account_type not null,
  kind text not null check (kind in ('cash', 'receivable', 'advances', 'inventory', 'payable', 'salaries', 'capital', 'drawings', 'revenue', 'cogs', 'expense', 'shortage', 'overage')),
  method text,                     -- للخزن: طريقة الدفع (cash, wallet, instapay, ...)
  holder_id uuid references public.profiles(id), -- للخزن: الموظف المسؤول عن الدرج
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  check (code is not null or nullif(trim(name), '') is not null),
  check ((kind = 'cash') = (method is not null)),
  check (holder_id is null or kind = 'cash')
);
create unique index accounts_code on public.accounts(shop_id, code) where code is not null;
create index accounts_shop on public.accounts(shop_id, kind);

-- الطرف الطبيعي للحساب: الأصول والمصروفات مدينة، والباقي دائن
create or replace function public.account_sign(t public.account_type) returns integer
language sql immutable as $$ select case when t in ('asset', 'expense') then 1 else -1 end $$;

-- ============================================================
-- 2) القيود
-- ============================================================
create table public.journal_entries (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references public.shops(id),
  entry_no bigint generated always as identity,
  occurred_at timestamptz not null default now(),
  source_type text not null check (source_type in ('payment', 'delivery', 'purchase', 'supplier_payment', 'part_use', 'sale', 'expense', 'salary', 'salary_payment', 'advance', 'advance_settle', 'capital', 'drawing', 'transfer', 'drawer_close', 'reversal')),
  source_id uuid,
  device_id uuid references public.devices(id),
  memo text check (length(memo) <= 500),
  idem_key uuid unique,            -- رقم العملية من التطبيق: نفس العملية لو اتبعتت مرتين ما تتسجلش مرتين
  reverses_id uuid unique references public.journal_entries(id),
  created_by uuid references public.profiles(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);
create index journal_entries_shop_time on public.journal_entries(shop_id, occurred_at);
create index journal_entries_source on public.journal_entries(source_type, source_id);

create table public.journal_lines (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references public.shops(id),
  entry_id uuid not null references public.journal_entries(id),
  account_id uuid not null references public.accounts(id),
  party_type text check (party_type in ('customer', 'supplier', 'employee')),
  party_id uuid,
  debit bigint not null default 0 check (debit >= 0 and debit <= 100000000000),
  credit bigint not null default 0 check (credit >= 0 and credit <= 100000000000),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  check ((debit > 0) <> (credit > 0)),
  check ((party_type is null) = (party_id is null))
);
create index journal_lines_entry on public.journal_lines(entry_id);
create index journal_lines_account on public.journal_lines(account_id);
create index journal_lines_party on public.journal_lines(party_type, party_id);

-- ============================================================
-- 3) الموردين والأصناف والمخزون والدفعات والدرج
-- ============================================================
create table public.suppliers (
  id uuid primary key,
  shop_id uuid not null references public.shops(id),
  name text not null check (length(trim(name)) between 1 and 120),
  phone text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

create table public.items (
  id uuid primary key,
  shop_id uuid not null references public.shops(id),
  kind text not null check (kind in ('part', 'accessory')),
  name text not null check (length(trim(name)) between 1 and 160),
  sku text,
  sale_price integer check (sale_price is null or sale_price between 0 and 2000000000),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

create table public.stock_moves (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references public.shops(id),
  item_id uuid not null references public.items(id),
  entry_id uuid not null references public.journal_entries(id),
  qty integer not null check (qty <> 0),
  value bigint not null,           -- القيمة بالقروش (موجبة للداخل وسالبة للخارج)
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);
create index stock_moves_item on public.stock_moves(item_id);

create table public.payments (
  id uuid primary key,
  shop_id uuid not null references public.shops(id),
  customer_id uuid not null references public.customers(id),
  device_id uuid references public.devices(id),
  cashbox_id uuid not null references public.accounts(id),
  method text not null,
  amount bigint not null check (amount > 0),
  entry_id uuid not null unique references public.journal_entries(id),
  created_by uuid references public.profiles(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);
create index payments_device on public.payments(device_id);

create table public.drawer_closings (
  id uuid primary key,
  shop_id uuid not null references public.shops(id),
  cashbox_id uuid not null references public.accounts(id),
  expected bigint not null,
  counted bigint not null check (counted >= 0),
  diff bigint not null,
  entry_id uuid references public.journal_entries(id),
  note text,
  closed_by uuid references public.profiles(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

-- ============================================================
-- 4) الحماية: ما بيتعدلش، وما بيتحذفش، والقيد لازم يتوازن
-- ============================================================
create or replace function public.tg_ledger_immutable() returns trigger
language plpgsql as $$
begin
  raise exception 'E_LEDGER_IMMUTABLE';
end $$;

do $$
declare t text;
begin
  foreach t in array array['journal_entries', 'journal_lines', 'stock_moves', 'payments', 'drawer_closings'] loop
    execute format('create trigger ledger_immutable before update or delete on public.%I for each row execute function public.tg_ledger_immutable()', t);
    execute format('create trigger ledger_no_truncate before truncate on public.%I for each statement execute function public.tg_ledger_immutable()', t);
  end loop;
  foreach t in array array['accounts', 'suppliers', 'items'] loop
    execute format('create trigger set_updated_at before update on public.%I for each row execute function public.tg_set_updated_at()', t);
    execute format('create trigger block_delete before delete on public.%I for each row execute function public.tg_block_delete()', t);
    execute format('create trigger a_force_shop_id before insert or update on public.%I for each row execute function public.tg_force_shop_id()', t);
  end loop;
  foreach t in array array['accounts', 'suppliers', 'items', 'journal_entries', 'payments', 'drawer_closings'] loop
    execute format('create trigger zz_audit after insert or update on public.%I for each row execute function public.tg_audit()', t);
  end loop;
end $$;

-- التوازن بيتراجع في آخر الـ transaction (deferred): أي قيد مش متوازن = الـ transaction كلها بتتلغي
-- security definer: الفحص بيحصل في آخر العملية بصلاحيات المستخدم، والمستخدم (زي الاستقبال) ما بيشوفش السطور
create or replace function public.tg_entry_balanced() returns trigger
language plpgsql security definer set search_path = public as $$
declare d bigint; c bigint; n int;
begin
  select coalesce(sum(debit), 0), coalesce(sum(credit), 0), count(*) into d, c, n from public.journal_lines where entry_id = new.entry_id;
  if n < 2 or d <> c then
    raise exception 'E_UNBALANCED';
  end if;
  return null;
end $$;
create constraint trigger entry_balanced after insert on public.journal_lines
  deferrable initially deferred for each row execute function public.tg_entry_balanced();

-- ============================================================
-- 5) الحسابات الأساسية لكل محل
-- ============================================================
create or replace function public.ensure_ledger_accounts(p_shop uuid) returns void
language plpgsql security definer set search_path = public as $$
declare m text;
begin
  insert into public.accounts(shop_id, code, type, kind)
  select p_shop, v.code, v.type::public.account_type, v.kind from (values
    ('ar', 'asset', 'receivable'), ('advances', 'asset', 'advances'), ('inventory', 'asset', 'inventory'),
    ('ap', 'liability', 'payable'), ('salaries_payable', 'liability', 'salaries'),
    ('capital', 'equity', 'capital'), ('drawings', 'equity', 'drawings'),
    ('rev_repair', 'revenue', 'revenue'), ('rev_parts', 'revenue', 'revenue'), ('rev_accessories', 'revenue', 'revenue'), ('overage', 'revenue', 'overage'),
    ('cogs', 'expense', 'cogs'), ('shortage', 'expense', 'shortage'),
    ('exp_salaries', 'expense', 'expense'), ('exp_rent', 'expense', 'expense'), ('exp_electricity', 'expense', 'expense'),
    ('exp_internet', 'expense', 'expense'), ('exp_purchases', 'expense', 'expense')
  ) as v(code, type, kind)
  on conflict (shop_id, code) where code is not null do nothing;
  -- خزنة لكل طريقة دفع مفعّلة في المحل
  for m in select unnest(payment_methods) from public.shops where id = p_shop loop
    insert into public.accounts(shop_id, code, type, kind, method)
    values (p_shop, 'cash_' || m, 'asset', 'cash', m)
    on conflict (shop_id, code) where code is not null do nothing;
  end loop;
end $$;
revoke execute on function public.ensure_ledger_accounts(uuid) from public, anon, authenticated;

-- إضافة الحسابات بتحصل من غير مستخدم (trigger على المحل)، فبنعدّي force_shop_id بإعداد مؤقت
create or replace function public.tg_force_shop_id() returns trigger
language plpgsql security definer set search_path = public as $$
declare s uuid := public.current_shop_id();
begin
  if current_setting('warsha.system', true) = 'on' then
    return new;
  end if;
  if s is null then
    if tg_op = 'UPDATE' and auth.uid() is null and new.shop_id = old.shop_id then
      return new;
    end if;
    raise exception 'E_NO_SHOP';
  end if;
  if tg_op = 'INSERT' then
    new.shop_id := s;
  elsif new.shop_id is distinct from old.shop_id then
    raise exception 'E_SHOP_CHANGE';
  end if;
  return new;
end $$;

create or replace function public.tg_shop_ledger() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  perform set_config('warsha.system', 'on', true);
  perform public.ensure_ledger_accounts(new.id);
  perform set_config('warsha.system', 'off', true);
  return null;
end $$;
create trigger zz_shop_ledger after insert or update of payment_methods on public.shops
  for each row execute function public.tg_shop_ledger();

-- المحلات الموجودة قبل كده
do $$
declare s uuid;
begin
  perform set_config('warsha.system', 'on', true);
  for s in select id from public.shops loop
    perform public.ensure_ledger_accounts(s);
  end loop;
  perform set_config('warsha.system', 'off', true);
end $$;

-- ============================================================
-- 6) تسجيل قيد (داخلية: الدوال بس هي اللي بتناديها)
-- ============================================================
-- p_lines: [{"account": uuid, "debit": n, "credit": n, "party_type": "...", "party_id": uuid}]
create or replace function public.ledger_post(
  p_source_type text, p_source_id uuid, p_memo text, p_lines jsonb,
  p_device uuid default null, p_idem uuid default null, p_reverses uuid default null
) returns uuid
language plpgsql security definer set search_path = public as $$
declare
  s uuid := public.current_shop_id();
  e uuid := gen_random_uuid();
  l jsonb;
  a public.accounts;
  d bigint := 0;
  c bigint := 0;
  ld bigint;
  lc bigint;
begin
  if s is null then raise exception 'E_NO_SHOP'; end if;
  if jsonb_typeof(p_lines) <> 'array' or jsonb_array_length(p_lines) < 2 then raise exception 'E_UNBALANCED'; end if;
  insert into public.journal_entries(id, shop_id, source_type, source_id, device_id, memo, idem_key, reverses_id, created_by)
  values (e, s, p_source_type, p_source_id, p_device, nullif(trim(p_memo), ''), p_idem, p_reverses, auth.uid());
  for l in select * from jsonb_array_elements(p_lines) loop
    select * into a from public.accounts where id = (l ->> 'account')::uuid and shop_id = s and deleted_at is null;
    if not found then raise exception 'E_BAD_ACCOUNT'; end if;
    ld := coalesce((l ->> 'debit')::bigint, 0);
    lc := coalesce((l ->> 'credit')::bigint, 0);
    if ld < 0 or lc < 0 or (ld > 0) = (lc > 0) then raise exception 'E_BAD_AMOUNT'; end if;
    -- العملاء والموردين والموظفين لازم يبقى معاهم الطرف
    if a.kind in ('receivable', 'payable', 'advances', 'salaries') and (l ->> 'party_id') is null then raise exception 'E_BAD_INPUT'; end if;
    insert into public.journal_lines(shop_id, entry_id, account_id, party_type, party_id, debit, credit)
    values (s, e, a.id, l ->> 'party_type', (l ->> 'party_id')::uuid, ld, lc);
    d := d + ld;
    c := c + lc;
  end loop;
  if d <> c or d = 0 then raise exception 'E_UNBALANCED'; end if;
  return e;
end $$;
revoke execute on function public.ledger_post(text, uuid, text, jsonb, uuid, uuid, uuid) from public, anon, authenticated;

-- أدوات صغيرة للدوال
create or replace function public.ledger_require(p_roles public.app_role[]) returns void
language plpgsql stable security definer set search_path = public as $$
begin
  if public.current_app_role() is null or not (public.current_app_role() = any(p_roles)) then
    raise exception 'E_FORBIDDEN';
  end if;
end $$;

create or replace function public.ledger_acc(p_code text) returns uuid
language sql stable security definer set search_path = public as $$
  select id from public.accounts where shop_id = public.current_shop_id() and code = p_code and deleted_at is null
$$;

create or replace function public.ledger_amount(p bigint) returns bigint
language plpgsql immutable as $$
begin
  if p is null or p <= 0 or p > 100000000000 then raise exception 'E_BAD_AMOUNT'; end if;
  return p;
end $$;

-- خزنة شغالة في المحل
create or replace function public.ledger_cashbox(p uuid) returns public.accounts
language plpgsql stable security definer set search_path = public as $$
declare a public.accounts;
begin
  select * into a from public.accounts where id = p and shop_id = public.current_shop_id() and kind = 'cash' and active and deleted_at is null;
  if not found then raise exception 'E_BAD_ACCOUNT'; end if;
  return a;
end $$;

create or replace function public.ledger_idem(p uuid) returns uuid
language sql stable security definer set search_path = public as $$
  select id from public.journal_entries where idem_key = p and shop_id = public.current_shop_id()
$$;

create or replace function public.ledger_line(p_acc uuid, p_debit bigint, p_credit bigint, p_party_type text default null, p_party uuid default null) returns jsonb
language sql immutable as $$
  select jsonb_strip_nulls(jsonb_build_object('account', p_acc, 'debit', p_debit, 'credit', p_credit, 'party_type', p_party_type, 'party_id', p_party))
$$;

-- رصيد حساب (اختياري: لطرف معيّن، ولحد وقت معيّن)
create or replace function public.ledger_balance(p_acc uuid, p_party uuid default null, p_before timestamptz default null) returns bigint
language sql stable security definer set search_path = public as $$
  select coalesce(sum((l.debit - l.credit) * public.account_sign(a.type)), 0)::bigint
  from public.journal_lines l
  join public.accounts a on a.id = l.account_id
  join public.journal_entries e on e.id = l.entry_id
  where l.account_id = p_acc and (p_party is null or l.party_id = p_party) and (p_before is null or e.occurred_at < p_before)
$$;

do $$
declare f text;
begin
  foreach f in array array['ledger_require(public.app_role[])', 'ledger_acc(text)', 'ledger_cashbox(uuid)', 'ledger_idem(uuid)', 'ledger_balance(uuid, uuid, timestamptz)'] loop
    execute format('revoke execute on function public.%s from public, anon, authenticated', f);
  end loop;
end $$;

-- ============================================================
-- 7) العمليات
-- ============================================================

-- دفعة من عميل (على جهاز أو من غير جهاز): تدخل الخزنة وتقلل دين العميل
create or replace function public.record_payment(p_id uuid, p_customer uuid, p_cashbox uuid, p_amount bigint, p_device uuid default null, p_method text default null, p_note text default null)
returns uuid
language plpgsql security definer set search_path = public as $$
declare
  cb public.accounts;
  e uuid;
  dev public.devices;
begin
  perform public.ledger_require(array['owner', 'reception']::public.app_role[]);
  e := public.ledger_idem(p_id);
  if e is not null then return e; end if;
  perform public.ledger_amount(p_amount);
  cb := public.ledger_cashbox(p_cashbox);
  if not exists (select 1 from public.customers where id = p_customer and shop_id = cb.shop_id and deleted_at is null) then raise exception 'E_NOT_FOUND'; end if;
  if p_device is not null then
    select * into dev from public.devices where id = p_device and shop_id = cb.shop_id and deleted_at is null;
    if not found or dev.customer_id <> p_customer then raise exception 'E_CROSS_SHOP'; end if;
  end if;
  e := public.ledger_post('payment', p_id, p_note, jsonb_build_array(
    public.ledger_line(cb.id, p_amount, 0),
    public.ledger_line(public.ledger_acc('ar'), 0, p_amount, 'customer', p_customer)
  ), p_device, p_id);
  insert into public.payments(id, shop_id, customer_id, device_id, cashbox_id, method, amount, entry_id, created_by)
  values (p_id, cb.shop_id, p_customer, p_device, cb.id, coalesce(p_method, cb.method), p_amount, e, auth.uid());
  return e;
end $$;

-- قيد عكسي: بيعكس كل سطور القيد الأصلي (وحركات المخزون لو فيه)، ومربوط بيه، وبيتسجل في السجل باسم مين وليه
create or replace function public.reverse_entry(p_entry uuid, p_reason text)
returns uuid
language plpgsql security definer set search_path = public as $$
declare
  o public.journal_entries;
  e uuid;
  lines jsonb;
  mv record;
begin
  perform public.ledger_require(array['owner']::public.app_role[]);
  if nullif(trim(p_reason), '') is null then raise exception 'E_BAD_INPUT'; end if;
  select * into o from public.journal_entries where id = p_entry and shop_id = public.current_shop_id() for update;
  if not found then raise exception 'E_NOT_FOUND'; end if;
  if o.source_type = 'reversal' or exists (select 1 from public.journal_entries where reverses_id = o.id) then
    raise exception 'E_ALREADY_REVERSED';
  end if;
  select jsonb_agg(public.ledger_line(account_id, credit, debit, party_type, party_id)) into lines
  from public.journal_lines where entry_id = o.id;
  e := public.ledger_post('reversal', o.source_id, p_reason, lines, o.device_id, null, o.id);
  for mv in select * from public.stock_moves where entry_id = o.id loop
    perform 1 from public.items where id = mv.item_id for update;
    if (select coalesce(sum(qty), 0) from public.stock_moves where item_id = mv.item_id) - mv.qty < 0 then
      raise exception 'E_STOCK';
    end if;
    insert into public.stock_moves(shop_id, item_id, entry_id, qty, value) values (mv.shop_id, mv.item_id, e, -mv.qty, -mv.value);
  end loop;
  insert into public.audit_log(shop_id, actor_id, action, entity, entity_id, before, after)
  values (o.shop_id, auth.uid(), 'reverse_entry', 'journal_entries', o.id, to_jsonb(o), jsonb_build_object('reversal_id', e, 'reason', p_reason));
  return e;
end $$;

-- تحويل بين خزنتين بقيد واحد
create or replace function public.transfer_cash(p_id uuid, p_from uuid, p_to uuid, p_amount bigint, p_note text default null)
returns uuid
language plpgsql security definer set search_path = public as $$
declare a public.accounts; b public.accounts; e uuid;
begin
  perform public.ledger_require(array['owner']::public.app_role[]);
  e := public.ledger_idem(p_id);
  if e is not null then return e; end if;
  perform public.ledger_amount(p_amount);
  a := public.ledger_cashbox(p_from);
  b := public.ledger_cashbox(p_to);
  if a.id = b.id then raise exception 'E_SAME_CASHBOX'; end if;
  if public.ledger_balance(a.id) < p_amount then raise exception 'E_INSUFFICIENT'; end if;
  return public.ledger_post('transfer', p_id, p_note, jsonb_build_array(public.ledger_line(b.id, p_amount, 0), public.ledger_line(a.id, 0, p_amount)), null, p_id);
end $$;

-- مصروف: يخرج من الخزنة المختارة
create or replace function public.record_expense(p_id uuid, p_account uuid, p_cashbox uuid, p_amount bigint, p_note text default null)
returns uuid
language plpgsql security definer set search_path = public as $$
declare cb public.accounts; e uuid;
begin
  perform public.ledger_require(array['owner']::public.app_role[]);
  e := public.ledger_idem(p_id);
  if e is not null then return e; end if;
  perform public.ledger_amount(p_amount);
  cb := public.ledger_cashbox(p_cashbox);
  if not exists (select 1 from public.accounts where id = p_account and shop_id = cb.shop_id and kind = 'expense' and active and deleted_at is null) then raise exception 'E_BAD_ACCOUNT'; end if;
  return public.ledger_post('expense', p_id, p_note, jsonb_build_array(public.ledger_line(p_account, p_amount, 0), public.ledger_line(cb.id, 0, p_amount)), null, p_id);
end $$;

-- رأس مال داخل، أو سحب صاحب المحل (السحب بيقلل رأس المال، مش مصروف)
create or replace function public.owner_capital(p_id uuid, p_cashbox uuid, p_amount bigint, p_note text default null)
returns uuid
language plpgsql security definer set search_path = public as $$
declare cb public.accounts; e uuid;
begin
  perform public.ledger_require(array['owner']::public.app_role[]);
  e := public.ledger_idem(p_id);
  if e is not null then return e; end if;
  perform public.ledger_amount(p_amount);
  cb := public.ledger_cashbox(p_cashbox);
  return public.ledger_post('capital', p_id, p_note, jsonb_build_array(public.ledger_line(cb.id, p_amount, 0), public.ledger_line(public.ledger_acc('capital'), 0, p_amount)), null, p_id);
end $$;

create or replace function public.owner_drawing(p_id uuid, p_cashbox uuid, p_amount bigint, p_note text default null)
returns uuid
language plpgsql security definer set search_path = public as $$
declare cb public.accounts; e uuid;
begin
  perform public.ledger_require(array['owner']::public.app_role[]);
  e := public.ledger_idem(p_id);
  if e is not null then return e; end if;
  perform public.ledger_amount(p_amount);
  cb := public.ledger_cashbox(p_cashbox);
  return public.ledger_post('drawing', p_id, p_note, jsonb_build_array(public.ledger_line(public.ledger_acc('drawings'), p_amount, 0), public.ledger_line(cb.id, 0, p_amount)), null, p_id);
end $$;

-- الموظفين: مرتب مستحق، صرف مرتب، سلفة، خصم سلفة من المرتب
create or replace function public.ledger_employee(p uuid) returns void
language plpgsql stable security definer set search_path = public as $$
begin
  if not exists (select 1 from public.profiles where id = p and shop_id = public.current_shop_id()) then raise exception 'E_NOT_FOUND'; end if;
end $$;
revoke execute on function public.ledger_employee(uuid) from public, anon, authenticated;

create or replace function public.accrue_salary(p_id uuid, p_employee uuid, p_amount bigint, p_note text default null)
returns uuid
language plpgsql security definer set search_path = public as $$
declare e uuid;
begin
  perform public.ledger_require(array['owner']::public.app_role[]);
  e := public.ledger_idem(p_id);
  if e is not null then return e; end if;
  perform public.ledger_amount(p_amount);
  perform public.ledger_employee(p_employee);
  return public.ledger_post('salary', p_id, p_note, jsonb_build_array(
    public.ledger_line(public.ledger_acc('exp_salaries'), p_amount, 0),
    public.ledger_line(public.ledger_acc('salaries_payable'), 0, p_amount, 'employee', p_employee)), null, p_id);
end $$;

create or replace function public.pay_salary(p_id uuid, p_employee uuid, p_cashbox uuid, p_amount bigint, p_note text default null)
returns uuid
language plpgsql security definer set search_path = public as $$
declare cb public.accounts; e uuid;
begin
  perform public.ledger_require(array['owner']::public.app_role[]);
  e := public.ledger_idem(p_id);
  if e is not null then return e; end if;
  perform public.ledger_amount(p_amount);
  perform public.ledger_employee(p_employee);
  cb := public.ledger_cashbox(p_cashbox);
  return public.ledger_post('salary_payment', p_id, p_note, jsonb_build_array(
    public.ledger_line(public.ledger_acc('salaries_payable'), p_amount, 0, 'employee', p_employee),
    public.ledger_line(cb.id, 0, p_amount)), null, p_id);
end $$;

create or replace function public.give_advance(p_id uuid, p_employee uuid, p_cashbox uuid, p_amount bigint, p_note text default null)
returns uuid
language plpgsql security definer set search_path = public as $$
declare cb public.accounts; e uuid;
begin
  perform public.ledger_require(array['owner']::public.app_role[]);
  e := public.ledger_idem(p_id);
  if e is not null then return e; end if;
  perform public.ledger_amount(p_amount);
  perform public.ledger_employee(p_employee);
  cb := public.ledger_cashbox(p_cashbox);
  return public.ledger_post('advance', p_id, p_note, jsonb_build_array(
    public.ledger_line(public.ledger_acc('advances'), p_amount, 0, 'employee', p_employee),
    public.ledger_line(cb.id, 0, p_amount)), null, p_id);
end $$;

create or replace function public.settle_advance(p_id uuid, p_employee uuid, p_amount bigint, p_note text default null)
returns uuid
language plpgsql security definer set search_path = public as $$
declare e uuid;
begin
  perform public.ledger_require(array['owner']::public.app_role[]);
  e := public.ledger_idem(p_id);
  if e is not null then return e; end if;
  perform public.ledger_amount(p_amount);
  perform public.ledger_employee(p_employee);
  return public.ledger_post('advance_settle', p_id, p_note, jsonb_build_array(
    public.ledger_line(public.ledger_acc('salaries_payable'), p_amount, 0, 'employee', p_employee),
    public.ledger_line(public.ledger_acc('advances'), 0, p_amount, 'employee', p_employee)), null, p_id);
end $$;

-- ---------- المخزون ----------
-- الكمية والقيمة الحالية لصنف (من حركاته)
create or replace function public.item_stock(p_item uuid, out qty bigint, out value bigint)
language sql stable security definer set search_path = public as $$
  select coalesce(sum(m.qty), 0)::bigint, coalesce(sum(m.value), 0)::bigint from public.stock_moves m where m.item_id = p_item
$$;
revoke execute on function public.item_stock(uuid) from public, anon, authenticated;

-- تكلفة خروج n من صنف بالمتوسط المرجّح. لو خرج كل الموجود بتطلع القيمة كلها بالظبط (من غير ما يفضل كسور)
create or replace function public.ledger_issue_cost(p_qty bigint, p_value bigint, n bigint) returns bigint
language sql immutable as $$
  select case when n = p_qty then p_value else (p_value * n + p_qty / 2) / p_qty end
$$;

-- شراء قطع أو إكسسوارات من مورد: نقدي (من خزنة) أو آجل (على المورد)
-- p_lines: [{"item": uuid, "qty": n, "unit_cost": n}]
create or replace function public.record_purchase(p_id uuid, p_supplier uuid, p_lines jsonb, p_cashbox uuid default null, p_note text default null)
returns uuid
language plpgsql security definer set search_path = public as $$
declare
  s uuid := public.current_shop_id();
  l jsonb;
  total bigint := 0;
  q bigint;
  u bigint;
  e uuid;
  credit_line jsonb;
begin
  perform public.ledger_require(array['owner']::public.app_role[]);
  e := public.ledger_idem(p_id);
  if e is not null then return e; end if;
  if not exists (select 1 from public.suppliers where id = p_supplier and shop_id = s and deleted_at is null) then raise exception 'E_NOT_FOUND'; end if;
  if jsonb_typeof(p_lines) <> 'array' or jsonb_array_length(p_lines) = 0 then raise exception 'E_BAD_INPUT'; end if;
  for l in select * from jsonb_array_elements(p_lines) loop
    q := (l ->> 'qty')::bigint;
    u := (l ->> 'unit_cost')::bigint;
    if q is null or q <= 0 or q > 100000 or u is null or u < 0 then raise exception 'E_BAD_AMOUNT'; end if;
    if not exists (select 1 from public.items where id = (l ->> 'item')::uuid and shop_id = s and deleted_at is null) then raise exception 'E_NOT_FOUND'; end if;
    total := total + q * u;
  end loop;
  perform public.ledger_amount(total);
  credit_line := case when p_cashbox is null
    then public.ledger_line(public.ledger_acc('ap'), 0, total, 'supplier', p_supplier)
    else public.ledger_line((public.ledger_cashbox(p_cashbox)).id, 0, total) end;
  e := public.ledger_post('purchase', p_id, p_note, jsonb_build_array(public.ledger_line(public.ledger_acc('inventory'), total, 0), credit_line), null, p_id);
  for l in select * from jsonb_array_elements(p_lines) loop
    insert into public.stock_moves(shop_id, item_id, entry_id, qty, value)
    values (s, (l ->> 'item')::uuid, e, (l ->> 'qty')::int, (l ->> 'qty')::bigint * (l ->> 'unit_cost')::bigint);
  end loop;
  return e;
end $$;

create or replace function public.pay_supplier(p_id uuid, p_supplier uuid, p_cashbox uuid, p_amount bigint, p_note text default null)
returns uuid
language plpgsql security definer set search_path = public as $$
declare cb public.accounts; e uuid;
begin
  perform public.ledger_require(array['owner']::public.app_role[]);
  e := public.ledger_idem(p_id);
  if e is not null then return e; end if;
  perform public.ledger_amount(p_amount);
  cb := public.ledger_cashbox(p_cashbox);
  if not exists (select 1 from public.suppliers where id = p_supplier and shop_id = cb.shop_id and deleted_at is null) then raise exception 'E_NOT_FOUND'; end if;
  return public.ledger_post('supplier_payment', p_id, p_note, jsonb_build_array(
    public.ledger_line(public.ledger_acc('ap'), p_amount, 0, 'supplier', p_supplier),
    public.ledger_line(cb.id, 0, p_amount)), null, p_id);
end $$;

-- خروج صنف من المخزون (داخلية): بيرجّع التكلفة
create or replace function public.ledger_issue(p_item uuid, p_qty bigint, p_entry uuid) returns bigint
language plpgsql security definer set search_path = public as $$
declare st record; cost bigint;
begin
  perform 1 from public.items where id = p_item and shop_id = public.current_shop_id() and deleted_at is null for update;
  if not found then raise exception 'E_NOT_FOUND'; end if;
  select * into st from public.item_stock(p_item);
  if p_qty <= 0 or st.qty < p_qty then raise exception 'E_STOCK'; end if;
  cost := public.ledger_issue_cost(st.qty, st.value, p_qty);
  insert into public.stock_moves(shop_id, item_id, entry_id, qty, value) values (public.current_shop_id(), p_item, p_entry, -p_qty, -cost);
  return cost;
end $$;
revoke execute on function public.ledger_issue(uuid, bigint, uuid) from public, anon, authenticated;

-- قطعة اتركبت في جهاز: تخرج من المخزون كتكلفة على الجهاز (الفني يقدر يسجلها من غير ما يشوف السعر)
create or replace function public.use_part(p_id uuid, p_device uuid, p_item uuid, p_qty integer default 1)
returns uuid
language plpgsql security definer set search_path = public as $$
declare
  e uuid;
  cost bigint;
  inv uuid := public.ledger_acc('inventory');
  cg uuid := public.ledger_acc('cogs');
begin
  perform public.ledger_require(array['owner', 'technician']::public.app_role[]);
  e := public.ledger_idem(p_id);
  if e is not null then return e; end if;
  if not exists (select 1 from public.devices where id = p_device and shop_id = public.current_shop_id() and deleted_at is null and status <> 'delivered') then raise exception 'E_NOT_FOUND'; end if;
  -- القيد محتاج يتعمل الأول عشان حركة المخزون تتربط بيه، والتوازن بيتراجع في آخر العملية
  e := gen_random_uuid();
  insert into public.journal_entries(id, shop_id, source_type, source_id, device_id, idem_key, created_by)
  values (e, public.current_shop_id(), 'part_use', p_item, p_device, p_id, auth.uid());
  cost := public.ledger_issue(p_item, p_qty, e);
  if cost > 0 then
    insert into public.journal_lines(shop_id, entry_id, account_id, debit, credit) values
      (public.current_shop_id(), e, cg, cost, 0),
      (public.current_shop_id(), e, inv, 0, cost);
  else
    raise exception 'E_BAD_AMOUNT';  -- صنف من غير تكلفة: لازم يتشتري بسعر الأول
  end if;
  return e;
end $$;

-- بيع قطع أو إكسسوارات على الكاونتر
-- p_lines: [{"item": uuid, "qty": n, "price": n}]
create or replace function public.record_sale(p_id uuid, p_lines jsonb, p_cashbox uuid default null, p_customer uuid default null, p_note text default null)
returns uuid
language plpgsql security definer set search_path = public as $$
declare
  s uuid := public.current_shop_id();
  e uuid := gen_random_uuid();
  l jsonb;
  it public.items;
  q bigint; p bigint; cost bigint;
  rev_parts bigint := 0; rev_acc bigint := 0; total_cost bigint := 0;
  debit_acc uuid; pt text; pid uuid;
begin
  perform public.ledger_require(array['owner', 'reception']::public.app_role[]);
  if public.ledger_idem(p_id) is not null then return public.ledger_idem(p_id); end if;
  -- البيع بالآجل لصاحب المحل بس
  if p_cashbox is null and (p_customer is null or public.current_app_role() <> 'owner') then raise exception 'E_BAD_INPUT'; end if;
  if p_customer is not null and not exists (select 1 from public.customers where id = p_customer and shop_id = s and deleted_at is null) then raise exception 'E_NOT_FOUND'; end if;
  if jsonb_typeof(p_lines) <> 'array' or jsonb_array_length(p_lines) = 0 then raise exception 'E_BAD_INPUT'; end if;
  insert into public.journal_entries(id, shop_id, source_type, source_id, memo, idem_key, created_by)
  values (e, s, 'sale', p_id, nullif(trim(p_note), ''), p_id, auth.uid());
  for l in select * from jsonb_array_elements(p_lines) loop
    select * into it from public.items where id = (l ->> 'item')::uuid and shop_id = s and deleted_at is null;
    if not found then raise exception 'E_NOT_FOUND'; end if;
    q := (l ->> 'qty')::bigint;
    p := (l ->> 'price')::bigint;
    if q is null or q <= 0 or p is null or p < 0 then raise exception 'E_BAD_AMOUNT'; end if;
    cost := public.ledger_issue(it.id, q, e);
    total_cost := total_cost + cost;
    if it.kind = 'part' then rev_parts := rev_parts + q * p; else rev_acc := rev_acc + q * p; end if;
  end loop;
  perform public.ledger_amount(rev_parts + rev_acc);
  if p_cashbox is null then
    debit_acc := public.ledger_acc('ar'); pt := 'customer'; pid := p_customer;
  else
    debit_acc := (public.ledger_cashbox(p_cashbox)).id;
  end if;
  insert into public.journal_lines(shop_id, entry_id, account_id, party_type, party_id, debit, credit)
  values (s, e, debit_acc, pt, pid, rev_parts + rev_acc, 0);
  if rev_parts > 0 then insert into public.journal_lines(shop_id, entry_id, account_id, debit, credit) values (s, e, public.ledger_acc('rev_parts'), 0, rev_parts); end if;
  if rev_acc > 0 then insert into public.journal_lines(shop_id, entry_id, account_id, debit, credit) values (s, e, public.ledger_acc('rev_accessories'), 0, rev_acc); end if;
  if total_cost > 0 then
    insert into public.journal_lines(shop_id, entry_id, account_id, debit, credit) values
      (s, e, public.ledger_acc('cogs'), total_cost, 0), (s, e, public.ledger_acc('inventory'), 0, total_cost);
  end if;
  if p_cashbox is not null and p_customer is not null then
    null; -- البيع النقدي لعميل معروف ما بيأثرش على رصيده
  end if;
  return e;
end $$;

-- ---------- الدرج ----------
-- الخزن اللي أقدر أقفلها، بالمتوقع فيها (الاستقبال: الخزن اللي هو مسؤول عنها بس)
create or replace function public.my_drawers()
returns table(id uuid, code text, name text, method text, expected bigint)
language plpgsql stable security definer set search_path = public as $$
begin
  perform public.ledger_require(array['owner', 'reception']::public.app_role[]);
  return query
  select a.id, a.code, a.name, a.method, public.ledger_balance(a.id)
  from public.accounts a
  where a.shop_id = public.current_shop_id() and a.kind = 'cash' and a.active and a.deleted_at is null
    and (public.current_app_role() = 'owner' or a.holder_id = auth.uid())
  order by a.created_at;
end $$;

-- تقفيل الدرج: المتوقع من النظام والفعلي، والفرق بيتسجل قيد عجز أو زيادة باسم الموظف
create or replace function public.close_drawer(p_id uuid, p_cashbox uuid, p_counted bigint, p_note text default null)
returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  cb public.accounts;
  exp bigint;
  d bigint;
  e uuid;
  r public.drawer_closings;
begin
  perform public.ledger_require(array['owner', 'reception']::public.app_role[]);
  select * into r from public.drawer_closings where id = p_id and shop_id = public.current_shop_id();
  if found then return jsonb_build_object('expected', r.expected, 'counted', r.counted, 'diff', r.diff); end if;
  cb := public.ledger_cashbox(p_cashbox);
  if public.current_app_role() <> 'owner' and cb.holder_id is distinct from auth.uid() then raise exception 'E_FORBIDDEN'; end if;
  if p_counted is null or p_counted < 0 or p_counted > 100000000000 then raise exception 'E_BAD_AMOUNT'; end if;
  perform 1 from public.accounts where id = cb.id for update;  -- ما يحصلش تقفيلين في نفس اللحظة
  exp := public.ledger_balance(cb.id);
  d := p_counted - exp;
  if d < 0 then
    e := public.ledger_post('drawer_close', p_id, p_note, jsonb_build_array(public.ledger_line(public.ledger_acc('shortage'), -d, 0), public.ledger_line(cb.id, 0, -d)), null, p_id);
  elsif d > 0 then
    e := public.ledger_post('drawer_close', p_id, p_note, jsonb_build_array(public.ledger_line(cb.id, d, 0), public.ledger_line(public.ledger_acc('overage'), 0, d)), null, p_id);
  end if;
  insert into public.drawer_closings(id, shop_id, cashbox_id, expected, counted, diff, entry_id, note, closed_by)
  values (p_id, cb.shop_id, cb.id, exp, p_counted, d, e, nullif(trim(p_note), ''), auth.uid());
  return jsonb_build_object('expected', exp, 'counted', p_counted, 'diff', d);
end $$;

-- ---------- الحسابات المضافة ----------
create or replace function public.add_account(p_id uuid, p_kind text, p_name text, p_method text default null, p_holder uuid default null)
returns uuid
language plpgsql security definer set search_path = public as $$
begin
  perform public.ledger_require(array['owner']::public.app_role[]);
  if p_kind not in ('cash', 'expense') or nullif(trim(p_name), '') is null or length(p_name) > 80 then raise exception 'E_BAD_INPUT'; end if;
  if p_kind = 'cash' and (p_method is null or not public.valid_payment_methods(array[p_method])) then raise exception 'E_BAD_INPUT'; end if;
  if p_holder is not null and not exists (select 1 from public.profiles where id = p_holder and shop_id = public.current_shop_id() and deleted_at is null) then raise exception 'E_NOT_FOUND'; end if;
  insert into public.accounts(id, shop_id, name, type, kind, method, holder_id)
  values (p_id, public.current_shop_id(), trim(p_name), case when p_kind = 'cash' then 'asset' else 'expense' end::public.account_type, p_kind,
          case when p_kind = 'cash' then p_method end, case when p_kind = 'cash' then p_holder end);
  return p_id;
end $$;

-- تعديل خزنة أو بند مصروف: الاسم، والمسؤول، والتفعيل. النوع والطريقة ما بيتغيروش
create or replace function public.update_account(p_id uuid, p_name text default null, p_holder uuid default null, p_active boolean default null, p_clear_holder boolean default false)
returns void
language plpgsql security definer set search_path = public as $$
declare a public.accounts;
begin
  perform public.ledger_require(array['owner']::public.app_role[]);
  select * into a from public.accounts where id = p_id and shop_id = public.current_shop_id() and deleted_at is null;
  if not found or a.kind not in ('cash', 'expense') then raise exception 'E_BAD_ACCOUNT'; end if;
  if p_holder is not null and not exists (select 1 from public.profiles where id = p_holder and shop_id = a.shop_id and deleted_at is null) then raise exception 'E_NOT_FOUND'; end if;
  if p_active = false and a.kind = 'cash' and public.ledger_balance(a.id) <> 0 then raise exception 'E_CASHBOX_NOT_EMPTY'; end if;
  update public.accounts set
    name = coalesce(nullif(trim(p_name), ''), name),
    holder_id = case when p_clear_holder then null when a.kind = 'cash' then coalesce(p_holder, holder_id) else null end,
    active = coalesce(p_active, active)
  where id = a.id;
end $$;

-- ============================================================
-- 8) ربط الأجهزة: منع التسليم قبل السداد، وتسجيل الإيراد عند التسليم
-- ============================================================
create or replace function public.device_paid(p_device uuid) returns bigint
language sql stable security definer set search_path = public as $$
  select coalesce(sum(p.amount), 0)::bigint from public.payments p
  where p.device_id = p_device and not exists (select 1 from public.journal_entries r where r.reverses_id = p.entry_id)
$$;
revoke execute on function public.device_paid(uuid) from public, anon, authenticated;

create or replace function public.tg_device_paid_guard() returns trigger
language plpgsql security definer set search_path = public as $$
declare fc integer;
begin
  if new.status = 'delivered' and old.status is distinct from 'delivered' then
    select final_cost into fc from public.device_costs where device_id = new.id and deleted_at is null;
    if coalesce(fc, 0) > public.device_paid(new.id) and coalesce(current_setting('warsha.credit_ok', true), '') <> new.id::text then
      raise exception 'E_UNPAID';
    end if;
  end if;
  return new;
end $$;
create trigger zy_device_paid before update on public.devices for each row execute function public.tg_device_paid_guard();

-- عند التسليم: الإيراد بيتسجل، ودين العميل بالتكلفة (والدفعات اللي قبل كده بتصفّيه). مرة واحدة بس لكل جهاز
create or replace function public.tg_device_revenue() returns trigger
language plpgsql security definer set search_path = public as $$
declare fc integer;
begin
  if new.status = 'delivered' and old.status is distinct from 'delivered'
     and not exists (select 1 from public.journal_entries e where e.source_type = 'delivery' and e.source_id = new.id
                     and not exists (select 1 from public.journal_entries r where r.reverses_id = e.id)) then
    select final_cost into fc from public.device_costs where device_id = new.id and deleted_at is null;
    if coalesce(fc, 0) > 0 then
      perform public.ledger_post('delivery', new.id, new.order_no, jsonb_build_array(
        public.ledger_line(public.ledger_acc('ar'), fc, 0, 'customer', new.customer_id),
        public.ledger_line(public.ledger_acc('rev_repair'), 0, fc)), new.id);
    end if;
  end if;
  return null;
end $$;
create trigger zz_device_revenue after update on public.devices for each row execute function public.tg_device_revenue();

-- بعد ما الإيراد يتسجل، التكلفة النهائية ما بتتغيرش (التصحيح بقيد عكسي)
create or replace function public.tg_cost_locked() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if new.final_cost is distinct from old.final_cost and exists (
    select 1 from public.journal_entries e where e.source_type = 'delivery' and e.source_id = new.device_id
      and not exists (select 1 from public.journal_entries r where r.reverses_id = e.id)) then
    raise exception 'E_COST_LOCKED';
  end if;
  return new;
end $$;
create trigger zy_cost_locked before update on public.device_costs for each row execute function public.tg_cost_locked();

-- التسليم بالآجل (صاحب المحل بس): الباقي بيفضل دين على العميل
create or replace function public.deliver_on_credit(p_device uuid) returns void
language plpgsql security definer set search_path = public as $$
begin
  perform public.ledger_require(array['owner']::public.app_role[]);
  perform set_config('warsha.credit_ok', p_device::text, true);
  update public.devices set status = 'delivered' where id = p_device and shop_id = public.current_shop_id();
  if not found then raise exception 'E_NOT_FOUND'; end if;
  perform set_config('warsha.credit_ok', '', true);
end $$;

-- فلوس الجهاز: التكلفة، والمدفوع، والباقي، والدفعات (لصاحب المحل والاستقبال)
create or replace function public.device_money(p_device uuid) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare fc integer; paid bigint;
begin
  perform public.ledger_require(array['owner', 'reception']::public.app_role[]);
  if not exists (select 1 from public.devices where id = p_device and shop_id = public.current_shop_id()) then raise exception 'E_NOT_FOUND'; end if;
  select final_cost into fc from public.device_costs where device_id = p_device and deleted_at is null;
  paid := public.device_paid(p_device);
  return jsonb_build_object(
    'final', fc, 'paid', paid, 'due', greatest(coalesce(fc, 0) - paid, 0),
    'payments', coalesce((select jsonb_agg(jsonb_build_object(
        'id', p.id, 'amount', p.amount, 'method', p.method, 'created_at', p.created_at, 'entry_id', p.entry_id,
        'by', (select full_name from public.profiles where id = p.created_by),
        'reversed', exists (select 1 from public.journal_entries r where r.reverses_id = p.entry_id)) order by p.created_at)
      from public.payments p where p.device_id = p_device), '[]'::jsonb),
    'parts_cost', case when public.current_app_role() = 'owner' then (
      select coalesce(sum(l.debit), 0) from public.journal_lines l join public.journal_entries e on e.id = l.entry_id
      where e.device_id = p_device and e.source_type in ('part_use', 'reversal') and l.account_id = public.ledger_acc('cogs')) - (
      select coalesce(sum(l.credit), 0) from public.journal_lines l join public.journal_entries e on e.id = l.entry_id
      where e.device_id = p_device and e.source_type = 'reversal' and l.account_id = public.ledger_acc('cogs')) end
  );
end $$;

-- ============================================================
-- 9) التقارير (صاحب المحل بس)
-- ============================================================
-- الوضع المالي للفترة [p_from, p_to)
create or replace function public.financial_position(p_from timestamptz, p_to timestamptz) returns jsonb
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
    left join public.journal_lines l on l.account_id = a.id
    where a.shop_id = s
    group by a.id, l.party_type, l.party_id
  ),
  acc as (select id, code, name, type, kind, method, sum(b)::bigint as b from bal group by id, code, name, type, kind, method),
  per as (
    select coalesce(sum(case when a.type = 'revenue' then l.credit - l.debit else 0 end), 0)::bigint as revenue,
           coalesce(sum(case when a.type = 'expense' then l.debit - l.credit else 0 end), 0)::bigint as expenses
    from public.journal_lines l join public.accounts a on a.id = l.account_id join public.journal_entries e on e.id = l.entry_id
    where l.shop_id = s and e.occurred_at >= p_from and e.occurred_at < p_to
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
      coalesce(sum(greatest(b, 0)) filter (where kind = 'inventory'), 0)::bigint as inventory
    from bal
  ),
  days as (
    select (date_trunc('day', e.occurred_at at time zone 'Africa/Cairo'))::date as day,
           coalesce(sum(case when a.type = 'revenue' then l.credit - l.debit else 0 end), 0)::bigint as revenue,
           coalesce(sum(case when a.type = 'expense' then l.debit - l.credit else 0 end), 0)::bigint as expenses
    from public.journal_lines l join public.accounts a on a.id = l.account_id join public.journal_entries e on e.id = l.entry_id
    where l.shop_id = s and e.occurred_at >= p_from and e.occurred_at < p_to and a.type in ('revenue', 'expense')
    group by 1
  )
  select jsonb_build_object(
    'cash', p.cash,
    'receivables', p.receivables + p.payables_debit,
    'payables', p.payables,
    'inventory', p.inventory,
    'revenue', per.revenue,
    'expenses', per.expenses,
    'profit', per.revenue - per.expenses,
    'net_worth', p.cash + p.receivables + p.payables_debit + p.inventory - p.payables,
    'equation', jsonb_build_object('assets', eq.assets, 'liabilities', eq.liabilities, 'equity', eq.equity, 'earnings', eq.earnings),
    'debits', tot.d, 'credits', tot.c, 'unbalanced_entries', unb.n,
    'balanced', tot.d = tot.c and unb.n = 0 and eq.assets = eq.liabilities + eq.equity + eq.earnings,
    'cashboxes', coalesce((select jsonb_agg(jsonb_build_object('id', a.id, 'code', a.code, 'name', a.name, 'method', a.method, 'balance', a.b) order by a.code nulls last, a.name)
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
         and not exists (select 1 from public.journal_entries r where r.reverses_id = p2.entry_id)
       group by p2.method) m), '{}'::jsonb),
    'delivered', (select count(*) from public.devices d where d.shop_id = s and d.delivered_at >= p_from and d.delivered_at < p_to),
    'closings', coalesce((select jsonb_agg(jsonb_build_object('cashbox', dc.cashbox_id, 'expected', dc.expected, 'counted', dc.counted, 'diff', dc.diff, 'at', dc.created_at,
       'by', (select full_name from public.profiles where id = dc.closed_by)) order by dc.created_at)
       from public.drawer_closings dc where dc.shop_id = s and dc.created_at >= p_from and dc.created_at < p_to), '[]'::jsonb)
  ) into res
  from parts p, per, tot, unb, eq;
  return res;
end $$;

-- حركات خزنة أو كشف حساب (عميل/مورد/موظف) بالرصيد بعد كل حركة
-- p_kind: 'cashbox' (p_id = الخزنة) أو 'customer' / 'supplier' / 'employee' (p_id = الطرف)
create or replace function public.statement(p_kind text, p_id uuid, p_from timestamptz, p_to timestamptz) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare
  s uuid := public.current_shop_id();
  accs uuid[];
  opening bigint;
  res jsonb;
begin
  perform public.ledger_require(array['owner']::public.app_role[]);
  if p_kind = 'cashbox' then
    select array_agg(id) into accs from public.accounts where id = p_id and shop_id = s and kind = 'cash';
  elsif p_kind = 'customer' then
    select array_agg(id) into accs from public.accounts where shop_id = s and kind = 'receivable';
  elsif p_kind = 'supplier' then
    select array_agg(id) into accs from public.accounts where shop_id = s and kind = 'payable';
  elsif p_kind = 'employee' then
    select array_agg(id) into accs from public.accounts where shop_id = s and kind in ('advances', 'salaries');
  else
    raise exception 'E_BAD_INPUT';
  end if;
  if accs is null then raise exception 'E_NOT_FOUND'; end if;
  -- الرصيد: للخزنة والعميل والسلف = مدين − دائن. للمورد والمرتبات = دائن − مدين (الطرف الطبيعي)
  select coalesce(sum((l.debit - l.credit) * public.account_sign(a.type)), 0) into opening
  from public.journal_lines l join public.accounts a on a.id = l.account_id join public.journal_entries e on e.id = l.entry_id
  where l.account_id = any(accs) and (p_kind = 'cashbox' or l.party_id = p_id) and e.occurred_at < p_from;
  with mv as (
    select e.id as entry_id, e.entry_no, e.occurred_at, e.source_type, e.source_id, e.device_id, e.memo, e.reverses_id,
           d.order_no, p.full_name as by_name, a.code as account_code,
           ((l.debit - l.credit) * public.account_sign(a.type))::bigint as amount
    from public.journal_lines l
    join public.accounts a on a.id = l.account_id
    join public.journal_entries e on e.id = l.entry_id
    left join public.devices d on d.id = e.device_id
    left join public.profiles p on p.id = e.created_by
    where l.account_id = any(accs) and (p_kind = 'cashbox' or l.party_id = p_id) and e.occurred_at >= p_from and e.occurred_at < p_to
  ),
  mv2 as (select mv.*, opening + sum(amount) over (order by occurred_at, entry_no rows unbounded preceding) as running from mv)
  select jsonb_build_object('opening', opening, 'moves', coalesce(jsonb_agg(jsonb_build_object(
      'entry_id', entry_id, 'entry_no', entry_no, 'at', occurred_at, 'source_type', source_type, 'source_id', source_id,
      'device_id', device_id, 'order_no', order_no, 'memo', memo, 'by', by_name, 'account', account_code, 'amount', amount,
      'reversed', exists (select 1 from public.journal_entries r where r.reverses_id = entry_id), 'reverses', reverses_id,
      'balance', running) order by occurred_at, entry_no), '[]'::jsonb))
  into res from mv2;
  return res;
end $$;

-- الأصناف بالكمية (والتكلفة والقيمة لصاحب المحل بس)
create or replace function public.items_stock() returns table(id uuid, kind text, name text, sku text, sale_price integer, qty bigint, avg_cost bigint, value bigint)
language plpgsql stable security definer set search_path = public as $$
declare r public.app_role := public.current_app_role();
begin
  if r is null then raise exception 'E_FORBIDDEN'; end if;
  return query
  select i.id, i.kind, i.name, i.sku,
         case when r = 'technician' then null else i.sale_price end,
         coalesce(st.q, 0)::bigint,
         case when r = 'owner' and coalesce(st.q, 0) > 0 then (st.v / st.q)::bigint end,
         case when r = 'owner' then coalesce(st.v, 0)::bigint end
  from public.items i
  left join (select m.item_id, sum(m.qty) as q, sum(m.value) as v from public.stock_moves m group by m.item_id) st on st.item_id = i.id
  where i.shop_id = public.current_shop_id() and i.deleted_at is null
  order by i.kind, i.name;
end $$;

-- ============================================================
-- 10) الصلاحيات
-- ============================================================
alter table public.accounts enable row level security;
alter table public.journal_entries enable row level security;
alter table public.journal_lines enable row level security;
alter table public.suppliers enable row level security;
alter table public.items enable row level security;
alter table public.stock_moves enable row level security;
alter table public.payments enable row level security;
alter table public.drawer_closings enable row level security;

revoke all on public.accounts, public.journal_entries, public.journal_lines, public.suppliers, public.items,
  public.stock_moves, public.payments, public.drawer_closings from public, anon, authenticated;

-- الحسابات: صاحب المحل كلها، والاستقبال الخزن بس (أسماءها، من غير أرصدة)
create policy accounts_select on public.accounts for select to authenticated using (
  shop_id = public.current_shop_id() and (public.current_app_role() = 'owner' or (public.current_app_role() = 'reception' and kind = 'cash')));
grant select on public.accounts to authenticated;

-- القيود والسطور والمخزون: صاحب المحل بس. ومحدش بيكتب فيهم مباشرة (الدوال بس)
create policy entries_select on public.journal_entries for select to authenticated using (shop_id = public.current_shop_id() and public.current_app_role() = 'owner');
create policy lines_select on public.journal_lines for select to authenticated using (shop_id = public.current_shop_id() and public.current_app_role() = 'owner');
create policy moves_select on public.stock_moves for select to authenticated using (shop_id = public.current_shop_id() and public.current_app_role() = 'owner');
grant select on public.journal_entries, public.journal_lines, public.stock_moves to authenticated;

-- الدفعات: صاحب المحل والاستقبال يشوفوها
create policy payments_select on public.payments for select to authenticated using (shop_id = public.current_shop_id() and public.current_app_role() in ('owner', 'reception'));
grant select on public.payments to authenticated;

-- تقفيل الدرج: صاحب المحل الكل، والاستقبال بتاعه بس
create policy closings_select on public.drawer_closings for select to authenticated using (
  shop_id = public.current_shop_id() and (public.current_app_role() = 'owner' or closed_by = auth.uid()));
grant select on public.drawer_closings to authenticated;

-- الموردين: صاحب المحل بس
create policy suppliers_all on public.suppliers for select to authenticated using (shop_id = public.current_shop_id() and public.current_app_role() = 'owner');
create policy suppliers_insert on public.suppliers for insert to authenticated with check (shop_id = public.current_shop_id() and public.current_app_role() = 'owner');
create policy suppliers_update on public.suppliers for update to authenticated using (shop_id = public.current_shop_id() and public.current_app_role() = 'owner') with check (shop_id = public.current_shop_id());
grant select, insert, update on public.suppliers to authenticated;

-- الأصناف: صاحب المحل بيضيف ويعدّل، والاستقبال بيشوف (الفني من items_stock من غير أسعار)
create policy items_select on public.items for select to authenticated using (shop_id = public.current_shop_id() and public.current_app_role() in ('owner', 'reception'));
create policy items_insert on public.items for insert to authenticated with check (shop_id = public.current_shop_id() and public.current_app_role() = 'owner');
create policy items_update on public.items for update to authenticated using (shop_id = public.current_shop_id() and public.current_app_role() = 'owner') with check (shop_id = public.current_shop_id());
grant select, insert, update on public.items to authenticated;

-- الدوال: للمستخدمين المسجلين بس (وكل دالة بتتأكد من الدور جواها)
do $$
declare f text;
begin
  foreach f in array array[
    'record_payment(uuid, uuid, uuid, bigint, uuid, text, text)', 'reverse_entry(uuid, text)', 'transfer_cash(uuid, uuid, uuid, bigint, text)',
    'record_expense(uuid, uuid, uuid, bigint, text)', 'owner_capital(uuid, uuid, bigint, text)', 'owner_drawing(uuid, uuid, bigint, text)',
    'accrue_salary(uuid, uuid, bigint, text)', 'pay_salary(uuid, uuid, uuid, bigint, text)', 'give_advance(uuid, uuid, uuid, bigint, text)',
    'settle_advance(uuid, uuid, bigint, text)', 'record_purchase(uuid, uuid, jsonb, uuid, text)', 'pay_supplier(uuid, uuid, uuid, bigint, text)',
    'use_part(uuid, uuid, uuid, integer)', 'record_sale(uuid, jsonb, uuid, uuid, text)', 'my_drawers()', 'close_drawer(uuid, uuid, bigint, text)',
    'add_account(uuid, text, text, text, uuid)', 'update_account(uuid, text, uuid, boolean, boolean)', 'deliver_on_credit(uuid)',
    'device_money(uuid)', 'financial_position(timestamptz, timestamptz)', 'statement(text, uuid, timestamptz, timestamptz)', 'items_stock()'
  ] loop
    execute format('revoke execute on function public.%s from public, anon', f);
    execute format('grant execute on function public.%s to authenticated', f);
  end loop;
end $$;
$m0008$;
  insert into public.app_migrations(version, how) values ('0008_ledger.sql', 'applied');
  raise notice 'applied %', '0008_ledger.sql';
end $run$;
commit;

-- ============================== 0009_tracking_guess_limit.sql ==============================
begin;
do $run$ begin
  if exists (select 1 from public.app_migrations where version = '0009_tracking_guess_limit.sql') then return; end if;
  execute $m0009$
-- حد المحاولات على رقم الطلب: بيعدّ التخمينات المختلفة بس
--
-- المشكلة: رقم الطلب (زي 2026-0001) بيتكرر بين المحلات. لو القفل بيعدّ كل محاولة غلط،
-- عميل بيغلط في كتابة رقمه في محل، ممكن يقفل نفس الرقم على عميل في محل تاني.
-- الحل: القفل بيعدّ آخر 4 أرقام *المختلفة* اللي اتجربت على رقم الطلب ده (5 في 15 دقيقة).
-- العميل اللي بيكرر نفس الغلطة ما بيقفلش حاجة، واللي بيخمّن أرقام كتير بيتقفل بعد 5.
-- التخمين بيتخزن hash، مش الأرقام نفسها.

alter table public.tracking_attempts add column if not exists guess text;

create or replace function public.tracking_guess(p_order text, p_last4 text) returns text
language sql immutable set search_path = public, extensions as $$
  select case when p_order is null or p_last4 is null then null
    else encode(digest(upper(trim(p_order)) || ':' || trim(p_last4), 'sha256'), 'hex') end
$$;

create or replace function public.tracking_guard(p_order text) returns text
language plpgsql security definer set search_path = public as $$
declare k text := public.tracking_client_key();
begin
  if (select count(*) from public.tracking_attempts where client_key = k and not success and created_at > now() - interval '15 minutes') >= 10
     or (p_order is not null and (select count(distinct guess) from public.tracking_attempts
           where order_no = trim(p_order) and not success and guess is not null and created_at > now() - interval '15 minutes') >= 5) then
    raise exception 'E_RATE_LIMIT';
  end if;
  return k;
end $$;

create or replace function public.get_tracking(p_order text default null, p_last4 text default null, p_token text default null)
returns table(
  order_no text, status public.device_status, brand text, model text, received_at timestamptz,
  updated_at timestamptz, estimated_cost integer, final_cost integer, technician text,
  shop_name text, shop_phone text, shop_logo text, currency text, warranty_until timestamptz,
  can_decide boolean, decision text
)
language plpgsql security definer set search_path = public as $$
declare
  k text := public.tracking_guard(p_order);
  d public.devices;
begin
  d := public.tracking_find(p_order, p_last4, p_token);
  if d.id is null then
    -- مش بنرمي خطأ هنا عشان المحاولة الغلط تفضل متسجلة (الخطأ بيلغي التسجيل). النتيجة الفاضية = مش موجود
    insert into public.tracking_attempts(client_key, order_no, success, guess) values (k, trim(p_order), false, public.tracking_guess(p_order, p_last4));
    return;
  end if;
  insert into public.tracking_attempts(shop_id, client_key, order_no, success) values (d.shop_id, k, d.order_no, true);
  return query
  select d.order_no, d.status, d.brand, d.model, d.received_at,
    coalesce((select max(l.created_at) from public.status_log l where l.device_id = d.id), d.updated_at),
    dc.estimated_cost, dc.final_cost,
    -- اسم الفني: آخر فني غيّر الحالة (الاسم الأول بس)
    (select split_part(p.full_name, ' ', 1) from public.status_log l join public.profiles p on p.id = l.changed_by
       where l.device_id = d.id and p.role = 'technician' order by l.created_at desc limit 1),
    s.name, s.phone, s.logo_path, s.currency, d.warranty_until,
    d.status = 'awaiting_approval' and not exists (
      select 1 from public.quote_decisions q where q.device_id = d.id and q.created_at > coalesce(
        (select max(l.created_at) from public.status_log l where l.device_id = d.id and l.new_status = 'awaiting_approval'), d.received_at)),
    (select q.decision from public.quote_decisions q where q.device_id = d.id order by q.created_at desc limit 1)
  from public.shops s
  left join public.device_costs dc on dc.device_id = d.id and dc.deleted_at is null
  where s.id = d.shop_id;
end $$;

create or replace function public.decide_quote(p_decision text, p_order text default null, p_last4 text default null, p_token text default null)
returns public.device_status
language plpgsql security definer set search_path = public as $$
declare
  k text := public.tracking_guard(p_order);
  d public.devices;
  amt integer;
  next_status public.device_status;
begin
  if p_decision not in ('approved', 'rejected') then raise exception 'E_BAD_INPUT'; end if;
  d := public.tracking_find(p_order, p_last4, p_token);
  if d.id is null then
    insert into public.tracking_attempts(client_key, order_no, success, guess) values (k, trim(p_order), false, public.tracking_guess(p_order, p_last4));
    return null;
  end if;
  if d.status <> 'awaiting_approval' then raise exception 'E_BAD_TRANSITION'; end if;
  select coalesce(final_cost, estimated_cost) into amt from public.device_costs where device_id = d.id and deleted_at is null;
  insert into public.quote_decisions(shop_id, device_id, decision, amount, client_key) values (d.shop_id, d.id, p_decision, amt, k);
  next_status := case when p_decision = 'approved' then 'in_repair'::public.device_status else 'unrepairable'::public.device_status end;
  update public.devices set status = next_status where id = d.id;
  insert into public.audit_log(shop_id, actor_id, action, entity, entity_id, after)
  values (d.shop_id, null, 'customer_' || p_decision, 'devices', d.id, jsonb_build_object('amount', amt, 'order_no', d.order_no));
  return next_status;
end $$;

revoke execute on function public.get_tracking(text, text, text) from public;
revoke execute on function public.decide_quote(text, text, text, text) from public;
grant execute on function public.get_tracking(text, text, text) to anon, authenticated;
grant execute on function public.decide_quote(text, text, text, text) to anon, authenticated;
revoke execute on function public.tracking_guard(text) from public, anon, authenticated;
revoke execute on function public.tracking_guess(text, text) from public, anon, authenticated;
$m0009$;
  insert into public.app_migrations(version, how) values ('0009_tracking_guess_limit.sql', 'applied');
  raise notice 'applied %', '0009_tracking_guess_limit.sql';
end $run$;
commit;

-- ============================== 0010_default_cashboxes.sql ==============================
begin;
do $run$ begin
  if exists (select 1 from public.app_migrations where version = '0010_default_cashboxes.sql') then return; end if;
  execute $m0010$
-- الخزن الأساسية لكل محل (طلب صاحب المشروع): كاش الدرج، فودافون كاش، InstaPay، حساب بنك، الكارت (POS)،
-- غير أي طريقة دفع تانية مفعّلة في المحل (زي التقسيط). صاحب المحل يقدر يضيف خزن تانية من add_account.
create or replace function public.ensure_ledger_accounts(p_shop uuid) returns void
language plpgsql security definer set search_path = public as $$
declare m text;
begin
  insert into public.accounts(shop_id, code, type, kind)
  select p_shop, v.code, v.type::public.account_type, v.kind from (values
    ('ar', 'asset', 'receivable'), ('advances', 'asset', 'advances'), ('inventory', 'asset', 'inventory'),
    ('ap', 'liability', 'payable'), ('salaries_payable', 'liability', 'salaries'),
    ('capital', 'equity', 'capital'), ('drawings', 'equity', 'drawings'),
    ('rev_repair', 'revenue', 'revenue'), ('rev_parts', 'revenue', 'revenue'), ('rev_accessories', 'revenue', 'revenue'), ('overage', 'revenue', 'overage'),
    ('cogs', 'expense', 'cogs'), ('shortage', 'expense', 'shortage'),
    ('exp_salaries', 'expense', 'expense'), ('exp_rent', 'expense', 'expense'), ('exp_electricity', 'expense', 'expense'),
    ('exp_internet', 'expense', 'expense'), ('exp_purchases', 'expense', 'expense')
  ) as v(code, type, kind)
  on conflict (shop_id, code) where code is not null do nothing;
  for m in
    select unnest(array['cash', 'wallet', 'instapay', 'bank_transfer', 'card'])
    union
    select unnest(payment_methods) from public.shops where id = p_shop
  loop
    insert into public.accounts(shop_id, code, type, kind, method)
    values (p_shop, 'cash_' || m, 'asset', 'cash', m)
    on conflict (shop_id, code) where code is not null do nothing;
  end loop;
end $$;
revoke execute on function public.ensure_ledger_accounts(uuid) from public, anon, authenticated;

do $$
declare s uuid;
begin
  perform set_config('warsha.system', 'on', true);
  for s in select id from public.shops loop
    perform public.ensure_ledger_accounts(s);
  end loop;
  perform set_config('warsha.system', 'off', true);
end $$;
$m0010$;
  insert into public.app_migrations(version, how) values ('0010_default_cashboxes.sql', 'applied');
  raise notice 'applied %', '0010_default_cashboxes.sql';
end $run$;
commit;

-- ============================== 0011_finance_drilldown.sql ==============================
begin;
do $run$ begin
  if exists (select 1 from public.app_migrations where version = '0011_finance_drilldown.sql') then return; end if;
  execute $m0011$
-- تفاصيل أرقام شاشة "الوضع المالي" (صاحب المحل بس): كل رقم بيتفتح لتفاصيله

-- كل الأرصدة لنوع معيّن: customers (ليّا)، suppliers (عليّا)، employees (سلف ومرتبات)
create or replace function public.party_balances(p_kind text)
returns table(party_type text, party_id uuid, name text, account text, balance bigint)
language plpgsql stable security definer set search_path = public as $$
declare s uuid := public.current_shop_id();
begin
  perform public.ledger_require(array['owner']::public.app_role[]);
  if p_kind not in ('customers', 'suppliers', 'employees') then raise exception 'E_BAD_INPUT'; end if;
  return query
  select l.party_type, l.party_id,
         coalesce(c.name, sp.name, p.full_name) as name, a.code,
         sum((l.debit - l.credit) * public.account_sign(a.type))::bigint
  from public.journal_lines l
  join public.accounts a on a.id = l.account_id
  left join public.customers c on l.party_type = 'customer' and c.id = l.party_id
  left join public.suppliers sp on l.party_type = 'supplier' and sp.id = l.party_id
  left join public.profiles p on l.party_type = 'employee' and p.id = l.party_id
  where l.shop_id = s and l.party_id is not null
    and ((p_kind = 'customers' and a.kind = 'receivable') or (p_kind = 'suppliers' and a.kind = 'payable') or (p_kind = 'employees' and a.kind in ('advances', 'salaries')))
  group by l.party_type, l.party_id, c.name, sp.name, p.full_name, a.code
  having sum((l.debit - l.credit) * public.account_sign(a.type)) <> 0
  order by 5 desc;
end $$;

-- الإيرادات والمصروفات لكل بند في الفترة
create or replace function public.pl_breakdown(p_from timestamptz, p_to timestamptz)
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
  group by a.id
  having sum(l.debit - l.credit) <> 0
  order by a.type desc, 5 desc;
end $$;

-- صافي حركة كل خزنة يوم بيوم في الفترة (للـ sparkline)
create or replace function public.cashbox_daily(p_from timestamptz, p_to timestamptz)
returns table(cashbox uuid, day date, net bigint)
language plpgsql stable security definer set search_path = public as $$
begin
  perform public.ledger_require(array['owner']::public.app_role[]);
  return query
  select l.account_id, (date_trunc('day', e.occurred_at at time zone 'Africa/Cairo'))::date, sum(l.debit - l.credit)::bigint
  from public.journal_lines l
  join public.accounts a on a.id = l.account_id and a.kind = 'cash'
  join public.journal_entries e on e.id = l.entry_id
  where l.shop_id = public.current_shop_id() and e.occurred_at >= p_from and e.occurred_at < p_to
  group by 1, 2
  order by 2;
end $$;

do $$
declare f text;
begin
  foreach f in array array['party_balances(text)', 'pl_breakdown(timestamptz, timestamptz)', 'cashbox_daily(timestamptz, timestamptz)'] loop
    execute format('revoke execute on function public.%s from public, anon', f);
    execute format('grant execute on function public.%s to authenticated', f);
  end loop;
end $$;

-- تحديث لحظي: أي قيد جديد بيحدّث شاشة الوضع المالي (والـ RLS بيخلي صاحب المحل بس يستقبله)
do $$
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    begin
      alter publication supabase_realtime add table public.journal_entries, public.payments;
    exception when duplicate_object then null;
    end;
  end if;
end $$;

-- قالب واتساب جديد: تذكير العميل المدين بالمبلغ اللي عليه
alter table public.message_templates drop constraint if exists message_templates_key_check;
alter table public.message_templates add constraint message_templates_key_check
  check (key in ('received', 'status', 'approval', 'ready', 'reminder', 'delivered', 'debt'));
$m0011$;
  insert into public.app_migrations(version, how) values ('0011_finance_drilldown.sql', 'applied');
  raise notice 'applied %', '0011_finance_drilldown.sql';
end $run$;
commit;

-- ============================== 0012_spec_completion.sql ==============================
begin;
do $run$ begin
  if exists (select 1 from public.app_migrations where version = '0012_spec_completion.sql') then return; end if;
  execute $m0012$
-- استكمال المراحل 1-3 حسب docs/spec.pdf (المراجعة يوم 2026-11-06)
--
-- 1) صفحة التتبع بتعرض المتبقي.
-- 2) التسليم بالآجل بيتسجل في سجل النشاط باسم صاحب المحل اللي وافق.
-- 3) كل قطعة بمصدرها: المورد وتاريخ الشراء وسعره (حتى في الشراء النقدي)، ومقارنة أسعار الموردين.
-- 4) حد أدنى لكل صنف وقائمة النواقص.
-- 5) قائمة المدينين بأقدم دين.
-- 6) القطع المستبدلة في الجهاز (للفاتورة) من غير تكاليف.
-- 7) التسعير: هامش الربح وأجرة كل نوع عطل من الإعدادات، والسعر المقترح للاستقبال من غير ما تشوف التكلفة.
-- 8) توقيع العميل على الشاشة عند الاستلام.

-- ---------- 1) التتبع ----------
drop function if exists public.get_tracking(text, text, text);
create or replace function public.get_tracking(p_order text default null, p_last4 text default null, p_token text default null)
returns table(
  order_no text, status public.device_status, brand text, model text, received_at timestamptz,
  updated_at timestamptz, estimated_cost integer, final_cost integer, technician text,
  shop_name text, shop_phone text, shop_logo text, currency text, warranty_until timestamptz,
  can_decide boolean, decision text, due bigint
)
language plpgsql security definer set search_path = public as $$
declare
  k text := public.tracking_guard(p_order);
  d public.devices;
begin
  d := public.tracking_find(p_order, p_last4, p_token);
  if d.id is null then
    -- مش بنرمي خطأ هنا عشان المحاولة الغلط تفضل متسجلة (الخطأ بيلغي التسجيل). النتيجة الفاضية = مش موجود
    insert into public.tracking_attempts(client_key, order_no, success, guess) values (k, trim(p_order), false, public.tracking_guess(p_order, p_last4));
    return;
  end if;
  insert into public.tracking_attempts(shop_id, client_key, order_no, success) values (d.shop_id, k, d.order_no, true);
  return query
  select d.order_no, d.status, d.brand, d.model, d.received_at,
    coalesce((select max(l.created_at) from public.status_log l where l.device_id = d.id), d.updated_at),
    dc.estimated_cost, dc.final_cost,
    -- اسم الفني: آخر فني غيّر الحالة (الاسم الأول بس)
    (select split_part(p.full_name, ' ', 1) from public.status_log l join public.profiles p on p.id = l.changed_by
       where l.device_id = d.id and p.role = 'technician' order by l.created_at desc limit 1),
    s.name, s.phone, s.logo_path, s.currency, d.warranty_until,
    d.status = 'awaiting_approval' and not exists (
      select 1 from public.quote_decisions q where q.device_id = d.id and q.created_at > coalesce(
        (select max(l.created_at) from public.status_log l where l.device_id = d.id and l.new_status = 'awaiting_approval'), d.received_at)),
    (select q.decision from public.quote_decisions q where q.device_id = d.id order by q.created_at desc limit 1),
    -- المتبقي على العميل للجهاز ده (بعد التكلفة النهائية بس)
    case when dc.final_cost is not null then greatest(dc.final_cost - public.device_paid(d.id), 0)::bigint end
  from public.shops s
  left join public.device_costs dc on dc.device_id = d.id and dc.deleted_at is null
  where s.id = d.shop_id;
end $$;
revoke execute on function public.get_tracking(text, text, text) from public;
grant execute on function public.get_tracking(text, text, text) to anon, authenticated;

-- ---------- 2) التسليم بالآجل في السجل ----------
create or replace function public.deliver_on_credit(p_device uuid) returns void
language plpgsql security definer set search_path = public as $$
declare due bigint;
begin
  perform public.ledger_require(array['owner']::public.app_role[]);
  select greatest(coalesce(c.final_cost, 0) - public.device_paid(p_device), 0) into due
  from public.devices d left join public.device_costs c on c.device_id = d.id and c.deleted_at is null
  where d.id = p_device and d.shop_id = public.current_shop_id();
  if not found then raise exception 'E_NOT_FOUND'; end if;
  perform set_config('warsha.credit_ok', p_device::text, true);
  update public.devices set status = 'delivered' where id = p_device and shop_id = public.current_shop_id();
  perform set_config('warsha.credit_ok', '', true);
  insert into public.audit_log(shop_id, actor_id, action, entity, entity_id, after)
  values (public.current_shop_id(), auth.uid(), 'deliver_on_credit', 'devices', p_device, jsonb_build_object('due', due));
end $$;

-- ---------- 3) مصدر كل قطعة ----------
create table public.purchases (
  id uuid primary key,
  shop_id uuid not null references public.shops(id),
  supplier_id uuid not null references public.suppliers(id),
  entry_id uuid not null unique references public.journal_entries(id),
  on_credit boolean not null,
  created_by uuid references public.profiles(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);
alter table public.purchases enable row level security;
revoke all on public.purchases from public, anon, authenticated;
create policy purchases_select on public.purchases for select to authenticated using (shop_id = public.current_shop_id() and public.current_app_role() = 'owner');
grant select on public.purchases to authenticated;
create trigger ledger_immutable before update or delete on public.purchases for each row execute function public.tg_ledger_immutable();
create trigger zz_audit after insert on public.purchases for each row execute function public.tg_audit();

-- المشتريات القديمة: المورد من سطر الآجل
insert into public.purchases(id, shop_id, supplier_id, entry_id, on_credit, created_by, created_at)
select e.source_id, e.shop_id, l.party_id, e.id, true, e.created_by, e.created_at
from public.journal_entries e join public.journal_lines l on l.entry_id = e.id and l.party_type = 'supplier'
where e.source_type = 'purchase' on conflict do nothing;

create or replace function public.tg_purchase_link() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  return null;
end $$;

-- record_purchase بيسجل المورد في purchases (نفس المنطق، وزيادة السطر ده)
create or replace function public.record_purchase(p_id uuid, p_supplier uuid, p_lines jsonb, p_cashbox uuid default null, p_note text default null)
returns uuid
language plpgsql security definer set search_path = public as $$
declare
  s uuid := public.current_shop_id();
  l jsonb;
  total bigint := 0;
  q bigint;
  u bigint;
  e uuid;
  credit_line jsonb;
begin
  perform public.ledger_require(array['owner']::public.app_role[]);
  e := public.ledger_idem(p_id);
  if e is not null then return e; end if;
  if not exists (select 1 from public.suppliers where id = p_supplier and shop_id = s and deleted_at is null) then raise exception 'E_NOT_FOUND'; end if;
  if jsonb_typeof(p_lines) <> 'array' or jsonb_array_length(p_lines) = 0 then raise exception 'E_BAD_INPUT'; end if;
  for l in select * from jsonb_array_elements(p_lines) loop
    q := (l ->> 'qty')::bigint;
    u := (l ->> 'unit_cost')::bigint;
    if q is null or q <= 0 or q > 100000 or u is null or u < 0 then raise exception 'E_BAD_AMOUNT'; end if;
    if not exists (select 1 from public.items where id = (l ->> 'item')::uuid and shop_id = s and deleted_at is null) then raise exception 'E_NOT_FOUND'; end if;
    total := total + q * u;
  end loop;
  perform public.ledger_amount(total);
  credit_line := case when p_cashbox is null
    then public.ledger_line(public.ledger_acc('ap'), 0, total, 'supplier', p_supplier)
    else public.ledger_line((public.ledger_cashbox(p_cashbox)).id, 0, total) end;
  e := public.ledger_post('purchase', p_id, p_note, jsonb_build_array(public.ledger_line(public.ledger_acc('inventory'), total, 0), credit_line), null, p_id);
  for l in select * from jsonb_array_elements(p_lines) loop
    insert into public.stock_moves(shop_id, item_id, entry_id, qty, value)
    values (s, (l ->> 'item')::uuid, e, (l ->> 'qty')::int, (l ->> 'qty')::bigint * (l ->> 'unit_cost')::bigint);
  end loop;
  insert into public.purchases(id, shop_id, supplier_id, entry_id, on_credit, created_by) values (p_id, s, p_supplier, e, p_cashbox is null, auth.uid());
  return e;
end $$;
drop function if exists public.tg_purchase_link();

-- أسعار الصنف عند كل مورد: آخر سعر، وأقل سعر، وآخر تاريخ شراء (صاحب المحل)
create or replace function public.item_suppliers(p_item uuid)
returns table(supplier_id uuid, supplier text, last_cost bigint, min_cost bigint, last_at timestamptz, total_qty bigint)
language plpgsql stable security definer set search_path = public as $$
#variable_conflict use_column
begin
  perform public.ledger_require(array['owner']::public.app_role[]);
  return query
  select p.supplier_id, sp.name,
         (array_agg((m.value / m.qty)::bigint order by m.created_at desc))[1],
         min((m.value / m.qty)::bigint),
         max(m.created_at), sum(m.qty)::bigint
  from public.stock_moves m
  join public.purchases p on p.entry_id = m.entry_id
  join public.suppliers sp on sp.id = p.supplier_id
  where m.item_id = p_item and m.shop_id = public.current_shop_id() and m.qty > 0
    and not exists (select 1 from public.journal_entries r where r.reverses_id = m.entry_id)
  group by p.supplier_id, sp.name
  order by 3;
end $$;

-- ---------- 4) الحد الأدنى والنواقص ----------
alter table public.items add column if not exists min_qty integer not null default 0 check (min_qty between 0 and 100000);
alter table public.items add column if not exists supplier_id uuid references public.suppliers(id);

drop function if exists public.items_stock();
create or replace function public.items_stock() returns table(id uuid, kind text, name text, sku text, sale_price integer, qty bigint, avg_cost bigint, value bigint, min_qty integer, supplier_id uuid, short boolean)
language plpgsql stable security definer set search_path = public as $$
declare r public.app_role := public.current_app_role();
begin
  if r is null then raise exception 'E_FORBIDDEN'; end if;
  return query
  select i.id, i.kind, i.name, i.sku,
         case when r = 'technician' then null else i.sale_price end,
         coalesce(st.q, 0)::bigint,
         case when r = 'owner' and coalesce(st.q, 0) > 0 then (st.v / st.q)::bigint end,
         case when r = 'owner' then coalesce(st.v, 0)::bigint end,
         i.min_qty, case when r = 'owner' then i.supplier_id end,
         i.min_qty > 0 and coalesce(st.q, 0) <= i.min_qty
  from public.items i
  left join (select m.item_id, sum(m.qty) as q, sum(m.value) as v from public.stock_moves m group by m.item_id) st on st.item_id = i.id
  where i.shop_id = public.current_shop_id() and i.deleted_at is null
  order by i.kind, i.name;
end $$;

-- ---------- 5) المدينين بأقدم دين ----------
-- أقدم دين = تاريخ أقدم حركة مدينة لسه ما اتسددتش (السداد بيقفل الأقدم الأول)
drop function if exists public.party_balances(text);
create or replace function public.party_balances(p_kind text)
returns table(party_type text, party_id uuid, name text, account text, balance bigint, oldest timestamptz)
language plpgsql stable security definer set search_path = public as $$
#variable_conflict use_column
declare s uuid := public.current_shop_id();
begin
  perform public.ledger_require(array['owner']::public.app_role[]);
  if p_kind not in ('customers', 'suppliers', 'employees') then raise exception 'E_BAD_INPUT'; end if;
  return query
  with lines as (
    select l.party_type, l.party_id, a.code, e.occurred_at, e.entry_no,
           (case when public.account_sign(a.type) = 1 then l.debit else l.credit end)::bigint as plus,
           (case when public.account_sign(a.type) = 1 then l.credit else l.debit end)::bigint as minus
    from public.journal_lines l join public.accounts a on a.id = l.account_id join public.journal_entries e on e.id = l.entry_id
    where l.shop_id = s and l.party_id is not null
      and ((p_kind = 'customers' and a.kind = 'receivable') or (p_kind = 'suppliers' and a.kind = 'payable') or (p_kind = 'employees' and a.kind in ('advances', 'salaries')))
  ),
  tot as (select party_type, party_id, code, sum(plus) - sum(minus) as bal, sum(minus) as paid from lines group by 1, 2, 3),
  cum as (select l.*, sum(l.plus) over (partition by l.party_id, l.code order by l.occurred_at, l.entry_no) as cum_plus from lines l where l.plus > 0)
  select t.party_type, t.party_id, coalesce(c.name, sp.name, p.full_name), t.code, t.bal::bigint,
         (select min(x.occurred_at) from cum x where x.party_id = t.party_id and x.code = t.code and x.cum_plus > t.paid)
  from tot t
  left join public.customers c on t.party_type = 'customer' and c.id = t.party_id
  left join public.suppliers sp on t.party_type = 'supplier' and sp.id = t.party_id
  left join public.profiles p on t.party_type = 'employee' and p.id = t.party_id
  where t.bal <> 0
  order by 5 desc;
end $$;

-- ---------- 6) القطع المستبدلة (للفاتورة) ----------
create or replace function public.device_parts(p_device uuid)
returns table(item_id uuid, name text, qty bigint)
language plpgsql stable security definer set search_path = public as $$
#variable_conflict use_column
begin
  if public.current_app_role() is null then raise exception 'E_FORBIDDEN'; end if;
  if not exists (select 1 from public.devices where id = p_device and shop_id = public.current_shop_id()) then raise exception 'E_NOT_FOUND'; end if;
  return query
  select i.id, i.name, (-sum(m.qty))::bigint
  from public.stock_moves m
  join public.journal_entries e on e.id = m.entry_id
  join public.items i on i.id = m.item_id
  where (e.device_id = p_device) and e.source_type in ('part_use', 'reversal')
  group by i.id, i.name
  having -sum(m.qty) > 0;
end $$;

-- ---------- 7) التسعير ----------
alter table public.shops add column if not exists default_margin_pct integer not null default 20 check (default_margin_pct between 0 and 1000);

create table public.labor_rates (
  id uuid primary key,
  shop_id uuid not null references public.shops(id),
  issue text not null check (length(trim(issue)) between 1 and 80),
  amount integer not null check (amount between 0 and 2000000000),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);
create unique index labor_rates_issue on public.labor_rates(shop_id, lower(trim(issue))) where deleted_at is null;
alter table public.labor_rates enable row level security;
revoke all on public.labor_rates from public, anon, authenticated;
create policy labor_select on public.labor_rates for select to authenticated using (shop_id = public.current_shop_id() and public.current_app_role() in ('owner', 'reception'));
create policy labor_insert on public.labor_rates for insert to authenticated with check (shop_id = public.current_shop_id() and public.current_app_role() = 'owner');
create policy labor_update on public.labor_rates for update to authenticated using (shop_id = public.current_shop_id() and public.current_app_role() = 'owner') with check (shop_id = public.current_shop_id());
grant select, insert, update on public.labor_rates to authenticated;
create trigger set_updated_at before update on public.labor_rates for each row execute function public.tg_set_updated_at();
create trigger block_delete before delete on public.labor_rates for each row execute function public.tg_block_delete();
create trigger a_force_shop_id before insert or update on public.labor_rates for each row execute function public.tg_force_shop_id();
create trigger zz_audit after insert or update on public.labor_rates for each row execute function public.tg_audit();

-- السعر المقترح = تكلفة القطع + أجرة العطل + هامش على القطع، متقرّب لأقرب 5 جنيه.
-- الاستقبال بتشوف السعر بس (من غير تكلفة القطع ولا الربح). نفس معادلة suggestPrice في src/lib/ledger.ts
create or replace function public.suggest_device_price(p_device uuid) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare
  d public.devices;
  parts bigint;
  labor bigint;
  margin int;
  markup bigint;
  price bigint;
begin
  perform public.ledger_require(array['owner', 'reception']::public.app_role[]);
  select * into d from public.devices where id = p_device and shop_id = public.current_shop_id();
  if not found then raise exception 'E_NOT_FOUND'; end if;
  select coalesce(-sum(m.value), 0) into parts from public.stock_moves m join public.journal_entries e on e.id = m.entry_id
   where e.device_id = p_device and e.source_type in ('part_use', 'reversal');
  select coalesce(sum(r.amount), 0) into labor from public.labor_rates r
   where r.shop_id = d.shop_id and r.deleted_at is null and position(lower(trim(r.issue)) in lower(d.issue)) > 0;
  select default_margin_pct into margin from public.shops where id = d.shop_id;
  markup := (parts * margin + 99) / 100;
  price := ((parts + labor + markup + 499) / 500) * 500;
  return case when public.current_app_role() = 'owner'
    then jsonb_build_object('price', price, 'parts', parts, 'labor', labor, 'margin', margin, 'markup', markup)
    else jsonb_build_object('price', price, 'labor', labor) end;
end $$;

-- ---------- 8) توقيع العميل ----------
alter table public.devices add column if not exists intake_signature text check (intake_signature is null or (intake_signature like 'data:image/png;base64,%' and length(intake_signature) < 300000));

do $$
declare f text;
begin
  foreach f in array array['item_suppliers(uuid)', 'items_stock()', 'party_balances(text)', 'device_parts(uuid)', 'suggest_device_price(uuid)', 'deliver_on_credit(uuid)'] loop
    execute format('revoke execute on function public.%s from public, anon', f);
    execute format('grant execute on function public.%s to authenticated', f);
  end loop;
end $$;
$m0012$;
  insert into public.app_migrations(version, how) values ('0012_spec_completion.sql', 'applied');
  raise notice 'applied %', '0012_spec_completion.sql';
end $run$;
commit;

-- ============================== 0013_tracking_ambiguous.sql ==============================
begin;
do $run$ begin
  if exists (select 1 from public.app_migrations where version = '0013_tracking_ambiguous.sql') then return; end if;
  execute $m0013$
-- التتبع برقم الطلب وآخر 4 أرقام: رقم الطلب بيتكرر بين المحلات، وممكن عميلين في محلين يشتركوا في آخر 4 أرقام.
-- قبل كده كان بيرجّع أحدث جهاز (ممكن يبقى جهاز محل تاني). دلوقتي لو فيه أكتر من جهاز مطابق، ما بيرجّعش أي واحد،
-- وبيطلب من العميل يمسح الـ QR (الرمز السري فريد). وده بيحمي كمان الموافقة على التكلفة من إنها توصل لجهاز غلط.
create or replace function public.tracking_find(p_order text, p_last4 text, p_token text)
returns public.devices
language plpgsql stable security definer set search_path = public as $$
declare d public.devices; n int;
begin
  if p_token is not null and length(p_token) >= 16 then
    select * into d from public.devices where tracking_token = p_token and deleted_at is null;
    if found and (p_order is null or d.order_no = trim(p_order)) then return d; end if;
    return null;
  end if;
  if p_order is null or p_last4 is null or p_last4 !~ '^[0-9]{4}$' then return null; end if;
  select count(*) into n
  from public.devices dv join public.customers c on c.id = dv.customer_id
  where dv.order_no = trim(p_order) and right(c.phone, 4) = p_last4 and dv.deleted_at is null;
  if n > 1 then raise exception 'E_TRACK_AMBIGUOUS'; end if;
  select dv.* into d
  from public.devices dv join public.customers c on c.id = dv.customer_id
  where dv.order_no = trim(p_order) and right(c.phone, 4) = p_last4 and dv.deleted_at is null;
  if found then return d; end if;
  return null;
end $$;
revoke execute on function public.tracking_find(text, text, text) from public, anon, authenticated;
$m0013$;
  insert into public.app_migrations(version, how) values ('0013_tracking_ambiguous.sql', 'applied');
  raise notice 'applied %', '0013_tracking_ambiguous.sql';
end $run$;
commit;

-- ============================== 0014_technicians.sql ==============================
begin;
do $run$ begin
  if exists (select 1 from public.app_migrations where version = '0014_technicians.sql') then return; end if;
  execute $m0014$
-- المرحلة 4: الفنيون وتوزيع الشغل (docs/spec.pdf صفحة 3)
--
-- - كل فني ليه تخصص أو أكتر، وكل نوع عطل ليه مسار (خطوات بالترتيب، كل خطوة تخصص). صاحب المحل بيعدّلهم من الإعدادات.
-- - الجهاز بيتحرك لوحده بين الفنيين حسب المسار. اللي عمل نفس التخصص قبل كده في نفس الجهاز بياخده تاني (اللي فك يركّب).
--   وإلا الفني صاحب التخصص الأقل شغلًا.
-- - الفني بيشوف أجهزته بس. أول ما يبدأ بيتسجل وقت البداية، ولما يخلّص الجهاز بيروح للخطوة اللي بعدها.
-- - آخر فني بيعمل فحص نهائي (نفس قائمة الفحص السريع) قبل ما الجهاز يبقى جاهز.
-- - "عطل غير معروف": أول فني بيفحص ويحدد المسار.
-- - مرتجع الضمان بيرجع لنفس الفني اللي قفله، وبيتسجل عليه كمرتجع.
-- - الأولوية: عاجل، عادي، ضمان. وتقدير الوقت من متوسط الأجهزة المشابهة (5 أو أكتر).
-- - الفني ما يبدأش شغل والجهاز مستني موافقة العميل.

-- ============================================================
-- الجداول
-- ============================================================
create table public.specialties (
  id uuid primary key,
  shop_id uuid not null references public.shops(id),
  code text,                         -- الأساسية: assembly / micro / software (الاسم بيتترجم في الواجهة)
  name text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  check (code is not null or nullif(trim(name), '') is not null)
);
create unique index specialties_code on public.specialties(shop_id, code) where code is not null;

create table public.staff_specialties (
  id uuid primary key,
  shop_id uuid not null references public.shops(id),
  profile_id uuid not null references public.profiles(id),
  specialty_id uuid not null references public.specialties(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);
create unique index staff_specialties_one on public.staff_specialties(profile_id, specialty_id) where deleted_at is null;

create table public.routes (
  id uuid primary key,
  shop_id uuid not null references public.shops(id),
  code text,
  name text,
  keywords text[] not null default '{}',
  steps uuid[] not null check (cardinality(steps) between 1 and 8),
  diagnose boolean not null default false,  -- عطل غير معروف: بعد أول خطوة الفني بيحدد المسار
  sort integer not null default 100,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  check (code is not null or nullif(trim(name), '') is not null)
);
create unique index routes_code on public.routes(shop_id, code) where code is not null;

alter table public.devices add column if not exists priority text not null default 'normal' check (priority in ('urgent', 'normal', 'warranty'));
alter table public.devices add column if not exists route_id uuid references public.routes(id);
alter table public.devices add column if not exists est_minutes integer check (est_minutes is null or est_minutes between 1 and 100000);
alter table public.devices add column if not exists return_of_tech uuid references public.profiles(id);

create table public.repair_steps (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references public.shops(id),
  device_id uuid not null references public.devices(id),
  route_id uuid references public.routes(id),
  step_no integer not null,
  specialty_id uuid not null references public.specialties(id),
  technician_id uuid references public.profiles(id),
  status text not null default 'pending' check (status in ('pending', 'active', 'done', 'skipped')),
  started_at timestamptz,
  finished_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  unique (device_id, step_no)
);
create index repair_steps_tech on public.repair_steps(technician_id, status);

do $$
declare t text;
begin
  foreach t in array array['specialties', 'staff_specialties', 'routes', 'repair_steps'] loop
    execute format('alter table public.%I enable row level security', t);
    execute format('revoke all on public.%I from public, anon, authenticated', t);
    execute format('create trigger set_updated_at before update on public.%I for each row execute function public.tg_set_updated_at()', t);
    execute format('create trigger block_delete before delete on public.%I for each row execute function public.tg_block_delete()', t);
    execute format('create trigger a_force_shop_id before insert or update on public.%I for each row execute function public.tg_force_shop_id()', t);
    execute format('create trigger zz_audit after insert or update on public.%I for each row execute function public.tg_audit()', t);
  end loop;
end $$;

-- الإعدادات: كل المحل بيقرا، وصاحب المحل بس بيعدّل
create policy specialties_select on public.specialties for select to authenticated using (shop_id = public.current_shop_id());
create policy specialties_write on public.specialties for insert to authenticated with check (shop_id = public.current_shop_id() and public.current_app_role() = 'owner');
create policy specialties_update on public.specialties for update to authenticated using (shop_id = public.current_shop_id() and public.current_app_role() = 'owner') with check (shop_id = public.current_shop_id());
create policy staff_spec_select on public.staff_specialties for select to authenticated using (shop_id = public.current_shop_id());
create policy staff_spec_write on public.staff_specialties for insert to authenticated with check (shop_id = public.current_shop_id() and public.current_app_role() = 'owner');
create policy staff_spec_update on public.staff_specialties for update to authenticated using (shop_id = public.current_shop_id() and public.current_app_role() = 'owner') with check (shop_id = public.current_shop_id());
create policy routes_select on public.routes for select to authenticated using (shop_id = public.current_shop_id());
create policy routes_write on public.routes for insert to authenticated with check (shop_id = public.current_shop_id() and public.current_app_role() = 'owner');
create policy routes_update on public.routes for update to authenticated using (shop_id = public.current_shop_id() and public.current_app_role() = 'owner') with check (shop_id = public.current_shop_id());
grant select, insert, update on public.specialties, public.staff_specialties, public.routes to authenticated;
-- الخطوات: القراءة للمحل، والكتابة بالدوال بس
create policy steps_select on public.repair_steps for select to authenticated using (shop_id = public.current_shop_id());
grant select on public.repair_steps to authenticated;

-- ============================================================
-- الفني بيشوف أجهزته بس
-- ============================================================
-- الفني "العام": فني ملوش أي تخصص متسجل، فبيقدر ياخد أي خطوة (المحل الصغير اللي فيه فني واحد)
create or replace function public.tech_has_specialty(p_tech uuid, p_specialty uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.profiles p where p.id = p_tech and p.role = 'technician' and p.deleted_at is null)
     and (exists (select 1 from public.staff_specialties ss where ss.profile_id = p_tech and ss.specialty_id = p_specialty and ss.deleted_at is null)
          or not exists (select 1 from public.staff_specialties ss where ss.profile_id = p_tech and ss.deleted_at is null))
$$;

-- أجهزته = فيها خطوة متعيّنة له، أو خطوة مش متعيّنة لحد وهو عنده تخصصها، أو أجهزة لسه ملهاش مسار خالص
create or replace function public.tech_can_see(p_device uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.repair_steps s where s.device_id = p_device and s.technician_id = auth.uid())
      or exists (select 1 from public.repair_steps s
                 where s.device_id = p_device and s.technician_id is null and s.status in ('pending', 'active') and public.tech_has_specialty(auth.uid(), s.specialty_id)
                   and not exists (select 1 from public.repair_steps p where p.device_id = s.device_id and p.step_no < s.step_no and p.status in ('pending', 'active')))
      or not exists (select 1 from public.repair_steps s where s.device_id = p_device)
$$;
drop policy if exists devices_select on public.devices;
create policy devices_select on public.devices for select to authenticated
  using (shop_id = public.current_shop_id() and (public.current_app_role() <> 'technician' or public.tech_can_see(id)));

-- ============================================================
-- الأساسيات لكل محل: 3 تخصصات و4 مسارات (من المواصفات)، وصاحب المحل يعدّلهم
-- ============================================================
create or replace function public.ensure_tech_defaults(p_shop uuid) returns void
language plpgsql security definer set search_path = public as $$
declare a uuid; m uuid; sw uuid;
begin
  insert into public.specialties(id, shop_id, code) select gen_random_uuid(), p_shop, c from unnest(array['assembly', 'micro', 'software']) c
  on conflict (shop_id, code) where code is not null do nothing;
  select id into a from public.specialties where shop_id = p_shop and code = 'assembly';
  select id into m from public.specialties where shop_id = p_shop and code = 'micro';
  select id into sw from public.specialties where shop_id = p_shop and code = 'software';
  insert into public.routes(id, shop_id, code, keywords, steps, diagnose, sort) values
    (gen_random_uuid(), p_shop, 'screen_battery', array['شاشة', 'شاشه', 'بطارية', 'بطاريه', 'تاتش', 'screen', 'battery', 'lcd'], array[a], false, 10),
    (gen_random_uuid(), p_shop, 'board', array['شحن', 'ic', 'شبكة', 'شبكه', 'بوردة', 'بورده', 'charging', 'network', 'board'], array[a, m, a], false, 20),
    (gen_random_uuid(), p_shop, 'software', array['سوفت', 'فلاشة', 'فلاشه', 'تعليق', 'بيعلق', 'software', 'flash'], array[sw], false, 30),
    (gen_random_uuid(), p_shop, 'unknown', '{}', array[a], true, 1000)
  on conflict (shop_id, code) where code is not null do nothing;
end $$;
revoke execute on function public.ensure_tech_defaults(uuid) from public, anon, authenticated;

create or replace function public.tg_shop_tech() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  perform set_config('warsha.system', 'on', true);
  perform public.ensure_tech_defaults(new.id);
  perform set_config('warsha.system', 'off', true);
  return null;
end $$;
create trigger zz_shop_tech after insert on public.shops for each row execute function public.tg_shop_tech();

do $$
declare s uuid;
begin
  perform set_config('warsha.system', 'on', true);
  for s in select id from public.shops loop perform public.ensure_tech_defaults(s); end loop;
  perform set_config('warsha.system', 'off', true);
end $$;

-- ============================================================
-- التوزيع
-- ============================================================
-- المسار المناسب لوصف العطل: أول مسار (بالترتيب) فيه كلمة من كلماته جوه الوصف، وإلا مسار "عطل غير معروف"
create or replace function public.detect_route(p_issue text) returns uuid
language sql stable security definer set search_path = public as $$
  select id from public.routes r
  where r.shop_id = public.current_shop_id() and r.deleted_at is null
    and (r.diagnose or exists (select 1 from unnest(r.keywords) k where position(lower(k) in lower(coalesce(p_issue, ''))) > 0))
  order by r.diagnose, r.sort, r.created_at
  limit 1
$$;

-- الفني للخطوة: اللي عمل نفس التخصص في نفس الجهاز قبل كده، وإلا صاحب التخصص الأقل شغلًا (خطوات مفتوحة)
create or replace function public.pick_technician(p_device uuid, p_specialty uuid) returns uuid
language sql stable security definer set search_path = public as $$
  select coalesce(
    (select s.technician_id from public.repair_steps s join public.profiles p on p.id = s.technician_id and p.deleted_at is null
      where s.device_id = p_device and s.specialty_id = p_specialty and s.technician_id is not null and s.status = 'done'
      order by s.step_no desc limit 1),
    (select ss.profile_id from public.staff_specialties ss join public.profiles p on p.id = ss.profile_id and p.deleted_at is null and p.role = 'technician'
      where ss.specialty_id = p_specialty and ss.deleted_at is null and ss.shop_id = public.current_shop_id()
      order by (select count(*) from public.repair_steps x where x.technician_id = ss.profile_id and x.status in ('pending', 'active')), p.full_name
      limit 1),
    -- مفيش حد عنده التخصص: فني عام (ملوش تخصصات)
    (select p.id from public.profiles p
      where p.shop_id = public.current_shop_id() and p.role = 'technician' and p.deleted_at is null
        and not exists (select 1 from public.staff_specialties ss where ss.profile_id = p.id and ss.deleted_at is null)
      order by (select count(*) from public.repair_steps x where x.technician_id = p.id and x.status in ('pending', 'active')), p.full_name
      limit 1))
$$;

-- حماية الجهاز من المرحلة 1، ومعاها استثناء لحقول التوزيع من جوه الدوال (warsha.routing)
create or replace function public.tg_device_guard() returns trigger
language plpgsql security definer set search_path = public as $$
declare
  r public.app_role := public.current_app_role();
  fc integer;
  -- حقول التوزيع (المسار، الأولوية، فني المرتجع) بتتغير من دوال التوزيع الموثوقة بس، حتى لو اللي نادى فني
  sys text[] := case when current_setting('warsha.routing', true) = 'on' then array['route_id', 'priority', 'return_of_tech', 'warranty_days', 'warranty_until'] else array[]::text[] end;
begin
  -- حاجات ما بتتغيرش بعد الاستلام
  if new.order_no is distinct from old.order_no
     or new.received_at is distinct from old.received_at
     or new.received_by is distinct from old.received_by then
    raise exception 'E_RECEIPT_IMMUTABLE';
  end if;

  -- الفني يغيّر الحالة بس
  if r = 'technician' and
     (to_jsonb(new) - 'status' - 'updated_at' - 'delivered_at' - sys) <> (to_jsonb(old) - 'status' - 'updated_at' - 'delivered_at' - sys) then
    raise exception 'E_TECH_STATUS_ONLY';
  end if;

  if new.status is distinct from old.status then
    if not public.is_valid_transition(old.status, new.status) then
      raise exception 'E_BAD_TRANSITION';
    end if;
    if new.status = 'delivered' then
      if r = 'technician' then
        raise exception 'E_TECH_NO_DELIVER';
      end if;
      select final_cost into fc from public.device_costs where device_id = new.id and deleted_at is null;
      if fc is null then
        raise exception 'E_FINAL_COST_REQUIRED';
      end if;
      new.delivered_at := now();
    elsif old.status = 'delivered' then
      new.delivered_at := null;  -- رجع ضمان
    end if;
  elsif new.delivered_at is distinct from old.delivered_at then
    raise exception 'E_DELIVERED_AUTO';
  end if;
  return new;
end $$;

-- يحط مسار للجهاز: الخطوات المفتوحة القديمة بتتلغي (skipped)، والجديدة بتتضاف بعدها، وأول خطوة بتتعيّن لفني
create or replace function public.set_route(p_device uuid, p_route uuid) returns void
language plpgsql security definer set search_path = public as $$
declare
  d public.devices;
  r public.routes;
  n int;
  sp uuid;
  i int := 0;
  first_step uuid;
begin
  select * into d from public.devices where id = p_device and shop_id = public.current_shop_id() and deleted_at is null for update;
  if not found then raise exception 'E_NOT_FOUND'; end if;
  select * into r from public.routes where id = p_route and shop_id = d.shop_id and deleted_at is null;
  if not found then raise exception 'E_NOT_FOUND'; end if;
  -- الفني بيحدد المسار بس لو هو اللي فحص (خطوة فحص في مسار "غير معروف" متعيّنة له)
  if public.current_app_role() = 'technician' and not exists (
      select 1 from public.repair_steps s join public.routes rr on rr.id = s.route_id and rr.diagnose
      where s.device_id = d.id and s.technician_id = auth.uid() and s.status in ('active', 'done')) then
    raise exception 'E_FORBIDDEN';
  end if;
  if public.current_app_role() is null then raise exception 'E_FORBIDDEN'; end if;
  update public.repair_steps set status = 'skipped', finished_at = now() where device_id = d.id and status in ('pending', 'active');
  select coalesce(max(step_no), 0) into n from public.repair_steps where device_id = d.id;
  foreach sp in array r.steps loop
    i := i + 1;
    insert into public.repair_steps(shop_id, device_id, route_id, step_no, specialty_id, technician_id)
    values (d.shop_id, d.id, r.id, n + i, sp, case when i = 1 then public.pick_technician(d.id, sp) end)
    returning id into first_step;
  end loop;
  perform set_config('warsha.routing', 'on', true);
  update public.devices set route_id = r.id where id = d.id;
  perform set_config('warsha.routing', 'off', true);
end $$;

-- يمشّي الجهاز في الحالات المسموحة لحد حالة معيّنة (من غير ما يكسر قواعد الانتقال)
create or replace function public.walk_status(p_device uuid, p_target public.device_status) returns void
language plpgsql security definer set search_path = public as $$
declare cur public.device_status; nxt public.device_status; guard int := 0;
begin
  loop
    select status into cur from public.devices where id = p_device;
    exit when cur = p_target or guard > 6;
    guard := guard + 1;
    nxt := case
      when p_target = 'inspecting' and cur = 'received' then 'inspecting'
      when p_target = 'in_repair' and cur in ('received') then 'inspecting'
      when p_target = 'in_repair' and cur in ('inspecting', 'awaiting_part', 'repaired', 'warranty_return') then 'in_repair'
      when p_target in ('repaired', 'ready') and cur = 'received' then 'inspecting'
      when p_target in ('repaired', 'ready') and cur in ('inspecting', 'awaiting_part', 'warranty_return') then 'in_repair'
      when p_target in ('repaired', 'ready') and cur = 'in_repair' then 'repaired'
      when p_target = 'ready' and cur = 'repaired' then 'ready'
      else null end;
    if nxt is null then raise exception 'E_BAD_TRANSITION'; end if;
    update public.devices set status = nxt where id = p_device;
  end loop;
end $$;
revoke execute on function public.walk_status(uuid, public.device_status) from public, anon, authenticated;

-- الفني بيبدأ خطوة: بيتسجل وقت البداية، والجهاز بيتنقل للفحص أو الصيانة
create or replace function public.start_step(p_step uuid) returns void
language plpgsql security definer set search_path = public as $$
declare s public.repair_steps; d public.devices; r public.routes;
begin
  select * into s from public.repair_steps where id = p_step and shop_id = public.current_shop_id() for update;
  if not found then raise exception 'E_NOT_FOUND'; end if;
  if public.current_app_role() = 'technician' then
    if s.technician_id is null and public.tech_has_specialty(auth.uid(), s.specialty_id) then
      s.technician_id := auth.uid();  -- خطوة مش متعيّنة لحد وهو عنده التخصص: بياخدها
    elsif s.technician_id is distinct from auth.uid() then
      raise exception 'E_FORBIDDEN';
    end if;
  elsif public.current_app_role() is distinct from 'owner' then
    raise exception 'E_FORBIDDEN';
  end if;
  if s.status <> 'pending' then raise exception 'E_BAD_TRANSITION'; end if;
  if exists (select 1 from public.repair_steps x where x.device_id = s.device_id and x.step_no < s.step_no and x.status in ('pending', 'active')) then
    raise exception 'E_STEP_ORDER';
  end if;
  select * into d from public.devices where id = s.device_id;
  if d.status = 'awaiting_approval' then raise exception 'E_AWAITING_APPROVAL'; end if;
  if d.status in ('delivered', 'ready', 'unrepairable') then raise exception 'E_BAD_TRANSITION'; end if;
  update public.repair_steps set status = 'active', started_at = now(), technician_id = s.technician_id where id = s.id;
  select * into r from public.routes where id = s.route_id;
  perform public.walk_status(d.id, case when coalesce(r.diagnose, false) or d.status = 'received' then 'inspecting'::public.device_status else 'in_repair'::public.device_status end);
end $$;

-- الفني خلّص خطوته. لو فيه خطوة بعدها الجهاز بيروح للفني بتاعها. لو دي الأخيرة: فحص نهائي إجباري، والجهاز بيبقى جاهز.
-- لو مسار "غير معروف": الفني لازم يحدد المسار الجاي (p_next_route)
create or replace function public.finish_step(p_step uuid, p_check jsonb default null, p_next_route uuid default null) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  s public.repair_steps;
  r public.routes;
  nxt public.repair_steps;
  ck uuid;
begin
  select * into s from public.repair_steps where id = p_step and shop_id = public.current_shop_id() for update;
  if not found then raise exception 'E_NOT_FOUND'; end if;
  if public.current_app_role() = 'technician' and s.technician_id is distinct from auth.uid() then raise exception 'E_FORBIDDEN'; end if;
  if public.current_app_role() not in ('owner', 'technician') then raise exception 'E_FORBIDDEN'; end if;
  if s.status <> 'active' then raise exception 'E_BAD_TRANSITION'; end if;
  if (select status from public.devices where id = s.device_id) = 'awaiting_approval' then raise exception 'E_AWAITING_APPROVAL'; end if;
  select * into r from public.routes where id = s.route_id;
  select * into nxt from public.repair_steps where device_id = s.device_id and step_no > s.step_no and status = 'pending' order by step_no limit 1;

  if nxt.id is null and coalesce(r.diagnose, false) then
    -- الفحص خلص: الفني بيحدد المسار
    if p_next_route is null then raise exception 'E_ROUTE_REQUIRED'; end if;
    update public.repair_steps set status = 'done', finished_at = now() where id = s.id;
    perform public.set_route(s.device_id, p_next_route);
    select * into nxt from public.repair_steps where device_id = s.device_id and status = 'pending' order by step_no limit 1;
    return jsonb_build_object('next_step', nxt.id, 'next_tech', nxt.technician_id, 'ready', false);
  end if;

  if nxt.id is null then
    -- آخر خطوة: الفحص النهائي بنفس قائمة الفحص السريع
    if p_check is null or jsonb_typeof(p_check) <> 'object' or p_check = '{}'::jsonb then raise exception 'E_FINAL_CHECK_REQUIRED'; end if;
    select id into ck from public.device_checks where device_id = s.device_id and stage = 'delivery' and deleted_at is null;
    if ck is null then
      insert into public.device_checks(id, shop_id, device_id, stage, items) values (gen_random_uuid(), s.shop_id, s.device_id, 'delivery', p_check);
    else
      update public.device_checks set items = p_check where id = ck;
    end if;
    update public.repair_steps set status = 'done', finished_at = now() where id = s.id;
    perform public.walk_status(s.device_id, 'ready');
    return jsonb_build_object('next_step', null, 'ready', true);
  end if;

  update public.repair_steps set status = 'done', finished_at = now() where id = s.id;
  if nxt.technician_id is null then
    update public.repair_steps set technician_id = public.pick_technician(s.device_id, nxt.specialty_id) where id = nxt.id returning * into nxt;
  end if;
  return jsonb_build_object('next_step', nxt.id, 'next_tech', nxt.technician_id, 'ready', false);
end $$;

-- تحويل خطوة لفني تاني (صاحب المحل والاستقبال)
create or replace function public.reassign_step(p_step uuid, p_tech uuid) returns void
language plpgsql security definer set search_path = public as $$
declare s public.repair_steps;
begin
  perform public.ledger_require(array['owner', 'reception']::public.app_role[]);
  select * into s from public.repair_steps where id = p_step and shop_id = public.current_shop_id() for update;
  if not found or s.status not in ('pending', 'active') then raise exception 'E_NOT_FOUND'; end if;
  if p_tech is not null and not exists (select 1 from public.profiles where id = p_tech and shop_id = s.shop_id and role = 'technician' and deleted_at is null) then raise exception 'E_NOT_FOUND'; end if;
  update public.repair_steps set technician_id = p_tech, status = case when status = 'active' then 'pending' else status end, started_at = null where id = s.id;
end $$;

-- لما الجهاز يتسجل مرتجع ضمان: أولوية ضمان، وبيرجع لنفس الفني اللي قفله، وبيتسجل عليه كمرتجع
create or replace function public.tg_device_warranty_tech() returns trigger
language plpgsql security definer set search_path = public as $$
declare t uuid; sp uuid; n int;
begin
  if new.status = 'warranty_return' and old.status is distinct from 'warranty_return' then
    select s.technician_id, s.specialty_id into t, sp from public.repair_steps s
     where s.device_id = new.id and s.status = 'done' and s.technician_id is not null order by s.step_no desc limit 1;
    perform set_config('warsha.routing', 'on', true);
    update public.devices set priority = 'warranty', return_of_tech = t where id = new.id;
    perform set_config('warsha.routing', 'off', true);
    if sp is not null then
      select coalesce(max(step_no), 0) into n from public.repair_steps where device_id = new.id;
      insert into public.repair_steps(shop_id, device_id, route_id, step_no, specialty_id, technician_id)
      values (new.shop_id, new.id, new.route_id, n + 1, sp, t);
    end if;
  end if;
  return null;
end $$;
create trigger zz_warranty_tech after update of status on public.devices for each row execute function public.tg_device_warranty_tech();

-- ============================================================
-- قائمة الفني: أجهزته بالأولوية ثم بتاريخ الاستلام، والمتأخر متعلّم (من غير أسعار ولا بيانات عملاء)
-- ============================================================
create or replace function public.my_queue()
returns table(step_id uuid, device_id uuid, order_no text, brand text, model text, issue text, priority text, status public.device_status,
              received_at timestamptz, est_minutes integer, step_no integer, steps_total integer, specialty_id uuid, step_status text,
              started_at timestamptz, diagnose boolean, late boolean, is_return boolean)
language plpgsql stable security definer set search_path = public as $$
#variable_conflict use_column
begin
  if public.current_app_role() is null then raise exception 'E_FORBIDDEN'; end if;
  return query
  select s.id, d.id, d.order_no, d.brand, d.model, d.issue, d.priority, d.status, d.received_at, d.est_minutes, s.step_no,
         (select count(*)::int from public.repair_steps x where x.device_id = d.id and x.status <> 'skipped'),
         s.specialty_id, s.status, s.started_at, coalesce(r.diagnose, false),
         (d.est_minutes is not null and now() > d.received_at + make_interval(mins => d.est_minutes)) or now() - d.received_at > interval '7 days',
         d.return_of_tech is not null
  from public.repair_steps s
  join public.devices d on d.id = s.device_id and d.deleted_at is null
  left join public.routes r on r.id = s.route_id
  where s.shop_id = public.current_shop_id() and s.status in ('pending', 'active')
    and (s.technician_id = auth.uid()
         or (s.technician_id is null and public.tech_has_specialty(auth.uid(), s.specialty_id)))
    and not exists (select 1 from public.repair_steps p where p.device_id = s.device_id and p.step_no < s.step_no and p.status in ('pending', 'active'))
  order by case d.priority when 'urgent' then 0 when 'warranty' then 1 else 2 end, d.received_at;
end $$;

-- ============================================================
-- تقدير الوقت: متوسط الوقت الفعلي لنفس (نوع الجهاز + نوع العطل). لو 5 أجهزة أو أكتر بيقترح، لو أقل بيرجع null
-- ============================================================
create or replace function public.estimate_minutes(p_brand text, p_route uuid) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare n int; avgm numeric;
begin
  if public.current_app_role() is null then raise exception 'E_FORBIDDEN'; end if;
  select count(*), avg(mins) into n, avgm from (
    select extract(epoch from max(s.finished_at) - min(s.started_at)) / 60 as mins
    from public.devices d join public.repair_steps s on s.device_id = d.id and s.status = 'done'
    where d.shop_id = public.current_shop_id() and d.route_id = p_route and lower(d.brand) = lower(trim(p_brand)) and d.return_of_tech is null
      and not exists (select 1 from public.repair_steps o where o.device_id = d.id and o.status in ('pending', 'active'))
    group by d.id
  ) t where mins > 0;
  return jsonb_build_object('n', n, 'minutes', case when n >= 5 then greatest(1, round(avgm))::int end);
end $$;

-- الفني الحالي للجهاز (الاسم الأول): للرسايل باسم الفني
create or replace function public.device_tech_name(p_device uuid) returns text
language sql stable security definer set search_path = public as $$
  select split_part(p.full_name, ' ', 1) from public.repair_steps s join public.profiles p on p.id = s.technician_id
  where s.device_id = p_device and s.shop_id = public.current_shop_id() and s.status in ('active', 'pending', 'done')
  order by case s.status when 'active' then 0 when 'pending' then 1 else 2 end, s.step_no desc limit 1
$$;

-- ============================================================
-- التقارير (صاحب المحل)
-- ============================================================
-- أداء كل فني: الأجهزة اللي قفلها، ومتوسط وقت الخطوة، والمرتجعات ونسبتها، والإيراد اللي جابه (الأجهزة اللي قفلها واتسلّمت)
create or replace function public.tech_report(p_from timestamptz, p_to timestamptz)
returns table(tech_id uuid, name text, devices integer, steps integer, avg_minutes integer, returns integer, return_rate integer, revenue bigint)
language plpgsql stable security definer set search_path = public as $$
#variable_conflict use_column
declare s uuid := public.current_shop_id();
begin
  perform public.ledger_require(array['owner']::public.app_role[]);
  return query
  with closed as (  -- آخر خطوة "تمت" في كل جهاز اتقفل في الفترة = الفني اللي قفله
    select distinct on (x.device_id) x.device_id, x.technician_id, x.finished_at
    from public.repair_steps x where x.shop_id = s and x.status = 'done' and x.technician_id is not null
    order by x.device_id, x.step_no desc
  )
  select p.id, p.full_name,
    (select count(*)::int from closed c where c.technician_id = p.id and c.finished_at >= p_from and c.finished_at < p_to),
    (select count(*)::int from public.repair_steps x where x.technician_id = p.id and x.status = 'done' and x.finished_at >= p_from and x.finished_at < p_to),
    (select round(avg(extract(epoch from x.finished_at - x.started_at) / 60))::int from public.repair_steps x
      where x.technician_id = p.id and x.status = 'done' and x.started_at is not null and x.finished_at >= p_from and x.finished_at < p_to),
    (select count(*)::int from public.devices d where d.return_of_tech = p.id and d.updated_at >= p_from and d.updated_at < p_to),
    case when (select count(*) from closed c where c.technician_id = p.id) = 0 then 0
         else ((select count(*) from public.devices d where d.return_of_tech = p.id) * 100 / (select count(*) from closed c where c.technician_id = p.id))::int end,
    -- الإيراد من قيود التسليم نفسها (بتفضل حتى لو الجهاز رجع ضمان بعد كده)
    (select coalesce(sum(l.debit), 0)::bigint from closed c
       join public.journal_entries e on e.source_type = 'delivery' and e.source_id = c.device_id and e.occurred_at >= p_from and e.occurred_at < p_to
         and not exists (select 1 from public.journal_entries r where r.reverses_id = e.id)
       join public.journal_lines l on l.entry_id = e.id and l.debit > 0
     where c.technician_id = p.id)
  from public.profiles p
  where p.shop_id = s and p.role = 'technician' and p.deleted_at is null
  order by 3 desc, 2;
end $$;

-- ربحية كل نوع عطل: الأجهزة المسلّمة، والإيراد، وتكلفة القطع، والربح
create or replace function public.issue_report(p_from timestamptz, p_to timestamptz)
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
  where d.shop_id = public.current_shop_id() and d.status = 'delivered' and d.delivered_at >= p_from and d.delivered_at < p_to
  group by r.id, r.code, r.name
  order by 7 desc;
end $$;

-- أكتر الأعطال والموديلات اللي دخلت (للاستقبال كمان، من غير فلوس)
create or replace function public.models_report(p_from timestamptz, p_to timestamptz)
returns table(kind text, label text, devices integer)
language plpgsql stable security definer set search_path = public as $$
#variable_conflict use_column
begin
  perform public.ledger_require(array['owner', 'reception']::public.app_role[]);
  return query
  (select 'model'::text, d.brand || ' ' || d.model, count(*)::int from public.devices d
    where d.shop_id = public.current_shop_id() and d.received_at >= p_from and d.received_at < p_to and d.deleted_at is null
    group by d.brand, d.model order by 3 desc limit 10)
  union all
  (select 'route'::text, coalesce(r.code, r.name, '-'), count(*)::int from public.devices d left join public.routes r on r.id = d.route_id
    where d.shop_id = public.current_shop_id() and d.received_at >= p_from and d.received_at < p_to and d.deleted_at is null
    group by r.code, r.name order by 3 desc limit 10);
end $$;

-- ============================================================
-- الصلاحيات للدوال
-- ============================================================
do $$
declare f text;
begin
  foreach f in array array['tech_can_see(uuid)', 'pick_technician(uuid, uuid)', 'tech_has_specialty(uuid, uuid)'] loop
    execute format('revoke execute on function public.%s from public, anon, authenticated', f);
  end loop;
  foreach f in array array['detect_route(text)', 'set_route(uuid, uuid)', 'start_step(uuid)', 'finish_step(uuid, jsonb, uuid)', 'reassign_step(uuid, uuid)',
                           'my_queue()', 'estimate_minutes(text, uuid)', 'device_tech_name(uuid)', 'tech_report(timestamptz, timestamptz)',
                           'issue_report(timestamptz, timestamptz)', 'models_report(timestamptz, timestamptz)'] loop
    execute format('revoke execute on function public.%s from public, anon', f);
    execute format('grant execute on function public.%s to authenticated', f);
  end loop;
end $$;
-- السياسة بتنادي tech_can_see بصلاحيات المستخدم
grant execute on function public.tech_can_see(uuid) to authenticated;
grant execute on function public.tech_has_specialty(uuid, uuid) to authenticated;

-- تحديث لحظي لقائمة الفني
do $$
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    begin
      alter publication supabase_realtime add table public.repair_steps;
    exception when duplicate_object then null;
    end;
  end if;
end $$;
$m0014$;
  insert into public.app_migrations(version, how) values ('0014_technicians.sql', 'applied');
  raise notice 'applied %', '0014_technicians.sql';
end $run$;
commit;

-- ============================== 0015_offline_backup.sql ==============================
begin;
do $run$ begin
  if exists (select 1 from public.app_migrations where version = '0015_offline_backup.sql') then return; end if;
  execute $m0015$
-- المرحلة 5: بدون إنترنت والنسخ الاحتياطي
--
-- 1) مزامنة تغيير الحالة اللي اتعمل بدون نت: "آخر تعديل بالوقت يكسب". لو الجهاز اتعدّل على السيرفر بعد وقت التعديل
--    اللي على الجهاز، التعديل القديم ما بيتطبقش، والتعارض بيتسجل في سجل النشاط.
-- 2) تصدير نسخة كاملة من بيانات المحل (صاحب المحل بس). الملف بيتشفّر على الجهاز بكلمة سر قبل ما يتحفظ.
--    أسرار أقفال الأجهزة (Vault) ما بتطلعش في النسخة أبدًا.
-- 3) نسخة احتياطية يومية تلقائية على السيرفر (آخر 7 أيام) لو pg_cron متاح.

-- ---------- 1) آخر تعديل يكسب ----------
create or replace function public.apply_status_lww(p_device uuid, p_status public.device_status, p_client_ts timestamptz)
returns jsonb
language plpgsql security definer set search_path = public as $$
declare d public.devices;
begin
  if public.current_app_role() is null then raise exception 'E_FORBIDDEN'; end if;
  select * into d from public.devices where id = p_device and shop_id = public.current_shop_id() and deleted_at is null for update;
  if not found then raise exception 'E_NOT_FOUND'; end if;
  if d.status = p_status then
    return jsonb_build_object('applied', true, 'same', true);
  end if;
  if d.updated_at > p_client_ts then
    insert into public.audit_log(shop_id, actor_id, action, entity, entity_id, before, after)
    values (d.shop_id, auth.uid(), 'sync_conflict', 'devices', d.id,
            jsonb_build_object('status', d.status, 'updated_at', d.updated_at),
            jsonb_build_object('status', p_status, 'client_ts', p_client_ts, 'kept', 'server'));
    return jsonb_build_object('applied', false, 'reason', 'newer_on_server', 'server_status', d.status);
  end if;
  begin
    update public.devices set status = p_status where id = d.id;
  exception when others then
    -- التعديل ما ينفعش يتطبق (مثلًا الانتقال مش مسموح دلوقتي): بيتسجل تعارض بسببه
    insert into public.audit_log(shop_id, actor_id, action, entity, entity_id, before, after)
    values (d.shop_id, auth.uid(), 'sync_conflict', 'devices', d.id,
            jsonb_build_object('status', d.status, 'updated_at', d.updated_at),
            jsonb_build_object('status', p_status, 'client_ts', p_client_ts, 'kept', 'server', 'error', sqlerrm));
    return jsonb_build_object('applied', false, 'reason', 'rejected', 'error', sqlerrm, 'server_status', d.status);
  end;
  return jsonb_build_object('applied', true);
end $$;

-- ---------- 2) النسخة الكاملة ----------
create or replace function public.backup_snapshot(p_shop uuid) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare
  res jsonb := jsonb_build_object('format', 'warsha-backup', 'version', 1, 'generated_at', now(), 'shop_id', p_shop);
  t text;
  rows jsonb;
begin
  foreach t in array array['shops', 'profiles', 'customers', 'devices', 'device_costs', 'status_log', 'device_notes', 'device_photos', 'device_checks',
                           'quote_decisions', 'message_templates', 'message_log', 'accounts', 'journal_entries', 'journal_lines', 'payments', 'drawer_closings',
                           'suppliers', 'items', 'stock_moves', 'purchases', 'labor_rates', 'specialties', 'staff_specialties', 'routes', 'repair_steps', 'audit_log'] loop
    execute format('select coalesce(jsonb_agg(to_jsonb(x)), ''[]''::jsonb) from public.%I x where x.shop_id = $1', t) into rows using p_shop;
    -- توقيع العميل صورة كبيرة: بيفضل في النسخة، بس من غير أي أسرار
    res := res || jsonb_build_object(t, rows);
  end loop;
  -- الأقفال: نوعها بس، من غير السر
  select coalesce(jsonb_agg(jsonb_build_object('device_id', device_id, 'kind', kind, 'erased_at', erased_at)), '[]'::jsonb)
    into rows from public.device_passcodes where shop_id = p_shop;
  return res || jsonb_build_object('device_passcodes', rows);
end $$;
revoke execute on function public.backup_snapshot(uuid) from public, anon, authenticated;

create or replace function public.export_backup() returns jsonb
language plpgsql security definer set search_path = public as $$
declare s uuid := public.current_shop_id();
begin
  perform public.ledger_require(array['owner']::public.app_role[]);
  insert into public.audit_log(shop_id, actor_id, action, entity, entity_id, after)
  values (s, auth.uid(), 'backup_export', 'shops', s, jsonb_build_object('at', now()));
  return public.backup_snapshot(s);
end $$;
revoke execute on function public.export_backup() from public, anon;
grant execute on function public.export_backup() to authenticated;

-- ---------- 3) النسخة اليومية على السيرفر ----------
create table public.shop_backups (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references public.shops(id),
  data jsonb not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);
create index shop_backups_shop on public.shop_backups(shop_id, created_at desc);
alter table public.shop_backups enable row level security;
revoke all on public.shop_backups from public, anon, authenticated;
-- صاحب المحل بيشوف قايمة النسخ (من غير البيانات نفسها) وبينزّل آخر واحدة بالدالة
create policy backups_none on public.shop_backups for select to authenticated using (false);
create trigger block_delete before delete on public.shop_backups for each row execute function public.tg_block_delete();
create trigger set_updated_at before update on public.shop_backups for each row execute function public.tg_set_updated_at();

create or replace function public.daily_backups() returns integer
language plpgsql security definer set search_path = public as $$
declare s uuid; n int := 0;
begin
  for s in select id from public.shops where deleted_at is null loop
    insert into public.shop_backups(shop_id, data) values (s, public.backup_snapshot(s));
    n := n + 1;
  end loop;
  -- آخر 7 أيام بس: النسخ الأقدم بتتعلّم محذوفة (soft delete) ومحتواها بيتفضّى عشان المساحة. مفيش حذف فعلي
  update public.shop_backups b set deleted_at = now(), data = '{}'::jsonb where b.created_at < now() - interval '7 days' and b.deleted_at is null;
  return n;
end $$;
revoke execute on function public.daily_backups() from public, anon, authenticated;

create or replace function public.list_backups() returns table(id uuid, created_at timestamptz, size_kb integer)
language plpgsql stable security definer set search_path = public as $$
#variable_conflict use_column
begin
  perform public.ledger_require(array['owner']::public.app_role[]);
  return query select b.id, b.created_at, (octet_length(b.data::text) / 1024)::int from public.shop_backups b
    where b.shop_id = public.current_shop_id() and b.deleted_at is null order by b.created_at desc;
end $$;
create or replace function public.get_backup(p_id uuid) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare d jsonb;
begin
  perform public.ledger_require(array['owner']::public.app_role[]);
  select data into d from public.shop_backups where id = p_id and shop_id = public.current_shop_id() and deleted_at is null;
  if d is null then raise exception 'E_NOT_FOUND'; end if;
  return d;
end $$;
do $$
declare f text;
begin
  foreach f in array array['apply_status_lww(uuid, public.device_status, timestamptz)', 'list_backups()', 'get_backup(uuid)'] loop
    execute format('revoke execute on function public.%s from public, anon', f);
    execute format('grant execute on function public.%s to authenticated', f);
  end loop;
end $$;

-- جدولة يومية (3 الفجر بتوقيت القاهرة تقريبًا = 1 UTC) لو pg_cron متاح في المشروع
do $$
begin
  begin
    create extension if not exists pg_cron;
  exception when others then
    raise notice 'pg_cron مش متاح: النسخة اليومية التلقائية مش هتشتغل، والتصدير اليدوي شغال';
    return;
  end;
  begin
    perform cron.schedule('warsha-daily-backup', '0 1 * * *', 'select public.daily_backups()');
  exception when others then
    raise notice 'ما قدرناش نجدول النسخة اليومية: %', sqlerrm;
  end;
end $$;
$m0015$;
  insert into public.app_migrations(version, how) values ('0015_offline_backup.sql', 'applied');
  raise notice 'applied %', '0015_offline_backup.sql';
end $run$;
commit;

-- ============================== 0016_shop_identity.sql ==============================
begin;
do $run$ begin
  if exists (select 1 from public.app_migrations where version = '0016_shop_identity.sql') then return; end if;
  execute $m0016$
-- هوية كل محل على كل حاجة بتتطبع أو بتوصل للعميل (طلب صاحب المشروع)
--
-- - shop_branding: الاسم بالإنجليزي، والشعار القصير، والتليفونات، وواتساب، والسوشيال، واللوجو.
-- - اللوجو الأصلي في Storage (shop-logos) تحت shop_id، والـ bucket بقى خاص: كل محل بيشوف لوجو محله بس.
-- - بيتحفظ كمان نسختين جاهزين للطباعة (ملونة للفاتورة وصفحة التتبع، وأبيض وأسود للطابعة الحرارية) كصورة PNG صغيرة
--   في الجدول نفسه. كده الطباعة شغالة بدون نت، وصفحة التتبع العامة بتعرض اللوجو من غير ما تفتح الـ Storage للزوار.
-- - سطر "بواسطة [اسم التطبيق]" مقفول افتراضيًا.

create table public.shop_branding (
  id uuid primary key,
  shop_id uuid not null unique references public.shops(id),
  name_en text check (name_en is null or length(name_en) <= 120),
  tagline text check (tagline is null or length(tagline) <= 120),
  phones text[] not null default '{}' check (cardinality(phones) <= 4),
  whatsapp text check (whatsapp is null or length(whatsapp) <= 20),
  socials jsonb not null default '{}'::jsonb,
  logo_path text,                                   -- الأصل في Storage
  logo_color text check (logo_color is null or (logo_color like 'data:image/png;base64,%' and length(logo_color) < 700000)),
  logo_thermal text check (logo_thermal is null or (logo_thermal like 'data:image/png;base64,%' and length(logo_thermal) < 400000)),
  thermal_contrast integer not null default 50 check (thermal_contrast between 0 and 100),
  thermal_custom boolean not null default false,   -- صاحب المحل رفع نسخة حرارية بنفسه
  show_powered_by boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);
alter table public.shop_branding enable row level security;
revoke all on public.shop_branding from public, anon, authenticated;
create policy branding_select on public.shop_branding for select to authenticated using (shop_id = public.current_shop_id());
create policy branding_insert on public.shop_branding for insert to authenticated with check (shop_id = public.current_shop_id() and public.current_app_role() = 'owner');
create policy branding_update on public.shop_branding for update to authenticated using (shop_id = public.current_shop_id() and public.current_app_role() = 'owner') with check (shop_id = public.current_shop_id());
grant select, insert, update on public.shop_branding to authenticated;
create trigger set_updated_at before update on public.shop_branding for each row execute function public.tg_set_updated_at();
create trigger block_delete before delete on public.shop_branding for each row execute function public.tg_block_delete();
create trigger a_force_shop_id before insert or update on public.shop_branding for each row execute function public.tg_force_shop_id();
create trigger zz_audit after insert or update on public.shop_branding for each row execute function public.tg_audit();

-- ---------- اللوجو في Storage: خاص بكل محل ----------
update storage.buckets set public = false, file_size_limit = 2097152,
  allowed_mime_types = array['image/png', 'image/jpeg', 'image/svg+xml', 'image/webp'] where id = 'shop-logos';
do $$
begin
  begin
    drop policy if exists shop_logos_read on storage.objects;
  exception when others then null;
  end;
end $$;
create policy shop_logos_read on storage.objects for select to authenticated
  using (bucket_id = 'shop-logos' and (storage.foldername(name))[1] = public.current_shop_id()::text);
create policy shop_logos_update on storage.objects for update to authenticated
  using (bucket_id = 'shop-logos' and (storage.foldername(name))[1] = public.current_shop_id()::text and public.current_app_role() = 'owner');

-- ---------- صفحة التتبع: لوجو المحل الملون من الهوية ----------
create or replace function public.get_tracking(p_order text default null, p_last4 text default null, p_token text default null)
returns table(
  order_no text, status public.device_status, brand text, model text, received_at timestamptz,
  updated_at timestamptz, estimated_cost integer, final_cost integer, technician text,
  shop_name text, shop_phone text, shop_logo text, currency text, warranty_until timestamptz,
  can_decide boolean, decision text, due bigint
)
language plpgsql security definer set search_path = public as $$
declare
  k text := public.tracking_guard(p_order);
  d public.devices;
begin
  d := public.tracking_find(p_order, p_last4, p_token);
  if d.id is null then
    insert into public.tracking_attempts(client_key, order_no, success, guess) values (k, trim(p_order), false, public.tracking_guess(p_order, p_last4));
    return;
  end if;
  insert into public.tracking_attempts(shop_id, client_key, order_no, success) values (d.shop_id, k, d.order_no, true);
  return query
  select d.order_no, d.status, d.brand, d.model, d.received_at,
    coalesce((select max(l.created_at) from public.status_log l where l.device_id = d.id), d.updated_at),
    dc.estimated_cost, dc.final_cost,
    (select split_part(p.full_name, ' ', 1) from public.status_log l join public.profiles p on p.id = l.changed_by
       where l.device_id = d.id and p.role = 'technician' order by l.created_at desc limit 1),
    s.name, s.phone,
    -- لوجو المحل الملون (صورة صغيرة جاهزة)، مش مسار في Storage
    (select b.logo_color from public.shop_branding b where b.shop_id = s.id and b.deleted_at is null),
    s.currency, d.warranty_until,
    d.status = 'awaiting_approval' and not exists (
      select 1 from public.quote_decisions q where q.device_id = d.id and q.created_at > coalesce(
        (select max(l.created_at) from public.status_log l where l.device_id = d.id and l.new_status = 'awaiting_approval'), d.received_at)),
    (select q.decision from public.quote_decisions q where q.device_id = d.id order by q.created_at desc limit 1),
    case when dc.final_cost is not null then greatest(dc.final_cost - public.device_paid(d.id), 0)::bigint end
  from public.shops s
  left join public.device_costs dc on dc.device_id = d.id and dc.deleted_at is null
  where s.id = d.shop_id;
end $$;
revoke execute on function public.get_tracking(text, text, text) from public;
grant execute on function public.get_tracking(text, text, text) to anon, authenticated;

-- ---------- النسخة الاحتياطية بتشمل الهوية ----------
create or replace function public.backup_snapshot(p_shop uuid) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare
  res jsonb := jsonb_build_object('format', 'warsha-backup', 'version', 1, 'generated_at', now(), 'shop_id', p_shop);
  t text;
  rows jsonb;
begin
  foreach t in array array['shops', 'shop_branding', 'profiles', 'customers', 'devices', 'device_costs', 'status_log', 'device_notes', 'device_photos', 'device_checks',
                           'quote_decisions', 'message_templates', 'message_log', 'accounts', 'journal_entries', 'journal_lines', 'payments', 'drawer_closings',
                           'suppliers', 'items', 'stock_moves', 'purchases', 'labor_rates', 'specialties', 'staff_specialties', 'routes', 'repair_steps', 'audit_log'] loop
    execute format('select coalesce(jsonb_agg(to_jsonb(x)), ''[]''::jsonb) from public.%I x where x.shop_id = $1', t) into rows using p_shop;
    res := res || jsonb_build_object(t, rows);
  end loop;
  select coalesce(jsonb_agg(jsonb_build_object('device_id', device_id, 'kind', kind, 'erased_at', erased_at)), '[]'::jsonb)
    into rows from public.device_passcodes where shop_id = p_shop;
  return res || jsonb_build_object('device_passcodes', rows);
end $$;
revoke execute on function public.backup_snapshot(uuid) from public, anon, authenticated;
$m0016$;
  insert into public.app_migrations(version, how) values ('0016_shop_identity.sql', 'applied');
  raise notice 'applied %', '0016_shop_identity.sql';
end $run$;
commit;

-- ============================== 0017_growth.sql ==============================
begin;
do $run$ begin
  if exists (select 1 from public.app_migrations where version = '0017_growth.sql') then return; end if;
  execute $m0017$
-- المرحلة 6: النمو
--
-- 1) دور "مدير التسويق" (marketing): بيشوف فيديوهات الإصلاح بس. مش معدود موظف في المحل في أي صلاحية تانية
--    (current_shop_id بيرجّع فاضي ليه)، فما بيشوفش أجهزة ولا عملاء ولا فلوس.
-- 2) فيديوهات الإصلاح: الفني بيرفع، ومدير التسويق بيراجع، والمقبول بيزوّد نقاط الفني. من غير بيانات العميل.
-- 3) تقييم العميل للجهاز بعد التسليم (من صفحة التتبع)، وبيتحسب للفني اللي قفله.
-- 4) مجتمع الفنيين: مشترك بين المحلات (مقصود)، ومن غير بيانات عملاء: أي نص فيه رقم موبايل أو IMEI بيترفض. والمشرف بيخفي.
-- 5) الخطط والحدود: كل محل على خطة (مجانية افتراضيًا)، والحد بيتطبق في قاعدة البيانات.
-- 6) لوحة المشرف (صاحب المنصة بس): المحلات واستخدامها من غير بيانات عملاء، وتغيير الخطة، والإيقاف، ومراجعة المجتمع.
-- 7) عداد استخدام المساعد الذكي (الحد اليومي من الخطة). الأسئلة نفسها ما بتتخزنش.
--
-- ملحوظة: القيمة الجديدة في enum بتتستخدم كنص (::text) في الملف ده، عشان الملف يشتغل في transaction واحدة.

alter type public.app_role add value if not exists 'marketing';

-- ============================================================
-- الخطط
-- ============================================================
create table public.plans (
  code text primary key,
  max_devices_month integer,  -- null = من غير حد
  max_staff integer,
  ai_daily integer not null default 0,
  max_videos integer,
  sort integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);
insert into public.plans(code, max_devices_month, max_staff, ai_daily, max_videos, sort) values
  ('free', 300, 5, 20, 50, 1),
  ('pro', null, null, 200, null, 2)
on conflict (code) do nothing;
alter table public.plans enable row level security;
revoke all on public.plans from public, anon, authenticated;
create policy plans_read on public.plans for select to authenticated using (true);
grant select on public.plans to authenticated;

alter table public.shops add column if not exists plan_code text not null default 'free' references public.plans(code);
alter table public.shops add column if not exists suspended_at timestamptz;

-- ============================================================
-- المشرفين (صاحب المنصة)
-- ============================================================
create table public.platform_admins (
  user_id uuid primary key references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);
alter table public.platform_admins enable row level security;
revoke all on public.platform_admins from public, anon, authenticated;

create or replace function public.is_platform_admin() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.platform_admins where user_id = auth.uid() and deleted_at is null)
$$;

-- ============================================================
-- المحل الحالي: مدير التسويق والمحل الموقوف ملهمش محل في الصلاحيات العادية
-- ============================================================
create or replace function public.current_shop_id() returns uuid
language sql stable security definer set search_path = public as $$
  select p.shop_id from public.profiles p join public.shops s on s.id = p.shop_id
  where p.id = auth.uid() and p.deleted_at is null and p.role::text <> 'marketing' and s.suspended_at is null
$$;
-- محل مدير التسويق (للفيديوهات بس)
create or replace function public.marketing_shop_id() returns uuid
language sql stable security definer set search_path = public as $$
  select p.shop_id from public.profiles p join public.shops s on s.id = p.shop_id
  where p.id = auth.uid() and p.deleted_at is null and p.role::text = 'marketing' and s.suspended_at is null
$$;
-- أي حد في المحل (لأي دور، ومنهم التسويق) — للفيديوهات والمجتمع
create or replace function public.member_shop_id() returns uuid
language sql stable security definer set search_path = public as $$
  select p.shop_id from public.profiles p join public.shops s on s.id = p.shop_id
  where p.id = auth.uid() and p.deleted_at is null and s.suspended_at is null
$$;
create or replace function public.member_role() returns text
language sql stable security definer set search_path = public as $$
  select p.role::text from public.profiles p where p.id = auth.uid() and p.deleted_at is null
$$;

-- الصف الجديد بياخد محل المستخدم (لأي دور، ومنهم التسويق). الصلاحيات (RLS) هي اللي بتمنع التسويق من الجداول
create or replace function public.tg_force_shop_id() returns trigger
language plpgsql security definer set search_path = public as $$
declare s uuid := coalesce(public.current_shop_id(), public.member_shop_id());
begin
  if current_setting('warsha.system', true) = 'on' then
    return new;
  end if;
  if s is null then
    if tg_op = 'UPDATE' and auth.uid() is null and new.shop_id = old.shop_id then
      return new;
    end if;
    raise exception 'E_NO_SHOP';
  end if;
  if tg_op = 'INSERT' then
    new.shop_id := s;
  elsif new.shop_id is distinct from old.shop_id then
    raise exception 'E_SHOP_CHANGE';
  end if;
  return new;
end $$;

-- ============================================================
-- حدود الخطة
-- ============================================================
create or replace function public.shop_plan(p_shop uuid) returns public.plans
language sql stable security definer set search_path = public as $$
  select pl.* from public.shops s join public.plans pl on pl.code = s.plan_code where s.id = p_shop
$$;

create or replace function public.tg_plan_devices() returns trigger
language plpgsql security definer set search_path = public as $$
declare pl public.plans := public.shop_plan(new.shop_id); n int;
begin
  if pl.max_devices_month is not null then
    select count(*) into n from public.devices
     where shop_id = new.shop_id and received_at >= date_trunc('month', now() at time zone 'Africa/Cairo') at time zone 'Africa/Cairo';
    if n >= pl.max_devices_month then raise exception 'E_PLAN_LIMIT'; end if;
  end if;
  return new;
end $$;
create trigger zz_plan_devices before insert on public.devices for each row execute function public.tg_plan_devices();

create or replace function public.tg_plan_staff() returns trigger
language plpgsql security definer set search_path = public as $$
declare pl public.plans := public.shop_plan(new.shop_id); n int;
begin
  if pl.max_staff is not null then
    select (select count(*) from public.profiles where shop_id = new.shop_id and deleted_at is null)
         + (select count(*) from public.staff_invites where shop_id = new.shop_id and accepted_at is null and deleted_at is null) into n;
    if n >= pl.max_staff then raise exception 'E_PLAN_LIMIT'; end if;
  end if;
  return new;
end $$;
create trigger zz_plan_staff before insert on public.staff_invites for each row execute function public.tg_plan_staff();

-- استخدام المحل وحدود خطته (صاحب المحل)
create or replace function public.plan_usage() returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare s uuid := public.current_shop_id(); pl public.plans;
begin
  if public.current_app_role() is distinct from 'owner' then raise exception 'E_FORBIDDEN'; end if;
  pl := public.shop_plan(s);
  return jsonb_build_object(
    'plan', pl.code, 'max_devices_month', pl.max_devices_month, 'max_staff', pl.max_staff, 'ai_daily', pl.ai_daily, 'max_videos', pl.max_videos,
    'devices_month', (select count(*) from public.devices where shop_id = s and received_at >= date_trunc('month', now() at time zone 'Africa/Cairo') at time zone 'Africa/Cairo'),
    'staff', (select count(*) from public.profiles where shop_id = s and deleted_at is null),
    'ai_today', (select count(*) from public.ai_usage where shop_id = s and created_at >= date_trunc('day', now() at time zone 'Africa/Cairo') at time zone 'Africa/Cairo'),
    'videos', (select count(*) from public.repair_videos where shop_id = s and deleted_at is null));
end $$;

-- ============================================================
-- فيديوهات الإصلاح
-- ============================================================
create table public.repair_videos (
  id uuid primary key,
  shop_id uuid not null references public.shops(id),
  technician_id uuid not null references public.profiles(id),
  device_id uuid references public.devices(id),
  title text not null check (length(trim(title)) between 1 and 120),
  description text check (description is null or length(description) <= 1000),
  storage_path text not null,
  status text not null default 'pending' check (status in ('pending', 'approved', 'rejected')),
  points integer not null default 0 check (points between 0 and 100),
  review_note text check (review_note is null or length(review_note) <= 500),
  reviewed_by uuid references public.profiles(id),
  reviewed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);
alter table public.repair_videos enable row level security;
revoke all on public.repair_videos from public, anon, authenticated;
-- الفني بيشوف فيديوهاته، وصاحب المحل ومدير التسويق بيشوفوا فيديوهات المحل كلها
create policy videos_select on public.repair_videos for select to authenticated using (
  shop_id = public.member_shop_id() and (technician_id = auth.uid() or public.member_role() in ('owner', 'marketing')));
grant select on public.repair_videos to authenticated;
create trigger set_updated_at before update on public.repair_videos for each row execute function public.tg_set_updated_at();
create trigger block_delete before delete on public.repair_videos for each row execute function public.tg_block_delete();
create trigger zz_audit after insert or update on public.repair_videos for each row execute function public.tg_audit();

-- الفني (أو صاحب المحل) بيضيف فيديو بعد ما يرفعه في Storage
create or replace function public.add_video(p_id uuid, p_title text, p_path text, p_device uuid default null, p_description text default null) returns uuid
language plpgsql security definer set search_path = public as $$
declare s uuid := public.member_shop_id(); pl public.plans;
begin
  if public.member_role() not in ('technician', 'owner') then raise exception 'E_FORBIDDEN'; end if;
  if p_path is null or split_part(p_path, '/', 1) <> s::text then raise exception 'E_BAD_INPUT'; end if;
  if p_device is not null and not exists (select 1 from public.devices where id = p_device and shop_id = s) then raise exception 'E_NOT_FOUND'; end if;
  if public.has_private_data(coalesce(p_title, '') || ' ' || coalesce(p_description, '')) then raise exception 'E_PRIVATE_DATA'; end if;
  pl := public.shop_plan(s);
  if pl.max_videos is not null and (select count(*) from public.repair_videos where shop_id = s and deleted_at is null) >= pl.max_videos then raise exception 'E_PLAN_LIMIT'; end if;
  insert into public.repair_videos(id, shop_id, technician_id, device_id, title, description, storage_path)
  values (p_id, s, auth.uid(), p_device, trim(p_title), nullif(trim(p_description), ''), p_path)
  on conflict (id) do nothing;
  return p_id;
end $$;

-- مدير التسويق (أو صاحب المحل) بيراجع: موافقة بنقاط للفني، أو رفض
create or replace function public.review_video(p_video uuid, p_approve boolean, p_points integer default 10, p_note text default null) returns void
language plpgsql security definer set search_path = public as $$
declare v public.repair_videos;
begin
  if public.member_role() not in ('marketing', 'owner') then raise exception 'E_FORBIDDEN'; end if;
  select * into v from public.repair_videos where id = p_video and shop_id = public.member_shop_id() and deleted_at is null for update;
  if not found then raise exception 'E_NOT_FOUND'; end if;
  if p_points < 0 or p_points > 100 then raise exception 'E_BAD_INPUT'; end if;
  update public.repair_videos set status = case when p_approve then 'approved' else 'rejected' end,
    points = case when p_approve then p_points else 0 end, review_note = nullif(trim(p_note), ''), reviewed_by = auth.uid(), reviewed_at = now()
  where id = v.id;
end $$;

-- Storage للفيديوهات: خاص بكل محل
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('repair-videos', 'repair-videos', false, 104857600, array['video/mp4', 'video/webm', 'video/quicktime'])
on conflict (id) do nothing;
create policy videos_upload on storage.objects for insert to authenticated
  with check (bucket_id = 'repair-videos' and (storage.foldername(name))[1] = public.member_shop_id()::text and public.member_role() in ('technician', 'owner'));
create policy videos_read on storage.objects for select to authenticated
  using (bucket_id = 'repair-videos' and (storage.foldername(name))[1] = public.member_shop_id()::text and public.member_role() in ('technician', 'owner', 'marketing'));

-- ============================================================
-- تقييمات العملاء
-- ============================================================
create table public.device_ratings (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references public.shops(id),
  device_id uuid not null unique references public.devices(id),
  technician_id uuid references public.profiles(id),
  stars integer not null check (stars between 1 and 5),
  comment text check (comment is null or length(comment) <= 500),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);
alter table public.device_ratings enable row level security;
revoke all on public.device_ratings from public, anon, authenticated;
create policy ratings_select on public.device_ratings for select to authenticated using (shop_id = public.current_shop_id() and public.current_app_role() in ('owner', 'reception'));
grant select on public.device_ratings to authenticated;
create trigger ratings_immutable before update or delete on public.device_ratings for each row execute function public.tg_ledger_immutable();

-- حالة التقييم في صفحة التتبع (بالرمز السري بس)
create or replace function public.rating_state(p_token text) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare d public.devices;
begin
  select * into d from public.devices where tracking_token = p_token and deleted_at is null;
  if not found then return jsonb_build_object('can_rate', false); end if;
  return jsonb_build_object('can_rate', d.status = 'delivered' and not exists (select 1 from public.device_ratings r where r.device_id = d.id),
                            'stars', (select stars from public.device_ratings r where r.device_id = d.id));
end $$;

-- العميل بيقيّم مرة واحدة بعد التسليم. التقييم بيتحسب للفني اللي قفل الجهاز
create or replace function public.rate_device(p_token text, p_stars integer, p_comment text default null) returns void
language plpgsql security definer set search_path = public as $$
declare d public.devices; k text := public.tracking_guard(null); t uuid;
begin
  if p_stars is null or p_stars < 1 or p_stars > 5 then raise exception 'E_BAD_INPUT'; end if;
  select * into d from public.devices where tracking_token = p_token and deleted_at is null;
  if not found then
    insert into public.tracking_attempts(client_key, order_no, success) values (k, null, false);
    return;
  end if;
  if d.status <> 'delivered' then raise exception 'E_BAD_TRANSITION'; end if;
  if exists (select 1 from public.device_ratings where device_id = d.id) then raise exception 'E_ALREADY_RATED'; end if;
  select s.technician_id into t from public.repair_steps s where s.device_id = d.id and s.status = 'done' and s.technician_id is not null order by s.step_no desc limit 1;
  insert into public.device_ratings(shop_id, device_id, technician_id, stars, comment)
  values (d.shop_id, d.id, t, p_stars, nullif(trim(left(p_comment, 500)), ''));
end $$;

-- ============================================================
-- المجتمع (مشترك بين المحلات، ومن غير بيانات عملاء)
-- ============================================================
-- نص فيه رقم موبايل أو IMEI أو أي رقم طويل = ممكن يكون بيانات عميل
create or replace function public.has_private_data(p text) returns boolean
language sql immutable as $$
  select coalesce(p, '') ~ '(\+?\d[\d\s-]{7,}\d)' or coalesce(p, '') ~ '[٠-٩]{8,}'
$$;

create table public.community_posts (
  id uuid primary key,
  shop_id uuid not null references public.shops(id),  -- محل الكاتب (المنشور نفسه مشترك)
  author_id uuid not null references public.profiles(id),
  parent_id uuid references public.community_posts(id), -- رد على منشور
  title text check (title is null or length(title) between 1 and 160),
  body text not null check (length(trim(body)) between 1 and 4000),
  tags text[] not null default '{}',
  hidden_at timestamptz,
  hidden_by uuid,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);
create index community_posts_parent on public.community_posts(parent_id, created_at);
alter table public.community_posts enable row level security;
revoke all on public.community_posts from public, anon, authenticated;
create policy community_select on public.community_posts for select to authenticated using (
  deleted_at is null and (hidden_at is null or author_id = auth.uid() or public.is_platform_admin()) and public.member_shop_id() is not null);
grant select on public.community_posts to authenticated;
create trigger set_updated_at before update on public.community_posts for each row execute function public.tg_set_updated_at();
create trigger block_delete before delete on public.community_posts for each row execute function public.tg_block_delete();

create table public.community_reports (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references public.shops(id),
  post_id uuid not null references public.community_posts(id),
  reporter_id uuid not null references public.profiles(id),
  reason text check (reason is null or length(reason) <= 300),
  resolved_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  unique (post_id, reporter_id)
);
alter table public.community_reports enable row level security;
revoke all on public.community_reports from public, anon, authenticated;

create or replace function public.community_post(p_id uuid, p_body text, p_title text default null, p_parent uuid default null, p_tags text[] default '{}') returns uuid
language plpgsql security definer set search_path = public as $$
declare s uuid := public.member_shop_id();
begin
  if s is null or public.member_role() = 'marketing' then raise exception 'E_FORBIDDEN'; end if;
  if public.has_private_data(coalesce(p_title, '') || ' ' || coalesce(p_body, '')) then raise exception 'E_PRIVATE_DATA'; end if;
  if p_parent is not null and not exists (select 1 from public.community_posts where id = p_parent and parent_id is null and deleted_at is null and hidden_at is null) then
    raise exception 'E_NOT_FOUND';
  end if;
  insert into public.community_posts(id, shop_id, author_id, parent_id, title, body, tags)
  values (p_id, s, auth.uid(), p_parent, case when p_parent is null then nullif(trim(p_title), '') end, trim(p_body), coalesce(p_tags, '{}'))
  on conflict (id) do nothing;
  return p_id;
end $$;

create or replace function public.community_report(p_post uuid, p_reason text default null) returns void
language plpgsql security definer set search_path = public as $$
begin
  if public.member_shop_id() is null then raise exception 'E_FORBIDDEN'; end if;
  insert into public.community_reports(shop_id, post_id, reporter_id, reason) values (public.member_shop_id(), p_post, auth.uid(), nullif(trim(p_reason), ''))
  on conflict (post_id, reporter_id) do nothing;
end $$;

-- المنشورات مع اسم الكاتب الأول بس واسم محله (من غير أي بيانات عملاء)
create or replace function public.community_feed(p_parent uuid default null, p_limit integer default 50)
returns table(id uuid, parent_id uuid, title text, body text, tags text[], author text, shop text, created_at timestamptz, replies integer, mine boolean, hidden boolean)
language plpgsql stable security definer set search_path = public as $$
#variable_conflict use_column
begin
  if public.member_shop_id() is null then raise exception 'E_FORBIDDEN'; end if;
  return query
  select c.id, c.parent_id, c.title, c.body, c.tags, split_part(p.full_name, ' ', 1), s.name, c.created_at,
         (select count(*)::int from public.community_posts r where r.parent_id = c.id and r.deleted_at is null and r.hidden_at is null),
         c.author_id = auth.uid(), c.hidden_at is not null
  from public.community_posts c join public.profiles p on p.id = c.author_id join public.shops s on s.id = c.shop_id
  where c.deleted_at is null and (c.hidden_at is null or c.author_id = auth.uid() or public.is_platform_admin())
    and ((p_parent is null and c.parent_id is null) or c.parent_id = p_parent or (p_parent is not null and c.id = p_parent))
  order by case when c.id = p_parent then 0 else 1 end, c.created_at desc
  limit least(greatest(p_limit, 1), 200);
end $$;

-- ============================================================
-- المساعد الذكي: عداد بس (الأسئلة ما بتتخزنش)
-- ============================================================
create table public.ai_usage (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references public.shops(id),
  user_id uuid not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);
create index ai_usage_shop_time on public.ai_usage(shop_id, created_at);
alter table public.ai_usage enable row level security;
revoke all on public.ai_usage from public, anon, authenticated;

-- بتتنادى من الـ Edge Function قبل أي سؤال: بتسجل الاستخدام وبترفض لو الحد اليومي خلص
create or replace function public.ai_take() returns jsonb
language plpgsql security definer set search_path = public as $$
declare s uuid := public.member_shop_id(); pl public.plans; n int;
begin
  if s is null or public.member_role() not in ('owner', 'reception', 'technician') then raise exception 'E_FORBIDDEN'; end if;
  pl := public.shop_plan(s);
  select count(*) into n from public.ai_usage where shop_id = s and created_at >= date_trunc('day', now() at time zone 'Africa/Cairo') at time zone 'Africa/Cairo';
  if n >= pl.ai_daily then raise exception 'E_PLAN_LIMIT'; end if;
  insert into public.ai_usage(shop_id, user_id) values (s, auth.uid());
  return jsonb_build_object('left', pl.ai_daily - n - 1);
end $$;

-- ============================================================
-- تقرير الفنيين: + متوسط التقييم + نقاط الفيديوهات
-- ============================================================
drop function if exists public.tech_report(timestamptz, timestamptz);
create or replace function public.tech_report(p_from timestamptz, p_to timestamptz)
returns table(tech_id uuid, name text, devices integer, steps integer, avg_minutes integer, returns integer, return_rate integer, revenue bigint, rating numeric, ratings integer, points integer)
language plpgsql stable security definer set search_path = public as $$
#variable_conflict use_column
declare s uuid := public.current_shop_id();
begin
  perform public.ledger_require(array['owner']::public.app_role[]);
  return query
  with closed as (
    select distinct on (x.device_id) x.device_id, x.technician_id, x.finished_at
    from public.repair_steps x where x.shop_id = s and x.status = 'done' and x.technician_id is not null
    order by x.device_id, x.step_no desc
  )
  select p.id, p.full_name,
    (select count(*)::int from closed c where c.technician_id = p.id and c.finished_at >= p_from and c.finished_at < p_to),
    (select count(*)::int from public.repair_steps x where x.technician_id = p.id and x.status = 'done' and x.finished_at >= p_from and x.finished_at < p_to),
    (select round(avg(extract(epoch from x.finished_at - x.started_at) / 60))::int from public.repair_steps x
      where x.technician_id = p.id and x.status = 'done' and x.started_at is not null and x.finished_at >= p_from and x.finished_at < p_to),
    (select count(*)::int from public.devices d where d.return_of_tech = p.id and d.updated_at >= p_from and d.updated_at < p_to),
    case when (select count(*) from closed c where c.technician_id = p.id) = 0 then 0
         else ((select count(*) from public.devices d where d.return_of_tech = p.id) * 100 / (select count(*) from closed c where c.technician_id = p.id))::int end,
    (select coalesce(sum(l.debit), 0)::bigint from closed c
       join public.journal_entries e on e.source_type = 'delivery' and e.source_id = c.device_id and e.occurred_at >= p_from and e.occurred_at < p_to
         and not exists (select 1 from public.journal_entries r where r.reverses_id = e.id)
       join public.journal_lines l on l.entry_id = e.id and l.debit > 0
     where c.technician_id = p.id),
    (select round(avg(r.stars)::numeric, 1) from public.device_ratings r where r.technician_id = p.id),
    (select count(*)::int from public.device_ratings r where r.technician_id = p.id),
    (select coalesce(sum(v.points), 0)::int from public.repair_videos v where v.technician_id = p.id and v.status = 'approved' and v.deleted_at is null)
  from public.profiles p
  where p.shop_id = s and p.role = 'technician' and p.deleted_at is null
  order by 3 desc, 2;
end $$;

-- ============================================================
-- لوحة المشرف (صاحب المنصة بس): من غير أي بيانات عملاء
-- ============================================================
create or replace function public.admin_shops()
returns table(id uuid, name text, created_at timestamptz, plan text, suspended boolean, staff integer, devices integer, devices_month integer, last_activity timestamptz)
language plpgsql stable security definer set search_path = public as $$
#variable_conflict use_column
begin
  if not public.is_platform_admin() then raise exception 'E_FORBIDDEN'; end if;
  return query
  select s.id, s.name, s.created_at, s.plan_code, s.suspended_at is not null,
         (select count(*)::int from public.profiles p where p.shop_id = s.id and p.deleted_at is null),
         (select count(*)::int from public.devices d where d.shop_id = s.id and d.deleted_at is null),
         (select count(*)::int from public.devices d where d.shop_id = s.id and d.received_at >= date_trunc('month', now())),
         (select max(a.created_at) from public.audit_log a where a.shop_id = s.id)
  from public.shops s order by s.created_at desc;
end $$;

create or replace function public.admin_set_plan(p_shop uuid, p_plan text) returns void
language plpgsql security definer set search_path = public as $$
begin
  if not public.is_platform_admin() then raise exception 'E_FORBIDDEN'; end if;
  if not exists (select 1 from public.plans where code = p_plan) then raise exception 'E_NOT_FOUND'; end if;
  perform set_config('warsha.system', 'on', true);
  update public.shops set plan_code = p_plan where id = p_shop;
  perform set_config('warsha.system', 'off', true);
  insert into public.audit_log(shop_id, actor_id, action, entity, entity_id, after) values (p_shop, auth.uid(), 'admin_set_plan', 'shops', p_shop, jsonb_build_object('plan', p_plan));
end $$;

create or replace function public.admin_suspend(p_shop uuid, p_suspend boolean) returns void
language plpgsql security definer set search_path = public as $$
begin
  if not public.is_platform_admin() then raise exception 'E_FORBIDDEN'; end if;
  perform set_config('warsha.system', 'on', true);
  update public.shops set suspended_at = case when p_suspend then now() end where id = p_shop;
  perform set_config('warsha.system', 'off', true);
  insert into public.audit_log(shop_id, actor_id, action, entity, entity_id, after) values (p_shop, auth.uid(), case when p_suspend then 'admin_suspend' else 'admin_unsuspend' end, 'shops', p_shop, '{}'::jsonb);
end $$;

create or replace function public.admin_reports()
returns table(post_id uuid, body text, author text, shop text, reports integer, hidden boolean, created_at timestamptz)
language plpgsql stable security definer set search_path = public as $$
#variable_conflict use_column
begin
  if not public.is_platform_admin() then raise exception 'E_FORBIDDEN'; end if;
  return query
  select c.id, c.body, split_part(p.full_name, ' ', 1), s.name, count(r.id)::int, c.hidden_at is not null, c.created_at
  from public.community_reports r join public.community_posts c on c.id = r.post_id
  join public.profiles p on p.id = c.author_id join public.shops s on s.id = c.shop_id
  where r.resolved_at is null
  group by c.id, p.full_name, s.name order by 5 desc, c.created_at desc;
end $$;

create or replace function public.admin_moderate(p_post uuid, p_hide boolean) returns void
language plpgsql security definer set search_path = public as $$
begin
  if not public.is_platform_admin() then raise exception 'E_FORBIDDEN'; end if;
  update public.community_posts set hidden_at = case when p_hide then now() end, hidden_by = case when p_hide then auth.uid() end where id = p_post;
  update public.community_reports set resolved_at = now() where post_id = p_post and resolved_at is null;
end $$;

-- الإيقاف والخطة بيتغيروا من المشرف بس (صاحب المحل ما يقدرش يغيّرهم)
create or replace function public.tg_shop_admin_fields() returns trigger
language plpgsql as $$
begin
  if (new.plan_code is distinct from old.plan_code or new.suspended_at is distinct from old.suspended_at)
     and coalesce(current_setting('warsha.system', true), '') <> 'on' then
    raise exception 'E_FORBIDDEN';
  end if;
  return new;
end $$;
create trigger zy_shop_admin_fields before update on public.shops for each row execute function public.tg_shop_admin_fields();

-- ============================================================
-- الصلاحيات للدوال
-- ============================================================
do $$
declare f text;
begin
  foreach f in array array['marketing_shop_id()', 'shop_plan(uuid)'] loop
    execute format('revoke execute on function public.%s from public, anon, authenticated', f);
  end loop;
  foreach f in array array['is_platform_admin()', 'member_shop_id()', 'member_role()', 'plan_usage()', 'add_video(uuid, text, text, uuid, text)',
                           'review_video(uuid, boolean, integer, text)', 'community_post(uuid, text, text, uuid, text[])', 'community_report(uuid, text)',
                           'community_feed(uuid, integer)', 'ai_take()', 'tech_report(timestamptz, timestamptz)', 'admin_shops()', 'admin_set_plan(uuid, text)',
                           'admin_suspend(uuid, boolean)', 'admin_reports()', 'admin_moderate(uuid, boolean)'] loop
    execute format('revoke execute on function public.%s from public, anon', f);
    execute format('grant execute on function public.%s to authenticated', f);
  end loop;
  -- صفحة التتبع (من غير تسجيل دخول)
  foreach f in array array['rating_state(text)', 'rate_device(text, integer, text)'] loop
    execute format('revoke execute on function public.%s from public', f);
    execute format('grant execute on function public.%s to anon, authenticated', f);
  end loop;
end $$;
$m0017$;
  insert into public.app_migrations(version, how) values ('0017_growth.sql', 'applied');
  raise notice 'applied %', '0017_growth.sql';
end $run$;
commit;

select 1 as part, 6 as parts, count(*) as applied_files, max(version) as latest,
  case when '0017_growth.sql' in (select version from public.app_migrations) then
    'الجزء 1 خلص. اللي بعده: upgrade_part_2.sql'
  else 'فيه ملف ما اتطبقش' end as status
from public.app_migrations;
