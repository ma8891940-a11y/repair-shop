# مراجعة المتطلبات (REQUIREMENTS_CHECK)

آخر مراجعة: 2026-11-07.

**المصادر:**
- `docs/spec.pdf` (المواصفات).
- `docs/phase-3-ledger.md`.
- `CLAUDE.md` و`PROGRESS.md`.
- رسايل صاحب المشروع في الجلسة.

**الحالة:**
- ✅ تم وفيه اختبار.
- 🟡 تم جزئيًا أو محتاج تجربة يدوية.
- ❌ ناقص.

اللي اتصلح في المراجعة دي متعلّم **(اتصلح)**.

**الاختبارات:**
- `db/` = `tests/db/*.test.ts` (Vitest على قاعدة بيانات حقيقية).
- `e2e/` = `tests/e2e/*.spec.ts` (Playwright على كمبيوتر وموبايل × داكن وفاتح).
- `unit/` = `src/**/*.test.ts`.

---

## أ) المنتج والشكل
| # | المتطلب | المصدر | الحالة | الكود | الاختبار |
|---|---|---|---|---|---|
| 1 | تطبيق مثبّت (PWA)، يفتح على الدخول ثم لوحة التحكم، ومن غير صفحة تسويقية | CLAUDE | ✅ | `vite.config.ts`، `src/App.tsx` | `unit/boot.test.ts`، `e2e/brand`، `e2e/phase1` |
| 2 | الكمبيوتر أساس (اختصارات F1–F5 وCtrl+K، وطباعة)، وشغال على الموبايل | CLAUDE | ✅ | `src/app/AppShell.tsx`، `src/app/shortcuts.ts` | `e2e/*` على 4 مشاريع، و`noHorizontalScroll` |
| 3 | عربي كامل RTL، وإنجليزي، والمصطلحات الفنية إنجليزي | spec، CLAUDE | ✅ | `src/i18n/*` | `unit/i18n.test.ts` (نفس المفاتيح، مفيش نص مكتوب مباشرة)، و`e2e/languages` (اتضاف) |
| 4 | الوضع الداكن أساسي + وضع فاتح، والاختيار بيتحفظ | CLAUDE | ✅ | `src/app/prefs.tsx`، `src/styles/tokens.css` | `e2e/*` (مشروعين لكل وضع) |
| 5 | كل الألوان والمقاسات من tokens | CLAUDE | ✅ | `src/styles/tokens.css` | مراجعة كود |
| 6 | حالات تحميل وفاضي وخطأ لكل شاشة | CLAUDE | ✅ | `src/ui/Feedback.tsx` | `e2e/*` |
| 7 | إمكانية الوصول: كيبورد، وfocus ظاهر، وتباين AA | CLAUDE | 🟡 | `src/styles/index.css` | الكيبورد في `e2e/phase1`. التباين متراجع يدويًا بس |
| 8 | الحركة 150–250ms، وبتتلغي مع "تقليل الحركة" | CLAUDE | ✅ | `src/App.tsx` (MotionConfig) | `e2e/effects`، `e2e/splash` |
| 9 | المؤثرات الكاملة للزجاج والتقيل بس، ومقفولة افتراضيًا، وبتتقفل تحت 50 إطار لمدة 3 ثواني (سماح ثانيتين) | CLAUDE، رسايل | ✅ | `src/app/EffectsGuard.tsx`، `src/lib/fpsGuard.ts` | `unit/fpsGuard`، `e2e/effects` |
| 10 | الخلفية الحية شغالة للكل، وبتثبت مع "تقليل الحركة"، وبتثبت بنعومة تحت 50 إطار لمدة 2 ثانية وتتحفظ للجهاز | رسايل | ✅ | `src/app/stage.tsx`، `src/ui/fx/CircuitField.tsx` | `unit/fpsGuard`، `e2e/splash` |
| 11 | حارس الخلفية ما يشتغلش في dev ولا وقت التحميل ولا والتبويب في الخلفية، والسبب ظاهر في الإعدادات مع الحل | رسايل | ✅ | `src/app/motionStatus.ts`، `src/screens/settings/MotionStatus.tsx` | `unit/motionStatus`، `e2e/splash` |
| 12 | الافتتاحية: نفس الخلفية، واللوجو في النص بتعتيم دايري، وتجمّع الإشارات، وتوهج، وسكان، وطيران لمكانه، وأقل من ثانية ونص | رسايل | ✅ | `src/screens/SplashScreen.tsx`، `src/app/stage.tsx` | `e2e/splash` (بيقيس حوالي 1.3 ثانية) |
| 13 | index.html بنفس الخلفية واللوجو ثابت قبل الكود، والـ manifest بنفس اللون | رسايل | ✅ | `index.html`، `vite.config.ts` | `unit/boot.test.ts`، `e2e/splash` |
| 14 | اسم التطبيق "جوالك / Gawalak" في كل مكان | رسايل | ✅ | `src/i18n`، `index.html`، `vite.config.ts` | `e2e/brand` |
| 15 | لوجو صاحب المشروع كما هو في 5 أماكن، وأيقونات 16/32/192/512 maskable | رسايل، CLAUDE | ✅ | `src/ui/Logo.tsx`، `brand/build-icons.py` | `e2e/brand`، `e2e/splash` |
| 16 | من غير إيموجي، ومن غير نسخ تصميم برنامج تاني | CLAUDE | ✅ | — | مراجعة كود |

