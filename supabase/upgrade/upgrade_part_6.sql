-- جوالك / Gawalak: ترقية مشروع Supabase لآخر نسخة، الجزء 6 من 6 (الملفات 0072_sale_line_return.sql لـ 0084_party_branch.sql).
-- بيتولد تلقائيًا: npm run db:setup-file. ما تعدّلوش بإيدك.
-- شغّل الأجزاء بالترتيب في SQL Editor (كل جزء لوحده: New query ← الصق ← Run): upgrade_part_1.sql ثم upgrade_part_2.sql ثم upgrade_part_3.sql ثم upgrade_part_4.sql ثم upgrade_part_5.sql ثم upgrade_part_6.sql.
-- آمن تشغّل أي جزء أكتر من مرة: اللي اتطبق قبل كده بيتخطى. ولو ملف فشل، اللي قبله بيفضل، وصلّح السبب وشغّل نفس الجزء تاني.
-- لو لقى ملف أحدث موجود وأقدم منه ناقص بيقف (E_UPGRADE_GAP). ولو جزء قبله لسه ما اتطبقش بيقف (E_UPGRADE_ORDER). الاتنين من غير تغيير.
-- ملفات الجزء ده: 0072_sale_line_return.sql, 0073_shop_extras.sql, 0074_idem_cheque_plan.sql, 0075_delete_by_section.sql, 0076_debt_aging.sql, 0077_period_lock.sql, 0078_accountant_export.sql, 0079_purchase_orders.sql, 0080_stock_count.sql, 0081_repair_invoice.sql, 0082_order_prefix.sql, 0083_print_perm.sql, 0084_party_branch.sql

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
  insert into public.app_migrations(version, how) select v, 'inferred' from unnest(array['0022_security_review.sql']::text[]) v
    where v < (select max(version) from public.app_migrations) on conflict (version) do nothing;
  select min(v) into first_missing from unnest(array['0001_phase1.sql', '0002_storage.sql', '0003_shop_profile_realtime.sql', '0004_error_codes.sql', '0005_device_passcode.sql', '0006_invite_name.sql', '0007_phase2_customer.sql', '0008_ledger.sql', '0009_tracking_guess_limit.sql', '0010_default_cashboxes.sql', '0011_finance_drilldown.sql', '0012_spec_completion.sql', '0013_tracking_ambiguous.sql', '0014_technicians.sql', '0015_offline_backup.sql', '0016_shop_identity.sql', '0017_growth.sql', '0018_account_state.sql', '0019_extras.sql', '0020_admin_paging.sql', '0021_spec_rules.sql', '0022_security_review.sql', '0023_restore.sql', '0024_signout.sql', '0025_integrity.sql', '0026_edit_delete.sql', '0027_inventory.sql', '0028_opening.sql', '0029_partners.sql', '0030_party_links.sql', '0031_partner_capital.sql', '0032_lists.sql', '0033_assistant.sql', '0034_branches.sql', '0035_lists_everywhere.sql', '0036_roles.sql', '0037_item_details.sql', '0038_roles_grant.sql', '0039_payment_plans.sql', '0040_branch_books.sql', '0041_analytics.sql', '0042_app_brand.sql', '0043_printing.sql', '0044_capture.sql', '0045_checklists.sql', '0046_master.sql', '0047_mfa.sql', '0048_used.sql', '0049_commissions.sql', '0050_insights.sql', '0051_demo.sql', '0052_catalog.sql', '0053_portal.sql', '0054_telegram.sql', '0055_eta_placeholder.sql', '0056_branch_features.sql', '0057_categories.sql', '0058_web_push.sql', '0059_counters_branch.sql', '0060_sale_lines.sql', '0061_attendance.sql', '0062_vat.sql', '0063_cheques.sql', '0064_day_report.sql', '0065_cheque_pending.sql', '0066_commission_net.sql', '0067_idem_lock.sql', '0068_stock_adjust.sql', '0069_sale_errors.sql', '0070_perm_matrix.sql', '0071_device_children.sql', '0072_sale_line_return.sql', '0073_shop_extras.sql', '0074_idem_cheque_plan.sql', '0075_delete_by_section.sql', '0076_debt_aging.sql', '0077_period_lock.sql', '0078_accountant_export.sql', '0079_purchase_orders.sql', '0080_stock_count.sql', '0081_repair_invoice.sql', '0082_order_prefix.sql', '0083_print_perm.sql', '0084_party_branch.sql']) v where v not in (select version from public.app_migrations);
  select max(version) into later_present from public.app_migrations where first_missing is not null and version > first_missing;
  if later_present is not null then raise exception 'E_UPGRADE_GAP: % موجود، بس % ناقص قبله. ابعت الرسالة دي للمطوّر.', later_present, first_missing; end if;
end $chk$;

-- 2) الأجزاء اللي قبل الجزء ده لازم تكون اتطبقت
do $ord$
declare
  files text[] := array['0001_phase1.sql', '0002_storage.sql', '0003_shop_profile_realtime.sql', '0004_error_codes.sql', '0005_device_passcode.sql', '0006_invite_name.sql', '0007_phase2_customer.sql', '0008_ledger.sql', '0009_tracking_guess_limit.sql', '0010_default_cashboxes.sql', '0011_finance_drilldown.sql', '0012_spec_completion.sql', '0013_tracking_ambiguous.sql', '0014_technicians.sql', '0015_offline_backup.sql', '0016_shop_identity.sql', '0017_growth.sql', '0018_account_state.sql', '0019_extras.sql', '0020_admin_paging.sql', '0021_spec_rules.sql', '0022_security_review.sql', '0023_restore.sql', '0024_signout.sql', '0025_integrity.sql', '0026_edit_delete.sql', '0027_inventory.sql', '0028_opening.sql', '0029_partners.sql', '0030_party_links.sql', '0031_partner_capital.sql', '0032_lists.sql', '0033_assistant.sql', '0034_branches.sql', '0035_lists_everywhere.sql', '0036_roles.sql', '0037_item_details.sql', '0038_roles_grant.sql', '0039_payment_plans.sql', '0040_branch_books.sql', '0041_analytics.sql', '0042_app_brand.sql', '0043_printing.sql', '0044_capture.sql', '0045_checklists.sql', '0046_master.sql', '0047_mfa.sql', '0048_used.sql', '0049_commissions.sql', '0050_insights.sql', '0051_demo.sql', '0052_catalog.sql', '0053_portal.sql', '0054_telegram.sql', '0055_eta_placeholder.sql', '0056_branch_features.sql', '0057_categories.sql', '0058_web_push.sql', '0059_counters_branch.sql', '0060_sale_lines.sql', '0061_attendance.sql', '0062_vat.sql', '0063_cheques.sql', '0064_day_report.sql', '0065_cheque_pending.sql', '0066_commission_net.sql', '0067_idem_lock.sql', '0068_stock_adjust.sql', '0069_sale_errors.sql', '0070_perm_matrix.sql', '0071_device_children.sql', '0072_sale_line_return.sql', '0073_shop_extras.sql', '0074_idem_cheque_plan.sql', '0075_delete_by_section.sql', '0076_debt_aging.sql', '0077_period_lock.sql', '0078_accountant_export.sql', '0079_purchase_orders.sql', '0080_stock_count.sql', '0081_repair_invoice.sql', '0082_order_prefix.sql', '0083_print_perm.sql', '0084_party_branch.sql'];
  parts int[] := array[1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 3, 3, 3, 3, 3, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6];
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

-- ============================== 0078_accountant_export.sql ==============================
begin;
do $run$ begin
  if exists (select 1 from public.app_migrations where version = '0078_accountant_export.sql') then return; end if;
  execute $m0078$
-- 0078: (4) تصدير للمحاسب: كل القيود بسطورها، والمدفوعات، وسطور البيع، لفترة وفرع. المبالغ بالقروش، ومجموع المدين = مجموع الدائن.
-- - صلاحية "يصدّر" في الوضع المالي. الموظف فرعه بس، ومن غير قيود المرتبات والسلف والشركاء ورأس المال، ولا تحويل لخزنة فرع تاني (restricted = true).
-- - sales = سطور البيع بأسعارها شاملة الضريبة (المرتجع بالسالب)، ومش بديل القيود: المرتجع من غير فاتورة والصيانة في lines بس.
-- - الأيام بتوقيت القاهرة، من وإلى داخلين. وكل تصدير في سجل النشاط.
create or replace function public.accountant_export(p_from date, p_to date, p_branch uuid default null) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  s uuid := public.current_shop_id(); own boolean := public.current_app_role() = 'owner'; names boolean; res jsonb;
  f timestamptz; t timestamptz;
