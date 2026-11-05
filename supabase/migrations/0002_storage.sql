-- =====================================================================
-- المرحلة 1: تخزين صور الأجهزة (Supabase Storage)
-- الصور خاصة (private): محدش يشوفها غير موظفين نفس المحل.
-- مسار كل صورة: {shop_id}/{device_id}/{اسم الملف}
-- =====================================================================

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('device-photos', 'device-photos', false, 5242880, array['image/jpeg','image/png','image/webp'])
on conflict (id) do nothing;

create policy device_photos_read on storage.objects for select to authenticated
  using (
    bucket_id = 'device-photos'
    and (storage.foldername(name))[1] = public.current_shop_id()::text
  );

create policy device_photos_upload on storage.objects for insert to authenticated
  with check (
    bucket_id = 'device-photos'
    and (storage.foldername(name))[1] = public.current_shop_id()::text
    and public.current_app_role() in ('owner','reception')
  );
-- مفيش سياسة تعديل أو حذف: الصورة بتفضل محفوظة، والإخفاء بيحصل بـ deleted_at في جدول device_photos.