## ب) الحسابات والصلاحيات
| # | المتطلب | المصدر | الحالة | الكود | الاختبار |
|---|---|---|---|---|---|
| 17 | تسجيل محل بمعالج، ودعوة موظفين بالدور | spec، CLAUDE | ✅ | `src/screens/auth/RegisterWizard.tsx`، `src/screens/TeamScreen.tsx` | `db/rls`، `e2e/phase1` |
| 18 | الأدوار: صاحب المحل، والاستقبال، والفني، ومدير التسويق | spec | ✅ | `0001`، `0017` | `db/rls`، `db/growth` |
| 19 | تأكيد الإيميل برابط (الافتراضي) أو بكود (القالب)، أو من غير تأكيد | رسايل | ✅ | `RegisterWizard.tsx`، `LoginScreen.tsx` | `e2e/confirm`، وكل اختبارات التسجيل |
| 20 | حساب من غير محل ولا دعوة ← "كمّل تسجيل محلك" | رسايل | ✅ | `JoinScreen.tsx`، `RegisterWizard.tsx` (resume) | `e2e/confirm` |
| 21 | رابط تأكيد منتهي ← رسالة واضحة، وإعادة إرسال للي ما أكدش | رسايل | ✅ | `LoginScreen.tsx` | `e2e/confirm` |
| 22 | الفني ما يشوفش أسعار ولا أرباح ولا بيانات عملاء | spec، CLAUDE | ✅ | RLS في `0001` و`0008` | `db/rls`، `db/ledger` (قبول 8) |
| 23 | الاستقبال ما يشوفش الأرباح ولا أرصدة الخزن | spec، phase-3 | ✅ | `0008` | `db/ledger` (قبول 8)، `e2e/phase3` |
| 24 | مدير التسويق: الفيديوهات بس | spec | ✅ | `0017`، `src/App.tsx` (MarketingRoutes) | `db/growth`، `e2e/phase6` |
| 25 | RLS على كل جدول، ومحل ما يشوفش محل تاني | CLAUDE | ✅ | كل الـ migrations | `db/rls`، و`db/security` (اتضاف: على كل الجداول تلقائيًا) |
| 26 | سجل النشاط: كل عملية حساسة بقيمتها قبل وبعد، وما بيتعدلش ولا بيتحذف، وصاحب المحل بس يشوفه، وفلتر بالمستخدم والتاريخ والنوع | spec، CLAUDE | ✅ | `0001` (tg_audit)، `src/screens/AuditScreen.tsx` | `db/rls` |
| 27 | حذف جهاز (أو عميل) محتاج صاحب المحل **(اتصلح)** | spec | ✅ | `0021` (tg_owner_soft_delete) | `db/rules21` |
| 28 | خصم كبير محتاج صاحب المحل، والنسبة من الإعدادات **(اتصلح)** | spec | ✅ | `0021` (tg_cost_discount)، `PricingSettings.tsx` | `db/rules21`، `e2e/rules21` |
| 29 | Soft delete بس، و`id` من التطبيق | CLAUDE | ✅ | `tg_block_delete` | `db/rls`، `unit/rules.test.ts` |
| 30 | مفيش service_role في الواجهة، والأسرار في `.env.local` بس | CLAUDE | ✅ | — | `unit/rules.test.ts`، ومراجعة التاريخ (القسم ج) |