begin
  perform public.grant_require('finance', 'view');
  perform public.grant_require('finance', 'export');
  if p_from is null or p_to is null or not isfinite(p_from) or not isfinite(p_to) or p_to < p_from or p_to - p_from > 366 then raise exception 'E_BAD_INPUT'; end if;
  f := p_from::timestamp at time zone 'Africa/Cairo';
  t := (p_to + 1)::timestamp at time zone 'Africa/Cairo';
  if not public.all_my_branches() and (p_branch is null or not public.can_branch(p_branch)) then
    p_branch := public.op_branch();
    if p_branch is null then raise exception 'E_FORBIDDEN'; end if;
  end if;
  if p_branch is not null and not exists (select 1 from public.branches where id = p_branch and shop_id = s) then raise exception 'E_BAD_BRANCH'; end if;
  names := own or public.has_perm('customers', 'view');
  with ent as materialized (
    select e.* from public.journal_entries e
    where e.shop_id = s and e.occurred_at >= f and e.occurred_at < t and (p_branch is null or e.branch_id = p_branch)
      and (own or not exists (select 1 from public.journal_lines l join public.accounts a on a.id = l.account_id
                              where l.entry_id = e.id and (a.kind in ('advances', 'salaries', 'partner_capital', 'partner_current', 'capital', 'drawings')
                                or a.kind = 'cash' and not public.can_branch(a.branch_id))))
  ),
  ln as (
    select ent.entry_no, ent.occurred_at, ent.source_type, ent.memo, b.name as branch, a.code, a.name as account, a.type::text as account_type, l.debit, l.credit, l.id,
           (select o.entry_no from public.journal_entries o where o.id = ent.reverses_id) as reverses_no,
           case l.party_type when 'customer' then case when names then (select c.name from public.customers c where c.id = l.party_id) end
                             when 'supplier' then case when own or public.has_perm('purchases', 'view') then (select sp.name from public.suppliers sp where sp.id = l.party_id) end
                             when 'employee' then (select p.full_name from public.profiles p where p.id = l.party_id)
                             when 'partner' then (select pr.name from public.partners pr where pr.id = l.party_id) end as party
    from ent join public.journal_lines l on l.entry_id = ent.id join public.accounts a on a.id = l.account_id left join public.branches b on b.id = ent.branch_id
  )
  select jsonb_build_object(
    'from', p_from, 'to', p_to, 'branch', p_branch, 'restricted', not own,
    'lines', coalesce((select jsonb_agg(jsonb_build_object('entry_no', entry_no, 'at', occurred_at, 'source', source_type, 'memo', memo, 'branch', branch, 'code', code, 'account', account,
        'type', account_type, 'party', party, 'debit', debit, 'credit', credit, 'reverses_no', reverses_no) order by occurred_at, entry_no, debit = 0, id) from ln), '[]'::jsonb),
    'payments', coalesce((select jsonb_agg(jsonb_build_object('entry_no', ent.entry_no, 'at', ent.occurred_at, 'method', p.method, 'amount', p.amount, 'cashbox', a.code, 'cashbox_name', a.name,
        'customer', case when names then c.name end, 'order_no', d.order_no,
        'reversed', exists (select 1 from public.journal_entries r where r.reverses_id = ent.id and r.occurred_at < t)) order by ent.occurred_at, ent.entry_no)
      from ent join public.payments p on p.entry_id = ent.id join public.accounts a on a.id = p.cashbox_id
      left join public.customers c on c.id = p.customer_id left join public.devices d on d.id = p.device_id), '[]'::jsonb),
    'sales', coalesce((select jsonb_agg(jsonb_build_object('entry_no', ent.entry_no, 'at', ent.occurred_at, 'item', sl.name, 'qty', sl.qty, 'price', sl.price, 'amount', case when sl.return_of is null then 1 else -1 end * sl.qty * sl.price,
        'return_of', (select o.entry_no from public.sale_lines b join public.journal_entries o on o.id = b.entry_id where b.id = sl.return_of),
        'reversed', exists (select 1 from public.journal_entries r where r.reverses_id = ent.id and r.occurred_at < t)) order by ent.occurred_at, ent.entry_no, sl.seq)
      from ent join public.sale_lines sl on sl.entry_id = ent.id and sl.deleted_at is null), '[]'::jsonb),
    'debit', (select coalesce(sum(debit), 0) from ln), 'credit', (select coalesce(sum(credit), 0) from ln))
  into res;
  insert into public.audit_log(shop_id, actor_id, action, entity, entity_id, after)
  values (s, auth.uid(), 'accountant_export', 'shops', s, jsonb_build_object('from', p_from, 'to', p_to, 'branch', p_branch));
  return res;
end $$;
revoke execute on function public.accountant_export(date, date, uuid) from public, anon;
grant execute on function public.accountant_export(date, date, uuid) to authenticated;
$m0078$;
  insert into public.app_migrations(version, how) values ('0078_accountant_export.sql', 'applied');
  raise notice 'applied %', '0078_accountant_export.sql';
end $run$;
commit;

-- ============================== 0079_purchase_orders.sql ==============================
begin;
do $run$ begin
  if exists (select 1 from public.app_migrations where version = '0079_purchase_orders.sql') then return; end if;
  execute $m0079$
