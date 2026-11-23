-- جوالك / Gawalak: ترقية مشروع Supabase لآخر نسخة، الجزء 2 من 6 (الملفات 0018_account_state.sql لـ 0033_assistant.sql).
-- بيتولد تلقائيًا: npm run db:setup-file. ما تعدّلوش بإيدك.
-- شغّل الأجزاء بالترتيب في SQL Editor (كل جزء لوحده: New query ← الصق ← Run): upgrade_part_1.sql ثم upgrade_part_2.sql ثم upgrade_part_3.sql ثم upgrade_part_4.sql ثم upgrade_part_5.sql ثم upgrade_part_6.sql.
-- آمن تشغّل أي جزء أكتر من مرة: اللي اتطبق قبل كده بيتخطى. ولو ملف فشل، اللي قبله بيفضل، وصلّح السبب وشغّل نفس الجزء تاني.
-- لو لقى ملف أحدث موجود وأقدم منه ناقص بيقف (E_UPGRADE_GAP). ولو جزء قبله لسه ما اتطبقش بيقف (E_UPGRADE_ORDER). الاتنين من غير تغيير.
-- ملفات الجزء ده: 0018_account_state.sql, 0019_extras.sql, 0020_admin_paging.sql, 0021_spec_rules.sql, 0022_security_review.sql, 0023_restore.sql, 0024_signout.sql, 0025_integrity.sql, 0026_edit_delete.sql, 0027_inventory.sql, 0028_opening.sql, 0029_partners.sql, 0030_party_links.sql, 0031_partner_capital.sql, 0032_lists.sql, 0033_assistant.sql

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
  insert into public.app_migrations(version, how) select v, 'inferred' from unnest(array['0022_security_review.sql']::text[]) v
    where v < (select max(version) from public.app_migrations) on conflict (version) do nothing;
  select min(v) into first_missing from unnest(array['0001_phase1.sql', '0002_storage.sql', '0003_shop_profile_realtime.sql', '0004_error_codes.sql', '0005_device_passcode.sql', '0006_invite_name.sql', '0007_phase2_customer.sql', '0008_ledger.sql', '0009_tracking_guess_limit.sql', '0010_default_cashboxes.sql', '0011_finance_drilldown.sql', '0012_spec_completion.sql', '0013_tracking_ambiguous.sql', '0014_technicians.sql', '0015_offline_backup.sql', '0016_shop_identity.sql', '0017_growth.sql', '0018_account_state.sql', '0019_extras.sql', '0020_admin_paging.sql', '0021_spec_rules.sql', '0022_security_review.sql', '0023_restore.sql', '0024_signout.sql', '0025_integrity.sql', '0026_edit_delete.sql', '0027_inventory.sql', '0028_opening.sql', '0029_partners.sql', '0030_party_links.sql', '0031_partner_capital.sql', '0032_lists.sql', '0033_assistant.sql', '0034_branches.sql', '0035_lists_everywhere.sql', '0036_roles.sql', '0037_item_details.sql', '0038_roles_grant.sql', '0039_payment_plans.sql', '0040_branch_books.sql', '0041_analytics.sql', '0042_app_brand.sql', '0043_printing.sql', '0044_capture.sql', '0045_checklists.sql', '0046_master.sql', '0047_mfa.sql', '0048_used.sql', '0049_commissions.sql', '0050_insights.sql', '0051_demo.sql', '0052_catalog.sql', '0053_portal.sql', '0054_telegram.sql', '0055_eta_placeholder.sql', '0056_branch_features.sql', '0057_categories.sql', '0058_web_push.sql', '0059_counters_branch.sql', '0060_sale_lines.sql', '0061_attendance.sql', '0062_vat.sql', '0063_cheques.sql', '0064_day_report.sql', '0065_cheque_pending.sql', '0066_commission_net.sql', '0067_idem_lock.sql', '0068_stock_adjust.sql', '0069_sale_errors.sql', '0070_perm_matrix.sql', '0071_device_children.sql', '0072_sale_line_return.sql', '0073_shop_extras.sql']) v where v not in (select version from public.app_migrations);
  select max(version) into later_present from public.app_migrations where first_missing is not null and version > first_missing;
  if later_present is not null then raise exception 'E_UPGRADE_GAP: % موجود، بس % ناقص قبله. ابعت الرسالة دي للمطوّر.', later_present, first_missing; end if;
end $chk$;

-- 2) الأجزاء اللي قبل الجزء ده لازم تكون اتطبقت
do $ord$
declare
  files text[] := array['0001_phase1.sql', '0002_storage.sql', '0003_shop_profile_realtime.sql', '0004_error_codes.sql', '0005_device_passcode.sql', '0006_invite_name.sql', '0007_phase2_customer.sql', '0008_ledger.sql', '0009_tracking_guess_limit.sql', '0010_default_cashboxes.sql', '0011_finance_drilldown.sql', '0012_spec_completion.sql', '0013_tracking_ambiguous.sql', '0014_technicians.sql', '0015_offline_backup.sql', '0016_shop_identity.sql', '0017_growth.sql', '0018_account_state.sql', '0019_extras.sql', '0020_admin_paging.sql', '0021_spec_rules.sql', '0022_security_review.sql', '0023_restore.sql', '0024_signout.sql', '0025_integrity.sql', '0026_edit_delete.sql', '0027_inventory.sql', '0028_opening.sql', '0029_partners.sql', '0030_party_links.sql', '0031_partner_capital.sql', '0032_lists.sql', '0033_assistant.sql', '0034_branches.sql', '0035_lists_everywhere.sql', '0036_roles.sql', '0037_item_details.sql', '0038_roles_grant.sql', '0039_payment_plans.sql', '0040_branch_books.sql', '0041_analytics.sql', '0042_app_brand.sql', '0043_printing.sql', '0044_capture.sql', '0045_checklists.sql', '0046_master.sql', '0047_mfa.sql', '0048_used.sql', '0049_commissions.sql', '0050_insights.sql', '0051_demo.sql', '0052_catalog.sql', '0053_portal.sql', '0054_telegram.sql', '0055_eta_placeholder.sql', '0056_branch_features.sql', '0057_categories.sql', '0058_web_push.sql', '0059_counters_branch.sql', '0060_sale_lines.sql', '0061_attendance.sql', '0062_vat.sql', '0063_cheques.sql', '0064_day_report.sql', '0065_cheque_pending.sql', '0066_commission_net.sql', '0067_idem_lock.sql', '0068_stock_adjust.sql', '0069_sale_errors.sql', '0070_perm_matrix.sql', '0071_device_children.sql', '0072_sale_line_return.sql', '0073_shop_extras.sql'];
  parts int[] := array[1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 3, 3, 3, 3, 3, 3, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 6];
  miss text;
begin
  select min(v) into miss from unnest(files) v where v < '0018_account_state.sql' and v not in (select version from public.app_migrations);
  if miss is not null then raise exception 'E_UPGRADE_ORDER: الملف % لسه ما اتطبقش. شغّل upgrade_part_%.sql الأول، وبعدين الجزء ده (2).', miss, parts[array_position(files, miss)]; end if;
end $ord$;

-- 3) ملفات الجزء 2 بالترتيب، كل ملف في transaction لوحده
-- ============================== 0018_account_state.sql ==============================
begin;
do $run$ begin
  if exists (select 1 from public.app_migrations where version = '0018_account_state.sql') then return; end if;
  execute $m0018$
-- المرحلة 6 (تكملة): حالة الحساب للواجهة
-- مدير التسويق والمحل الموقوف ملهمش محل في الصلاحيات العادية (current_shop_id فاضي)،
-- فالواجهة محتاجة تعرف هي فين: ملف المستخدم نفسه، واسم المحل، والدور، وهل المحل موقوف، وهل هو مشرف المنصة.
-- الدالة بترجّع بيانات المستخدم نفسه ومحله بس، ومفيهاش أي بيانات أجهزة أو عملاء أو فلوس.
create or replace function public.my_account() returns jsonb
language sql stable security definer set search_path = public as $$
  select jsonb_build_object(
    'profile', (select jsonb_build_object('id', p.id, 'shop_id', p.shop_id, 'full_name', p.full_name, 'email', p.email, 'role', p.role::text, 'deleted_at', p.deleted_at)
                from public.profiles p where p.id = auth.uid()),
    'shop', (select jsonb_build_object('id', s.id, 'name', s.name, 'theme', s.theme, 'locale', s.locale, 'suspended', s.suspended_at is not null)
             from public.profiles p join public.shops s on s.id = p.shop_id where p.id = auth.uid() and p.deleted_at is null),
    'is_admin', public.is_platform_admin())
$$;
revoke all on function public.my_account() from public, anon;
grant execute on function public.my_account() to authenticated;
$m0018$;
  insert into public.app_migrations(version, how) values ('0018_account_state.sql', 'applied');
  raise notice 'applied %', '0018_account_state.sql';
end $run$;
commit;

-- ============================== 0019_extras.sql ==============================
begin;
do $run$ begin
  if exists (select 1 from public.app_migrations where version = '0019_extras.sql') then return; end if;
  execute $m0019$
-- ميزات إضافية مجانية (بعد المرحلة 6). كلها إضافة فوق الموجود، ولكل واحدة مفتاح تشغيل في الإعدادات.
-- 1) أعطال جاهزة للاستلام: صاحب المحل بيكتب الأعطال المتكررة وسعرها التقريبي، والاستقبال بيختار بضغطة.
-- 2) مفاتيح التشغيل في shops.extras (صاحب المحل بس بيعدّلها، من سياسة shops_update الموجودة).
-- مفيش أي بيانات عملاء هنا.

alter table public.shops add column if not exists extras jsonb not null
  default '{"quick_issues": true, "day_summary": true, "auto_print": false}'::jsonb;

create table public.issue_presets (
  id uuid primary key,
  shop_id uuid not null references public.shops(id),
  label text not null check (length(trim(label)) between 1 and 60),
  issue text not null check (length(trim(issue)) between 1 and 300),
  est_cost integer check (est_cost is null or est_cost between 0 and 100000000), -- بالقروش
  sort integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);
create index issue_presets_shop on public.issue_presets(shop_id, sort) where deleted_at is null;
alter table public.issue_presets enable row level security;
revoke all on public.issue_presets from public, anon, authenticated;
create trigger set_updated_at before update on public.issue_presets for each row execute function public.tg_set_updated_at();
create trigger block_delete before delete on public.issue_presets for each row execute function public.tg_block_delete();
create trigger a_force_shop_id before insert or update on public.issue_presets for each row execute function public.tg_force_shop_id();
create trigger zz_audit after insert or update on public.issue_presets for each row execute function public.tg_audit();

-- الاستقبال وصاحب المحل بيقروا (الفني مش محتاجها، وفيها أسعار)، وصاحب المحل بس بيكتب
create policy presets_select on public.issue_presets for select to authenticated
  using (shop_id = public.current_shop_id() and public.current_app_role() in ('owner', 'reception'));
create policy presets_insert on public.issue_presets for insert to authenticated
  with check (shop_id = public.current_shop_id() and public.current_app_role() = 'owner');
create policy presets_update on public.issue_presets for update to authenticated
  using (shop_id = public.current_shop_id() and public.current_app_role() = 'owner')
  with check (shop_id = public.current_shop_id());
grant select, insert, update on public.issue_presets to authenticated;

-- النسخة الاحتياطية: كانت ناقصة جداول المرحلة 6 (الفيديوهات والتقييمات)، ودلوقتي فيها كمان الأعطال الجاهزة
create or replace function public.backup_snapshot(p_shop uuid) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare
  res jsonb := jsonb_build_object('format', 'warsha-backup', 'version', 1, 'generated_at', now(), 'shop_id', p_shop);
  t text;
  rows jsonb;
begin
  foreach t in array array['shops', 'shop_branding', 'profiles', 'customers', 'devices', 'device_costs', 'status_log', 'device_notes', 'device_photos', 'device_checks',
                           'quote_decisions', 'message_templates', 'message_log', 'accounts', 'journal_entries', 'journal_lines', 'payments', 'drawer_closings',
                           'suppliers', 'items', 'stock_moves', 'purchases', 'labor_rates', 'specialties', 'staff_specialties', 'routes', 'repair_steps',
                           'repair_videos', 'device_ratings', 'issue_presets', 'audit_log'] loop
    execute format('select coalesce(jsonb_agg(to_jsonb(x)), ''[]''::jsonb) from public.%I x where x.shop_id = $1', t) into rows using p_shop;
    res := res || jsonb_build_object(t, rows);
  end loop;
  select coalesce(jsonb_agg(jsonb_build_object('device_id', device_id, 'kind', kind, 'erased_at', erased_at)), '[]'::jsonb)
    into rows from public.device_passcodes where shop_id = p_shop;
  return res || jsonb_build_object('device_passcodes', rows);
end $$;
revoke execute on function public.backup_snapshot(uuid) from public, anon, authenticated;
$m0019$;
  insert into public.app_migrations(version, how) values ('0019_extras.sql', 'applied');
  raise notice 'applied %', '0019_extras.sql';
end $run$;
commit;

-- ============================== 0020_admin_paging.sql ==============================
begin;
do $run$ begin
  if exists (select 1 from public.app_migrations where version = '0020_admin_paging.sql') then return; end if;
  execute $m0020$
-- لوحة المشرف: المحلات على صفحات (50 في المرة) وبحث بالاسم، بدل ما كلهم يتجابوا مرة واحدة.
-- ليه: Supabase بيرجّع أقصى 1000 صف في الطلب، وحساب الأجهزة والموظفين لكل المحلات مرة واحدة كان تقيل.
-- الحسابات دلوقتي بتتعمل للمحلات اللي في الصفحة بس. ومفيش أي بيانات عملاء زي الأول.
drop function if exists public.admin_shops();

create or replace function public.admin_shops(p_search text default null, p_limit integer default 50, p_offset integer default 0)
returns table(id uuid, name text, created_at timestamptz, plan text, suspended boolean, staff integer, devices integer, devices_month integer, last_activity timestamptz, total integer)
language plpgsql stable security definer set search_path = public as $$
#variable_conflict use_column
declare q text := nullif(trim(coalesce(p_search, '')), '');
begin
  if not public.is_platform_admin() then raise exception 'E_FORBIDDEN'; end if;
  return query
  with matched as (
    select s.* from public.shops s
    where q is null or s.name ilike '%' || replace(replace(replace(q, '\', '\\'), '%', '\%'), '_', '\_') || '%'
  ), page as (
    select * from matched order by created_at desc, id limit greatest(1, least(coalesce(p_limit, 50), 200)) offset greatest(0, coalesce(p_offset, 0))
  )
  select s.id, s.name, s.created_at, s.plan_code, s.suspended_at is not null,
         (select count(*)::int from public.profiles p where p.shop_id = s.id and p.deleted_at is null),
         (select count(*)::int from public.devices d where d.shop_id = s.id and d.deleted_at is null),
         (select count(*)::int from public.devices d where d.shop_id = s.id and d.received_at >= date_trunc('month', now())),
         (select max(a.created_at) from public.audit_log a where a.shop_id = s.id),
         (select count(*)::int from matched)
  from page s order by s.created_at desc, s.id;
end $$;
revoke execute on function public.admin_shops(text, integer, integer) from public, anon;
grant execute on function public.admin_shops(text, integer, integer) to authenticated;
$m0020$;
  insert into public.app_migrations(version, how) values ('0020_admin_paging.sql', 'applied');
  raise notice 'applied %', '0020_admin_paging.sql';
end $run$;
commit;

-- ============================== 0021_spec_rules.sql ==============================
begin;
do $run$ begin
  if exists (select 1 from public.app_migrations where version = '0021_spec_rules.sql') then return; end if;
  execute $m0021$
-- استكمال قواعد من المواصفات (مراجعة شاملة 2026-11-07)
-- 1) مدة ضمان لكل نوع عطل (مسار)، ولو مش متحددة بتاخد مدة الضمان بتاعة المحل.
-- 2) حذف (أرشفة) جهاز أو عميل: صاحب المحل بس. ("أي عملية حساسة زي حذف جهاز تحتاج إذن صاحب المحل")
-- 3) خصم كبير: الاستقبال ما يقدرش ينزّل التكلفة عن التقديرية بأكتر من نسبة يحددها صاحب المحل (افتراضي 20%)
--    من غير صاحب المحل. وكل تعديل في الأسعار بيتسجل في سجل النشاط زي الأول.

-- ============================================================
-- 1) الضمان لكل نوع عطل
-- ============================================================
alter table public.routes add column if not exists warranty_days integer check (warranty_days is null or warranty_days between 0 and 3650);

create or replace function public.tg_device_warranty() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if new.status = 'delivered' and old.status is distinct from 'delivered' then
    if new.warranty_days is null then
      -- مدة ضمان نوع العطل (المسار)، وإلا مدة ضمان المحل
      select coalesce(r.warranty_days, s.warranty_days) into new.warranty_days
      from public.shops s left join public.routes r on r.id = new.route_id and r.deleted_at is null
      where s.id = new.shop_id;
    end if;
    new.warranty_until := now() + make_interval(days => coalesce(new.warranty_days, 0));
  end if;
  if new.tracking_token is distinct from old.tracking_token then
    raise exception 'E_RECEIPT_IMMUTABLE';
  end if;
  return new;
end $$;

-- ============================================================
-- 2) الأرشفة (soft delete) لصاحب المحل بس
-- ============================================================
create or replace function public.tg_owner_soft_delete() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if new.deleted_at is distinct from old.deleted_at
     and auth.uid() is not null
     and coalesce(current_setting('warsha.system', true), '') <> 'on'
     and public.current_app_role() is distinct from 'owner' then
    raise exception 'E_OWNER_APPROVAL';
  end if;
  return new;
