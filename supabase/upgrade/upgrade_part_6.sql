-- جوالك / Gawalak: ترقية مشروع Supabase لآخر نسخة، الجزء 6 من 6 (الملفات 0072_sale_line_return.sql لـ 0077_period_lock.sql).
-- بيتولد تلقائيًا: npm run db:setup-file. ما تعدّلوش بإيدك.
-- شغّل الأجزاء بالترتيب في SQL Editor (كل جزء لوحده: New query ← الصق ← Run): upgrade_part_1.sql ثم upgrade_part_2.sql ثم upgrade_part_3.sql ثم upgrade_part_4.sql ثم upgrade_part_5.sql ثم upgrade_part_6.sql.
-- آمن تشغّل أي جزء أكتر من مرة: اللي اتطبق قبل كده بيتخطى. ولو ملف فشل، اللي قبله بيفضل، وصلّح السبب وشغّل نفس الجزء تاني.
-- لو لقى ملف أحدث موجود وأقدم منه ناقص بيقف (E_UPGRADE_GAP). ولو جزء قبله لسه ما اتطبقش بيقف (E_UPGRADE_ORDER). الاتنين من غير تغيير.
-- ملفات الجزء ده: 0072_sale_line_return.sql, 0073_shop_extras.sql, 0074_idem_cheque_plan.sql, 0075_delete_by_section.sql, 0076_debt_aging.sql, 0077_period_lock.sql

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
  insert into public.app_migrations(version, how) select v, 'inferred' from unnest(array['0022_security_review.sql']::text[]) v
    where v < (select max(version) from public.app_migrations) on conflict (version) do nothing;
  select min(v) into first_missing from unnest(array['0001_phase1.sql', '0002_storage.sql', '0003_shop_profile_realtime.sql', '0004_error_codes.sql', '0005_device_passcode.sql', '0006_invite_name.sql', '0007_phase2_customer.sql', '0008_ledger.sql', '0009_tracking_guess_limit.sql', '0010_default_cashboxes.sql', '0011_finance_drilldown.sql', '0012_spec_completion.sql', '0013_tracking_ambiguous.sql', '0014_technicians.sql', '0015_offline_backup.sql', '0016_shop_identity.sql', '0017_growth.sql', '0018_account_state.sql', '0019_extras.sql', '0020_admin_paging.sql', '0021_spec_rules.sql', '0022_security_review.sql', '0023_restore.sql', '0024_signout.sql', '0025_integrity.sql', '0026_edit_delete.sql', '0027_inventory.sql', '0028_opening.sql', '0029_partners.sql', '0030_party_links.sql', '0031_partner_capital.sql', '0032_lists.sql', '0033_assistant.sql', '0034_branches.sql', '0035_lists_everywhere.sql', '0036_roles.sql', '0037_item_details.sql', '0038_roles_grant.sql', '0039_payment_plans.sql', '0040_branch_books.sql', '0041_analytics.sql', '0042_app_brand.sql', '0043_printing.sql', '0044_capture.sql', '0045_checklists.sql', '0046_master.sql', '0047_mfa.sql', '0048_used.sql', '0049_commissions.sql', '0050_insights.sql', '0051_demo.sql', '0052_catalog.sql', '0053_portal.sql', '0054_telegram.sql', '0055_eta_placeholder.sql', '0056_branch_features.sql', '0057_categories.sql', '0058_web_push.sql', '0059_counters_branch.sql', '0060_sale_lines.sql', '0061_attendance.sql', '0062_vat.sql', '0063_cheques.sql', '0064_day_report.sql', '0065_cheque_pending.sql', '0066_commission_net.sql', '0067_idem_lock.sql', '0068_stock_adjust.sql', '0069_sale_errors.sql', '0070_perm_matrix.sql', '0071_device_children.sql', '0072_sale_line_return.sql', '0073_shop_extras.sql', '0074_idem_cheque_plan.sql', '0075_delete_by_section.sql', '0076_debt_aging.sql', '0077_period_lock.sql']) v where v not in (select version from public.app_migrations);
  select max(version) into later_present from public.app_migrations where first_missing is not null and version > first_missing;
  if later_present is not null then raise exception 'E_UPGRADE_GAP: % موجود، بس % ناقص قبله. ابعت الرسالة دي للمطوّر.', later_present, first_missing; end if;
end $chk$;

-- 2) الأجزاء اللي قبل الجزء ده لازم تكون اتطبقت
do $ord$
declare
  files text[] := array['0001_phase1.sql', '0002_storage.sql', '0003_shop_profile_realtime.sql', '0004_error_codes.sql', '0005_device_passcode.sql', '0006_invite_name.sql', '0007_phase2_customer.sql', '0008_ledger.sql', '0009_tracking_guess_limit.sql', '0010_default_cashboxes.sql', '0011_finance_drilldown.sql', '0012_spec_completion.sql', '0013_tracking_ambiguous.sql', '0014_technicians.sql', '0015_offline_backup.sql', '0016_shop_identity.sql', '0017_growth.sql', '0018_account_state.sql', '0019_extras.sql', '0020_admin_paging.sql', '0021_spec_rules.sql', '0022_security_review.sql', '0023_restore.sql', '0024_signout.sql', '0025_integrity.sql', '0026_edit_delete.sql', '0027_inventory.sql', '0028_opening.sql', '0029_partners.sql', '0030_party_links.sql', '0031_partner_capital.sql', '0032_lists.sql', '0033_assistant.sql', '0034_branches.sql', '0035_lists_everywhere.sql', '0036_roles.sql', '0037_item_details.sql', '0038_roles_grant.sql', '0039_payment_plans.sql', '0040_branch_books.sql', '0041_analytics.sql', '0042_app_brand.sql', '0043_printing.sql', '0044_capture.sql', '0045_checklists.sql', '0046_master.sql', '0047_mfa.sql', '0048_used.sql', '0049_commissions.sql', '0050_insights.sql', '0051_demo.sql', '0052_catalog.sql', '0053_portal.sql', '0054_telegram.sql', '0055_eta_placeholder.sql', '0056_branch_features.sql', '0057_categories.sql', '0058_web_push.sql', '0059_counters_branch.sql', '0060_sale_lines.sql', '0061_attendance.sql', '0062_vat.sql', '0063_cheques.sql', '0064_day_report.sql', '0065_cheque_pending.sql', '0066_commission_net.sql', '0067_idem_lock.sql', '0068_stock_adjust.sql', '0069_sale_errors.sql', '0070_perm_matrix.sql', '0071_device_children.sql', '0072_sale_line_return.sql', '0073_shop_extras.sql', '0074_idem_cheque_plan.sql', '0075_delete_by_section.sql', '0076_debt_aging.sql', '0077_period_lock.sql'];
  parts int[] := array[1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 3, 3, 3, 3, 3, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 6, 6, 6, 6, 6, 6];
  miss text;
