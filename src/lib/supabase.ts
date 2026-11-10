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