end $$;
drop trigger if exists a_owner_soft_delete on public.devices;
create trigger a_owner_soft_delete before update on public.devices for each row execute function public.tg_owner_soft_delete();
drop trigger if exists a_owner_soft_delete on public.customers;
create trigger a_owner_soft_delete before update on public.customers for each row execute function public.tg_owner_soft_delete();

-- ============================================================
-- 3) الخصم الكبير محتاج صاحب المحل
-- ============================================================
alter table public.shops add column if not exists max_discount_pct integer not null default 20 check (max_discount_pct between 0 and 100);

create or replace function public.tg_cost_discount() returns trigger
language plpgsql security definer set search_path = public as $$
declare pct integer; est integer;
begin
  if auth.uid() is null or coalesce(current_setting('warsha.system', true), '') = 'on' or public.current_app_role() = 'owner' then
    return new;
  end if;
  select max_discount_pct into pct from public.shops where id = new.shop_id;
  pct := coalesce(pct, 20);
  -- التكلفة التقديرية نفسها ما تنزلش بخصم كبير
  if tg_op = 'UPDATE' and old.estimated_cost > 0 and new.estimated_cost is distinct from old.estimated_cost
     and coalesce(new.estimated_cost, 0)::bigint * 100 < old.estimated_cost::bigint * (100 - pct) then
    raise exception 'E_OWNER_APPROVAL';
  end if;
  -- التكلفة النهائية مقارنة بالتقديرية (أعداد صحيحة بس، من غير كسور)
  est := case when tg_op = 'UPDATE' then coalesce(old.estimated_cost, new.estimated_cost) else new.estimated_cost end;
  if new.final_cost is not null and est > 0
     and (tg_op = 'INSERT' or new.final_cost is distinct from old.final_cost)
     and new.final_cost::bigint * 100 < est::bigint * (100 - pct) then
    raise exception 'E_OWNER_APPROVAL';
  end if;
  return new;
end $$;
drop trigger if exists a_cost_discount on public.device_costs;
create trigger a_cost_discount before insert or update on public.device_costs for each row execute function public.tg_cost_discount();

-- ============================================================
-- 4) تذكيرات تسويقية بموافقة العميل ("صيانة من 6 شهور")
-- ============================================================
alter table public.message_templates drop constraint if exists message_templates_key_check;
alter table public.message_templates add constraint message_templates_key_check
  check (key in ('received', 'status', 'approval', 'ready', 'reminder', 'delivered', 'debt', 'marketing'));

-- العملاء اللي وافقوا على التذكيرات، وآخر جهاز ليهم اتسلّم من 6 شهور أو أكتر (لحد سنة)،
-- وما اتبعتلهمش تذكير تسويقي من وقت التسليم ده. للاستقبال وصاحب المحل بس.
create or replace function public.marketing_due(p_days integer default 180)
returns table(device_id uuid, order_no text, brand text, model text, issue text, delivered_at timestamptz,
              customer_id uuid, customer_name text, phone text, tracking_token text)
language plpgsql stable security definer set search_path = public as $$
#variable_conflict use_column
declare s uuid := public.current_shop_id(); days integer := greatest(30, least(coalesce(p_days, 180), 720));
begin
  if public.current_app_role() not in ('owner', 'reception') then raise exception 'E_FORBIDDEN'; end if;
  return query
  with last_dev as (
    select distinct on (d.customer_id) d.*
    from public.devices d
    where d.shop_id = s and d.deleted_at is null and d.status = 'delivered' and d.delivered_at is not null
    order by d.customer_id, d.delivered_at desc
  )
  select d.id, d.order_no, d.brand, d.model, d.issue, d.delivered_at, c.id, c.name, c.phone, d.tracking_token
  from last_dev d join public.customers c on c.id = d.customer_id and c.deleted_at is null
  where c.marketing_ok
    and d.delivered_at <= now() - make_interval(days => days)
    and d.delivered_at > now() - make_interval(days => days + 365)
    and not exists (select 1 from public.message_log m where m.customer_id = c.id and m.template_key = 'marketing' and m.created_at >= d.delivered_at and m.deleted_at is null)
  order by d.delivered_at
  limit 200;
end $$;
revoke execute on function public.marketing_due(integer) from public, anon;
grant execute on function public.marketing_due(integer) to authenticated;
$m0021$;
  insert into public.app_migrations(version, how) values ('0021_spec_rules.sql', 'applied');
  raise notice 'applied %', '0021_spec_rules.sql';
end $run$;
commit;

-- ============================== 0022_security_review.sql ==============================
begin;
do $run$ begin
  if exists (select 1 from public.app_migrations where version = '0022_security_review.sql') then return; end if;
  execute $m0022$
-- المراجعة الأمنية الشاملة (2026-11-07)
-- حالة التقييم في صفحة التتبع (rating_state) كانت الدالة العامة الوحيدة من غير حد للمحاولات.
-- دلوقتي زي باقي دوال الصفحة العامة: بعد 10 محاولات غلط من نفس الجهاز في 15 دقيقة بتقفل (E_RATE_LIMIT)،
-- والرمز الغلط بيتسجل كمحاولة فاشلة. والنتيجة زي ما هي: هل يقدر يقيّم، والنجوم لو قيّم، ومفيش أي بيانات تانية.
create or replace function public.rating_state(p_token text) returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare d public.devices; k text := public.tracking_guard(null);
begin
  select * into d from public.devices where tracking_token = p_token and deleted_at is null;
  if not found then
    insert into public.tracking_attempts(client_key, order_no, success) values (k, null, false);
    return jsonb_build_object('can_rate', false);
  end if;
  return jsonb_build_object('can_rate', d.status = 'delivered' and not exists (select 1 from public.device_ratings r where r.device_id = d.id),
                            'stars', (select stars from public.device_ratings r where r.device_id = d.id));
end $$;
revoke execute on function public.rating_state(text) from public;
grant execute on function public.rating_state(text) to anon, authenticated;
$m0022$;
  insert into public.app_migrations(version, how) values ('0022_security_review.sql', 'applied');
  raise notice 'applied %', '0022_security_review.sql';
end $run$;
commit;

-- ============================== 0023_restore.sql ==============================
begin;
do $run$ begin
  if exists (select 1 from public.app_migrations where version = '0023_restore.sql') then return; end if;
  execute $m0023$
-- 0023: استرجاع نسخة احتياطية لمحل جديد فاضي (بقرار صاحب المشروع 2026-11-07)
--
-- - الاسترجاع لمحل جديد فاضي بس (في نفس مشروع Supabase أو مشروع جديد). ممنوع على محل فيه شغل.
-- - كل صف بياخد id جديد، وكل الروابط بين الجداول بتتظبط على الـ ids الجديدة، فمفيش تعارض مع المحل الأصلي
--   لو لسه موجود في نفس المشروع.
-- - الحسابات والمسارات والتخصصات وقوالب الرسايل اللي اتعملت مع التسجيل بتتطابق بالكود، وبتاخد قيم النسخة.
-- - الموظفين القدام بيرجعوا "موظفين سابقين" (بأساميهم، عشان سجل مين عمل إيه يفضل)، ولازم يتعزموا من جديد.
--   صاحب المحل في النسخة = صاحب المحل اللي بيسترجع.
-- - القيود بترجع زي ما هي (ما بتتعدلش): القيد المتوازن بيتأكد عند الحفظ، ورصيد كل حساب لازم يطابق النسخة
--   بالظبط، وإلا الاسترجاع كله بيتلغي ومحدش بيتغيّر.
-- - مش جوه النسخة أصلًا: ملفات الصور (Storage)، وأسرار أقفال الأجهزة، وحسابات الدخول.

-- علامة الاسترجاع: شغالة جوه restore_backup بس (set_config محلي للـ transaction)
create or replace function public.restoring() returns boolean
language sql stable set search_path = public as $$
  select coalesce(current_setting('warsha.restore', true), '') = 'on'
$$;

-- التريجرات اللي كانت هتغيّر الصفوف الراجعة (رقم الطلب، والحالة، والكاتب، وسجل الحالات، وحد الخطة، وسجل النشاط):
-- نفس تعريفها بالظبط، وزيادة سطر واحد في الأول بيسيب الصف زي ما هو وقت الاسترجاع بس.
CREATE OR REPLACE FUNCTION public.tg_audit()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  act text;
  shop uuid;
begin
  -- وقت الاسترجاع: الصف راجع زي ما هو من النسخة (src: 0023)
  if public.restoring() then return new; end if;
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
end $function$;

CREATE OR REPLACE FUNCTION public.tg_check_author()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  -- وقت الاسترجاع: الصف راجع زي ما هو من النسخة (src: 0023)
  if public.restoring() then return new; end if;
  new.checked_by := auth.uid();
  return new;
end $function$;

CREATE OR REPLACE FUNCTION public.tg_note_author()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  -- وقت الاسترجاع: الصف راجع زي ما هو من النسخة (src: 0023)
  if public.restoring() then return new; end if;
  if tg_op = 'INSERT' then
    new.author_id := auth.uid();
  elsif new.body is distinct from old.body or new.author_id is distinct from old.author_id then
    raise exception 'E_NOTE_IMMUTABLE';
  end if;
  return new;
end $function$;

CREATE OR REPLACE FUNCTION public.tg_device_defaults()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  y integer := extract(year from (now() at time zone 'Africa/Cairo'))::integer;
  n integer;
begin
  -- وقت الاسترجاع: الصف راجع زي ما هو من النسخة (src: 0023)
  if public.restoring() then return new; end if;
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
end $function$;

CREATE OR REPLACE FUNCTION public.tg_device_status_log()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  -- وقت الاسترجاع: الصف راجع زي ما هو من النسخة (src: 0023)
  if public.restoring() then return null; end if;
  if tg_op = 'INSERT' then
    insert into public.status_log(shop_id, device_id, old_status, new_status, changed_by)
    values (new.shop_id, new.id, null, new.status, auth.uid());
  elsif new.status is distinct from old.status then
    insert into public.status_log(shop_id, device_id, old_status, new_status, changed_by)
    values (new.shop_id, new.id, old.status, new.status, auth.uid());
  end if;
  return null;
end $function$;

CREATE OR REPLACE FUNCTION public.tg_plan_devices()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare pl public.plans := public.shop_plan(new.shop_id); n int;
begin
  -- وقت الاسترجاع: الصف راجع زي ما هو من النسخة (src: 0023)
  if public.restoring() then return new; end if;
  if pl.max_devices_month is not null then
    select count(*) into n from public.devices
     where shop_id = new.shop_id and received_at >= date_trunc('month', now() at time zone 'Africa/Cairo') at time zone 'Africa/Cairo';
    if n >= pl.max_devices_month then raise exception 'E_PLAN_LIMIT'; end if;
  end if;
  return new;
end $function$;

-- ============================================================
-- الاسترجاع
-- ============================================================
create or replace function public.restore_remap(j jsonb) returns jsonb
language plpgsql stable set search_path = public, pg_temp as $$
declare res jsonb;
begin
  -- أي قيمة uuid ليها id جديد بتتبدل بيه (الـ ids والروابط كلها). جدول _rmap مؤقت جوه restore_backup
  select coalesce(jsonb_object_agg(k, case
      when jsonb_typeof(v) = 'string' and (v #>> '{}') ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
        then coalesce((select to_jsonb(m.new::text) from _rmap m where m.old = (v #>> '{}')::uuid), v)
      else v end), '{}'::jsonb)
    into res
  from jsonb_each(j) e(k, v);
  return res;
end $$;

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
  tabs text[] := array['profiles', 'shop_branding', 'accounts', 'customers', 'suppliers', 'specialties', 'staff_specialties', 'routes', 'labor_rates',
                       'issue_presets', 'message_templates', 'items', 'devices', 'device_costs', 'status_log', 'device_notes', 'device_checks',
                       'quote_decisions', 'repair_steps', 'repair_videos', 'device_ratings', 'journal_entries', 'journal_lines', 'payments',
                       'purchases', 'stock_moves', 'drawer_closings', 'message_log', 'audit_log'];
  -- الجداول دي ليها نسخة اتعملت مع التسجيل: بتتطابق بالكود (أو المفتاح) وبتاخد قيم النسخة
  keyed text[] := array['accounts', 'routes', 'specialties', 'message_templates', 'labor_rates', 'shop_branding'];
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
  insert into public.order_counters(shop_id, year, last_value)
  select s, split_part(order_no, '-', 1)::int, max(split_part(order_no, '-', 2)::int)
    from public.devices where shop_id = s and order_no ~ '^\d{4}-\d+$' group by 2
  on conflict (shop_id, year) do update set last_value = greatest(public.order_counters.last_value, excluded.last_value);

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
revoke execute on function public.restore_backup(jsonb) from public, anon;
grant execute on function public.restore_backup(jsonb) to authenticated;
revoke execute on function public.restore_remap(jsonb) from public, anon, authenticated;
revoke execute on function public.restoring() from public, anon;
-- (قراءة بس: صح أو غلط. التريجرات بتستخدمها، ومحدش يقدر يفعّل العلامة من بره restore_backup)
grant execute on function public.restoring() to authenticated;
$m0023$;
  insert into public.app_migrations(version, how) values ('0023_restore.sql', 'applied');
  raise notice 'applied %', '0023_restore.sql';
end $run$;
commit;

-- ============================== 0024_signout.sql ==============================
begin;
do $run$ begin
  if exists (select 1 from public.app_migrations where version = '0024_signout.sql') then return; end if;
  execute $m0024$
-- 0024: الخروج من غير أخطاء لما الجلسة تكون منتهية أو المستخدم اتحذف
--
-- الواجهة كانت بتنادي /auth/v1/logout، وده بيرجع 403 لو المستخدم اتحذف أو الجلسة اتلغت من السيرفر،
-- والمتصفح بيكتب الخطأ في الـ console. دلوقتي الواجهة بتنادي الدالة دي (بترجع نجاح دايمًا)، وبعدها بتمسح
-- الجلسة من الجهاز بس.
--
-- end_my_session: بتلغي الجلسة الحالية بس (والـ refresh tokens بتاعتها) لو لسه موجودة. لو مش موجودة: مفيش حاجة.
create or replace function public.end_my_session() returns void
language plpgsql security definer set search_path = public as $$
declare sid uuid;
begin
  begin
    sid := nullif(auth.jwt() ->> 'session_id', '')::uuid;
  exception when others then
    sid := null;
  end;
  if sid is null or auth.uid() is null then return; end if;
  begin
    delete from auth.sessions where id = sid and user_id = auth.uid();
  exception when insufficient_privilege or undefined_table then
    -- لو صلاحيات المشروع ما بتسمحش: الجلسة بتتمسح من الجهاز بس (زي "الخروج من الجهاز ده")
    null;
  end;
end $$;
revoke execute on function public.end_my_session() from public, anon;
grant execute on function public.end_my_session() to authenticated;
$m0024$;
  insert into public.app_migrations(version, how) values ('0024_signout.sql', 'applied');
  raise notice 'applied %', '0024_signout.sql';
end $run$;
commit;

-- ============================== 0025_integrity.sql ==============================
begin;
do $run$ begin
  if exists (select 1 from public.app_migrations where version = '0025_integrity.sql') then return; end if;
  execute $m0025$
-- 0025: دقة الحسابات
--
-- 1) خطأ اتلقى: إلغاء (قيد عكسي) لشراء بعد ما جزء من البضاعة اتصرف ممكن يسيب الصنف بكمية صفر وقيمة، أو بقيمة بالسالب
--    (مثال: 5 بـ 100 و10 بـ 1، صرف 9، إلغاء الشراء الأول = وحدة واحدة بقيمة -296 قرش). وده بيخلّي تكلفة أي صرف بعد كده غلط.
--    الحل: بعد أي إلغاء فيه مخزون، الصنف بيتسوّى: الفرق بيروح "فرق تكلفة" (تكلفة البضاعة) بقيد متوازن، والقيمة بتبقى صح.
-- 2) فحص سلامة تلقائي (integrity_report) لصاحب المحل: أي فرق بيظهر بالمكان والمبلغ.

alter table public.journal_entries drop constraint if exists journal_entries_source_type_check;
alter table public.journal_entries add constraint journal_entries_source_type_check check (source_type = any (array[
  'payment', 'delivery', 'purchase', 'supplier_payment', 'part_use', 'sale', 'expense', 'salary', 'salary_payment', 'advance',
  'advance_settle', 'capital', 'drawing', 'transfer', 'drawer_close', 'reversal', 'cost_adjust']));
-- حركة تسوية القيمة: كمية صفر وقيمة
alter table public.stock_moves drop constraint if exists stock_moves_qty_check;
alter table public.stock_moves add constraint stock_moves_qty_check check (qty <> 0 or value <> 0);

-- تسوية صنف: لو كميته صفر وفيه قيمة باقية، أو قيمته بالسالب، الفرق بيروح تكلفة البضاعة
create or replace function public.ledger_settle_item(p_item uuid, p_device uuid default null) returns void
language plpgsql security definer set search_path = public as $$
declare st record; v bigint; e uuid;
begin
  select * into st from public.item_stock(p_item);
  if not ((st.qty = 0 and st.value <> 0) or (st.qty > 0 and st.value < 0)) then return; end if;
  v := st.value;
  e := public.ledger_post('cost_adjust', p_item, 'فرق تكلفة مخزون',
    case when v > 0 then jsonb_build_array(public.ledger_line(public.ledger_acc('cogs'), v, 0), public.ledger_line(public.ledger_acc('inventory'), 0, v))
         else jsonb_build_array(public.ledger_line(public.ledger_acc('inventory'), -v, 0), public.ledger_line(public.ledger_acc('cogs'), 0, -v)) end,
    p_device);
  insert into public.stock_moves(shop_id, item_id, entry_id, qty, value) values (public.current_shop_id(), p_item, e, 0, -v);
end $$;
revoke execute on function public.ledger_settle_item(uuid, uuid) from public, anon, authenticated;

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
  -- (0025) بعد إلغاء حركة مخزون: لو الصنف بقى كميته صفر وفيه قيمة، أو قيمته بالسالب، الفرق بيروح "فرق تكلفة"
  for mv in select distinct item_id from public.stock_moves where entry_id = o.id loop
    perform public.ledger_settle_item(mv.item_id, o.device_id);
  end loop;
  insert into public.audit_log(shop_id, actor_id, action, entity, entity_id, before, after)
  values (o.shop_id, auth.uid(), 'reverse_entry', 'journal_entries', o.id, to_jsonb(o), jsonb_build_object('reversal_id', e, 'reason', p_reason));
  return e;
end $function$;

-- ============================================================
-- فحص السلامة
-- ============================================================
create or replace function public.integrity_report() returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare s uuid := public.current_shop_id(); out jsonb := '[]'::jsonb; r record; inv bigint; mv bigint;
begin
  perform public.ledger_require(array['owner']::public.app_role[]);
  -- 1) قيد مش متوازن، أو ناقص طرف (أقل من سطرين)
  for r in select e.id, e.entry_no, coalesce(sum(l.debit), 0) - coalesce(sum(l.credit), 0) diff, count(l.id) n
           from public.journal_entries e left join public.journal_lines l on l.entry_id = e.id
           where e.shop_id = s group by e.id having coalesce(sum(l.debit), 0) <> coalesce(sum(l.credit), 0) or count(l.id) < 2 loop
    out := out || jsonb_build_array(jsonb_build_object('kind', case when r.n < 2 then 'entry_missing_side' else 'entry_unbalanced' end, 'amount', abs(r.diff), 'entry_id', r.id, 'entry_no', r.entry_no));
  end loop;
  -- 2) قيمة المخزون في الدفتر = مجموع حركات المخزون
  select coalesce(sum(l.debit - l.credit), 0) into inv from public.journal_lines l join public.accounts a on a.id = l.account_id where a.shop_id = s and a.kind = 'inventory';
  select coalesce(sum(m.value), 0) into mv from public.stock_moves m where m.shop_id = s;
  if inv <> mv then out := out || jsonb_build_array(jsonb_build_object('kind', 'inventory_ledger', 'amount', abs(inv - mv), 'ledger', inv, 'stock', mv)); end if;
  -- 3) كل صنف: الكمية مش بالسالب، ومفيش قيمة من غير كمية، ومفيش قيمة بالسالب
  for r in select i.id, i.name, coalesce(sum(m.qty), 0) q, coalesce(sum(m.value), 0) v from public.items i left join public.stock_moves m on m.item_id = i.id
           where i.shop_id = s group by i.id having coalesce(sum(m.qty), 0) < 0 or (coalesce(sum(m.qty), 0) = 0 and coalesce(sum(m.value), 0) <> 0) or coalesce(sum(m.value), 0) < 0 loop
    out := out || jsonb_build_array(jsonb_build_object('kind', 'item_value', 'amount', abs(r.v), 'item_id', r.id, 'item', r.name, 'qty', r.q, 'value', r.v));
  end loop;
  -- 4) كل حركة مخزون بقيمتها في قيد على حساب المخزون بنفس المبلغ
  for r in select m.entry_id, e.entry_no, sum(m.value) mvv,
                  (select coalesce(sum(l.debit - l.credit), 0) from public.journal_lines l join public.accounts a on a.id = l.account_id where l.entry_id = m.entry_id and a.kind = 'inventory') lv
           from public.stock_moves m join public.journal_entries e on e.id = m.entry_id where m.shop_id = s group by m.entry_id, e.entry_no loop
    if r.mvv <> r.lv then out := out || jsonb_build_array(jsonb_build_object('kind', 'stock_entry', 'amount', abs(r.mvv - r.lv), 'entry_id', r.entry_id, 'entry_no', r.entry_no)); end if;
  end loop;
  -- 5) كل دفعة مبلغها = المبلغ اللي دخل الخزنة في قيدها
  for r in select p.id, p.amount, p.entry_id, e.entry_no,
                  (select coalesce(sum(l.debit), 0) from public.journal_lines l join public.accounts a on a.id = l.account_id where l.entry_id = p.entry_id and a.kind = 'cash') cash
           from public.payments p join public.journal_entries e on e.id = p.entry_id where p.shop_id = s loop
    if r.cash <> r.amount then out := out || jsonb_build_array(jsonb_build_object('kind', 'payment_entry', 'amount', abs(r.cash - r.amount), 'entry_id', r.entry_id, 'entry_no', r.entry_no)); end if;
  end loop;
  -- 6) حسابات العملاء والموردين والموظفين: كل سطر عليه طرف (عشان رصيد كل واحد = كشف حسابه)
  for r in select l.entry_id, e.entry_no, sum(l.debit + l.credit) amt from public.journal_lines l join public.accounts a on a.id = l.account_id join public.journal_entries e on e.id = l.entry_id
           where l.shop_id = s and a.kind in ('receivable', 'payable', 'advances', 'salaries') and l.party_id is null group by l.entry_id, e.entry_no loop
    out := out || jsonb_build_array(jsonb_build_object('kind', 'party_missing', 'amount', r.amt, 'entry_id', r.entry_id, 'entry_no', r.entry_no));
  end loop;
  -- 7) كل سطر في نفس محل القيد
  for r in select l.entry_id, e.entry_no from public.journal_lines l join public.journal_entries e on e.id = l.entry_id where e.shop_id = s and l.shop_id <> e.shop_id group by 1, 2 loop
    out := out || jsonb_build_array(jsonb_build_object('kind', 'shop_mismatch', 'amount', 0, 'entry_id', r.entry_id, 'entry_no', r.entry_no));
  end loop;
  return out;