begin
  select min(v) into miss from unnest(files) v where v < '0072_sale_line_return.sql' and v not in (select version from public.app_migrations);
  if miss is not null then raise exception 'E_UPGRADE_ORDER: الملف % لسه ما اتطبقش. شغّل upgrade_part_%.sql الأول، وبعدين الجزء ده (6).', miss, parts[array_position(files, miss)]; end if;
end $ord$;

-- 3) ملفات الجزء 6 بالترتيب، كل ملف في transaction لوحده
-- ============================== 0072_sale_line_return.sql ==============================
begin;
do $run$ begin
  if exists (select 1 from public.app_migrations where version = '0072_sale_line_return.sql') then return; end if;
  execute $m0072$
-- 0072: (3) مرتجع مربوط بسطر البيع: بكميته وسعره وضريبته وتكلفته وقت البيع، وما يزيدش عن اللي اتباع.
-- صف المرتجع في sale_lines نفسه: return_of = سطر البيع الأصلي، وentry_id = قيد المرتجع. إضافة بس زي الباقي.

alter table public.sale_lines add column return_of uuid references public.sale_lines(id);
create index sale_lines_return_of on public.sale_lines(return_of) where return_of is not null;

-- نوع الصنف بيحدد حساب إيراده: صنف اتباع ما يتغيّرش نوعه (المرتجع وتقسيم الإيراد بيعتمدوا عليه)
create or replace function public.tg_item_kind_fixed() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if new.kind is distinct from old.kind and not public.restoring() and exists (select 1 from public.sale_lines l where l.item_id = old.id) then
    raise exception 'E_ITEM_KIND';
  end if;
  return new;
end $$;
create trigger b_item_kind_fixed before update of kind on public.items for each row execute function public.tg_item_kind_fixed();
create index sale_lines_item on public.sale_lines(item_id);

-- حساب الإيراد من نوع الصنف (نفس تقسيم record_sale)
create or replace function public.item_rev_code(p_kind text) returns text
language sql immutable as $$
  select case p_kind when 'service' then 'rev_repair' when 'part' then 'rev_parts' else 'rev_accessories' end
$$;
revoke execute on function public.item_rev_code(text) from public, anon, authenticated;

-- اللي رجع من سطر بيع (المرتجع الملغي بقيد عكسي ما بيتحسبش)
create or replace function public.sale_line_returned(p_line uuid) returns bigint
language sql stable security definer set search_path = public as $$
  select coalesce(sum(r.qty), 0)::bigint from public.sale_lines r
  where r.return_of = p_line and not exists (select 1 from public.journal_entries x where x.reverses_id = r.entry_id)
$$;
revoke execute on function public.sale_line_returned(uuid) from public, anon, authenticated;

-- الفاتورة برقمها عشان المرتجع: السطور واللي رجع من كل سطر، من غير تكلفة ولا بيانات العميل
create or replace function public.sale_for_return(p_no bigint) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare s uuid := public.current_shop_id(); o public.journal_entries;
begin
  perform public.ledger_require(array['owner', 'reception']::public.app_role[]);
  if public.has_perm('sales', 'edit') is not true then raise exception 'E_FORBIDDEN'; end if;
  select * into o from public.journal_entries where entry_no = p_no and shop_id = s and source_type = 'sale'
    and (public.current_app_role() = 'owner' or public.can_branch(branch_id))
    -- بعد الاسترجاع ممكن رقم قديم يتكرر: الأحدث (والشاشة بتعرض التاريخ)
    order by occurred_at desc limit 1;
  if not found then raise exception 'E_NOT_FOUND'; end if;
  return jsonb_build_object('entry', o.id, 'entry_no', o.entry_no, 'at', o.occurred_at, 'branch_id', o.branch_id,
    'cancelled', exists (select 1 from public.journal_entries r where r.reverses_id = o.id),
    'credit', exists (select 1 from public.journal_lines l join public.accounts a on a.id = l.account_id where l.entry_id = o.id and a.kind = 'receivable'),
    'has_customer', exists (select 1 from public.sale_lines l join public.customers c on c.id = l.customer_id and c.deleted_at is null where l.entry_id = o.id),
    'lines', coalesce((select jsonb_agg(jsonb_build_object('id', l.id, 'name', l.name, 'qty', l.qty, 'price', l.price, 'returned', public.sale_line_returned(l.id),
        'service', i.kind = 'service') order by l.seq)
      from public.sale_lines l join public.items i on i.id = l.item_id where l.entry_id = o.id), '[]'::jsonb));
end $$;
revoke execute on function public.sale_for_return(bigint) from public, anon;
grant execute on function public.sale_for_return(bigint) to authenticated;