## ج) الاستلام والحالات (المرحلة 1)
| # | المتطلب | المصدر | الحالة | الكود | الاختبار |
|---|---|---|---|---|---|
| 31 | بيانات العميل: الاسم، والرقم (واتساب)، والمنطقة | spec | ✅ | `IntakeScreen.tsx` | `e2e/phase1` |
| 32 | الجهاز: النوع، والموديل، وIMEI (Luhn)، واللون، والملحقات | spec | ✅ | `IntakeScreen.tsx`، `src/lib/imei.ts` | `unit/lib`، `e2e/phase1` |
| 33 | العطل كما وصفه العميل، والحالة الشكلية | spec | ✅ | `IntakeScreen.tsx` | `e2e/phase1` |
| 34 | صور من كل الجهات (6 بحد أقصى) | spec | ✅ | `src/lib/photos.ts`، `0002` | `db/rls`، `e2e/phase2` |
| 35 | كلمة سر الجهاز مشفّرة (Vault)، والفني وصاحب المحل بس يشوفوها، وبتتمسح عند التسليم | spec، CLAUDE | ✅ | `0005` | `db/rls` |
| 36 | توقيع العميل على الشاشة | spec | ✅ | `src/ui/SignaturePad.tsx`، `0012` | `db/spec`، `e2e/spec` |
| 37 | تنبيه IMEI في نفس المحل بس | CLAUDE (قديم) | ✅ | `IntakeScreen.tsx` | `db/rls` |
| 38 | الحالات العشرة، والانتقالات متطابقة بين الواجهة وقاعدة البيانات | spec، CLAUDE | ✅ | `src/lib/status.ts`، `is_valid_transition` | `db/rls` (100 حالة)، `unit/lib` |
| 39 | كل تغيير حالة بيتسجل بالوقت والموظف | spec | ✅ | `status_log` | `db/rls` |
| 40 | كل تغيير حالة بيبعت رسالة للعميل: "ابعت للعميل" بعد التغيير **(اتصلح)** | spec | ✅ | `DeviceDetailScreen.tsx` | `e2e/rules21` |
| 41 | التسليم محتاج تكلفة نهائية | CLAUDE | ✅ | `0001` | `db/rls` |
| 42 | ملاحظات داخلية للفريق بس | CLAUDE (قديم) | ✅ | `device_notes` | `db/rls` |
| 43 | لوحة التحكم: أجهزة اليوم، وتحت الصيانة، والجاهزة، والمتأخرة، والنواقص، والديون، و**ربح اليوم (اتصلح)** | spec | ✅ | `DashboardScreen.tsx` | `e2e/phase1`، `e2e/review` |
| 44 | إيصال 80مم وفاتورة A4 | CLAUDE | ✅ | `PrintScreen.tsx` | `e2e/phase1`، `e2e/identity` |

