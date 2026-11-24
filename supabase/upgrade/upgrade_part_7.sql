-- جوالك / Gawalak: ترقية مشروع Supabase لآخر نسخة، الجزء 7 من 7 (الملفات 0085_finance_branch.sql لـ 0087_private_finance.sql).
-- بيتولد تلقائيًا: npm run db:setup-file. ما تعدّلوش بإيدك.
-- شغّل الأجزاء بالترتيب في SQL Editor (كل جزء لوحده: New query ← الصق ← Run): upgrade_part_1.sql ثم upgrade_part_2.sql ثم upgrade_part_3.sql ثم upgrade_part_4.sql ثم upgrade_part_5.sql ثم upgrade_part_6.sql ثم upgrade_part_7.sql.
-- آمن تشغّل أي جزء أكتر من مرة: اللي اتطبق قبل كده بيتخطى. ولو ملف فشل، اللي قبله بيفضل، وصلّح السبب وشغّل نفس الجزء تاني.
-- لو لقى ملف أحدث موجود وأقدم منه ناقص بيقف (E_UPGRADE_GAP). ولو جزء قبله لسه ما اتطبقش بيقف (E_UPGRADE_ORDER). الاتنين من غير تغيير.
-- ملفات الجزء ده: 0085_finance_branch.sql, 0086_finance_cards.sql, 0087_private_finance.sql

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
  insert into public.app_migrations(version, how) select v, 'inferred' from unnest(array['0022_security_review.sql']::text[]) v
    where v < (select max(version) from public.app_migrations) on conflict (version) do nothing;
  select min(v) into first_missing from unnest(array['0001_phase1.sql', '0002_storage.sql', '0003_shop_profile_realtime.sql', '0004_error_codes.sql', '0005_device_passcode.sql', '0006_invite_name.sql', '0007_phase2_customer.sql', '0008_ledger.sql', '0009_tracking_guess_limit.sql', '0010_default_cashboxes.sql', '0011_finance_drilldown.sql', '0012_spec_completion.sql', '0013_tracking_ambiguous.sql', '0014_technicians.sql', '0015_offline_backup.sql', '0016_shop_identity.sql', '0017_growth.sql', '0018_account_state.sql', '0019_extras.sql', '0020_admin_paging.sql', '0021_spec_rules.sql', '0022_security_review.sql', '0023_restore.sql', '0024_signout.sql', '0025_integrity.sql', '0026_edit_delete.sql', '0027_inventory.sql', '0028_opening.sql', '0029_partners.sql', '0030_party_links.sql', '0031_partner_capital.sql', '0032_lists.sql', '0033_assistant.sql', '0034_branches.sql', '0035_lists_everywhere.sql', '0036_roles.sql', '0037_item_details.sql', '0038_roles_grant.sql', '0039_payment_plans.sql', '0040_branch_books.sql', '0041_analytics.sql', '0042_app_brand.sql', '0043_printing.sql', '0044_capture.sql', '0045_checklists.sql', '0046_master.sql', '0047_mfa.sql', '0048_used.sql', '0049_commissions.sql', '0050_insights.sql', '0051_demo.sql', '0052_catalog.sql', '0053_portal.sql', '0054_telegram.sql', '0055_eta_placeholder.sql', '0056_branch_features.sql', '0057_categories.sql', '0058_web_push.sql', '0059_counters_branch.sql', '0060_sale_lines.sql', '0061_attendance.sql', '0062_vat.sql', '0063_cheques.sql', '0064_day_report.sql', '0065_cheque_pending.sql', '0066_commission_net.sql', '0067_idem_lock.sql', '0068_stock_adjust.sql', '0069_sale_errors.sql', '0070_perm_matrix.sql', '0071_device_children.sql', '0072_sale_line_return.sql', '0073_shop_extras.sql', '0074_idem_cheque_plan.sql', '0075_delete_by_section.sql', '0076_debt_aging.sql', '0077_period_lock.sql', '0078_accountant_export.sql', '0079_purchase_orders.sql', '0080_stock_count.sql', '0081_repair_invoice.sql', '0082_order_prefix.sql', '0083_print_perm.sql', '0084_party_branch.sql', '0085_finance_branch.sql', '0086_finance_cards.sql', '0087_private_finance.sql']) v where v not in (select version from public.app_migrations);
  select max(version) into later_present from public.app_migrations where first_missing is not null and version > first_missing;
  if later_present is not null then raise exception 'E_UPGRADE_GAP: % موجود، بس % ناقص قبله. ابعت الرسالة دي للمطوّر.', later_present, first_missing; end if;
end $chk$;

