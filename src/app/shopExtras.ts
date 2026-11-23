import { supabase } from '../lib/supabase';

/** حفظ مفاتيح من shops.extras بس (الباقي زي ما هو على السيرفر). merge: القيم اللي object بتتحط فوق القديمة */
export function saveExtras(patch: Record<string, unknown>, merge = false) {
  return supabase.rpc('set_shop_extras', { p_patch: patch, p_merge: merge });
}