create or replace function public.sale_line_return(p_id uuid, p_line uuid, p_qty integer, p_cashbox uuid default null, p_restock boolean default true, p_reason text default null) returns uuid
language plpgsql security definer set search_path = public as $$
declare
  s uuid := public.current_shop_id(); e uuid; sl public.sale_lines; o public.journal_entries; it public.items; cb public.accounts;
  cust uuid; amt bigint; rev uuid; gross bigint; net bigint; back bigint; vat_back bigint; v bigint;
  sold bigint; sold_cost bigint; item_back bigint; cost_back bigint; cost bigint := 0;
begin
  perform public.ledger_require(array['owner', 'reception']::public.app_role[]);
  perform public.perm_require('sales', 'edit');
  e := public.ledger_idem(p_id);
  if e is not null then return e; end if;
  if nullif(trim(p_reason), '') is null then raise exception 'E_REASON_REQUIRED'; end if;
  select * into sl from public.sale_lines where id = p_line and shop_id = s and return_of is null;
  if not found then raise exception 'E_NOT_FOUND'; end if;
  -- القفل على قيد البيع: مرتجعين في نفس اللحظة (أو مرتجع وإلغاء) ما يعدّوش مع بعض
  select * into o from public.journal_entries where id = sl.entry_id and shop_id = s and source_type = 'sale' for update;
  if not found then raise exception 'E_NOT_FOUND'; end if;
  if public.current_app_role() <> 'owner' and not public.can_branch(o.branch_id) then raise exception 'E_FORBIDDEN'; end if;
  if exists (select 1 from public.journal_entries r where r.reverses_id = o.id) then raise exception 'E_ALREADY_REVERSED'; end if;
  -- موبايل مستعمل: بيترجع بإلغاء بيعه (عشان حالته ترجع "متاح")
  if exists (select 1 from public.used_devices u where u.sold_entry = o.id and u.item_id = sl.item_id) then raise exception 'E_USED_RETURN'; end if;
  if p_qty is null or p_qty <= 0 or p_qty > sl.qty - public.sale_line_returned(sl.id) then raise exception 'E_RETURN_QTY'; end if;
  select * into it from public.items where id = sl.item_id and shop_id = s for update;
  if p_restock and it.deleted_at is not null then raise exception 'E_NOT_FOUND'; end if;
  amt := p_qty * sl.price;
  perform set_config('app.branch', o.branch_id::text, true);

  -- البيع الآجل بيتخصم من حساب العميل بس (ما ياخدش كاش على حاجة ما دفعهاش)، والكاش من خزنة فرع البيع أو رصيد للعميل المعروف
  select max(l.party_id::text)::uuid into cust from public.journal_lines l join public.accounts a on a.id = l.account_id where l.entry_id = o.id and a.kind = 'receivable';
  if cust is not null then
    if p_cashbox is not null then raise exception 'E_RETURN_CREDIT'; end if;
  elsif p_cashbox is not null then
    cb := public.ledger_cashbox(p_cashbox);
    if cb.branch_id is distinct from o.branch_id then raise exception 'E_BAD_BRANCH'; end if;
  else
    select c.id into cust from public.customers c where c.id = sl.customer_id and c.deleted_at is null;
    if cust is null and amt > 0 then raise exception 'E_BAD_INPUT'; end if;
  end if;

  -- الضريبة من قيد البيع نفسه (مش النسبة الحالية): نصيب تراكمي من نفس نوع الإيراد، فآخر مرتجع بيقفلها بالقرش
  rev := public.ledger_acc(public.item_rev_code(it.kind));
  select coalesce(sum(l.qty * l.price), 0) into gross from public.sale_lines l join public.items i on i.id = l.item_id
    where l.entry_id = o.id and public.item_rev_code(i.kind) = public.item_rev_code(it.kind);
  select coalesce(sum(l.credit), 0) into net from public.journal_lines l where l.entry_id = o.id and l.account_id = rev;
  -- نوع الصنف اتغيّر قبل ما يتمنع تغييره: الإيراد مش في نفس الحساب
  if amt > 0 and (net <= 0 or net > gross or (gross > net and not exists (
      select 1 from public.journal_lines l join public.accounts a on a.id = l.account_id where l.entry_id = o.id and a.kind = 'tax' and l.credit >= gross - net))) then raise exception 'E_BAD_INPUT'; end if;
  select coalesce(sum(r.qty * r.price), 0),
         coalesce(sum((select sum(l.debit) from public.journal_lines l join public.accounts a on a.id = l.account_id where l.entry_id = r.entry_id and a.kind = 'tax')), 0)
    into back, vat_back
  from public.sale_lines r join public.sale_lines b on b.id = r.return_of join public.items i on i.id = b.item_id
  where b.entry_id = o.id and not exists (select 1 from public.journal_entries x where x.reverses_id = r.entry_id)
    and public.item_rev_code(i.kind) = public.item_rev_code(it.kind);
  v := 0;
  if gross > net then
    -- أقرب قرش بأعداد صحيحة (numeric عشان المبالغ الكبيرة ما تفيضش)
    v := div((gross - net)::numeric * (back + amt) * 2 + gross, 2 * gross::numeric)::bigint - vat_back;
    v := least(greatest(v, 0), amt);
  end if;

  -- التكلفة زي ما خرجت في البيع نفسه، بنصيب تراكمي من اللي رجع المخزون فعلًا
  if it.kind <> 'service' and p_restock then
    select coalesce(-sum(m.qty), 0), coalesce(-sum(m.value), 0) into sold, sold_cost from public.stock_moves m where m.entry_id = o.id and m.item_id = sl.item_id;
    -- بيع من غير تكلفة (بيتسوى وقت الشراء): تكلفته مش معروفة من البيع، فبيترجع من غير فاتورة
    if sold <= 0 or exists (select 1 from public.uncosted_sales u where u.entry_id = o.id and u.item_id = sl.item_id and u.deleted_at is null) then raise exception 'E_RETURN_UNCOSTED'; end if;
    select coalesce(sum(m.qty), 0), coalesce(sum(m.value), 0) into item_back, cost_back
      from public.stock_moves m join public.sale_lines r on r.entry_id = m.entry_id and r.item_id = m.item_id join public.sale_lines b on b.id = r.return_of
      where b.entry_id = o.id and m.item_id = sl.item_id and not exists (select 1 from public.journal_entries x where x.reverses_id = r.entry_id);
    cost := greatest(0, div(sold_cost::numeric * (item_back + p_qty), sold::numeric)::bigint - cost_back);
  end if;
  if amt = 0 and cost = 0 then raise exception 'E_BAD_AMOUNT'; end if;

  e := gen_random_uuid();
  insert into public.journal_entries(id, shop_id, source_type, source_id, memo, idem_key, created_by)
  values (e, s, 'sale_return', sl.item_id, left(trim(p_reason), 300), p_id, auth.uid());
  insert into public.sale_lines(shop_id, entry_id, item_id, name, qty, price, seq, customer_id, return_of)
  values (s, e, sl.item_id, sl.name, p_qty, sl.price, 1, coalesce(cust, sl.customer_id), sl.id);
  if amt > 0 then
    if amt > v then insert into public.journal_lines(shop_id, entry_id, account_id, debit, credit) values (s, e, rev, amt - v, 0); end if;
    if v > 0 then insert into public.journal_lines(shop_id, entry_id, account_id, debit, credit) values (s, e, public.ledger_acc('vat_payable'), v, 0); end if;
    if cb.id is not null then
      insert into public.journal_lines(shop_id, entry_id, account_id, debit, credit) values (s, e, cb.id, 0, amt);
    else
      insert into public.journal_lines(shop_id, entry_id, account_id, party_type, party_id, debit, credit) values (s, e, public.ledger_acc('ar'), 'customer', cust, 0, amt);
    end if;
  end if;
  -- السليم بيرجع المخزون، والتالف تكلفته بتفضل مصروف (زي sale_return)
  if it.kind <> 'service' and p_restock then
    if cost > 0 then
      insert into public.journal_lines(shop_id, entry_id, account_id, debit, credit) values
        (s, e, public.ledger_acc('inventory'), cost, 0), (s, e, public.ledger_acc('cogs'), 0, cost);
    end if;
    insert into public.stock_moves(shop_id, item_id, entry_id, qty, value) values (s, sl.item_id, e, p_qty, cost);
  end if;
  return e;