end $$;
revoke execute on function public.integrity_report() from public, anon;
grant execute on function public.integrity_report() to authenticated;
$m0025$;
  insert into public.app_migrations(version, how) values ('0025_integrity.sql', 'applied');
  raise notice 'applied %', '0025_integrity.sql';
end $run$;
commit;

-- ============================== 0026_edit_delete.sql ==============================
begin;
do $run$ begin
  if exists (select 1 from public.app_migrations where version = '0026_edit_delete.sql') then return; end if;
  execute $m0026$
-- ============================================================
-- 0026: تعديل وحذف في كل حاجة (البند 2)
-- - الفلوس والمخزون: القيد الأصلي ما بيتلمسش أبدًا. "الحذف" = قيد عكسي، و"التعديل" = قيد عكسي + قيد جديد
--   في نفس الـ transaction (لو أي جزء فشل، ولا حاجة بتتسجل). والسبب إجباري.
-- - الصلاحية: صاحب المحل، أو موظف صاحب المحل اداله إذن "تصحيح العمليات" (profiles.can_correct).
-- - العملاء والموردين والأصناف والأجهزة: حذف ناعم (deleted_at) بس، ومن غير ما يبوّظ أي رصيد:
--   العميل أو المورد اللي عليه أو ليه فلوس ما بيتحذفش، والصنف اللي في المخزون ما بيتحذفش،
--   والجهاز اللي عليه فلوس ما بيتحذفش. وكل ده بيتسجل في سجل النشاط بالسبب.
-- ============================================================

-- 1) إذن التصحيح لموظف
alter table public.profiles add column if not exists can_correct boolean not null default false;

create or replace function public.can_correct() returns boolean
language sql stable security definer set search_path = public as $$
  select public.current_app_role() = 'owner'
      or coalesce((select p.can_correct from public.profiles p where p.id = auth.uid() and p.deleted_at is null), false)
$$;
revoke execute on function public.can_correct() from public, anon;
grant execute on function public.can_correct() to authenticated;

create or replace function public.set_can_correct(p_user uuid, p_on boolean) returns void
language plpgsql security definer set search_path = public as $$
declare o public.profiles;
begin
  perform public.ledger_require(array['owner']::public.app_role[]);
  select * into o from public.profiles where id = p_user and shop_id = public.current_shop_id();
  if not found then raise exception 'E_NOT_FOUND'; end if;
  if o.role = 'owner' then raise exception 'E_BAD_INPUT'; end if;
  perform set_config('warsha.grant', '1', true);
  update public.profiles set can_correct = p_on, updated_at = now() where id = p_user;
  perform set_config('warsha.grant', '', true);
  insert into public.audit_log(shop_id, actor_id, action, entity, entity_id, before, after)
  values (o.shop_id, auth.uid(), 'set_can_correct', 'profiles', o.id, jsonb_build_object('can_correct', o.can_correct), jsonb_build_object('can_correct', p_on));
end $$;
revoke execute on function public.set_can_correct(uuid, boolean) from public, anon;
grant execute on function public.set_can_correct(uuid, boolean) to authenticated;

-- الإذن ما بيتغيرش غير من set_can_correct (ولا حتى الموظف لنفسه)
create or replace function public.tg_profile_grant_guard() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if new.can_correct is distinct from old.can_correct and coalesce(current_setting('warsha.grant', true), '') <> '1' and not public.restoring() then
    raise exception 'E_FORBIDDEN';
  end if;
  return new;
end $$;
drop trigger if exists profile_grant_guard on public.profiles;
create trigger profile_grant_guard before update on public.profiles for each row execute function public.tg_profile_grant_guard();

-- 2) الإلغاء بقيد عكسي: صاحب المحل أو اللي معاه الإذن (نفس جسم 0025 بالظبط، والصلاحية بس اللي اتغيرت)
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
  e := public.ledger_post('reversal', o.source_id, p_reason, lines, o.device_id, null, o.id);
  for mv in select * from public.stock_moves where entry_id = o.id loop
    perform 1 from public.items where id = mv.item_id for update;
    if (select coalesce(sum(qty), 0) from public.stock_moves where item_id = mv.item_id) - mv.qty < 0 then
      raise exception 'E_STOCK';
    end if;
    insert into public.stock_moves(shop_id, item_id, entry_id, qty, value) values (mv.shop_id, mv.item_id, e, -mv.qty, -mv.value);
  end loop;
  for mv in select distinct item_id from public.stock_moves where entry_id = o.id loop
    perform public.ledger_settle_item(mv.item_id, o.device_id);
  end loop;
  insert into public.audit_log(shop_id, actor_id, action, entity, entity_id, before, after)
  values (o.shop_id, auth.uid(), 'reverse_entry', 'journal_entries', o.id, to_jsonb(o), jsonb_build_object('reversal_id', e, 'reason', p_reason));
  return e;
end $function$;

-- 3) بيانات العملية عشان شاشة التعديل تتملي بيها (من القيد نفسه)
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
    select jsonb_agg(jsonb_build_object('item', x.item_id, 'qty', x.q,
             'price', case when x.n = 1 then rev / x.q else coalesce(i.sale_price, 0) end) order by x.first)
      into ls
    from (select m.item_id, -sum(m.qty) q, count(*) over () n, min(m.created_at) first from public.stock_moves m where m.entry_id = o.id group by m.item_id) x
    join public.items i on i.id = x.item_id;
    res := res || jsonb_build_object('customer', cust, 'cashbox', cash_in, 'lines', coalesce(ls, '[]'::jsonb));
  end if;
  return res;
end $$;
revoke execute on function public.entry_args(uuid) from public, anon;
grant execute on function public.entry_args(uuid) to authenticated;

-- 4) التعديل: قيد عكسي للأصل + نفس نوع العملية بالبيانات الجديدة، في نفس الـ transaction
-- p_new.id = id العملية الجديدة (من التطبيق). لو نفس التعديل اتبعت مرتين (مزامنة)، بيرجع نفس النتيجة من غير تكرار.
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
revoke execute on function public.edit_entry(uuid, text, jsonb) from public, anon;
grant execute on function public.edit_entry(uuid, text, jsonb) to authenticated;

-- 5) الحذف الناعم الآمن: عميل، مورد، صنف، جهاز
create or replace function public.soft_delete(p_kind text, p_id uuid, p_reason text default null) returns void
language plpgsql security definer set search_path = public as $$
declare s uuid := public.current_shop_id(); before jsonb; tbl text;
begin
  if public.current_app_role() is null or not public.can_correct() then raise exception 'E_FORBIDDEN'; end if;
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
revoke execute on function public.soft_delete(text, uuid, text) from public, anon;
grant execute on function public.soft_delete(text, uuid, text) to authenticated;

-- ملاحظة: الأرشفة المباشرة (update deleted_at) لسه لصاحب المحل بس زي قاعدة 0021 (tg_owner_soft_delete).
-- soft_delete بتعدّي القاعدة دي للموظف اللي معاه إذن التصحيح، بعد ما تتأكد إن الحذف مش هيبوّظ أي رصيد.
drop trigger if exists soft_delete_guard on public.customers;
drop trigger if exists soft_delete_guard on public.suppliers;
drop trigger if exists soft_delete_guard on public.items;
drop trigger if exists soft_delete_guard on public.devices;
drop function if exists public.tg_soft_delete_guard();
$m0026$;
  insert into public.app_migrations(version, how) values ('0026_edit_delete.sql', 'applied');
  raise notice 'applied %', '0026_edit_delete.sql';
end $run$;
commit;

-- ============================== 0027_inventory.sql ==============================
begin;
do $run$ begin
  if exists (select 1 from public.app_migrations where version = '0027_inventory.sql') then return; end if;
  execute $m0027$
-- ============================================================
-- 0027: المخزون قسم مستقل بحساباته (البند 3)
-- كل عملية هنا قيد متوازن واحد جوه transaction، بالقروش، وبالمتوسط المرجّح، وما بتعديش المخزون بالسالب:
-- - الهالك (write_off): مصروف "هالك" مدين، والمخزون دائن بالتكلفة. والسبب إجباري.
-- - مرتجع للمورد (supplier_return): المخزون بيقل بالتكلفة، وحساب المورد بيقل (أو استرداد كاش) بالمبلغ المتفق عليه،
--   والفرق (لو المورد رجّع أقل أو أكتر من التكلفة) بيروح تكلفة البضاعة.
-- - مرتجع من العميل (sale_return): الإيراد بيقل بالمبلغ المرتجع، والفلوس بترجع من خزنة (أو رصيد للعميل).
--   والقطعة يا إما بترجع المخزون بتكلفتها، يا إما بتتسجل هالك لو بايظة.
-- - "ربط المخزون بالصيانة" (shops.extras.link_inventory، الافتراضي مربوط): لو مش مربوط،
--   القطعة بتتكتب على الجهاز يدوي بتكلفتها (device_manual_part) من غير ما المخزون يتأثر، والربح صح في الحالتين.
-- - الأصناف: تصنيف، وباركود (مش متكرر في نفس المحل)، وصورة في Storage تحت shop_id.
-- ============================================================

alter table public.journal_entries drop constraint if exists journal_entries_source_type_check;
alter table public.journal_entries add constraint journal_entries_source_type_check check (source_type = any (array[
  'payment', 'delivery', 'purchase', 'supplier_payment', 'part_use', 'sale', 'expense', 'salary', 'salary_payment', 'advance',
  'advance_settle', 'capital', 'drawing', 'transfer', 'drawer_close', 'reversal', 'cost_adjust',
  'write_off', 'supplier_return', 'sale_return']));

-- حساب "هالك" لكل محل (نوعه تكلفة بضاعة عشان ما يظهرش في قايمة المصروفات العادية)
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
    ('cogs', 'expense', 'cogs'), ('shortage', 'expense', 'shortage'), ('wastage', 'expense', 'cogs'),
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

-- الأصناف: تصنيف وباركود وصورة
alter table public.items add column if not exists category text check (category is null or length(category) <= 60);
alter table public.items add column if not exists barcode text check (barcode is null or barcode ~ '^[0-9A-Za-z-]{4,32}$');
alter table public.items add column if not exists image_path text;
create unique index if not exists items_barcode_unique on public.items(shop_id, barcode) where barcode is not null and deleted_at is null;

-- صور الأصناف: خاصة بكل محل
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('item-images', 'item-images', false, 2097152, array['image/png', 'image/jpeg', 'image/webp'])
on conflict (id) do nothing;
do $$
begin
  begin drop policy if exists item_images_read on storage.objects; exception when others then null; end;
  begin drop policy if exists item_images_upload on storage.objects; exception when others then null; end;
  begin drop policy if exists item_images_update on storage.objects; exception when others then null; end;
end $$;
create policy item_images_read on storage.objects for select to authenticated
  using (bucket_id = 'item-images' and (storage.foldername(name))[1] = public.current_shop_id()::text);
create policy item_images_upload on storage.objects for insert to authenticated
  with check (bucket_id = 'item-images' and (storage.foldername(name))[1] = public.current_shop_id()::text and public.current_app_role() = 'owner');
create policy item_images_update on storage.objects for update to authenticated
  using (bucket_id = 'item-images' and (storage.foldername(name))[1] = public.current_shop_id()::text and public.current_app_role() = 'owner');

-- رصيد صنف (كمية وقيمة) + آخر تكلفة شراء (لو المخزون خلص، عشان المرتجع يرجع بتكلفة معقولة)
create or replace function public.item_last_cost(p_item uuid) returns bigint
language sql stable security definer set search_path = public as $$
  select coalesce(
    (select case when sum(qty) > 0 then sum(value) / sum(qty) end from public.stock_moves where item_id = p_item having sum(qty) > 0),
    (select m.value / m.qty from public.stock_moves m join public.journal_entries e on e.id = m.entry_id
      where m.item_id = p_item and m.qty > 0 and e.source_type = 'purchase' order by m.created_at desc limit 1),
    0)::bigint
