-- جوالك / Gawalak: ترقية مشروع Supabase لآخر نسخة، الجزء 5 من 7 (الملفات 0057_categories.sql لـ 0069_sale_errors.sql).
-- بيتولد تلقائيًا: npm run db:setup-file. ما تعدّلوش بإيدك.
-- شغّل الأجزاء بالترتيب في SQL Editor (كل جزء لوحده: New query ← الصق ← Run): upgrade_part_1.sql ثم upgrade_part_2.sql ثم upgrade_part_3.sql ثم upgrade_part_4.sql ثم upgrade_part_5.sql ثم upgrade_part_6.sql ثم upgrade_part_7.sql.
-- آمن تشغّل أي جزء أكتر من مرة: اللي اتطبق قبل كده بيتخطى. ولو ملف فشل، اللي قبله بيفضل، وصلّح السبب وشغّل نفس الجزء تاني.
-- لو لقى ملف أحدث موجود وأقدم منه ناقص بيقف (E_UPGRADE_GAP). ولو جزء قبله لسه ما اتطبقش بيقف (E_UPGRADE_ORDER). الاتنين من غير تغيير.
-- ملفات الجزء ده: 0057_categories.sql, 0058_web_push.sql, 0059_counters_branch.sql, 0060_sale_lines.sql, 0061_attendance.sql, 0062_vat.sql, 0063_cheques.sql, 0064_day_report.sql, 0065_cheque_pending.sql, 0066_commission_net.sql, 0067_idem_lock.sql, 0068_stock_adjust.sql, 0069_sale_errors.sql

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
  select min(v) into miss from unnest(files) v where v < '0057_categories.sql' and v not in (select version from public.app_migrations);
  if miss is not null then raise exception 'E_UPGRADE_ORDER: الملف % لسه ما اتطبقش. شغّل upgrade_part_%.sql الأول، وبعدين الجزء ده (5).', miss, parts[array_position(files, miss)]; end if;
end $ord$;

-- 3) ملفات الجزء 5 بالترتيب، كل ملف في transaction لوحده
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
  -- بترجع زي ما Postgres بيحفظها بالظبط (من غير public.)، فالسياسة الملفوفة قبل كده بتتخطى فعلًا
  return regexp_replace(t, '@@(current_shop_id|current_app_role)@@', '\1()', 'g');
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

-- ============================== 0062_vat.sql ==============================
begin;
do $run$ begin
  if exists (select 1 from public.app_migrations where version = '0062_vat.sql') then return; end if;
  execute $m0062$
-- ============================================================
-- 0062: R5 ضريبة القيمة المضافة الاختيارية (لكل محل مسجّل)
-- - مقفولة افتراضيًا. صاحب المحل بيفتحها من الإعدادات (shops.extras.vat: enabled، rate_bp، reg_no).
-- - السعر شامل الضريبة دايمًا: العميل بيدفع نفس المبلغ، والقيد بيفصل "ضريبة مستحقة" (التزام) عن الإيراد.
--   الضريبة = round(المبلغ × النسبة ÷ (1 + النسبة)) بالقروش، لكل نوع إيراد لوحده (قطع، إكسسوار، خدمة/صيانة).
-- - النسبة بتتاخد ساعة القيد وبتتخزن في القيد نفسه، فتغييرها بعدين ما بيغيّرش القديم.
-- - البيع والتسليم بس. الإلغاء بقيد عكسي (reverse_entry) بيرجّع الضريبة لوحده.
-- - سداد الضريبة للمصلحة: pay_vat (صاحب المحل بس)، وتقرير الضريبة للفترة: vat_report.
-- - الفاتورة الإلكترونية والإيصال الإلكتروني لسه ممنوعين (CLAUDE.md)، ده تجهيز بس.
-- ============================================================

-- ---------- حساب "ضريبة القيمة المضافة المستحقة" ----------
alter table public.accounts drop constraint if exists accounts_kind_check;
alter table public.accounts add constraint accounts_kind_check check (kind = any (array[
  'cash', 'receivable', 'advances', 'inventory', 'payable', 'salaries', 'capital', 'drawings', 'revenue', 'cogs', 'expense', 'shortage', 'overage',
  'partner_capital', 'partner_current', 'retained', 'fixed_asset', 'tax']));

alter table public.journal_entries drop constraint if exists journal_entries_source_type_check;
alter table public.journal_entries add constraint journal_entries_source_type_check check (source_type = any (array[
  'payment', 'delivery', 'purchase', 'supplier_payment', 'part_use', 'sale', 'expense', 'salary', 'salary_payment', 'advance', 'advance_settle',
  'capital', 'drawing', 'transfer', 'drawer_close', 'reversal', 'cost_adjust', 'write_off', 'supplier_return', 'sale_return', 'opening',
  'partner_capital', 'partner_withdrawal', 'profit_distribution', 'netting', 'stock_transfer', 'commission', 'bonus', 'penalty', 'vat_payment']));

-- ---------- النسبة والحساب ----------
-- النسبة بالـ basis points (1400 = 14%). مقفولة أو قيمة مش سليمة = 0. أقصى حاجة 30%
create or replace function public.vat_bp(p_shop uuid) returns integer
language sql stable security definer set search_path = public as $$
  select case
    -- true كـ boolean بس (مش نص)، زي readVat في الواجهة
    when (sh.extras -> 'vat' -> 'enabled') is distinct from 'true'::jsonb then 0
    when coalesce(sh.extras -> 'vat' ->> 'rate_bp', '') !~ '^[0-9]{1,5}$' then 1400
    else least((sh.extras -> 'vat' ->> 'rate_bp')::integer, 3000)
  end
  from public.shops sh where sh.id = p_shop
$$;
revoke execute on function public.vat_bp(uuid) from public, anon, authenticated;

-- الضريبة جوه مبلغ شامل: round(g × bp ÷ (10000 + bp))، تقريب نص لفوق، أعداد صحيحة بس
create or replace function public.vat_of(p_gross bigint, p_bp integer) returns bigint
language sql immutable as $$
  select case when coalesce(p_bp, 0) <= 0 or coalesce(p_gross, 0) <= 0 then 0::bigint
    else (p_gross * p_bp * 2 + (10000 + p_bp)) / (2 * (10000 + p_bp)) end
$$;
revoke execute on function public.vat_of(bigint, integer) from public, anon;
grant execute on function public.vat_of(bigint, integer) to authenticated;

-- حساب الضريبة لكل المحلات الموجودة.
-- warsha.system: الترقية بتشتغل من SQL Editor من غير مستخدم، وtg_force_shop_id كان بيرفض (E_NO_SHOP) لو فيه محلات
do $vat$
begin
  perform set_config('warsha.system', 'on', true);
  insert into public.accounts(shop_id, code, type, kind)
  select sh.id, 'vat_payable', 'liability', 'tax' from public.shops sh
  on conflict (shop_id, code) where code is not null do nothing;
  perform set_config('warsha.system', 'off', true);
end $vat$;

-- ---------- ضريبة جهاز اتسلّم (للفاتورة والإيصال) ----------
-- من قيد التسليم نفسه (مش من النسبة الحالية). الفني لأ (مفيش أسعار)
create or replace function public.device_vat(p_device uuid) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare s uuid := public.current_shop_id(); r public.app_role := public.current_app_role(); v bigint; g bigint;
begin
  if s is null or r is null or r = 'technician' or r = 'marketing' then raise exception 'E_FORBIDDEN'; end if;
  select coalesce(sum(l.credit) filter (where a.kind = 'tax'), 0), coalesce(sum(l.credit) filter (where a.kind in ('tax', 'revenue')), 0)
    into v, g
  from public.journal_entries e join public.journal_lines l on l.entry_id = e.id join public.accounts a on a.id = l.account_id
  where e.shop_id = s and e.source_type = 'delivery' and e.source_id = p_device
    and not exists (select 1 from public.journal_entries x where x.reverses_id = e.id);
  if g = 0 then return null; end if;
  return jsonb_build_object('vat', v, 'gross', g, 'net', g - v);
end $$;
revoke execute on function public.device_vat(uuid) from public, anon;
grant execute on function public.device_vat(uuid) to authenticated;