end $$;
revoke execute on function public.sale_line_return(uuid, uuid, integer, uuid, boolean, text) from public, anon;
grant execute on function public.sale_line_return(uuid, uuid, integer, uuid, boolean, text) to authenticated;

-- reverse_entry: (src: 0070_perm_matrix.sql) + بيع رجع منه حاجة ما يتلغيش قبل ما المرتجع نفسه يتلغي (الفلوس ما ترجعش مرتين)
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
  perform public.entry_require(o.id);
  if o.source_type in ('reversal', 'cost_adjust') or exists (select 1 from public.journal_entries where reverses_id = o.id) then
    raise exception 'E_ALREADY_REVERSED';
  end if;
  if o.source_type = 'sale' and exists (select 1 from public.sale_lines sl where sl.entry_id = o.id and public.sale_line_returned(sl.id) > 0) then
    raise exception 'E_HAS_RETURNS';
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
$m0072$;
  insert into public.app_migrations(version, how) values ('0072_sale_line_return.sql', 'applied');
  raise notice 'applied %', '0072_sale_line_return.sql';
end $run$;
commit;

-- ============================== 0073_shop_extras.sql ==============================
begin;
do $run$ begin
  if exists (select 1 from public.app_migrations where version = '0073_shop_extras.sql') then return; end if;
  execute $m0073$
-- 0073: (26) حفظ إعدادات المحل (shops.extras) مفتاح بمفتاح، وفحص "المحل فاضي" في الاسترجاع يشمل الحضور.

-- كل شاشة كانت بتكتب extras كله من نسختها، فتعديلين قريبين واحد يمسح التاني. هنا بيتعدّل المفاتيح المبعوتة بس.
-- p_merge: لو القيمة القديمة والجديدة object، الجديدة بتتحط فوق القديمة (مثلًا reminders اللي شاشتين بتعدّله)
-- shortcut: الدمج مستوى واحد، وقيمة واحدة بتتعدّل من جهازين في نفس اللحظة (مصفوفة أو اختصارات) الأخيرة تكسب. لو احتجناها: دمج أعمق
create or replace function public.set_shop_extras(p_patch jsonb, p_merge boolean default false) returns void
language plpgsql security definer set search_path = public as $$
begin
  perform public.ledger_require(array['owner']::public.app_role[]);
  if p_patch is null or jsonb_typeof(p_patch) <> 'object' or p_patch = '{}'::jsonb then raise exception 'E_BAD_INPUT'; end if;
  -- نفس الـ update: التعديل التاني بيستنى الأول وبيبني على اللي اتحفظ
  update public.shops sh set extras = coalesce(sh.extras, '{}'::jsonb) || (
    select jsonb_object_agg(k.key, case when p_merge and jsonb_typeof(k.value) = 'object' and jsonb_typeof(sh.extras -> k.key) = 'object'
                                        then (sh.extras -> k.key) || k.value else k.value end)
    from jsonb_each(p_patch) k)
  where sh.id = public.current_shop_id();
  if not found then raise exception 'E_FORBIDDEN'; end if;
end $$;
revoke execute on function public.set_shop_extras(jsonb, boolean) from public, anon;
grant execute on function public.set_shop_extras(jsonb, boolean) to authenticated;