## د) العميل (المرحلة 2)
| # | المتطلب | المصدر | الحالة | الكود | الاختبار |
|---|---|---|---|---|---|
| 45 | QR على ملصق 80×40 | spec | ✅ | `PrintScreen.tsx` (label) | `e2e/phase2` |
| 46 | صفحة تتبع: الحالة، وآخر تحديث، والتكلفة، والمتبقي، واسم الفني (الأول بس)، ومن غير بيانات العميل | spec | ✅ | `get_tracking` (`0016`)، `TrackingScreen.tsx` | `db/phase2`، `db/spec`، `e2e/phase2` |
| 47 | حد محاولات التتبع، والتخمين متشفّر | CLAUDE | ✅ | `0009`، `0013` | `db/phase2` |
| 48 | واتساب بقوالب يعدّلها صاحب المحل (استلام، وحالة، وموافقة، وجاهز، وتذكير، وتسليم، ودين، و**تسويقي (اتضاف)**) | spec، رسايل | ✅ | `src/lib/messages.ts`، `MessagesTab.tsx` | `db/phase2`، `unit/phase2` |
| 49 | تذكير الجاهز من 10 أيام | spec | ✅ | `FollowUpPanel.tsx` | `unit/phase2`، `e2e/phase2` |
| 50 | الموافقة على زيادة التكلفة من صفحة التتبع، والفني ما يكمّلش قبلها | spec | ✅ | `decide_quote`، `0014` | `db/phase2`، `db/technicians` |
| 51 | الضمان: مدة **لكل نوع عطل (اتصلح)**، وتنبيه لو رجع في الضمان **ولنفس العطل (اتصلح)** | spec | ✅ | `0021`، `TechTab.tsx`، `IntakeScreen.tsx` | `db/rules21`، `db/phase2`، `e2e/rules21` |
| 52 | الفحص السريع عند الاستلام والتسليم، والمقارنة | spec | ✅ | `src/ui/QuickCheck.tsx`، `src/lib/checks.ts` | `unit/phase2`، `e2e/phase2` |
| 53 | ملف العميل: أجهزته، ومجموع ما دفعه، ودينه، والتصنيف (جديد/دائم/VIP/متأخر) | spec | ✅ | `CustomersScreen.tsx` | `unit/phase2`، `e2e/phase2` |
| 54 | بحث سريع بالاسم والرقم وIMEI ورقم الطلب | spec | ✅ | `src/app/CommandPalette`، `DevicesScreen.tsx` | `e2e/phase1` |
| 55 | تذكيرات تسويقية بموافقة العميل ("صيانة من 6 شهور") **(اتصلح)** | spec | ✅ | `0021` (marketing_due)، `MarketingPanel.tsx` | `db/rules21`، `e2e/rules21` |