$$;
revoke execute on function public.item_last_cost(uuid) from public, anon, authenticated;

-- ---------- الهالك ----------
create or replace function public.write_off(p_id uuid, p_item uuid, p_qty integer, p_reason text) returns uuid
language plpgsql security definer set search_path = public as $$
declare s uuid := public.current_shop_id(); e uuid; cost bigint;
begin
  perform public.ledger_require(array['owner']::public.app_role[]);
  e := public.ledger_idem(p_id);
  if e is not null then return e; end if;
  if nullif(trim(p_reason), '') is null then raise exception 'E_REASON_REQUIRED'; end if;
  if p_qty is null or p_qty <= 0 then raise exception 'E_BAD_AMOUNT'; end if;
  e := gen_random_uuid();
  insert into public.journal_entries(id, shop_id, source_type, source_id, memo, idem_key, created_by)
  values (e, s, 'write_off', p_item, trim(p_reason), p_id, auth.uid());
  cost := public.ledger_issue(p_item, p_qty, e);
  if cost > 0 then
    insert into public.journal_lines(shop_id, entry_id, account_id, debit, credit) values
      (s, e, public.ledger_acc('wastage'), cost, 0), (s, e, public.ledger_acc('inventory'), 0, cost);
  else
    -- صنف قيمته صفر: مفيش قيد يتعمل بطرفين، فبيترفض (والرسالة بتقول إن المبلغ غلط)
    raise exception 'E_BAD_AMOUNT';
  end if;
  return e;
end $$;

-- ---------- مرتجع للمورد ----------
-- p_refund: اللي المورد هيرجّعه (أو هيخصمه من حسابه). p_cashbox فاضي = بيتخصم من حساب المورد
create or replace function public.supplier_return(p_id uuid, p_supplier uuid, p_item uuid, p_qty integer, p_refund bigint, p_cashbox uuid default null, p_reason text default null) returns uuid
language plpgsql security definer set search_path = public as $$
declare s uuid := public.current_shop_id(); e uuid; cost bigint; diff bigint; cb uuid;
begin
  perform public.ledger_require(array['owner']::public.app_role[]);
  e := public.ledger_idem(p_id);
  if e is not null then return e; end if;
  if nullif(trim(p_reason), '') is null then raise exception 'E_REASON_REQUIRED'; end if;
  if p_qty is null or p_qty <= 0 or p_refund is null or p_refund < 0 then raise exception 'E_BAD_AMOUNT'; end if;
  if not exists (select 1 from public.suppliers where id = p_supplier and shop_id = s and deleted_at is null) then raise exception 'E_NOT_FOUND'; end if;
  if p_cashbox is not null then cb := (public.ledger_cashbox(p_cashbox)).id; end if;
  e := gen_random_uuid();
  insert into public.journal_entries(id, shop_id, source_type, source_id, memo, idem_key, created_by)
  values (e, s, 'supplier_return', p_supplier, trim(p_reason), p_id, auth.uid());
  cost := public.ledger_issue(p_item, p_qty, e);
  if cost = 0 and p_refund = 0 then raise exception 'E_BAD_AMOUNT'; end if;
  if cost > 0 then
    insert into public.journal_lines(shop_id, entry_id, account_id, debit, credit) values (s, e, public.ledger_acc('inventory'), 0, cost);
  end if;
  if p_refund > 0 then
    if cb is null then
      insert into public.journal_lines(shop_id, entry_id, account_id, party_type, party_id, debit, credit) values (s, e, public.ledger_acc('ap'), 'supplier', p_supplier, p_refund, 0);
    else
      insert into public.journal_lines(shop_id, entry_id, account_id, debit, credit) values (s, e, cb, p_refund, 0);
    end if;
  end if;
  diff := cost - p_refund;
  if diff > 0 then
    insert into public.journal_lines(shop_id, entry_id, account_id, debit, credit) values (s, e, public.ledger_acc('cogs'), diff, 0);
  elsif diff < 0 then
    insert into public.journal_lines(shop_id, entry_id, account_id, debit, credit) values (s, e, public.ledger_acc('cogs'), 0, -diff);
  end if;
  return e;
end $$;

-- ---------- مرتجع من العميل ----------
-- p_refund: اللي بيرجع للعميل. p_cashbox فاضي + p_customer = رصيد للعميل (بيتخصم من مديونيته). p_restock: القطعة سليمة وبترجع المخزون، وإلا هالك
create or replace function public.sale_return(p_id uuid, p_item uuid, p_qty integer, p_refund bigint, p_cashbox uuid default null, p_customer uuid default null, p_restock boolean default true, p_reason text default null) returns uuid
language plpgsql security definer set search_path = public as $$
declare s uuid := public.current_shop_id(); e uuid; it public.items; cost bigint; cb uuid; rev uuid;
begin
  perform public.ledger_require(array['owner', 'reception']::public.app_role[]);
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
    insert into public.journal_lines(shop_id, entry_id, account_id, debit, credit) values (s, e, rev, p_refund, 0);
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

-- ---------- قطعة يدوية على الجهاز (المخزون مش مربوط بالصيانة) ----------
-- اتدفع تمنها من خزنة، أو على مورد بالآجل. بتتسجل كتكلفة قطع على الجهاز (part_use) من غير أي حركة مخزون
create or replace function public.device_manual_part(p_id uuid, p_device uuid, p_name text, p_cost bigint, p_cashbox uuid default null, p_supplier uuid default null) returns uuid
language plpgsql security definer set search_path = public as $$
declare s uuid := public.current_shop_id(); e uuid; credit_line jsonb;
begin
  perform public.ledger_require(array['owner', 'reception']::public.app_role[]);
  e := public.ledger_idem(p_id);
  if e is not null then return e; end if;
  if nullif(trim(p_name), '') is null then raise exception 'E_BAD_INPUT'; end if;
  perform public.ledger_amount(p_cost);
  if not exists (select 1 from public.devices where id = p_device and shop_id = s and deleted_at is null and status <> 'delivered') then raise exception 'E_NOT_FOUND'; end if;
  if p_cashbox is not null then
    credit_line := public.ledger_line((public.ledger_cashbox(p_cashbox)).id, 0, p_cost);
  elsif p_supplier is not null then
    if not exists (select 1 from public.suppliers where id = p_supplier and shop_id = s and deleted_at is null) then raise exception 'E_NOT_FOUND'; end if;
    credit_line := public.ledger_line(public.ledger_acc('ap'), 0, p_cost, 'supplier', p_supplier);
  else
    raise exception 'E_BAD_INPUT';
  end if;
  return public.ledger_post('part_use', null, trim(p_name), jsonb_build_array(public.ledger_line(public.ledger_acc('cogs'), p_cost, 0), credit_line), p_device, p_id);
end $$;

do $$
declare f text;
begin
  foreach f in array array['write_off(uuid, uuid, integer, text)', 'supplier_return(uuid, uuid, uuid, integer, bigint, uuid, text)',
    'sale_return(uuid, uuid, integer, bigint, uuid, uuid, boolean, text)', 'device_manual_part(uuid, uuid, text, bigint, uuid, uuid)'] loop
    execute format('revoke execute on function public.%s from public, anon', f);
    execute format('grant execute on function public.%s to authenticated', f);
  end loop;
end $$;

-- ---------- المخزون بالأعمدة الجديدة (للكل حسب الصلاحية زي الأول) ----------
drop function if exists public.items_stock();
create or replace function public.items_stock() returns table(id uuid, kind text, name text, sku text, sale_price integer, qty bigint, avg_cost bigint, value bigint, min_qty integer, supplier_id uuid, short boolean, category text, barcode text, image_path text)
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
         i.min_qty > 0 and coalesce(st.q, 0) <= i.min_qty,
         i.category, i.barcode, i.image_path
  from public.items i
  left join (select m.item_id, sum(m.qty) as q, sum(m.value) as v from public.stock_moves m group by m.item_id) st on st.item_id = i.id
  where i.shop_id = public.current_shop_id() and i.deleted_at is null
  order by i.kind, i.name;
end $$;
revoke execute on function public.items_stock() from public, anon;
grant execute on function public.items_stock() to authenticated;

-- ---------- حركة صنف: كل دخول وخروج بالترتيب، والرصيد بعد كل حركة (صاحب المحل) ----------
create or replace function public.item_moves(p_item uuid) returns table(entry_id uuid, entry_no bigint, at timestamptz, source_type text, memo text, qty bigint, value bigint, balance_qty bigint, balance_value bigint, device_id uuid, order_no text, by text, reversed boolean)
language plpgsql stable security definer set search_path = public as $$
begin
  perform public.ledger_require(array['owner']::public.app_role[]);
  if not exists (select 1 from public.items where id = p_item and shop_id = public.current_shop_id()) then raise exception 'E_NOT_FOUND'; end if;
  return query
  select e.id, e.entry_no, e.occurred_at, e.source_type, e.memo, m.qty::bigint, m.value::bigint,
         (sum(m.qty) over w)::bigint, (sum(m.value) over w)::bigint,
         e.device_id, d.order_no, p.full_name,
         exists (select 1 from public.journal_entries r where r.reverses_id = e.id)
  from public.stock_moves m
  join public.journal_entries e on e.id = m.entry_id
  left join public.devices d on d.id = e.device_id
  left join public.profiles p on p.id = e.created_by
  where m.item_id = p_item
  window w as (order by e.occurred_at, e.entry_no, m.created_at rows unbounded preceding)
  order by e.occurred_at, e.entry_no, m.created_at;
end $$;
revoke execute on function public.item_moves(uuid) from public, anon;
grant execute on function public.item_moves(uuid) to authenticated;

-- ---------- حسابات المخزون لوحده لفترة: الإيراد والتكلفة والربح ----------
-- القيد العكسي بيتحسب مع نوع العملية الأصلية (إلغاء بيع بيقلل المبيعات)
create or replace function public.inventory_summary(p_from timestamptz, p_to timestamptz) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare s uuid := public.current_shop_id(); res jsonb;
begin
  perform public.ledger_require(array['owner']::public.app_role[]);
  with en as (
    select e.id, coalesce(o.source_type, e.source_type) t
    from public.journal_entries e left join public.journal_entries o on o.id = e.reverses_id
    where e.shop_id = s and e.occurred_at >= p_from and e.occurred_at < p_to
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
    'stock_value', (select coalesce(sum(value), 0) from public.stock_moves where shop_id = s),
    'stock_qty', (select coalesce(sum(qty), 0) from public.stock_moves where shop_id = s),
    'top', coalesce((select jsonb_agg(x order by x.qty desc) from (
        select i.id, i.name, -sum(m.qty)::bigint qty, -sum(m.value)::bigint cost
        from public.stock_moves m join en on en.id = m.entry_id join public.items i on i.id = m.item_id
        where en.t = 'sale' group by i.id, i.name order by -sum(m.qty) desc limit 10) x), '[]'::jsonb)
  ) into res;
  res := res || jsonb_build_object('profit', (res->>'sales')::bigint - (res->>'sales_cost')::bigint - (res->>'wastage')::bigint - (res->>'return_diff')::bigint - (res->>'cost_adjust')::bigint);
  return res;
end $$;
revoke execute on function public.inventory_summary(timestamptz, timestamptz) from public, anon;
grant execute on function public.inventory_summary(timestamptz, timestamptz) to authenticated;
$m0027$;
  insert into public.app_migrations(version, how) values ('0027_inventory.sql', 'applied');
  raise notice 'applied %', '0027_inventory.sql';
end $run$;
commit;

-- ============================== 0028_opening.sql ==============================
begin;
do $run$ begin
  if exists (select 1 from public.app_migrations where version = '0028_opening.sql') then return; end if;
  execute $m0028$
-- ============================================================
-- 0028: جرد المحل أول مرة والأرصدة الافتتاحية (البند 4)
-- كل رصيد افتتاحي قيد متوازن (source_type = 'opening') قصاده "رأس المال" (حقوق ملكية):
--   - المخزون: المخزون مدين بالكمية × التكلفة، ورأس المال دائن (وحركة مخزون بنفس القيمة).
--   - الخزنة: الخزنة مدين، ورأس المال دائن.
--   - دين على عميل: العملاء مدين (للعميل)، ورأس المال دائن. ولو المحل هو اللي عليه للعميل (عربون مثلًا): العكس.
--   - دين لمورد: رأس المال مدين، والموردين دائن (للمورد). ولو المورد هو اللي عليه: العكس.
-- فالدفتر بيقفل متوازن دايمًا، وصافي "رأس المال الافتتاحي" = الأصول - الالتزامات.
-- أي رصيد غلط بيتصحح بقيد عكسي زي أي عملية. ونفس الرقم (p_id) لو اتبعت مرتين ما بيتسجلش مرتين.
-- ============================================================

alter table public.journal_entries drop constraint if exists journal_entries_source_type_check;
alter table public.journal_entries add constraint journal_entries_source_type_check check (source_type = any (array[
  'payment', 'delivery', 'purchase', 'supplier_payment', 'part_use', 'sale', 'expense', 'salary', 'salary_payment', 'advance',
  'advance_settle', 'capital', 'drawing', 'transfer', 'drawer_close', 'reversal', 'cost_adjust',
  'write_off', 'supplier_return', 'sale_return', 'opening']));

create or replace function public.opening_balance(p_id uuid, p_kind text, p_ref uuid, p_amount bigint default null, p_lines jsonb default null)
returns uuid
language plpgsql security definer set search_path = public as $$
declare
  s uuid := public.current_shop_id();
  e uuid;
  cap uuid := public.ledger_acc('capital');
  l jsonb; q bigint; u bigint; total bigint := 0;
  lines jsonb;
  memo text;
begin
  perform public.ledger_require(array['owner']::public.app_role[]);
  e := public.ledger_idem(p_id);
  if e is not null then return e; end if;
  if p_kind = 'stock' then
    if jsonb_typeof(p_lines) <> 'array' or jsonb_array_length(p_lines) = 0 then raise exception 'E_BAD_INPUT'; end if;
    for l in select * from jsonb_array_elements(p_lines) loop
      q := (l ->> 'qty')::bigint;
      u := (l ->> 'unit_cost')::bigint;
      if q is null or q <= 0 or q > 100000 or u is null or u < 0 then raise exception 'E_BAD_AMOUNT'; end if;
      if not exists (select 1 from public.items where id = (l ->> 'item')::uuid and shop_id = s and deleted_at is null) then raise exception 'E_NOT_FOUND'; end if;
      total := total + q * u;
    end loop;
    perform public.ledger_amount(total);
    e := public.ledger_post('opening', null, 'stock', jsonb_build_array(public.ledger_line(public.ledger_acc('inventory'), total, 0), public.ledger_line(cap, 0, total)), null, p_id);
    for l in select * from jsonb_array_elements(p_lines) loop
      insert into public.stock_moves(shop_id, item_id, entry_id, qty, value)
      values (s, (l ->> 'item')::uuid, e, (l ->> 'qty')::int, (l ->> 'qty')::bigint * (l ->> 'unit_cost')::bigint);
    end loop;
    return e;
  end if;
  if p_amount is null or p_amount = 0 then raise exception 'E_BAD_AMOUNT'; end if;
  perform public.ledger_amount(abs(p_amount));
  if p_kind = 'cash' then
    if p_amount < 0 then raise exception 'E_BAD_AMOUNT'; end if;
    lines := jsonb_build_array(public.ledger_line((public.ledger_cashbox(p_ref)).id, p_amount, 0), public.ledger_line(cap, 0, p_amount));
  elsif p_kind = 'customer' then
    if not exists (select 1 from public.customers where id = p_ref and shop_id = s and deleted_at is null) then raise exception 'E_NOT_FOUND'; end if;
    -- موجب = العميل عليه للمحل. سالب = المحل عليه للعميل
    lines := jsonb_build_array(
      public.ledger_line(public.ledger_acc('ar'), greatest(p_amount, 0), greatest(-p_amount, 0), 'customer', p_ref),
      public.ledger_line(cap, greatest(-p_amount, 0), greatest(p_amount, 0)));
  elsif p_kind = 'supplier' then
    if not exists (select 1 from public.suppliers where id = p_ref and shop_id = s and deleted_at is null) then raise exception 'E_NOT_FOUND'; end if;
    -- موجب = المحل عليه للمورد. سالب = المورد عليه للمحل
    lines := jsonb_build_array(
      public.ledger_line(public.ledger_acc('ap'), greatest(-p_amount, 0), greatest(p_amount, 0), 'supplier', p_ref),
      public.ledger_line(cap, greatest(p_amount, 0), greatest(-p_amount, 0)));
  else
    raise exception 'E_BAD_INPUT';
  end if;
  memo := p_kind;
  return public.ledger_post('opening', p_ref, memo, lines, null, p_id);
end $$;
revoke execute on function public.opening_balance(uuid, text, uuid, bigint, jsonb) from public, anon;
grant execute on function public.opening_balance(uuid, text, uuid, bigint, jsonb) to authenticated;