-- restore_backup: (src: 0063_cheques.sql) + سجل حضور (مش ملغي) = المحل مش فاضي
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
                       'quote_decisions', 'repair_steps', 'repair_videos', 'device_ratings', 'journal_entries', 'journal_lines', 'sale_lines', 'cheques', 'profit_distributions', 'payments',
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
     or exists (select 1 from public.attendance where shop_id = s and deleted_at is null)
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
$m0073$;
  insert into public.app_migrations(version, how) values ('0073_shop_extras.sql', 'applied');
  raise notice 'applied %', '0073_shop_extras.sql';
end $run$;
commit;

-- ============================== 0074_idem_cheque_plan.sql ==============================
begin;
do $run$ begin
  if exists (select 1 from public.app_migrations where version = '0074_idem_cheque_plan.sql') then return; end if;
  execute $m0074$
-- 0074: (22ب) ضغطتين متزامنتين على استلام شيك أو إصداره أو حفظ خطة أقساط: التاني بيستنى الأول ويرجّع نفس الرقم من غير خطأ.
-- ledger_idem (0067) بياخد القفل على رقم العملية قبل ما الدالة تبص هي موجودة ولا لأ.

-- cheque_receive: (src: 0065_cheque_pending.sql) + القفل
create or replace function public.cheque_receive(p_id uuid, p_customer uuid, p_no text, p_bank text, p_due date, p_amount bigint, p_note text default null, p_device uuid default null)
returns uuid
language plpgsql security definer set search_path = public as $$
declare s uuid := public.current_shop_id();
begin
  perform public.cheque_require();
  perform public.ledger_idem(p_id);
  if exists (select 1 from public.cheques where id = p_id) then return p_id; end if;
  perform public.ledger_amount(p_amount);
  if coalesce(trim(p_no), '') = '' or p_due is null then raise exception 'E_BAD_INPUT'; end if;
  if not exists (select 1 from public.customers where id = p_customer and shop_id = s and deleted_at is null) then raise exception 'E_NOT_FOUND'; end if;
  if p_device is not null and not exists (select 1 from public.devices where id = p_device and shop_id = s and customer_id = p_customer and deleted_at is null and public.can_branch(branch_id)) then
    raise exception 'E_NOT_FOUND';
  end if;
  insert into public.cheques(id, shop_id, branch_id, direction, party_type, party_id, cheque_no, bank, due_date, amount, entry_id, device_id, note, created_by)
  values (p_id, s, public.op_branch(), 'in', 'customer', p_customer, trim(p_no), nullif(trim(p_bank), ''), p_due, p_amount, null, p_device, nullif(trim(p_note), ''), auth.uid());
  return p_id;
end $$;

-- cheque_issue: (src: 0063_cheques.sql) + القفل
create or replace function public.cheque_issue(p_id uuid, p_supplier uuid, p_no text, p_bank text, p_due date, p_amount bigint, p_note text default null)
returns uuid
language plpgsql security definer set search_path = public as $$
declare s uuid := public.current_shop_id(); e uuid;
begin
  perform public.cheque_require();
  perform public.ledger_idem(p_id);
  if exists (select 1 from public.cheques where id = p_id) then return p_id; end if;
  perform public.ledger_amount(p_amount);
  if coalesce(trim(p_no), '') = '' or p_due is null then raise exception 'E_BAD_INPUT'; end if;
  if not exists (select 1 from public.suppliers where id = p_supplier and shop_id = s and deleted_at is null) then raise exception 'E_NOT_FOUND'; end if;
  e := public.ledger_post('cheque_out', p_id, nullif(trim(p_note), ''), jsonb_build_array(
    public.ledger_line(public.ledger_acc('ap'), p_amount, 0, 'supplier', p_supplier),
    public.ledger_line(public.ledger_acc('cheques_out'), 0, p_amount, 'supplier', p_supplier)), null, p_id);
  insert into public.cheques(id, shop_id, branch_id, direction, party_type, party_id, cheque_no, bank, due_date, amount, entry_id, note, created_by)
  values (p_id, s, public.op_branch(), 'out', 'supplier', p_supplier, trim(p_no), nullif(trim(p_bank), ''), p_due, p_amount, e, nullif(trim(p_note), ''), auth.uid());
  return p_id;
end $$;

-- save_plan: (src: 0039_payment_plans.sql) + القفل
create or replace function public.save_plan(p_id uuid, p_party_type text, p_party uuid, p_rows jsonb, p_title text default null, p_note text default null) returns uuid
language plpgsql security definer set search_path = public as $$
declare s uuid := public.current_shop_id(); r jsonb; n integer := 0; tot bigint := 0; a bigint; d date;
begin
  perform public.grant_require('finance', 'add');
  perform public.ledger_idem(p_id);
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
$m0074$;
  insert into public.app_migrations(version, how) values ('0074_idem_cheque_plan.sql', 'applied');
  raise notice 'applied %', '0074_idem_cheque_plan.sql';
end $run$;
commit;

-- ============================== 0075_delete_by_section.sql ==============================
begin;
do $run$ begin
  if exists (select 1 from public.app_migrations where version = '0075_delete_by_section.sql') then return; end if;
  execute $m0075$
-- 0075: قرارات صاحب المشروع (2026-11-24):
-- 1) "يحذف" في قسم = إلغاء وتعديل وحذف حاجة القسم ده بس (كان أي "يحذف" بيفتح كل حاجة).
--    إذن "يصحح ويحذف" الكامل (profiles.can_correct) اللي صاحب المحل بيديه لموظف بعينه زي ما هو.
-- 2) المرتجع من غير فاتورة لصاحب المحل بس.

