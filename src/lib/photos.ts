import { supabase, PHOTO_BUCKET } from './supabase';

export const MAX_PHOTOS = 6;

/** يصغّر الصورة قبل الرفع (أقصى ضلع 1600 بكسل، JPEG) عشان النت الضعيف ومساحة التخزين */
export async function shrinkImage(file: File, maxSide = 1600, quality = 0.8): Promise<Blob> {
  const bitmap = await createImageBitmap(file);
  const scale = Math.min(1, maxSide / Math.max(bitmap.width, bitmap.height));
  const w = Math.round(bitmap.width * scale);
  const h = Math.round(bitmap.height * scale);
  const canvas = document.createElement('canvas');
  canvas.width = w;
  canvas.height = h;
  canvas.getContext('2d')!.drawImage(bitmap, 0, 0, w, h);
  bitmap.close();
  return new Promise((resolve, reject) =>
    canvas.toBlob((b) => (b ? resolve(b) : reject(new Error('IMAGE_PROCESSING_FAILED'))), 'image/jpeg', quality),
  );
}

/** يرفع صورة لجهاز: الملف في Storage + صف في جدول device_photos */
export async function uploadDevicePhoto(shopId: string, deviceId: string, file: File): Promise<void> {
  const blob = await shrinkImage(file);
  const id = crypto.randomUUID();
  const path = `${shopId}/${deviceId}/${id}.jpg`;
  const { error: upErr } = await supabase.storage.from(PHOTO_BUCKET).upload(path, blob, {
    contentType: 'image/jpeg',
    upsert: false,
  });
  if (upErr) throw upErr;
  const { error } = await supabase
    .from('device_photos')
    .insert({ id, shop_id: shopId, device_id: deviceId, storage_path: path });
  if (error) throw error;
}

export async function signedPhotoUrls(paths: string[]): Promise<Record<string, string>> {
  if (paths.length === 0) return {};
  const { data, error } = await supabase.storage.from(PHOTO_BUCKET).createSignedUrls(paths, 3600);
  if (error) throw error;
  const out: Record<string, string> = {};
  for (const item of data ?? []) if (item.path && item.signedUrl) out[item.path] = item.signedUrl;
  return out;
}