-- ---------- سداد الضريبة للمصلحة ----------
create or replace function public.pay_vat(p_id uuid, p_cashbox uuid, p_amount bigint, p_note text default null)
returns uuid
language plpgsql security definer set search_path = public as $$
declare cb public.accounts; e uuid;
begin
  perform public.ledger_require(array['owner']::public.app_role[]);
  e := public.ledger_idem(p_id);
  if e is not null then return e; end if;
  perform public.ledger_amount(p_amount);
  cb := public.ledger_cashbox(p_cashbox);
  if public.ledger_acc('vat_payable') is null then raise exception 'E_NOT_FOUND'; end if;
  return public.ledger_post('vat_payment', p_id, p_note, jsonb_build_array(
    public.ledger_line(public.ledger_acc('vat_payable'), p_amount, 0), public.ledger_line(cb.id, 0, p_amount)), null, p_id);
end $$;
revoke execute on function public.pay_vat(uuid, uuid, bigint, text) from public, anon;
grant execute on function public.pay_vat(uuid, uuid, bigint, text) to authenticated;

-- ---------- تقرير الضريبة للفترة ----------
-- من الدفتر بس: ضريبة المبيعات والصيانة (والصافي قبلها)، والمرتجع بالإلغاء، والمدفوع للمصلحة، والرصيد المستحق لحد آخر الفترة
create or replace function public.vat_report(p_from timestamptz, p_to timestamptz, p_branch uuid default null) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare
  s uuid := public.current_shop_id();
  res jsonb;
begin
  perform public.grant_require('finance', 'view');
  if p_from is null or p_to is null or p_to <= p_from then raise exception 'E_BAD_INPUT'; end if;
  if not public.all_my_branches() and (p_branch is null or not public.can_branch(p_branch)) then p_branch := public.op_branch(); end if;
  with ln as (
    -- قيد الإلغاء بيتحسب على نوع القيد الأصلي (بيع أو تسليم)
    select coalesce(o.source_type, e.source_type) as src, e.source_type as own, a.kind, l.debit, l.credit
    from public.journal_entries e
    join public.journal_lines l on l.entry_id = e.id
    join public.accounts a on a.id = l.account_id
    left join public.journal_entries o on o.id = e.reverses_id
    where e.shop_id = s and e.occurred_at >= p_from and e.occurred_at < p_to
      -- السداد على المحل كله (الضريبة على المحل مش الفرع)، والباقي بفلتر الفرع
      and (p_branch is null or e.branch_id = p_branch or coalesce(o.source_type, e.source_type) = 'vat_payment')
      and a.kind in ('tax', 'revenue')
      and coalesce(o.source_type, e.source_type) in ('sale', 'delivery', 'vat_payment', 'sale_return')
  ),
  -- الحركات اللي فيها ضريبة بس (الصافي قبل الضريبة = إيراد نفس القيود)
  tx as (
    select e.id from public.journal_entries e join public.journal_lines l on l.entry_id = e.id join public.accounts a on a.id = l.account_id
    where e.shop_id = s and e.occurred_at >= p_from and e.occurred_at < p_to and (p_branch is null or e.branch_id = p_branch) and a.kind = 'tax'
    group by e.id
  ),
  net as (
    -- الصافي قبل الضريبة من البيع والتسليم الأصليين بس (زي ضريبتهم). الإلغاء والمرتجع في سطر "ضريبة مرتجعة"
    select e.source_type as src, coalesce(sum(l.credit - l.debit), 0)::bigint as v
    from tx join public.journal_entries e on e.id = tx.id
    join public.journal_lines l on l.entry_id = e.id join public.accounts a on a.id = l.account_id
    where a.kind = 'revenue' and e.reverses_id is null and e.source_type in ('sale', 'delivery') group by 1
  )
  select jsonb_build_object(
    'from', p_from, 'to', p_to, 'branch', p_branch, 'rate_bp', public.vat_bp(s),
    'sales_vat', coalesce(sum(credit) filter (where kind = 'tax' and src = 'sale' and own <> 'reversal'), 0),
    'repair_vat', coalesce(sum(credit) filter (where kind = 'tax' and src = 'delivery' and own <> 'reversal'), 0),
    -- المرتجع: إلغاء بيع أو تسليم بقيد عكسي، أو مرتجع من عميل
    'reversed_vat', coalesce(sum(debit - credit) filter (where kind = 'tax' and ((own = 'reversal' and src in ('sale', 'delivery')) or src = 'sale_return')), 0),
    'paid', coalesce(sum(debit) filter (where kind = 'tax' and src = 'vat_payment' and own <> 'reversal'), 0)
      - coalesce(sum(credit) filter (where kind = 'tax' and src = 'vat_payment' and own = 'reversal'), 0),
    'sales_net', coalesce((select v from net where src = 'sale'), 0),
    'repair_net', coalesce((select v from net where src = 'delivery'), 0),
    -- المستحق لحد آخر الفترة (كل الفروع: الضريبة على المحل كله)
    'due', coalesce((select sum(l.credit - l.debit) from public.journal_lines l join public.journal_entries e on e.id = l.entry_id
                     join public.accounts a on a.id = l.account_id where e.shop_id = s and a.kind = 'tax' and e.occurred_at < p_to), 0)::bigint
  ) into res from ln;
  return res;
end $$;
revoke execute on function public.vat_report(timestamptz, timestamptz, uuid) from public, anon;
grant execute on function public.vat_report(timestamptz, timestamptz, uuid) to authenticated;


-- ---------- الدوال اللي اتعدلت ----------
-- ensure_ledger_accounts: (src: 0027_inventory.sql) + vat_payable
create or replace function public.ensure_ledger_accounts(p_shop uuid) returns void
language plpgsql security definer set search_path = public as $$
declare m text;
begin
  insert into public.accounts(shop_id, code, type, kind)
  select p_shop, v.code, v.type::public.account_type, v.kind from (values
    ('ar', 'asset', 'receivable'), ('advances', 'asset', 'advances'), ('inventory', 'asset', 'inventory'),
    ('ap', 'liability', 'payable'), ('salaries_payable', 'liability', 'salaries'), ('vat_payable', 'liability', 'tax'),
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

-- record_sale: (src: 0060_sale_lines.sql) + فصل الضريبة
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
  bp integer := public.vat_bp(s); v_parts bigint := 0; v_acc bigint := 0; v_srv bigint := 0;
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
  -- R5: السعر شامل الضريبة. الضريبة بتتفصل من كل نوع إيراد لوحده، ومجموعها في حساب الضريبة المستحقة
  if bp > 0 then
    v_parts := public.vat_of(rev_parts, bp); v_acc := public.vat_of(rev_acc, bp); v_srv := public.vat_of(rev_srv, bp);
    if v_parts + v_acc + v_srv > 0 then
      insert into public.journal_lines(shop_id, entry_id, account_id, debit, credit) values (s, e, public.ledger_acc('vat_payable'), 0, v_parts + v_acc + v_srv);
    end if;
  end if;
  if rev_parts > 0 then insert into public.journal_lines(shop_id, entry_id, account_id, debit, credit) values (s, e, public.ledger_acc('rev_parts'), 0, rev_parts - v_parts); end if;
  if rev_acc > 0 then insert into public.journal_lines(shop_id, entry_id, account_id, debit, credit) values (s, e, public.ledger_acc('rev_accessories'), 0, rev_acc - v_acc); end if;
  if rev_srv > 0 then insert into public.journal_lines(shop_id, entry_id, account_id, debit, credit) values (s, e, public.ledger_acc('rev_repair'), 0, rev_srv - v_srv); end if;
  if total_cost > 0 then
    insert into public.journal_lines(shop_id, entry_id, account_id, debit, credit) values
      (s, e, public.ledger_acc('cogs'), total_cost, 0), (s, e, public.ledger_acc('inventory'), 0, total_cost);
  end if;
  if p_cashbox is not null and p_customer is not null then
    null; -- البيع النقدي لعميل معروف ما بيأثرش على رصيده
  end if;
  return e;
end $$;

-- tg_device_revenue: (src: 0008_ledger.sql) + فصل الضريبة
create or replace function public.tg_device_revenue() returns trigger
language plpgsql security definer set search_path = public as $$
declare fc integer; v bigint;
begin
  if new.status = 'delivered' and old.status is distinct from 'delivered'
     and not exists (select 1 from public.journal_entries e where e.source_type = 'delivery' and e.source_id = new.id
                     and not exists (select 1 from public.journal_entries r where r.reverses_id = e.id)) then
    select final_cost into fc from public.device_costs where device_id = new.id and deleted_at is null;
    if coalesce(fc, 0) > 0 then
      -- R5: التكلفة النهائية شاملة الضريبة (لو المحل مسجّل)
      v := public.vat_of(fc, public.vat_bp(new.shop_id));
      perform public.ledger_post('delivery', new.id, new.order_no, jsonb_build_array(
        public.ledger_line(public.ledger_acc('ar'), fc, 0, 'customer', new.customer_id),
        public.ledger_line(public.ledger_acc('rev_repair'), 0, fc - v))
        || case when v > 0 then jsonb_build_array(public.ledger_line(public.ledger_acc('vat_payable'), 0, v)) else '[]'::jsonb end, new.id);
    end if;
  end if;
  return null;
end $$;

-- sale_invoice: (src: 0060_sale_lines.sql) + الضريبة ورقم التسجيل
create or replace function public.sale_invoice(p_entry uuid) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare
  s uuid := public.current_shop_id(); r public.app_role := public.current_app_role();
  o public.journal_entries; ls jsonb; old boolean := false;
  total bigint; vat bigint; paid bigint; due bigint; cust uuid; cname text; cphone text; rev_no integer;
begin
  if s is null or r is null or r = 'technician' then raise exception 'E_FORBIDDEN'; end if;
  select * into o from public.journal_entries where id = p_entry and shop_id = s and source_type = 'sale';
  if not found then raise exception 'E_NOT_FOUND'; end if;
  if r <> 'owner' and not ((public.has_perm('sales', 'add') or public.has_perm('finance', 'view')) and public.can_branch(o.branch_id)) then
    raise exception 'E_FORBIDDEN';
  end if;
  -- المبالغ من الدفتر: الإجمالي = الإيراد، والمدفوع = اللي دخل الخزنة، والباقي = على العميل
  select coalesce(sum(l.credit) filter (where a.type = 'revenue' or a.kind = 'tax'), 0),
         coalesce(sum(l.credit) filter (where a.kind = 'tax'), 0),
         coalesce(sum(l.debit) filter (where a.kind = 'cash'), 0),
         coalesce(sum(l.debit) filter (where a.kind = 'receivable'), 0),
         max(l.party_id::text) filter (where l.party_type = 'customer')::uuid
    into total, vat, paid, due, cust
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
    'lines', coalesce(ls, '[]'::jsonb), 'legacy', old, 'total', total, 'vat', vat, 'net', total - vat,
    'vat_no', case when vat > 0 then (select nullif(trim(sh.extras -> 'vat' ->> 'reg_no'), '') from public.shops sh where sh.id = s) end,
    'paid', paid, 'due', due,
    'customer', cname, 'phone', cphone, 'cancelled_by', rev_no);