-- 0079: (27) أوامر الشراء: أمر لمورد بأصنافه، واستلام جزئي لحد ما يكمل من غير تضاعف، ومرتجع مورد مربوط بسطر الاستلام نفسه.
-- - الأمر نفسه ما بيعملش قيد. القيد وقت الاستلام (شراء عادي)، والمستلم والمرتجع بيتحسبوا من حركة المخزون بس.
-- - سطر الاستلام = حركة مخزون مربوطة بسطر الأمر (order_line_id)، والمرتجع = حركة مربوطة بحركة الاستلام (return_of).
create table public.purchase_orders (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references public.shops(id),
  branch_id uuid not null references public.branches(id),
  supplier_id uuid not null references public.suppliers(id),
  order_no bigint generated always as identity,
  expected_on date,
  note text check (note is null or length(note) <= 300),
  cancelled_at timestamptz,
  cancel_reason text check (cancel_reason is null or length(cancel_reason) <= 300),
  created_by uuid references public.profiles(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  check ((cancelled_at is null) = (cancel_reason is null))
);
create table public.purchase_order_lines (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references public.shops(id),
  order_id uuid not null references public.purchase_orders(id),
  item_id uuid not null references public.items(id),
  qty integer not null check (qty > 0 and qty <= 100000),
  unit_cost bigint not null check (unit_cost >= 0),
  seq integer not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  unique (order_id, item_id)
);
create index purchase_orders_shop on public.purchase_orders(shop_id, created_at);
alter table public.stock_moves add column order_line_id uuid references public.purchase_order_lines(id);
alter table public.stock_moves add column return_of uuid references public.stock_moves(id);
create index stock_moves_order_line on public.stock_moves(order_line_id) where order_line_id is not null;
create index stock_moves_return_of on public.stock_moves(return_of) where return_of is not null;
do $$
declare t text;
begin
  foreach t in array array['purchase_orders', 'purchase_order_lines'] loop
    execute format('alter table public.%I enable row level security', t);
    execute format('revoke all on public.%I from public, anon, authenticated', t);
    execute format('grant select on public.%I to authenticated', t);
    execute format('create trigger set_updated_at before update on public.%I for each row execute function public.tg_set_updated_at()', t);
    execute format('create trigger block_delete before delete on public.%I for each row execute function public.tg_block_delete()', t);
    execute format('create trigger zz_audit after insert or update on public.%I for each row execute function public.tg_audit()', t);
  end loop;
end $$;
-- سطور الأمر ما بتتعدلش (الغلط: إلغاء الأمر وأمر جديد)
create trigger ledger_immutable before update or delete on public.purchase_order_lines for each row execute function public.tg_ledger_immutable();
create policy purchase_orders_select on public.purchase_orders for select to authenticated
  using (shop_id = (select public.current_shop_id()) and ((select public.current_app_role()) = 'owner'
         or ((select public.current_app_role()) = 'reception' and (select public.has_perm('purchases', 'view')) and public.can_branch(branch_id))));
create policy purchase_order_lines_select on public.purchase_order_lines for select to authenticated
  using (shop_id = (select public.current_shop_id()) and exists (select 1 from public.purchase_orders o where o.id = order_id));

-- المستلم من سطر أمر (الاستلام الملغي بقيد عكسي ما بيتحسبش)
create or replace function public.order_line_received(p_line uuid) returns bigint
language sql stable security definer set search_path = public as $$
  select coalesce(sum(m.qty), 0)::bigint from public.stock_moves m
  where m.order_line_id = p_line and not exists (select 1 from public.journal_entries x where x.reverses_id = m.entry_id)
$$;
-- الراجع للمورد من سطر استلام
create or replace function public.move_returned(p_move uuid) returns bigint
language sql stable security definer set search_path = public as $$
  select coalesce(-sum(m.qty), 0)::bigint from public.stock_moves m
  where m.return_of = p_move and not exists (select 1 from public.journal_entries x where x.reverses_id = m.entry_id)
$$;
revoke execute on function public.order_line_received(uuid), public.move_returned(uuid) from public, anon, authenticated;

create or replace function public.save_purchase_order(p_id uuid, p_supplier uuid, p_lines jsonb, p_expected date default null, p_note text default null) returns uuid
language plpgsql security definer set search_path = public as $$
declare s uuid := public.current_shop_id(); l jsonb; n int := 0; total numeric := 0; it uuid;
begin
  perform public.grant_require('purchases', 'add');
  perform public.ledger_idem(p_id);
  if exists (select 1 from public.purchase_orders where id = p_id) then
    if exists (select 1 from public.purchase_orders where id = p_id and shop_id = s and (public.current_app_role() = 'owner' or public.can_branch(branch_id))) then return p_id; end if;
    raise exception 'E_NOT_FOUND';
  end if;
  if not exists (select 1 from public.suppliers where id = p_supplier and shop_id = s and deleted_at is null) then raise exception 'E_NOT_FOUND'; end if;
  if p_lines is null or jsonb_typeof(p_lines) <> 'array' or jsonb_array_length(p_lines) not between 1 and 300 then raise exception 'E_BAD_INPUT'; end if;
  insert into public.purchase_orders(id, shop_id, branch_id, supplier_id, expected_on, note, created_by)
  values (p_id, s, public.op_branch(), p_supplier, p_expected, left(nullif(trim(p_note), ''), 300), auth.uid());
  for l in select * from jsonb_array_elements(p_lines) loop
    n := n + 1;
    if coalesce(l ->> 'qty', '') !~ '^[0-9]{1,6}$' or (l ->> 'qty')::int not between 1 and 100000 then raise exception 'E_BAD_QTY'; end if;
    if coalesce(l ->> 'unit_cost', '') !~ '^[0-9]{1,12}$' then raise exception 'E_BAD_PRICE'; end if;
    it := (l ->> 'item')::uuid;
    if not exists (select 1 from public.items where id = it and shop_id = s and deleted_at is null and kind <> 'service') then raise exception 'E_NOT_FOUND'; end if;
    if exists (select 1 from public.purchase_order_lines where order_id = p_id and item_id = it) then raise exception 'E_BAD_INPUT'; end if;
    insert into public.purchase_order_lines(shop_id, order_id, item_id, qty, unit_cost, seq) values (s, p_id, it, (l ->> 'qty')::int, (l ->> 'unit_cost')::bigint, n);
    total := total + (l ->> 'qty')::numeric * (l ->> 'unit_cost')::numeric;
  end loop;
  if total <= 0 or total > 100000000000 then raise exception 'E_BAD_AMOUNT'; end if;
  return p_id;
end $$;

create or replace function public.cancel_purchase_order(p_order uuid, p_reason text) returns void
language plpgsql security definer set search_path = public as $$
declare o public.purchase_orders;
begin
  perform public.grant_require('purchases', 'edit');
  select * into o from public.purchase_orders where id = p_order and shop_id = public.current_shop_id() and deleted_at is null for update;
  if not found or (public.current_app_role() <> 'owner' and not public.can_branch(o.branch_id)) then raise exception 'E_NOT_FOUND'; end if;
  if o.cancelled_at is not null then return; end if;
  if nullif(trim(p_reason), '') is null then raise exception 'E_REASON_REQUIRED'; end if;
  -- المستلم بيفضل مستلم، والباقي مش هييجي
  update public.purchase_orders set cancelled_at = now(), cancel_reason = left(trim(p_reason), 300) where id = o.id;
end $$;

-- p_lines: [{"line": سطر الأمر، "qty": اللي وصل، "unit_cost": سعره الفعلي (اختياري، الافتراضي سعر الأمر)}]
create or replace function public.receive_purchase_order(p_id uuid, p_order uuid, p_lines jsonb, p_cashbox uuid default null, p_note text default null) returns uuid
language plpgsql security definer set search_path = public as $$
declare s uuid := public.current_shop_id(); o public.purchase_orders; ol public.purchase_order_lines; l jsonb; e uuid; q int; u bigint; total bigint := 0; cb public.accounts; credit_line jsonb; seen uuid[] := '{}';
begin
  perform public.grant_require('purchases', 'add');
  e := public.ledger_idem(p_id);
  if e is not null then return e; end if;
  -- القفل على الأمر: استلامين في نفس اللحظة ما يزيدوش عن المطلوب
  select * into o from public.purchase_orders where id = p_order and shop_id = s and deleted_at is null for update;
  if not found or (public.current_app_role() <> 'owner' and not public.can_branch(o.branch_id)) then raise exception 'E_NOT_FOUND'; end if;
  if o.cancelled_at is not null then raise exception 'E_ORDER_CANCELLED'; end if;
  if p_lines is null or jsonb_typeof(p_lines) <> 'array' or jsonb_array_length(p_lines) = 0 then raise exception 'E_BAD_INPUT'; end if;
  perform set_config('app.branch', o.branch_id::text, true);
  for l in select * from jsonb_array_elements(p_lines) loop
    select * into ol from public.purchase_order_lines where id = (l ->> 'line')::uuid and order_id = o.id;
    if not found then raise exception 'E_NOT_FOUND'; end if;
    if ol.id = any (seen) then raise exception 'E_BAD_INPUT'; end if;
    seen := seen || ol.id;
    if coalesce(l ->> 'qty', '') !~ '^[0-9]{1,6}$' or (l ->> 'qty')::int <= 0 then raise exception 'E_BAD_QTY'; end if;
    if l ->> 'unit_cost' is not null and l ->> 'unit_cost' !~ '^[0-9]{1,12}$' then raise exception 'E_BAD_PRICE'; end if;
    q := (l ->> 'qty')::int;
    if q > ol.qty - public.order_line_received(ol.id) then raise exception 'E_ORDER_QTY'; end if;
    if not exists (select 1 from public.items where id = ol.item_id and deleted_at is null) then raise exception 'E_NOT_FOUND'; end if;
    if q::numeric * coalesce((l ->> 'unit_cost')::numeric, ol.unit_cost) > 100000000000 then raise exception 'E_BAD_AMOUNT'; end if;
    total := total + q::bigint * coalesce((l ->> 'unit_cost')::bigint, ol.unit_cost);
  end loop;
  perform public.ledger_amount(total);
  if p_cashbox is not null then
    cb := public.ledger_cashbox(p_cashbox);
    if cb.branch_id is distinct from o.branch_id then raise exception 'E_BAD_BRANCH'; end if;
    credit_line := public.ledger_line(cb.id, 0, total);
  else
    credit_line := public.ledger_line(public.ledger_acc('ap'), 0, total, 'supplier', o.supplier_id);
  end if;
  e := public.ledger_post('purchase', p_id, p_note, jsonb_build_array(public.ledger_line(public.ledger_acc('inventory'), total, 0), credit_line), null, p_id);
  for l in select * from jsonb_array_elements(p_lines) loop
    select * into ol from public.purchase_order_lines where id = (l ->> 'line')::uuid;
    u := coalesce((l ->> 'unit_cost')::bigint, ol.unit_cost);
    insert into public.stock_moves(shop_id, item_id, entry_id, qty, value, order_line_id)
    values (s, ol.item_id, e, (l ->> 'qty')::int, (l ->> 'qty')::bigint * u, ol.id);
  end loop;
  insert into public.purchases(id, shop_id, supplier_id, entry_id, on_credit, created_by) values (p_id, s, o.supplier_id, e, p_cashbox is null, auth.uid());
  return e;
end $$;

-- مرتجع من سطر استلام (شراء عادي أو بأمر): بسعر شراه هو، وما يزيدش عن اللي وصل فيه
create or replace function public.purchase_move_return(p_id uuid, p_move uuid, p_qty integer, p_cashbox uuid default null, p_reason text default null) returns uuid
language plpgsql security definer set search_path = public as $$
declare s uuid := public.current_shop_id(); mv public.stock_moves; o public.journal_entries; sup uuid; e uuid; back bigint; refund bigint; cost bigint; diff bigint; cb public.accounts; st record;
begin
  perform public.grant_require('purchases', 'edit');
  e := public.ledger_idem(p_id);
  if e is not null then return e; end if;
  if nullif(trim(p_reason), '') is null then raise exception 'E_REASON_REQUIRED'; end if;
  select * into mv from public.stock_moves where id = p_move and shop_id = s and qty > 0 and return_of is null;
  if not found then raise exception 'E_NOT_FOUND'; end if;
  select * into o from public.journal_entries where id = mv.entry_id and shop_id = s and source_type = 'purchase' for update;
  if not found then raise exception 'E_NOT_FOUND'; end if;
  if public.current_app_role() <> 'owner' and not public.can_branch(o.branch_id) then raise exception 'E_FORBIDDEN'; end if;
  if exists (select 1 from public.journal_entries x where x.reverses_id = o.id) then raise exception 'E_ALREADY_REVERSED'; end if;
  if exists (select 1 from public.used_devices u where u.item_id = mv.item_id) then raise exception 'E_USED_RETURN'; end if;
  select p.supplier_id into sup from public.purchases p where p.entry_id = o.id;
  if sup is null then raise exception 'E_NOT_FOUND'; end if;
  back := public.move_returned(mv.id);
  if p_qty is null or p_qty <= 0 or p_qty > mv.qty - back then raise exception 'E_RETURN_QTY'; end if;
  -- قيمة سطر الشرا = الكمية × سعر الوحدة، فالقسمة من غير باقي
  refund := mv.value / mv.qty * p_qty;
  perform set_config('app.branch', o.branch_id::text, true);
  if p_cashbox is not null then
    cb := public.ledger_cashbox(p_cashbox);
    if cb.branch_id is distinct from o.branch_id then raise exception 'E_BAD_BRANCH'; end if;
  end if;
  e := gen_random_uuid();
  insert into public.journal_entries(id, shop_id, source_type, source_id, memo, idem_key, created_by)
  values (e, s, 'supplier_return', sup, left(trim(p_reason), 300), p_id, auth.uid());
  -- نفس ledger_issue، والحركة مربوطة بسطر الاستلام (الحركات ما بتتعدلش بعدين)
  perform 1 from public.items where id = mv.item_id and shop_id = s for update;
  select * into st from public.item_stock_at(mv.item_id, o.branch_id);
  if st.qty < p_qty then raise exception 'E_STOCK'; end if;
  cost := public.ledger_issue_cost(st.qty, st.value, p_qty);
  insert into public.stock_moves(shop_id, item_id, entry_id, qty, value, branch_id, return_of) values (s, mv.item_id, e, -p_qty, -cost, o.branch_id, mv.id);
  if cost = 0 and refund = 0 then raise exception 'E_BAD_AMOUNT'; end if;
  if cost > 0 then
    insert into public.journal_lines(shop_id, entry_id, account_id, debit, credit) values (s, e, public.ledger_acc('inventory'), 0, cost);
  end if;
  if refund > 0 then
    if cb.id is null then
      insert into public.journal_lines(shop_id, entry_id, account_id, party_type, party_id, debit, credit) values (s, e, public.ledger_acc('ap'), 'supplier', sup, refund, 0);
    else
      insert into public.journal_lines(shop_id, entry_id, account_id, debit, credit) values (s, e, cb.id, refund, 0);
    end if;
  end if;
  -- الفرق بين متوسط التكلفة وسعر الشرا: تكلفة بضاعة (زي supplier_return)
  diff := cost - refund;
  if diff > 0 then
    insert into public.journal_lines(shop_id, entry_id, account_id, debit, credit) values (s, e, public.ledger_acc('cogs'), diff, 0);
  elsif diff < 0 then
    insert into public.journal_lines(shop_id, entry_id, account_id, debit, credit) values (s, e, public.ledger_acc('cogs'), 0, -diff);
  end if;
  return e;
end $$;

-- الأوامر بحالتها: open (ما وصلش حاجة)، partial، received، cancelled. وكل سطر: المطلوب والمستلم وحركات استلامه (للمرتجع)
create or replace function public.purchase_orders_list(p_status text default null, p_branch uuid default null) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare s uuid := public.current_shop_id();
begin
  perform public.grant_require('purchases', 'view');
  return coalesce((
    -- shortcut: آخر 300 أمر، ولو محل عدّاهم نضيف صفحات
    with po0 as materialized (
      select o.* from public.purchase_orders o
      where o.shop_id = s and o.deleted_at is null and (p_branch is null or o.branch_id = p_branch)
        and (public.current_app_role() = 'owner' or public.can_branch(o.branch_id))
      order by o.created_at desc, o.id limit 300
    ),
    ln as materialized (
      select l.order_id, l.id, l.seq, l.item_id, i.name, l.qty, l.unit_cost, public.order_line_received(l.id) as got,
             coalesce((select jsonb_agg(jsonb_build_object('move', m.id, 'entry', m.entry_id, 'at', e.occurred_at, 'qty', m.qty, 'value', m.value, 'returned', public.move_returned(m.id)) order by e.occurred_at, m.id)
               from public.stock_moves m join public.journal_entries e on e.id = m.entry_id
               where m.order_line_id = l.id and not exists (select 1 from public.journal_entries x where x.reverses_id = m.entry_id)), '[]'::jsonb) as receipts
      from po0 join public.purchase_order_lines l on l.order_id = po0.id join public.items i on i.id = l.item_id
    ),
    po as (
      select o.*, sp.name as supplier,
             (select case when o.cancelled_at is not null then 'cancelled' when sum(ln.got) = 0 then 'open' when sum(ln.got) < sum(ln.qty) then 'partial' else 'received' end from ln where ln.order_id = o.id) as status
      from po0 o join public.suppliers sp on sp.id = o.supplier_id
    )
    select jsonb_agg(jsonb_build_object('id', po.id, 'order_no', po.order_no, 'branch_id', po.branch_id, 'supplier_id', po.supplier_id, 'supplier', po.supplier, 'status', po.status,
        'expected_on', po.expected_on, 'note', po.note, 'created_at', po.created_at, 'cancel_reason', po.cancel_reason,
        'lines', (select jsonb_agg(jsonb_build_object('id', ln.id, 'item', ln.item_id, 'name', ln.name, 'qty', ln.qty, 'unit_cost', ln.unit_cost, 'received', ln.got, 'receipts', ln.receipts) order by ln.seq)
                  from ln where ln.order_id = po.id)) order by po.created_at desc, po.id)
    from po where p_status is null or po.status = p_status), '[]'::jsonb);
end $$;
do $$
declare f text;
begin
  foreach f in array array['save_purchase_order(uuid, uuid, jsonb, date, text)', 'cancel_purchase_order(uuid, text)', 'receive_purchase_order(uuid, uuid, jsonb, uuid, text)',
                           'purchase_move_return(uuid, uuid, integer, uuid, text)', 'purchase_orders_list(text, uuid)'] loop
    execute format('revoke execute on function public.%s from public, anon', f);
    execute format('grant execute on function public.%s to authenticated', f);
  end loop;
end $$;

-- reverse_entry: (src: 0072_sale_line_return.sql) + شرا رجع منه حاجة ما يتلغيش قبل المرتجع
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
  if o.source_type = 'purchase' and exists (select 1 from public.stock_moves m where m.entry_id = o.id and m.qty > 0 and public.move_returned(m.id) > 0) then
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

-- backup_snapshot: (src: 0063_cheques.sql) + أوامر الشراء
create or replace function public.backup_snapshot(p_shop uuid) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare
  res jsonb := jsonb_build_object('format', 'warsha-backup', 'version', 1, 'generated_at', now(), 'shop_id', p_shop);
  t text;
  rows jsonb;
begin
  foreach t in array array['shops', 'branches', 'staff_branches', 'attendance', 'shop_branding', 'profiles', 'customers', 'devices', 'device_costs', 'status_log', 'device_notes', 'device_photos', 'device_checks',
                           'quote_decisions', 'message_templates', 'message_log', 'accounts', 'journal_entries', 'journal_lines', 'sale_lines', 'cheques', 'payments', 'drawer_closings',
                           'suppliers', 'categories', 'items', 'purchase_orders', 'purchase_order_lines', 'stock_moves', 'uncosted_sales', 'payment_plans', 'plan_installments', 'branch_goals', 'printers', 'print_templates', 'check_templates', 'used_devices', 'commission_rules', 'purchases', 'labor_rates', 'specialties', 'staff_specialties', 'routes', 'repair_steps',
                           'repair_videos', 'device_ratings', 'issue_presets', 'partners', 'profit_distributions', 'party_links', 'shop_lists', 'audit_log'] loop
    execute format('select coalesce(jsonb_agg(to_jsonb(x)), ''[]''::jsonb) from public.%I x where x.shop_id = $1', t) into rows using p_shop;
    res := res || jsonb_build_object(t, rows);
  end loop;
  select coalesce(jsonb_agg(jsonb_build_object('device_id', device_id, 'kind', kind, 'erased_at', erased_at)), '[]'::jsonb)
    into rows from public.device_passcodes where shop_id = p_shop;
  return res || jsonb_build_object('device_passcodes', rows);
end $$;

-- restore_backup: (src: 0073_shop_extras.sql) + أوامر الشراء (قبل حركة المخزون)
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
                       'purchases', 'purchase_orders', 'purchase_order_lines', 'stock_moves', 'uncosted_sales', 'used_devices', 'payment_plans', 'plan_installments', 'branch_goals', 'printers', 'print_templates', 'check_templates', 'drawer_closings', 'message_log', 'audit_log'];
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