create or replace function public.can_delete(p_section text) returns boolean
language sql stable security definer set search_path = public as $$
  -- الفني ما يلغيش ولا يحذف (القيود فيها مبالغ)، حتى لو متعلّمله
  select public.current_app_role() in ('owner', 'reception')
     and (coalesce(public.has_perm(p_section, 'delete'), false)
          or coalesce((select p.can_correct from public.profiles p where p.id = auth.uid() and p.deleted_at is null), false))
$$;
-- القيد بتاع أنهي قسم (اللي مش مذكور: الوضع المالي)
create or replace function public.entry_section(p_source text) returns text
language sql immutable as $$
  select case
    when p_source in ('sale', 'sale_return') then 'sales'
    when p_source in ('payment', 'transfer', 'drawer_close') then 'cashbox'
    when p_source = 'expense' then 'expenses'
    when p_source in ('purchase', 'supplier_payment', 'supplier_return') then 'purchases'
    when p_source in ('write_off', 'stock_transfer') then 'inventory'
    when p_source in ('part_use', 'delivery') then 'devices'
    else 'finance' end
$$;
revoke execute on function public.can_delete(text), public.entry_section(text) from public, anon, authenticated;

-- entry_require: (src: 0070_perm_matrix.sql) + قسم القيد
create or replace function public.entry_require(p_entry uuid) returns void
language plpgsql stable security definer set search_path = public as $$
begin
  if public.current_app_role() = 'owner' then return; end if;
  if public.can_delete((select public.entry_section(e.source_type) from public.journal_entries e where e.id = p_entry)) is not true then raise exception 'E_FORBIDDEN'; end if;
  if exists (select 1 from public.journal_entries e where e.id = p_entry and (e.source_type = 'vat_payment' or not public.can_branch(e.branch_id)))
     or exists (select 1 from public.journal_lines l join public.accounts a on a.id = l.account_id where l.entry_id = p_entry
                and (a.kind in ('advances', 'salaries', 'partner_capital', 'partner_current', 'capital', 'drawings') or (a.kind = 'cash' and not public.can_branch(a.branch_id))))
     or exists (select 1 from public.stock_moves m where m.entry_id = p_entry and not public.can_branch(m.branch_id)) then
    raise exception 'E_FORBIDDEN';
  end if;
end $$;

-- soft_delete: (src: 0070_perm_matrix.sql) + قسم الحاجة اللي بتتحذف
create or replace function public.soft_delete(p_kind text, p_id uuid, p_reason text default null) returns void
language plpgsql security definer set search_path = public as $$
declare s uuid := public.current_shop_id(); before jsonb; tbl text;
begin
  if public.current_app_role() is null or not public.can_correct() then raise exception 'E_FORBIDDEN'; end if;
  if public.can_delete(case p_kind when 'customer' then 'customers' when 'supplier' then 'purchases' when 'item' then 'inventory' when 'device' then 'devices' end) is not true then raise exception 'E_FORBIDDEN'; end if;
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
    if public.current_app_role() <> 'owner' and not public.can_branch((before ->> 'branch_id')::uuid) then raise exception 'E_FORBIDDEN'; end if;
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

-- sale_return: (src: 0062_vat.sql) + صاحب المحل بس
create or replace function public.sale_return(p_id uuid, p_item uuid, p_qty integer, p_refund bigint, p_cashbox uuid default null, p_customer uuid default null, p_restock boolean default true, p_reason text default null) returns uuid
language plpgsql security definer set search_path = public as $$
declare s uuid := public.current_shop_id(); e uuid; it public.items; cost bigint; cb uuid; rev uuid; v bigint;
begin
  perform public.ledger_require(array['owner']::public.app_role[]);
  perform public.perm_require('sales', 'edit');
  e := public.ledger_idem(p_id);
  if e is not null then return e; end if;
  if nullif(trim(p_reason), '') is null then raise exception 'E_REASON_REQUIRED'; end if;
  if p_qty is null or p_qty <= 0 or p_refund is null or p_refund < 0 then raise exception 'E_BAD_AMOUNT'; end if;
  select * into it from public.items where id = p_item and shop_id = s and deleted_at is null for update;
  if not found then raise exception 'E_NOT_FOUND'; end if;
  if p_cashbox is null and p_refund > 0 and p_customer is null then raise exception 'E_BAD_INPUT'; end if;
  if p_customer is not null and not exists (select 1 from public.customers where id = p_customer and shop_id = s and deleted_at is null) then raise exception 'E_NOT_FOUND'; end if;
  if p_cashbox is not null then cb := (public.ledger_cashbox(p_cashbox)).id; end if;
  rev := public.ledger_acc(case when it.kind = 'part' then 'rev_parts' else 'rev_accessories' end);
  cost := public.item_last_cost(p_item) * p_qty;
  if p_refund = 0 and (cost = 0 or not p_restock) then raise exception 'E_BAD_AMOUNT'; end if;
  e := gen_random_uuid();
  insert into public.journal_entries(id, shop_id, source_type, source_id, memo, idem_key, created_by)
  values (e, s, 'sale_return', p_item, trim(p_reason), p_id, auth.uid());
  if p_refund > 0 then
    -- R5: المبلغ المرتجع شامل الضريبة: الضريبة بترجع من حساب الضريبة المستحقة، والباقي من الإيراد
    v := public.vat_of(p_refund, public.vat_bp(s));
    insert into public.journal_lines(shop_id, entry_id, account_id, debit, credit) values (s, e, rev, p_refund - v, 0);
    if v > 0 then insert into public.journal_lines(shop_id, entry_id, account_id, debit, credit) values (s, e, public.ledger_acc('vat_payable'), v, 0); end if;
    if cb is not null then
      insert into public.journal_lines(shop_id, entry_id, account_id, debit, credit) values (s, e, cb, 0, p_refund);
    else
      insert into public.journal_lines(shop_id, entry_id, account_id, party_type, party_id, debit, credit) values (s, e, public.ledger_acc('ar'), 'customer', p_customer, 0, p_refund);
    end if;
  end if;
  -- القطعة السليمة بترجع المخزون بتكلفتها (والتكلفة بتخرج من تكلفة البضاعة). البايظة ما بترجعش، وتكلفتها فضلت مصروف.
  if p_restock and cost > 0 then
    insert into public.journal_lines(shop_id, entry_id, account_id, debit, credit) values
      (s, e, public.ledger_acc('inventory'), cost, 0), (s, e, public.ledger_acc('cogs'), 0, cost);
    insert into public.stock_moves(shop_id, item_id, entry_id, qty, value) values (s, p_item, e, p_qty, cost);
  elsif p_restock then
    insert into public.stock_moves(shop_id, item_id, entry_id, qty, value) values (s, p_item, e, p_qty, 0);
  end if;
  return e;