## هـ) الفلوس (المرحلة 3)
| # | المتطلب | المصدر | الحالة | الكود | الاختبار |
|---|---|---|---|---|---|
| 56 | قيد مزدوج متوازن دايمًا | phase-3 | ✅ | `0008` | `db/ledger` (قبول 1 و9)، و`db/ledger3days` (اتضاف) |
| 57 | الأرصدة بتتحسب من القيود بس | phase-3 | ✅ | `0008` | `db/ledger` (قبول 2)، `db/ledger3days` |
| 58 | القيد ما بيتعدلش ولا بيتحذف، والتصحيح بقيد عكسي مسجّل في السجل | phase-3 | ✅ | `0008` | `db/ledger` (قبول 4 و4ب) |
| 59 | كل حساب RPC جوه transaction | phase-3 | ✅ | `0008` | `db/ledger` (قبول 6) |
| 60 | الخزن الخمسة الافتراضية، وصاحب المحل يضيف | phase-3 | ✅ | `0010` | `db/ledger` |
| 61 | شاشة الوضع المالي: الأرقام الستة، والمعادلة، وكروت الخزن، وأكبر الأرصدة، والرسم اليومي، والفلتر | phase-3 | ✅ | `FinanceScreen.tsx` | `e2e/phase3`، `db/ledger` (قبول 3) |
| 62 | صفحة الخزنة: افتتاحي، وحركات، وبحث، وتصدير PDF وExcel، وتحويل، وتقفيل الدرج بالعجز أو الزيادة | phase-3، رسايل | ✅ | `StatementScreen.tsx`، `DrawerScreen.tsx` | `e2e/phase3`، `db/ledger` |
| 63 | كشف حساب العميل والمورد، ودفعة منه، وطباعة، وتذكير | phase-3 | ✅ | `StatementScreen.tsx`، `FinancePrint.tsx` | `e2e/phase3` |
| 64 | الربط التلقائي (دفعة، وتسليم، وشراء، وقطعة، ومصروف، ومرتب، وسحب) | phase-3 | ✅ | `0008`، `0012` | `db/ledger`، `db/ledger3days` |
| 65 | حاسبة التسعير: القطعة + الأجرة + الهامش، والتعديل بيتسجل | spec | ✅ | `suggest_device_price`، `PricingCalculator` | `unit/ledger`، `db/spec`، `e2e/spec` |
| 66 | عربون ودفعات والمتبقي تلقائي، ومنع التسليم قبل السداد إلا بإذن صاحب المحل (متسجل مين) | spec | ✅ | `0008`، `0012` | `db/ledger`، `db/spec` |
| 67 | المدينين بأقدم دين، وتذكير واتساب | spec | ✅ | `party_balances` | `db/spec` |
| 68 | الموردين: الأسعار، والمديونية، ومصدر كل قطعة، ومقارنة الأسعار، والحد الأدنى والنواقص | spec | ✅ | `0012`، `InventoryScreen.tsx` | `db/spec`، `unit/inventory`، `e2e/spec` |
| 69 | المخزون بالمتوسط المرجّح، والإكسسوارات بباركود | spec، CLAUDE | ✅ | `stock_moves` | `db/ledger`، `e2e/spec` |
| 70 | طريقة الدفع لكل دفعة | CLAUDE (قديم) | ✅ | `OpDialog.tsx` | `e2e/phase3` |
| 71 | تقرير اليوم | CLAUDE | ✅ | `FinancePrint.tsx` (DayReportPrint) | `e2e/phase3` |
| 72 | المبالغ بالقروش أعداد صحيحة | CLAUDE | ✅ | `src/lib/money.ts` | `unit/lib`، `db/ledger` (قبول 7)، `db/rules21` |

## و) الفنيون (المرحلة 4)
| # | المتطلب | المصدر | الحالة | الكود | الاختبار |
|---|---|---|---|---|---|
| 73 | التخصصات والمسارات من الإعدادات | spec | ✅ | `0014`، `TechTab.tsx` | `db/technicians` |
| 74 | المسار من نوع العطل، وIC: فك ← ميكروسكوب ← نفس الفني يقفل | spec | ✅ | `0014` | `db/technicians`، `e2e/phase4` |
| 75 | الفني يشوف أجهزته بس، وأول ما يدوس بيبدأ، ولما يخلّص الجهاز بيروح للخطوة اللي بعدها | spec | ✅ | `WorkScreen.tsx`، `StepsPanel.tsx` | `e2e/phase4` |
| 76 | فحص نهائي إجباري قبل "جاهز" | spec | ✅ | `finish_step` | `db/technicians`، `e2e/phase4` |
| 77 | الأولوية (عاجل، وعادي، وضمان)، والمتأخر بالأحمر | spec | ✅ | `src/lib/tech.ts` | `unit/tech`، `db/technicians` |
| 78 | تقدير الوقت: متوسط 5 أجهزة مشابهة، وإلا يدوي | spec | ✅ | `useDuration` | `db/technicians` |
| 79 | المرتجع في الضمان بيتنسب لنفس الفني | spec | ✅ | `tg_device_warranty_tech` | `db/technicians` |
| 80 | الرسايل باسم الفني | spec | ✅ | `messaging.tsx` | `db/technicians` |
| 81 | تقارير: الأرباح، وربحية كل عطل، وأداء الفنيين، والأعطال والموديلات، والديون، والنواقص، وتصدير CSV/PDF | spec | ✅ | `ReportsScreen.tsx` | `e2e/phase4` |