-- edit_entry: (src: 0026_edit_delete.sql) + استلام أمر شراء ما يتعدلش (الجديد بيبقى من غير ربط بالأمر فيتستلم تاني): يتلغي ويتستلم من الأمر
create or replace function public.edit_entry(p_entry uuid, p_reason text, p_new jsonb) returns uuid
language plpgsql security definer set search_path = public as $$
declare
  o public.journal_entries;
  nid uuid := (p_new ->> 'id')::uuid;
  e uuid;
  amt bigint := (p_new ->> 'amount')::bigint;
  note text := nullif(trim(p_new ->> 'note'), '');
begin
  if public.current_app_role() is null or not public.can_correct() then raise exception 'E_FORBIDDEN'; end if;
  if nid is null then raise exception 'E_BAD_INPUT'; end if;
  e := public.ledger_idem(nid);
  if e is not null then return e; end if;
  select * into o from public.journal_entries where id = p_entry and shop_id = public.current_shop_id();
  if not found then raise exception 'E_NOT_FOUND'; end if;
  if exists (select 1 from public.stock_moves m where m.entry_id = o.id and m.order_line_id is not null) then raise exception 'E_ORDER_EDIT'; end if;
  perform public.reverse_entry(p_entry, p_reason);
  case o.source_type
    when 'payment' then e := public.record_payment(nid, (p_new ->> 'customer')::uuid, (p_new ->> 'cashbox')::uuid, amt, (p_new ->> 'device')::uuid, p_new ->> 'method', note);
    when 'expense' then e := public.record_expense(nid, (p_new ->> 'account')::uuid, (p_new ->> 'cashbox')::uuid, amt, note);
    when 'transfer' then e := public.transfer_cash(nid, (p_new ->> 'from')::uuid, (p_new ->> 'to')::uuid, amt, note);
    when 'capital' then e := public.owner_capital(nid, (p_new ->> 'cashbox')::uuid, amt, note);
    when 'drawing' then e := public.owner_drawing(nid, (p_new ->> 'cashbox')::uuid, amt, note);
    when 'advance' then e := public.give_advance(nid, (p_new ->> 'employee')::uuid, (p_new ->> 'cashbox')::uuid, amt, note);
    when 'salary' then e := public.accrue_salary(nid, (p_new ->> 'employee')::uuid, amt, note);
    when 'salary_payment' then e := public.pay_salary(nid, (p_new ->> 'employee')::uuid, (p_new ->> 'cashbox')::uuid, amt, note);
    when 'supplier_payment' then e := public.pay_supplier(nid, (p_new ->> 'supplier')::uuid, (p_new ->> 'cashbox')::uuid, amt, note);
    when 'purchase' then e := public.record_purchase(nid, (p_new ->> 'supplier')::uuid, p_new -> 'lines', (p_new ->> 'cashbox')::uuid, note);
    when 'sale' then e := public.record_sale(nid, p_new -> 'lines', (p_new ->> 'cashbox')::uuid, (p_new ->> 'customer')::uuid, note);
    else raise exception 'E_NOT_EDITABLE';
  end case;
  insert into public.audit_log(shop_id, actor_id, action, entity, entity_id, before, after)
  values (o.shop_id, auth.uid(), 'edit_entry', 'journal_entries', o.id, to_jsonb(o), jsonb_build_object('new_entry', e, 'reason', p_reason));
  return e;
end $$;
$m0079$;
  insert into public.app_migrations(version, how) values ('0079_purchase_orders.sql', 'applied');
  raise notice 'applied %', '0079_purchase_orders.sql';
end $run$;
commit;

-- ============================== 0080_stock_count.sql ==============================
begin;
do $run$ begin
  if exists (select 1 from public.app_migrations where version = '0080_stock_count.sql') then return; end if;
  execute $m0080$
-- 0080: (29) الجرد الدوري لفرع: رصيد بداية الجرد، والعد صنف صنف، وكشف الفروق، والاعتماد بقيد واحد.
-- - العد لوحده ما بيعملش تسوية. الفرق = المعدود − رصيد النظام لحظة عدّ الصنف، فالبيع بعد العد ما يلخبطش الفرق.
-- - اللي ما اتعدّش ما بيتسواش. المستعمل (IMEI) والخدمات مش في الجرد.
-- - العد بصلاحية "يعدّل" في المخزون، والاعتماد بصلاحية "المبالغ" و"يحذف" (زي الهالك).
alter table public.journal_entries drop constraint if exists journal_entries_source_type_check;
alter table public.journal_entries add constraint journal_entries_source_type_check check (source_type = any (array[
  'payment', 'delivery', 'purchase', 'supplier_payment', 'part_use', 'sale', 'expense', 'salary', 'salary_payment', 'advance', 'advance_settle',
  'capital', 'drawing', 'transfer', 'drawer_close', 'reversal', 'cost_adjust', 'write_off', 'supplier_return', 'sale_return', 'opening',
  'partner_capital', 'partner_withdrawal', 'profit_distribution', 'netting', 'stock_transfer', 'commission', 'bonus', 'penalty', 'vat_payment',
  'cheque_in', 'cheque_out', 'cheque_clear', 'cheque_bounce', 'stock_count']));

