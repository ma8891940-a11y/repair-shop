-- جوالك / Gawalak: ترقية مشروع Supabase لآخر نسخة، الجزء 3 من 7 (الملفات 0034_branches.sql لـ 0038_roles_grant.sql).
-- بيتولد تلقائيًا: npm run db:setup-file. ما تعدّلوش بإيدك.
-- شغّل الأجزاء بالترتيب في SQL Editor (كل جزء لوحده: New query ← الصق ← Run): upgrade_part_1.sql ثم upgrade_part_2.sql ثم upgrade_part_3.sql ثم upgrade_part_4.sql ثم upgrade_part_5.sql ثم upgrade_part_6.sql ثم upgrade_part_7.sql.
-- آمن تشغّل أي جزء أكتر من مرة: اللي اتطبق قبل كده بيتخطى. ولو ملف فشل، اللي قبله بيفضل، وصلّح السبب وشغّل نفس الجزء تاني.
-- لو لقى ملف أحدث موجود وأقدم منه ناقص بيقف (E_UPGRADE_GAP). ولو جزء قبله لسه ما اتطبقش بيقف (E_UPGRADE_ORDER). الاتنين من غير تغيير.
-- ملفات الجزء ده: 0034_branches.sql, 0035_lists_everywhere.sql, 0036_roles.sql, 0037_item_details.sql, 0038_roles_grant.sql

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
  if not exists (select 1 from public.app_migrations where version = '0038_roles_grant.sql') and (exists (select 1 from pg_policies where policyname = 'staff_moves_select')) then
    insert into public.app_migrations(version, how) values ('0038_roles_grant.sql', 'found: policy staff_moves_select');
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
  if not exists (select 1 from public.app_migrations where version = '0083_print_perm.sql') and (exists (select 1 from pg_proc p where p.pronamespace = 'public'::regnamespace and p.proname = 'can_edit_print' and position('or (public.current_app_role() = ''reception'' and public.has_perm(''print_templates'', ''edit'')' in p.prosrc) > 0)) then
    insert into public.app_migrations(version, how) values ('0083_print_perm.sql', 'found: function can_edit_print');
  end if;
  if not exists (select 1 from public.app_migrations where version = '0084_party_branch.sql') and (exists (select 1 from pg_proc p where p.pronamespace = 'public'::regnamespace and p.proname = 'party_branch' and position('if public.current_app_role() = ''owner'' then return null; end if;' in p.prosrc) > 0)) then
    insert into public.app_migrations(version, how) values ('0084_party_branch.sql', 'found: function party_branch');
  end if;
  if not exists (select 1 from public.app_migrations where version = '0085_finance_branch.sql') and (exists (select 1 from pg_proc p where p.pronamespace = 'public'::regnamespace and p.proname = 'cashbox_daily' and position('where l.shop_id = public.current_shop_id() and e.occurred_at >= p_from and e.occurred_at < p_to and (br is null or a.branch_id = br)' in p.prosrc) > 0)) then
    insert into public.app_migrations(version, how) values ('0085_finance_branch.sql', 'found: function cashbox_daily');
  end if;
  if not exists (select 1 from public.app_migrations where version = '0086_finance_cards.sql') and (exists (select 1 from pg_proc p where p.pronamespace = 'public'::regnamespace and p.proname = 'financial_position' and position('''partners_due'', case when own then p.partners_due end,' in p.prosrc) > 0)) then
    insert into public.app_migrations(version, how) values ('0086_finance_cards.sql', 'found: function financial_position');
  end if;
  if not exists (select 1 from public.app_migrations where version = '0087_private_finance.sql') and (exists (select 1 from pg_proc p where p.pronamespace = 'public'::regnamespace and p.proname = 'perm_sections' and position('select array[''devices'', ''intake'', ''customers'', ''technicians'', ''inventory'', ''item_create'', ''sales'', ''purchases'', ''cashbox'', ''expenses'', ''finance'', ''private_finance'', ''partners'', ''reports'', ''staff'', ''settings'', ''print_templates'', ''audit'']' in p.prosrc) > 0)) then
    insert into public.app_migrations(version, how) values ('0087_private_finance.sql', 'found: function perm_sections');
  end if;
  if not exists (select 1 from public.app_migrations where version = '0088_print_layout.sql') and (exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'print_templates' and column_name = 'mode')) then
    insert into public.app_migrations(version, how) values ('0088_print_layout.sql', 'found: column print_templates.mode');
  end if;
  if not exists (select 1 from public.app_migrations where version = '0089_print_background.sql') and (exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'printers' and column_name = 'offset_x')) then
    insert into public.app_migrations(version, how) values ('0089_print_background.sql', 'found: column printers.offset_x');
  end if;
  if not exists (select 1 from public.app_migrations where version = '0090_print_versions.sql') and (to_regclass('public.print_template_versions') is not null) then
    insert into public.app_migrations(version, how) values ('0090_print_versions.sql', 'found: table print_template_versions');
  end if;
  if not exists (select 1 from public.app_migrations where version = '0091_print_sticker.sql') and (exists (select 1 from pg_proc p where p.pronamespace = 'public'::regnamespace and p.proname = 'print_free_fields' and position('when p_doc = ''sticker'' then array[''shopName'', ''logo'', ''shopPhone'', ''shopAddress'', ''text'', ''orderNo'', ''date'', ''customer'', ''phone'', ''device'', ''imei'', ''issue'', ''warranty'', ''terms'', ''qr'', ''barcode'', ''price'', ''paid'', ''remaining'']' in p.prosrc) > 0)) then
    insert into public.app_migrations(version, how) values ('0091_print_sticker.sql', 'found: function print_free_fields');
  end if;
  insert into public.app_migrations(version, how) select v, 'inferred' from unnest(array['0022_security_review.sql']::text[]) v
    where v < (select max(version) from public.app_migrations) on conflict (version) do nothing;
  select min(v) into first_missing from unnest(array['0001_phase1.sql', '0002_storage.sql', '0003_shop_profile_realtime.sql', '0004_error_codes.sql', '0005_device_passcode.sql', '0006_invite_name.sql', '0007_phase2_customer.sql', '0008_ledger.sql', '0009_tracking_guess_limit.sql', '0010_default_cashboxes.sql', '0011_finance_drilldown.sql', '0012_spec_completion.sql', '0013_tracking_ambiguous.sql', '0014_technicians.sql', '0015_offline_backup.sql', '0016_shop_identity.sql', '0017_growth.sql', '0018_account_state.sql', '0019_extras.sql', '0020_admin_paging.sql', '0021_spec_rules.sql', '0022_security_review.sql', '0023_restore.sql', '0024_signout.sql', '0025_integrity.sql', '0026_edit_delete.sql', '0027_inventory.sql', '0028_opening.sql', '0029_partners.sql', '0030_party_links.sql', '0031_partner_capital.sql', '0032_lists.sql', '0033_assistant.sql', '0034_branches.sql', '0035_lists_everywhere.sql', '0036_roles.sql', '0037_item_details.sql', '0038_roles_grant.sql', '0039_payment_plans.sql', '0040_branch_books.sql', '0041_analytics.sql', '0042_app_brand.sql', '0043_printing.sql', '0044_capture.sql', '0045_checklists.sql', '0046_master.sql', '0047_mfa.sql', '0048_used.sql', '0049_commissions.sql', '0050_insights.sql', '0051_demo.sql', '0052_catalog.sql', '0053_portal.sql', '0054_telegram.sql', '0055_eta_placeholder.sql', '0056_branch_features.sql', '0057_categories.sql', '0058_web_push.sql', '0059_counters_branch.sql', '0060_sale_lines.sql', '0061_attendance.sql', '0062_vat.sql', '0063_cheques.sql', '0064_day_report.sql', '0065_cheque_pending.sql', '0066_commission_net.sql', '0067_idem_lock.sql', '0068_stock_adjust.sql', '0069_sale_errors.sql', '0070_perm_matrix.sql', '0071_device_children.sql', '0072_sale_line_return.sql', '0073_shop_extras.sql', '0074_idem_cheque_plan.sql', '0075_delete_by_section.sql', '0076_debt_aging.sql', '0077_period_lock.sql', '0078_accountant_export.sql', '0079_purchase_orders.sql', '0080_stock_count.sql', '0081_repair_invoice.sql', '0082_order_prefix.sql', '0083_print_perm.sql', '0084_party_branch.sql', '0085_finance_branch.sql', '0086_finance_cards.sql', '0087_private_finance.sql', '0088_print_layout.sql', '0089_print_background.sql', '0090_print_versions.sql', '0091_print_sticker.sql']) v where v not in (select version from public.app_migrations);
  select max(version) into later_present from public.app_migrations where first_missing is not null and version > first_missing;
  if later_present is not null then raise exception 'E_UPGRADE_GAP: % موجود، بس % ناقص قبله. ابعت الرسالة دي للمطوّر.', later_present, first_missing; end if;
end $chk$;

-- 2) الأجزاء اللي قبل الجزء ده لازم تكون اتطبقت
do $ord$
declare
  files text[] := array['0001_phase1.sql', '0002_storage.sql', '0003_shop_profile_realtime.sql', '0004_error_codes.sql', '0005_device_passcode.sql', '0006_invite_name.sql', '0007_phase2_customer.sql', '0008_ledger.sql', '0009_tracking_guess_limit.sql', '0010_default_cashboxes.sql', '0011_finance_drilldown.sql', '0012_spec_completion.sql', '0013_tracking_ambiguous.sql', '0014_technicians.sql', '0015_offline_backup.sql', '0016_shop_identity.sql', '0017_growth.sql', '0018_account_state.sql', '0019_extras.sql', '0020_admin_paging.sql', '0021_spec_rules.sql', '0022_security_review.sql', '0023_restore.sql', '0024_signout.sql', '0025_integrity.sql', '0026_edit_delete.sql', '0027_inventory.sql', '0028_opening.sql', '0029_partners.sql', '0030_party_links.sql', '0031_partner_capital.sql', '0032_lists.sql', '0033_assistant.sql', '0034_branches.sql', '0035_lists_everywhere.sql', '0036_roles.sql', '0037_item_details.sql', '0038_roles_grant.sql', '0039_payment_plans.sql', '0040_branch_books.sql', '0041_analytics.sql', '0042_app_brand.sql', '0043_printing.sql', '0044_capture.sql', '0045_checklists.sql', '0046_master.sql', '0047_mfa.sql', '0048_used.sql', '0049_commissions.sql', '0050_insights.sql', '0051_demo.sql', '0052_catalog.sql', '0053_portal.sql', '0054_telegram.sql', '0055_eta_placeholder.sql', '0056_branch_features.sql', '0057_categories.sql', '0058_web_push.sql', '0059_counters_branch.sql', '0060_sale_lines.sql', '0061_attendance.sql', '0062_vat.sql', '0063_cheques.sql', '0064_day_report.sql', '0065_cheque_pending.sql', '0066_commission_net.sql', '0067_idem_lock.sql', '0068_stock_adjust.sql', '0069_sale_errors.sql', '0070_perm_matrix.sql', '0071_device_children.sql', '0072_sale_line_return.sql', '0073_shop_extras.sql', '0074_idem_cheque_plan.sql', '0075_delete_by_section.sql', '0076_debt_aging.sql', '0077_period_lock.sql', '0078_accountant_export.sql', '0079_purchase_orders.sql', '0080_stock_count.sql', '0081_repair_invoice.sql', '0082_order_prefix.sql', '0083_print_perm.sql', '0084_party_branch.sql', '0085_finance_branch.sql', '0086_finance_cards.sql', '0087_private_finance.sql', '0088_print_layout.sql', '0089_print_background.sql', '0090_print_versions.sql', '0091_print_sticker.sql'];
  parts int[] := array[1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 3, 3, 3, 3, 3, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 7, 7, 7, 7, 7, 7, 7];
  miss text;
begin
  select min(v) into miss from unnest(files) v where v < '0034_branches.sql' and v not in (select version from public.app_migrations);
  if miss is not null then raise exception 'E_UPGRADE_ORDER: الملف % لسه ما اتطبقش. شغّل upgrade_part_%.sql الأول، وبعدين الجزء ده (3).', miss, parts[array_position(files, miss)]; end if;
end $ord$;

-- 3) ملفات الجزء 3 بالترتيب، كل ملف في transaction لوحده
-- ============================== 0034_branches.sql ==============================
begin;
do $run$ begin
  if exists (select 1 from public.app_migrations where version = '0034_branches.sql') then return; end if;
  execute $m0034$
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
$m0034$;
  insert into public.app_migrations(version, how) values ('0034_branches.sql', 'applied');
  raise notice 'applied %', '0034_branches.sql';
end $run$;
commit;

-- ============================== 0035_lists_everywhere.sql ==============================
begin;
do $run$ begin
  if exists (select 1 from public.app_migrations where version = '0035_lists_everywhere.sql') then return; end if;
  execute $m0035$
-- ============================================================
-- 0035: قوائم الملء السريع في البرنامج كله (طلب صاحب المشروع 2026-11-10)
-- - قوايم جديدة: أنواع الأجهزة، والأعطال (زراير "+ عطل" في الاستلام)، وقطع الغيار، وأسباب المرتجع (جنب الماركات والموديلات والملحقات
--   والألوان والحالة الشكلية وتصنيفات الأصناف وأسباب الهالك والحالات الفرعية).
-- - الأعطال الجاهزة بالسعر (issue_presets) بقت بنفس الصلاحية.
-- - الإضافة والحذف من أي مكان بيستخدم القايمة، لكل الموظفين في المحل (القايمة واحدة للمحل).
-- - مين يضيف ويحذف: صاحب المحل دايمًا، والأدوار اللي يختارها في shops.extras.lists_edit (مثلًا ["reception"]).
-- - الحذف ناعم وبيخفي البند من الاختيار بس: البيانات القديمة متخزنة بالقيمة (نص)، فما بتتغيرش.
-- - كل إضافة وحذف بيتسجلوا في سجل النشاط (zz_audit على shop_lists من 0032).
-- - الصنف في المخزون ليه ماركة (اختياري) من نفس قايمة الماركات.
-- ============================================================

alter table public.shop_lists drop constraint if exists shop_lists_list_check;
alter table public.shop_lists add constraint shop_lists_list_check check (list in (
  'brands', 'models', 'accessories', 'colors', 'conditions', 'item_categories', 'write_off_reasons', 'sub_statuses',
  'device_types', 'issues', 'parts', 'return_reasons'));

-- مين يقدر يضيف أو يحذف من القوايم
create or replace function public.can_edit_lists() returns boolean
language sql stable security definer set search_path = public as $$
  select coalesce(public.current_app_role() = 'owner'
    or exists (select 1 from public.shops s where s.id = public.current_shop_id()
               and coalesce(s.extras -> 'lists_edit', '[]'::jsonb) ? public.current_app_role()::text), false)
$$;
revoke execute on function public.can_edit_lists() from public, anon;
grant execute on function public.can_edit_lists() to authenticated;

drop policy if exists lists_insert on public.shop_lists;
drop policy if exists lists_update on public.shop_lists;
create policy lists_insert on public.shop_lists for insert to authenticated
  with check (shop_id = public.current_shop_id() and public.can_edit_lists());
create policy lists_update on public.shop_lists for update to authenticated
  using (shop_id = public.current_shop_id() and public.can_edit_lists())
  with check (shop_id = public.current_shop_id());

-- الحذف من القايمة بس (deleted_at)، مش تعديل القيمة: عشان البيانات القديمة اللي اتسجلت بالقيمة تفضل مفهومة
create or replace function public.tg_list_value_fixed() returns trigger
language plpgsql as $$
begin
  if (new.value is distinct from old.value or new.list is distinct from old.list or new.parent is distinct from old.parent) and not public.restoring() then
    raise exception 'E_LIST_VALUE_FIXED';
  end if;
  return new;
end $$;
drop trigger if exists b_list_value_fixed on public.shop_lists;
create trigger b_list_value_fixed before update on public.shop_lists for each row execute function public.tg_list_value_fixed();

-- الأعطال الجاهزة: نفس صلاحية القوايم
drop policy if exists presets_insert on public.issue_presets;
drop policy if exists presets_update on public.issue_presets;
create policy presets_insert on public.issue_presets for insert to authenticated
  with check (shop_id = public.current_shop_id() and public.can_edit_lists());
create policy presets_update on public.issue_presets for update to authenticated
  using (shop_id = public.current_shop_id() and public.can_edit_lists())
  with check (shop_id = public.current_shop_id());

-- نوع الجهاز (اختياري، من قايمة أنواع الأجهزة)
alter table public.devices add column if not exists device_type text check (device_type is null or length(trim(device_type)) between 1 and 60);

-- ماركة الصنف (اختياري)
alter table public.items add column if not exists brand text check (brand is null or length(trim(brand)) between 1 and 60);
create index if not exists items_brand on public.items(shop_id, brand) where deleted_at is null and brand is not null;

-- المخزون بماركة الصنف (نفس 0034 + عمود brand)
drop function if exists public.items_stock(boolean);
create or replace function public.items_stock(p_all boolean default false) returns table(id uuid, kind text, name text, sku text, sale_price integer, qty bigint, avg_cost bigint, value bigint, min_qty integer, supplier_id uuid, short boolean, category text, barcode text, image_path text, brand text)
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
         i.category, i.barcode, i.image_path, i.brand
  from public.items i
  left join (select m.item_id, sum(m.qty) as q, sum(m.value) as v from public.stock_moves m where everywhere or m.branch_id = b group by m.item_id) st on st.item_id = i.id
  where i.shop_id = public.current_shop_id() and i.deleted_at is null
  order by i.kind, i.name;
end $$;
revoke execute on function public.items_stock(boolean) from public, anon;
grant execute on function public.items_stock(boolean) to authenticated;

-- ---------- بنود المصروفات من نافذة المصروف نفسها (بنفس صلاحية القوايم) ----------
-- بند المصروف حساب في الدفتر: الإضافة حساب جديد، و"الحذف" بيقفله بس (قيوده القديمة زي ما هي)
create or replace function public.add_expense_type(p_id uuid, p_name text) returns uuid
language plpgsql security definer set search_path = public as $$
declare s uuid := public.current_shop_id(); nm text := trim(coalesce(p_name, ''));
begin
  if s is null or not public.can_edit_lists() then raise exception 'E_FORBIDDEN'; end if;
  if nm = '' or length(nm) > 80 then raise exception 'E_BAD_INPUT'; end if;
  if exists (select 1 from public.accounts where id = p_id) then return p_id; end if;
  insert into public.accounts(id, shop_id, name, type, kind) values (p_id, s, nm, 'expense', 'expense');
  return p_id;
end $$;

create or replace function public.hide_expense_type(p_id uuid) returns void
language plpgsql security definer set search_path = public as $$
declare s uuid := public.current_shop_id();
begin
  if s is null or not public.can_edit_lists() then raise exception 'E_FORBIDDEN'; end if;
  update public.accounts set active = false where id = p_id and shop_id = s and kind = 'expense' and deleted_at is null;
  if not found then raise exception 'E_NOT_FOUND'; end if;
end $$;
revoke execute on function public.add_expense_type(uuid, text), public.hide_expense_type(uuid) from public, anon;
grant execute on function public.add_expense_type(uuid, text), public.hide_expense_type(uuid) to authenticated;
$m0035$;
  insert into public.app_migrations(version, how) values ('0035_lists_everywhere.sql', 'applied');
  raise notice 'applied %', '0035_lists_everywhere.sql';
end $run$;
commit;

-- ============================== 0036_roles.sql ==============================
begin;
do $run$ begin
  if exists (select 1 from public.app_migrations where version = '0036_roles.sql') then return; end if;
  execute $m0036$
-- =====================================================================
-- P (المرحلة الأولى): الأدوار والصلاحيات التفصيلية، ونوع الفرع
-- قرار صاحب المشروع: مرحلتين. المرحلة دي: جدول الصلاحيات، والأدوار الجاهزة، و"شيل" أي صلاحية،
-- ونوع الفرع. فتح صلاحيات الموظف ما عندوش النهارده (زي الأرباح) في المرحلة التانية.
--
-- - الأدوار بأسماء من صاحب المحل. كل دور: جدول (الأقسام × يشوف/يضيف/يعدّل/يحذف/يشوف المبالغ/يطبع ويصدّر).
-- - كل موظف: دور أو أكتر (staff_roles)، وفرع أو أكتر (staff_branches من B)، واستثناءات ليه هو (staff_overrides).
-- - الحماية في قاعدة البيانات: سياسات RLS "مقيّدة" (as restrictive) فوق الموجودة، فبتشيل بس ومش بتفتح حاجة،
--   والدوال اللي بتكتب (البيع، والدفعة، والمصروف، والقطع) بتتأكد من الصلاحية.
-- - صاحب المحل عنده كل الصلاحيات دايمًا (من غير أدوار)، وما ينفعش يتشال. وكل تغيير في سجل النشاط.
-- - نقل الأدوار القديمة: الاستقبال ← دور "استقبال"، والفني ← دور "فني"، بنفس اللي كانوا بيعملوه بالظبط.
-- =====================================================================

-- ---------- الأقسام والعمليات ----------
create or replace function public.perm_sections() returns text[]
language sql immutable as $$
  select array['devices', 'intake', 'customers', 'technicians', 'inventory', 'sales', 'purchases', 'cashbox', 'expenses', 'finance', 'partners', 'reports', 'staff', 'settings', 'audit']
$$;
create or replace function public.perm_ops() returns text[]
language sql immutable as $$
  select array['view', 'add', 'edit', 'delete', 'amounts', 'export']
$$;

-- صلاحيات صالحة: {"devices": ["view", "add"], ...} من الأقسام والعمليات دي بس
create or replace function public.perms_valid(p jsonb) returns boolean
language sql immutable as $$
  select jsonb_typeof(p) = 'object' and not exists (
    select 1 from jsonb_each(p) e
    where not (e.key = any (public.perm_sections())) or jsonb_typeof(e.value) <> 'array'
       or exists (select 1 from jsonb_array_elements_text(e.value) o where not (o = any (public.perm_ops()))))
$$;

revoke execute on function public.perm_sections(), public.perm_ops(), public.perms_valid(jsonb) from public, anon;
grant execute on function public.perm_sections(), public.perm_ops(), public.perms_valid(jsonb) to authenticated;

-- ---------- الجداول ----------
create table public.roles (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references public.shops(id),
  name text not null check (length(trim(name)) between 1 and 60),
  -- الأدوار الجاهزة (صاحب المحل يقدر يعدّلها). base = الدور الأساسي في البرنامج اللي الدور ده بيتبني عليه
  preset text check (preset is null or preset in ('branch_manager', 'reception', 'technician', 'cashier', 'accountant')),
  base public.app_role not null default 'reception' check (base in ('reception', 'technician')),
  perms jsonb not null default '{}'::jsonb check (public.perms_valid(perms)),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);
create unique index roles_name_uq on public.roles(shop_id, lower(trim(name))) where deleted_at is null;
create unique index roles_preset_uq on public.roles(shop_id, preset) where deleted_at is null and preset is not null;

create table public.staff_roles (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references public.shops(id),
  profile_id uuid not null references public.profiles(id),
  role_id uuid not null references public.roles(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);
create unique index staff_roles_uq on public.staff_roles(profile_id, role_id) where deleted_at is null;

-- استثناء لموظف معيّن بعيد عن دوره (يسمح أو يمنع)، وبيظهر في الشاشة إنه استثناء
create table public.staff_overrides (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references public.shops(id),
  profile_id uuid not null references public.profiles(id),
  section text not null check (section = any (public.perm_sections())),
  op text not null check (op = any (public.perm_ops())),
  allow boolean not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);
create unique index staff_overrides_uq on public.staff_overrides(profile_id, section, op) where deleted_at is null;

alter table public.staff_invites add column role_ids uuid[] not null default '{}';

-- نوع الفرع: صيانة بس، أو مبيعات بس، أو الاتنين. تغييره ما بيمسحش أي بيانات
alter table public.branches add column kind text not null default 'both' check (kind in ('repair', 'sales', 'both'));

do $$
declare t text;
begin
  foreach t in array array['roles', 'staff_roles', 'staff_overrides'] loop
    execute format('alter table public.%I enable row level security', t);
    execute format('create trigger set_updated_at before update on public.%I for each row execute function public.tg_set_updated_at()', t);
    execute format('create trigger block_delete before delete on public.%I for each row execute function public.tg_block_delete()', t);
    execute format('create trigger zz_audit after insert or update on public.%I for each row execute function public.tg_audit()', t);
  end loop;
end $$;

-- ---------- الأدوار الجاهزة ----------
-- نفس اللي الدور الأساسي كان بيعمله قبل كده بالظبط (من غير ما حد يكسب أو يخسر صلاحية)
create or replace function public.preset_perms(p text) returns jsonb
language sql immutable as $$
  select case p
    when 'reception' then '{"devices":["view","add","edit","amounts","export"],"intake":["view","add"],"customers":["view","add","edit","export"],"technicians":["view"],"inventory":["view","add","edit","export"],"sales":["view","add","edit","export"],"cashbox":["view","add"],"expenses":["view","add"]}'::jsonb
    when 'branch_manager' then '{"devices":["view","add","edit","amounts","export"],"intake":["view","add"],"customers":["view","add","edit","export"],"technicians":["view"],"inventory":["view","add","edit","export"],"sales":["view","add","edit","export"],"cashbox":["view","add"],"expenses":["view","add"]}'::jsonb
    when 'technician' then '{"devices":["view","edit"],"technicians":["view"],"inventory":["view"]}'::jsonb
    when 'cashier' then '{"customers":["view","add"],"inventory":["view","export"],"sales":["view","add","edit","export"],"cashbox":["view","add"]}'::jsonb
    when 'accountant' then '{"cashbox":["view"],"expenses":["view","add"],"inventory":["view","export"],"sales":["view","export"],"customers":["view"]}'::jsonb
    else '{}'::jsonb end
$$;
create or replace function public.preset_name(p text) returns text
language sql immutable as $$
  select case p when 'branch_manager' then 'مدير فرع' when 'reception' then 'استقبال' when 'technician' then 'فني'
                when 'cashier' then 'كاشير مبيعات' when 'accountant' then 'محاسب' end
$$;

revoke execute on function public.preset_perms(text), public.preset_name(text) from public, anon;
grant execute on function public.preset_perms(text), public.preset_name(text) to authenticated;

create or replace function public.ensure_role_presets(p_shop uuid) returns void
language plpgsql security definer set search_path = public as $$
declare p text;
begin
  foreach p in array array['branch_manager', 'reception', 'technician', 'cashier', 'accountant'] loop
    insert into public.roles(shop_id, name, preset, base, perms)
    select p_shop, public.preset_name(p), p, (case when p = 'technician' then 'technician' else 'reception' end)::public.app_role, public.preset_perms(p)
    where not exists (select 1 from public.roles r where r.shop_id = p_shop and r.preset = p and r.deleted_at is null);
  end loop;
end $$;
revoke execute on function public.ensure_role_presets(uuid) from public, anon, authenticated;

select public.ensure_role_presets(id) from public.shops;
create or replace function public.tg_shop_roles() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  perform public.ensure_role_presets(new.id);
  return null;
end $$;
create trigger zz_shop_roles after insert on public.shops for each row execute function public.tg_shop_roles();

-- النقل: كل موظف حالي (استقبال أو فني) ← الدور الجاهز بتاع دوره
insert into public.staff_roles(shop_id, profile_id, role_id)
select p.shop_id, p.id, r.id from public.profiles p
join public.roles r on r.shop_id = p.shop_id and r.preset = p.role::text and r.deleted_at is null
where p.role in ('reception', 'technician')
  and not exists (select 1 from public.staff_roles sr where sr.profile_id = p.id and sr.deleted_at is null);

-- ---------- التحقق ----------
-- صلاحيات المستخدم الحالي الفعلية {"devices": [...], ...}: أدواره + الاستثناءات. صاحب المحل: كله
create or replace function public.my_perms() returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare r public.app_role := public.current_app_role(); uid uuid := auth.uid(); res jsonb := '{}'::jsonb; sec text; ops text[];
begin
  if r is null then return '{}'::jsonb; end if;
  if r = 'owner' then
    select jsonb_object_agg(s, to_jsonb(public.perm_ops())) into res from unnest(public.perm_sections()) s;
    return res;
  end if;
  foreach sec in array public.perm_sections() loop
    ops := array(
      select o from unnest(public.perm_ops()) o
      where coalesce(
        (select ov.allow from public.staff_overrides ov where ov.profile_id = uid and ov.section = sec and ov.op = o and ov.deleted_at is null),
        exists (select 1 from public.staff_roles sr join public.roles ro on ro.id = sr.role_id and ro.deleted_at is null
                where sr.profile_id = uid and sr.deleted_at is null and coalesce(ro.perms -> sec, '[]'::jsonb) ? o)
        -- موظف من غير أدوار (مفروض ما يحصلش بعد النقل): صلاحيات دوره الأساسي الجاهزة
        or (not exists (select 1 from public.staff_roles sr where sr.profile_id = uid and sr.deleted_at is null)
            and coalesce(public.preset_perms(r::text) -> sec, '[]'::jsonb) ? o)));
    if array_length(ops, 1) > 0 then res := res || jsonb_build_object(sec, to_jsonb(ops)); end if;
  end loop;
  return res;
end $$;

create or replace function public.has_perm(p_section text, p_op text) returns boolean
language sql stable security definer set search_path = public as $$
  select public.current_app_role() = 'owner' or coalesce(public.my_perms() -> p_section, '[]'::jsonb) ? p_op
$$;

-- نوع فرع العملية: صيانة بس ← ما فيش مبيعات، ومبيعات بس ← ما فيش استلام أجهزة
create or replace function public.branch_allows(p_branch uuid, p_section text) returns boolean
language sql stable security definer set search_path = public as $$
  select coalesce((select case b.kind when 'repair' then p_section <> 'sales' when 'sales' then p_section not in ('devices', 'intake', 'technicians') else true end
                   from public.branches b where b.id = p_branch), true)
$$;

revoke execute on function public.my_perms(), public.has_perm(text, text), public.branch_allows(uuid, text) from public, anon;
grant execute on function public.my_perms(), public.has_perm(text, text), public.branch_allows(uuid, text) to authenticated;

-- الحذف والتصحيح: صلاحية "يحذف" في أي قسم من الجدول (جنب الإذن القديم can_correct من البند 2)
create or replace function public.can_correct() returns boolean
language sql stable security definer set search_path = public as $$
  select public.current_app_role() = 'owner'
      or coalesce((select p.can_correct from public.profiles p where p.id = auth.uid() and p.deleted_at is null), false)
      or exists (select 1 from jsonb_each(public.my_perms()) e where e.value ? 'delete')
$$;

-- ---------- RLS: سياسات مقيّدة فوق الموجودة (بتشيل بس) ----------
-- (select ...) = بتتحسب مرة واحدة للطلب، مش لكل صف
create policy perm_devices_select on public.devices as restrictive for select to authenticated using ((select public.has_perm('devices', 'view')));
create policy perm_devices_insert on public.devices as restrictive for insert to authenticated
  with check ((select public.has_perm('intake', 'add')) and public.branch_allows(branch_id, 'intake'));
create policy perm_devices_update on public.devices as restrictive for update to authenticated using ((select public.has_perm('devices', 'edit')));

create policy perm_customers_select on public.customers as restrictive for select to authenticated
  using ((select public.has_perm('customers', 'view')) or (select public.has_perm('intake', 'add')));
create policy perm_customers_insert on public.customers as restrictive for insert to authenticated
  with check ((select public.has_perm('customers', 'add')) or (select public.has_perm('intake', 'add')));
create policy perm_customers_update on public.customers as restrictive for update to authenticated using ((select public.has_perm('customers', 'edit')));

-- مبالغ الجهاز (التكلفة): "يشوف المبالغ" في الأجهزة
create policy perm_costs_select on public.device_costs as restrictive for select to authenticated using ((select public.has_perm('devices', 'amounts')));
create policy perm_costs_insert on public.device_costs as restrictive for insert to authenticated with check ((select public.has_perm('devices', 'amounts')) or (select public.has_perm('intake', 'add')));
create policy perm_costs_update on public.device_costs as restrictive for update to authenticated using ((select public.has_perm('devices', 'amounts')));

-- تفاصيل الأجهزة (الملاحظات والصور والسجل والفحص): بتاعة اللي بيشوف الأجهزة بس
do $$
declare t text;
begin
  foreach t in array array['device_notes', 'device_photos', 'status_log', 'device_checks', 'quote_decisions'] loop
    if to_regclass('public.' || t) is not null then
      execute format('create policy perm_%1$s_select on public.%1$I as restrictive for select to authenticated using ((select public.has_perm(''devices'', ''view'')))', t);
    end if;
  end loop;
end $$;

-- الفنيين: خطوات الصيانة والتخصصات، وبيانات الفنيين نفسهم (كاشير المبيعات ما يشوفهمش ولا من الـ API)
create policy perm_steps_select on public.repair_steps as restrictive for select to authenticated
  using ((select public.has_perm('technicians', 'view')) or technician_id = auth.uid());
create policy perm_staff_spec_select on public.staff_specialties as restrictive for select to authenticated
  using ((select public.has_perm('technicians', 'view')) or profile_id = auth.uid());
create policy perm_profiles_select on public.profiles as restrictive for select to authenticated
  using (id = auth.uid() or role <> 'technician' or (select public.has_perm('technicians', 'view')) or (select public.has_perm('staff', 'view')));

-- المخزون
create policy perm_items_select on public.items as restrictive for select to authenticated
  using ((select public.has_perm('inventory', 'view')) or (select public.has_perm('sales', 'view')));
create policy perm_items_insert on public.items as restrictive for insert to authenticated with check ((select public.has_perm('inventory', 'add')));
create policy perm_items_update on public.items as restrictive for update to authenticated using ((select public.has_perm('inventory', 'edit')));

-- الخزن: اللي بيشوف الخزن أو بيبيع (بيختار الخزنة)
create policy perm_accounts_select on public.accounts as restrictive for select to authenticated
  using (kind <> 'cash' or (select public.has_perm('cashbox', 'view')) or (select public.has_perm('sales', 'add')));

-- الأدوار نفسها: صاحب المحل بيعدّل، وكل موظف بيشوف أدواره واستثناءاته
create policy roles_select on public.roles for select to authenticated using (shop_id = public.current_shop_id());
create policy staff_roles_select on public.staff_roles for select to authenticated
  using (shop_id = public.current_shop_id() and (public.current_app_role() = 'owner' or profile_id = auth.uid()));
create policy staff_overrides_select on public.staff_overrides for select to authenticated
  using (shop_id = public.current_shop_id() and (public.current_app_role() = 'owner' or profile_id = auth.uid()));
grant select on public.roles, public.staff_roles, public.staff_overrides to authenticated;

-- ---------- إدارة الأدوار (صاحب المحل بس، وكله في سجل النشاط) ----------
create or replace function public.save_role(p_id uuid, p_name text, p_base public.app_role, p_perms jsonb) returns uuid
language plpgsql security definer set search_path = public as $$
declare s uuid := public.current_shop_id(); r public.roles; nm text := trim(coalesce(p_name, ''));
begin
  perform public.ledger_require(array['owner']::public.app_role[]);
  if nm = '' or length(nm) > 60 or p_base not in ('reception', 'technician') or not public.perms_valid(coalesce(p_perms, '{}'::jsonb)) then raise exception 'E_BAD_INPUT'; end if;
  if exists (select 1 from public.roles x where x.shop_id = s and x.deleted_at is null and x.id <> p_id and lower(trim(x.name)) = lower(nm)) then raise exception 'E_DUP_NAME'; end if;
  select * into r from public.roles where id = p_id and shop_id = s for update;
  if found then
    if r.deleted_at is not null then raise exception 'E_NOT_FOUND'; end if;
    update public.roles set name = nm, base = p_base, perms = p_perms where id = p_id;
    -- الموظفين اللي عندهم الدور ده: دورهم الأساسي بيتحدّث على طول (من غير خروج ودخول)
    perform public.sync_base_role(sr.profile_id) from public.staff_roles sr where sr.role_id = p_id and sr.deleted_at is null;
  else
    insert into public.roles(id, shop_id, name, base, perms) values (p_id, s, nm, p_base, coalesce(p_perms, '{}'::jsonb));
  end if;
  return p_id;
end $$;

create or replace function public.archive_role(p_id uuid) returns void
language plpgsql security definer set search_path = public as $$
declare s uuid := public.current_shop_id();
begin
  perform public.ledger_require(array['owner']::public.app_role[]);
  if exists (select 1 from public.staff_roles sr join public.profiles p on p.id = sr.profile_id and p.deleted_at is null where sr.role_id = p_id and sr.deleted_at is null) then raise exception 'E_ROLE_IN_USE'; end if;
  update public.roles set deleted_at = now() where id = p_id and shop_id = s and deleted_at is null;
  if not found then raise exception 'E_NOT_FOUND'; end if;
end $$;

-- الدور الأساسي للموظف (استقبال أو فني) من أدواره: لو فيه دور مبني على "فني" ← فني، وإلا استقبال
create or replace function public.sync_base_role(p_profile uuid) returns void
language plpgsql security definer set search_path = public as $$
declare b public.app_role;
begin
  select case when bool_or(r.base = 'technician') and not bool_or(r.base = 'reception') then 'technician' else 'reception' end::public.app_role
    into b from public.staff_roles sr join public.roles r on r.id = sr.role_id and r.deleted_at is null
   where sr.profile_id = p_profile and sr.deleted_at is null;
  if b is null then return; end if;
  perform set_config('warsha.grant', '1', true);
  update public.profiles set role = b where id = p_profile and role in ('reception', 'technician') and role is distinct from b;
  perform set_config('warsha.grant', '', true);
end $$;
revoke execute on function public.sync_base_role(uuid) from public, anon, authenticated;

-- أدوار موظف (دور أو أكتر). صاحب المحل ما بيتغيّرش (عنده كل حاجة دايمًا)
create or replace function public.set_staff_roles(p_profile uuid, p_roles uuid[]) returns void
language plpgsql security definer set search_path = public as $$
declare s uuid := public.current_shop_id(); o public.profiles; before uuid[];
begin
  perform public.ledger_require(array['owner']::public.app_role[]);
  select * into o from public.profiles where id = p_profile and shop_id = s and deleted_at is null;
  if not found then raise exception 'E_NOT_FOUND'; end if;
  if o.role = 'owner' then raise exception 'E_OWNER_PERMS'; end if;
  if coalesce(array_length(p_roles, 1), 0) = 0 then raise exception 'E_BAD_INPUT'; end if;
  if exists (select 1 from unnest(p_roles) x where not exists (select 1 from public.roles r where r.id = x and r.shop_id = s and r.deleted_at is null)) then raise exception 'E_NOT_FOUND'; end if;
  before := array(select role_id from public.staff_roles where profile_id = p_profile and deleted_at is null);
  update public.staff_roles set deleted_at = now() where profile_id = p_profile and deleted_at is null and role_id <> all (p_roles);
  insert into public.staff_roles(shop_id, profile_id, role_id)
  select s, p_profile, x from unnest(p_roles) x
  where not exists (select 1 from public.staff_roles sr where sr.profile_id = p_profile and sr.role_id = x and sr.deleted_at is null);
  perform public.sync_base_role(p_profile);
  insert into public.audit_log(shop_id, actor_id, action, entity, entity_id, before, after)
  values (s, auth.uid(), 'staff_roles', 'profiles', p_profile, jsonb_build_object('roles', before), jsonb_build_object('roles', p_roles));
end $$;

-- استثناء لموظف: يسمح أو يمنع، أو null = يرجع زي دوره
create or replace function public.set_staff_override(p_profile uuid, p_section text, p_op text, p_allow boolean) returns void
language plpgsql security definer set search_path = public as $$
declare s uuid := public.current_shop_id(); o public.profiles;
begin
  perform public.ledger_require(array['owner']::public.app_role[]);
  select * into o from public.profiles where id = p_profile and shop_id = s and deleted_at is null;
  if not found then raise exception 'E_NOT_FOUND'; end if;
  if o.role = 'owner' then raise exception 'E_OWNER_PERMS'; end if;
  if not (p_section = any (public.perm_sections())) or not (p_op = any (public.perm_ops())) then raise exception 'E_BAD_INPUT'; end if;
  update public.staff_overrides set deleted_at = now() where profile_id = p_profile and section = p_section and op = p_op and deleted_at is null;
  if p_allow is not null then
    insert into public.staff_overrides(shop_id, profile_id, section, op, allow) values (s, p_profile, p_section, p_op, p_allow);
  end if;
end $$;

-- الدعوة: الأدوار اللي اتختارت (لو فاضية: الدور الجاهز بتاع دوره الأساسي)
create or replace function public.tg_join_roles() returns trigger
language plpgsql security definer set search_path = public as $$
declare inv public.staff_invites;
begin
  if new.role not in ('reception', 'technician') then return null; end if;
  select * into inv from public.staff_invites where shop_id = new.shop_id and lower(email) = lower(new.email) order by accepted_at desc nulls last, created_at desc limit 1;
  insert into public.staff_roles(shop_id, profile_id, role_id)
  select new.shop_id, new.id, r.id from public.roles r
  where r.shop_id = new.shop_id and r.deleted_at is null
    and (r.id = any (coalesce(inv.role_ids, '{}')) or (coalesce(array_length(inv.role_ids, 1), 0) = 0 and r.preset = new.role::text))
    and not exists (select 1 from public.staff_roles sr where sr.profile_id = new.id and sr.role_id = r.id and sr.deleted_at is null);
  perform public.sync_base_role(new.id);
  return null;
end $$;
create trigger zz_join_roles after insert on public.profiles for each row execute function public.tg_join_roles();

-- الدور الأساسي بيتغير من الأدوار بس (sync_base_role)، مش بتعديل مباشر
create or replace function public.tg_profile_role_guard() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if new.role is distinct from old.role and old.role in ('reception', 'technician') and new.role in ('reception', 'technician')
     and coalesce(current_setting('warsha.grant', true), '') <> '1' and not public.restoring() then
    raise exception 'E_FORBIDDEN';
  end if;
  return new;
end $$;
create trigger b_profile_role_guard before update on public.profiles for each row execute function public.tg_profile_role_guard();

-- نوع الفرع (صاحب المحل)
create or replace function public.set_branch_kind(p_id uuid, p_kind text) returns void
language plpgsql security definer set search_path = public as $$
begin
  perform public.ledger_require(array['owner']::public.app_role[]);
  if p_kind not in ('repair', 'sales', 'both') then raise exception 'E_BAD_INPUT'; end if;
  update public.branches set kind = p_kind where id = p_id and shop_id = public.current_shop_id() and deleted_at is null;
  if not found then raise exception 'E_NOT_FOUND'; end if;
end $$;

revoke execute on function public.save_role(uuid, text, public.app_role, jsonb), public.archive_role(uuid), public.set_staff_roles(uuid, uuid[]),
  public.set_staff_override(uuid, text, text, boolean), public.set_branch_kind(uuid, text) from public, anon;
grant execute on function public.save_role(uuid, text, public.app_role, jsonb), public.archive_role(uuid), public.set_staff_roles(uuid, uuid[]),
  public.set_staff_override(uuid, text, text, boolean), public.set_branch_kind(uuid, text) to authenticated;

-- ---------- الدوال اللي بتكتب: الصلاحية (ونوع الفرع) قبل أي حاجة ----------
create or replace function public.perm_require(p_section text, p_op text) returns void
language plpgsql stable security definer set search_path = public as $$
begin
  if not public.has_perm(p_section, p_op) then raise exception 'E_FORBIDDEN'; end if;
  if not public.branch_allows(public.op_branch(), p_section) then raise exception 'E_BRANCH_KIND'; end if;
end $$;
revoke execute on function public.perm_require(text, text) from public, anon, authenticated;

-- ---------- الدوال اللي بتكتب أو بتقرا مبالغ: الصلاحية ----------
-- record_sale: (src: 0008_ledger.sql) + الصلاحية
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
  perform public.perm_require('sales', 'add');
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

-- sale_return: (src: 0027_inventory.sql) + الصلاحية
create or replace function public.sale_return(p_id uuid, p_item uuid, p_qty integer, p_refund bigint, p_cashbox uuid default null, p_customer uuid default null, p_restock boolean default true, p_reason text default null) returns uuid
language plpgsql security definer set search_path = public as $$
declare s uuid := public.current_shop_id(); e uuid; it public.items; cost bigint; cb uuid; rev uuid;
begin
  perform public.ledger_require(array['owner', 'reception']::public.app_role[]);
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

-- record_payment: (src: 0008_ledger.sql) + الصلاحية
create or replace function public.record_payment(p_id uuid, p_customer uuid, p_cashbox uuid, p_amount bigint, p_device uuid default null, p_method text default null, p_note text default null)
returns uuid
language plpgsql security definer set search_path = public as $$
declare
  cb public.accounts;
  e uuid;
  dev public.devices;
begin
  perform public.ledger_require(array['owner', 'reception']::public.app_role[]);
  perform public.perm_require('cashbox', 'add');
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

-- record_expense: (src: 0008_ledger.sql) + الصلاحية
create or replace function public.record_expense(p_id uuid, p_account uuid, p_cashbox uuid, p_amount bigint, p_note text default null)
returns uuid
language plpgsql security definer set search_path = public as $$
declare cb public.accounts; e uuid;
begin
  perform public.ledger_require(array['owner']::public.app_role[]);
  perform public.perm_require('expenses', 'add');
  e := public.ledger_idem(p_id);
  if e is not null then return e; end if;
  perform public.ledger_amount(p_amount);
  cb := public.ledger_cashbox(p_cashbox);
  if not exists (select 1 from public.accounts where id = p_account and shop_id = cb.shop_id and kind = 'expense' and active and deleted_at is null) then raise exception 'E_BAD_ACCOUNT'; end if;
  return public.ledger_post('expense', p_id, p_note, jsonb_build_array(public.ledger_line(p_account, p_amount, 0), public.ledger_line(cb.id, 0, p_amount)), null, p_id);
end $$;

-- use_part: (src: 0008_ledger.sql) + الصلاحية
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
  perform public.perm_require('devices', 'edit');
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

-- device_manual_part: (src: 0027_inventory.sql) + الصلاحية
create or replace function public.device_manual_part(p_id uuid, p_device uuid, p_name text, p_cost bigint, p_cashbox uuid default null, p_supplier uuid default null) returns uuid
language plpgsql security definer set search_path = public as $$
declare s uuid := public.current_shop_id(); e uuid; credit_line jsonb;
begin
  perform public.ledger_require(array['owner', 'reception']::public.app_role[]);
  perform public.perm_require('devices', 'edit');
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

-- device_money: (src: 0008_ledger.sql) + الصلاحية
create or replace function public.device_money(p_device uuid) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare fc integer; paid bigint;
begin
  perform public.ledger_require(array['owner', 'reception']::public.app_role[]);
  if not public.has_perm('devices', 'amounts') then raise exception 'E_FORBIDDEN'; end if;
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

-- items_stock: (src: 0035_lists_everywhere.sql) + الصلاحية
create or replace function public.items_stock(p_all boolean default false) returns table(id uuid, kind text, name text, sku text, sale_price integer, qty bigint, avg_cost bigint, value bigint, min_qty integer, supplier_id uuid, short boolean, category text, barcode text, image_path text, brand text)
language plpgsql stable security definer set search_path = public as $$
declare r public.app_role := public.current_app_role(); b uuid := public.op_branch(); everywhere boolean;
begin
  if r is null then raise exception 'E_FORBIDDEN'; end if;
  if not (public.has_perm('inventory', 'view') or public.has_perm('sales', 'view')) then raise exception 'E_FORBIDDEN'; end if;
  everywhere := p_all and r = 'owner';
  return query
  select i.id, i.kind, i.name, i.sku,
         case when r = 'technician' then null else i.sale_price end,
         coalesce(st.q, 0)::bigint,
         case when r = 'owner' and coalesce(st.q, 0) > 0 then (st.v / st.q)::bigint end,
         case when r = 'owner' then coalesce(st.v, 0)::bigint end,
         i.min_qty, case when r = 'owner' then i.supplier_id end,
         i.min_qty > 0 and coalesce(st.q, 0) <= i.min_qty,
         i.category, i.barcode, i.image_path, i.brand
  from public.items i
  left join (select m.item_id, sum(m.qty) as q, sum(m.value) as v from public.stock_moves m where everywhere or m.branch_id = b group by m.item_id) st on st.item_id = i.id
  where i.shop_id = public.current_shop_id() and i.deleted_at is null
  order by i.kind, i.name;
end $$;
$m0036$;
  insert into public.app_migrations(version, how) values ('0036_roles.sql', 'applied');
  raise notice 'applied %', '0036_roles.sql';
end $run$;
commit;

-- ============================== 0037_item_details.sql ==============================
begin;
do $run$ begin
  if exists (select 1 from public.app_migrations where version = '0037_item_details.sql') then return; end if;
  execute $m0037$
-- =====================================================================
-- 0037: تفاصيل الصنف، والبيع لصنف مالوش رصيد (تعديل صاحب المشروع 2026-11-11)
-- - الصنف ليه خانات: النوع، والماركة (من 0035)، والموديل، والجودة، واللون. كلها اختيارية، والأصناف القديمة زي ما هي.
--   وكل خانة قايمة ملء سريع (item_types وqualities جديدة، والماركات والموديلات والألوان موجودة).
-- - "السماح بالبيع بدون رصيد" (shops.extras.allow_negative_stock، مقفول افتراضيًا):
--   - مقفول: البيع بكمية أكتر من الرصيد مرفوض (E_STOCK) زي الأول، والكاشير يسجّل الكمية والتكلفة الأول (stock_in).
--   - مفتوح: الكمية الموجودة بتخرج بتكلفتها، والباقي بيخرج من غير تكلفة ويتسجل "محتاج تسوية" (uncosted_sales).
--     ولما الكمية تيجي بعدين (شراء، أو رصيد، أو مرتجع، أو تحويل)، الفرق بيتسوى لوحده بقيد متوازن
--     (تكلفة البضاعة المباعة ← من المخزون) بالمتوسط المرجّح للفرع.
-- - الدفتر متوازن دايمًا، والأرصدة بتتحسب من القيود.
-- =====================================================================

alter table public.items add column if not exists item_type text check (item_type is null or length(trim(item_type)) between 1 and 60);
alter table public.items add column if not exists model text check (model is null or length(trim(model)) between 1 and 80);
alter table public.items add column if not exists quality text check (quality is null or length(trim(quality)) between 1 and 60);
alter table public.items add column if not exists color text check (color is null or length(trim(color)) between 1 and 40);

alter table public.shop_lists drop constraint if exists shop_lists_list_check;
alter table public.shop_lists add constraint shop_lists_list_check check (list in (
  'brands', 'models', 'accessories', 'colors', 'conditions', 'item_categories', 'write_off_reasons', 'sub_statuses',
  'device_types', 'issues', 'parts', 'return_reasons', 'item_types', 'qualities'));

-- ---------- البيع من غير رصيد ----------
create table public.uncosted_sales (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references public.shops(id),
  branch_id uuid not null references public.branches(id),
  item_id uuid not null references public.items(id),
  entry_id uuid not null references public.journal_entries(id),
  qty integer not null check (qty > 0),
  settled integer not null default 0 check (settled >= 0 and settled <= qty),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);
create index uncosted_open on public.uncosted_sales(item_id, branch_id) where settled < qty and deleted_at is null;
alter table public.uncosted_sales enable row level security;
create trigger set_updated_at before update on public.uncosted_sales for each row execute function public.tg_set_updated_at();
create trigger block_delete before delete on public.uncosted_sales for each row execute function public.tg_block_delete();
create trigger zz_audit after insert or update on public.uncosted_sales for each row execute function public.tg_audit();
create policy uncosted_select on public.uncosted_sales for select to authenticated using (shop_id = public.current_shop_id());
grant select on public.uncosted_sales to authenticated;

create or replace function public.allow_negative_stock() returns boolean
language sql stable security definer set search_path = public as $$
  select coalesce((select (s.extras ->> 'allow_negative_stock')::boolean from public.shops s where s.id = public.current_shop_id()), false)
$$;
revoke execute on function public.allow_negative_stock() from public, anon, authenticated;

-- الكمية اللي لسه محتاجة تسوية لصنف في فرع (بيعات ما اتلغتش)
create or replace function public.uncosted_open(p_item uuid, p_branch uuid) returns bigint
language sql stable security definer set search_path = public as $$
  select coalesce(sum(u.qty - u.settled), 0)::bigint from public.uncosted_sales u
  where u.item_id = p_item and u.branch_id = p_branch and u.deleted_at is null and u.settled < u.qty
    and not exists (select 1 from public.journal_entries r where r.reverses_id = u.entry_id)
$$;
revoke execute on function public.uncosted_open(uuid, uuid) from public, anon, authenticated;

-- الخروج من المخزون: لو الإعداد مفتوح وفي بيع (app.uncosted = on)، اللي مش موجود بيخرج من غير تكلفة ويتسجل للتسوية
create or replace function public.ledger_issue(p_item uuid, p_qty bigint, p_entry uuid) returns bigint
language plpgsql security definer set search_path = public as $$
declare st record; cost bigint; b uuid; avail bigint; short bigint;
begin
  perform 1 from public.items where id = p_item and shop_id = public.current_shop_id() and deleted_at is null for update;
  if not found then raise exception 'E_NOT_FOUND'; end if;
  select e.branch_id into b from public.journal_entries e where e.id = p_entry;
  select * into st from public.item_stock_at(p_item, b);
  if p_qty <= 0 then raise exception 'E_STOCK'; end if;
  if st.qty < p_qty then
    if current_setting('app.uncosted', true) is distinct from 'on' or not public.allow_negative_stock() then raise exception 'E_STOCK'; end if;
    avail := greatest(st.qty, 0);
    short := p_qty - avail;
    cost := case when avail > 0 then public.ledger_issue_cost(st.qty, st.value, avail) else 0 end;
    insert into public.stock_moves(shop_id, item_id, entry_id, qty, value, branch_id) values (public.current_shop_id(), p_item, p_entry, -p_qty, -cost, b);
    insert into public.uncosted_sales(shop_id, branch_id, item_id, entry_id, qty) values (public.current_shop_id(), b, p_item, p_entry, short);
    return cost;
  end if;
  cost := public.ledger_issue_cost(st.qty, st.value, p_qty);
  insert into public.stock_moves(shop_id, item_id, entry_id, qty, value, branch_id) values (public.current_shop_id(), p_item, p_entry, -p_qty, -cost, b);
  return cost;
end $$;
revoke execute on function public.ledger_issue(uuid, bigint, uuid) from public, anon, authenticated;

-- التسوية: الوحدات اللي اتباعت من غير تكلفة بتاخد تكلفتها من اللي وصل (المتوسط المرجّح للفرع):
-- مدين تكلفة البضاعة المباعة / دائن المخزون، وحركة مخزون بالقيمة بس (من غير كمية)
create or replace function public.settle_uncosted(p_item uuid, p_branch uuid) returns void
language plpgsql security definer set search_path = public as $$
declare pend bigint; st record; units bigint; n bigint; v bigint; e uuid; old text := current_setting('app.branch', true); u record; left_ bigint;
begin
  pend := public.uncosted_open(p_item, p_branch);
  if pend <= 0 then return; end if;
  select * into st from public.item_stock_at(p_item, p_branch);
  -- القيمة الموجودة بتاعة (الكمية + اللي اتباع من غير تكلفة)
  units := st.qty + pend;
  if units <= 0 or st.value <= 0 then return; end if;
  n := least(pend, units);
  v := public.ledger_issue_cost(units, st.value, n);
  if v <= 0 then return; end if;
  perform set_config('app.branch', p_branch::text, true);
  e := public.ledger_post('cost_adjust', p_item, 'تسوية بيع بدون رصيد',
    jsonb_build_array(public.ledger_line(public.ledger_acc('cogs'), v, 0), public.ledger_line(public.ledger_acc('inventory'), 0, v)));
  insert into public.stock_moves(shop_id, item_id, entry_id, qty, value, branch_id) values (public.current_shop_id(), p_item, e, 0, -v, p_branch);
  perform set_config('app.branch', coalesce(old, ''), true);
  -- الأقدم الأول
  left_ := n;
  for u in select * from public.uncosted_sales where item_id = p_item and branch_id = p_branch and deleted_at is null and settled < qty
             and not exists (select 1 from public.journal_entries r where r.reverses_id = uncosted_sales.entry_id)
           order by created_at, id for update loop
    exit when left_ <= 0;
    update public.uncosted_sales set settled = settled + least(left_, u.qty - u.settled) where id = u.id;
    left_ := left_ - least(left_, u.qty - u.settled);
  end loop;
end $$;
revoke execute on function public.settle_uncosted(uuid, uuid) from public, anon, authenticated;

-- أي كمية بتدخل (شراء، رصيد، مرتجع، تحويل، رأس مال بضاعة): لو فيه بيع محتاج تسوية في الفرع ده، بيتسوى
create or replace function public.tg_move_settle() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if new.qty > 0 and not public.restoring() and exists (select 1 from public.uncosted_sales u where u.item_id = new.item_id and u.branch_id = new.branch_id and u.settled < u.qty and u.deleted_at is null) then
    perform public.settle_uncosted(new.item_id, new.branch_id);
  end if;
  return null;
end $$;
create trigger zz_move_settle after insert on public.stock_moves for each row execute function public.tg_move_settle();

-- عكس بيع اتسوّى فعلًا مرفوض (التسوية قيد تاني اتسجل خلاص). العكس قبل التسوية: الكمية بترجع والتسوية بتتلغي
create or replace function public.tg_reverse_settled() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if new.reverses_id is not null and exists (select 1 from public.uncosted_sales u where u.entry_id = new.reverses_id and u.settled > 0) then
    raise exception 'E_SETTLED';
  end if;
  return new;
end $$;
create trigger b_reverse_settled before insert on public.journal_entries for each row execute function public.tg_reverse_settled();

-- ---------- تسجيل كمية وتكلفة من نافذة البيع (أو أي مكان) ----------
-- بضاعة دخلت المحل من غير مورد (زي الرصيد الافتتاحي): مدين المخزون / دائن رأس المال، بصلاحية "يضيف" في المخزون
create or replace function public.stock_in(p_id uuid, p_item uuid, p_qty integer, p_unit_cost bigint, p_note text default null) returns uuid
language plpgsql security definer set search_path = public as $$
declare s uuid := public.current_shop_id(); e uuid; total bigint;
begin
  perform public.ledger_require(array['owner', 'reception']::public.app_role[]);
  perform public.perm_require('inventory', 'add');
  e := public.ledger_idem(p_id);
  if e is not null then return e; end if;
  if p_qty is null or p_qty <= 0 or p_qty > 100000 or p_unit_cost is null or p_unit_cost < 0 then raise exception 'E_BAD_AMOUNT'; end if;
  if not exists (select 1 from public.items where id = p_item and shop_id = s and deleted_at is null) then raise exception 'E_NOT_FOUND'; end if;
  total := p_qty::bigint * p_unit_cost;
  if total <= 0 then raise exception 'E_BAD_AMOUNT'; end if;
  perform public.ledger_amount(total);
  e := public.ledger_post('opening', p_item, coalesce(nullif(trim(p_note), ''), 'stock'),
    jsonb_build_array(public.ledger_line(public.ledger_acc('inventory'), total, 0), public.ledger_line(public.ledger_acc('capital'), 0, total)), null, p_id);
  insert into public.stock_moves(shop_id, item_id, entry_id, qty, value) values (s, p_item, e, p_qty, total);
  return e;
end $$;
revoke execute on function public.stock_in(uuid, uuid, integer, bigint, text) from public, anon;
grant execute on function public.stock_in(uuid, uuid, integer, bigint, text) to authenticated;

-- ---------- دوال موجودة اتعدّلت ----------
-- record_sale: (src: 0036_roles.sql)
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
    cost := public.ledger_issue(it.id, q, e);
    total_cost := total_cost + cost;
    if it.kind = 'part' then rev_parts := rev_parts + q * p; else rev_acc := rev_acc + q * p; end if;
  end loop;
  perform set_config('app.uncosted', 'off', true);
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

-- items_stock: (src: 0036_roles.sql) + تفاصيل الصنف و"محتاج تسوية"
drop function if exists public.items_stock(boolean);
create or replace function public.items_stock(p_all boolean default false) returns table(id uuid, kind text, name text, sku text, sale_price integer, qty bigint, avg_cost bigint, value bigint, min_qty integer, supplier_id uuid, short boolean, category text, barcode text, image_path text, brand text, item_type text, model text, quality text, color text, unsettled bigint)
language plpgsql stable security definer set search_path = public as $$
declare r public.app_role := public.current_app_role(); b uuid := public.op_branch(); everywhere boolean;
begin
  if r is null then raise exception 'E_FORBIDDEN'; end if;
  if not (public.has_perm('inventory', 'view') or public.has_perm('sales', 'view')) then raise exception 'E_FORBIDDEN'; end if;
  everywhere := p_all and r = 'owner';
  return query
  select i.id, i.kind, i.name, i.sku,
         case when r = 'technician' then null else i.sale_price end,
         coalesce(st.q, 0)::bigint,
         case when r = 'owner' and coalesce(st.q, 0) > 0 then (st.v / st.q)::bigint end,
         case when r = 'owner' then coalesce(st.v, 0)::bigint end,
         i.min_qty, case when r = 'owner' then i.supplier_id end,
         i.min_qty > 0 and coalesce(st.q, 0) <= i.min_qty,
         i.category, i.barcode, i.image_path, i.brand, i.item_type, i.model, i.quality, i.color,
         (select coalesce(sum(u.qty - u.settled), 0)::bigint from public.uncosted_sales u where u.item_id = i.id and u.deleted_at is null and u.settled < u.qty
            and (everywhere or u.branch_id = b) and not exists (select 1 from public.journal_entries rv where rv.reverses_id = u.entry_id))
  from public.items i
  left join (select m.item_id, sum(m.qty) as q, sum(m.value) as v from public.stock_moves m where everywhere or m.branch_id = b group by m.item_id) st on st.item_id = i.id
  where i.shop_id = public.current_shop_id() and i.deleted_at is null
  order by i.kind, i.name;
end $$;
revoke execute on function public.items_stock(boolean) from public, anon;
grant execute on function public.items_stock(boolean) to authenticated;

-- integrity_report: (src: 0029_partners.sql)
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
           where i.shop_id = s group by i.id
           -- (0037) كمية بالسالب مسموحة بقدر البيع اللي لسه محتاج تسوية بس
           having coalesce(sum(m.qty), 0) + (select coalesce(sum(u.qty - u.settled), 0) from public.uncosted_sales u where u.item_id = i.id and u.deleted_at is null and u.settled < u.qty and not exists (select 1 from public.journal_entries rv where rv.reverses_id = u.entry_id)) < 0
              or (coalesce(sum(m.qty), 0) = 0 and coalesce(sum(m.value), 0) <> 0) or coalesce(sum(m.value), 0) < 0 loop
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

-- backup_snapshot: (src: 0034_branches.sql)
create or replace function public.backup_snapshot(p_shop uuid) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare
  res jsonb := jsonb_build_object('format', 'warsha-backup', 'version', 1, 'generated_at', now(), 'shop_id', p_shop);
  t text;
  rows jsonb;
begin
  foreach t in array array['shops', 'branches', 'staff_branches', 'shop_branding', 'profiles', 'customers', 'devices', 'device_costs', 'status_log', 'device_notes', 'device_photos', 'device_checks',
                           'quote_decisions', 'message_templates', 'message_log', 'accounts', 'journal_entries', 'journal_lines', 'payments', 'drawer_closings',
                           'suppliers', 'items', 'stock_moves', 'uncosted_sales', 'purchases', 'labor_rates', 'specialties', 'staff_specialties', 'routes', 'repair_steps',
                           'repair_videos', 'device_ratings', 'issue_presets', 'partners', 'profit_distributions', 'party_links', 'shop_lists', 'audit_log'] loop
    execute format('select coalesce(jsonb_agg(to_jsonb(x)), ''[]''::jsonb) from public.%I x where x.shop_id = $1', t) into rows using p_shop;
    res := res || jsonb_build_object(t, rows);
  end loop;
  select coalesce(jsonb_agg(jsonb_build_object('device_id', device_id, 'kind', kind, 'erased_at', erased_at)), '[]'::jsonb)
    into rows from public.device_passcodes where shop_id = p_shop;
  return res || jsonb_build_object('device_passcodes', rows);
end $$;

-- restore_backup: (src: 0034_branches.sql)
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
                       'purchases', 'stock_moves', 'uncosted_sales', 'drawer_closings', 'message_log', 'audit_log'];
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

-- ---------- صنف جديد من أي نافذة (البيع، والشراء، والمرتجع، والهالك، والجرد، وقطع الجهاز) ----------
-- بصلاحية "يضيف" في المخزون (جدول الصلاحيات). والكمية والتكلفة اللي عندي (اختياري) بتتسجل في نفس العملية
create or replace function public.create_item(
  p_id uuid, p_kind text, p_name text, p_item_type text default null, p_brand text default null, p_model text default null,
  p_quality text default null, p_color text default null, p_sale_price integer default null, p_qty integer default null, p_unit_cost bigint default null,
  p_stock_id uuid default null
) returns uuid
language plpgsql security definer set search_path = public as $$
declare s uuid := public.current_shop_id(); nm text := trim(coalesce(p_name, ''));
begin
  perform public.ledger_require(array['owner', 'reception']::public.app_role[]);
  perform public.perm_require('inventory', 'add');
  if exists (select 1 from public.items where id = p_id and shop_id = s) then return p_id; end if;
  if p_kind not in ('part', 'accessory') or nm = '' or length(nm) > 160 then raise exception 'E_BAD_INPUT'; end if;
  if p_sale_price is not null and (p_sale_price < 0 or p_sale_price > 2000000000) then raise exception 'E_BAD_AMOUNT'; end if;
  insert into public.items(id, shop_id, kind, name, item_type, brand, model, quality, color, sale_price)
  values (p_id, s, p_kind, nm, nullif(trim(p_item_type), ''), nullif(trim(p_brand), ''), nullif(trim(p_model), ''), nullif(trim(p_quality), ''), nullif(trim(p_color), ''), p_sale_price);
  if coalesce(p_qty, 0) > 0 then
    if p_unit_cost is null or p_unit_cost <= 0 then raise exception 'E_BAD_AMOUNT'; end if;
    perform public.stock_in(coalesce(p_stock_id, gen_random_uuid()), p_id, p_qty, p_unit_cost, 'stock');
  end if;
  return p_id;
end $$;
revoke execute on function public.create_item(uuid, text, text, text, text, text, text, text, integer, integer, bigint, uuid) from public, anon;
grant execute on function public.create_item(uuid, text, text, text, text, text, text, text, integer, integer, bigint, uuid) to authenticated;

-- inventory_summary: (src: 0034_branches.sql) S6: فلتر بالنوع والماركة والموديل والجودة
drop function if exists public.inventory_summary(timestamptz, timestamptz, uuid);
create or replace function public.inventory_summary(p_from timestamptz, p_to timestamptz, p_branch uuid default null, p_filter jsonb default null) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare s uuid := public.current_shop_id(); res jsonb;
  -- S6: فلتر الأصناف (النوع والماركة والموديل والجودة) على أكتر الأصناف مبيعًا وقيمة المخزون بتاعتها
  fk text := nullif(trim(p_filter ->> 'item_type'), ''); fb text := nullif(trim(p_filter ->> 'brand'), '');
  fm text := nullif(trim(p_filter ->> 'model'), ''); fq text := nullif(trim(p_filter ->> 'quality'), '');
  has_f boolean := coalesce(fk, fb, fm, fq) is not null;
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
        where en.t = 'sale' and (fk is null or i.item_type = fk) and (fb is null or i.brand = fb) and (fm is null or i.model = fm) and (fq is null or i.quality = fq) group by i.id, i.name order by -sum(m.qty) desc limit case when has_f then 50 else 10 end) x), '[]'::jsonb),
    'filtered', case when has_f then (select jsonb_build_object('stock_value', coalesce(sum(m.value), 0), 'stock_qty', coalesce(sum(m.qty), 0), 'items', count(distinct i.id))
        from public.items i left join public.stock_moves m on m.item_id = i.id and (p_branch is null or m.branch_id = p_branch)
        where i.shop_id = s and i.deleted_at is null and (fk is null or i.item_type = fk) and (fb is null or i.brand = fb) and (fm is null or i.model = fm) and (fq is null or i.quality = fq)) end
  ) into res;
  res := res || jsonb_build_object('profit', (res->>'sales')::bigint - (res->>'sales_cost')::bigint - (res->>'wastage')::bigint - (res->>'return_diff')::bigint - (res->>'cost_adjust')::bigint);
  return res;
end $$;
revoke execute on function public.inventory_summary(timestamptz, timestamptz, uuid, jsonb) from public, anon;
grant execute on function public.inventory_summary(timestamptz, timestamptz, uuid, jsonb) to authenticated;
$m0037$;
  insert into public.app_migrations(version, how) values ('0037_item_details.sql', 'applied');
  raise notice 'applied %', '0037_item_details.sql';
end $run$;
commit;

-- ============================== 0038_roles_grant.sql ==============================
begin;
do $run$ begin
  if exists (select 1 from public.app_migrations where version = '0038_roles_grant.sql') then return; end if;
  execute $m0038$
-- 0038: P المرحلة التانية: صاحب المحل يقدر يدي الموظف صلاحيات ما كانتش عنده قبل كده (من جدول الصلاحيات).
-- الأقسام اللي بقت تتفتح للموظف: المشتريات، والوضع المالي، والتقارير، والتحويل بين الخزن، والهالك والتحويل لفرع، والمصروفات، وسجل النشاط.
-- اللي بيفضل لصاحب المحل بس: الإعدادات، والمرتبات، والشركاء، والنسخ الاحتياطي، والأدوار، والفروع، والجرد الافتتاحي.
-- الأدوار المبنية على "فني" عمرها ما بتاخد حاجة من دول (الفني ما يشوفش أسعار ولا أرباح): الدوال بتقبل owner وreception بس.
-- ومحدش بيكسب صلاحية لوحده: دور "استقبال" (اللي الموظفين الحاليين عليه) بيتشال منه "المصروفات" اللي ما كانتش شغالة.

-- قرار صاحب المشروع: "إضافة صنف جديد" صلاحية لوحدها في الجدول (item_create ← يضيف)، مقفولة لكل الأدوار ما عدا صاحب المحل
create or replace function public.perm_sections() returns text[]
language sql immutable as $$
  select array['devices', 'intake', 'customers', 'technicians', 'inventory', 'item_create', 'sales', 'purchases', 'cashbox', 'expenses', 'finance', 'partners', 'reports', 'staff', 'settings', 'audit']
$$;

-- الموظف معاه كل فروع المحل؟ (التقارير على مستوى المحل كله بتحتاج كده)
create or replace function public.all_my_branches() returns boolean
language sql stable security definer set search_path = public as $$
  select public.current_app_role() = 'owner' or not exists (
    select 1 from public.branches b where b.shop_id = public.current_shop_id() and b.deleted_at is null and not (b.id = any (public.my_branch_ids())))
$$;
revoke execute on function public.all_my_branches() from public, anon;
grant execute on function public.all_my_branches() to authenticated;

-- صاحب المحل، أو موظف (مش فني) ليه الصلاحية في الجدول. p_wide: العملية على مستوى المحل كله ← لازم كل الفروع
create or replace function public.grant_require(p_section text, p_op text, p_wide boolean default false) returns void
language plpgsql stable security definer set search_path = public as $$
begin
  perform public.ledger_require(array['owner', 'reception']::public.app_role[]);
  perform public.perm_require(p_section, p_op);
  if p_wide and not public.all_my_branches() then raise exception 'E_FORBIDDEN'; end if;
end $$;
revoke execute on function public.grant_require(text, text, boolean) from public, anon, authenticated;

-- ---------- الأدوار الجاهزة ----------
create or replace function public.preset_perms(p text) returns jsonb
language sql immutable as $$
  select case p
    when 'reception' then '{"devices":["view","add","edit","amounts","export"],"intake":["view","add"],"customers":["view","add","edit","export"],"technicians":["view"],"inventory":["view","add","edit","export"],"sales":["view","add","edit","export"],"cashbox":["view","add"]}'::jsonb
    when 'branch_manager' then '{"devices":["view","add","edit","amounts","export"],"intake":["view","add"],"customers":["view","add","edit","export"],"technicians":["view"],"inventory":["view","add","edit","delete","amounts","export"],"sales":["view","add","edit","export"],"purchases":["view","add","edit"],"cashbox":["view","add","edit"],"expenses":["view","add"],"finance":["view","amounts"],"reports":["view","export"],"audit":["view"]}'::jsonb
    when 'technician' then '{"devices":["view","edit"],"technicians":["view"],"inventory":["view"]}'::jsonb
    when 'cashier' then '{"customers":["view","add"],"inventory":["view","export"],"sales":["view","add","edit","export"],"cashbox":["view","add"]}'::jsonb
    when 'accountant' then '{"cashbox":["view"],"expenses":["view","add"],"inventory":["view","amounts","export"],"sales":["view","export"],"customers":["view"],"purchases":["view"],"finance":["view","amounts","export"],"reports":["view","export"],"audit":["view"]}'::jsonb
    else '{}'::jsonb end
$$;

-- دور "استقبال" الحالي: "المصروفات" كانت متعلّمة بس ما كانتش شغالة ← بتتشال عشان محدش يكسبها لوحده
update public.roles set perms = perms - 'expenses' where preset = 'reception' and deleted_at is null;
-- مدير الفرع والمحاسب: لو لسه زي ما اتعملوا (ما اتعدّلوش)، بياخدوا الصلاحيات الجديدة الجاهزة
update public.roles set perms = public.preset_perms(preset)
where deleted_at is null and preset = 'branch_manager'
  and perms = '{"devices":["view","add","edit","amounts","export"],"intake":["view","add"],"customers":["view","add","edit","export"],"technicians":["view"],"inventory":["view","add","edit","export"],"sales":["view","add","edit","export"],"cashbox":["view","add"],"expenses":["view","add"]}'::jsonb;
update public.roles set perms = public.preset_perms(preset)
where deleted_at is null and preset = 'accountant'
  and perms = '{"cashbox":["view"],"expenses":["view","add"],"inventory":["view","export"],"sales":["view","export"],"customers":["view"]}'::jsonb;
-- استثناءات "مسموح" لصلاحيات ما كانتش شغالة: بتتشال (عشان محدش يكسب حاجة لوحده)
update public.staff_overrides set deleted_at = now()
where deleted_at is null and allow
  and ((section in ('purchases', 'finance', 'reports', 'expenses', 'audit')) or (section = 'inventory' and op in ('delete', 'amounts')) or (section = 'cashbox' and op = 'edit'));

-- record_purchase: (src: 0012_spec_completion.sql) + الصلاحية من الجدول
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
  perform public.grant_require('purchases', 'add');
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

-- pay_supplier: (src: 0008_ledger.sql) + الصلاحية من الجدول
create or replace function public.pay_supplier(p_id uuid, p_supplier uuid, p_cashbox uuid, p_amount bigint, p_note text default null)
returns uuid
language plpgsql security definer set search_path = public as $$
declare cb public.accounts; e uuid;
begin
  perform public.grant_require('purchases', 'add');
  e := public.ledger_idem(p_id);
  if e is not null then return e; end if;
  perform public.ledger_amount(p_amount);
  cb := public.ledger_cashbox(p_cashbox);
  if not exists (select 1 from public.suppliers where id = p_supplier and shop_id = cb.shop_id and deleted_at is null) then raise exception 'E_NOT_FOUND'; end if;
  return public.ledger_post('supplier_payment', p_id, p_note, jsonb_build_array(
    public.ledger_line(public.ledger_acc('ap'), p_amount, 0, 'supplier', p_supplier),
    public.ledger_line(cb.id, 0, p_amount)), null, p_id);
end $$;

-- supplier_return: (src: 0027_inventory.sql) + الصلاحية من الجدول
create or replace function public.supplier_return(p_id uuid, p_supplier uuid, p_item uuid, p_qty integer, p_refund bigint, p_cashbox uuid default null, p_reason text default null) returns uuid
language plpgsql security definer set search_path = public as $$
declare s uuid := public.current_shop_id(); e uuid; cost bigint; diff bigint; cb uuid;
begin
  perform public.grant_require('purchases', 'edit');
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

-- item_suppliers: (src: 0012_spec_completion.sql) + الصلاحية من الجدول
create or replace function public.item_suppliers(p_item uuid)
returns table(supplier_id uuid, supplier text, last_cost bigint, min_cost bigint, last_at timestamptz, total_qty bigint)
language plpgsql stable security definer set search_path = public as $$
#variable_conflict use_column
begin
  perform public.grant_require('purchases', 'view');
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

-- write_off: (src: 0027_inventory.sql) + الصلاحية من الجدول
create or replace function public.write_off(p_id uuid, p_item uuid, p_qty integer, p_reason text) returns uuid
language plpgsql security definer set search_path = public as $$
declare s uuid := public.current_shop_id(); e uuid; cost bigint;
begin
  perform public.grant_require('inventory', 'delete');
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

-- transfer_stock: (src: 0034_branches.sql) + الصلاحية من الجدول
create or replace function public.transfer_stock(p_id uuid, p_item uuid, p_qty integer, p_from uuid, p_to uuid, p_note text default null) returns uuid
language plpgsql security definer set search_path = public as $$
declare s uuid := public.current_shop_id(); e uuid; cost bigint; inv uuid := public.ledger_acc('inventory');
begin
  perform public.grant_require('inventory', 'edit');
  perform public.grant_require('inventory', 'amounts');
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

-- item_moves: (src: 0027_inventory.sql) + الصلاحية من الجدول
create or replace function public.item_moves(p_item uuid) returns table(entry_id uuid, entry_no bigint, at timestamptz, source_type text, memo text, qty bigint, value bigint, balance_qty bigint, balance_value bigint, device_id uuid, order_no text, by text, reversed boolean)
language plpgsql stable security definer set search_path = public as $$
begin
  perform public.grant_require('inventory', 'amounts');
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

-- items_sold30: (src: 0033_assistant.sql) + الصلاحية من الجدول
create or replace function public.items_sold30() returns table(item_id uuid, qty bigint)
language plpgsql stable security definer set search_path = public as $$
begin
  perform public.grant_require('reports', 'view', true);
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

-- inventory_summary: (src: 0037_item_details.sql) + الصلاحية من الجدول
create or replace function public.inventory_summary(p_from timestamptz, p_to timestamptz, p_branch uuid default null, p_filter jsonb default null) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare s uuid := public.current_shop_id(); res jsonb;
  -- S6: فلتر الأصناف (النوع والماركة والموديل والجودة) على أكتر الأصناف مبيعًا وقيمة المخزون بتاعتها
  fk text := nullif(trim(p_filter ->> 'item_type'), ''); fb text := nullif(trim(p_filter ->> 'brand'), '');
  fm text := nullif(trim(p_filter ->> 'model'), ''); fq text := nullif(trim(p_filter ->> 'quality'), '');
  has_f boolean := coalesce(fk, fb, fm, fq) is not null;
begin
  perform public.grant_require('reports', 'view');
  -- الموظف: فروعه بس (لو مش معاه كل الفروع)
  if not public.all_my_branches() and (p_branch is null or not public.can_branch(p_branch)) then p_branch := public.op_branch(); end if;
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
        where en.t = 'sale' and (fk is null or i.item_type = fk) and (fb is null or i.brand = fb) and (fm is null or i.model = fm) and (fq is null or i.quality = fq) group by i.id, i.name order by -sum(m.qty) desc limit case when has_f then 50 else 10 end) x), '[]'::jsonb),
    'filtered', case when has_f then (select jsonb_build_object('stock_value', coalesce(sum(m.value), 0), 'stock_qty', coalesce(sum(m.qty), 0), 'items', count(distinct i.id))
        from public.items i left join public.stock_moves m on m.item_id = i.id and (p_branch is null or m.branch_id = p_branch)
        where i.shop_id = s and i.deleted_at is null and (fk is null or i.item_type = fk) and (fb is null or i.brand = fb) and (fm is null or i.model = fm) and (fq is null or i.quality = fq)) end
  ) into res;
  res := res || jsonb_build_object('profit', (res->>'sales')::bigint - (res->>'sales_cost')::bigint - (res->>'wastage')::bigint - (res->>'return_diff')::bigint - (res->>'cost_adjust')::bigint);
  return res;
end $$;

-- tech_report: (src: 0017_growth.sql) + الصلاحية من الجدول
create or replace function public.tech_report(p_from timestamptz, p_to timestamptz)
returns table(tech_id uuid, name text, devices integer, steps integer, avg_minutes integer, returns integer, return_rate integer, revenue bigint, rating numeric, ratings integer, points integer)
language plpgsql stable security definer set search_path = public as $$
#variable_conflict use_column
declare s uuid := public.current_shop_id();
begin
  perform public.grant_require('reports', 'view', true);
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

-- issue_report: (src: 0034_branches.sql) + الصلاحية من الجدول
create or replace function public.issue_report(p_from timestamptz, p_to timestamptz, p_branch uuid default null)
returns table(route_id uuid, code text, name text, devices integer, revenue bigint, parts bigint, profit bigint)
language plpgsql stable security definer set search_path = public as $$
#variable_conflict use_column
begin
  perform public.grant_require('reports', 'view');
  -- الموظف: فروعه بس (لو مش معاه كل الفروع)
  if not public.all_my_branches() and (p_branch is null or not public.can_branch(p_branch)) then p_branch := public.op_branch(); end if;
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

-- financial_position: (src: 0034_branches.sql) + الصلاحية من الجدول
create or replace function public.financial_position(p_from timestamptz, p_to timestamptz, p_branch uuid default null) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare
  s uuid := public.current_shop_id();
  res jsonb;
begin
  perform public.grant_require('finance', 'view');
  -- الموظف: فروعه بس (لو مش معاه كل الفروع)
  if not public.all_my_branches() and (p_branch is null or not public.can_branch(p_branch)) then p_branch := public.op_branch(); end if;
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

-- pl_breakdown: (src: 0034_branches.sql) + الصلاحية من الجدول
create or replace function public.pl_breakdown(p_from timestamptz, p_to timestamptz, p_branch uuid default null)
returns table(account_id uuid, code text, name text, type public.account_type, amount bigint)
language plpgsql stable security definer set search_path = public as $$
begin
  perform public.grant_require('finance', 'view');
  -- الموظف: فروعه بس (لو مش معاه كل الفروع)
  if not public.all_my_branches() and (p_branch is null or not public.can_branch(p_branch)) then p_branch := public.op_branch(); end if;
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

-- cashbox_daily: (src: 0011_finance_drilldown.sql) + الصلاحية من الجدول
create or replace function public.cashbox_daily(p_from timestamptz, p_to timestamptz)
returns table(cashbox uuid, day date, net bigint)
language plpgsql stable security definer set search_path = public as $$
begin
  perform public.grant_require('finance', 'view', true);
  return query
  select l.account_id, (date_trunc('day', e.occurred_at at time zone 'Africa/Cairo'))::date, sum(l.debit - l.credit)::bigint
  from public.journal_lines l
  join public.accounts a on a.id = l.account_id and a.kind = 'cash'
  join public.journal_entries e on e.id = l.entry_id
  where l.shop_id = public.current_shop_id() and e.occurred_at >= p_from and e.occurred_at < p_to
  group by 1, 2
  order by 2;
end $$;

-- party_balances: (src: 0012_spec_completion.sql) + الصلاحية من الجدول
create or replace function public.party_balances(p_kind text)
returns table(party_type text, party_id uuid, name text, account text, balance bigint, oldest timestamptz)
language plpgsql stable security definer set search_path = public as $$
#variable_conflict use_column
declare s uuid := public.current_shop_id();
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

-- statement: (src: 0030_party_links.sql) + الصلاحية من الجدول
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
  perform public.grant_require('finance', 'view');
  -- المرتبات والشركاء لصاحب المحل بس، والخزنة لازم تكون في فروع الموظف
  if public.current_app_role() <> 'owner' and (p_kind in ('employee', 'partner')
     or (p_kind = 'cashbox' and not exists (select 1 from public.accounts a where a.id = p_id and public.can_branch(a.branch_id)))) then raise exception 'E_FORBIDDEN'; end if;
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

-- transfer_cash: (src: 0008_ledger.sql) + الصلاحية من الجدول
create or replace function public.transfer_cash(p_id uuid, p_from uuid, p_to uuid, p_amount bigint, p_note text default null)
returns uuid
language plpgsql security definer set search_path = public as $$
declare a public.accounts; b public.accounts; e uuid;
begin
  perform public.grant_require('cashbox', 'edit');
  e := public.ledger_idem(p_id);
  if e is not null then return e; end if;
  perform public.ledger_amount(p_amount);
  a := public.ledger_cashbox(p_from);
  b := public.ledger_cashbox(p_to);
  if a.id = b.id then raise exception 'E_SAME_CASHBOX'; end if;
  if public.ledger_balance(a.id) < p_amount then raise exception 'E_INSUFFICIENT'; end if;
  return public.ledger_post('transfer', p_id, p_note, jsonb_build_array(public.ledger_line(b.id, p_amount, 0), public.ledger_line(a.id, 0, p_amount)), null, p_id);
end $$;

-- record_expense: (src: 0036_roles.sql) + الصلاحية من الجدول
create or replace function public.record_expense(p_id uuid, p_account uuid, p_cashbox uuid, p_amount bigint, p_note text default null)
returns uuid
language plpgsql security definer set search_path = public as $$
declare cb public.accounts; e uuid;
begin
  perform public.grant_require('expenses', 'add');
  e := public.ledger_idem(p_id);
  if e is not null then return e; end if;
  perform public.ledger_amount(p_amount);
  cb := public.ledger_cashbox(p_cashbox);
  if not exists (select 1 from public.accounts where id = p_account and shop_id = cb.shop_id and kind = 'expense' and active and deleted_at is null) then raise exception 'E_BAD_ACCOUNT'; end if;
  return public.ledger_post('expense', p_id, p_note, jsonb_build_array(public.ledger_line(p_account, p_amount, 0), public.ledger_line(cb.id, 0, p_amount)), null, p_id);
end $$;

-- items_stock: (src: 0037_item_details.sql) + المبالغ بالصلاحية
create or replace function public.items_stock(p_all boolean default false) returns table(id uuid, kind text, name text, sku text, sale_price integer, qty bigint, avg_cost bigint, value bigint, min_qty integer, supplier_id uuid, short boolean, category text, barcode text, image_path text, brand text, item_type text, model text, quality text, color text, unsettled bigint)
language plpgsql stable security definer set search_path = public as $$
declare r public.app_role := public.current_app_role(); b uuid := public.op_branch(); everywhere boolean;
  amt boolean := r = 'owner' or (r = 'reception' and public.has_perm('inventory', 'amounts'));
begin
  if r is null then raise exception 'E_FORBIDDEN'; end if;
  if not (public.has_perm('inventory', 'view') or public.has_perm('sales', 'view')) then raise exception 'E_FORBIDDEN'; end if;
  everywhere := p_all and r = 'owner';
  return query
  select i.id, i.kind, i.name, i.sku,
         case when r = 'technician' then null else i.sale_price end,
         coalesce(st.q, 0)::bigint,
         case when amt and coalesce(st.q, 0) > 0 then (st.v / st.q)::bigint end,
         case when amt then coalesce(st.v, 0)::bigint end,
         i.min_qty, case when amt then i.supplier_id end,
         i.min_qty > 0 and coalesce(st.q, 0) <= i.min_qty,
         i.category, i.barcode, i.image_path, i.brand, i.item_type, i.model, i.quality, i.color,
         (select coalesce(sum(u.qty - u.settled), 0)::bigint from public.uncosted_sales u where u.item_id = i.id and u.deleted_at is null and u.settled < u.qty
            and (everywhere or u.branch_id = b) and not exists (select 1 from public.journal_entries rv where rv.reverses_id = u.entry_id))
  from public.items i
  left join (select m.item_id, sum(m.qty) as q, sum(m.value) as v from public.stock_moves m where everywhere or m.branch_id = b group by m.item_id) st on st.item_id = i.id
  where i.shop_id = public.current_shop_id() and i.deleted_at is null
  order by i.kind, i.name;
end $$;

-- create_item: (src: 0037_item_details.sql) + صلاحية "إضافة صنف جديد"
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
  if p_kind not in ('part', 'accessory') or nm = '' or length(nm) > 160 then raise exception 'E_BAD_INPUT'; end if;
  if p_sale_price is not null and (p_sale_price < 0 or p_sale_price > 2000000000) then raise exception 'E_BAD_AMOUNT'; end if;
  insert into public.items(id, shop_id, kind, name, item_type, brand, model, quality, color, sale_price)
  values (p_id, s, p_kind, nm, nullif(trim(p_item_type), ''), nullif(trim(p_brand), ''), nullif(trim(p_model), ''), nullif(trim(p_quality), ''), nullif(trim(p_color), ''), p_sale_price);
  if coalesce(p_qty, 0) > 0 then
    if p_unit_cost is null or p_unit_cost <= 0 then raise exception 'E_BAD_AMOUNT'; end if;
    perform public.stock_in(coalesce(p_stock_id, gen_random_uuid()), p_id, p_qty, p_unit_cost, 'stock');
  end if;
  return p_id;
end $$;

-- ---------- القراية (RLS): للموظف (مش الفني) اللي معاه الصلاحية، وفي فروعه بس ----------
create policy staff_entries_select on public.journal_entries for select to authenticated
  using (shop_id = public.current_shop_id() and public.current_app_role() = 'reception' and (select public.has_perm('finance', 'view')) and public.can_branch(branch_id));
create policy staff_lines_select on public.journal_lines for select to authenticated
  using (shop_id = public.current_shop_id() and public.current_app_role() = 'reception' and (select public.has_perm('finance', 'view'))
         and exists (select 1 from public.journal_entries e where e.id = entry_id and public.can_branch(e.branch_id)));
create policy staff_accounts_select on public.accounts for select to authenticated
  using (shop_id = public.current_shop_id() and public.current_app_role() = 'reception' and (select public.has_perm('finance', 'view'))
         and (kind <> 'cash' or public.can_branch(branch_id)) and kind not in ('advances', 'salaries', 'partner_capital', 'partner_current'));
create policy staff_moves_select on public.stock_moves for select to authenticated
  using (shop_id = public.current_shop_id() and public.current_app_role() = 'reception' and (select public.has_perm('inventory', 'amounts')) and public.can_branch(branch_id));
create policy staff_suppliers_select on public.suppliers for select to authenticated
  using (shop_id = public.current_shop_id() and public.current_app_role() = 'reception' and (select public.has_perm('purchases', 'view')));
create policy staff_suppliers_insert on public.suppliers for insert to authenticated
  with check (shop_id = public.current_shop_id() and public.current_app_role() = 'reception' and (select public.has_perm('purchases', 'add')));
create policy staff_suppliers_update on public.suppliers for update to authenticated
  using (shop_id = public.current_shop_id() and public.current_app_role() = 'reception' and (select public.has_perm('purchases', 'edit')));
create policy staff_audit_select on public.audit_log for select to authenticated
  using (shop_id = public.current_shop_id() and public.current_app_role() = 'reception' and (select public.has_perm('audit', 'view')));
$m0038$;
  insert into public.app_migrations(version, how) values ('0038_roles_grant.sql', 'applied');
  raise notice 'applied %', '0038_roles_grant.sql';
end $run$;
commit;

select 3 as part, 7 as parts, count(*) as applied_files, max(version) as latest,
  case when '0038_roles_grant.sql' in (select version from public.app_migrations) then
    'الجزء 3 خلص. اللي بعده: upgrade_part_4.sql'
  else 'فيه ملف ما اتطبقش' end as status
from public.app_migrations;