-- ملخص الأرصدة الافتتاحية (الساري بس، من غير الملغي): كل نوع لوحده، وصافي رأس المال، والدفتر متوازن ولا لأ
create or replace function public.opening_summary() returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare s uuid := public.current_shop_id(); res jsonb;
begin
  perform public.ledger_require(array['owner']::public.app_role[]);
  with en as (
    select e.id, e.memo from public.journal_entries e
    where e.shop_id = s and e.source_type = 'opening' and not exists (select 1 from public.journal_entries r where r.reverses_id = e.id)
  ), ln as (
    select en.memo, a.code, a.kind, l.debit, l.credit from en join public.journal_lines l on l.entry_id = en.id join public.accounts a on a.id = l.account_id
  )
  select jsonb_build_object(
    'stock', coalesce((select sum(debit - credit) from ln where kind = 'inventory'), 0),
    'stock_items', (select count(distinct m.item_id) from public.stock_moves m join en on en.id = m.entry_id),
    'cash', coalesce((select sum(debit - credit) from ln where kind = 'cash'), 0),
    'receivables', coalesce((select sum(debit - credit) from ln where kind = 'receivable'), 0),
    'payables', coalesce((select sum(credit - debit) from ln where kind = 'payable'), 0),
    'capital', coalesce((select sum(credit - debit) from ln where code = 'capital'), 0),
    'entries', (select count(*) from en),
    'balanced', coalesce((select sum(debit) = sum(credit) from ln), true),
    'done', coalesce((select (extras ->> 'opening_done')::boolean from public.shops where id = s), false)
  ) into res;
  return res;
end $$;
revoke execute on function public.opening_summary() from public, anon;
grant execute on function public.opening_summary() to authenticated;
$m0028$;
  insert into public.app_migrations(version, how) values ('0028_opening.sql', 'applied');
  raise notice 'applied %', '0028_opening.sql';
end $run$;
commit;

-- ============================== 0029_partners.sql ==============================
begin;
do $run$ begin
  if exists (select 1 from public.app_migrations where version = '0029_partners.sql') then return; end if;
  execute $m0029$
-- ============================================================
-- 0029: الشركاء (البند 5)
-- - كل شريك: الاسم، ورأس ماله، ونسبته من صافي الربح (بالـ 0.01%: من 0 لـ 10000)، وتاريخ دخوله. ومجموع النسب ≤ 100%.
-- - حسابين لكل محل (حقوق ملكية): "رأس مال الشركاء" و"جاري الشركاء"، وكل سطر عليهم باسم الشريك.
--   - إيداع رأس مال: الخزنة مدين، ورأس مال الشريك دائن.
--   - سحب شريك: جاري الشريك (أو رأس ماله) مدين، والخزنة دائن. **مش مصروف**، فما بيقللش الربح.
--   - توزيع الأرباح لفترة: صافي الربح (الإيرادات − المصروفات) × نسبة كل شريك، بيتنقل من "أرباح محتجزة" لجاري الشريك.
--     الباقي (لو النسب أقل من 100%) بيفضل للمحل. والقسمة أعداد صحيحة بالقروش (من غير كسور).
--     ممنوع توزيع نفس الفترة مرتين (إلا لو التوزيع القديم اتلغى بقيد عكسي). والخسارة بتتوزع بنفس الطريقة.
-- - الشريك بيدخل توزيع الفترة لو تاريخ دخوله قبل نهايتها.
-- ============================================================

alter table public.journal_entries drop constraint if exists journal_entries_source_type_check;
alter table public.journal_entries add constraint journal_entries_source_type_check check (source_type = any (array[
  'payment', 'delivery', 'purchase', 'supplier_payment', 'part_use', 'sale', 'expense', 'salary', 'salary_payment', 'advance',
  'advance_settle', 'capital', 'drawing', 'transfer', 'drawer_close', 'reversal', 'cost_adjust',
  'write_off', 'supplier_return', 'sale_return', 'opening', 'partner_capital', 'partner_withdrawal', 'profit_distribution']));
alter table public.accounts drop constraint if exists accounts_kind_check;
alter table public.accounts add constraint accounts_kind_check check (kind = any (array[
  'cash', 'receivable', 'advances', 'inventory', 'payable', 'salaries', 'capital', 'drawings', 'revenue', 'cogs', 'expense', 'shortage', 'overage',
  'partner_capital', 'partner_current', 'retained']));
alter table public.journal_lines drop constraint if exists journal_lines_party_type_check;
alter table public.journal_lines add constraint journal_lines_party_type_check check (party_type = any (array['customer', 'supplier', 'employee', 'partner']));

-- ---------- الشركاء ----------
create table if not exists public.partners (
  id uuid primary key,
  shop_id uuid not null references public.shops(id),
  name text not null check (length(trim(name)) between 1 and 120),
  phone text check (phone is null or length(phone) <= 20),
  share_bp integer not null check (share_bp between 0 and 10000),
  joined_on date not null default current_date,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);
alter table public.partners enable row level security;
revoke all on public.partners from public, anon, authenticated;
grant select, insert, update on public.partners to authenticated;
drop policy if exists partners_select on public.partners;
drop policy if exists partners_insert on public.partners;
drop policy if exists partners_update on public.partners;
create policy partners_select on public.partners for select to authenticated using (shop_id = public.current_shop_id() and public.current_app_role() = 'owner');
create policy partners_insert on public.partners for insert to authenticated with check (shop_id = public.current_shop_id() and public.current_app_role() = 'owner');
create policy partners_update on public.partners for update to authenticated using (shop_id = public.current_shop_id() and public.current_app_role() = 'owner') with check (shop_id = public.current_shop_id());
drop trigger if exists set_updated_at on public.partners;
create trigger set_updated_at before update on public.partners for each row execute function public.tg_set_updated_at();
drop trigger if exists block_delete on public.partners;
create trigger block_delete before delete on public.partners for each row execute function public.tg_block_delete();
drop trigger if exists a_force_shop_id on public.partners;
create trigger a_force_shop_id before insert or update on public.partners for each row execute function public.tg_force_shop_id();
drop trigger if exists zz_audit on public.partners;
create trigger zz_audit after insert or update on public.partners for each row execute function public.tg_audit();

-- مجموع نسب الشركاء الساريين ≤ 100%
create or replace function public.tg_partners_share() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  perform pg_advisory_xact_lock(hashtext('partners:' || new.shop_id::text));
  -- الشريك اللي ليه أو عليه فلوس ما بيتحذفش (سوّي حسابه الأول)
  if tg_op = 'UPDATE' and old.deleted_at is null and new.deleted_at is not null
     and exists (select 1 from public.journal_lines l where l.party_type = 'partner' and l.party_id = new.id group by l.party_id having sum(l.credit - l.debit) <> 0) then
    raise exception 'E_HAS_BALANCE';
  end if;
  if (select coalesce(sum(share_bp), 0) from public.partners where shop_id = new.shop_id and deleted_at is null) > 10000 then
    raise exception 'E_SHARE_OVER_100';
  end if;
  return null;
end $$;
drop trigger if exists zz_partners_share on public.partners;
create constraint trigger zz_partners_share after insert or update on public.partners deferrable initially immediate for each row execute function public.tg_partners_share();

-- ---------- الحسابات ----------
create or replace function public.ensure_partner_accounts(p_shop uuid) returns void
language sql security definer set search_path = public as $$
  insert into public.accounts(shop_id, code, type, kind) values
    (p_shop, 'partners_capital', 'equity', 'partner_capital'),
    (p_shop, 'partners_current', 'equity', 'partner_current'),
    (p_shop, 'retained', 'equity', 'retained')
  on conflict (shop_id, code) where code is not null do nothing
$$;
revoke execute on function public.ensure_partner_accounts(uuid) from public, anon, authenticated;
create or replace function public.tg_shop_partner_accounts() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  perform set_config('warsha.system', 'on', true);
  perform public.ensure_partner_accounts(new.id);
  perform set_config('warsha.system', 'off', true);
  return null;
end $$;
drop trigger if exists zz_shop_partner_accounts on public.shops;
create trigger zz_shop_partner_accounts after insert on public.shops for each row execute function public.tg_shop_partner_accounts();
do $$
declare s uuid;
begin
  perform set_config('warsha.system', 'on', true);
  for s in select id from public.shops loop perform public.ensure_partner_accounts(s); end loop;
  perform set_config('warsha.system', 'off', true);
end $$;

-- ---------- توزيعات الأرباح (عشان نفس الفترة ما تتوزعش مرتين) ----------
create table if not exists public.profit_distributions (
  id uuid primary key,
  shop_id uuid not null references public.shops(id),
  period_from timestamptz not null,
  period_to timestamptz not null check (period_to > period_from),
  profit bigint not null,
  entry_id uuid not null unique references public.journal_entries(id),
  created_by uuid references public.profiles(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);
alter table public.profit_distributions enable row level security;
revoke all on public.profit_distributions from public, anon, authenticated;
grant select on public.profit_distributions to authenticated;
drop policy if exists distributions_select on public.profit_distributions;
create policy distributions_select on public.profit_distributions for select to authenticated using (shop_id = public.current_shop_id() and public.current_app_role() = 'owner');
drop trigger if exists block_delete on public.profit_distributions;
create trigger block_delete before delete on public.profit_distributions for each row execute function public.tg_block_delete();
-- ---------- إيداع رأس مال شريك ----------
create or replace function public.partner_deposit(p_id uuid, p_partner uuid, p_cashbox uuid, p_amount bigint, p_note text default null) returns uuid
language plpgsql security definer set search_path = public as $$
declare cb public.accounts; e uuid;
begin
  perform public.ledger_require(array['owner']::public.app_role[]);
  e := public.ledger_idem(p_id);
  if e is not null then return e; end if;
  perform public.ledger_amount(p_amount);
  cb := public.ledger_cashbox(p_cashbox);
  if not exists (select 1 from public.partners where id = p_partner and shop_id = cb.shop_id and deleted_at is null) then raise exception 'E_NOT_FOUND'; end if;
  return public.ledger_post('partner_capital', p_partner, p_note, jsonb_build_array(
    public.ledger_line(cb.id, p_amount, 0),
    public.ledger_line(public.ledger_acc('partners_capital'), 0, p_amount, 'partner', p_partner)), null, p_id);
end $$;

-- ---------- سحب شريك (مش مصروف): من جاريه، أو من رأس ماله ----------
create or replace function public.partner_withdraw(p_id uuid, p_partner uuid, p_cashbox uuid, p_amount bigint, p_note text default null, p_from_capital boolean default false) returns uuid
language plpgsql security definer set search_path = public as $$
declare cb public.accounts; e uuid;
begin
  perform public.ledger_require(array['owner']::public.app_role[]);
  e := public.ledger_idem(p_id);
  if e is not null then return e; end if;
  perform public.ledger_amount(p_amount);
  cb := public.ledger_cashbox(p_cashbox);
  if not exists (select 1 from public.partners where id = p_partner and shop_id = cb.shop_id) then raise exception 'E_NOT_FOUND'; end if;
  return public.ledger_post('partner_withdrawal', p_partner, p_note, jsonb_build_array(
    public.ledger_line(public.ledger_acc(case when p_from_capital then 'partners_capital' else 'partners_current' end), p_amount, 0, 'partner', p_partner),
    public.ledger_line(cb.id, 0, p_amount)), null, p_id);
end $$;

-- صافي الربح لفترة (الإيرادات − المصروفات) من القيود
create or replace function public.period_profit(p_shop uuid, p_from timestamptz, p_to timestamptz) returns bigint
language sql stable security definer set search_path = public as $$
  select coalesce(sum(l.credit - l.debit), 0)::bigint
  from public.journal_lines l join public.accounts a on a.id = l.account_id join public.journal_entries e on e.id = l.entry_id
  where e.shop_id = p_shop and a.type in ('revenue', 'expense') and e.occurred_at >= p_from and e.occurred_at < p_to
$$;
revoke execute on function public.period_profit(uuid, timestamptz, timestamptz) from public, anon, authenticated;

-- معاينة التوزيع: الربح ونصيب كل شريك (من غير ما يتسجل حاجة)
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
    'shares', coalesce((select jsonb_agg(jsonb_build_object('partner', p.id, 'name', p.name, 'share_bp', p.share_bp,
                 'amount', (pr * p.share_bp / 10000)::bigint) order by p.share_bp desc, p.name)
               from public.partners p where p.shop_id = s and p.deleted_at is null and p.joined_on <= ((p_to - interval '1 microsecond') at time zone 'Africa/Cairo')::date), '[]'::jsonb));
end $$;

-- التوزيع نفسه
create or replace function public.distribute_profit(p_id uuid, p_from timestamptz, p_to timestamptz) returns uuid
language plpgsql security definer set search_path = public as $$
declare s uuid := public.current_shop_id(); e uuid; sp jsonb; x jsonb; total bigint := 0; amt bigint; lines jsonb := '[]'::jsonb; pr bigint;
begin
  perform public.ledger_require(array['owner']::public.app_role[]);
  e := public.ledger_idem(p_id);
  if e is not null then return e; end if;
  perform pg_advisory_xact_lock(hashtext('distribute:' || s::text));
  sp := public.profit_split(p_from, p_to);
  if (sp ->> 'overlap')::boolean then raise exception 'E_PERIOD_DISTRIBUTED'; end if;
  pr := (sp ->> 'profit')::bigint;
  for x in select * from jsonb_array_elements(sp -> 'shares') loop
    amt := (x ->> 'amount')::bigint;
    if amt = 0 then continue; end if;
    total := total + amt;
    lines := lines || jsonb_build_array(public.ledger_line(public.ledger_acc('partners_current'), greatest(-amt, 0), greatest(amt, 0), 'partner', (x ->> 'partner')::uuid));
  end loop;
  if total = 0 then raise exception 'E_NOTHING_TO_DISTRIBUTE'; end if;
  lines := lines || jsonb_build_array(public.ledger_line(public.ledger_acc('retained'), greatest(total, 0), greatest(-total, 0)));
  e := public.ledger_post('profit_distribution', null, to_char(p_from at time zone 'Africa/Cairo', 'YYYY-MM-DD') || ' → ' || to_char((p_to - interval '1 second') at time zone 'Africa/Cairo', 'YYYY-MM-DD'), lines, null, p_id);
  insert into public.profit_distributions(id, shop_id, period_from, period_to, profit, entry_id, created_by) values (p_id, s, p_from, p_to, pr, e, auth.uid());
  return e;
end $$;

-- أرصدة الشركاء: رأس المال، والجاري، والإجمالي (اللي ليه عند المحل)
create or replace function public.partner_balances() returns table(id uuid, name text, phone text, share_bp integer, joined_on date, capital bigint, current bigint, total bigint)
language plpgsql stable security definer set search_path = public as $$
begin
  perform public.ledger_require(array['owner']::public.app_role[]);
  return query
  select p.id, p.name, p.phone, p.share_bp, p.joined_on,
         coalesce(sum(l.credit - l.debit) filter (where a.kind = 'partner_capital'), 0)::bigint,
         coalesce(sum(l.credit - l.debit) filter (where a.kind = 'partner_current'), 0)::bigint,
         coalesce(sum(l.credit - l.debit), 0)::bigint
  from public.partners p
  left join public.journal_lines l on l.party_type = 'partner' and l.party_id = p.id
  left join public.accounts a on a.id = l.account_id
  where p.shop_id = public.current_shop_id() and p.deleted_at is null
  group by p.id
  order by p.share_bp desc, p.name;
end $$;

do $$
declare f text;
begin
  foreach f in array array['partner_deposit(uuid, uuid, uuid, bigint, text)', 'partner_withdraw(uuid, uuid, uuid, bigint, text, boolean)',
    'profit_split(timestamptz, timestamptz)', 'distribute_profit(uuid, timestamptz, timestamptz)', 'partner_balances()'] loop
    execute format('revoke execute on function public.%s from public, anon', f);
    execute format('grant execute on function public.%s to authenticated', f);
  end loop;
end $$;

-- (0029) نفس ledger_post من 0008، والفرق: حسابات الشركاء لازم يبقى معاها الشريك
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
    -- العملاء والموردين والموظفين والشركاء لازم يبقى معاهم الطرف
    if a.kind in ('receivable', 'payable', 'advances', 'salaries', 'partner_capital', 'partner_current') and (l ->> 'party_id') is null then raise exception 'E_BAD_INPUT'; end if;
    insert into public.journal_lines(shop_id, entry_id, account_id, party_type, party_id, debit, credit)
    values (s, e, a.id, l ->> 'party_type', (l ->> 'party_id')::uuid, ld, lc);
    d := d + ld;
    c := c + lc;
  end loop;
  if d <> c or d = 0 then raise exception 'E_UNBALANCED'; end if;
  return e;
end $$;

-- (0029) نفس statement من 0008، والفرق: كشف حساب الشريك
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
  elsif p_kind = 'partner' then
    -- (0029) كشف الشريك: رأس ماله وحسابه الجاري. الرصيد = اللي ليه عند المحل
    select array_agg(id) into accs from public.accounts where shop_id = s and kind in ('partner_capital', 'partner_current');
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

