import { createClient, type SupabaseClient } from '@supabase/supabase-js';
import { branchFetch } from './branchHeader';

// القيم دي بتيجي من ملف .env.local اللي صاحب المشروع بيكتبه بنفسه.
// anon key بس. ممنوع service_role هنا.
const url = import.meta.env.VITE_SUPABASE_URL as string | undefined;
const anonKey = import.meta.env.VITE_SUPABASE_ANON_KEY as string | undefined;

export const isConfigured = Boolean(url && anonKey);

export const supabase: SupabaseClient = isConfigured
  ? createClient(url!, anonKey!, { auth: { persistSession: true, autoRefreshToken: true }, global: { fetch: branchFetch() } })
  : (null as unknown as SupabaseClient);

export const PHOTO_BUCKET = 'device-photos';

/**
 * C1: عميل Supabase مؤقت للصفحات العامة اللي بتشتغل بـ token (رفع صور الاستلام من الموبايل، وصور صفحة التتبع).
 * الـ token بيتبعت في header، وسياسات Storage في القاعدة هي اللي بتتأكد منه. من غير جلسة دخول.
 */
export function tokenClient(header: 'x-upload-token' | 'x-track-token', token: string): SupabaseClient {
  return createClient(url!, anonKey!, {
    auth: { persistSession: false, autoRefreshToken: false, detectSessionInUrl: false, storageKey: `tok-${header}` },
    global: { headers: { [header]: token } },
  });
}