end $$;
$m0075$;
  insert into public.app_migrations(version, how) values ('0075_delete_by_section.sql', 'applied');
  raise notice 'applied %', '0075_delete_by_section.sql';
end $run$;
commit;

-- ============================== 0076_debt_aging.sql ==============================
begin;
do $run$ begin
  if exists (select 1 from public.app_migrations where version = '0076_debt_aging.sql') then return; end if;
  execute $m0076$
-- 0076: (5) أعمار المديونية: رصيد كل عميل أو مورد متقسم على عمر العملية اللي عملته (0–29، 30–59، 60 يوم أو أكتر).
-- - من القيود بس، لحد تاريخ معيّن (as-of) بتوقيت القاهرة. مفيش رصيد متخزن.
-- - الدفعة بتغطي الأقدم الأول (زي party_balances)، والمرتجع بفاتورة من بيع آجل بيقلّل بيعه هو.
-- - العمر من تاريخ القيد: شيك مرفوض أو رصيد افتتاحي أو قيد اتعدّل عمره من يوم القيد الجديد.
-- القيد الملغي وعكسه بيتشالوا الاتنين، فإلغاء بيع جديد ما يغطيش دين قديم.
-- - اللي رصيده صفر أو ليه فلوس عندنا مش في الكشف. مجموع الشرايح = الرصيد بالظبط.
create or replace function public.debt_aging(p_kind text, p_as_of date default null, p_branch uuid default null)
returns table(party_id uuid, name text, balance bigint, d0 bigint, d30 bigint, d60 bigint, oldest date, as_of date)
language plpgsql stable security definer set search_path = public as $$
#variable_conflict use_column
declare s uuid := public.current_shop_id(); today date := (now() at time zone 'Africa/Cairo')::date; d date := coalesce(p_as_of, today);
  upto timestamptz := (d + 1)::timestamp at time zone 'Africa/Cairo';  -- أول لحظة بعد التاريخ
begin
  perform public.grant_require('finance', 'view');
  if p_kind is null or p_kind not in ('customers', 'suppliers') then raise exception 'E_BAD_INPUT'; end if;
  if d > today then raise exception 'E_BAD_INPUT'; end if;
  -- الموظف اللي مش معاه كل الفروع: فرعه هو، حتى لو طلب غيره (زي باقي التقارير)
  if not public.all_my_branches() and (p_branch is null or not public.can_branch(p_branch)) then
    p_branch := public.op_branch();
    if p_branch is null then raise exception 'E_FORBIDDEN'; end if;
  end if;
  return query
  with ent as (
    select e.id, e.entry_no, e.occurred_at, (e.occurred_at at time zone 'Africa/Cairo')::date as day
    from public.journal_entries e
    where e.shop_id = s and e.occurred_at < upto and (p_branch is null or e.branch_id = p_branch)
      and e.reverses_id is null
      and not exists (select 1 from public.journal_entries r where r.reverses_id = e.id and r.occurred_at < upto)
  ),
  raw as (
    select l.party_id, ent.id as entry_id, ent.day, ent.occurred_at, ent.entry_no, l.id as line_id,
           (case when p_kind = 'customers' then l.debit else l.credit end)::bigint as plus,
           (case when p_kind = 'customers' then l.credit else l.debit end)::bigint as minus
    from ent join public.journal_lines l on l.entry_id = ent.id join public.accounts a on a.id = l.account_id
    where l.party_id is not null and a.kind = case when p_kind = 'customers' then 'receivable' else 'payable' end
  ),
  -- مرتجع بفاتورة من بيع آجل: بيقلّل دين البيع نفسه (مش الأقدم)
  ret as (
    select distinct x.line_id, sale.line_id as sale_line
    from raw x join public.sale_lines rl on rl.entry_id = x.entry_id join public.sale_lines b on b.id = rl.return_of
    join raw sale on sale.entry_id = b.entry_id and sale.party_id = x.party_id and sale.plus > 0
    where p_kind = 'customers' and x.minus > 0
  ),
  ln as (
    select x.party_id, x.day, x.occurred_at, x.entry_no, x.line_id,
           x.plus - coalesce((select sum(q.minus) from ret join raw q on q.line_id = ret.line_id where ret.sale_line = x.line_id), 0)::bigint as plus,
           case when exists (select 1 from ret where ret.line_id = x.line_id) then 0 else x.minus end as minus
    from raw x
  ),
  paid as (select ln.party_id, sum(ln.minus) as m, sum(ln.plus) as p from ln group by 1 having sum(ln.plus) > sum(ln.minus)),
  cum as (
    select ln.party_id, ln.day, least(ln.plus, greatest(0, sum(ln.plus) over (partition by ln.party_id order by ln.occurred_at, ln.entry_no, ln.line_id) - paid.m))::bigint as open
    from ln join paid on paid.party_id = ln.party_id where ln.plus > 0
  )
  select c.party_id, coalesce(cu.name, sp.name), sum(c.open)::bigint,
         coalesce(sum(c.open) filter (where d - c.day < 30), 0)::bigint,
         coalesce(sum(c.open) filter (where d - c.day between 30 and 59), 0)::bigint,
         coalesce(sum(c.open) filter (where d - c.day >= 60), 0)::bigint,
         min(c.day) filter (where c.open > 0), d
  from cum c
  left join public.customers cu on p_kind = 'customers' and cu.id = c.party_id
  left join public.suppliers sp on p_kind = 'suppliers' and sp.id = c.party_id
  group by c.party_id, coalesce(cu.name, sp.name)
  order by 6 desc, 5 desc, 3 desc;
