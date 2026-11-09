// قبل أي تشغيل لاختبارات قاعدة البيانات: قاعدة الاختبار المحلية بتتنضف (من غير محلات ولا مستخدمين)،
// عشان النتايج تفضل سريعة وما تتأثرش بداتا تشغيلات قديمة. على أي قاعدة مش محلية ما بيعملش حاجة.
// تقدر تقفله بـ TEST_DB_RESET=0 (مثلًا لو عايز تبص على الداتا بعد اختبار).
import { isLocalDb, purgeAll } from './purgeCore';

export default async function setup() {
  const url = process.env.TEST_DATABASE_URL;
  if (!isLocalDb(url) || process.env.TEST_DB_RESET === '0') return;
  await purgeAll(url);
}