create table public.stock_counts (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references public.shops(id),
  branch_id uuid not null references public.branches(id),
  status text not null default 'open' check (status in ('open', 'posted', 'cancelled')),
  note text check (note is null or length(note) <= 300),
  entry_id uuid references public.journal_entries(id),
  closed_at timestamptz,
  closed_by uuid references public.profiles(id),
  created_by uuid references public.profiles(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  check ((status = 'open') = (closed_at is null))
);
-- جرد مفتوح واحد لكل فرع
create unique index stock_counts_open on public.stock_counts(branch_id) where status = 'open' and deleted_at is null;
create table public.stock_count_lines (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references public.shops(id),
  count_id uuid not null references public.stock_counts(id),
  item_id uuid not null references public.items(id),
  opening_qty bigint not null,
  system_qty bigint,
  counted_qty bigint check (counted_qty is null or (counted_qty >= 0 and counted_qty <= 1000000)),
  counted_at timestamptz,
  counted_by uuid references public.profiles(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  unique (count_id, item_id),
  check ((counted_qty is null) = (system_qty is null))
);
do $$
declare t text;
begin
  foreach t in array array['stock_counts', 'stock_count_lines'] loop
    execute format('alter table public.%I enable row level security', t);
    execute format('revoke all on public.%I from public, anon, authenticated', t);
    execute format('grant select on public.%I to authenticated', t);
    execute format('create trigger set_updated_at before update on public.%I for each row execute function public.tg_set_updated_at()', t);
    execute format('create trigger block_delete before delete on public.%I for each row execute function public.tg_block_delete()', t);
  end loop;
end $$;
create trigger zz_audit after insert or update on public.stock_counts for each row execute function public.tg_audit();
create trigger zz_audit after update on public.stock_count_lines for each row execute function public.tg_audit();
create policy stock_counts_select on public.stock_counts for select to authenticated
  using (shop_id = (select public.current_shop_id()) and ((select public.current_app_role()) = 'owner'
         or ((select public.current_app_role()) = 'reception' and (select public.has_perm('inventory', 'edit')) and public.can_branch(branch_id))));
create policy stock_count_lines_select on public.stock_count_lines for select to authenticated
  using (shop_id = (select public.current_shop_id()) and exists (select 1 from public.stock_counts c where c.id = count_id));

-- الجرد لو الموظف ليه فرعه (والقفل عليه لو p_lock)
create or replace function public.stock_count_get(p_count uuid, p_open boolean) returns public.stock_counts
language plpgsql security definer set search_path = public as $$
declare c public.stock_counts;
begin
  select * into c from public.stock_counts where id = p_count and shop_id = public.current_shop_id() and deleted_at is null for update;
  if not found or (public.current_app_role() <> 'owner' and not public.can_branch(c.branch_id)) then raise exception 'E_NOT_FOUND'; end if;
  if p_open and c.status <> 'open' then raise exception 'E_COUNT_CLOSED'; end if;
  return c;
end $$;
revoke execute on function public.stock_count_get(uuid, boolean) from public, anon, authenticated;

-- تكلفة الوحدة في الفرع: متوسطه، ولو مفيش رصيد بقيمة: آخر سعر شرا (متوسط كل الفروع ممكن يتلخبط برصيد من غير تكلفة)
create or replace function public.stock_count_cost(p_item uuid, p_branch uuid) returns bigint
language sql stable security definer set search_path = public as $$
  select coalesce(
    (select case when st.qty > 0 and st.value > 0 then st.value / st.qty end from public.item_stock_at(p_item, p_branch) st),
    (select m.value / m.qty from public.stock_moves m join public.journal_entries e on e.id = m.entry_id
      where m.item_id = p_item and m.qty > 0 and e.source_type = 'purchase' order by e.occurred_at desc, m.created_at desc limit 1),
    0)::bigint
$$;
revoke execute on function public.stock_count_cost(uuid, uuid) from public, anon, authenticated;

create or replace function public.start_stock_count(p_id uuid, p_note text default null) returns uuid
language plpgsql security definer set search_path = public as $$
declare s uuid := public.current_shop_id(); b uuid;
begin
  perform public.grant_require('inventory', 'edit');
  perform public.ledger_idem(p_id);
  if exists (select 1 from public.stock_counts where id = p_id) then
    return (public.stock_count_get(p_id, false)).id;
  end if;
  b := public.op_branch();
  begin
    insert into public.stock_counts(id, shop_id, branch_id, note, created_by) values (p_id, s, b, left(nullif(trim(p_note), ''), 300), auth.uid());
  exception when unique_violation then raise exception 'E_COUNT_OPEN';
  end;
  insert into public.stock_count_lines(shop_id, count_id, item_id, opening_qty)
  select s, p_id, i.id, coalesce((select sum(m.qty) from public.stock_moves m where m.item_id = i.id and m.branch_id = b), 0)
  from public.items i where i.shop_id = s and i.deleted_at is null and i.kind in ('part', 'accessory') order by i.id;
  return p_id;
end $$;

-- p_counted = null: مسح العد. صنف اتضاف بعد بداية الجرد بيتعدّ عادي
create or replace function public.save_stock_count(p_count uuid, p_item uuid, p_counted bigint) returns void
language plpgsql security definer set search_path = public as $$
declare s uuid := public.current_shop_id(); c public.stock_counts; q bigint;
begin
  perform public.grant_require('inventory', 'edit');
  c := public.stock_count_get(p_count, true);
  if p_counted is not null and (p_counted < 0 or p_counted > 1000000) then raise exception 'E_BAD_QTY'; end if;
  -- قفل الصنف: بيع في نفس اللحظة يبقى قبل العد أو بعده
  perform 1 from public.items where id = p_item and shop_id = s and deleted_at is null and kind in ('part', 'accessory') for update;
  if not found then raise exception 'E_NOT_FOUND'; end if;
  select st.qty into q from public.item_stock_at(p_item, c.branch_id) st;
  insert into public.stock_count_lines(shop_id, count_id, item_id, opening_qty) values (s, c.id, p_item, q) on conflict (count_id, item_id) do nothing;
  update public.stock_count_lines set counted_qty = p_counted, system_qty = case when p_counted is not null then q end,
         counted_at = case when p_counted is not null then now() end, counted_by = case when p_counted is not null then auth.uid() end
  where count_id = c.id and item_id = p_item;
end $$;

create or replace function public.cancel_stock_count(p_count uuid) returns void
language plpgsql security definer set search_path = public as $$
declare c public.stock_counts;
begin
  perform public.grant_require('inventory', 'edit');
  c := public.stock_count_get(p_count, false);
  if c.status = 'cancelled' then return; end if;
  if c.status = 'posted' then raise exception 'E_COUNT_CLOSED'; end if;
  update public.stock_counts set status = 'cancelled', closed_at = now(), closed_by = auth.uid() where id = c.id;
end $$;

-- الاعتماد: النقص بيخرج بمتوسط تكلفته، والزيادة بتدخل بآخر تكلفة، والفرق في "هالك المخزون". من غير فروق: بيتقفل من غير قيد
create or replace function public.post_stock_count(p_id uuid, p_count uuid, p_reason text) returns uuid
language plpgsql security definer set search_path = public as $$
declare s uuid := public.current_shop_id(); c public.stock_counts; l record; e uuid; diff bigint; cost bigint; net bigint := 0; gross bigint := 0; n int := 0;
begin
  perform public.grant_require('inventory', 'amounts');
  perform public.grant_require('inventory', 'delete');
  e := public.ledger_idem(p_id);
  if e is not null then return e; end if;
  c := public.stock_count_get(p_count, false);
  if c.status = 'posted' then return c.entry_id; end if;
  if c.status <> 'open' then raise exception 'E_COUNT_CLOSED'; end if;
  if nullif(trim(p_reason), '') is null then raise exception 'E_REASON_REQUIRED'; end if;
  if not exists (select 1 from public.stock_count_lines where count_id = c.id and counted_qty is not null) then raise exception 'E_COUNT_EMPTY'; end if;
  if exists (select 1 from public.stock_count_lines sl join public.items i on i.id = sl.item_id and i.deleted_at is null where sl.count_id = c.id and sl.counted_qty <> sl.system_qty) then
    perform set_config('app.branch', c.branch_id::text, true);
    e := gen_random_uuid();
    insert into public.journal_entries(id, shop_id, source_type, source_id, memo, idem_key, created_by, branch_id)
    values (e, s, 'stock_count', c.id, left(trim(p_reason), 300), p_id, auth.uid(), c.branch_id);
    -- بترتيب ثابت عشان جردين ما يستنوش بعض. صنف اتحذف بعد العد (رصيده صفر): مفيش حاجة تتسوى
    for l in select sl.* from public.stock_count_lines sl join public.items i on i.id = sl.item_id and i.deleted_at is null
             where sl.count_id = c.id and sl.counted_qty <> sl.system_qty order by sl.item_id loop
      perform 1 from public.items where id = l.item_id for update;
      diff := l.counted_qty - l.system_qty;
      if diff < 0 then
        cost := public.ledger_issue(l.item_id, -diff, e);
        net := net + cost;
      else
        cost := public.stock_count_cost(l.item_id, c.branch_id) * diff;
        -- زيادة في صنف تكلفته مش معروفة: بتتسجل من "تسوية مخزون" بتكلفتها
        if cost <= 0 then raise exception 'E_COUNT_COST'; end if;
        insert into public.stock_moves(shop_id, item_id, entry_id, qty, value, branch_id) values (s, l.item_id, e, diff, cost, c.branch_id);
        net := net - cost;
      end if;
      gross := gross + cost;
      n := n + 1;
    end loop;
    if gross = 0 then raise exception 'E_COUNT_COST'; end if;
    -- الزيادة والنقص كل واحد بسطره (القيد بيبان منه الاتنين حتى لو صافيهم صفر)
    if (gross + net) / 2 > 0 then
      insert into public.journal_lines(shop_id, entry_id, account_id, debit, credit) values
        (s, e, public.ledger_acc('wastage'), (gross + net) / 2, 0), (s, e, public.ledger_acc('inventory'), 0, (gross + net) / 2);
    end if;
    if (gross - net) / 2 > 0 then
      insert into public.journal_lines(shop_id, entry_id, account_id, debit, credit) values
        (s, e, public.ledger_acc('inventory'), (gross - net) / 2, 0), (s, e, public.ledger_acc('wastage'), 0, (gross - net) / 2);
    end if;
  end if;
  update public.stock_counts set status = 'posted', closed_at = now(), closed_by = auth.uid(), entry_id = e where id = c.id;
  insert into public.audit_log(shop_id, actor_id, action, entity, entity_id, after)
  values (s, auth.uid(), 'stock_count_post', 'stock_counts', c.id, jsonb_build_object('items', n, 'shortage', (gross + net) / 2, 'surplus', (gross - net) / 2, 'reason', left(trim(p_reason), 300), 'entry', e));
  return e;
end $$;

-- كشف الفروق: القيمة (بالتكلفة) لأصحاب "المبالغ" بس
create or replace function public.stock_count_sheet(p_count uuid) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare c public.stock_counts; m boolean := public.has_perm('inventory', 'amounts');
begin
  perform public.grant_require('inventory', 'edit');
  select * into c from public.stock_counts where id = p_count and shop_id = public.current_shop_id() and deleted_at is null;
  if not found or (public.current_app_role() <> 'owner' and not public.can_branch(c.branch_id)) then raise exception 'E_NOT_FOUND'; end if;
  return jsonb_build_object('id', c.id, 'branch_id', c.branch_id, 'status', c.status, 'note', c.note, 'started_at', c.created_at, 'closed_at', c.closed_at, 'entry', c.entry_id,
    'reversed', exists (select 1 from public.journal_entries x where x.reverses_id = c.entry_id),
    'lines', coalesce((select jsonb_agg(jsonb_build_object('item', l.item_id, 'name', i.name, 'opening', l.opening_qty, 'system', l.system_qty, 'counted', l.counted_qty, 'diff', l.counted_qty - l.system_qty,
        'counted_at', l.counted_at, 'value', case when m and l.counted_qty is not null then (l.counted_qty - l.system_qty) * public.stock_count_cost(l.item_id, c.branch_id) end) order by i.name, i.id)
      from public.stock_count_lines l join public.items i on i.id = l.item_id where l.count_id = c.id), '[]'::jsonb));
end $$;
do $$
declare f text;
begin
  foreach f in array array['start_stock_count(uuid, text)', 'save_stock_count(uuid, uuid, bigint)', 'cancel_stock_count(uuid)', 'post_stock_count(uuid, uuid, text)', 'stock_count_sheet(uuid)'] loop
    execute format('revoke execute on function public.%s from public, anon', f);
    execute format('grant execute on function public.%s to authenticated', f);
  end loop;
end $$;

-- entry_section: (src: 0075_delete_by_section.sql) + قيد الجرد تبع المخزون
create or replace function public.entry_section(p_source text) returns text
language sql immutable as $$
  select case
    when p_source in ('sale', 'sale_return') then 'sales'
    when p_source in ('payment', 'transfer', 'drawer_close') then 'cashbox'
    when p_source = 'expense' then 'expenses'
    when p_source in ('purchase', 'supplier_payment', 'supplier_return') then 'purchases'
    when p_source in ('write_off', 'stock_transfer', 'stock_count') then 'inventory'
    when p_source in ('part_use', 'delivery') then 'devices'
    else 'finance' end
$$;

-- backup_snapshot: (src: 0079_purchase_orders.sql) + الجرد
create or replace function public.backup_snapshot(p_shop uuid) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare
  res jsonb := jsonb_build_object('format', 'warsha-backup', 'version', 1, 'generated_at', now(), 'shop_id', p_shop);
  t text;
  rows jsonb;
begin
  foreach t in array array['shops', 'branches', 'staff_branches', 'attendance', 'shop_branding', 'profiles', 'customers', 'devices', 'device_costs', 'status_log', 'device_notes', 'device_photos', 'device_checks',
                           'quote_decisions', 'message_templates', 'message_log', 'accounts', 'journal_entries', 'journal_lines', 'sale_lines', 'cheques', 'payments', 'drawer_closings',
                           'suppliers', 'categories', 'items', 'purchase_orders', 'purchase_order_lines', 'stock_counts', 'stock_count_lines', 'stock_moves', 'uncosted_sales', 'payment_plans', 'plan_installments', 'branch_goals', 'printers', 'print_templates', 'check_templates', 'used_devices', 'commission_rules', 'purchases', 'labor_rates', 'specialties', 'staff_specialties', 'routes', 'repair_steps',
                           'repair_videos', 'device_ratings', 'issue_presets', 'partners', 'profit_distributions', 'party_links', 'shop_lists', 'audit_log'] loop
    execute format('select coalesce(jsonb_agg(to_jsonb(x)), ''[]''::jsonb) from public.%I x where x.shop_id = $1', t) into rows using p_shop;
    res := res || jsonb_build_object(t, rows);
  end loop;
  select coalesce(jsonb_agg(jsonb_build_object('device_id', device_id, 'kind', kind, 'erased_at', erased_at)), '[]'::jsonb)
    into rows from public.device_passcodes where shop_id = p_shop;
  return res || jsonb_build_object('device_passcodes', rows);
end $$;

-- restore_backup: (src: 0079_purchase_orders.sql) + الجرد
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
                       'purchases', 'purchase_orders', 'purchase_order_lines', 'stock_counts', 'stock_count_lines', 'stock_moves', 'uncosted_sales', 'used_devices', 'payment_plans', 'plan_installments', 'branch_goals', 'printers', 'print_templates', 'check_templates', 'drawer_closings', 'message_log', 'audit_log'];
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
     or exists (select 1 from public.stock_counts where shop_id = s and status = 'open')
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
$m0080$;
  insert into public.app_migrations(version, how) values ('0080_stock_count.sql', 'applied');
  raise notice 'applied %', '0080_stock_count.sql';
end $run$;
commit;

-- ============================== 0081_repair_invoice.sql ==============================
begin;
do $run$ begin
  if exists (select 1 from public.app_migrations where version = '0081_repair_invoice.sql') then return; end if;
  execute $m0081$
-- 0081: (19) فاتورة صيانة ثابتة: رقم مستقل وتاريخ إصدار لكل تسليم، والبيانات زي ما كانت وقت الإصدار.
-- - بتتعمل أول مرة الفاتورة تتطلب بعد التسليم، وبعدها نفس الفاتورة دايمًا (إعادة الطباعة ما بتغيّرش حاجة).
-- - مربوطة بقيد التسليم: لو اتلغى، الفاتورة بتبان ملغية (reversed)، والتسليم الجديد ليه رقم جديد. مرتجع الضمان بيرجع بنفس فاتورته.
-- - المبلغ والضريبة من القيد نفسه. المدفوع والباقي مش جوه الفاتورة (بيتغيّروا)، والشاشة بتقراهم لحظتها.
create table public.repair_invoices (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references public.shops(id),
  branch_id uuid not null references public.branches(id),
  device_id uuid not null references public.devices(id),
  entry_id uuid not null unique references public.journal_entries(id),
  prefix text not null default '',
  year integer not null,
  seq integer not null check (seq > 0),
  invoice_no text not null,
  issued_at timestamptz not null default now(),
  issued_by uuid references public.profiles(id),
  data jsonb not null check (jsonb_typeof(data) = 'object'),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  -- الترقيم بالبادئة مش بالفرع: بادئة اتنقلت لفرع تاني بتكمّل نفس الترقيم
  unique (shop_id, prefix, year, seq),
  unique (shop_id, invoice_no)
);
create index repair_invoices_device on public.repair_invoices(device_id);
alter table public.repair_invoices enable row level security;
revoke all on public.repair_invoices from public, anon, authenticated;
grant select on public.repair_invoices to authenticated;
create trigger set_updated_at before update on public.repair_invoices for each row execute function public.tg_set_updated_at();
create trigger block_delete before delete on public.repair_invoices for each row execute function public.tg_block_delete();
create trigger ledger_immutable before update or delete on public.repair_invoices for each row execute function public.tg_ledger_immutable();
create trigger ledger_no_truncate before truncate on public.repair_invoices for each statement execute function public.tg_ledger_immutable();
-- فيها اسم العميل والمبلغ: مبالغ الأجهزة + الجهاز نفسه باين (فرعه دلوقتي). الفني لأ. وسجل النشاط فيه الرقم بس
create policy repair_invoices_select on public.repair_invoices for select to authenticated
  using (shop_id = (select public.current_shop_id()) and (select public.current_app_role()) in ('owner', 'reception')
         and (select public.has_perm('devices', 'amounts')) and exists (select 1 from public.devices d where d.id = device_id));

-- p_issue = false: اقرا الموجودة بس (null لو لسه ما صدرتش)
create or replace function public.repair_invoice(p_device uuid, p_issue boolean default true) returns jsonb
language plpgsql security definer set search_path = public as $$
declare s uuid := public.current_shop_id(); d public.devices; e public.journal_entries; inv public.repair_invoices; y integer; n integer; pre text; gross bigint; vat bigint;
begin
  perform public.ledger_require(array['owner', 'reception']::public.app_role[]);
  select * into d from public.devices where id = p_device and shop_id = s and deleted_at is null;
  if not found then raise exception 'E_NOT_FOUND'; end if;
  perform public.device_require(d.id, 'amounts');
  if p_issue then select * into d from public.devices where id = d.id for update; end if;
  select * into e from public.journal_entries j where j.shop_id = s and j.source_type = 'delivery' and j.source_id = d.id
    and not exists (select 1 from public.journal_entries x where x.reverses_id = j.id) order by j.occurred_at desc limit 1;
  if e.id is not null then select * into inv from public.repair_invoices where entry_id = e.id; end if;
  if inv.id is null then
    if not p_issue then return null; end if;
    -- لسه ما اتسلّمش، أو اتسلّم من غير تكلفة: مفيش فاتورة
    if e.id is null then raise exception 'E_NO_INVOICE'; end if;
    -- الجهاز راجع ضمان: قطع الضمان ما تدخلش فاتورة التسليم الأول
    if d.status <> 'delivered' then raise exception 'E_NO_INVOICE'; end if;
    select coalesce(sum(l.credit), 0), coalesce(sum(l.credit) filter (where a.kind = 'tax'), 0) into gross, vat
      from public.journal_lines l join public.accounts a on a.id = l.account_id where l.entry_id = e.id and a.kind in ('revenue', 'tax');
    y := extract(year from (now() at time zone 'Africa/Cairo'))::int;
    -- رقم ورا رقم من غير فجوات ولا تكرار للبادئة والسنة
    select coalesce(b.prefix, '') into pre from public.branches b where b.id = e.branch_id;
    perform pg_advisory_xact_lock(hashtextextended('repair_invoice:' || s || ':' || pre || ':' || y, 0));
    select coalesce(max(seq), 0) + 1 into n from public.repair_invoices where shop_id = s and prefix = pre and year = y;
    insert into public.repair_invoices(shop_id, branch_id, device_id, entry_id, prefix, year, seq, invoice_no, issued_by, data)
    values (s, e.branch_id, d.id, e.id, pre, y, n, concat_ws('-', nullif(pre, ''), 'F', y, lpad(n::text, greatest(4, length(n::text)), '0')), auth.uid(), jsonb_build_object(
      'order_no', d.order_no, 'brand', d.brand, 'model', d.model, 'imei', d.imei, 'issue', d.issue, 'received_at', d.received_at, 'delivered_at', e.occurred_at, 'warranty_until', d.warranty_until,
      'customer', (select c.name from public.customers c where c.id = d.customer_id), 'phone', (select c.phone from public.customers c where c.id = d.customer_id),
      'parts', coalesce((select jsonb_agg(jsonb_build_object('name', x.name, 'qty', x.qty) order by x.name) from public.device_parts(d.id) x), '[]'::jsonb),
      'total', gross, 'vat', vat, 'net', gross - vat,
      'vat_no', case when vat > 0 then (select nullif(trim(sh.extras -> 'vat' ->> 'reg_no'), '') from public.shops sh where sh.id = s) end,
      'currency', (select sh.currency from public.shops sh where sh.id = s)))
    returning * into inv;
    insert into public.audit_log(shop_id, actor_id, action, entity, entity_id, after)
    values (s, auth.uid(), 'insert', 'repair_invoices', inv.id, jsonb_build_object('invoice_no', inv.invoice_no, 'order_no', d.order_no));
  end if;
  return inv.data || jsonb_build_object('id', inv.id, 'invoice_no', inv.invoice_no, 'issued_at', inv.issued_at, 'branch_id', inv.branch_id, 'device_id', inv.device_id);
end $$;
revoke execute on function public.repair_invoice(uuid, boolean) from public, anon;
grant execute on function public.repair_invoice(uuid, boolean) to authenticated;

-- كل فواتير الجهاز (والملغي منها باين)
create or replace function public.repair_invoices_of(p_device uuid) returns jsonb
language plpgsql stable security definer set search_path = public as $$
begin
  perform public.ledger_require(array['owner', 'reception']::public.app_role[]);
  if not exists (select 1 from public.devices where id = p_device and shop_id = public.current_shop_id()) then raise exception 'E_NOT_FOUND'; end if;
  perform public.device_require(p_device, 'amounts');
  return coalesce((select jsonb_agg(v.data || jsonb_build_object('id', v.id, 'invoice_no', v.invoice_no, 'issued_at', v.issued_at,
      'reversed', exists (select 1 from public.journal_entries x where x.reverses_id = v.entry_id)) order by v.issued_at, v.seq)
    from public.repair_invoices v where v.device_id = p_device), '[]'::jsonb);
end $$;
revoke execute on function public.repair_invoices_of(uuid) from public, anon;
grant execute on function public.repair_invoices_of(uuid) to authenticated;

-- backup_snapshot: (src: 0080_stock_count.sql) + فواتير الصيانة
create or replace function public.backup_snapshot(p_shop uuid) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare
  res jsonb := jsonb_build_object('format', 'warsha-backup', 'version', 1, 'generated_at', now(), 'shop_id', p_shop);
  t text;
  rows jsonb;
begin
  foreach t in array array['shops', 'branches', 'staff_branches', 'attendance', 'shop_branding', 'profiles', 'customers', 'devices', 'device_costs', 'status_log', 'device_notes', 'device_photos', 'device_checks',
                           'quote_decisions', 'message_templates', 'message_log', 'accounts', 'journal_entries', 'journal_lines', 'repair_invoices', 'sale_lines', 'cheques', 'payments', 'drawer_closings',
                           'suppliers', 'categories', 'items', 'purchase_orders', 'purchase_order_lines', 'stock_counts', 'stock_count_lines', 'stock_moves', 'uncosted_sales', 'payment_plans', 'plan_installments', 'branch_goals', 'printers', 'print_templates', 'check_templates', 'used_devices', 'commission_rules', 'purchases', 'labor_rates', 'specialties', 'staff_specialties', 'routes', 'repair_steps',
                           'repair_videos', 'device_ratings', 'issue_presets', 'partners', 'profit_distributions', 'party_links', 'shop_lists', 'audit_log'] loop
    execute format('select coalesce(jsonb_agg(to_jsonb(x)), ''[]''::jsonb) from public.%I x where x.shop_id = $1', t) into rows using p_shop;
    res := res || jsonb_build_object(t, rows);
  end loop;
  select coalesce(jsonb_agg(jsonb_build_object('device_id', device_id, 'kind', kind, 'erased_at', erased_at)), '[]'::jsonb)
    into rows from public.device_passcodes where shop_id = p_shop;
  return res || jsonb_build_object('device_passcodes', rows);
end $$;

-- restore_backup: (src: 0080_stock_count.sql) + فواتير الصيانة
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
                       'quote_decisions', 'repair_steps', 'repair_videos', 'device_ratings', 'journal_entries', 'journal_lines', 'repair_invoices', 'sale_lines', 'cheques', 'profit_distributions', 'payments',
                       'purchases', 'purchase_orders', 'purchase_order_lines', 'stock_counts', 'stock_count_lines', 'stock_moves', 'uncosted_sales', 'used_devices', 'payment_plans', 'plan_installments', 'branch_goals', 'printers', 'print_templates', 'check_templates', 'drawer_closings', 'message_log', 'audit_log'];
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
     or exists (select 1 from public.stock_counts where shop_id = s and status = 'open')
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
$m0081$;
  insert into public.app_migrations(version, how) values ('0081_repair_invoice.sql', 'applied');
  raise notice 'applied %', '0081_repair_invoice.sql';