## ز) بدون إنترنت (المرحلة 5)
| # | المتطلب | المصدر | الحالة | الكود | الاختبار |
|---|---|---|---|---|---|
| 82 | الاستلام وتغيير الحالة والدفعة على الجهاز الأول، وطابور بالترتيب ومن غير تكرار | spec | ✅ | `src/offline/*` | `unit/outbox`، `e2e/phase5` |
| 83 | "آخر تعديل يكسب" والتعارض في السجل | spec | ✅ | `apply_status_lww` | `db/offline` |
| 84 | مؤشر الاتصال و"بانتظار المزامنة" | spec | ✅ | `ConnectionBadge.tsx` | `e2e/phase5` |
| 85 | الدخول بدون نت | CLAUDE | ✅ | `auth.tsx` | `e2e/phase5` |
| 86 | فتح التطبيق من الأول والنت فاصل (service worker) | spec | 🟡 | `vite-plugin-pwa` | اتجرّب يدويًا على النسخة النهائية (القسم 5) |
| 87 | نسخة يومية على السيرفر، وتصدير يدوي مشفّر | spec | ✅ | `0015`، `BackupTab.tsx` | `db/offline`، `unit/backupCrypto`، `e2e/phase5` |
| 88 | **استرجاع النسخة الاحتياطية** | رسايل | الحالة في القسم "الاسترجاع" تحت | | |

## ح) النمو (المرحلة 6)
| # | المتطلب | المصدر | الحالة | الكود | الاختبار |
|---|---|---|---|---|---|
| 89 | المساعد عبر Edge Function من غير بيانات عميل، ودليل مجاني لو مش مفعّل | CLAUDE | 🟡 | `supabase/functions/assistant`، `aiScrub.ts` | `unit/growth`، `e2e/phase6`. الـ Edge Function الحقيقية محتاجة مفتاح |
| 90 | تقييم العميل بعد التسليم، ومرة واحدة | spec | ✅ | `0017` | `db/growth`، `e2e/phase6` |
| 91 | الفيديوهات بالنقاط | spec | ✅ | `0017`، `VideosScreen.tsx` | `db/growth`، `e2e/phase6` |
| 92 | مجتمع الفنيين من غير بيانات عملاء | spec | ✅ | `0017`، `CommunityScreen.tsx` | `db/growth`، `e2e/phase6` |
| 93 | الخطط والحدود، ولوحة المشرف (صفحات وبحث) | CLAUDE | ✅ | `0017`، `0020`، `AdminScreen.tsx` | `db/growth`، `e2e/phase6` |
| 94 | تعدد الفروع | spec | ⛔ | خارج النطاق حسب المواصفات نفسها (قسم النطاق) | — |

## ط) هوية المحل والطباعة
| # | المتطلب | المصدر | الحالة | الكود | الاختبار |
|---|---|---|---|---|---|
| 95 | كل حاجة مطبوعة أو بتوصل للعميل باسم المحل ولوجوه | CLAUDE، رسايل | ✅ | `src/app/brand/branding.tsx` | `db/identity`، `e2e/identity` |
| 96 | الإيصال أبيض وأسود، والفاتورة ملونة، ومن غير لوجو الاسم بيتطبع كبير، و"بواسطة" مقفول | CLAUDE | ✅ | `brandImage.ts` | `unit/brandImage`، `e2e/identity` |
| 97 | لوجو المحل في Storage تحت shop_id ومعزول | CLAUDE | ✅ | `0016` | `db/identity` |

## ي) الإضافات (FEATURES_ADDED.md)
| # | المتطلب | الحالة | الاختبار |
|---|---|---|---|
| 98 | أعطال جاهزة، وطباعة تلقائية، وملخص اليوم، ولكل واحدة مفتاح | ✅ | `db/extras`، `unit/extras`، `e2e/extras` |

## ك) ممنوع يتبني (CLAUDE)
| # | المتطلب | الحالة |
|---|---|---|
| 99 | من غير خانة "جهاز مشبوه"، ولا صيانة خارجية، ولا عمولة فني، ولا فاتورة إلكترونية | ✅ (اتراجع: مش موجودين) |

---

## الاسترجاع
النتيجة النهائية متسجلة في قسم "نتيجة المراجعة" تحت، بعد تجربة الاسترجاع.

## نتيجة المراجعة
بتتحدث في آخر المراجعة.
