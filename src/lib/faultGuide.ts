import words from './faultWords.json';

/**
 * دليل الأعطال المدمج (مجاني ومن غير نت): لو المساعد الذكي مش مفعّل، أو مفيش نت، أو الحد اليومي خلص.
 * كل عطل ليه كلمات بيتعرف بيها، وأسباب محتملة، وخطوات فحص، وتحذير لو فيه.
 * الكلام نفسه في ملفات الترجمة (guide.*)، والملف ده فيه المفاتيح والكلمات بس.
 */
/** المفاتيح بالترتيب، والكلمات (عربي وإنجليزي) في faultWords.json */
export const FAULTS = words as { key: FaultKey; words: string[] }[];
export type FaultKey = 'no_charge' | 'no_power' | 'screen' | 'battery' | 'water' | 'network' | 'audio' | 'camera' | 'software' | 'heat';

/** الأعطال اللي الوصف بيتكلم عنها، مرتبة بعدد الكلمات اللي اتلقت */
export function matchFaults(text: string): FaultKey[] {
  const s = (text ?? '').toLowerCase();
  return FAULTS.map((f) => ({ key: f.key, n: f.words.filter((w) => s.includes(w.toLowerCase())).length }))
    .filter((x) => x.n > 0)
    .sort((a, b) => b.n - a.n)
    .map((x) => x.key);
}
