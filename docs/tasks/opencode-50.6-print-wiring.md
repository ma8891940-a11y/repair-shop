# مهمة OpenCode 50.6: ربط شاشات الطباعة بالمحرّك الواحد

الفرع: `opencode/print-wiring` (متفرّع من `claude/print-engine`). اقرا `AGENTS.md` الأول.

## الموجود (ما تعدّلوش)
- `src/lib/printEngine.ts`: `pagePlan(mode, layout, printer, fallback, appLang)` بيرجع المقاس والهامش والإزاحة والخلفية واللغة، و`blockStyle(block)` (خط وحجم الخانة لو اتحددوا، وإلا `{}`)، و`DOC_PAGE` (المقاس الافتراضي لكل نوع).
- `src/app/print/engine.tsx`:
  - `loadTemplate(doc, branchId, ref?)`: قالب الفرع أو المحل الافتراضي وطابعته. لو `doc` فاتورة صيانة أو بيع أو سند و`ref` موجود: الشكل من `print_document` (النسخة الثابتة من أول طباعة) ومعاه `shop` (بيانات المحل وقت أول طباعة). بيرجع `null` لو مفيش قالب.
  - `useBgUrl(shopId, file)`، و`<PageStyle plan>` (الـ `@page`)، و`<Offset plan>` (إزاحة الطابعة)، و`<FreePage plan fields values bgUrl>` (القالب الحر: كل حقل في مكانه بالمللي).
- `src/screens/TestPrint.tsx`: مثال كامل بيستخدم كل ده (اقراه الأول).

## المطلوب
لكل شاشة من دول: التحميل والمقاس والإزاحة من المحرّك، والخط والحجم على كل خانة، والقالب الحر لو `mode === 'free'`. **شكل أي مستند من غير قالب، أو بقالب قديم (من غير `font` ولا `pt` ولا `paper`)، لازم يفضل زي ما هو بالظبط** (نفس الـ classes ونفس الـ `data-testid`).

1. `src/screens/PrintScreen.tsx` للأنواع `receipt` و`receipt-a4` و`invoice` بس (الاستيكر والملصق والـ `sticker-test` ما تلمسهمش):
   - بدل استعلام `print_templates` و`printers` اللي جوه `useLoad`: `loadTemplate(kind, d.branch_id, ref)`. الـ `ref` للفاتورة بس: آخر فاتورة مش `reversed` من `supabase.rpc('repair_invoices_of', { p_device: id })` (بترجع array فيها `id` و`reversed`)، ولو مفيش: من غير `ref`.
   - المعاينة (`preview=1` و`sessionStorage`) تفضل شغالة زي ما هي على `blocks`.
   - `const plan = pagePlan(tpl?.mode ?? 'flow', tpl?.layout, tpl?.printer, DOC_PAGE[kind], i18n.language)`. للأنواع التلاتة دول: `<PageStyle plan={plan} />` بدل الـ `<style>` بتاعة الـ `@page` (الاستيكر والملصق يفضلوا بالـ `<style>` القديمة)، والـ `article` جوه `<Offset plan={plan}>`.
   - كل خانة flow: `style={blockStyle(x)}` على العنصر الخارجي اللي عليه `data-block` (في `row` وكل `case`).
   - لو `tpl.shop` موجود (فاتورة متجمّدة): اسم المحل وتليفونه وعنوانه وشروطه منه (`name`، `phone`، `address`، `terms`)، واللوجو (`logo_color`، `logo_thermal`) بدل اللي في `useBranding` في الـ header.
   - لو `mode === 'free'`: `<FreePage>` بدل الـ `article`، والـ `values` من نفس البيانات (حقول `FREE_FIELDS[kind]` في `src/lib/printLayout.ts`): `shopName`، و`shopPhone`، و`shopAddress`، و`logo` (`<img>` بارتفاع 100%)، و`orderNo`، و`date`، و`customer`، و`phone`، و`device`، و`imei`، و`issue`، و`warranty`، و`terms`، و`qr` (صورة الـ QR بارتفاع 100%، فـ `qr` لازم يتحسب للفاتورة كمان لو الحقل موجود)، و`price` و`paid` و`remaining` (بـ `f.money` و`className="num"` و`dir="ltr"`)، و`parts`. `barcode` في الإيصال: سيبه فاضي.
   - الخلفية: `const bgUrl = useBgUrl(shop.id, plan.bg?.file)`، والطباعة التلقائية تستنى `bgUrl` لو `plan.bg` موجود.
   - لغة القالب: النصوص الثابتة (`t(...)`) بـ `i18n.getFixedT(plan.lang)` بدل `t` جوه المستند بس (الشريط اللي فوق بلغة البرنامج)، والـ `article` بـ `dir` و`lang` من `plan.lang`.
2. `src/screens/finance/FinancePrint.tsx`: كشف الحساب (flow بس، من غير `ref`)، والسند والبيع (`ref` = id القيد). نفس النقط: `loadTemplate`، و`PageStyle`، و`Offset`، و`blockStyle`، و`tpl.shop` للسند والبيع، والقالب الحر للسند والبيع (حقول `FREE_FIELDS.voucher` و`FREE_FIELDS.sale`).
3. `src/screens/finance/BarcodePrint.tsx`: `loadTemplate('barcode', ...)` والمقاس من `pagePlan` (الافتراضي `DOC_PAGE.barcode` أو ملف الطابعة زي دلوقتي)، و`blockStyle`، والقالب الحر (حقول `FREE_FIELDS.barcode`، و`barcode` = نفس مكوّن `Barcode` بارتفاع 100%). كل ملصق نسخة في صفحة لوحدها زي دلوقتي.

## الملفات المسموح بيها بس
- `src/screens/PrintScreen.tsx`
- `src/screens/finance/FinancePrint.tsx`
- `src/screens/finance/BarcodePrint.tsx`
- `tests/e2e/printEngine.spec.ts` (جديد)

## الممنوع
- أي ملف تاني (خصوصًا `src/lib/*`، و`src/app/print/engine.tsx`، و`supabase/`، وملفات الترجمة). لو محتاج نص جديد: اكتبه في الملخص.
- تغيير أي `data-testid` موجود، أو شكل أي مستند من غير قالب.
- أي حساب فلوس جديد: المبالغ زي ما هي جاية من البرنامج، والعرض بـ `f.money` بس.
- ألوان أو مقاسات مكتوبة مباشرة غير بالمللي على الورق (زي الموجود).
- `git push`، أو أي فرع تاني.

## الاختبارات
- `npm run typecheck` و`npm run lint` نضاف، و`npx vitest run src/lib` بيعدّي.
- `tests/e2e/printEngine.spec.ts` (Claude هيشغّله على GitHub، إنت مش هتقدر تشغّله): على نمط `tests/e2e/printTest.spec.ts`:
  - قالب `receipt-a4` حر (مقاس A4، وحقل `customer` في x=20 y=30، وحقل `price`) بطابعة إزاحتها 1 و1: الإيصال بيطلع `[data-field=customer]` باسم العميل في مكانه، والإزاحة `translate(1mm, 1mm)`.
  - قالب `receipt` flow فيه خانة `customer` بـ `font: 'mono'` و`pt: 14`: `[data-block=customer]` عليها `font-size: 14pt`.
  - من غير قالب: `print-receipt` بنفس شكله (اختبارات `print.spec.ts` الموجودة لازم تفضل تعدّي).

## في الآخر
commit على الفرع ده، وملخص: اللي اتعمل، واللي ما اتعملش وليه.