-- 2) الأجزاء اللي قبل الجزء ده لازم تكون اتطبقت
do $ord$
declare
  files text[] := array['0001_phase1.sql', '0002_storage.sql', '0003_shop_profile_realtime.sql', '0004_error_codes.sql', '0005_device_passcode.sql', '0006_invite_name.sql', '0007_phase2_customer.sql', '0008_ledger.sql', '0009_tracking_guess_limit.sql', '0010_default_cashboxes.sql', '0011_finance_drilldown.sql', '0012_spec_completion.sql', '0013_tracking_ambiguous.sql', '0014_technicians.sql', '0015_offline_backup.sql', '0016_shop_identity.sql', '0017_growth.sql', '0018_account_state.sql', '0019_extras.sql', '0020_admin_paging.sql', '0021_spec_rules.sql', '0022_security_review.sql', '0023_restore.sql', '0024_signout.sql', '0025_integrity.sql', '0026_edit_delete.sql', '0027_inventory.sql', '0028_opening.sql', '0029_partners.sql', '0030_party_links.sql', '0031_partner_capital.sql', '0032_lists.sql', '0033_assistant.sql', '0034_branches.sql', '0035_lists_everywhere.sql', '0036_roles.sql', '0037_item_details.sql', '0038_roles_grant.sql', '0039_payment_plans.sql', '0040_branch_books.sql', '0041_analytics.sql', '0042_app_brand.sql', '0043_printing.sql', '0044_capture.sql', '0045_checklists.sql', '0046_master.sql', '0047_mfa.sql', '0048_used.sql', '0049_commissions.sql', '0050_insights.sql', '0051_demo.sql', '0052_catalog.sql', '0053_portal.sql', '0054_telegram.sql', '0055_eta_placeholder.sql', '0056_branch_features.sql', '0057_categories.sql', '0058_web_push.sql', '0059_counters_branch.sql', '0060_sale_lines.sql', '0061_attendance.sql', '0062_vat.sql', '0063_cheques.sql', '0064_day_report.sql', '0065_cheque_pending.sql', '0066_commission_net.sql', '0067_idem_lock.sql', '0068_stock_adjust.sql', '0069_sale_errors.sql', '0070_perm_matrix.sql', '0071_device_children.sql', '0072_sale_line_return.sql', '0073_shop_extras.sql', '0074_idem_cheque_plan.sql', '0075_delete_by_section.sql', '0076_debt_aging.sql', '0077_period_lock.sql', '0078_accountant_export.sql', '0079_purchase_orders.sql', '0080_stock_count.sql', '0081_repair_invoice.sql', '0082_order_prefix.sql', '0083_print_perm.sql', '0084_party_branch.sql', '0085_finance_branch.sql', '0086_finance_cards.sql', '0087_private_finance.sql'];
  parts int[] := array[1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 3, 3, 3, 3, 3, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 7, 7, 7];
  miss text;
begin
  select min(v) into miss from unnest(files) v where v < '0085_finance_branch.sql' and v not in (select version from public.app_migrations);
  if miss is not null then raise exception 'E_UPGRADE_ORDER: الملف % لسه ما اتطبقش. شغّل upgrade_part_%.sql الأول، وبعدين الجزء ده (7).', miss, parts[array_position(files, miss)]; end if;
end $ord$;

-- 3) ملفات الجزء 7 بالترتيب، كل ملف في transaction لوحده
-- ============================== 0085_finance_branch.sql ==============================
begin;
do $run$ begin
  if exists (select 1 from public.app_migrations where version = '0085_finance_branch.sql') then return; end if;
  execute $m0085$
-- 0085: (قرار صاحب المشروع 2026-11-24) المالية للموظف: فرع واحد من فروعه دايمًا (اللي اختاره، وإلا الشغال عليه). صاحب المحل بس اللي يشوف المحل كله.
-- الوضع المالي، والأرباح، والتدفق اليومي، وميزان المراجعة، والمستحق بين الفروع، والضريبة، والشيكات، والأقساط وتنبيهاتها، والتقرير اليومي، وملف المحاسب.

-- financial_position: (src: 0063_cheques.sql)
create or replace function public.financial_position(p_from timestamptz, p_to timestamptz, p_branch uuid default null) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare
  s uuid := public.current_shop_id();
  res jsonb;
  own boolean := public.current_app_role() = 'owner';
begin
  perform public.grant_require('finance', 'view');
  -- الموظف: فرع واحد من فروعه دايمًا، ومن غير إجماليات المحل كله
  if public.current_app_role() <> 'owner' and (p_branch is null or not public.can_branch(p_branch)) then p_branch := public.op_branch(); end if;
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
    -- الضريبة على المحل كله لصاحب المحل، وللموظف فرعه
    'vat_due', (select coalesce(sum(l.credit - l.debit), 0)::bigint from public.journal_lines l join public.accounts a on a.id = l.account_id where l.shop_id = s and a.kind = 'tax' and (own or exists (select 1 from public.journal_entries te where te.id = l.entry_id and te.branch_id = p_branch))),
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
    'equation', case when own then jsonb_build_object('assets', eq_all.assets, 'liabilities', eq_all.liabilities, 'equity', eq_all.equity, 'earnings', eq_all.earnings) end,
    'debits', case when own then tot.d end, 'credits', case when own then tot.c end, 'unbalanced_entries', unb.n,
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

-- pl_breakdown: (src: 0038_roles_grant.sql)
create or replace function public.pl_breakdown(p_from timestamptz, p_to timestamptz, p_branch uuid default null)
returns table(account_id uuid, code text, name text, type public.account_type, amount bigint)
language plpgsql stable security definer set search_path = public as $$
begin
  perform public.grant_require('finance', 'view');
  -- الموظف: فرع واحد من فروعه
  if public.current_app_role() <> 'owner' and (p_branch is null or not public.can_branch(p_branch)) then p_branch := public.op_branch(); end if;
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

