import { useEffect } from 'react';
import { useParams, useNavigate, useSearchParams } from 'react-router';
import { useTranslation } from 'react-i18next';
import { useBackground } from '../app/stage';
import { useMe } from '../app/auth';
import { useBranch } from '../app/branch';
import { useLoad } from '../app/useLoad';
import { FreePage, Guides, Offset, PageStyle, fieldCaps, loadTemplate, useBgUrl } from '../app/print/engine';
import { DOC_PAGE, pagePlan } from '../lib/printEngine';
import { PRINT_DOCS, type FreeField, type PrintDoc } from '../lib/printLayout';
import { readPrint } from '../lib/printPlan';
import { useFormat } from '../i18n/format';
import { Skeleton } from '../ui/Feedback';

// حقول بتترسم كمربع عليه اسمها (مش نص): الصورة والأكواد
const BOXES = ['logo', 'qr', 'barcode'];
const MONEY: Record<string, number> = { price: 150000, paid: 50000, remaining: 100000, amount: 25050 };

/**
 * 50.6: الطباعة التجريبية لأي نوع: خطوط إرشاد بالمقاس الحقيقي وبإزاحة الطابعة، والقالب الحر بحقوله في أماكنها ببيانات تجريبية ثابتة.
 * الورق المطبوع جاهز: الخلفية على الشاشة بس، فاللي بيطلع هو البيانات وخطوط الإرشاد عشان تقارنهم بالورقة.
 */
export function TestPrint() {
  const { doc = '' } = useParams();
  useBackground('off');
  const { t, i18n } = useTranslation();
  const f = useFormat();
  const { shop } = useMe();
  const br = useBranch();
  const navigate = useNavigate();
  const [params] = useSearchParams();
  const embed = params.get('embed') === '1';
  const known = (PRINT_DOCS as readonly string[]).includes(doc);
  const branch = params.get('branch') ?? br.working?.id ?? null;
  const { data, error } = useLoad(async () => (known ? loadTemplate(doc as PrintDoc, branch) : null), [doc, branch]);
  const sticker = readPrint(shop.extras).sticker;
  // الاستيكر من غير قالب: مقاسه من الإعدادات ← الطباعة (زي الطباعة الفعلية)
  const fallback = doc === 'sticker' ? { w: sticker.w, h: sticker.h, margin: 0 } : (DOC_PAGE[doc] ?? DOC_PAGE.receipt);
  const base = pagePlan(data?.mode ?? 'flow', data?.layout, data?.printer, fallback, i18n.language);
  // الاستيكر من غير ملف طابعة: الإزاحة من الإعدادات ← الطباعة (زي StickerLabel)
  const plan = doc === 'sticker' && !data?.printer ? { ...base, dx: sticker.dx, dy: sticker.dy } : base;
  const bgUrl = useBgUrl(shop.id, plan.bg?.file);
  const ready = data !== undefined && (!plan.bg || !!bgUrl);
  useEffect(() => {
    if (!ready || !embed) return;
    const tm = setTimeout(() => window.print(), 150);
    return () => clearTimeout(tm);
  }, [ready, embed]);

  const tl = i18n.getFixedT(plan.lang);
  const sample = (key: string) =>
    BOXES.includes(key) ? (
      <span style={{ display: 'grid', placeItems: 'center', height: '100%', border: '0.2mm solid #000', fontSize: '6pt' }}>{key.toUpperCase()}</span>
    ) : key in MONEY ? (
      <span className="num" dir="ltr">{f.money(MONEY[key])}</span>
    ) : key === 'date' ? (
      f.date(new Date())
    ) : (
      tl(`printTest.sample.${key}`, { defaultValue: '' })
    );
  // الطول المفتوح (الحراري): الإطار بطول 100 مللي للتجربة
  const height = plan.h ?? 100;

  return (
    <div className="min-h-dvh bg-white text-black">
      {/* حافة الورقة = حافة الصفحة: الهامش مرسوم خط متقطع */}
      <PageStyle plan={{ ...plan, h: height, margin: 0 }} />
      <div className={`flex flex-wrap items-center gap-3 border-b border-neutral-200 bg-neutral-50 px-4 py-3 print:hidden${embed ? ' hidden' : ''}`}>
        <button type="button" onClick={() => window.print()} className="h-9 rounded-md bg-accent px-4 text-sm font-semibold text-on-accent">
          {t('print.print')}
        </button>
        <button type="button" onClick={() => navigate(-1)} className="h-9 rounded-md border border-neutral-300 px-4 text-sm">
          {t('print.back')}
        </button>
        <span className="text-xs text-neutral-600">{t('printTest.hint')}</span>
        {data === null && known && <span className="text-xs text-neutral-600" data-testid="test-no-template">{t('printTest.noTemplate')}</span>}
      </div>
      {!known ? (
        <p className="p-6 text-sm text-red-700">{t('errors.db.E_NOT_FOUND')}</p>
      ) : error ? (
        <p className="p-6 text-sm text-red-700">{error}</p>
      ) : data === undefined ? (
        <div className="mx-auto w-[76mm] p-4">
          <Skeleton className="h-40 w-full" />
        </div>
      ) : (
        <div className="mx-auto my-4 w-fit print:m-0" data-testid="test-print" data-doc={doc} data-size={`${plan.w}x${plan.h ?? 'auto'}`}>
          {data?.mode === 'free' && plan.h ? (
            <FreePage plan={plan} fields={(data.layout.fields ?? []) as FreeField[]} values={Object.fromEntries((data.layout.fields ?? []).map((x) => [x.key, sample(x.key)]))} caps={fieldCaps(doc, tl)} bgUrl={bgUrl} guides />
          ) : (
            <Offset plan={plan}>
              <article style={{ position: 'relative', width: `${plan.w}mm`, height: `${height}mm`, background: '#fff', color: '#000', boxSizing: 'border-box' }}>
                {bgUrl && plan.bg && <img src={bgUrl} alt="" data-testid="print-bg" className={plan.bg.print ? undefined : 'print:hidden'} style={{ position: 'absolute', inset: 0, width: '100%', height: '100%' }} />}
                <Guides plan={plan} height={height} />
              </article>
            </Offset>
          )}
        </div>
      )}
    </div>
  );
}
