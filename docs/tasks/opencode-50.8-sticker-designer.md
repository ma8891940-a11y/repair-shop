# مهمة OpenCode 50.8 (أ): ستيكر الجهاز جوه مصمم الطباعة

الفرع: `opencode/sticker-designer` (متفرّع من `claude/print-sticker`، وفيه محرّك 50.6). اقرا `AGENTS.md` الأول.

## الموجود (ما تعدّلوش)
- `src/lib/printPlan.ts`: `stickerLayout(st)`: قالب حر بنفس سطور الاستيكر الحالي من إعدادات الطباعة (`readPrint(shop.extras).sticker`).
- `src/lib/printLayout.ts`: `FREE_FIELDS.sticker` (الحقول المسموحة)، و`templateError(doc, mode, blocks, layout)` (نفس فحص السيرفر: `null` = سليم)، و`FreeField` (فيه `cap`: اسم الحقل قبل قيمته).
- `src/app/print/engine.tsx`: `loadTemplate`، و`FreePage` (فيها `caps`)، و`fieldCaps(doc, t)`، و`PageStyle`، و`useBgUrl`.
- `src/lib/printEngine.ts`: `pagePlan`.
- `src/screens/TestPrint.tsx`: الطباعة التجريبية (`#/print/test/sticker`) ومثال للاستخدام.

## المطلوب
1. **المصمم** (`src/screens/settings/PrintersTab.tsx`، الكومبوننت `Designer`):
   - "ستيكر الجهاز" يظهر في قايمة نوع الورقة (`tpl-doc`) **أول واحد**. الـ state بتاع النوع يبقى `PrintDoc` (من `printLayout`) بدل `TemplateDoc`.
   - لما النوع `sticker`: بدل قايمة الخانات، قايمة حقول (`data-testid="tpl-fields"`، وكل صف `data-testid="tpl-field"` و`data-key`):
     - البداية: `current.layout.fields` لو القالب المحفوظ `mode === 'free'`، وإلا `stickerLayout(readPrint(shop.extras).sticker)`.
     - لكل حقل: اسمه، وX وY والعرض والطول بالمللي (`Input type="number" step="0.1"`)، والحجم بالـ pt (صحيح من 5 لـ 72)، والخط (`sans` و`mono` و`system`)، والمحاذاة، وعريض، و"اسمه قبله" (`cap`)، وشيل. والنص الحر بخانة نص.
     - "إضافة حقل": قايمة بحقول `FREE_FIELDS.sticker` اللي مش موجودة (والنص الحر دايمًا)، وبيتضاف في x=1 y=1 بعرض 20 وطول 4.
     - عرض وطول الورقة (`layout.paper` من نوع `custom`).
     - قبل الحفظ: `templateError('sticker', 'free', [], layout)`. لو فيه غلط: رسالة واضحة بالعربي (`data-testid="tpl-error"`) ومن غير حفظ.
     - الحفظ: `mode: 'free'`، و`blocks: []`، و`layout`. و"رجّع للافتراضي" زي ما هو (بيمسح القالب، فالستيكر بيرجع يتطبع بالشكل القديم).
   - المعاينة: نفس الإطار على `print/sticker/<آخر جهاز>?preview=1&embed=1&v=..`، والمسودة في `sessionStorage` تحت `tpl-preview:sticker` (الـ `layout` كله). و"طباعة اختبار" للستيكر = `#/print/test/sticker`.
   - باقي الأنواع ما تتغيّرش خالص.
2. **الطباعة** (`src/screens/PrintScreen.tsx`، النوع `sticker` بس):
   - `loadTemplate('sticker', d.branch_id)` جوه `useLoad`. ولو `preview=1`: الـ `layout` من `sessionStorage` (`tpl-preview:sticker`) بدل المحفوظ.
   - لو القالب `mode === 'free'`: كل نسخة (`st.copies`) `FreePage` جوه نفس `div.sticker-page`، بـ `plan = pagePlan('free', layout, printer, { w: st.w, h: st.h, margin: 0 }, i18n.language)`، ولو مفيش طابعة: `dx`/`dy` من `st.dx` و`st.dy`. و`<PageStyle plan>` بدل الـ `<style>` بتاعة الـ `@page` للستيكر. والقيم: `orderNo` (`noOverride || order_no`)، و`customer`، و`phone`، و`device` (الماركة والموديل)، و`issue`، و`imei`، و`price` (التكلفة النهائية وإلا المتوقعة، زي `StickerLabel`)، و`paid`، و`remaining` (`remaining()` من `printPlan`)، و`date` (`f.date(received_at)`)، و`shopName`، و`shopPhone`، و`warranty`. الفلوس بـ `f.money` و`className="num"` و`dir="ltr"`، و`caps={fieldCaps('sticker', t)}`، و`testid` أول نسخة `sticker`.
   - من غير قالب حر: `StickerLabel` زي ما هو بالظبط.
3. **الترجمة** (`src/i18n/ar.json` و`src/i18n/en.json`): `printers.docs.sticker` ("ستيكر الجهاز" / "Device sticker")، وأسماء الحقول الناقصة في `printers.b` (`shopName`، و`logo`، و`shopPhone`، و`shopAddress`، و`barcode`)، ونصوص الخانات الجديدة. نفس المفاتيح في الملفين.

## الملفات المسموح بيها بس
- `src/screens/settings/PrintersTab.tsx`
- `src/screens/PrintScreen.tsx`
- `src/i18n/ar.json` و`src/i18n/en.json`
- `tests/e2e/printSticker.spec.ts` (جديد)

## الممنوع
- أي ملف تاني (`src/lib/*`، و`src/app/print/*`، و`supabase/`). لو محتاج تغيير فيهم: اكتبه في الملخص.
- تغيير شكل الستيكر من غير قالب، أو أي `data-testid` موجود، أو أي نوع تاني في المصمم.
- ألوان أو مقاسات مكتوبة مباشرة في المصمم (من نظام التصميم بس، زي باقي الشاشة).
- `git push`، أو أي فرع تاني.

## الاختبارات
- `npm run typecheck` و`npm run lint` نضاف، و`npx vitest run src/lib src/i18n` بيعدّي.
- `tests/e2e/printSticker.spec.ts` (Claude بيشغّله على GitHub) على نمط `tests/e2e/printDesigner.spec.ts`:
  - "ستيكر الجهاز" أول نوع في القايمة، ولما يتختار بيظهر 9 حقول (`stickerLayout`).
  - تعديل X بتاع `customer` لـ 5 والحفظ ← طباعة ستيكر جهاز: `[data-field=customer]` بـ `left: 5mm` واسم العميل، و`[data-field=price]` فيه "التكلفة: ".
  - حقل بره الورقة (X = 39 والعرض 20): رسالة `tpl-error` ومن غير حفظ.
  - "رجّع للافتراضي" ← الستيكر بيرجع `data-testid="sticker"` القديم (فيه `sticker-order`).

## في الآخر
commit على الفرع ده، وملخص: اللي اتعمل، واللي ما اتعملش وليه.
