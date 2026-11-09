// حالة المساعد الذكي من رد السيرفر (من غير أي بيانات): عشان الواجهة تقول السبب بالظبط بدل ما تختفي
export type AssistantState = 'on' | 'no-key' | 'no-function' | 'offline';

/**
 * - on: الدالة منشورة والمفتاح موجود.
 * - no-key: الدالة منشورة بس مفيش GEMINI_API_KEY في أسرار Supabase.
 * - no-function: الدالة "assistant" مش منشورة على المشروع (404) أو السيرفر مش بيرد عليها.
 * - offline: الجهاز من غير نت.
 */
export function assistantState(r: { data?: { enabled?: boolean } | null; status?: number | null; networkError?: boolean; online: boolean }): AssistantState {
  if (!r.online) return 'offline';
  if (r.data && typeof r.data.enabled === 'boolean') return r.data.enabled ? 'on' : 'no-key';
  if (r.status === 503) return 'no-key';
  return 'no-function';
}