-- cashbox_daily: (src: 0038_roles_grant.sql)
create or replace function public.cashbox_daily(p_from timestamptz, p_to timestamptz)
returns table(cashbox uuid, day date, net bigint)
language plpgsql stable security definer set search_path = public as $$
declare br uuid;
begin
  perform public.grant_require('finance', 'view', true);
  br := public.party_branch();
  return query
  select l.account_id, (date_trunc('day', e.occurred_at at time zone 'Africa/Cairo'))::date, sum(l.debit - l.credit)::bigint
  from public.journal_lines l
  join public.accounts a on a.id = l.account_id and a.kind = 'cash'
  join public.journal_entries e on e.id = l.entry_id
  where l.shop_id = public.current_shop_id() and e.occurred_at >= p_from and e.occurred_at < p_to and (br is null or a.branch_id = br)
  group by 1, 2
  order by 2;
end $$;

-- vat_report: (src: 0062_vat.sql)
create or replace function public.vat_report(p_from timestamptz, p_to timestamptz, p_branch uuid default null) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare
  s uuid := public.current_shop_id();
  res jsonb;
  whole boolean := public.current_app_role() = 'owner';
begin
  perform public.grant_require('finance', 'view');
  if p_from is null or p_to is null or p_to <= p_from then raise exception 'E_BAD_INPUT'; end if;
  if public.current_app_role() <> 'owner' and (p_branch is null or not public.can_branch(p_branch)) then p_branch := public.op_branch(); end if;
  with ln as (
    -- قيد الإلغاء بيتحسب على نوع القيد الأصلي (بيع أو تسليم)
    select coalesce(o.source_type, e.source_type) as src, e.source_type as own, a.kind, l.debit, l.credit
    from public.journal_entries e
    join public.journal_lines l on l.entry_id = e.id
    join public.accounts a on a.id = l.account_id
    left join public.journal_entries o on o.id = e.reverses_id
    where e.shop_id = s and e.occurred_at >= p_from and e.occurred_at < p_to
      -- السداد على المحل كله لصاحب المحل (الضريبة على المحل مش الفرع)، والباقي بفلتر الفرع
      and (p_branch is null or e.branch_id = p_branch or whole and coalesce(o.source_type, e.source_type) = 'vat_payment')
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
    -- المستحق لحد آخر الفترة (صاحب المحل: كل الفروع، والموظف فرعه)
    'due', coalesce((select sum(l.credit - l.debit) from public.journal_lines l join public.journal_entries e on e.id = l.entry_id
                     join public.accounts a on a.id = l.account_id where e.shop_id = s and a.kind = 'tax' and e.occurred_at < p_to and (whole or e.branch_id = p_branch)), 0)::bigint
  ) into res from ln;
  return res;
end $$;

-- cheques_list: (src: 0063_cheques.sql)
create or replace function public.cheques_list(p_status text default null, p_branch uuid default null) returns table (
  id uuid, direction text, party_type text, party_id uuid, party_name text, cheque_no text, bank text, due_date date,
  amount bigint, status text, branch_id uuid, settled_at timestamptz, note text, created_at timestamptz)
language plpgsql stable security definer set search_path = public as $$
declare s uuid := public.current_shop_id();
begin
  perform public.grant_require('finance', 'view');
  if public.current_app_role() <> 'owner' and (p_branch is null or not public.can_branch(p_branch)) then p_branch := public.op_branch(); end if;
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

-- day_cash_report: (src: 0064_day_report.sql)
create or replace function public.day_cash_report(p_from timestamptz, p_to timestamptz, p_branch uuid default null) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare
  s uuid := public.current_shop_id();
  res jsonb;
begin
  perform public.grant_require('finance', 'view');
  if public.current_app_role() <> 'owner' and (p_branch is null or not public.can_branch(p_branch)) then
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

-- accountant_export: (src: 0078_accountant_export.sql)
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
  if public.current_app_role() <> 'owner' and (p_branch is null or not public.can_branch(p_branch)) then
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

-- trial_balance: (src: 0040_branch_books.sql)
create or replace function public.trial_balance(p_branch uuid default null, p_to timestamptz default null)
returns table(account_id uuid, code text, name text, type text, kind text, debit bigint, credit bigint, balance bigint)
language plpgsql stable security definer set search_path = public as $$
#variable_conflict use_column
begin
  perform public.grant_require('finance', 'view');
  if p_branch is not null and public.current_app_role() <> 'owner' and not public.can_branch(p_branch) then raise exception 'E_FORBIDDEN'; end if;
  if p_branch is null then p_branch := public.party_branch(); end if;
  return query
  with b as (select * from public.branch_lines_raw(p_to) bl where p_branch is null or bl.branch_id = p_branch),
  t as (select b.account_id acc, sum(greatest(b.amount, 0))::bigint dr, sum(greatest(-b.amount, 0))::bigint cr from b group by 1)
  select t.acc, a.code, a.name, coalesce(a.type::text, 'inter_branch'), coalesce(a.kind, 'inter_branch'), t.dr, t.cr, (t.dr - t.cr)::bigint
  from t left join public.accounts a on a.id = t.acc
  where t.dr - t.cr <> 0 or t.acc is null and p_branch is not null
  order by case coalesce(a.type::text, 'inter_branch') when 'asset' then 1 when 'liability' then 2 when 'equity' then 3 when 'revenue' then 4 when 'expense' then 5 else 6 end, a.code nulls last, a.name;
end $$;

