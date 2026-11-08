/**
 * مواعيد الافتتاحية.
 * الافتتاحية ليها ميزانية ثابتة من لحظة فتح البرنامج (مش من لحظة ما الكود يخلص تحميل):
 * - على جهاز عادي الكود بيحمّل بسرعة، فالمواعيد زي التصميم تقريبًا (0.85 ثانية + 0.4 للطيران، وأسرع بحوالي 10% بالكتير).
 * - على جهاز ضعيف (أول مرة خصوصًا) التحميل بياخد وقت، فنفس التسلسل بيمشي أسرع بنفس النسب،
 *   عشان المجموع يفضل أقل من ثانية ونص.
 */
/** حركة اللوجو (0.65) + نبضة التوهج (0.2): نفس INTRO_S في src/ui/LogoIntro.tsx */
export const SPLASH_ANIM_MS = 850;
export const HANDOFF_MS = 400;
/** من فتح البرنامج لحد ما اللوجو يستقر في مكانه */
export const SPLASH_BUDGET_MS = 1200;
/** أسرع حاجة مسموحة (عشان الحركة ما تبقاش خطفة) */
export const MIN_SPEED = 0.5;

/** معامل المدة (1 = زي التصميم، أقل = أسرع)، من الوقت اللي عدّى من فتح البرنامج لحد ما الافتتاحية ظهرت */
export function splashSpeed(startedAtMs: number): number {
  const left = SPLASH_BUDGET_MS - Math.max(0, startedAtMs);
  return Math.min(1, Math.max(MIN_SPEED, left / (SPLASH_ANIM_MS + HANDOFF_MS)));
}

let speed = 1;
let fixed = false;
/** بيتحدد مرة واحدة لما الافتتاحية تظهر أول مرة */
export function initSplashSpeed(startedAtMs: number): number {
  if (!fixed) {
    speed = splashSpeed(startedAtMs);
    fixed = true;
  }
  return speed;
}
export const getSplashSpeed = () => speed;

/** آخر وقت (من فتح البرنامج) اللوجو المفروض يكون استقر فيه */
export const LAND_BY_MS = 1350;
/** أقصر مدة للطيران (عشان يفضل باين إنه بيطير لمكانه) */
export const MIN_HANDOFF_MS = 200;

/**
 * مدة طيران اللوجو، محسوبة لحظة ما الطيران يبدأ: لو الجهاز اتأخر في الرسم وسط الافتتاحية،
 * الطيران بياخد الوقت الباقي بس، عشان اللوجو يستقر قبل ثانية ونص.
 */
export function handoffDuration(nowMs: number, speedFactor: number): number {
  const normal = HANDOFF_MS * speedFactor;
  return Math.round(Math.min(normal, Math.max(MIN_HANDOFF_MS, LAND_BY_MS - nowMs)));
}

let handoff: number | null = null;
/** بتتحسب مرة واحدة أول ما الطيران يبدأ، وكل اللي محتاجها (الطيران نفسه ومؤقّت النهاية) بياخدوا نفس الرقم */
export function getHandoffMs(): number {
  if (handoff === null) handoff = handoffDuration(performance.now(), speed);
  return handoff;
}