end $$;
revoke execute on function public.debt_aging(text, date, uuid) from public, anon;
grant execute on function public.debt_aging(text, date, uuid) to authenticated;
$m0076$;
  insert into public.app_migrations(version, how) values ('0076_debt_aging.sql', 'applied');
  raise notice 'applied %', '0076_debt_aging.sql';
end $run$;
commit;

-- ============================== 0077_period_lock.sql ==============================
begin;
do $run$ begin
  if exists (select 1 from public.app_migrations where version = '0077_period_lock.sql') then return; end if;
  execute $m0077$
-- 0077: (6) قفل الفترة المحاسبية: لحد يوم معيّن (بتوقيت القاهرة) ممنوع قيد بتاريخ جوه الفترة، وممنوع إلغاء أو تعديل قيد جواها.
-- - صاحب المحل بس بيقفل ويفتح. الفتح (أو تأخير القفل لورا) بسبب وكلمة السر الرئيسية لو متحددة، والاتنين في سجل النشاط.
-- - التقفيل لحد امبارح بالكتير: شغل النهارده ما بيقفش. ومرتجع النهارده لبيع قديم قيد جديد بتاريخ النهارده، فمسموح.
-- - القفل مش جزء من الاسترجاع (المحل المسترجع مفتوح)، ومسح بيانات التجربة محتاج الفترة مفتوحة لو قيودها جواها.
-- - الحماية على الجدول نفسه، فأي دالة (حتى اللي هتتعمل بعدين) ممنوعة.
alter table public.shops add column books_locked_until date;

create or replace function public.tg_period_lock() returns trigger
language plpgsql security definer set search_path = public as $$
declare d date := (new.occurred_at at time zone 'Africa/Cairo')::date; lck date;
begin
  if public.restoring() then return new; end if;
  -- الشغل العادي (تاريخه النهارده ومش عكس) ما بيلمسش القفل
  if new.reverses_id is null and d >= (now() at time zone 'Africa/Cairo')::date then return new; end if;
  if new.reverses_id is not null then
    d := least(d, (select (o.occurred_at at time zone 'Africa/Cairo')::date from public.journal_entries o where o.id = new.reverses_id));
  end if;
  -- for share: قفل بيتسجل في نفس اللحظة بيستنى القيد ده، والعكس
  select sh.books_locked_until into lck from public.shops sh where sh.id = new.shop_id for share;
  if lck is not null and d <= lck then raise exception 'E_PERIOD_LOCKED'; end if;
  return new;
end $$;
create trigger c_period_lock before insert on public.journal_entries for each row execute function public.tg_period_lock();

-- التاريخ بيتغيّر من set_period_lock بس (صاحب المحل بيعدّل صف المحل مباشرة في الإعدادات)
create or replace function public.tg_shop_period_guard() returns trigger
language plpgsql set search_path = public as $$
begin
  if new.books_locked_until is distinct from old.books_locked_until and coalesce(current_setting('warsha.period', true), '') <> 'on' then
    raise exception 'E_FORBIDDEN';
  end if;
  return new;
end $$;
create trigger zy_shop_period_guard before update on public.shops for each row execute function public.tg_shop_period_guard();

-- p_until = آخر يوم مقفول. null = فتح كل حاجة. بيرجّع التاريخ بعد التعديل
create or replace function public.set_period_lock(p_until date, p_reason text default null) returns date
language plpgsql security definer set search_path = public as $$
declare s uuid := public.current_shop_id(); old date; opening boolean;
begin
  perform public.ledger_require(array['owner']::public.app_role[]);
  select sh.books_locked_until into old from public.shops sh where sh.id = s for update;
  if not found then raise exception 'E_FORBIDDEN'; end if;
  if p_until is not distinct from old then return old; end if;
  if p_until >= (now() at time zone 'Africa/Cairo')::date then raise exception 'E_PERIOD_DATE'; end if;
  opening := old is not null and (p_until is null or p_until < old);
  if opening then
    perform public.master_require();
    if nullif(trim(p_reason), '') is null then raise exception 'E_REASON_REQUIRED'; end if;
  end if;
  perform set_config('warsha.period', 'on', true);
  update public.shops set books_locked_until = p_until where id = s;
  perform set_config('warsha.period', '', true);
  insert into public.audit_log(shop_id, actor_id, action, entity, entity_id, before, after)
  values (s, auth.uid(), case when opening then 'period_unlock' else 'period_lock' end, 'shops', s,
          jsonb_build_object('until', old), jsonb_build_object('until', p_until, 'reason', left(nullif(trim(p_reason), ''), 300)));
  return p_until;
end $$;
revoke execute on function public.set_period_lock(date, text) from public, anon;
grant execute on function public.set_period_lock(date, text) to authenticated;
$m0077$;
  insert into public.app_migrations(version, how) values ('0077_period_lock.sql', 'applied');
  raise notice 'applied %', '0077_period_lock.sql';
end $run$;
commit;

select 6 as part, 6 as parts, count(*) as applied_files, max(version) as latest,
  case when '0077_period_lock.sql' in (select version from public.app_migrations) then
    'خلص: المشروع على آخر نسخة'
  else 'فيه ملف ما اتطبقش' end as status
from public.app_migrations;