-- inter_branch_dues: (src: 0040_branch_books.sql)
create or replace function public.inter_branch_dues(p_to timestamptz default null)
returns table(branch_id uuid, other_id uuid, amount bigint)
language plpgsql stable security definer set search_path = public as $$
#variable_conflict use_column
declare br uuid;
begin
  perform public.grant_require('finance', 'view');
  br := public.party_branch();
  return query
  with d as (select bl.entry_id, bl.branch_id, bl.amount from public.branch_lines_raw(p_to) bl where bl.account_id is null),
  -- القيد بين فرعين: كل فرع قصاد التاني. لو أكتر من فرعين: بالنسبة (نادر جدًا)
  pairs as (
    select a.branch_id, o.branch_id other, (a.amount * abs(o.amount) / nullif((select sum(abs(z.amount)) from d z where z.entry_id = a.entry_id and z.branch_id <> a.branch_id), 0))::bigint amt
    from d a join d o on o.entry_id = a.entry_id and o.branch_id <> a.branch_id and sign(o.amount) <> sign(a.amount)
  )
  select p.branch_id, p.other, sum(p.amt)::bigint from pairs p where br is null or p.branch_id = br group by 1, 2 having sum(p.amt) <> 0 order by 1, 2;
end $$;

-- branch_lines: (src: 0040_branch_books.sql)
create or replace function public.branch_lines(p_to timestamptz default null)
returns table(entry_id uuid, occurred_at timestamptz, source_type text, branch_id uuid, account_id uuid, amount bigint)
language plpgsql stable security definer set search_path = public as $$
#variable_conflict use_column
declare br uuid;
begin
  perform public.grant_require('finance', 'view');
  br := public.party_branch();
  return query select * from public.branch_lines_raw(p_to) x where br is null or x.branch_id = br;
end $$;

-- plans_overview: (src: 0039_payment_plans.sql)
create or replace function public.plans_overview(p_party_type text default null, p_party uuid default null)
returns table(plan_id uuid, party_type text, party_id uuid, party_name text, title text, total bigint, paid bigint, remaining bigint,
              next_due date, next_amount bigint, overdue bigint, status text, created_at timestamptz, installments jsonb)
language plpgsql stable security definer set search_path = public as $$
#variable_conflict use_column
declare s uuid := public.current_shop_id(); today date := (now() at time zone 'Africa/Cairo')::date; soon integer := public.reminder_days(); br uuid;
begin
  perform public.grant_require('finance', 'view');
  br := public.party_branch();
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
  -- السداد بيتوزع على كل خطط الطرف الأول، وبعدها الموظف يشوف خطط فرعه بس
  where br is null or coalesce(pd.branch_id, public.main_branch(s)) = br
  order by (pd.got >= pd.total), (select min(x.due_date) from inst x where x.plan_id = pd.id and x.covered < x.amount) nulls last, pd.created_at;
end $$;

-- cancel_plan: (src: 0039_payment_plans.sql)
create or replace function public.cancel_plan(p_id uuid) returns void
language plpgsql security definer set search_path = public as $$
begin
  perform public.grant_require('finance', 'delete');
  update public.payment_plans set deleted_at = now() where id = p_id and shop_id = public.current_shop_id() and deleted_at is null
    and (public.current_app_role() = 'owner' or public.can_branch(coalesce(branch_id, public.main_branch(shop_id))));
  if not found then raise exception 'E_NOT_FOUND'; end if;
end $$;

-- القراية المباشرة لخطط الأقساط: فروع الموظف بس
drop policy plans_select on public.payment_plans;
create policy plans_select on public.payment_plans for select to authenticated
  using (shop_id = (select public.current_shop_id()) and ((select public.current_app_role()) = 'owner'
    or ((select public.current_app_role()) = 'reception' and (select public.has_perm('finance', 'view')) and (branch_id in (select unnest(public.my_branch_ids())) or branch_id is null and (select public.all_my_branches())))));
drop policy installments_select on public.plan_installments;
create policy installments_select on public.plan_installments for select to authenticated
  using (shop_id = (select public.current_shop_id()) and exists (select 1 from public.payment_plans p where p.id = plan_id));
$m0085$;
  insert into public.app_migrations(version, how) values ('0085_finance_branch.sql', 'applied');
  raise notice 'applied %', '0085_finance_branch.sql';
end $run$;
commit;

-- ============================== 0086_finance_cards.sql ==============================
begin;
do $run$ begin
  if exists (select 1 from public.app_migrations where version = '0086_finance_cards.sql') then return; end if;
  execute $m0086$
-- 0086: (قرار صاحب المشروع 2026-11-24) كروت المالية للموظف: صافي القيمة وحقوق الملكية لصاحب المحل بس، و"ليّا" و"عليّا" من غير المرتبات والسلف.

-- financial_position: (src: 0085_finance_branch.sql)
create or replace function public.financial_position(p_from timestamptz, p_to timestamptz, p_branch uuid default null) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare
  s uuid := public.current_shop_id();
  res jsonb;
  own boolean := public.current_app_role() = 'owner';