end $run$;
commit;

-- ============================== 0082_order_prefix.sql ==============================
begin;
do $run$ begin
  if exists (select 1 from public.app_migrations where version = '0082_order_prefix.sql') then return; end if;
  execute $m0082$
-- 0082: (35ج) بادئة فرع اتعاد استخدامها كانت بتكرّر رقم الطلب والاستلام بيقف.
-- - save_branch بيرفض بادئة اتستخدمت قبل كده في المحل (أجهزة أو فواتير)، حتى لو فرعها اتقفل أو غيّر بادئته.
-- - المحلات اللي وقعت فيها خلاص: العدّاد بيعدّي الأرقام المستخدمة. (وبيغطي جهاز اتنقل لفرع تاني قبل استرجاع نسخة.)
-- - الرقم بعد 9999 بيكمّل بخانات أكتر (lpad كانت بتقصّه وتكرّره).

-- tg_device_defaults: (src: 0034_branches.sql)
create or replace function public.tg_device_defaults() returns trigger
language plpgsql security definer set search_path = public as $$
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
  loop
    new.order_no := concat_ws('-', nullif(pre, ''), y, lpad(n::text, greatest(4, length(n::text)), '0'));
    exit when not exists (select 1 from public.devices d where d.shop_id = new.shop_id and d.order_no = new.order_no);
    n := n + 1;
  end loop;
  update public.order_counters set last_value = n where shop_id = new.shop_id and branch_id = new.branch_id and year = y and last_value <> n;
  new.status := 'received';
  new.received_by := auth.uid();
  new.received_at := now();
  new.delivered_at := null;
  return new;
