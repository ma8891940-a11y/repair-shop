# مهمة Codex رقم 001: قالب "كشف الحساب" في مصمم الطباعة (جزء من U5)

- **الفرع:** `codex/statement-template` (في worktree منفصل: `../repair-shop-codex`)
- **المسؤول:** codex · **المراجع:** claude
- **الحالة (2026-11-18):** عملها Claude بدل Codex (الحد المجاني خلص لحد 2026-12-18)، على فرع `claude/statement-template`.
- **اقرا الأول:** `AGENTS.md` كله.

## المطلوب بالظبط
مصمم الطباعة (الإعدادات ← الطابعات ومصمم الطباعة) فيه دلوقتي 3 أنواع ورق: الإيصال الحراري، والإيصال A4، والفاتورة.
المطلوب: نوع رابع **"كشف الحساب"** (`statement`)، وصفحة طباعة كشف الحساب تمشي على القالب ده.

1. **`src/lib/printTemplate.ts`:**
   - زوّد `'statement'` على `TemplateDoc`.
   - زوّد خانات جديدة على `BlockKey` خاصة بالكشف:
     - `party` (اسم العميل أو المورد أو الخزنة).
     - `period` (الفترة).
     - `opening` (الرصيد الافتتاحي).
     - `moves` (جدول الحركات).
     - `closing` (الرصيد الختامي).
   - `DOC_BLOCKS.statement` = `['header', 'title', 'party', 'period', 'opening', 'moves', 'closing', 'signature', 'thanks']`، و"نص حر" (`text`) مسموح زي باقي الأنواع.
   - `defaultBlocks('statement')`: الافتراضي لازم يطلع **نفس شكل الكشف الحالي بالظبط**. يعني:
     - كل الخانات ظاهرة، ما عدا `signature` و`thanks` يكونوا مخفيين.
     - `closing` عريض وحجمه `lg`.
   - `normalizeBlocks` تشتغل على النوع الجديد زي القديم (الخانة المجهولة بتتشال، والناقصة بتتضاف مخفية).
2. **`src/screens/settings/PrintersTab.tsx`:**
   - زوّد `'statement'` على `DOCS`، عشان يظهر في اختيار نوع الورقة.
   - من غير أي تغيير تاني في الحفظ أو الجداول.
3. **`src/screens/finance/FinancePrint.tsx` (الدالة `StatementPrint` بس):**
   - هات القالب الافتراضي من `print_templates` بنفس طريقة `PrintScreen.tsx`، وهي:
     ```
     .eq('doc', 'statement').eq('is_default', true).is('deleted_at', null)
     ```
     ولو فيه قالب للفرع يكسب، ولو مفيش قالب خالص استخدم `defaultBlocks('statement')`.
   - اعرض الخانات بترتيب القالب. الخانة المخفية ما تظهرش، والحجم والمحاذاة والعريض بيتطبقوا. و"نص حر" يظهر مكانه.
   - **المبالغ والأرقام ما تتغيرش خالص:**
     - نفس `f.money(...)`، ونفس البيانات من `rpc('statement')`.
     - ممنوع أي حساب جديد: لا جمع، ولا طرح، ولا تقريب.
   - `PrintHeader` يفضل هو اللي بيطبع اسم المحل ولوجوه (خانة `header`).
   - خلّي `data-testid` ثابتة للاختبار: `statement-opening` و`statement-closing` و`statement-moves` و`statement-party`.
4. **الترجمة:** أسماء الخانات الجديدة ونوع الورقة الجديد في `src/i18n/ar.json` و`src/i18n/en.json` (نفس المفاتيح في الاتنين، جنب مفاتيح أسماء الخانات الموجودة).

## الملفات المسموح تلمسها بس
- `src/lib/printTemplate.ts` و`src/lib/printTemplate.test.ts`
- `src/screens/settings/PrintersTab.tsx`
- `src/screens/finance/FinancePrint.tsx` (الدالة `StatementPrint` بس، وأي import محتاجه)
- `src/i18n/ar.json` و`src/i18n/en.json` (إضافة مفاتيح بس، ممنوع تغيير أو مسح مفتاح موجود)
- `tests/e2e/printStatement.spec.ts` (ملف جديد)

## ممنوع
- أي ملف في `supabase/` (قاعدة البيانات بتقبل `statement` أصلًا، فمفيش SQL).
- أي تغيير في حساب أو عرض المبالغ، أو في `rpc('statement')`، أو الدفتر، أو الصلاحيات.
- أي ملف تاني غير اللي فوق، و`package.json`، وتثبيت أي حزمة.
- `git push`، أو لمس فرع `main`، أو أي فرع غير `codex/statement-template`.
- تعطيل أو تخطي أي اختبار.
- نص عربي مكتوب في `.ts`/`.tsx`، أو ألوان أو مقاسات مكتوبة مباشرة برّه اللي موجود في صفحات الطباعة.

## الاختبارات المطلوبة
1. **`src/lib/printTemplate.test.ts`:** اختبارات للنوع الجديد:
   - `defaultBlocks('statement')` فيه الخانات بالترتيب، و`signature` و`thanks` مخفيين.
   - `normalizeBlocks('statement', ...)` بتشيل خانة من نوع تاني (مثلًا `imei`)، وبتضيف الناقصة مخفية.
2. **`tests/e2e/printStatement.spec.ts`** (على الأربع مشاريع):
   - سجّل محل.
   - اعمل عميل عليه دفعة أو حركة. استخدم نفس المساعدات اللي في `tests/e2e/helpers.ts`، وبص على `tests/e2e/printDesigner.spec.ts` كمثال.
   - افتح طباعة كشف حسابه، واتأكد إن الرصيد الافتتاحي والختامي ظاهرين.
   - من المصمم اختار "كشف الحساب"، واخفي خانة "الرصيد الافتتاحي" واحفظ. الكشف يطلع من غيرها، والختامي **نفس الرقم بالظبط**.
   - "رجّع الافتراضي" يرجّعها.
3. **شغّل وتأكد إنهم عدّوا:**
   - `npm run typecheck`
   - `npm run lint`
   - `npm test`
   - لو Supabase محلي شغال (Docker): `npm run test:e2e -- tests/e2e/printStatement.spec.ts tests/e2e/printDesigner.spec.ts --trace off`. لو مش متاح، اكتب ده صريح في الملخص.

## في الآخر
- commit واحد أو أكتر على `codex/statement-template` برسائل واضحة بالعربي.
- اكتب ملخص فيه:
  - الملفات اللي اتغيرت.
  - نتيجة كل أمر من اللي فوق بالأرقام.
  - أي حاجة ما اتعملتش أو ما اتختبرتش.
