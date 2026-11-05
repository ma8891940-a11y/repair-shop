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
