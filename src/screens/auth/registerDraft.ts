import type { Session } from '@supabase/supabase-js';

// بيانات التسجيل المحفوظة (في ملف لوحده عشان App.tsx يستخدمها من غير ما يحمّل المعالج كله)
const DRAFT = 'reg-draft';
/** shop = تسجيل محل جديد (6 خطوات) · invite = موظف معاه دعوة (الحساب والكود بس) */
export type WizardMode = 'shop' | 'invite';
export interface Draft {
  mode?: WizardMode;
  step: number;
  shopName: string;
  ownerName: string;
  shopPhone: string;
  area: string;
  email: string;
}
export function loadDraft(): Draft | null {
  try {
    const v = sessionStorage.getItem(DRAFT);
    return v ? (JSON.parse(v) as Draft) : null;
  } catch {
    return null;
  }
}
export function saveDraft(d: Draft | null) {
  try {
    if (d) sessionStorage.setItem(DRAFT, JSON.stringify(d));
    else sessionStorage.removeItem(DRAFT);
  } catch {
    /* تجاهل */
  }
}
export function hasRegisterDraft(): boolean {
  return loadDraft() !== null;
}

/**
 * بيانات التسجيل اللي بتتحفظ مع الحساب نفسه (user_metadata) وقت signUp.
 * عشان لو رابط التأكيد اتفتح في تبويب تاني أو على جهاز تاني، التسجيل يكمّل من غير ما يسأل تاني.
 * دي بيانات لملء الخانات بس، والصلاحيات بتتحدد في قاعدة البيانات.
 */
export interface RegMeta {
  reg_mode?: WizardMode;
  shop_name?: string;
  owner_name?: string;
  shop_phone?: string;
  area?: string;
}
export function regMeta(session: Session | null): RegMeta | null {
  const m = session?.user.user_metadata as RegMeta | undefined;
  return m?.reg_mode === 'shop' || m?.reg_mode === 'invite' ? m : null;
}
export function draftMode(session: Session | null = null): WizardMode {
  return loadDraft()?.mode ?? regMeta(session)?.reg_mode ?? 'shop';
}