begin
  perform public.grant_require('finance', 'view');
  -- الموظف: فرع واحد من فروعه دايمًا، ومن غير إجماليات المحل كله
  if public.current_app_role() <> 'owner' and (p_branch is null or not public.can_branch(p_branch)) then p_branch := public.op_branch(); end if;
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
    -- المرتبات والسلف لصاحب المحل بس
    where own or kind not in ('advances', 'salaries')
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
    -- الضريبة على المحل كله لصاحب المحل، وللموظف فرعه
    'vat_due', (select coalesce(sum(l.credit - l.debit), 0)::bigint from public.journal_lines l join public.accounts a on a.id = l.account_id where l.shop_id = s and a.kind = 'tax' and (own or exists (select 1 from public.journal_entries te where te.id = l.entry_id and te.branch_id = p_branch))),
    'partners_due', case when own then p.partners_due end,
    -- قيمة المحل = الأصول − الالتزامات اللي لناس من بره بس (رأس مال الشركاء وأرباحهم حقوق ملكية، فما بتقللهاش)
    'net_worth', case when own then p.cash + p.receivables + p.payables_debit + p.fixed_assets - p.payables
      + case when p_branch is null then p.inventory else (select coalesce(sum(m.value), 0)::bigint from public.stock_moves m where m.shop_id = s and m.branch_id = p_branch) end end,
    'branch', p_branch,
    -- حقوق الملكية بالتفصيل (من أول يوم): رأس مال صاحب المحل، والسحوبات، ورأس مال وجاري كل شريك، والأرباح المحتجزة
    'equity_parts', case when own then jsonb_build_object(
      'owner_capital', coalesce((select b from acc where code = 'capital'), 0),
      'drawings', -coalesce((select b from acc where code = 'drawings'), 0),
      'retained', eq.earnings + coalesce((select b from acc where code = 'retained'), 0),
      'partners', coalesce((select jsonb_agg(jsonb_build_object('id', pt.id, 'name', pt.name, 'share_bp', pt.share_bp,
          'capital', coalesce((select sum(b.b) from bal b where b.kind = 'partner_capital' and b.party_id = pt.id), 0),
          'current', coalesce((select sum(b.b) from bal b where b.kind = 'partner_current' and b.party_id = pt.id), 0)) order by pt.share_bp desc, pt.name)
        from public.partners pt where pt.shop_id = s and (pt.deleted_at is null or exists (select 1 from bal b where b.party_id = pt.id and b.b <> 0))), '[]'::jsonb)) end,
    'equation', case when own then jsonb_build_object('assets', eq_all.assets, 'liabilities', eq_all.liabilities, 'equity', eq_all.equity, 'earnings', eq_all.earnings) end,
    'debits', case when own then tot.d end, 'credits', case when own then tot.c end, 'unbalanced_entries', unb.n,
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
$m0086$;
  insert into public.app_migrations(version, how) values ('0086_finance_cards.sql', 'applied');
  raise notice 'applied %', '0086_finance_cards.sql';
end $run$;
commit;

-- ============================== 0087_private_finance.sql ==============================
begin;
do $run$ begin
  if exists (select 1 from public.app_migrations where version = '0087_private_finance.sql') then return; end if;
  execute $m0087$
-- 0087: (قرار صاحب المشروع 2026-11-24) المرتبات ورأس المال: صلاحية لوحدها (private_finance ← يشوف)، مقفولة لكل الأدوار ما عدا صاحب المحل. الفني عمره ما ياخدها.
-- من غيرها: مش في الميزان ولا الأرباح ولا أرقام الوضع المالي، وفي كشف الخزنة والتقرير اليومي "حركة خاصة" بالمبلغ بس، والقيد نفسه ما بيتقراش من الجداول.
-- صافي القيمة وحقوق الملكية والشركاء لصاحب المحل بس زي ما هم.

-- perm_sections: (src: 0083_print_perm.sql) + private_finance
create or replace function public.perm_sections() returns text[]
language sql immutable as $$
  select array['devices', 'intake', 'customers', 'technicians', 'inventory', 'item_create', 'sales', 'purchases', 'cashbox', 'expenses', 'finance', 'private_finance', 'partners', 'reports', 'staff', 'settings', 'print_templates', 'audit']
$$;

create or replace function public.can_private() returns boolean
language sql stable security definer set search_path = public as $$
  select coalesce(public.current_app_role() = 'owner' or (public.current_app_role() = 'reception' and public.has_perm('private_finance', 'view')), false)
$$;
revoke execute on function public.can_private() from public, anon;
grant execute on function public.can_private() to authenticated;

-- حساب مرتبات أو رأس مال
create or replace function public.private_account(p_kind text, p_code text) returns boolean
language sql immutable as $$
  select p_kind in ('advances', 'salaries', 'capital', 'drawings', 'partner_capital', 'partner_current', 'retained') or coalesce(p_code = 'exp_salaries', false)
$$;

-- قيد فيه أي سطر على حساب منهم
create or replace function public.private_entry(p_entry uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.journal_lines l join public.accounts a on a.id = l.account_id where l.entry_id = p_entry and public.private_account(a.kind, a.code))
$$;
revoke execute on function public.private_entry(uuid) from public, anon;
grant execute on function public.private_entry(uuid) to authenticated;

-- party_balances: (src: 0084_party_branch.sql)
create or replace function public.party_balances(p_kind text)
returns table(party_type text, party_id uuid, name text, account text, balance bigint, oldest timestamptz)
language plpgsql stable security definer set search_path = public as $$
#variable_conflict use_column
declare s uuid := public.current_shop_id(); br uuid := public.party_branch();
begin
  perform public.grant_require('finance', 'view');
  if p_kind = 'employees' and not public.can_private() then raise exception 'E_FORBIDDEN'; end if;
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

