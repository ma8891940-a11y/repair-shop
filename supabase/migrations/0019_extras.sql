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