end $$;

create or replace function public.prefix_used(p_shop uuid, p_prefix text) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.devices where shop_id = p_shop and order_no ~ ('^' || p_prefix || '-[0-9]{4}-[0-9]+$'))
      or exists (select 1 from public.repair_invoices where shop_id = p_shop and prefix = p_prefix)
$$;
revoke execute on function public.prefix_used(uuid, text) from public, anon, authenticated;

-- save_branch: (src: 0034_branches.sql) + E_PREFIX_USED
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
    if pre <> b.prefix and public.prefix_used(s, pre) then raise exception 'E_PREFIX_USED'; end if;
    if exists (select 1 from public.branches x where x.shop_id = s and x.deleted_at is null and x.id <> b.id and lower(trim(x.name)) = lower(nm)) then raise exception 'E_DUP_NAME'; end if;
    update public.branches set name = nm, prefix = pre, phone = nullif(trim(p_phone), ''), address = nullif(trim(p_address), '') where id = b.id;
    return b.id;
  end if;
  if pre !~ '^[A-Z0-9]{1,4}$' then raise exception 'E_BAD_PREFIX'; end if;
  if exists (select 1 from public.branches x where x.shop_id = s and x.deleted_at is null and x.prefix = pre) then raise exception 'E_DUP_PREFIX'; end if;
  if public.prefix_used(s, pre) then raise exception 'E_PREFIX_USED'; end if;
  if exists (select 1 from public.branches x where x.shop_id = s and x.deleted_at is null and lower(trim(x.name)) = lower(nm)) then raise exception 'E_DUP_NAME'; end if;
  insert into public.branches(id, shop_id, name, prefix, phone, address) values (p_id, s, nm, pre, nullif(trim(p_phone), ''), nullif(trim(p_address), ''));
  for m in select unnest(array['cash']) union select unnest(payment_methods) from public.shops where id = s loop
    insert into public.accounts(shop_id, name, type, kind, method, branch_id) values (s, nm, 'asset', 'cash', m, p_id);
  end loop;
  return p_id;