-- (0029) نفس integrity_report من 0025، والفرق: سطور الشركاء من غير الشريك بتظهر كمشكلة
create or replace function public.integrity_report() returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare s uuid := public.current_shop_id(); out jsonb := '[]'::jsonb; r record; inv bigint; mv bigint;
begin
  perform public.ledger_require(array['owner']::public.app_role[]);
  -- 1) قيد مش متوازن، أو ناقص طرف (أقل من سطرين)
  for r in select e.id, e.entry_no, coalesce(sum(l.debit), 0) - coalesce(sum(l.credit), 0) diff, count(l.id) n
           from public.journal_entries e left join public.journal_lines l on l.entry_id = e.id
           where e.shop_id = s group by e.id having coalesce(sum(l.debit), 0) <> coalesce(sum(l.credit), 0) or count(l.id) < 2 loop
    out := out || jsonb_build_array(jsonb_build_object('kind', case when r.n < 2 then 'entry_missing_side' else 'entry_unbalanced' end, 'amount', abs(r.diff), 'entry_id', r.id, 'entry_no', r.entry_no));
  end loop;
  -- 2) قيمة المخزون في الدفتر = مجموع حركات المخزون
  select coalesce(sum(l.debit - l.credit), 0) into inv from public.journal_lines l join public.accounts a on a.id = l.account_id where a.shop_id = s and a.kind = 'inventory';
  select coalesce(sum(m.value), 0) into mv from public.stock_moves m where m.shop_id = s;
  if inv <> mv then out := out || jsonb_build_array(jsonb_build_object('kind', 'inventory_ledger', 'amount', abs(inv - mv), 'ledger', inv, 'stock', mv)); end if;
  -- 3) كل صنف: الكمية مش بالسالب، ومفيش قيمة من غير كمية، ومفيش قيمة بالسالب
  for r in select i.id, i.name, coalesce(sum(m.qty), 0) q, coalesce(sum(m.value), 0) v from public.items i left join public.stock_moves m on m.item_id = i.id
           where i.shop_id = s group by i.id having coalesce(sum(m.qty), 0) < 0 or (coalesce(sum(m.qty), 0) = 0 and coalesce(sum(m.value), 0) <> 0) or coalesce(sum(m.value), 0) < 0 loop
    out := out || jsonb_build_array(jsonb_build_object('kind', 'item_value', 'amount', abs(r.v), 'item_id', r.id, 'item', r.name, 'qty', r.q, 'value', r.v));
  end loop;
  -- 4) كل حركة مخزون بقيمتها في قيد على حساب المخزون بنفس المبلغ
  for r in select m.entry_id, e.entry_no, sum(m.value) mvv,
                  (select coalesce(sum(l.debit - l.credit), 0) from public.journal_lines l join public.accounts a on a.id = l.account_id where l.entry_id = m.entry_id and a.kind = 'inventory') lv
           from public.stock_moves m join public.journal_entries e on e.id = m.entry_id where m.shop_id = s group by m.entry_id, e.entry_no loop
    if r.mvv <> r.lv then out := out || jsonb_build_array(jsonb_build_object('kind', 'stock_entry', 'amount', abs(r.mvv - r.lv), 'entry_id', r.entry_id, 'entry_no', r.entry_no)); end if;
  end loop;
  -- 5) كل دفعة مبلغها = المبلغ اللي دخل الخزنة في قيدها
  for r in select p.id, p.amount, p.entry_id, e.entry_no,
                  (select coalesce(sum(l.debit), 0) from public.journal_lines l join public.accounts a on a.id = l.account_id where l.entry_id = p.entry_id and a.kind = 'cash') cash
           from public.payments p join public.journal_entries e on e.id = p.entry_id where p.shop_id = s loop
    if r.cash <> r.amount then out := out || jsonb_build_array(jsonb_build_object('kind', 'payment_entry', 'amount', abs(r.cash - r.amount), 'entry_id', r.entry_id, 'entry_no', r.entry_no)); end if;
  end loop;
  -- 6) حسابات العملاء والموردين والموظفين: كل سطر عليه طرف (عشان رصيد كل واحد = كشف حسابه)
  for r in select l.entry_id, e.entry_no, sum(l.debit + l.credit) amt from public.journal_lines l join public.accounts a on a.id = l.account_id join public.journal_entries e on e.id = l.entry_id
           where l.shop_id = s and a.kind in ('receivable', 'payable', 'advances', 'salaries', 'partner_capital', 'partner_current') and l.party_id is null group by l.entry_id, e.entry_no loop
    out := out || jsonb_build_array(jsonb_build_object('kind', 'party_missing', 'amount', r.amt, 'entry_id', r.entry_id, 'entry_no', r.entry_no));
  end loop;
  -- 7) كل سطر في نفس محل القيد
  for r in select l.entry_id, e.entry_no from public.journal_lines l join public.journal_entries e on e.id = l.entry_id where e.shop_id = s and l.shop_id <> e.shop_id group by 1, 2 loop
    out := out || jsonb_build_array(jsonb_build_object('kind', 'shop_mismatch', 'amount', 0, 'entry_id', r.entry_id, 'entry_no', r.entry_no));
  end loop;
  return out;
end $$;

-- (0029) نفس opening_balance من 0028، والفرق: رأس مال الشريك في الجرد
create or replace function public.opening_balance(p_id uuid, p_kind text, p_ref uuid, p_amount bigint default null, p_lines jsonb default null)
returns uuid
language plpgsql security definer set search_path = public as $$
declare
  s uuid := public.current_shop_id();
  e uuid;
  cap uuid := public.ledger_acc('capital');
  l jsonb; q bigint; u bigint; total bigint := 0;
  lines jsonb;
  memo text;
begin
  perform public.ledger_require(array['owner']::public.app_role[]);
  e := public.ledger_idem(p_id);
  if e is not null then return e; end if;
  if p_kind = 'stock' then
    if jsonb_typeof(p_lines) <> 'array' or jsonb_array_length(p_lines) = 0 then raise exception 'E_BAD_INPUT'; end if;
    for l in select * from jsonb_array_elements(p_lines) loop
      q := (l ->> 'qty')::bigint;
      u := (l ->> 'unit_cost')::bigint;
      if q is null or q <= 0 or q > 100000 or u is null or u < 0 then raise exception 'E_BAD_AMOUNT'; end if;
      if not exists (select 1 from public.items where id = (l ->> 'item')::uuid and shop_id = s and deleted_at is null) then raise exception 'E_NOT_FOUND'; end if;
      total := total + q * u;
    end loop;
    perform public.ledger_amount(total);
    e := public.ledger_post('opening', null, 'stock', jsonb_build_array(public.ledger_line(public.ledger_acc('inventory'), total, 0), public.ledger_line(cap, 0, total)), null, p_id);
    for l in select * from jsonb_array_elements(p_lines) loop
      insert into public.stock_moves(shop_id, item_id, entry_id, qty, value)
      values (s, (l ->> 'item')::uuid, e, (l ->> 'qty')::int, (l ->> 'qty')::bigint * (l ->> 'unit_cost')::bigint);
    end loop;
    return e;
  end if;
  if p_amount is null or p_amount = 0 then raise exception 'E_BAD_AMOUNT'; end if;
  perform public.ledger_amount(abs(p_amount));
  if p_kind = 'cash' then
    if p_amount < 0 then raise exception 'E_BAD_AMOUNT'; end if;
    lines := jsonb_build_array(public.ledger_line((public.ledger_cashbox(p_ref)).id, p_amount, 0), public.ledger_line(cap, 0, p_amount));
  elsif p_kind = 'customer' then
    if not exists (select 1 from public.customers where id = p_ref and shop_id = s and deleted_at is null) then raise exception 'E_NOT_FOUND'; end if;
    -- موجب = العميل عليه للمحل. سالب = المحل عليه للعميل
    lines := jsonb_build_array(
      public.ledger_line(public.ledger_acc('ar'), greatest(p_amount, 0), greatest(-p_amount, 0), 'customer', p_ref),
      public.ledger_line(cap, greatest(-p_amount, 0), greatest(p_amount, 0)));
  elsif p_kind = 'supplier' then
    if not exists (select 1 from public.suppliers where id = p_ref and shop_id = s and deleted_at is null) then raise exception 'E_NOT_FOUND'; end if;
    -- موجب = المحل عليه للمورد. سالب = المورد عليه للمحل
    lines := jsonb_build_array(
      public.ledger_line(public.ledger_acc('ap'), greatest(-p_amount, 0), greatest(p_amount, 0), 'supplier', p_ref),
      public.ledger_line(cap, greatest(p_amount, 0), greatest(-p_amount, 0)));
  elsif p_kind = 'partner' then
    -- (0029) رأس مال شريك وقت الجرد: جزء من رأس المال الافتتاحي بيتنقل لحساب الشريك
    if p_amount < 0 then raise exception 'E_BAD_AMOUNT'; end if;
    if not exists (select 1 from public.partners where id = p_ref and shop_id = s and deleted_at is null) then raise exception 'E_NOT_FOUND'; end if;
    lines := jsonb_build_array(public.ledger_line(cap, p_amount, 0), public.ledger_line(public.ledger_acc('partners_capital'), 0, p_amount, 'partner', p_ref));
  else
    raise exception 'E_BAD_INPUT';
  end if;
  memo := p_kind;
  return public.ledger_post('opening', p_ref, memo, lines, null, p_id);
end $$;

-- (0029) النسخة الاحتياطية والاسترجاع: نفس 0019 و0023، والفرق إن الشركاء وتوزيعات الأرباح بقوا جوه النسخة
create or replace function public.backup_snapshot(p_shop uuid) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare
  res jsonb := jsonb_build_object('format', 'warsha-backup', 'version', 1, 'generated_at', now(), 'shop_id', p_shop);
  t text;
  rows jsonb;
begin
  foreach t in array array['shops', 'shop_branding', 'profiles', 'customers', 'devices', 'device_costs', 'status_log', 'device_notes', 'device_photos', 'device_checks',
                           'quote_decisions', 'message_templates', 'message_log', 'accounts', 'journal_entries', 'journal_lines', 'payments', 'drawer_closings',
                           'suppliers', 'items', 'stock_moves', 'purchases', 'labor_rates', 'specialties', 'staff_specialties', 'routes', 'repair_steps',
                           'repair_videos', 'device_ratings', 'issue_presets', 'partners', 'profit_distributions', 'audit_log'] loop
    execute format('select coalesce(jsonb_agg(to_jsonb(x)), ''[]''::jsonb) from public.%I x where x.shop_id = $1', t) into rows using p_shop;
    res := res || jsonb_build_object(t, rows);
  end loop;
  select coalesce(jsonb_agg(jsonb_build_object('device_id', device_id, 'kind', kind, 'erased_at', erased_at)), '[]'::jsonb)
    into rows from public.device_passcodes where shop_id = p_shop;
  return res || jsonb_build_object('device_passcodes', rows);
end $$;
revoke execute on function public.backup_snapshot(uuid) from public, anon, authenticated;

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
  tabs text[] := array['profiles', 'shop_branding', 'accounts', 'customers', 'suppliers', 'partners', 'specialties', 'staff_specialties', 'routes', 'labor_rates',
                       'issue_presets', 'message_templates', 'items', 'devices', 'device_costs', 'status_log', 'device_notes', 'device_checks',
                       'quote_decisions', 'repair_steps', 'repair_videos', 'device_ratings', 'journal_entries', 'journal_lines', 'profit_distributions', 'payments',
                       'purchases', 'stock_moves', 'drawer_closings', 'message_log', 'audit_log'];
  -- الجداول دي ليها نسخة اتعملت مع التسجيل: بتتطابق بالكود (أو المفتاح) وبتاخد قيم النسخة
  keyed text[] := array['accounts', 'routes', 'specialties', 'message_templates', 'labor_rates', 'shop_branding'];
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
  insert into public.order_counters(shop_id, year, last_value)
  select s, split_part(order_no, '-', 1)::int, max(split_part(order_no, '-', 2)::int)
    from public.devices where shop_id = s and order_no ~ '^\d{4}-\d+$' group by 2
  on conflict (shop_id, year) do update set last_value = greatest(public.order_counters.last_value, excluded.last_value);

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
revoke execute on function public.restore_backup(jsonb) from public, anon;
grant execute on function public.restore_backup(jsonb) to authenticated;

-- (0029) نفس opening_summary من 0028، والفرق: رأس مال الشركاء في الجرد بيظهر لوحده (والإجمالي زي ما هو)
create or replace function public.opening_summary() returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare s uuid := public.current_shop_id(); res jsonb;
begin
  perform public.ledger_require(array['owner']::public.app_role[]);
  with en as (
    select e.id, e.memo from public.journal_entries e
    where e.shop_id = s and e.source_type = 'opening' and not exists (select 1 from public.journal_entries r where r.reverses_id = e.id)
  ), ln as (
    select en.memo, a.code, a.kind, l.debit, l.credit from en join public.journal_lines l on l.entry_id = en.id join public.accounts a on a.id = l.account_id
  )
  select jsonb_build_object(
    'stock', coalesce((select sum(debit - credit) from ln where kind = 'inventory'), 0),
    'stock_items', (select count(distinct m.item_id) from public.stock_moves m join en on en.id = m.entry_id),
    'cash', coalesce((select sum(debit - credit) from ln where kind = 'cash'), 0),
    'receivables', coalesce((select sum(debit - credit) from ln where kind = 'receivable'), 0),
    'payables', coalesce((select sum(credit - debit) from ln where kind = 'payable'), 0),
    -- (0029) رأس مال المحل الافتتاحي كله = رأس المال + اللي اتنقل للشركاء
    'capital', coalesce((select sum(credit - debit) from ln where code in ('capital', 'partners_capital')), 0),
    'partners', coalesce((select sum(credit - debit) from ln where code = 'partners_capital'), 0),
    'entries', (select count(*) from en),
    'balanced', coalesce((select sum(debit) = sum(credit) from ln), true),
    'done', coalesce((select (extras ->> 'opening_done')::boolean from public.shops where id = s), false)
  ) into res;
  return res;
end $$;
$m0029$;
  insert into public.app_migrations(version, how) values ('0029_partners.sql', 'applied');
  raise notice 'applied %', '0029_partners.sql';
end $run$;
commit;

-- ============================== 0030_party_links.sql ==============================
begin;
do $run$ begin
  if exists (select 1 from public.app_migrations where version = '0030_party_links.sql') then return; end if;
  execute $m0030$
-- ============================================================
-- 0030: ربط عميل بمورد (البند 6)
-- نفس الشخص ممكن يكون عميل (بيصلّح أو بيشتري) ومورد (بيبيعلنا قطع). بالربط:
-- - كشف واحد بالرصيد الصافي: اللي عليه كعميل − اللي ليه كمورد.
-- - مقاصة: قيد متوازن (الموردين مدين، والعملاء دائن) بيخصم الدينين من بعض، لحد أقل رصيد فيهم. وبتتلغي بقيد عكسي.
-- - فك الربط في أي وقت (حذف ناعم للربط بس)، والقيود والكشوف القديمة زي ما هي.
-- كل عميل أو مورد ليه ربط واحد ساري بس.
-- ============================================================

alter table public.journal_entries drop constraint if exists journal_entries_source_type_check;
alter table public.journal_entries add constraint journal_entries_source_type_check check (source_type = any (array[
  'payment', 'delivery', 'purchase', 'supplier_payment', 'part_use', 'sale', 'expense', 'salary', 'salary_payment', 'advance',
  'advance_settle', 'capital', 'drawing', 'transfer', 'drawer_close', 'reversal', 'cost_adjust',
  'write_off', 'supplier_return', 'sale_return', 'opening', 'partner_capital', 'partner_withdrawal', 'profit_distribution', 'netting']));