end $$;

-- financial_position: (src: 0038_roles_grant.sql) + الضريبة المستحقة
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
      (coalesce(sum(greatest(b, 0)) filter (where kind in ('payable', 'salaries', 'tax')), 0)
        + coalesce(sum(greatest(-b, 0)) filter (where kind in ('receivable', 'advances')), 0)
        + coalesce(sum(greatest(-b, 0)) filter (where kind = 'inventory'), 0))::bigint as payables,
      coalesce(sum(greatest(-b, 0)) filter (where kind in ('payable', 'salaries', 'tax')), 0)::bigint as payables_debit,
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
    -- الضريبة على المحل كله (مش الفرع المختار)
    'vat_due', (select coalesce(sum(l.credit - l.debit), 0)::bigint from public.journal_lines l join public.accounts a on a.id = l.account_id where l.shop_id = s and a.kind = 'tax'),
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

-- sale_return: (src: 0036_roles.sql) + الضريبة من المبلغ المرتجع
create or replace function public.sale_return(p_id uuid, p_item uuid, p_qty integer, p_refund bigint, p_cashbox uuid default null, p_customer uuid default null, p_restock boolean default true, p_reason text default null) returns uuid
language plpgsql security definer set search_path = public as $$
declare s uuid := public.current_shop_id(); e uuid; it public.items; cost bigint; cb uuid; rev uuid; v bigint;
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
$m0062$;
  insert into public.app_migrations(version, how) values ('0062_vat.sql', 'applied');
  raise notice 'applied %', '0062_vat.sql';
end $run$;
commit;

-- ============================== 0063_cheques.sql ==============================
begin;
do $run$ begin
  if exists (select 1 from public.app_migrations where version = '0063_cheques.sql') then return; end if;
  execute $m0063$
-- ============================================================
-- 0063: R7 الشيكات (تحت التحصيل وبميعاد)
-- - شيك من عميل: بيقلل اللي على العميل، وبيدخل حساب "شيكات تحت التحصيل" (أصل) لحد ما يتصرف في خزنة (بنك).
-- - شيك لمورد: بيقلل اللي للمورد، وبيدخل "شيكات مستحقة الدفع" (التزام) لحد ما يتصرف من خزنة.
-- - الشيك اللي اترفض (أو اتلغى قبل الصرف): الدين بيرجع للعميل أو المورد زي ما كان.
-- - كل خطوة قيد متوازن، والقيود ما بتتعدلش. الإلغاء بقيد عكسي ممنوع لقيود الشيكات: الرفض هو الطريقة الوحيدة.
-- - صاحب المحل أو اللي معاه "المالية ← يضيف"، وفي فروعه بس.
-- ============================================================

alter table public.accounts drop constraint if exists accounts_kind_check;
alter table public.accounts add constraint accounts_kind_check check (kind = any (array[
  'cash', 'receivable', 'advances', 'inventory', 'payable', 'salaries', 'capital', 'drawings', 'revenue', 'cogs', 'expense', 'shortage', 'overage',
  'partner_capital', 'partner_current', 'retained', 'fixed_asset', 'tax', 'cheque_in', 'cheque_out']));

alter table public.journal_entries drop constraint if exists journal_entries_source_type_check;
alter table public.journal_entries add constraint journal_entries_source_type_check check (source_type = any (array[
  'payment', 'delivery', 'purchase', 'supplier_payment', 'part_use', 'sale', 'expense', 'salary', 'salary_payment', 'advance', 'advance_settle',
  'capital', 'drawing', 'transfer', 'drawer_close', 'reversal', 'cost_adjust', 'write_off', 'supplier_return', 'sale_return', 'opening',
  'partner_capital', 'partner_withdrawal', 'profit_distribution', 'netting', 'stock_transfer', 'commission', 'bonus', 'penalty', 'vat_payment',
  'cheque_in', 'cheque_out', 'cheque_clear', 'cheque_bounce']));

-- حسابات الشيكات لكل المحلات الموجودة (warsha.system: الترقية من SQL Editor من غير مستخدم)
do $chq$
begin
  perform set_config('warsha.system', 'on', true);
  insert into public.accounts(shop_id, code, type, kind)
  select sh.id, v.code, v.type::public.account_type, v.kind from public.shops sh
  cross join (values ('cheques_in', 'asset', 'cheque_in'), ('cheques_out', 'liability', 'cheque_out')) as v(code, type, kind)
  on conflict (shop_id, code) where code is not null do nothing;
  perform set_config('warsha.system', 'off', true);
end $chq$;