end $$;
$m0082$;
  insert into public.app_migrations(version, how) values ('0082_order_prefix.sql', 'applied');
  raise notice 'applied %', '0082_order_prefix.sql';
end $run$;
commit;

-- ============================== 0083_print_perm.sql ==============================
begin;
do $run$ begin
  if exists (select 1 from public.app_migrations where version = '0083_print_perm.sql') then return; end if;
  execute $m0083$
-- 0083: (50.1) صلاحية "قوالب الطباعة" (print_templates ← يعدّل)، مقفولة لكل الأدوار ما عدا صاحب المحل. الفني عمره ما ياخدها.
-- الموظف بيها: قوالب وطابعات فروعه بس. قالب المحل كله (من غير فرع) لصاحب المحل أو اللي معاه كل الفروع. القراية زي ما هي.

-- perm_sections: (src: 0038_roles_grant.sql) + print_templates
create or replace function public.perm_sections() returns text[]
language sql immutable as $$
  select array['devices', 'intake', 'customers', 'technicians', 'inventory', 'item_create', 'sales', 'purchases', 'cashbox', 'expenses', 'finance', 'partners', 'reports', 'staff', 'settings', 'print_templates', 'audit']
$$;

create or replace function public.can_edit_print(p_branch uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select coalesce(public.current_app_role() = 'owner'
    or (public.current_app_role() = 'reception' and public.has_perm('print_templates', 'edit')
        and case when p_branch is null then public.all_my_branches() else public.can_branch(p_branch) end), false)
$$;
revoke execute on function public.can_edit_print(uuid) from public, anon;
grant execute on function public.can_edit_print(uuid) to authenticated;

drop policy printers_insert on public.printers;
drop policy printers_update on public.printers;
drop policy templates_insert on public.print_templates;
drop policy templates_update on public.print_templates;
create policy printers_insert on public.printers for insert to authenticated with check (shop_id = (select public.current_shop_id()) and public.can_edit_print(branch_id));
create policy printers_update on public.printers for update to authenticated using (shop_id = (select public.current_shop_id()) and public.can_edit_print(branch_id));
create policy templates_insert on public.print_templates for insert to authenticated with check (shop_id = (select public.current_shop_id()) and public.can_edit_print(branch_id));
create policy templates_update on public.print_templates for update to authenticated using (shop_id = (select public.current_shop_id()) and public.can_edit_print(branch_id));
$m0083$;
  insert into public.app_migrations(version, how) values ('0083_print_perm.sql', 'applied');
  raise notice 'applied %', '0083_print_perm.sql';
end $run$;
commit;

-- ============================== 0084_party_branch.sql ==============================
begin;
do $run$ begin
  if exists (select 1 from public.app_migrations where version = '0084_party_branch.sql') then return; end if;
  execute $m0084$
-- 0084: (قرار صاحب المشروع 2026-11-24) أرصدة العملاء والموردين للموظف اللي معاه "الوضع المالي": فرعه بس، حتى لو معاه كل الفروع. صاحب المحل بس اللي يشوف المحل كله.
-- نفس القاعدة في الأرصدة، وكشف حساب العميل والمورد والمربوطين، وأعمار المديونية، عشان الأرقام تطابق.

-- null = المحل كله (صاحب المحل)
create or replace function public.party_branch() returns uuid
language plpgsql stable security definer set search_path = public as $$
declare b uuid;
begin
  if public.current_app_role() = 'owner' then return null; end if;
  b := public.op_branch();
  if b is null then raise exception 'E_FORBIDDEN'; end if;
  return b;
end $$;
revoke execute on function public.party_branch() from public, anon, authenticated;

-- party_balances: (src: 0038_roles_grant.sql)
create or replace function public.party_balances(p_kind text)
returns table(party_type text, party_id uuid, name text, account text, balance bigint, oldest timestamptz)
language plpgsql stable security definer set search_path = public as $$
#variable_conflict use_column
declare s uuid := public.current_shop_id(); br uuid := public.party_branch();
begin
  perform public.grant_require('finance', 'view');
  if p_kind = 'employees' and public.current_app_role() <> 'owner' then raise exception 'E_FORBIDDEN'; end if;
  if p_kind not in ('customers', 'suppliers', 'employees') then raise exception 'E_BAD_INPUT'; end if;
  return query
  with lines as (
    select l.party_type, l.party_id, a.code, e.occurred_at, e.entry_no,
           (case when public.account_sign(a.type) = 1 then l.debit else l.credit end)::bigint as plus,
           (case when public.account_sign(a.type) = 1 then l.credit else l.debit end)::bigint as minus
    from public.journal_lines l join public.accounts a on a.id = l.account_id join public.journal_entries e on e.id = l.entry_id
    where l.shop_id = s and l.party_id is not null and (br is null or e.branch_id = br)
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

-- statement: (src: 0038_roles_grant.sql)
create or replace function public.statement(p_kind text, p_id uuid, p_from timestamptz, p_to timestamptz) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare
  s uuid := public.current_shop_id();
  accs uuid[];
  parties uuid[] := array[p_id];
  lk public.party_links;
  opening bigint;
  br uuid; -- كشف العميل والمورد للموظف: فرعه بس. الخزنة ليها فحصها
  res jsonb;
begin
  perform public.grant_require('finance', 'view');
  -- المرتبات والشركاء لصاحب المحل بس، والخزنة لازم تكون في فروع الموظف
  if public.current_app_role() <> 'owner' and (p_kind in ('employee', 'partner')
     or (p_kind = 'cashbox' and not exists (select 1 from public.accounts a where a.id = p_id and public.can_branch(a.branch_id)))) then raise exception 'E_FORBIDDEN'; end if;
  if p_kind <> 'cashbox' then br := public.party_branch(); end if;
  if p_kind = 'cashbox' then
    select array_agg(id) into accs from public.accounts where id = p_id and shop_id = s and kind = 'cash';
  elsif p_kind = 'customer' then
    select array_agg(id) into accs from public.accounts where shop_id = s and kind = 'receivable';
  elsif p_kind = 'supplier' then
    select array_agg(id) into accs from public.accounts where shop_id = s and kind = 'payable';
  elsif p_kind = 'employee' then
    select array_agg(id) into accs from public.accounts where shop_id = s and kind in ('advances', 'salaries');
  elsif p_kind = 'partner' then
    -- (0029) كشف الشريك: رأس ماله وحسابه الجاري. الرصيد = اللي ليه عند المحل
    select array_agg(id) into accs from public.accounts where shop_id = s and kind in ('partner_capital', 'partner_current');
  elsif p_kind = 'linked' then
    -- (0030) كشف صافي لعميل ومورد مربوطين: اللي عليه كعميل − اللي ليه كمورد. موجب = هو عليه للمحل
    select * into lk from public.party_links where id = p_id and shop_id = s and deleted_at is null;
    if not found then raise exception 'E_NOT_FOUND'; end if;
    parties := array[lk.customer_id, lk.supplier_id];
    select array_agg(id) into accs from public.accounts where shop_id = s and kind in ('receivable', 'payable');
  else
    raise exception 'E_BAD_INPUT';
  end if;
  if accs is null then raise exception 'E_NOT_FOUND'; end if;
  -- الرصيد: للخزنة والعميل والسلف = مدين − دائن. للمورد والمرتبات = دائن − مدين (الطرف الطبيعي)
  select coalesce(sum((l.debit - l.credit) * (case when p_kind = 'linked' then 1 else public.account_sign(a.type) end)), 0) into opening
  from public.journal_lines l join public.accounts a on a.id = l.account_id join public.journal_entries e on e.id = l.entry_id
  where l.account_id = any(accs) and (p_kind = 'cashbox' or l.party_id = any(parties)) and (br is null or e.branch_id = br) and e.occurred_at < p_from;
  with mv as (
    select e.id as entry_id, e.entry_no, e.occurred_at, e.source_type, e.source_id, e.device_id, e.memo, e.reverses_id,
           d.order_no, p.full_name as by_name, a.code as account_code,
           ((l.debit - l.credit) * (case when p_kind = 'linked' then 1 else public.account_sign(a.type) end))::bigint as amount
    from public.journal_lines l
    join public.accounts a on a.id = l.account_id
    join public.journal_entries e on e.id = l.entry_id
    left join public.devices d on d.id = e.device_id
    left join public.profiles p on p.id = e.created_by
    where l.account_id = any(accs) and (p_kind = 'cashbox' or l.party_id = any(parties)) and (br is null or e.branch_id = br) and e.occurred_at >= p_from and e.occurred_at < p_to
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

-- debt_aging: (src: 0076_debt_aging.sql)
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
  -- الموظف: فرع واحد من فروعه، حتى لو طلب غيره. المحل كله لصاحب المحل بس
  if public.current_app_role() <> 'owner' and (p_branch is null or not public.can_branch(p_branch)) then
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
$m0084$;
  insert into public.app_migrations(version, how) values ('0084_party_branch.sql', 'applied');
  raise notice 'applied %', '0084_party_branch.sql';
end $run$;
commit;

select 6 as part, 6 as parts, count(*) as applied_files, max(version) as latest,
  case when '0084_party_branch.sql' in (select version from public.app_migrations) then
    'خلص: المشروع على آخر نسخة'
  else 'فيه ملف ما اتطبقش' end as status
from public.app_migrations;