create table if not exists public.party_links (
  id uuid primary key,
  shop_id uuid not null references public.shops(id),
  customer_id uuid not null references public.customers(id),
  supplier_id uuid not null references public.suppliers(id),
  created_by uuid references public.profiles(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);
create unique index if not exists party_links_customer on public.party_links(customer_id) where deleted_at is null;
create unique index if not exists party_links_supplier on public.party_links(supplier_id) where deleted_at is null;
alter table public.party_links enable row level security;
revoke all on public.party_links from public, anon, authenticated;
grant select on public.party_links to authenticated;
drop policy if exists party_links_select on public.party_links;
create policy party_links_select on public.party_links for select to authenticated using (shop_id = public.current_shop_id() and public.current_app_role() = 'owner');
drop trigger if exists set_updated_at on public.party_links;
create trigger set_updated_at before update on public.party_links for each row execute function public.tg_set_updated_at();
drop trigger if exists block_delete on public.party_links;
create trigger block_delete before delete on public.party_links for each row execute function public.tg_block_delete();
drop trigger if exists zz_audit on public.party_links;
create trigger zz_audit after insert or update on public.party_links for each row execute function public.tg_audit();

create or replace function public.link_parties(p_id uuid, p_customer uuid, p_supplier uuid) returns uuid
language plpgsql security definer set search_path = public as $$
declare s uuid := public.current_shop_id();
begin
  perform public.ledger_require(array['owner']::public.app_role[]);
  if exists (select 1 from public.party_links where id = p_id) then return p_id; end if;
  if not exists (select 1 from public.customers where id = p_customer and shop_id = s and deleted_at is null)
     or not exists (select 1 from public.suppliers where id = p_supplier and shop_id = s and deleted_at is null) then raise exception 'E_NOT_FOUND'; end if;
  if exists (select 1 from public.party_links where deleted_at is null and (customer_id = p_customer or supplier_id = p_supplier)) then raise exception 'E_ALREADY_LINKED'; end if;
  insert into public.party_links(id, shop_id, customer_id, supplier_id, created_by) values (p_id, s, p_customer, p_supplier, auth.uid());
  return p_id;
end $$;

create or replace function public.unlink_parties(p_link uuid) returns void
language plpgsql security definer set search_path = public as $$
begin
  perform public.ledger_require(array['owner']::public.app_role[]);
  update public.party_links set deleted_at = now() where id = p_link and shop_id = public.current_shop_id() and deleted_at is null;
  if not found then raise exception 'E_NOT_FOUND'; end if;
end $$;

-- الربط بتاع عميل أو مورد (لو موجود)، والأرصدة: عليه كعميل، وليه كمورد، والصافي، وأقصى مقاصة
create or replace function public.party_link_info(p_kind text, p_id uuid) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare s uuid := public.current_shop_id(); lk public.party_links; ar bigint; ap bigint;
begin
  perform public.ledger_require(array['owner']::public.app_role[]);
  select * into lk from public.party_links where shop_id = s and deleted_at is null
    and ((p_kind = 'customer' and customer_id = p_id) or (p_kind = 'supplier' and supplier_id = p_id) or (p_kind = 'link' and id = p_id));
  if not found then return null; end if;
  select coalesce(sum(l.debit - l.credit), 0) into ar from public.journal_lines l join public.accounts a on a.id = l.account_id where a.shop_id = s and a.kind = 'receivable' and l.party_id = lk.customer_id;
  select coalesce(sum(l.credit - l.debit), 0) into ap from public.journal_lines l join public.accounts a on a.id = l.account_id where a.shop_id = s and a.kind = 'payable' and l.party_id = lk.supplier_id;
  return jsonb_build_object('id', lk.id, 'customer_id', lk.customer_id, 'supplier_id', lk.supplier_id,
    'customer', (select name from public.customers where id = lk.customer_id), 'supplier', (select name from public.suppliers where id = lk.supplier_id),
    'receivable', ar, 'payable', ap, 'net', ar - ap, 'max_netting', greatest(least(ar, ap), 0));
end $$;

-- المقاصة: الموردين مدين (المحل عليه أقل للمورد)، والعملاء دائن (العميل عليه أقل). p_amount فاضي = أقصى مبلغ
create or replace function public.net_parties(p_id uuid, p_link uuid, p_amount bigint default null) returns uuid
language plpgsql security definer set search_path = public as $$
declare e uuid; info jsonb; amt bigint;
begin
  perform public.ledger_require(array['owner']::public.app_role[]);
  e := public.ledger_idem(p_id);
  if e is not null then return e; end if;
  info := public.party_link_info('link', p_link);
  if info is null then raise exception 'E_NOT_FOUND'; end if;
  amt := coalesce(p_amount, (info ->> 'max_netting')::bigint);
  if amt <= 0 or amt > (info ->> 'max_netting')::bigint then raise exception 'E_NETTING_LIMIT'; end if;
  return public.ledger_post('netting', p_link, null, jsonb_build_array(
    public.ledger_line(public.ledger_acc('ap'), amt, 0, 'supplier', (info ->> 'supplier_id')::uuid),
    public.ledger_line(public.ledger_acc('ar'), 0, amt, 'customer', (info ->> 'customer_id')::uuid)), null, p_id);
end $$;

do $$
declare f text;
begin
  foreach f in array array['link_parties(uuid, uuid, uuid)', 'unlink_parties(uuid)', 'party_link_info(text, uuid)', 'net_parties(uuid, uuid, bigint)'] loop
    execute format('revoke execute on function public.%s from public, anon', f);
    execute format('grant execute on function public.%s to authenticated', f);
  end loop;
end $$;

-- (0030) نفس statement من 0029، والفرق: كشف صافي للعميل والمورد المربوطين (kind = 'linked'، والـ id = رقم الربط)
create or replace function public.statement(p_kind text, p_id uuid, p_from timestamptz, p_to timestamptz) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare
  s uuid := public.current_shop_id();
  accs uuid[];
  parties uuid[] := array[p_id];
  lk public.party_links;
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
  where l.account_id = any(accs) and (p_kind = 'cashbox' or l.party_id = any(parties)) and e.occurred_at < p_from;
  with mv as (
    select e.id as entry_id, e.entry_no, e.occurred_at, e.source_type, e.source_id, e.device_id, e.memo, e.reverses_id,
           d.order_no, p.full_name as by_name, a.code as account_code,
           ((l.debit - l.credit) * (case when p_kind = 'linked' then 1 else public.account_sign(a.type) end))::bigint as amount
    from public.journal_lines l
    join public.accounts a on a.id = l.account_id
    join public.journal_entries e on e.id = l.entry_id
    left join public.devices d on d.id = e.device_id
    left join public.profiles p on p.id = e.created_by
    where l.account_id = any(accs) and (p_kind = 'cashbox' or l.party_id = any(parties)) and e.occurred_at >= p_from and e.occurred_at < p_to
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

-- (0030) النسخة الاحتياطية والاسترجاع: نفس 0029، والفرق إن روابط العملاء بالموردين بقت جوه النسخة
create or replace function public.backup_snapshot(p_shop uuid) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare
  res jsonb := jsonb_build_object('format', 'warsha-backup', 'version', 1, 'generated_at', now(), 'shop_id', p_shop);
  t text;
  rows jsonb;
begin
  foreach t in array array['shops', 'shop_branding', 'profiles', 'customers', 'devices', 'device_costs', 'status_log', 'device_notes', 'device_photos', 'device_checks',
                           'quote_decisions', 'message_templates', 'message_log', 'accounts', 'journal_entries', 'journal_lines', 'payments', 'drawer_closings',
                           'suppliers', 'items', 'stock_moves', 'purchases', 'labor_rates', 'specialties', 'staff_specialties', 'routes', 'repair_steps',
                           'repair_videos', 'device_ratings', 'issue_presets', 'partners', 'profit_distributions', 'party_links', 'audit_log'] loop
    execute format('select coalesce(jsonb_agg(to_jsonb(x)), ''[]''::jsonb) from public.%I x where x.shop_id = $1', t) into rows using p_shop;
    res := res || jsonb_build_object(t, rows);
  end loop;
  select coalesce(jsonb_agg(jsonb_build_object('device_id', device_id, 'kind', kind, 'erased_at', erased_at)), '[]'::jsonb)
    into rows from public.device_passcodes where shop_id = p_shop;
  return res || jsonb_build_object('device_passcodes', rows);
end $$;
revoke execute on function public.backup_snapshot(uuid) from public, anon, authenticated;

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
  tabs text[] := array['profiles', 'shop_branding', 'accounts', 'customers', 'suppliers', 'party_links', 'partners', 'specialties', 'staff_specialties', 'routes', 'labor_rates',
                       'issue_presets', 'message_templates', 'items', 'devices', 'device_costs', 'status_log', 'device_notes', 'device_checks',
                       'quote_decisions', 'repair_steps', 'repair_videos', 'device_ratings', 'journal_entries', 'journal_lines', 'profit_distributions', 'payments',
                       'purchases', 'stock_moves', 'drawer_closings', 'message_log', 'audit_log'];
  -- الجداول دي ليها نسخة اتعملت مع التسجيل: بتتطابق بالكود (أو المفتاح) وبتاخد قيم النسخة
  keyed text[] := array['accounts', 'routes', 'specialties', 'message_templates', 'labor_rates', 'shop_branding'];
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
  insert into public.order_counters(shop_id, year, last_value)
  select s, split_part(order_no, '-', 1)::int, max(split_part(order_no, '-', 2)::int)
    from public.devices where shop_id = s and order_no ~ '^\d{4}-\d+$' group by 2
  on conflict (shop_id, year) do update set last_value = greatest(public.order_counters.last_value, excluded.last_value);

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
revoke execute on function public.restore_backup(jsonb) from public, anon;
grant execute on function public.restore_backup(jsonb) to authenticated;
$m0030$;
  insert into public.app_migrations(version, how) values ('0030_party_links.sql', 'applied');
  raise notice 'applied %', '0030_party_links.sql';
end $run$;
commit;

-- ============================== 0031_partner_capital.sql ==============================
begin;
do $run$ begin
  if exists (select 1 from public.app_migrations where version = '0031_partner_capital.sql') then return; end if;
  execute $m0031$
-- ============================================================
-- 0031: رأس مال الشريك بأنواعه، وحقوق الملكية في الوضع المالي (ملاحظات صاحب المشروع على البند 5)
-- رأس مال الشريك حقوق ملكية، مش دين على المحل، ومش إيراد ولا ربح:
--   أ) فلوس دخلت دلوقتي: الخزنة مدين، ورأس مال الشريك دائن.
--   ب) بضاعة: المخزون مدين (وحركة مخزون بالكمية والتكلفة)، ورأس مال الشريك دائن.
--   ج) معدات: "أصول ثابتة" مدين، ورأس مال الشريك دائن (وبتدخل في قيمة المحل).
--   د) رأس مال قديم (قبل البرنامج): رصيد افتتاحي من غير ما يلمس الخزن: جزء من رأس المال الافتتاحي بيتنقل للشريك.
-- كل حركة بتاريخها (النهارده أو قبل كده). وزيادة رأس المال أو سحب جزء منه بعدين بنفس الطريقة.
-- الوضع المالي: "عليا للناس" فيها الموردين والمرتبات بس (ومعاهم عربون العملاء لأنه فلوس لناس من بره)، وحقوق الملكية في قسم لوحده.
-- ============================================================

alter table public.accounts drop constraint if exists accounts_kind_check;
alter table public.accounts add constraint accounts_kind_check check (kind = any (array[
  'cash', 'receivable', 'advances', 'inventory', 'payable', 'salaries', 'capital', 'drawings', 'revenue', 'cogs', 'expense', 'shortage', 'overage',
  'partner_capital', 'partner_current', 'retained', 'fixed_asset']));

create or replace function public.ensure_partner_accounts(p_shop uuid) returns void
language sql security definer set search_path = public as $$
  insert into public.accounts(shop_id, code, type, kind) values
    (p_shop, 'partners_capital', 'equity', 'partner_capital'),
    (p_shop, 'partners_current', 'equity', 'partner_current'),
    (p_shop, 'retained', 'equity', 'retained'),
    (p_shop, 'fixed_assets', 'asset', 'fixed_asset')
  on conflict (shop_id, code) where code is not null do nothing
$$;
revoke execute on function public.ensure_partner_accounts(uuid) from public, anon, authenticated;
do $$
declare s uuid;
begin
  perform set_config('warsha.system', 'on', true);
  for s in select id from public.shops loop perform public.ensure_partner_accounts(s); end loop;
  perform set_config('warsha.system', 'off', true);
end $$;