-- ---------- الجدول ----------
create table public.cheques (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references public.shops(id),
  branch_id uuid references public.branches(id),
  direction text not null check (direction in ('in', 'out')),
  party_type text not null check (party_type in ('customer', 'supplier')),
  party_id uuid not null,
  cheque_no text not null check (length(trim(cheque_no)) between 1 and 40),
  bank text check (bank is null or length(bank) <= 80),
  due_date date not null,
  amount bigint not null check (amount > 0 and amount <= 100000000000),
  status text not null default 'pending' check (status in ('pending', 'cleared', 'bounced')),
  entry_id uuid not null references public.journal_entries(id),
  settle_entry_id uuid references public.journal_entries(id),
  settled_at timestamptz,
  note text check (note is null or length(note) <= 300),
  created_by uuid references public.profiles(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  check ((direction = 'in') = (party_type = 'customer')),
  check ((status = 'pending') = (settle_entry_id is null))
);
create index cheques_due on public.cheques(shop_id, status, due_date) where deleted_at is null;
alter table public.cheques enable row level security;
create policy cheques_select on public.cheques for select to authenticated
  using (shop_id = (select public.current_shop_id()) and ((select public.current_app_role()) = 'owner' or (public.has_perm('finance', 'view') and public.can_branch(branch_id))));
-- الكتابة من الدوال بس
revoke all on public.cheques from public, anon, authenticated;
grant select on public.cheques to authenticated;
create trigger set_updated_at before update on public.cheques for each row execute function public.tg_set_updated_at();
create trigger block_delete before delete on public.cheques for each row execute function public.tg_block_delete();
create trigger zz_audit after insert or update on public.cheques for each row execute function public.tg_audit();

-- ---------- الصلاحية ----------
create or replace function public.cheque_require() returns void
language plpgsql stable security definer set search_path = public as $$
begin
  if public.current_app_role() = 'owner' then return; end if;
  perform public.grant_require('finance', 'add');
end $$;
revoke execute on function public.cheque_require() from public, anon, authenticated;

-- ---------- استلام شيك من عميل ----------
create or replace function public.cheque_receive(p_id uuid, p_customer uuid, p_no text, p_bank text, p_due date, p_amount bigint, p_note text default null)
returns uuid
language plpgsql security definer set search_path = public as $$
declare s uuid := public.current_shop_id(); e uuid;
begin
  perform public.cheque_require();
  if exists (select 1 from public.cheques where id = p_id) then return p_id; end if;
  perform public.ledger_amount(p_amount);
  if coalesce(trim(p_no), '') = '' or p_due is null then raise exception 'E_BAD_INPUT'; end if;
  if not exists (select 1 from public.customers where id = p_customer and shop_id = s and deleted_at is null) then raise exception 'E_NOT_FOUND'; end if;
  e := public.ledger_post('cheque_in', p_id, nullif(trim(p_note), ''), jsonb_build_array(
    public.ledger_line(public.ledger_acc('cheques_in'), p_amount, 0, 'customer', p_customer),
    public.ledger_line(public.ledger_acc('ar'), 0, p_amount, 'customer', p_customer)), null, p_id);
  insert into public.cheques(id, shop_id, branch_id, direction, party_type, party_id, cheque_no, bank, due_date, amount, entry_id, note, created_by)
  values (p_id, s, public.op_branch(), 'in', 'customer', p_customer, trim(p_no), nullif(trim(p_bank), ''), p_due, p_amount, e, nullif(trim(p_note), ''), auth.uid());
  return p_id;
end $$;

-- ---------- شيك لمورد ----------
create or replace function public.cheque_issue(p_id uuid, p_supplier uuid, p_no text, p_bank text, p_due date, p_amount bigint, p_note text default null)
returns uuid
language plpgsql security definer set search_path = public as $$
declare s uuid := public.current_shop_id(); e uuid;
begin
  perform public.cheque_require();
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

-- الشيك نفسه (مقفول للتعديل)، في المحل وفروع المستخدم
create or replace function public.cheque_lock(p_cheque uuid) returns public.cheques
language plpgsql security definer set search_path = public as $$
declare c public.cheques;
begin
  select * into c from public.cheques where id = p_cheque and shop_id = public.current_shop_id() and deleted_at is null for update;
  if not found then raise exception 'E_NOT_FOUND'; end if;
  if public.current_app_role() <> 'owner' and not public.can_branch(c.branch_id) then raise exception 'E_FORBIDDEN'; end if;
  -- الصرف والرفض بيتسجلوا في فرع الشيك نفسه (مش الفرع المفتوح على الشاشة)، وخزنة فرع تاني بتترفض (E_BRANCH_CASHBOX)
  perform public.pin_branch(c.branch_id);
  return c;
end $$;
revoke execute on function public.cheque_lock(uuid) from public, anon, authenticated;

-- ---------- الصرف: الفلوس دخلت أو خرجت من الخزنة (البنك غالبًا) ----------
create or replace function public.cheque_clear(p_op uuid, p_cheque uuid, p_cashbox uuid)
returns uuid
language plpgsql security definer set search_path = public as $$
declare c public.cheques; cb public.accounts; e uuid;
begin
  perform public.cheque_require();
  e := public.ledger_idem(p_op);
  if e is not null then return e; end if;
  c := public.cheque_lock(p_cheque);
  if c.status <> 'pending' then raise exception 'E_CHEQUE_DONE'; end if;
  cb := public.ledger_cashbox(p_cashbox);
  if c.direction = 'in' then
    e := public.ledger_post('cheque_clear', c.id, c.cheque_no, jsonb_build_array(
      public.ledger_line(cb.id, c.amount, 0),
      public.ledger_line(public.ledger_acc('cheques_in'), 0, c.amount, 'customer', c.party_id)), null, p_op);
  else
    e := public.ledger_post('cheque_clear', c.id, c.cheque_no, jsonb_build_array(
      public.ledger_line(public.ledger_acc('cheques_out'), c.amount, 0, 'supplier', c.party_id),
      public.ledger_line(cb.id, 0, c.amount)), null, p_op);
  end if;
  update public.cheques set status = 'cleared', settle_entry_id = e, settled_at = now() where id = c.id;
  return e;
end $$;

-- ---------- الرفض (أو الإلغاء قبل الصرف): الدين بيرجع زي ما كان ----------
create or replace function public.cheque_bounce(p_op uuid, p_cheque uuid, p_reason text)
returns uuid
language plpgsql security definer set search_path = public as $$
declare c public.cheques; e uuid;
begin
  perform public.cheque_require();
  e := public.ledger_idem(p_op);
  if e is not null then return e; end if;
  if coalesce(trim(p_reason), '') = '' then raise exception 'E_REASON_REQUIRED'; end if;
  c := public.cheque_lock(p_cheque);
  if c.status <> 'pending' then raise exception 'E_CHEQUE_DONE'; end if;
  if c.direction = 'in' then
    e := public.ledger_post('cheque_bounce', c.id, left(trim(p_reason), 300), jsonb_build_array(
      public.ledger_line(public.ledger_acc('ar'), c.amount, 0, 'customer', c.party_id),
      public.ledger_line(public.ledger_acc('cheques_in'), 0, c.amount, 'customer', c.party_id)), null, p_op);
  else
    e := public.ledger_post('cheque_bounce', c.id, left(trim(p_reason), 300), jsonb_build_array(
      public.ledger_line(public.ledger_acc('cheques_out'), c.amount, 0, 'supplier', c.party_id),
      public.ledger_line(public.ledger_acc('ap'), 0, c.amount, 'supplier', c.party_id)), null, p_op);
  end if;
  update public.cheques set status = 'bounced', settle_entry_id = e, settled_at = now() where id = c.id;
  return e;
end $$;

-- قيود الشيكات ما بتتلغيش بقيد عكسي (حالة الشيك كانت هتفضل غلط): الرفض بس
create or replace function public.tg_no_cheque_reversal() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if new.reverses_id is not null and exists (
    select 1 from public.journal_entries o where o.id = new.reverses_id and o.source_type in ('cheque_in', 'cheque_out', 'cheque_clear', 'cheque_bounce')) then
    raise exception 'E_CHEQUE_REVERSAL';
  end if;
  return new;
end $$;
create trigger a_no_cheque_reversal before insert on public.journal_entries for each row execute function public.tg_no_cheque_reversal();

-- ---------- القايمة (بأسماء العملاء والموردين) ----------
create or replace function public.cheques_list(p_status text default null, p_branch uuid default null) returns table (
  id uuid, direction text, party_type text, party_id uuid, party_name text, cheque_no text, bank text, due_date date,
  amount bigint, status text, branch_id uuid, settled_at timestamptz, note text, created_at timestamptz)
language plpgsql stable security definer set search_path = public as $$
declare s uuid := public.current_shop_id();
begin
  perform public.grant_require('finance', 'view');
  if not public.all_my_branches() and (p_branch is null or not public.can_branch(p_branch)) then p_branch := public.op_branch(); end if;
  return query
  select c.id, c.direction, c.party_type, c.party_id, coalesce(cu.name, sp.name), c.cheque_no, c.bank, c.due_date,
         c.amount, c.status, c.branch_id, c.settled_at, c.note, c.created_at
  from public.cheques c
  left join public.customers cu on c.party_type = 'customer' and cu.id = c.party_id
  left join public.suppliers sp on c.party_type = 'supplier' and sp.id = c.party_id
  where c.shop_id = s and c.deleted_at is null
    and (p_status is null or c.status = p_status)
    and (p_branch is null or c.branch_id = p_branch)
  order by (c.status = 'pending') desc, c.due_date, c.created_at;
end $$;

revoke execute on function public.cheque_receive(uuid, uuid, text, text, date, bigint, text) from public, anon;
revoke execute on function public.cheque_issue(uuid, uuid, text, text, date, bigint, text) from public, anon;
revoke execute on function public.cheque_clear(uuid, uuid, uuid) from public, anon;
revoke execute on function public.cheque_bounce(uuid, uuid, text) from public, anon;
revoke execute on function public.cheques_list(text, uuid) from public, anon;
grant execute on function public.cheque_receive(uuid, uuid, text, text, date, bigint, text) to authenticated;
grant execute on function public.cheque_issue(uuid, uuid, text, text, date, bigint, text) to authenticated;
grant execute on function public.cheque_clear(uuid, uuid, uuid) to authenticated;
grant execute on function public.cheque_bounce(uuid, uuid, text) to authenticated;
grant execute on function public.cheques_list(text, uuid) to authenticated;
revoke execute on function public.tg_no_cheque_reversal() from public, anon, authenticated;


-- ---------- الدوال اللي اتعدلت ----------
-- ensure_ledger_accounts: (src: 0062_vat.sql) + الشيكات
create or replace function public.ensure_ledger_accounts(p_shop uuid) returns void
language plpgsql security definer set search_path = public as $$
declare m text;
begin
  insert into public.accounts(shop_id, code, type, kind)
  select p_shop, v.code, v.type::public.account_type, v.kind from (values
    ('ar', 'asset', 'receivable'), ('advances', 'asset', 'advances'), ('inventory', 'asset', 'inventory'),
    ('ap', 'liability', 'payable'), ('salaries_payable', 'liability', 'salaries'), ('vat_payable', 'liability', 'tax'),
    ('cheques_in', 'asset', 'cheque_in'), ('cheques_out', 'liability', 'cheque_out'),
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

-- financial_position: (src: 0062_vat.sql) + الشيكات
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
      coalesce(sum(greatest(b, 0)) filter (where kind in ('receivable', 'advances', 'cheque_in')), 0)::bigint as receivables,
      (coalesce(sum(greatest(b, 0)) filter (where kind in ('payable', 'salaries', 'tax', 'cheque_out')), 0)
        + coalesce(sum(greatest(-b, 0)) filter (where kind in ('receivable', 'advances', 'cheque_in')), 0)
        + coalesce(sum(greatest(-b, 0)) filter (where kind = 'inventory'), 0))::bigint as payables,
      coalesce(sum(greatest(-b, 0)) filter (where kind in ('payable', 'salaries', 'tax', 'cheque_out')), 0)::bigint as payables_debit,
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
    'cheques_in', coalesce((select sum(b) from acc where kind = 'cheque_in'), 0),
    'cheques_out', coalesce((select sum(b) from acc where kind = 'cheque_out'), 0),
    -- الضريبة على المحل كله (مش الفرع المختار)
    'vat_due', (select coalesce(sum(l.credit - l.debit), 0)::bigint from public.journal_lines l join public.accounts a on a.id = l.account_id where l.shop_id = s and a.kind = 'tax'),
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

-- backup_snapshot: (src: 0061_attendance.sql) + cheques
create or replace function public.backup_snapshot(p_shop uuid) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare
  res jsonb := jsonb_build_object('format', 'warsha-backup', 'version', 1, 'generated_at', now(), 'shop_id', p_shop);
  t text;
  rows jsonb;
begin
  foreach t in array array['shops', 'branches', 'staff_branches', 'attendance', 'shop_branding', 'profiles', 'customers', 'devices', 'device_costs', 'status_log', 'device_notes', 'device_photos', 'device_checks',
                           'quote_decisions', 'message_templates', 'message_log', 'accounts', 'journal_entries', 'journal_lines', 'sale_lines', 'cheques', 'payments', 'drawer_closings',
                           'suppliers', 'categories', 'items', 'stock_moves', 'uncosted_sales', 'payment_plans', 'plan_installments', 'branch_goals', 'printers', 'print_templates', 'check_templates', 'used_devices', 'commission_rules', 'purchases', 'labor_rates', 'specialties', 'staff_specialties', 'routes', 'repair_steps',
                           'repair_videos', 'device_ratings', 'issue_presets', 'partners', 'profit_distributions', 'party_links', 'shop_lists', 'audit_log'] loop
    execute format('select coalesce(jsonb_agg(to_jsonb(x)), ''[]''::jsonb) from public.%I x where x.shop_id = $1', t) into rows using p_shop;
    res := res || jsonb_build_object(t, rows);
  end loop;
  select coalesce(jsonb_agg(jsonb_build_object('device_id', device_id, 'kind', kind, 'erased_at', erased_at)), '[]'::jsonb)
    into rows from public.device_passcodes where shop_id = p_shop;
  return res || jsonb_build_object('device_passcodes', rows);
end $$;

-- restore_backup: (src: 0061_attendance.sql) + cheques (بعد القيود)
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
$m0063$;
  insert into public.app_migrations(version, how) values ('0063_cheques.sql', 'applied');
  raise notice 'applied %', '0063_cheques.sql';
end $run$;
commit;

-- ============================== 0064_day_report.sql ==============================
begin;
do $run$ begin
  if exists (select 1 from public.app_migrations where version = '0064_day_report.sql') then return; end if;
  execute $m0064$
-- ============================================================
-- 0064: التقرير اليومي (بند 1 من qa-37)
-- - "حسب طريقة الدفع" كان بيجمع من جدول payments بس (دفعات الصيانة)، فالبيع الكاش ما كانش داخل.
-- - day_cash_report: تحصيلات العملاء كلها (صيانة + بيع) حسب طريقة الدفع، والمرتجع لوحده،
--   وتسوية كل خزنة: افتتاحي + وارد − صادر = ختامي، وقيود كل خزنة عشان كل رقم يفتح قيده.
-- - القيد اللي اتلغى (أو قيد الإلغاء نفسه) ما بيدخلش في التحصيل، بس بيفضل في حركة الخزنة عشان التسوية تطابق.
-- - قراءة بس: نفس صلاحية "المالية ← يشوف"، والموظف فروعه بس.
-- ============================================================

create or replace function public.day_cash_report(p_from timestamptz, p_to timestamptz, p_branch uuid default null) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare
  s uuid := public.current_shop_id();
  res jsonb;
begin
  perform public.grant_require('finance', 'view');
  if not public.all_my_branches() and (p_branch is null or not public.can_branch(p_branch)) then
    p_branch := public.op_branch();
    -- موظف من غير فرع: ما يشوفش خزن المحل كله
    if p_branch is null then raise exception 'E_FORBIDDEN'; end if;
  end if;
  with boxes as (
    select a.id, a.code, a.name, a.method, a.branch_id from public.accounts a
    where a.shop_id = s and a.kind = 'cash' and (p_branch is null or a.branch_id = p_branch)
  ),
  mv as (
    select l.account_id, e.id as entry_id, e.entry_no, e.source_type, e.memo, e.occurred_at, l.debit, l.credit,
           -- الإلغاء اللي حصل بعد الفترة ما يغيّرش تقرير يوم قديم
           (e.reverses_id is not null or exists (select 1 from public.journal_entries r where r.reverses_id = e.id and r.occurred_at < p_to)) as cancelled
    from public.journal_lines l join public.journal_entries e on e.id = l.entry_id
    where l.shop_id = s and l.account_id in (select id from boxes) and e.occurred_at >= p_from and e.occurred_at < p_to
  ),
  -- طريقة الدفع = طريقة الخزنة (record_payment بيسجل p_method، بس الواجهة ما بتبعتهوش، فهي نفس طريقة الخزنة)
  -- شيك العميل: بيتحسب تحصيل يوم ما يتصرف (cheque_clear لخزنة = فلوس دخلت). شيك المورد بيخرج من الخزنة (دائن) فما بيدخلش
  col as (
    select b.method,
           coalesce(sum(m.debit) filter (where m.source_type = 'payment'), 0)::bigint as payments,
           coalesce(sum(m.debit) filter (where m.source_type = 'sale'), 0)::bigint as sales,
           coalesce(sum(m.debit) filter (where m.source_type = 'cheque_clear'), 0)::bigint as cheques,
           coalesce(sum(m.credit) filter (where m.source_type = 'sale_return'), 0)::bigint as refunds
    from mv m join boxes b on b.id = m.account_id
    where not m.cancelled and m.source_type in ('payment', 'sale', 'cheque_clear', 'sale_return')
    group by b.method
  )
  select jsonb_build_object(
    'branch', p_branch,
    'collections', coalesce((select jsonb_agg(jsonb_build_object('method', method, 'payments', payments, 'sales', sales, 'cheques', cheques, 'refunds', refunds,
        'total', payments + sales + cheques - refunds) order by method) from col where payments + sales + cheques + refunds > 0), '[]'::jsonb),
    'cashboxes', coalesce((select jsonb_agg(x order by x ->> 'code' nulls last, x ->> 'name') from (
      select jsonb_build_object('id', b.id, 'code', b.code, 'name', b.name, 'method', b.method, 'branch_id', b.branch_id,
        'opening', o.opening, 'in', coalesce(t.d, 0), 'out', coalesce(t.c, 0), 'closing', o.opening + coalesce(t.d, 0) - coalesce(t.c, 0),
        'entries', coalesce((select jsonb_agg(jsonb_build_object('entry_id', m.entry_id, 'entry_no', m.entry_no, 'source_type', m.source_type,
            'memo', m.memo, 'at', m.occurred_at, 'in', m.debit, 'out', m.credit, 'cancelled', m.cancelled) order by m.occurred_at, m.entry_no)
          from mv m where m.account_id = b.id), '[]'::jsonb)) as x
      from boxes b
      cross join lateral (select coalesce(sum(l.debit - l.credit), 0)::bigint as opening from public.journal_lines l join public.journal_entries e on e.id = l.entry_id
                          where l.account_id = b.id and e.occurred_at < p_from) o
      left join lateral (select sum(m.debit)::bigint as d, sum(m.credit)::bigint as c from mv m where m.account_id = b.id) t on true
      -- الخزنة اللي ما اتحركتش ورصيدها صفر ما بتظهرش
      where o.opening <> 0 or t.d is not null) y), '[]'::jsonb)
  ) into res;
  return res;
end $$;
revoke all on function public.day_cash_report(timestamptz, timestamptz, uuid) from public;
grant execute on function public.day_cash_report(timestamptz, timestamptz, uuid) to authenticated;
$m0064$;
  insert into public.app_migrations(version, how) values ('0064_day_report.sql', 'applied');
  raise notice 'applied %', '0064_day_report.sql';
end $run$;
commit;

-- ============================== 0065_cheque_pending.sql ==============================
begin;
do $run$ begin
  if exists (select 1 from public.app_migrations where version = '0065_cheque_pending.sql') then return; end if;
  execute $m0065$
-- ============================================================
-- 0065: قرار صاحب المشروع (2026-11-23): شيك العميل "تحت التحصيل" ما بيقللش دين العميل غير لما يتصرف.
-- - الاستلام: بيتسجل الشيك بس، من غير قيد (اللي على العميل زي ما هو).
-- - الصرف: قيد واحد: الخزنة (مدين) / العملاء (دائن)، وصف في payments (لو الشيك على جهاز بيتحسب مدفوع للجهاز).
-- - الرفض: الحالة بس، من غير قيد (الدين أصلًا ما اتغيرش).
-- - التسليم قبل الصرف: الشيك مش دفعة، فـ"منع التسليم قبل السداد" (E_UNPAID) بيوقفه، وصاحب المحل بس يقدر "يسلّم بالآجل" (deliver_on_credit).
-- - الشيكات القديمة (قبل الملف ده) ليها قيد استلام: بتكمّل بنفس طريقتها القديمة لحد ما تتصرف أو تترفض، عشان الدفتر يفضل متوازن.
-- - شيكات الموردين ما اتغيرتش.
-- ============================================================

alter table public.cheques alter column entry_id drop not null;
alter table public.cheques add column if not exists device_id uuid references public.devices(id);
-- رقم عملية الرفض للشيك الجديد (مالوش قيد): نفس الطلب لو اتبعت تاني (من غير نت) ما يطلعش خطأ
alter table public.cheques add column if not exists settle_op uuid;
-- فريد جوه المحل بس: الاسترجاع بينسخ القيمة لمحل جديد (زي idem_key)
create unique index if not exists cheques_settle_op on public.cheques(shop_id, settle_op) where settle_op is not null;
-- الرفض الجديد ما لوش قيد: الحالة مربوطة بتاريخ التسوية مش بالقيد
do $c$
declare n text;
begin
  -- القيد القديم ((status = 'pending') = (settle_entry_id is null)) من غير اسم صريح: بندوّر عليه بتعريفه
  for n in select conname from pg_constraint where conrelid = 'public.cheques'::regclass and contype = 'c'
             and pg_get_constraintdef(oid) like '%settle_entry_id IS NULL%' loop
    execute format('alter table public.cheques drop constraint %I', n);
  end loop;
end $c$;
alter table public.cheques drop constraint if exists cheques_settled_check;
alter table public.cheques add constraint cheques_settled_check check ((status = 'pending') = (settled_at is null));
-- الشيك الجديد (من غير قيد استلام) لعميل بس
alter table public.cheques drop constraint if exists cheques_entry_check;
alter table public.cheques add constraint cheques_entry_check check (entry_id is not null or direction = 'in');

-- ---------- استلام شيك من عميل (src: 0063_cheques.sql) + من غير قيد، وجهاز اختياري ----------
drop function if exists public.cheque_receive(uuid, uuid, text, text, date, bigint, text);
create or replace function public.cheque_receive(p_id uuid, p_customer uuid, p_no text, p_bank text, p_due date, p_amount bigint, p_note text default null, p_device uuid default null)
returns uuid
language plpgsql security definer set search_path = public as $$
declare s uuid := public.current_shop_id();
begin
  perform public.cheque_require();
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
revoke execute on function public.cheque_receive(uuid, uuid, text, text, date, bigint, text, uuid) from public, anon;
grant execute on function public.cheque_receive(uuid, uuid, text, text, date, bigint, text, uuid) to authenticated;

-- ---------- الصرف (src: 0063_cheques.sql) + شيك العميل الجديد بيقلل الدين وقت الصرف ----------
create or replace function public.cheque_clear(p_op uuid, p_cheque uuid, p_cashbox uuid)
returns uuid
language plpgsql security definer set search_path = public as $$
declare c public.cheques; cb public.accounts; e uuid;
begin
  perform public.cheque_require();
  e := public.ledger_idem(p_op);
  if e is not null then return e; end if;
  c := public.cheque_lock(p_cheque);
  if c.status <> 'pending' then raise exception 'E_CHEQUE_DONE'; end if;
  cb := public.ledger_cashbox(p_cashbox);
  if c.direction = 'in' and c.entry_id is null then
    -- جديد: دلوقتي بس الفلوس وصلت، فالدين بيقل
    e := public.ledger_post('cheque_clear', c.id, c.cheque_no, jsonb_build_array(
      public.ledger_line(cb.id, c.amount, 0),
      public.ledger_line(public.ledger_acc('ar'), 0, c.amount, 'customer', c.party_id)), c.device_id, p_op);
    insert into public.payments(id, shop_id, customer_id, device_id, cashbox_id, method, amount, entry_id, created_by)
    values (gen_random_uuid(), c.shop_id, c.party_id, c.device_id, cb.id, cb.method, c.amount, e, auth.uid());
  elsif c.direction = 'in' then
    -- قديم: الدين اتخصم وقت الاستلام
    e := public.ledger_post('cheque_clear', c.id, c.cheque_no, jsonb_build_array(
      public.ledger_line(cb.id, c.amount, 0),
      public.ledger_line(public.ledger_acc('cheques_in'), 0, c.amount, 'customer', c.party_id)), null, p_op);
  else
    e := public.ledger_post('cheque_clear', c.id, c.cheque_no, jsonb_build_array(
      public.ledger_line(public.ledger_acc('cheques_out'), c.amount, 0, 'supplier', c.party_id),
      public.ledger_line(cb.id, 0, c.amount)), null, p_op);
  end if;
  update public.cheques set status = 'cleared', settle_entry_id = e, settled_at = now() where id = c.id;
  return e;
end $$;

-- ---------- الرفض (src: 0063_cheques.sql) + شيك العميل الجديد من غير قيد ----------
create or replace function public.cheque_bounce(p_op uuid, p_cheque uuid, p_reason text)
returns uuid
language plpgsql security definer set search_path = public as $$
declare c public.cheques; e uuid;
begin
  perform public.cheque_require();
  e := public.ledger_idem(p_op);
  if e is not null then return e; end if;
  if exists (select 1 from public.cheques where settle_op = p_op and shop_id = public.current_shop_id()) then return null; end if;
  if coalesce(trim(p_reason), '') = '' then raise exception 'E_REASON_REQUIRED'; end if;
  c := public.cheque_lock(p_cheque);
  -- نفس الطلب اتبعت مرتين في نفس اللحظة: التاني بيستنى القفل، وبعدها يرجع من غير خطأ
  if c.settle_op = p_op then return null; end if;
  if c.status <> 'pending' then raise exception 'E_CHEQUE_DONE'; end if;
  if c.direction = 'in' and c.entry_id is null then
    -- جديد: الدين ما اتغيرش أصلًا، فمفيش قيد. السبب في الملاحظة وفي سجل النشاط (zz_audit)
    update public.cheques set status = 'bounced', settled_at = now(), settle_op = p_op,
      note = left(concat_ws(' · ', note, trim(p_reason)), 300) where id = c.id;
    return null;
  elsif c.direction = 'in' then
    e := public.ledger_post('cheque_bounce', c.id, left(trim(p_reason), 300), jsonb_build_array(
      public.ledger_line(public.ledger_acc('ar'), c.amount, 0, 'customer', c.party_id),
      public.ledger_line(public.ledger_acc('cheques_in'), 0, c.amount, 'customer', c.party_id)), null, p_op);
  else
    e := public.ledger_post('cheque_bounce', c.id, left(trim(p_reason), 300), jsonb_build_array(
      public.ledger_line(public.ledger_acc('cheques_out'), c.amount, 0, 'supplier', c.party_id),
      public.ledger_line(public.ledger_acc('ap'), 0, c.amount, 'supplier', c.party_id)), null, p_op);
  end if;
  update public.cheques set status = 'bounced', settle_entry_id = e, settled_at = now() where id = c.id;
  return e;
end $$;
$m0065$;
  insert into public.app_migrations(version, how) values ('0065_cheque_pending.sql', 'applied');
  raise notice 'applied %', '0065_cheque_pending.sql';
end $run$;
commit;

-- ============================== 0066_commission_net.sql ==============================
begin;
do $run$ begin
  if exists (select 1 from public.app_migrations where version = '0066_commission_net.sql') then return; end if;
  execute $m0066$
-- ============================================================
-- 0066: قرار صاحب المشروع (2026-11-23): عمولة الفني على السعر قبل الضريبة.
-- - المصنعية = (التكلفة النهائية − الضريبة اللي جواها) − تكلفة القطع.
-- - الضريبة بنفس طريقة قيد التسليم بالظبط (vat_of بنسبة المحل وقت التسليم)، فالعمولة والقيد دايمًا متطابقين.
-- - المحل اللي الضريبة عنده مقفولة: مفيش أي فرق (vat_of = 0).
-- - العمولات القديمة اللي اتسجلت قبل الملف ده ما بتتغيرش (القيود ما بتتعدلش).
-- ============================================================

-- commission_preview: (src: 0056_branch_features.sql) + المصنعية من غير الضريبة
create or replace function public.commission_preview(p_device uuid) returns table(technician_id uuid, amount bigint)
language plpgsql stable security definer set search_path = public as $$
declare d public.devices; techs uuid[]; n int; base bigint; fc bigint; r public.commission_rules; t uuid; share bigint;
begin
  select * into d from public.devices where id = p_device;
  if d.id is null then return; end if;
  techs := public.device_technicians(p_device);
  n := coalesce(array_length(techs, 1), 0);
  if n = 0 then return; end if;
  fc := coalesce((select c.final_cost from public.device_costs c where c.device_id = p_device and c.deleted_at is null), 0);
  base := greatest(fc - public.vat_of(fc, public.vat_bp(d.shop_id)) - public.device_parts_cost(p_device), 0);
  foreach t in array techs loop
    r := public.commission_rule_for(d.shop_id, t, d.route_id, d.branch_id);
    continue when r.id is null;
    share := case when r.mode = 'fixed' then r.value else (base / n) * r.value / 10000 end;
    if share > 0 then technician_id := t; amount := share; return next; end if;
  end loop;
end $$;
revoke execute on function public.commission_preview(uuid) from public, anon, authenticated;
$m0066$;
  insert into public.app_migrations(version, how) values ('0066_commission_net.sql', 'applied');
  raise notice 'applied %', '0066_commission_net.sql';
end $run$;
commit;

-- ============================== 0067_idem_lock.sql ==============================
begin;
do $run$ begin
  if exists (select 1 from public.app_migrations where version = '0067_idem_lock.sql') then return; end if;
  execute $m0067$
-- ============================================================
-- 0067: بند 2 من qa-37: ضغطتين متزامنتين على الحفظ = عملية واحدة من غير خطأ.
-- - كل دوال الفلوس بتبدأ بـ ledger_idem(رقم العملية): لو اتسجلت قبل كده بترجع نفس القيد.
-- - المشكلة: طلبين في نفس اللحظة الاتنين بيعدّوا الفحص، والتاني بيقع بـ unique violation على idem_key
--   (البيانات سليمة، بس المستخدم بيشوف خطأ والطابور بتاع "من غير نت" بيعيد).
-- - الحل: قفل قصير على رقم العملية لحد آخر الـ transaction. الطلب التاني بيستنى، وبعدين بيلاقي القيد ويرجّعه.
-- ============================================================

-- ledger_idem: (src: 0008_ledger.sql) + قفل على رقم العملية (volatile بدل stable عشان القفل)
create or replace function public.ledger_idem(p uuid) returns uuid
language plpgsql volatile security definer set search_path = public as $$
declare r uuid;
begin
  if p is null then return null; end if;
  perform pg_advisory_xact_lock(hashtextextended(p::text, 0));
  select id into r from public.journal_entries where idem_key = p and shop_id = public.current_shop_id();
  return r;
end $$;
revoke execute on function public.ledger_idem(uuid) from public, anon, authenticated;
$m0067$;
  insert into public.app_migrations(version, how) values ('0067_idem_lock.sql', 'applied');
  raise notice 'applied %', '0067_idem_lock.sql';
end $run$;
commit;

-- ============================== 0068_stock_adjust.sql ==============================
begin;
do $run$ begin
  if exists (select 1 from public.app_migrations where version = '0068_stock_adjust.sql') then return; end if;
  execute $m0068$
-- ============================================================
-- 0068: بند 14 من qa-37: نقص المخزون في البيع = تسوية مخزون بصلاحية لوحدها وسبب وسجل.
-- - قبل كده: شاشة البيع لما الكمية مش كفاية كانت بتعرض "سجّل الكمية والتكلفة" (stock_in) لأي حد معاه "المخزون ← يضيف"
--   (الاستقبال)، من غير سبب، والقيد على رأس المال. يعني زيادة مخزون خفية من شاشة البيع.
-- - دلوقتي: stock_in = "تسوية مخزون": صاحب المحل أو اللي معاه "المخزون ← المبالغ" بس، والسبب إجباري،
--   وبيتسجل في سجل النشاط (مين، وإمتى، والكمية، والتكلفة، والسبب). البيع نفسه عمره ما بيزوّد المخزون (E_STOCK زي ما هو).
-- - الرصيد الأول لصنف جديد (create_item) فاضل زي ما هو: بصلاحيات إضافة الصنف والمخزون (من غير "المبالغ")، عن طريق _stock_in.
-- ============================================================

-- الشغل نفسه من غير صلاحيات (داخلي بس، محدش يناديه من بره)
create or replace function public._stock_in(p_id uuid, p_item uuid, p_qty integer, p_unit_cost bigint, p_memo text) returns uuid
language plpgsql security definer set search_path = public as $$
declare s uuid := public.current_shop_id(); e uuid; total bigint;
begin
  e := public.ledger_idem(p_id);
  if e is not null then return e; end if;
  if p_qty is null or p_qty <= 0 or p_qty > 100000 or p_unit_cost is null or p_unit_cost < 0 then raise exception 'E_BAD_AMOUNT'; end if;
  if not exists (select 1 from public.items where id = p_item and shop_id = s and deleted_at is null) then raise exception 'E_NOT_FOUND'; end if;
  total := p_qty::bigint * p_unit_cost;
  if total <= 0 then raise exception 'E_BAD_AMOUNT'; end if;
  perform public.ledger_amount(total);
  e := public.ledger_post('opening', p_item, left(coalesce(nullif(trim(p_memo), ''), 'stock'), 300),
    jsonb_build_array(public.ledger_line(public.ledger_acc('inventory'), total, 0), public.ledger_line(public.ledger_acc('capital'), 0, total)), null, p_id);
  insert into public.stock_moves(shop_id, item_id, entry_id, qty, value) values (s, p_item, e, p_qty, total);
  return e;
end $$;
revoke execute on function public._stock_in(uuid, uuid, integer, bigint, text) from public, anon, authenticated;

-- stock_in: (src: 0037_item_details.sql) = تسوية مخزون: صلاحية "المخزون ← المبالغ" والسبب إجباري وسجل
create or replace function public.stock_in(p_id uuid, p_item uuid, p_qty integer, p_unit_cost bigint, p_note text default null) returns uuid
language plpgsql security definer set search_path = public as $$
declare s uuid := public.current_shop_id(); e uuid; reason text := left(nullif(trim(p_note), ''), 300);
begin
  perform public.grant_require('inventory', 'amounts');
  e := public.ledger_idem(p_id);
  if e is not null then return e; end if;
  if reason is null then raise exception 'E_REASON_REQUIRED'; end if;
  e := public._stock_in(p_id, p_item, p_qty, p_unit_cost, reason);
  insert into public.audit_log(shop_id, actor_id, action, entity, entity_id, after)
  values (s, auth.uid(), 'stock_adjust', 'items', p_item, jsonb_build_object('qty', p_qty, 'unit_cost', p_unit_cost, 'value', p_qty::bigint * p_unit_cost, 'reason', reason, 'entry', e));
  return e;
end $$;
revoke execute on function public.stock_in(uuid, uuid, integer, bigint, text) from public, anon;
grant execute on function public.stock_in(uuid, uuid, integer, bigint, text) to authenticated;

-- create_item: (src: 0057_categories.sql) + الرصيد الأول بـ _stock_in بنفس صلاحيات stock_in القديمة (المخزون ← يضيف)
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
    perform public.perm_require('inventory', 'add');
    perform public._stock_in(coalesce(p_stock_id, gen_random_uuid()), p_id, p_qty, p_unit_cost, 'stock');
  end if;
  return p_id;
end $$;
$m0068$;
  insert into public.app_migrations(version, how) values ('0068_stock_adjust.sql', 'applied');
  raise notice 'applied %', '0068_stock_adjust.sql';
end $run$;
commit;

-- ============================== 0069_sale_errors.sql ==============================
begin;
do $run$ begin
  if exists (select 1 from public.app_migrations where version = '0069_sale_errors.sql') then return; end if;
  execute $m0069$
-- ============================================================
-- 0069: بند 13 من qa-37: أخطاء البيع برسالة الحقل، وسياسة البيع المجاني.
-- - الكمية الغلط E_BAD_QTY، والسعر الغلط E_BAD_PRICE (بدل رسالة عامة).
-- - صنف مجاني (سعر صفر): صاحب المحل أو اللي معاه "المخزون ← المبالغ"، والسبب (reason في السطر) إجباري.
--   السبب في سجل النشاط بس: ملاحظة البيع بتتطبع على فاتورة العميل، فما بيتحطش فيها.
-- - فاتورة كلها مجانية مرفوضة زي الأول (E_BAD_AMOUNT).
-- ============================================================

-- record_sale: (src: 0062_vat.sql)
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
  bp integer := public.vat_bp(s); v_parts bigint := 0; v_acc bigint := 0; v_srv bigint := 0;
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
    -- أعداد صحيحة بس (الكسور والفراغ وNaN والسالب بيترفضوا برسالة الحقل نفسه)
    if coalesce(l ->> 'qty', '') !~ '^[0-9]{1,6}$' or (l ->> 'qty')::bigint <= 0 then raise exception 'E_BAD_QTY'; end if;
    if coalesce(l ->> 'price', '') !~ '^[0-9]{1,12}$' then raise exception 'E_BAD_PRICE'; end if;
    q := (l ->> 'qty')::bigint;
    p := (l ->> 'price')::bigint;
    if p = 0 then
      if public.current_app_role() <> 'owner' and not public.has_perm('inventory', 'amounts') then raise exception 'E_FREE_SALE'; end if;
      if nullif(trim(l ->> 'reason'), '') is null then raise exception 'E_REASON_REQUIRED'; end if;
      insert into public.audit_log(shop_id, actor_id, action, entity, entity_id, after)
      values (s, auth.uid(), 'free_sale', 'items', it.id, jsonb_build_object('name', it.name, 'qty', q, 'reason', left(trim(l ->> 'reason'), 300), 'entry', e));
    end if;
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
  -- R5: السعر شامل الضريبة. الضريبة بتتفصل من كل نوع إيراد لوحده، ومجموعها في حساب الضريبة المستحقة
  if bp > 0 then
    v_parts := public.vat_of(rev_parts, bp); v_acc := public.vat_of(rev_acc, bp); v_srv := public.vat_of(rev_srv, bp);
    if v_parts + v_acc + v_srv > 0 then
      insert into public.journal_lines(shop_id, entry_id, account_id, debit, credit) values (s, e, public.ledger_acc('vat_payable'), 0, v_parts + v_acc + v_srv);
    end if;
  end if;
  if rev_parts > 0 then insert into public.journal_lines(shop_id, entry_id, account_id, debit, credit) values (s, e, public.ledger_acc('rev_parts'), 0, rev_parts - v_parts); end if;
  if rev_acc > 0 then insert into public.journal_lines(shop_id, entry_id, account_id, debit, credit) values (s, e, public.ledger_acc('rev_accessories'), 0, rev_acc - v_acc); end if;
  if rev_srv > 0 then insert into public.journal_lines(shop_id, entry_id, account_id, debit, credit) values (s, e, public.ledger_acc('rev_repair'), 0, rev_srv - v_srv); end if;
  if total_cost > 0 then
    insert into public.journal_lines(shop_id, entry_id, account_id, debit, credit) values
      (s, e, public.ledger_acc('cogs'), total_cost, 0), (s, e, public.ledger_acc('inventory'), 0, total_cost);
  end if;
  if p_cashbox is not null and p_customer is not null then
    null; -- البيع النقدي لعميل معروف ما بيأثرش على رصيده
  end if;
  return e;
end $$;

-- stock_in: (src: 0068_stock_adjust.sql) + اسم الصنف في سجل النشاط
create or replace function public.stock_in(p_id uuid, p_item uuid, p_qty integer, p_unit_cost bigint, p_note text default null) returns uuid
language plpgsql security definer set search_path = public as $$
declare s uuid := public.current_shop_id(); e uuid; reason text := left(nullif(trim(p_note), ''), 300);
begin
  perform public.grant_require('inventory', 'amounts');
  e := public.ledger_idem(p_id);
  if e is not null then return e; end if;
  if reason is null then raise exception 'E_REASON_REQUIRED'; end if;
  e := public._stock_in(p_id, p_item, p_qty, p_unit_cost, reason);
  insert into public.audit_log(shop_id, actor_id, action, entity, entity_id, after)
  values (s, auth.uid(), 'stock_adjust', 'items', p_item, jsonb_build_object('name', (select name from public.items where id = p_item), 'qty', p_qty, 'unit_cost', p_unit_cost, 'value', p_qty::bigint * p_unit_cost, 'reason', reason, 'entry', e));
  return e;
end $$;
$m0069$;
  insert into public.app_migrations(version, how) values ('0069_sale_errors.sql', 'applied');
  raise notice 'applied %', '0069_sale_errors.sql';
end $run$;
commit;

select 5 as part, 7 as parts, count(*) as applied_files, max(version) as latest,
  case when '0069_sale_errors.sql' in (select version from public.app_migrations) then
    'الجزء 5 خلص. اللي بعده: upgrade_part_6.sql'
  else 'فيه ملف ما اتطبقش' end as status
from public.app_migrations;
