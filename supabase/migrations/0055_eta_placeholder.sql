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