-- statement: (src: 0084_party_branch.sql)
create or replace function public.statement(p_kind text, p_id uuid, p_from timestamptz, p_to timestamptz) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare
  s uuid := public.current_shop_id();
  accs uuid[];
  parties uuid[] := array[p_id];
  lk public.party_links;
  opening bigint;
  priv boolean := public.can_private();
  br uuid; -- كشف العميل والمورد للموظف: فرعه بس. الخزنة ليها فحصها
  res jsonb;
begin
  perform public.grant_require('finance', 'view');
  -- المرتبات والشركاء لصاحب المحل بس، والخزنة لازم تكون في فروع الموظف
  if public.current_app_role() <> 'owner' and (p_kind = 'partner' or (p_kind = 'employee' and not priv)
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
    -- الخزنة: حركة المرتبات ورأس المال بالمبلغ بس (عشان الرصيد وإقفال الدرج)
    select e.id as entry_id, e.entry_no, e.occurred_at, case when h.hide then 'private' else e.source_type end as source_type, case when not h.hide then e.source_id end as source_id,
           case when not h.hide then e.device_id end as device_id, case when not h.hide then e.memo end as memo, case when not h.hide then e.reverses_id end as reverses_id,
           case when not h.hide then d.order_no end as order_no, case when not h.hide then p.full_name end as by_name, a.code as account_code,
           ((l.debit - l.credit) * (case when p_kind = 'linked' then 1 else public.account_sign(a.type) end))::bigint as amount
    from public.journal_lines l
    join public.accounts a on a.id = l.account_id
    join public.journal_entries e on e.id = l.entry_id
    left join public.devices d on d.id = e.device_id
    left join public.profiles p on p.id = e.created_by
    cross join lateral (select p_kind = 'cashbox' and not priv and public.private_entry(e.id) as hide) h
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

-- trial_balance: (src: 0085_finance_branch.sql)
create or replace function public.trial_balance(p_branch uuid default null, p_to timestamptz default null)
returns table(account_id uuid, code text, name text, type text, kind text, debit bigint, credit bigint, balance bigint)
language plpgsql stable security definer set search_path = public as $$
#variable_conflict use_column
declare priv boolean := public.can_private();
begin
  perform public.grant_require('finance', 'view');
  if p_branch is not null and public.current_app_role() <> 'owner' and not public.can_branch(p_branch) then raise exception 'E_FORBIDDEN'; end if;
  if p_branch is null then p_branch := public.party_branch(); end if;
  return query
  with b as (select * from public.branch_lines_raw(p_to) bl where p_branch is null or bl.branch_id = p_branch),
  t as (select b.account_id acc, sum(greatest(b.amount, 0))::bigint dr, sum(greatest(-b.amount, 0))::bigint cr from b group by 1)
  select t.acc, a.code, a.name, coalesce(a.type::text, 'inter_branch'), coalesce(a.kind, 'inter_branch'), t.dr, t.cr, (t.dr - t.cr)::bigint
  from t left join public.accounts a on a.id = t.acc
  where (t.dr - t.cr <> 0 or t.acc is null and p_branch is not null) and (priv or a.id is null or not public.private_account(a.kind, a.code))
  order by case coalesce(a.type::text, 'inter_branch') when 'asset' then 1 when 'liability' then 2 when 'equity' then 3 when 'revenue' then 4 when 'expense' then 5 else 6 end, a.code nulls last, a.name;
end $$;

-- pl_breakdown: (src: 0085_finance_branch.sql)
create or replace function public.pl_breakdown(p_from timestamptz, p_to timestamptz, p_branch uuid default null)
returns table(account_id uuid, code text, name text, type public.account_type, amount bigint)
language plpgsql stable security definer set search_path = public as $$
declare priv boolean := public.can_private();
begin
  perform public.grant_require('finance', 'view');
  -- الموظف: فرع واحد من فروعه
  if public.current_app_role() <> 'owner' and (p_branch is null or not public.can_branch(p_branch)) then p_branch := public.op_branch(); end if;
  return query
  select a.id, a.code, a.name, a.type,
         sum(case when a.type = 'revenue' then l.credit - l.debit else l.debit - l.credit end)::bigint
  from public.journal_lines l
  join public.accounts a on a.id = l.account_id
  join public.journal_entries e on e.id = l.entry_id
  where l.shop_id = public.current_shop_id() and a.type in ('revenue', 'expense') and e.occurred_at >= p_from and e.occurred_at < p_to and (priv or not public.private_account(a.kind, a.code))
    and (p_branch is null or e.branch_id = p_branch)
  group by a.id
  having sum(l.debit - l.credit) <> 0
  order by a.type desc, 5 desc;
end $$;

-- branch_lines: (src: 0085_finance_branch.sql)
create or replace function public.branch_lines(p_to timestamptz default null)
returns table(entry_id uuid, occurred_at timestamptz, source_type text, branch_id uuid, account_id uuid, amount bigint)
language plpgsql stable security definer set search_path = public as $$
#variable_conflict use_column
declare br uuid; priv boolean := public.can_private();
begin
  perform public.grant_require('finance', 'view');
  br := public.party_branch();
  return query select * from public.branch_lines_raw(p_to) x where (br is null or x.branch_id = br)
    and (priv or not exists (select 1 from public.accounts a where a.id = x.account_id and public.private_account(a.kind, a.code)));
end $$;

-- financial_position: (src: 0086_finance_cards.sql)
create or replace function public.financial_position(p_from timestamptz, p_to timestamptz, p_branch uuid default null) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare
  s uuid := public.current_shop_id();
  res jsonb;
  own boolean := public.current_app_role() = 'owner';
  priv boolean := public.can_private(); -- المرتبات ورأس المال
begin
  perform public.grant_require('finance', 'view');
  -- الموظف: فرع واحد من فروعه دايمًا، ومن غير إجماليات المحل كله
  if public.current_app_role() <> 'owner' and (p_branch is null or not public.can_branch(p_branch)) then p_branch := public.op_branch(); end if;
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
    where l.shop_id = s and e.occurred_at >= p_from and e.occurred_at < p_to and (p_branch is null or e.branch_id = p_branch) and (priv or not public.private_account(a.kind, a.code))
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
    where priv or kind not in ('advances', 'salaries')
  ),
  days as (
    select (date_trunc('day', e.occurred_at at time zone 'Africa/Cairo'))::date as day,
           coalesce(sum(case when a.type = 'revenue' then l.credit - l.debit else 0 end), 0)::bigint as revenue,
           coalesce(sum(case when a.type = 'expense' then l.debit - l.credit else 0 end), 0)::bigint as expenses
    from public.journal_lines l join public.accounts a on a.id = l.account_id join public.journal_entries e on e.id = l.entry_id
    where l.shop_id = s and e.occurred_at >= p_from and e.occurred_at < p_to and a.type in ('revenue', 'expense') and (p_branch is null or e.branch_id = p_branch) and (priv or not public.private_account(a.kind, a.code))
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
    -- الضريبة على المحل كله لصاحب المحل، وللموظف فرعه
    'vat_due', (select coalesce(sum(l.credit - l.debit), 0)::bigint from public.journal_lines l join public.accounts a on a.id = l.account_id where l.shop_id = s and a.kind = 'tax' and (own or exists (select 1 from public.journal_entries te where te.id = l.entry_id and te.branch_id = p_branch))),
    'partners_due', case when own then p.partners_due end,
    -- قيمة المحل = الأصول − الالتزامات اللي لناس من بره بس (رأس مال الشركاء وأرباحهم حقوق ملكية، فما بتقللهاش)
    'net_worth', case when own then p.cash + p.receivables + p.payables_debit + p.fixed_assets - p.payables
      + case when p_branch is null then p.inventory else (select coalesce(sum(m.value), 0)::bigint from public.stock_moves m where m.shop_id = s and m.branch_id = p_branch) end end,
    'branch', p_branch,
    -- حقوق الملكية بالتفصيل (من أول يوم): رأس مال صاحب المحل، والسحوبات، ورأس مال وجاري كل شريك، والأرباح المحتجزة
    'equity_parts', case when own then jsonb_build_object(
      'owner_capital', coalesce((select b from acc where code = 'capital'), 0),
      'drawings', -coalesce((select b from acc where code = 'drawings'), 0),
      'retained', eq.earnings + coalesce((select b from acc where code = 'retained'), 0),
      'partners', coalesce((select jsonb_agg(jsonb_build_object('id', pt.id, 'name', pt.name, 'share_bp', pt.share_bp,
          'capital', coalesce((select sum(b.b) from bal b where b.kind = 'partner_capital' and b.party_id = pt.id), 0),
          'current', coalesce((select sum(b.b) from bal b where b.kind = 'partner_current' and b.party_id = pt.id), 0)) order by pt.share_bp desc, pt.name)
        from public.partners pt where pt.shop_id = s and (pt.deleted_at is null or exists (select 1 from bal b where b.party_id = pt.id and b.b <> 0))), '[]'::jsonb)) end,
    'equation', case when own then jsonb_build_object('assets', eq_all.assets, 'liabilities', eq_all.liabilities, 'equity', eq_all.equity, 'earnings', eq_all.earnings) end,
    'debits', case when own then tot.d end, 'credits', case when own then tot.c end, 'unbalanced_entries', unb.n,
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

-- day_cash_report: (src: 0085_finance_branch.sql)
create or replace function public.day_cash_report(p_from timestamptz, p_to timestamptz, p_branch uuid default null) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare
  s uuid := public.current_shop_id();
  res jsonb;
  priv boolean := public.can_private();
begin
  perform public.grant_require('finance', 'view');
  if public.current_app_role() <> 'owner' and (p_branch is null or not public.can_branch(p_branch)) then
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
        'entries', coalesce((select jsonb_agg(jsonb_build_object('entry_id', m.entry_id, 'entry_no', m.entry_no, 'source_type', case when h.hide then 'private' else m.source_type end,
            'memo', case when not h.hide then m.memo end, 'at', m.occurred_at, 'in', m.debit, 'out', m.credit, 'cancelled', m.cancelled) order by m.occurred_at, m.entry_no)
          from mv m cross join lateral (select not priv and public.private_entry(m.entry_id) as hide) h where m.account_id = b.id), '[]'::jsonb)) as x
      from boxes b
      cross join lateral (select coalesce(sum(l.debit - l.credit), 0)::bigint as opening from public.journal_lines l join public.journal_entries e on e.id = l.entry_id
                          where l.account_id = b.id and e.occurred_at < p_from) o
      left join lateral (select sum(m.debit)::bigint as d, sum(m.credit)::bigint as c from mv m where m.account_id = b.id) t on true
      -- الخزنة اللي ما اتحركتش ورصيدها صفر ما بتظهرش
      where o.opening <> 0 or t.d is not null) y), '[]'::jsonb)
  ) into res;
  return res;
