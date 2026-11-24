-- جوالك / Gawalak: ترقية مشروع Supabase لآخر نسخة، الجزء 4 من 7 (الملفات 0039_payment_plans.sql لـ 0056_branch_features.sql).
-- بيتولد تلقائيًا: npm run db:setup-file. ما تعدّلوش بإيدك.
-- شغّل الأجزاء بالترتيب في SQL Editor (كل جزء لوحده: New query ← الصق ← Run): upgrade_part_1.sql ثم upgrade_part_2.sql ثم upgrade_part_3.sql ثم upgrade_part_4.sql ثم upgrade_part_5.sql ثم upgrade_part_6.sql ثم upgrade_part_7.sql.
-- آمن تشغّل أي جزء أكتر من مرة: اللي اتطبق قبل كده بيتخطى. ولو ملف فشل، اللي قبله بيفضل، وصلّح السبب وشغّل نفس الجزء تاني.
-- لو لقى ملف أحدث موجود وأقدم منه ناقص بيقف (E_UPGRADE_GAP). ولو جزء قبله لسه ما اتطبقش بيقف (E_UPGRADE_ORDER). الاتنين من غير تغيير.
-- ملفات الجزء ده: 0039_payment_plans.sql, 0040_branch_books.sql, 0041_analytics.sql, 0042_app_brand.sql, 0043_printing.sql, 0044_capture.sql, 0045_checklists.sql, 0046_master.sql, 0047_mfa.sql, 0048_used.sql, 0049_commissions.sql, 0050_insights.sql, 0051_demo.sql, 0052_catalog.sql, 0053_portal.sql, 0054_telegram.sql, 0055_eta_placeholder.sql, 0056_branch_features.sql

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
  if not exists (select 1 from public.app_migrations where version = '0075_delete_by_section.sql') and (exists (select 1 from pg_proc p where p.pronamespace = 'public'::regnamespace and p.proname = 'can_delete' and position('select public.current_app_role() in (''owner'', ''reception'')' in p.prosrc) > 0)) then
    insert into public.app_migrations(version, how) values ('0075_delete_by_section.sql', 'found: function can_delete');
  end if;
  if not exists (select 1 from public.app_migrations where version = '0076_debt_aging.sql') and (exists (select 1 from pg_proc p where p.pronamespace = 'public'::regnamespace and p.proname = 'debt_aging' and position('declare s uuid := public.current_shop_id(); today date := (now() at time zone ''Africa/Cairo'')::date; d date := coalesce(p_as_of, today);' in p.prosrc) > 0)) then
    insert into public.app_migrations(version, how) values ('0076_debt_aging.sql', 'found: function debt_aging');
  end if;
  if not exists (select 1 from public.app_migrations where version = '0077_period_lock.sql') and (exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'shops' and column_name = 'books_locked_until')) then
    insert into public.app_migrations(version, how) values ('0077_period_lock.sql', 'found: column shops.books_locked_until');
  end if;
  if not exists (select 1 from public.app_migrations where version = '0078_accountant_export.sql') and (exists (select 1 from pg_proc p where p.pronamespace = 'public'::regnamespace and p.proname = 'accountant_export' and position('s uuid := public.current_shop_id(); own boolean := public.current_app_role() = ''owner''; names boolean; res jsonb;' in p.prosrc) > 0)) then
    insert into public.app_migrations(version, how) values ('0078_accountant_export.sql', 'found: function accountant_export');
  end if;
  if not exists (select 1 from public.app_migrations where version = '0079_purchase_orders.sql') and (to_regclass('public.purchase_orders') is not null) then
    insert into public.app_migrations(version, how) values ('0079_purchase_orders.sql', 'found: table purchase_orders');
  end if;
  if not exists (select 1 from public.app_migrations where version = '0080_stock_count.sql') and (to_regclass('public.stock_counts') is not null) then
    insert into public.app_migrations(version, how) values ('0080_stock_count.sql', 'found: table stock_counts');
  end if;
  if not exists (select 1 from public.app_migrations where version = '0081_repair_invoice.sql') and (to_regclass('public.repair_invoices') is not null) then
    insert into public.app_migrations(version, how) values ('0081_repair_invoice.sql', 'found: table repair_invoices');
  end if;
  if not exists (select 1 from public.app_migrations where version = '0082_order_prefix.sql') and (exists (select 1 from pg_proc p where p.pronamespace = 'public'::regnamespace and p.proname = 'tg_device_defaults' and position('new.order_no := concat_ws(''-'', nullif(pre, ''''), y, lpad(n::text, greatest(4, length(n::text)), ''0''));' in p.prosrc) > 0)) then
    insert into public.app_migrations(version, how) values ('0082_order_prefix.sql', 'found: function tg_device_defaults');
  end if;
  if not exists (select 1 from public.app_migrations where version = '0083_print_perm.sql') and (exists (select 1 from pg_proc p where p.pronamespace = 'public'::regnamespace and p.proname = 'perm_sections' and position('select array[''devices'', ''intake'', ''customers'', ''technicians'', ''inventory'', ''item_create'', ''sales'', ''purchases'', ''cashbox'', ''expenses'', ''finance'', ''partners'', ''reports'', ''staff'', ''settings'', ''print_templates'', ''audit'']' in p.prosrc) > 0)) then
    insert into public.app_migrations(version, how) values ('0083_print_perm.sql', 'found: function perm_sections');
  end if;
  if not exists (select 1 from public.app_migrations where version = '0084_party_branch.sql') and (exists (select 1 from pg_proc p where p.pronamespace = 'public'::regnamespace and p.proname = 'party_branch' and position('if public.current_app_role() = ''owner'' then return null; end if;' in p.prosrc) > 0)) then
    insert into public.app_migrations(version, how) values ('0084_party_branch.sql', 'found: function party_branch');
  end if;
  if not exists (select 1 from public.app_migrations where version = '0085_finance_branch.sql') and (exists (select 1 from pg_proc p where p.pronamespace = 'public'::regnamespace and p.proname = 'financial_position' and position('if public.current_app_role() <> ''owner'' and (p_branch is null or not public.can_branch(p_branch)) then p_branch := public.op_branch(); end if;' in p.prosrc) > 0)) then
    insert into public.app_migrations(version, how) values ('0085_finance_branch.sql', 'found: function financial_position');
  end if;
  insert into public.app_migrations(version, how) select v, 'inferred' from unnest(array['0022_security_review.sql']::text[]) v
    where v < (select max(version) from public.app_migrations) on conflict (version) do nothing;
  select min(v) into first_missing from unnest(array['0001_phase1.sql', '0002_storage.sql', '0003_shop_profile_realtime.sql', '0004_error_codes.sql', '0005_device_passcode.sql', '0006_invite_name.sql', '0007_phase2_customer.sql', '0008_ledger.sql', '0009_tracking_guess_limit.sql', '0010_default_cashboxes.sql', '0011_finance_drilldown.sql', '0012_spec_completion.sql', '0013_tracking_ambiguous.sql', '0014_technicians.sql', '0015_offline_backup.sql', '0016_shop_identity.sql', '0017_growth.sql', '0018_account_state.sql', '0019_extras.sql', '0020_admin_paging.sql', '0021_spec_rules.sql', '0022_security_review.sql', '0023_restore.sql', '0024_signout.sql', '0025_integrity.sql', '0026_edit_delete.sql', '0027_inventory.sql', '0028_opening.sql', '0029_partners.sql', '0030_party_links.sql', '0031_partner_capital.sql', '0032_lists.sql', '0033_assistant.sql', '0034_branches.sql', '0035_lists_everywhere.sql', '0036_roles.sql', '0037_item_details.sql', '0038_roles_grant.sql', '0039_payment_plans.sql', '0040_branch_books.sql', '0041_analytics.sql', '0042_app_brand.sql', '0043_printing.sql', '0044_capture.sql', '0045_checklists.sql', '0046_master.sql', '0047_mfa.sql', '0048_used.sql', '0049_commissions.sql', '0050_insights.sql', '0051_demo.sql', '0052_catalog.sql', '0053_portal.sql', '0054_telegram.sql', '0055_eta_placeholder.sql', '0056_branch_features.sql', '0057_categories.sql', '0058_web_push.sql', '0059_counters_branch.sql', '0060_sale_lines.sql', '0061_attendance.sql', '0062_vat.sql', '0063_cheques.sql', '0064_day_report.sql', '0065_cheque_pending.sql', '0066_commission_net.sql', '0067_idem_lock.sql', '0068_stock_adjust.sql', '0069_sale_errors.sql', '0070_perm_matrix.sql', '0071_device_children.sql', '0072_sale_line_return.sql', '0073_shop_extras.sql', '0074_idem_cheque_plan.sql', '0075_delete_by_section.sql', '0076_debt_aging.sql', '0077_period_lock.sql', '0078_accountant_export.sql', '0079_purchase_orders.sql', '0080_stock_count.sql', '0081_repair_invoice.sql', '0082_order_prefix.sql', '0083_print_perm.sql', '0084_party_branch.sql', '0085_finance_branch.sql']) v where v not in (select version from public.app_migrations);
  select max(version) into later_present from public.app_migrations where first_missing is not null and version > first_missing;
  if later_present is not null then raise exception 'E_UPGRADE_GAP: % موجود، بس % ناقص قبله. ابعت الرسالة دي للمطوّر.', later_present, first_missing; end if;
end $chk$;

-- 2) الأجزاء اللي قبل الجزء ده لازم تكون اتطبقت
do $ord$
declare
  files text[] := array['0001_phase1.sql', '0002_storage.sql', '0003_shop_profile_realtime.sql', '0004_error_codes.sql', '0005_device_passcode.sql', '0006_invite_name.sql', '0007_phase2_customer.sql', '0008_ledger.sql', '0009_tracking_guess_limit.sql', '0010_default_cashboxes.sql', '0011_finance_drilldown.sql', '0012_spec_completion.sql', '0013_tracking_ambiguous.sql', '0014_technicians.sql', '0015_offline_backup.sql', '0016_shop_identity.sql', '0017_growth.sql', '0018_account_state.sql', '0019_extras.sql', '0020_admin_paging.sql', '0021_spec_rules.sql', '0022_security_review.sql', '0023_restore.sql', '0024_signout.sql', '0025_integrity.sql', '0026_edit_delete.sql', '0027_inventory.sql', '0028_opening.sql', '0029_partners.sql', '0030_party_links.sql', '0031_partner_capital.sql', '0032_lists.sql', '0033_assistant.sql', '0034_branches.sql', '0035_lists_everywhere.sql', '0036_roles.sql', '0037_item_details.sql', '0038_roles_grant.sql', '0039_payment_plans.sql', '0040_branch_books.sql', '0041_analytics.sql', '0042_app_brand.sql', '0043_printing.sql', '0044_capture.sql', '0045_checklists.sql', '0046_master.sql', '0047_mfa.sql', '0048_used.sql', '0049_commissions.sql', '0050_insights.sql', '0051_demo.sql', '0052_catalog.sql', '0053_portal.sql', '0054_telegram.sql', '0055_eta_placeholder.sql', '0056_branch_features.sql', '0057_categories.sql', '0058_web_push.sql', '0059_counters_branch.sql', '0060_sale_lines.sql', '0061_attendance.sql', '0062_vat.sql', '0063_cheques.sql', '0064_day_report.sql', '0065_cheque_pending.sql', '0066_commission_net.sql', '0067_idem_lock.sql', '0068_stock_adjust.sql', '0069_sale_errors.sql', '0070_perm_matrix.sql', '0071_device_children.sql', '0072_sale_line_return.sql', '0073_shop_extras.sql', '0074_idem_cheque_plan.sql', '0075_delete_by_section.sql', '0076_debt_aging.sql', '0077_period_lock.sql', '0078_accountant_export.sql', '0079_purchase_orders.sql', '0080_stock_count.sql', '0081_repair_invoice.sql', '0082_order_prefix.sql', '0083_print_perm.sql', '0084_party_branch.sql', '0085_finance_branch.sql'];
  parts int[] := array[1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 3, 3, 3, 3, 3, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 7];
  miss text;
begin
  select min(v) into miss from unnest(files) v where v < '0039_payment_plans.sql' and v not in (select version from public.app_migrations);
  if miss is not null then raise exception 'E_UPGRADE_ORDER: الملف % لسه ما اتطبقش. شغّل upgrade_part_%.sql الأول، وبعدين الجزء ده (4).', miss, parts[array_position(files, miss)]; end if;
end $ord$;

-- 3) ملفات الجزء 4 بالترتيب، كل ملف في transaction لوحده
-- ============================== 0039_payment_plans.sql ==============================
begin;
do $run$ begin
  if exists (select 1 from public.app_migrations where version = '0039_payment_plans.sql') then return; end if;
  execute $m0039$
-- 0039: N (المرحلة الأولى): مواعيد التحصيل وخطط التقسيط ومركز الإشعارات.
-- - خطة لعميل (ليا: هو عليه للمحل) أو لمورد (عليا: المحل عليه للمورد): قسط واحد = "ميعاد تحصيل"، أو كذا قسط بجدول.
-- - المدفوع ما بيتخزنش: بيتحسب من القيود (زي كل الأرصدة). كل اللي بيقلل رصيد الطرف بعد ما الخطة اتعملت
--   (دفعة، أو مرتجع، أو مقاصة) بيتوزع على خطط الطرف بالأقدم، وجوه الخطة على الأقساط بالترتيب:
--   الزيادة بتغطي القسط اللي بعده، والنقص بيفضل على نفس القسط. الخطة بتتقفل لوحدها لما تتغطى كلها.
-- - الإشعارات بتتحسب وقت ما تتطلب (مفيش مهام في الخلفية): أقساط متأخرة، وأقساط قربت، وأجهزة جاهزة من 10 أيام،
--   وأصناف ناقصة، وبيعات محتاجة تسوية. كل مستخدم بيشوف اللي ليه صلاحيته بس، و"اتقرا" بيتحفظ له هو.

create table public.payment_plans (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references public.shops(id),
  branch_id uuid references public.branches(id),
  party_type text not null check (party_type in ('customer', 'supplier')),
  party_id uuid not null,
  title text check (title is null or length(title) <= 120),
  total bigint not null check (total > 0),
  note text check (note is null or length(note) <= 500),
  created_by uuid references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);
create index payment_plans_party on public.payment_plans(shop_id, party_type, party_id) where deleted_at is null;

create table public.plan_installments (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references public.shops(id),
  plan_id uuid not null references public.payment_plans(id),
  seq integer not null check (seq between 1 and 120),
  due_date date not null,
  amount bigint not null check (amount > 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  unique (plan_id, seq)
);

create table public.notification_reads (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references public.shops(id),
  profile_id uuid not null references auth.users(id),
  key text not null check (length(key) <= 120),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  unique (profile_id, key)
);

alter table public.payment_plans enable row level security;
alter table public.plan_installments enable row level security;
alter table public.notification_reads enable row level security;
create trigger set_updated_at before update on public.payment_plans for each row execute function public.tg_set_updated_at();
create trigger set_updated_at before update on public.plan_installments for each row execute function public.tg_set_updated_at();
create trigger set_updated_at before update on public.notification_reads for each row execute function public.tg_set_updated_at();
create trigger block_delete before delete on public.payment_plans for each row execute function public.tg_block_delete();
create trigger block_delete before delete on public.plan_installments for each row execute function public.tg_block_delete();
create trigger block_delete before delete on public.notification_reads for each row execute function public.tg_block_delete();
create trigger zz_audit after insert or update on public.payment_plans for each row execute function public.tg_audit();

-- القراية: صاحب المحل، أو اللي معاه "يشوف" في الوضع المالي (مش الفني). الكتابة من الدوال بس
create policy plans_select on public.payment_plans for select to authenticated
  using (shop_id = public.current_shop_id() and (public.current_app_role() = 'owner' or (public.current_app_role() = 'reception' and (select public.has_perm('finance', 'view')))));
create policy installments_select on public.plan_installments for select to authenticated
  using (shop_id = public.current_shop_id() and (public.current_app_role() = 'owner' or (public.current_app_role() = 'reception' and (select public.has_perm('finance', 'view')))));
create policy reads_select on public.notification_reads for select to authenticated using (profile_id = auth.uid());
grant select on public.payment_plans, public.plan_installments, public.notification_reads to authenticated;

-- كام يوم قبل الميعاد بيبان "قرب" (الإعدادات ← التنبيهات، الافتراضي 3)
create or replace function public.reminder_days() returns integer
language sql stable security definer set search_path = public as $$
  select least(greatest(coalesce((select (s.extras -> 'reminders' ->> 'days')::int from public.shops s where s.id = public.current_shop_id()), 3), 0), 30)
$$;
revoke execute on function public.reminder_days() from public, anon;
grant execute on function public.reminder_days() to authenticated;

-- اللي اتدفع للطرف من وقت معيّن: كل اللي قلّل رصيده (من غير القيود اللي اتلغت ولا قيود الإلغاء نفسها)
create or replace function public.party_paid_since(p_type text, p_party uuid, p_since timestamptz) returns bigint
language sql stable security definer set search_path = public as $$
  select coalesce(sum(case when p_type = 'customer' then l.credit else l.debit end), 0)::bigint
  from public.journal_lines l
  join public.accounts a on a.id = l.account_id and a.kind = case when p_type = 'customer' then 'receivable' else 'payable' end
  join public.journal_entries e on e.id = l.entry_id
  where l.shop_id = public.current_shop_id() and l.party_id = p_party and e.created_at >= p_since
    and e.reverses_id is null and not exists (select 1 from public.journal_entries r where r.reverses_id = e.id)
$$;
revoke execute on function public.party_paid_since(text, uuid, timestamptz) from public, anon, authenticated;

-- الخطط بحالتها: المدفوع والباقي والقسط الجاي والمتأخر، وكل قسط مغطّي قد إيه
create or replace function public.plans_overview(p_party_type text default null, p_party uuid default null)
returns table(plan_id uuid, party_type text, party_id uuid, party_name text, title text, total bigint, paid bigint, remaining bigint,
              next_due date, next_amount bigint, overdue bigint, status text, created_at timestamptz, installments jsonb)
language plpgsql stable security definer set search_path = public as $$
#variable_conflict use_column
declare s uuid := public.current_shop_id(); today date := (now() at time zone 'Africa/Cairo')::date; soon integer := public.reminder_days();
begin
  perform public.grant_require('finance', 'view');
  return query
  with pl as (
    select p.*, min(p.created_at) over (partition by p.party_type, p.party_id) first_at,
           coalesce(sum(p.total) over (partition by p.party_type, p.party_id order by p.created_at, p.id rows between unbounded preceding and 1 preceding), 0) before_total
    from public.payment_plans p
    where p.shop_id = s and p.deleted_at is null
      and (p_party_type is null or p.party_type = p_party_type) and (p_party is null or p.party_id = p_party)
  ), pool as (
    select distinct x.party_type, x.party_id, public.party_paid_since(x.party_type, x.party_id, x.first_at) amount from pl x
  ), paid as (
    select pl.*, least(pl.total, greatest(0, po.amount - pl.before_total))::bigint got
    from pl join pool po on po.party_type = pl.party_type and po.party_id = pl.party_id
  ), inst as (
    select i.plan_id, i.seq, i.due_date, i.amount,
           least(i.amount, greatest(0, pd.got - coalesce(sum(i.amount) over (partition by i.plan_id order by i.seq rows between unbounded preceding and 1 preceding), 0)))::bigint covered
    from public.plan_installments i join paid pd on pd.id = i.plan_id
    where i.deleted_at is null
  )
  select pd.id, pd.party_type, pd.party_id,
         coalesce((select c.name from public.customers c where pd.party_type = 'customer' and c.id = pd.party_id),
                  (select sp.name from public.suppliers sp where pd.party_type = 'supplier' and sp.id = pd.party_id)),
         pd.title, pd.total, pd.got, pd.total - pd.got,
         (select min(x.due_date) from inst x where x.plan_id = pd.id and x.covered < x.amount),
         (select x.amount - x.covered from inst x where x.plan_id = pd.id and x.covered < x.amount order by x.seq limit 1),
         coalesce((select sum(x.amount - x.covered) from inst x where x.plan_id = pd.id and x.covered < x.amount and x.due_date < today), 0)::bigint,
         case when pd.got >= pd.total then 'done'
              when exists (select 1 from inst x where x.plan_id = pd.id and x.covered < x.amount and x.due_date < today) then 'overdue'
              when exists (select 1 from inst x where x.plan_id = pd.id and x.covered < x.amount and x.due_date <= today + soon) then 'due_soon'
              else 'open' end,
         pd.created_at,
         coalesce((select jsonb_agg(jsonb_build_object('seq', x.seq, 'due', x.due_date, 'amount', x.amount, 'covered', x.covered,
                     'status', case when x.covered >= x.amount then 'paid' when x.due_date < today then 'overdue' when x.due_date <= today + soon then 'due_soon' else 'upcoming' end)
                     order by x.seq) from inst x where x.plan_id = pd.id), '[]'::jsonb)
  from paid pd
  order by (pd.got >= pd.total), (select min(x.due_date) from inst x where x.plan_id = pd.id and x.covered < x.amount) nulls last, pd.created_at;
end $$;
revoke execute on function public.plans_overview(text, uuid) from public, anon;
grant execute on function public.plans_overview(text, uuid) to authenticated;

-- خطة جديدة: p_rows = [{due: 'YYYY-MM-DD', amount: قروش}] (قسط واحد = ميعاد تحصيل). الإجمالي = مجموع الأقساط
create or replace function public.save_plan(p_id uuid, p_party_type text, p_party uuid, p_rows jsonb, p_title text default null, p_note text default null) returns uuid
language plpgsql security definer set search_path = public as $$
declare s uuid := public.current_shop_id(); r jsonb; n integer := 0; tot bigint := 0; a bigint; d date;
begin
  perform public.grant_require('finance', 'add');
  if exists (select 1 from public.payment_plans where id = p_id) then
    if exists (select 1 from public.payment_plans where id = p_id and shop_id = s) then return p_id; end if;
    raise exception 'E_NOT_FOUND';
  end if;
  if p_party_type not in ('customer', 'supplier') then raise exception 'E_BAD_INPUT'; end if;
  if p_party_type = 'customer' and not exists (select 1 from public.customers where id = p_party and shop_id = s and deleted_at is null) then raise exception 'E_NOT_FOUND'; end if;
  if p_party_type = 'supplier' and not exists (select 1 from public.suppliers where id = p_party and shop_id = s and deleted_at is null) then raise exception 'E_NOT_FOUND'; end if;
  if jsonb_typeof(p_rows) <> 'array' or jsonb_array_length(p_rows) not between 1 and 120 then raise exception 'E_BAD_INPUT'; end if;
  insert into public.payment_plans(id, shop_id, branch_id, party_type, party_id, title, total, note, created_by)
  values (p_id, s, public.op_branch(), p_party_type, p_party, nullif(trim(p_title), ''), 1, nullif(trim(p_note), ''), auth.uid());
  for r in select * from jsonb_array_elements(p_rows) loop
    n := n + 1;
    a := (r ->> 'amount')::bigint;
    d := (r ->> 'due')::date;
    if a is null or a <= 0 or d is null then raise exception 'E_BAD_AMOUNT'; end if;
    perform public.ledger_amount(a);
    tot := tot + a;
    insert into public.plan_installments(shop_id, plan_id, seq, due_date, amount) values (s, p_id, n, d, a);
  end loop;
  perform public.ledger_amount(tot);
  update public.payment_plans set total = tot where id = p_id;
  return p_id;
end $$;
revoke execute on function public.save_plan(uuid, text, uuid, jsonb, text, text) from public, anon;
grant execute on function public.save_plan(uuid, text, uuid, jsonb, text, text) to authenticated;

-- إلغاء الخطة (مش حذف: بتتعلّم ملغية وبتفضل في سجل النشاط). الفلوس والقيود ما بتتأثرش
create or replace function public.cancel_plan(p_id uuid) returns void
language plpgsql security definer set search_path = public as $$
begin
  perform public.grant_require('finance', 'delete');
  update public.payment_plans set deleted_at = now() where id = p_id and shop_id = public.current_shop_id() and deleted_at is null;
  if not found then raise exception 'E_NOT_FOUND'; end if;
end $$;
revoke execute on function public.cancel_plan(uuid) from public, anon;
grant execute on function public.cancel_plan(uuid) to authenticated;

-- ---------- مركز الإشعارات ----------
-- key ثابت لكل إشعار (عشان "اتقرا" يفضل)، وkind + args بيتحولوا لجملة في الواجهة بلغة البرنامج
create or replace function public.my_notifications()
returns table(key text, kind text, args jsonb, link text, at timestamptz, read boolean)
language plpgsql stable security definer set search_path = public as $$
#variable_conflict use_column
declare s uuid := public.current_shop_id(); r public.app_role := public.current_app_role(); uid uuid := auth.uid();
  today date := (now() at time zone 'Africa/Cairo')::date;
begin
  if r is null then raise exception 'E_FORBIDDEN'; end if;
  -- أقساط متأخرة أو قربت (مين يشوف الوضع المالي)
  if r = 'owner' or (r = 'reception' and public.has_perm('finance', 'view')) then
    return query
    select 'inst:' || i.id::text || ':' || (case when i.due_date < today then 'late' else 'soon' end),
           case when i.due_date < today then 'overdue' else 'due_soon' end,
           jsonb_build_object('name', o.party_name, 'amount', (x ->> 'amount')::bigint - (x ->> 'covered')::bigint, 'due', i.due_date, 'party_type', o.party_type),
           '/finance/' || o.party_type || '/' || o.party_id::text,
           (i.due_date::timestamp at time zone 'Africa/Cairo'),
           false
    from public.plans_overview() o
    cross join lateral jsonb_array_elements(o.installments) x
    join public.plan_installments i on i.plan_id = o.plan_id and i.seq = (x ->> 'seq')::int and i.deleted_at is null
    where x ->> 'status' in ('overdue', 'due_soon');
  end if;
  -- أجهزة جاهزة من 10 أيام أو أكتر ومحدش استلمها (مين يشوف الأجهزة، في فروعه)
  if r <> 'technician' and public.has_perm('devices', 'view') then
    return query
    select 'ready:' || d.id::text, 'ready_old', jsonb_build_object('order', d.order_no, 'days', (today - (sl.at at time zone 'Africa/Cairo')::date)), '/devices/' || d.id::text, sl.at, false
    from public.devices d
    cross join lateral (select max(l.created_at) at from public.status_log l where l.device_id = d.id and l.new_status = 'ready' and l.deleted_at is null) sl
    where d.shop_id = s and d.deleted_at is null and d.status = 'ready' and public.can_branch(d.branch_id)
      and sl.at is not null and sl.at < now() - interval '10 days';
  end if;
  -- أصناف وصلت للحد الأدنى، وبيعات من غير رصيد لسه محتاجة تسوية
  if r <> 'technician' and public.has_perm('inventory', 'view') then
    return query
    select 'short:' || st.id::text || ':' || st.qty::text, 'short', jsonb_build_object('name', st.name, 'qty', st.qty), '/inventory', now(), false
    from public.items_stock() st where st.short;
    return query
    select 'unsettled:' || st.id::text || ':' || st.unsettled::text, 'unsettled', jsonb_build_object('name', st.name, 'qty', st.unsettled), '/inventory', now(), false
    from public.items_stock() st where st.unsettled > 0;
  end if;
end $$;
-- نفس القايمة ومعاها "اتقرا" لكل مستخدم
create or replace function public.notifications_feed()
returns table(key text, kind text, args jsonb, link text, at timestamptz, read boolean)
language sql stable security definer set search_path = public as $$
  select n.key, n.kind, n.args, n.link, n.at, exists (select 1 from public.notification_reads nr where nr.profile_id = auth.uid() and nr.key = n.key and nr.deleted_at is null)
  from public.my_notifications() n
  order by 6, 5 desc
  limit 200
$$;
revoke execute on function public.notifications_feed() from public, anon;
grant execute on function public.notifications_feed() to authenticated;
revoke execute on function public.my_notifications() from public, anon;
grant execute on function public.my_notifications() to authenticated;

create or replace function public.mark_notifications_read(p_keys text[]) returns void
language plpgsql security definer set search_path = public as $$
declare s uuid := public.current_shop_id();
begin
  if s is null or auth.uid() is null then raise exception 'E_FORBIDDEN'; end if;
  if coalesce(array_length(p_keys, 1), 0) > 200 then raise exception 'E_BAD_INPUT'; end if;
  insert into public.notification_reads(shop_id, profile_id, key)
  select s, auth.uid(), k from unnest(p_keys) k where length(k) between 1 and 120
  on conflict (profile_id, key) do nothing;
end $$;
revoke execute on function public.mark_notifications_read(text[]) from public, anon;
grant execute on function public.mark_notifications_read(text[]) to authenticated;

-- ---------- النسخة الاحتياطية والاسترجاع: الخطط والأقساط ----------
-- backup_snapshot: (src: 0037_item_details.sql) + payment_plans وplan_installments
create or replace function public.backup_snapshot(p_shop uuid) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare
  res jsonb := jsonb_build_object('format', 'warsha-backup', 'version', 1, 'generated_at', now(), 'shop_id', p_shop);
  t text;
  rows jsonb;
begin
  foreach t in array array['shops', 'branches', 'staff_branches', 'shop_branding', 'profiles', 'customers', 'devices', 'device_costs', 'status_log', 'device_notes', 'device_photos', 'device_checks',
                           'quote_decisions', 'message_templates', 'message_log', 'accounts', 'journal_entries', 'journal_lines', 'payments', 'drawer_closings',
                           'suppliers', 'items', 'stock_moves', 'uncosted_sales', 'payment_plans', 'plan_installments', 'purchases', 'labor_rates', 'specialties', 'staff_specialties', 'routes', 'repair_steps',
                           'repair_videos', 'device_ratings', 'issue_presets', 'partners', 'profit_distributions', 'party_links', 'shop_lists', 'audit_log'] loop
    execute format('select coalesce(jsonb_agg(to_jsonb(x)), ''[]''::jsonb) from public.%I x where x.shop_id = $1', t) into rows using p_shop;
    res := res || jsonb_build_object(t, rows);
  end loop;
  select coalesce(jsonb_agg(jsonb_build_object('device_id', device_id, 'kind', kind, 'erased_at', erased_at)), '[]'::jsonb)
    into rows from public.device_passcodes where shop_id = p_shop;
  return res || jsonb_build_object('device_passcodes', rows);
end $$;

-- restore_backup: (src: 0037_item_details.sql) + payment_plans وplan_installments
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
                       'purchases', 'stock_moves', 'uncosted_sales', 'payment_plans', 'plan_installments', 'drawer_closings', 'message_log', 'audit_log'];
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
$m0039$;
  insert into public.app_migrations(version, how) values ('0039_payment_plans.sql', 'applied');
  raise notice 'applied %', '0039_payment_plans.sql';
end $run$;
commit;

-- ============================== 0040_branch_books.sql ==============================
begin;
do $run$ begin
  if exists (select 1 from public.app_migrations where version = '0040_branch_books.sql') then return; end if;
  execute $m0040$
-- 0040: U2: كل فرع مستقل ماليًا (التطوير الكبير).
-- الدفتر واحد للمحل والقيود ما بتتغيرش خالص. كل سطر بيتنسب لفرع:
--   - الخزنة (kind = cash) ← فرع الخزنة نفسها.
--   - المخزون ← فرع حركة المخزون بتاعة نفس القيد (التحويل بين فرعين: الخارج من فرع والداخل للتاني).
--   - أي حساب تاني ← فرع القيد.
-- القيد اللي لمس فرعين (تحويل فلوس أو بضاعة) بيتولد له سطر محسوب "مستحق من فرع / مستحق لفرع" في كل فرع،
-- بحيث كل فرع يقفل متوازن لوحده، والمستحقات تلغي بعض في المجموع (مجموع المحل زي ما هو بالظبط).

-- السطور منسوبة للفروع: amount = مدين − دائن. account_id = null ← سطر "مستحق بين الفروع"
-- (من غير فحص صلاحية: بتتنادى من الدوال اللي فحصت بنفسها، ومقفولة على المستخدمين)
create or replace function public.branch_lines_raw(p_to timestamptz default null)
returns table(entry_id uuid, occurred_at timestamptz, source_type text, branch_id uuid, account_id uuid, amount bigint)
language plpgsql stable security definer set search_path = public as $$
#variable_conflict use_column
declare s uuid := public.current_shop_id(); inv uuid;
begin
  select a.id into inv from public.accounts a where a.shop_id = s and a.code = 'inventory' and a.deleted_at is null limit 1;
  return query
  with en as (
    select e.id, e.branch_id, e.occurred_at, e.source_type from public.journal_entries e
    where e.shop_id = s and (p_to is null or e.occurred_at < p_to)
  ), raw as (
    -- كل الحسابات غير المخزون
    select l.entry_id, coalesce(case when a.kind = 'cash' then a.branch_id end, en.branch_id) br, l.account_id acc, (l.debit - l.credit)::bigint amt
    from public.journal_lines l join en on en.id = l.entry_id join public.accounts a on a.id = l.account_id
    where l.account_id is distinct from inv
    union all
    -- المخزون: بفرع حركة المخزون
    select m.entry_id, m.branch_id, inv, sum(m.value)::bigint
    from public.stock_moves m join en on en.id = m.entry_id
    group by m.entry_id, m.branch_id
    union all
    -- لو سطر المخزون في القيد مش متغطي بحركات (نادر): الفرق على فرع القيد، عشان ولا قرش يضيع
    select en.id, en.branch_id, inv,
           (coalesce((select sum(l.debit - l.credit) from public.journal_lines l where l.entry_id = en.id and l.account_id = inv), 0)
            - coalesce((select sum(m.value) from public.stock_moves m where m.entry_id = en.id), 0))::bigint
    from en
  ), agg as (
    select r.entry_id, r.br, r.acc, sum(r.amt)::bigint amt from raw r group by 1, 2, 3 having sum(r.amt) <> 0
  ), due as (
    select a.entry_id, a.br, null::uuid acc, (-sum(a.amt))::bigint amt from agg a group by 1, 2 having sum(a.amt) <> 0
  )
  select x.entry_id, en.occurred_at, en.source_type, x.br, x.acc, x.amt
  from (select * from agg union all select * from due) x join en on en.id = x.entry_id
  -- الموظف: فروعه بس
  where public.all_my_branches() or public.can_branch(x.br);
end $$;
revoke execute on function public.branch_lines_raw(timestamptz) from public, anon, authenticated;

create or replace function public.branch_lines(p_to timestamptz default null)
returns table(entry_id uuid, occurred_at timestamptz, source_type text, branch_id uuid, account_id uuid, amount bigint)
language plpgsql stable security definer set search_path = public as $$
begin
  perform public.grant_require('finance', 'view');
  return query select * from public.branch_lines_raw(p_to);
end $$;
revoke execute on function public.branch_lines(timestamptz) from public, anon;
grant execute on function public.branch_lines(timestamptz) to authenticated;

-- ميزان المراجعة: لفرع (p_branch) أو موحّد (null). كل فرع بيقفل متوازن لوحده (مجموع الأرصدة = صفر)،
-- والموحّد ما فيهوش مستحقات (بتلغي بعض)
create or replace function public.trial_balance(p_branch uuid default null, p_to timestamptz default null)
returns table(account_id uuid, code text, name text, type text, kind text, debit bigint, credit bigint, balance bigint)
language plpgsql stable security definer set search_path = public as $$
#variable_conflict use_column
begin
  perform public.grant_require('finance', 'view');
  if p_branch is not null and not public.all_my_branches() and not public.can_branch(p_branch) then raise exception 'E_FORBIDDEN'; end if;
  if p_branch is null and not public.all_my_branches() then p_branch := public.op_branch(); end if;
  return query
  with b as (select * from public.branch_lines_raw(p_to) bl where p_branch is null or bl.branch_id = p_branch),
  t as (select b.account_id acc, sum(greatest(b.amount, 0))::bigint dr, sum(greatest(-b.amount, 0))::bigint cr from b group by 1)
  select t.acc, a.code, a.name, coalesce(a.type::text, 'inter_branch'), coalesce(a.kind, 'inter_branch'), t.dr, t.cr, (t.dr - t.cr)::bigint
  from t left join public.accounts a on a.id = t.acc
  where t.dr - t.cr <> 0 or t.acc is null and p_branch is not null
  order by case coalesce(a.type::text, 'inter_branch') when 'asset' then 1 when 'liability' then 2 when 'equity' then 3 when 'revenue' then 4 when 'expense' then 5 else 6 end, a.code nulls last, a.name;
end $$;
revoke execute on function public.trial_balance(uuid, timestamptz) from public, anon;
grant execute on function public.trial_balance(uuid, timestamptz) to authenticated;

-- المستحقات بين كل فرعين: موجب = الفرع ده ليه عند التاني (مستحق من)، سالب = عليه (مستحق لـ)
create or replace function public.inter_branch_dues(p_to timestamptz default null)
returns table(branch_id uuid, other_id uuid, amount bigint)
language plpgsql stable security definer set search_path = public as $$
#variable_conflict use_column
begin
  perform public.grant_require('finance', 'view');
  return query
  with d as (select bl.entry_id, bl.branch_id, bl.amount from public.branch_lines_raw(p_to) bl where bl.account_id is null),
  -- القيد بين فرعين: كل فرع قصاد التاني. لو أكتر من فرعين: بالنسبة (نادر جدًا)
  pairs as (
    select a.branch_id, o.branch_id other, (a.amount * abs(o.amount) / nullif((select sum(abs(z.amount)) from d z where z.entry_id = a.entry_id and z.branch_id <> a.branch_id), 0))::bigint amt
    from d a join d o on o.entry_id = a.entry_id and o.branch_id <> a.branch_id and sign(o.amount) <> sign(a.amount)
  )
  select p.branch_id, p.other, sum(p.amt)::bigint from pairs p group by 1, 2 having sum(p.amt) <> 0 order by 1, 2;
end $$;
revoke execute on function public.inter_branch_dues(timestamptz) from public, anon;
grant execute on function public.inter_branch_dues(timestamptz) to authenticated;
$m0040$;
  insert into public.app_migrations(version, how) values ('0040_branch_books.sql', 'applied');
  raise notice 'applied %', '0040_branch_books.sql';
end $run$;
commit;

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

select 4 as part, 7 as parts, count(*) as applied_files, max(version) as latest,
  case when '0056_branch_features.sql' in (select version from public.app_migrations) then
    'الجزء 4 خلص. اللي بعده: upgrade_part_5.sql'
  else 'فيه ملف ما اتطبقش' end as status
from public.app_migrations;