-- نفس ledger_post (0029) بتاريخ محدد للعملية (للحركات اللي حصلت قبل النهارده)
create or replace function public.ledger_post_at(
  p_at timestamptz, p_source_type text, p_source_id uuid, p_memo text, p_lines jsonb,
  p_device uuid default null, p_idem uuid default null
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
  insert into public.journal_entries(id, shop_id, occurred_at, source_type, source_id, device_id, memo, idem_key, created_by)
  values (e, s, p_at, p_source_type, p_source_id, p_device, nullif(trim(p_memo), ''), p_idem, auth.uid());
  for l in select * from jsonb_array_elements(p_lines) loop
    select * into a from public.accounts where id = (l ->> 'account')::uuid and shop_id = s and deleted_at is null;
    if not found then raise exception 'E_BAD_ACCOUNT'; end if;
    ld := coalesce((l ->> 'debit')::bigint, 0);
    lc := coalesce((l ->> 'credit')::bigint, 0);
    if ld < 0 or lc < 0 or (ld > 0) = (lc > 0) then raise exception 'E_BAD_AMOUNT'; end if;
    -- العملاء والموردين والموظفين والشركاء لازم يبقى معاهم الطرف
    if a.kind in ('receivable', 'payable', 'advances', 'salaries', 'partner_capital', 'partner_current') and (l ->> 'party_id') is null then raise exception 'E_BAD_INPUT'; end if;
    insert into public.journal_lines(shop_id, entry_id, account_id, party_type, party_id, debit, credit)
    values (s, e, a.id, l ->> 'party_type', (l ->> 'party_id')::uuid, ld, lc);
    d := d + ld;
    c := c + lc;
  end loop;
  if d <> c or d = 0 then raise exception 'E_UNBALANCED'; end if;
  return e;
end $$;
revoke execute on function public.ledger_post_at(timestamptz, text, uuid, text, jsonb, uuid, uuid) from public, anon, authenticated;

-- تاريخ العملية: اليوم اللي اتكتب (بتوقيت القاهرة، الساعة 12 الضهر) أو دلوقتي لو النهارده. ممنوع تاريخ في المستقبل
create or replace function public.ledger_day_at(p_date date) returns timestamptz
language plpgsql stable set search_path = public as $$
declare today date := (now() at time zone 'Africa/Cairo')::date;
begin
  if p_date is null or p_date = today then return now(); end if;
  if p_date > today or p_date < date '2000-01-01' then raise exception 'E_BAD_DATE'; end if;
  return (p_date + time '12:00') at time zone 'Africa/Cairo';
end $$;
revoke execute on function public.ledger_day_at(date) from public, anon, authenticated;

-- رأس مال داخل من شريك: p_kind = cash | goods | equipment | old
create or replace function public.partner_capital_in(p_id uuid, p_partner uuid, p_kind text, p_amount bigint default null, p_date date default null,
  p_cashbox uuid default null, p_lines jsonb default null, p_note text default null) returns uuid
language plpgsql security definer set search_path = public as $$
declare s uuid := public.current_shop_id(); e uuid; at timestamptz; l jsonb; q bigint; u bigint; total bigint := 0; debit_line jsonb; memo text;
begin
  perform public.ledger_require(array['owner']::public.app_role[]);
  e := public.ledger_idem(p_id);
  if e is not null then return e; end if;
  if not exists (select 1 from public.partners where id = p_partner and shop_id = s and deleted_at is null) then raise exception 'E_NOT_FOUND'; end if;
  at := public.ledger_day_at(p_date);
  memo := coalesce(nullif(trim(p_note), ''), p_kind);
  if p_kind = 'goods' then
    if jsonb_typeof(p_lines) <> 'array' or jsonb_array_length(p_lines) = 0 then raise exception 'E_BAD_INPUT'; end if;
    for l in select * from jsonb_array_elements(p_lines) loop
      q := (l ->> 'qty')::bigint;
      u := (l ->> 'unit_cost')::bigint;
      if q is null or q <= 0 or q > 100000 or u is null or u < 0 then raise exception 'E_BAD_AMOUNT'; end if;
      if not exists (select 1 from public.items where id = (l ->> 'item')::uuid and shop_id = s and deleted_at is null) then raise exception 'E_NOT_FOUND'; end if;
      total := total + q * u;
    end loop;
    perform public.ledger_amount(total);
    debit_line := public.ledger_line(public.ledger_acc('inventory'), total, 0);
  else
    perform public.ledger_amount(p_amount);
    total := p_amount;
    if p_kind = 'cash' then
      debit_line := public.ledger_line((public.ledger_cashbox(p_cashbox)).id, total, 0);
    elsif p_kind = 'equipment' then
      debit_line := public.ledger_line(public.ledger_acc('fixed_assets'), total, 0);
    elsif p_kind = 'old' then
      -- رأس مال قديم: الأصول نفسها اتسجلت في الجرد قصاد رأس المال، فهنا جزء منه بيتنقل للشريك بس
      debit_line := public.ledger_line(public.ledger_acc('capital'), total, 0);
    else
      raise exception 'E_BAD_INPUT';
    end if;
  end if;
  e := public.ledger_post_at(at, case when p_kind = 'old' then 'opening' else 'partner_capital' end, p_partner, memo, jsonb_build_array(
    debit_line, public.ledger_line(public.ledger_acc('partners_capital'), 0, total, 'partner', p_partner)), null, p_id);
  if p_kind = 'goods' then
    for l in select * from jsonb_array_elements(p_lines) loop
      insert into public.stock_moves(shop_id, item_id, entry_id, qty, value) values (s, (l ->> 'item')::uuid, e, (l ->> 'qty')::int, (l ->> 'qty')::bigint * (l ->> 'unit_cost')::bigint);
    end loop;
  end if;
  return e;
end $$;

-- سحب من الشريك بتاريخ: من رأس ماله (تخفيض رأس المال) أو من أرباحه (الجاري). مش مصروف
create or replace function public.partner_capital_out(p_id uuid, p_partner uuid, p_cashbox uuid, p_amount bigint, p_date date default null,
  p_from_capital boolean default true, p_note text default null) returns uuid
language plpgsql security definer set search_path = public as $$
declare e uuid; cb public.accounts;
begin
  perform public.ledger_require(array['owner']::public.app_role[]);
  e := public.ledger_idem(p_id);
  if e is not null then return e; end if;
  perform public.ledger_amount(p_amount);
  cb := public.ledger_cashbox(p_cashbox);
  if not exists (select 1 from public.partners where id = p_partner and shop_id = cb.shop_id) then raise exception 'E_NOT_FOUND'; end if;
  return public.ledger_post_at(public.ledger_day_at(p_date), 'partner_withdrawal', p_partner, p_note, jsonb_build_array(
    public.ledger_line(public.ledger_acc(case when p_from_capital then 'partners_capital' else 'partners_current' end), p_amount, 0, 'partner', p_partner),
    public.ledger_line(cb.id, 0, p_amount)), null, p_id);
end $$;

do $$
declare f text;
begin
  foreach f in array array['partner_capital_in(uuid, uuid, text, bigint, date, uuid, jsonb, text)', 'partner_capital_out(uuid, uuid, uuid, bigint, date, boolean, text)'] loop
    execute format('revoke execute on function public.%s from public, anon', f);
    execute format('grant execute on function public.%s to authenticated', f);
  end loop;
end $$;

-- (0031) نفس financial_position من 0008، والفرق: الأصول الثابتة، و"أرباح مستحقة للشركاء" لوحدها، وتفاصيل حقوق الملكية
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
    'fixed_assets', p.fixed_assets,
    'partners_due', p.partners_due,
    -- قيمة المحل = الأصول − الالتزامات اللي لناس من بره بس (رأس مال الشركاء وأرباحهم حقوق ملكية، فما بتقللهاش)
    'net_worth', p.cash + p.receivables + p.payables_debit + p.inventory + p.fixed_assets - p.payables,
    -- حقوق الملكية بالتفصيل (من أول يوم): رأس مال صاحب المحل، والسحوبات، ورأس مال وجاري كل شريك، والأرباح المحتجزة
    'equity_parts', jsonb_build_object(
      'owner_capital', coalesce((select b from acc where code = 'capital'), 0),
      'drawings', -coalesce((select b from acc where code = 'drawings'), 0),
      'retained', eq.earnings + coalesce((select b from acc where code = 'retained'), 0),
      'partners', coalesce((select jsonb_agg(jsonb_build_object('id', pt.id, 'name', pt.name, 'share_bp', pt.share_bp,
          'capital', coalesce((select sum(b.b) from bal b where b.kind = 'partner_capital' and b.party_id = pt.id), 0),
          'current', coalesce((select sum(b.b) from bal b where b.kind = 'partner_current' and b.party_id = pt.id), 0)) order by pt.share_bp desc, pt.name)
        from public.partners pt where pt.shop_id = s and (pt.deleted_at is null or exists (select 1 from bal b where b.party_id = pt.id and b.b <> 0))), '[]'::jsonb)),
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
$m0031$;
  insert into public.app_migrations(version, how) values ('0031_partner_capital.sql', 'applied');
  raise notice 'applied %', '0031_partner_capital.sql';
end $run$;
commit;

-- ============================== 0032_lists.sql ==============================
begin;
do $run$ begin
  if exists (select 1 from public.app_migrations where version = '0032_lists.sql') then return; end if;
  execute $m0032$
-- ============================================================
-- 0032: القوائم اللي بيديرها صاحب المحل (البند 7)
-- - القوايم: الماركات، والموديلات، والملحقات، والألوان، والحالة الشكلية، وتصنيفات الأصناف، وأسباب الهالك، والحالات الفرعية تحت كل حالة أساسية.
--   (الأعطال الجاهزة في الإعدادات ← إضافات، والمصروفات في ← الخزن والمصروفات، وطرق الدفع في ← طرق الدفع: ليهم شاشاتهم من قبل كده)
-- - البيانات نفسها بتتخزن بالقيمة (نص)، مش برقم البند: فحذف بند من القايمة (حذف ناعم) بيخفيه من الاختيار بس،
--   والأجهزة والأصناف القديمة بتفضل زي ما هي بالظبط.
-- - الحالات الأساسية ثابتة (src/lib/status.ts وis_valid_transition)، والحالة الفرعية تفصيلة تحتها بس
--   (مثلًا "مستني قطعة" ← "اتطلبت من المورد" أو "في الطريق"). ولما الحالة الأساسية تتغير، الفرعية بتتشال لوحدها.
-- - الكل بيشوف القوايم، وصاحب المحل بس اللي بيعدّلها.
-- ============================================================

create table if not exists public.shop_lists (
  id uuid primary key,
  shop_id uuid not null references public.shops(id),
  list text not null check (list in ('brands', 'models', 'accessories', 'colors', 'conditions', 'item_categories', 'write_off_reasons', 'sub_statuses')),
  value text not null check (length(trim(value)) between 1 and 60),
  -- للحالات الفرعية: الحالة الأساسية اللي تحتها
  parent text check (parent is null or parent in ('received', 'inspecting', 'awaiting_approval', 'awaiting_part', 'in_repair', 'repaired', 'ready', 'delivered', 'warranty_return', 'unrepairable')),
  sort integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  check ((list = 'sub_statuses') = (parent is not null))
);
-- (لو الجدول اتعمل قبل كده بقايمة أقصر)
alter table public.shop_lists drop constraint if exists shop_lists_list_check;
alter table public.shop_lists add constraint shop_lists_list_check check (list in ('brands', 'models', 'accessories', 'colors', 'conditions', 'item_categories', 'write_off_reasons', 'sub_statuses'));
-- نفس البند ما يتكررش في نفس القايمة (الساري بس)
create unique index if not exists shop_lists_unique on public.shop_lists(shop_id, list, coalesce(parent, ''), lower(trim(value))) where deleted_at is null;
create index if not exists shop_lists_shop on public.shop_lists(shop_id, list);
alter table public.shop_lists enable row level security;
revoke all on public.shop_lists from public, anon, authenticated;
grant select, insert, update on public.shop_lists to authenticated;
drop policy if exists lists_select on public.shop_lists;
drop policy if exists lists_insert on public.shop_lists;
drop policy if exists lists_update on public.shop_lists;
create policy lists_select on public.shop_lists for select to authenticated using (shop_id = public.current_shop_id());
create policy lists_insert on public.shop_lists for insert to authenticated with check (shop_id = public.current_shop_id() and public.current_app_role() = 'owner');
create policy lists_update on public.shop_lists for update to authenticated using (shop_id = public.current_shop_id() and public.current_app_role() = 'owner') with check (shop_id = public.current_shop_id());
drop trigger if exists set_updated_at on public.shop_lists;
create trigger set_updated_at before update on public.shop_lists for each row execute function public.tg_set_updated_at();
drop trigger if exists block_delete on public.shop_lists;
create trigger block_delete before delete on public.shop_lists for each row execute function public.tg_block_delete();
drop trigger if exists a_force_shop_id on public.shop_lists;
create trigger a_force_shop_id before insert or update on public.shop_lists for each row execute function public.tg_force_shop_id();
drop trigger if exists zz_audit on public.shop_lists;
create trigger zz_audit after insert or update on public.shop_lists for each row execute function public.tg_audit();

-- ---------- الحالة الفرعية على الجهاز ----------
alter table public.devices add column if not exists sub_status text check (sub_status is null or length(trim(sub_status)) between 1 and 60);

-- لما الحالة الأساسية تتغير، الفرعية بتتشال (لأنها كانت تفصيلة للحالة القديمة)
create or replace function public.tg_device_sub_status() returns trigger
language plpgsql as $$
begin
  if new.status is distinct from old.status and new.sub_status is not distinct from old.sub_status then
    new.sub_status := null;
  end if;
  return new;
end $$;
drop trigger if exists b_device_sub_status on public.devices;
create trigger b_device_sub_status before update on public.devices for each row execute function public.tg_device_sub_status();

-- (0032) نفس tg_device_guard من 0014، والفرق: الفني يقدر يغيّر الحالة الفرعية برضه
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

  -- الفني يغيّر الحالة (والحالة الفرعية تحتها، من 0032) بس
  if r = 'technician' and
     (to_jsonb(new) - 'status' - 'sub_status' - 'updated_at' - 'delivered_at' - sys) <> (to_jsonb(old) - 'status' - 'sub_status' - 'updated_at' - 'delivered_at' - sys) then
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

-- (0032) النسخة الاحتياطية والاسترجاع: نفس 0030، والفرق إن القوايم بقت جوه النسخة
create or replace function public.backup_snapshot(p_shop uuid) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare
  res jsonb := jsonb_build_object('format', 'warsha-backup', 'version', 1, 'generated_at', now(), 'shop_id', p_shop);
  t text;
  rows jsonb;
begin
  foreach t in array array['shops', 'shop_branding', 'profiles', 'customers', 'devices', 'device_costs', 'status_log', 'device_notes', 'device_photos', 'device_checks',
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
revoke execute on function public.backup_snapshot(uuid) from public, anon, authenticated;

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
  tabs text[] := array['profiles', 'shop_branding', 'accounts', 'customers', 'suppliers', 'party_links', 'partners', 'specialties', 'staff_specialties', 'routes', 'labor_rates',
                       'issue_presets', 'shop_lists', 'message_templates', 'items', 'devices', 'device_costs', 'status_log', 'device_notes', 'device_checks',
                       'quote_decisions', 'repair_steps', 'repair_videos', 'device_ratings', 'journal_entries', 'journal_lines', 'profit_distributions', 'payments',
                       'purchases', 'stock_moves', 'drawer_closings', 'message_log', 'audit_log'];
  -- الجداول دي ليها نسخة اتعملت مع التسجيل: بتتطابق بالكود (أو المفتاح) وبتاخد قيم النسخة
  keyed text[] := array['accounts', 'routes', 'specialties', 'message_templates', 'labor_rates', 'shop_branding'];
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
  insert into public.order_counters(shop_id, year, last_value)
  select s, split_part(order_no, '-', 1)::int, max(split_part(order_no, '-', 2)::int)
    from public.devices where shop_id = s and order_no ~ '^\d{4}-\d+$' group by 2
  on conflict (shop_id, year) do update set last_value = greatest(public.order_counters.last_value, excluded.last_value);

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
revoke execute on function public.restore_backup(jsonb) from public, anon;
grant execute on function public.restore_backup(jsonb) to authenticated;
$m0032$;
  insert into public.app_migrations(version, how) values ('0032_lists.sql', 'applied');
  raise notice 'applied %', '0032_lists.sql';
end $run$;
commit;

-- ============================== 0033_assistant.sql ==============================
begin;
do $run$ begin
  if exists (select 1 from public.app_migrations where version = '0033_assistant.sql') then return; end if;
  execute $m0033$
-- ============================================================
-- 0033: المساعد الذكي في البرنامج كله (S3)
--
-- الإعدادات في shops.extras -> 'assistant' (صاحب المحل بيغيّرها من الإعدادات ← المساعد):
--   enabled  : المساعد كله شغال ولا لأ (الافتراضي شغال)
--   areas    : كل مكان لوحده. المالية مقفولة افتراضيًا (فيها تنبيه عن الطبقة المجانية)
--   staff    : مين من الموظفين يستخدمه (الاستقبال، والفني). صاحب المحل دايمًا
--   daily    : حد يومي للمحل (أقل من حد الخطة أو زيه)
--
-- القواعد دي بتتأكد هنا في قاعدة البيانات (مش في الشاشة بس): الـ Edge Function بتنادي
-- ai_take_area قبل أي سؤال، ولو المكان مقفول أو الموظف مش مسموح له أو الحد خلص بترفض.
-- السؤال والإجابة ما بيتخزنوش. اللي بيتسجل: المحل، والمستخدم، والمكان، والوقت بس.
-- ============================================================

alter table public.ai_usage add column if not exists area text not null default 'tech';

-- الأماكن، ومين يقدر يستخدم كل واحد حسب دوره (فوق إعدادات صاحب المحل)
--   tech      : تلميحات التشخيص للجهاز            (كل الموظفين)
--   intake    : اقتراحات وقت الاستلام               (صاحب المحل والاستقبال)
--   inventory : اقتراحات الشراء                    (صاحب المحل)
--   finance   : أسئلة المالية والملخص الأسبوعي      (صاحب المحل)
--   customers : مسودة رسالة واتساب                  (صاحب المحل والاستقبال)
--   reports   : ملخص مكتوب للتقارير                 (صاحب المحل)
--   screen    : الزرار العايم (شرح الشاشة)          (كل الموظفين)
create or replace function public.assistant_area_roles(p_area text) returns text[]
language sql immutable set search_path = public as $$
  select case p_area
    when 'tech' then array['owner', 'reception', 'technician']
    when 'screen' then array['owner', 'reception', 'technician']
    when 'intake' then array['owner', 'reception']
    when 'customers' then array['owner', 'reception']
    when 'inventory' then array['owner']
    when 'finance' then array['owner']
    when 'reports' then array['owner']
    else array[]::text[] end
$$;
revoke all on function public.assistant_area_roles(text) from public, anon, authenticated;

-- الإعدادات بعد الافتراضي (نفس الافتراضي في src/lib/assistantSettings.ts، وفيه اختبار بيقارنهم)
create or replace function public.assistant_settings(s uuid) returns jsonb
language sql stable security definer set search_path = public as $$
  select jsonb_build_object(
    'enabled', coalesce((a ->> 'enabled')::boolean, true),
    'areas', jsonb_build_object(
      'tech', coalesce((a -> 'areas' ->> 'tech')::boolean, true),
      'intake', coalesce((a -> 'areas' ->> 'intake')::boolean, true),
      'inventory', coalesce((a -> 'areas' ->> 'inventory')::boolean, true),
      'finance', coalesce((a -> 'areas' ->> 'finance')::boolean, false),
      'customers', coalesce((a -> 'areas' ->> 'customers')::boolean, true),
      'reports', coalesce((a -> 'areas' ->> 'reports')::boolean, true),
      'screen', coalesce((a -> 'areas' ->> 'screen')::boolean, true)),
    'staff', jsonb_build_object(
      'reception', coalesce((a -> 'staff' ->> 'reception')::boolean, true),
      'technician', coalesce((a -> 'staff' ->> 'technician')::boolean, true)),
    'daily', case when jsonb_typeof(a -> 'daily') = 'number' and (a ->> 'daily')::numeric >= 0 then floor((a ->> 'daily')::numeric)::int else null end)
  from (select coalesce(extras -> 'assistant', '{}'::jsonb) a from public.shops where id = s) x
$$;
revoke all on function public.assistant_settings(uuid) from public, anon, authenticated;

-- بتتنادى من الـ Edge Function قبل أي سؤال: الصلاحية، والإعدادات، والحد اليومي، وبتسجل الاستخدام
create or replace function public.ai_take_area(p_area text) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  s uuid := public.member_shop_id();
  r text := public.member_role();
  st jsonb;
  pl public.plans;
  lim int;
  n int;
begin
  if s is null or r not in ('owner', 'reception', 'technician') then raise exception 'E_FORBIDDEN'; end if;
  if not (r = any (public.assistant_area_roles(p_area))) then raise exception 'E_FORBIDDEN'; end if;
  st := public.assistant_settings(s);
  if not (st ->> 'enabled')::boolean or not coalesce((st -> 'areas' ->> p_area)::boolean, false) then raise exception 'E_AI_OFF'; end if;
  if r <> 'owner' and not coalesce((st -> 'staff' ->> r)::boolean, false) then raise exception 'E_AI_OFF'; end if;
  pl := public.shop_plan(s);
  lim := least(pl.ai_daily, coalesce((st ->> 'daily')::int, pl.ai_daily));
  -- قفل للمحل ده بس، عشان سؤالين في نفس اللحظة ما يعدّوش الحد
  perform pg_advisory_xact_lock(hashtext('ai_take:' || s::text));
  select count(*) into n from public.ai_usage
    where shop_id = s and created_at >= date_trunc('day', now() at time zone 'Africa/Cairo') at time zone 'Africa/Cairo';
  if n >= lim then raise exception 'E_PLAN_LIMIT'; end if;
  insert into public.ai_usage(shop_id, user_id, area) values (s, auth.uid(), p_area);
  return jsonb_build_object('left', lim - n - 1, 'limit', lim);
end $$;
revoke all on function public.ai_take_area(text) from public, anon;
grant execute on function public.ai_take_area(text) to authenticated;

-- (0033) نفس ai_take من 0017 والفرق: بقت بتمشي على إعدادات المساعد كمان (مكان "التشخيص")
create or replace function public.ai_take() returns jsonb
language plpgsql security definer set search_path = public as $$
declare r jsonb;
begin
  r := public.ai_take_area('tech');
  return jsonb_build_object('left', (r ->> 'left')::int);
end $$;

-- للشاشة: الإعدادات، والمستخدم ده يقدر يستخدم أنهي أماكن، واستخدام النهارده من الحد
create or replace function public.assistant_info() returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare
  s uuid := public.member_shop_id();
  r text := public.member_role();
  st jsonb;
  pl public.plans;
  lim int;
  used int;
  allowed jsonb := '{}'::jsonb;
  a text;
begin
  if s is null then raise exception 'E_FORBIDDEN'; end if;
  st := public.assistant_settings(s);
  pl := public.shop_plan(s);
  lim := least(pl.ai_daily, coalesce((st ->> 'daily')::int, pl.ai_daily));
  select count(*) into used from public.ai_usage
    where shop_id = s and created_at >= date_trunc('day', now() at time zone 'Africa/Cairo') at time zone 'Africa/Cairo';
  foreach a in array array['tech', 'intake', 'inventory', 'finance', 'customers', 'reports', 'screen'] loop
    allowed := allowed || jsonb_build_object(a,
      (st ->> 'enabled')::boolean
      and coalesce((st -> 'areas' ->> a)::boolean, false)
      and r = any (public.assistant_area_roles(a))
      and (r = 'owner' or coalesce((st -> 'staff' ->> r)::boolean, false)));
  end loop;
  return jsonb_build_object('settings', st, 'allowed', allowed, 'used', used, 'limit', lim, 'plan_limit', pl.ai_daily);
end $$;
revoke all on function public.assistant_info() from public, anon;
grant execute on function public.assistant_info() to authenticated;

-- اقتراحات الشراء: اللي خرج من كل صنف آخر 30 يوم (بيع أو اتركب في جهاز)، من غير القيود الملغية. صاحب المحل بس
create or replace function public.items_sold30() returns table(item_id uuid, qty bigint)
language plpgsql stable security definer set search_path = public as $$
begin
  perform public.ledger_require(array['owner']::public.app_role[]);
  return query
  select m.item_id, (-sum(m.qty))::bigint
  from public.stock_moves m
  join public.journal_entries e on e.id = m.entry_id
  where e.shop_id = public.current_shop_id()
    and m.qty < 0
    and e.occurred_at >= now() - interval '30 days'
    and e.reverses_id is null
    and not exists (select 1 from public.journal_entries r where r.reverses_id = e.id)
  group by m.item_id;
end $$;
revoke execute on function public.items_sold30() from public, anon;
grant execute on function public.items_sold30() to authenticated;
$m0033$;
  insert into public.app_migrations(version, how) values ('0033_assistant.sql', 'applied');
  raise notice 'applied %', '0033_assistant.sql';
end $run$;
commit;

select 2 as part, 6 as parts, count(*) as applied_files, max(version) as latest,
  case when '0033_assistant.sql' in (select version from public.app_migrations) then
    'الجزء 2 خلص. اللي بعده: upgrade_part_3.sql'
  else 'فيه ملف ما اتطبقش' end as status
from public.app_migrations;