end $$;

-- accountant_export: (src: 0085_finance_branch.sql)
create or replace function public.accountant_export(p_from date, p_to date, p_branch uuid default null) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  s uuid := public.current_shop_id(); own boolean := public.current_app_role() = 'owner'; names boolean; res jsonb; priv boolean := public.can_private();
  f timestamptz; t timestamptz;
begin
  perform public.grant_require('finance', 'view');
  perform public.grant_require('finance', 'export');
  if p_from is null or p_to is null or not isfinite(p_from) or not isfinite(p_to) or p_to < p_from or p_to - p_from > 366 then raise exception 'E_BAD_INPUT'; end if;
  f := p_from::timestamp at time zone 'Africa/Cairo';
  t := (p_to + 1)::timestamp at time zone 'Africa/Cairo';
  if public.current_app_role() <> 'owner' and (p_branch is null or not public.can_branch(p_branch)) then
    p_branch := public.op_branch();
    if p_branch is null then raise exception 'E_FORBIDDEN'; end if;
  end if;
  if p_branch is not null and not exists (select 1 from public.branches where id = p_branch and shop_id = s) then raise exception 'E_BAD_BRANCH'; end if;
  names := own or public.has_perm('customers', 'view');
  with ent as materialized (
    select e.* from public.journal_entries e
    where e.shop_id = s and e.occurred_at >= f and e.occurred_at < t and (p_branch is null or e.branch_id = p_branch)
      and (own or not exists (select 1 from public.journal_lines l join public.accounts a on a.id = l.account_id
                              where l.entry_id = e.id and (not priv and public.private_account(a.kind, a.code)
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

-- entry_require: (src: 0075_delete_by_section.sql)
create or replace function public.entry_require(p_entry uuid) returns void
language plpgsql stable security definer set search_path = public as $$
begin
  if public.current_app_role() = 'owner' then return; end if;
  if public.can_delete((select public.entry_section(e.source_type) from public.journal_entries e where e.id = p_entry)) is not true then raise exception 'E_FORBIDDEN'; end if;
  if not public.can_private() and public.private_entry(p_entry) then raise exception 'E_FORBIDDEN'; end if;
  if exists (select 1 from public.journal_entries e where e.id = p_entry and (e.source_type = 'vat_payment' or not public.can_branch(e.branch_id)))
     or exists (select 1 from public.journal_lines l join public.accounts a on a.id = l.account_id where l.entry_id = p_entry
                and (a.kind in ('advances', 'salaries', 'partner_capital', 'partner_current', 'capital', 'drawings') or (a.kind = 'cash' and not public.can_branch(a.branch_id))))
     or exists (select 1 from public.stock_moves m where m.entry_id = p_entry and not public.can_branch(m.branch_id)) then
    raise exception 'E_FORBIDDEN';
  end if;
end $$;

-- ---------- القراية المباشرة ----------
drop policy staff_entries_select on public.journal_entries;
create policy staff_entries_select on public.journal_entries for select to authenticated
  using (shop_id = (select public.current_shop_id()) and (select public.current_app_role()) = 'reception' and (select public.has_perm('finance', 'view')) and public.can_branch(branch_id)
         and ((select public.can_private()) or not public.private_entry(id)));
drop policy staff_lines_select on public.journal_lines;
create policy staff_lines_select on public.journal_lines for select to authenticated
  using (shop_id = (select public.current_shop_id()) and (select public.current_app_role()) = 'reception' and (select public.has_perm('finance', 'view'))
         and exists (select 1 from public.journal_entries e where e.id = entry_id and public.can_branch(e.branch_id))
         and ((select public.can_private()) or not public.private_entry(entry_id)));
drop policy staff_accounts_select on public.accounts;
create policy staff_accounts_select on public.accounts for select to authenticated
  using (shop_id = (select public.current_shop_id()) and (select public.current_app_role()) = 'reception' and (select public.has_perm('finance', 'view'))
         and (kind <> 'cash' or public.can_branch(branch_id)) and ((select public.can_private()) or kind not in ('advances', 'salaries', 'partner_capital', 'partner_current')));
drop policy staff_audit_select on public.audit_log;
create policy staff_audit_select on public.audit_log for select to authenticated
  using (shop_id = (select public.current_shop_id()) and (select public.current_app_role()) = 'reception' and (select public.has_perm('audit', 'view'))
         and ((select public.can_private()) or not (entity in ('partners', 'profit_distributions', 'commission_rules') or (entity = 'journal_entries' and public.private_entry(entity_id)))));
$m0087$;
  insert into public.app_migrations(version, how) values ('0087_private_finance.sql', 'applied');
  raise notice 'applied %', '0087_private_finance.sql';
end $run$;
commit;

select 7 as part, 7 as parts, count(*) as applied_files, max(version) as latest,
  case when '0087_private_finance.sql' in (select version from public.app_migrations) then
    'خلص: المشروع على آخر نسخة'
  else 'فيه ملف ما اتطبقش' end as status
from public.app_migrations;
