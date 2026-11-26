/**
 * 50.6: محرّك طباعة واحد: تحميل القالب (والنسخة الثابتة للوثايق من print_document)، وصفحة القالب الحر بأماكنها بالمللي،
 * وخطوط الإرشاد للطباعة التجريبية. الحساب في lib/printEngine، والبيانات والأرقام دايمًا من الشاشة اللي بتطبع.
 */
import { useEffect, useState, type ReactNode } from 'react';
import { useTranslation } from 'react-i18next';
import { useMe } from '../auth';
import { supabase } from '../../lib/supabase';
import { DOC_PAGE, freeStyle, pagePlan, planCss, rulerTicks, type PagePlan, type PrinterRow } from '../../lib/printEngine';
import type { FreeField, PrintDoc, PrintLayout } from '../../lib/printLayout';

export interface LoadedTemplate {
  mode: 'flow' | 'free';
  /** خام زي ما اتخزن: الشاشة بتعدّيه على normalizeBlocks */
  blocks: unknown;
  layout: PrintLayout;
  printer: PrinterRow | null;
  /** بيانات المحل الثابتة وقت أول طباعة (الوثايق بس) */
  shop?: Record<string, unknown>;
}
const FROZEN = ['invoice', 'sale', 'voucher'];

/**
 * قالب الفرع (أو المحل) الافتراضي وطابعته. الوثايق (فاتورة صيانة، وبيع، وسند) بـ ref: شكلها من أول طباعة (0090)،
 * والطابعة (المقاس والإزاحة) دايمًا الحالية لأنها الجهاز مش المستند. null = مفيش قالب محفوظ (الشكل الافتراضي).
 */
export async function loadTemplate(doc: PrintDoc, branchId: string | null | undefined, ref?: string): Promise<LoadedTemplate | null> {
  const { data: ts, error } = await supabase.from('print_templates').select('branch_id, mode, blocks, layout, printer_id').eq('doc', doc).eq('is_default', true).is('deleted_at', null);
  if (error) throw error;
  const list = (ts ?? []) as { branch_id: string | null; mode: 'flow' | 'free'; blocks: unknown; layout: PrintLayout; printer_id: string | null }[];
  const pick = list.find((x) => x.branch_id && x.branch_id === branchId) ?? list.find((x) => !x.branch_id) ?? null;
  const printer = pick?.printer_id
    ? (((await supabase.from('printers').select('kind, width_mm, height_mm, margin_mm, offset_x, offset_y').eq('id', pick.printer_id).is('deleted_at', null).maybeSingle()).data as PrinterRow | null) ?? null)
    : null;
  if (ref && FROZEN.includes(doc)) {
    const { data, error: e } = await supabase.rpc('print_document', { p_doc: doc, p_ref: ref });
    if (e) throw e;
    const r = data as { shop: Record<string, unknown>; template: { mode: 'flow' | 'free'; blocks: unknown; layout: PrintLayout } | null };
    return r.template ? { ...r.template, printer, shop: r.shop } : { mode: 'flow', blocks: null, layout: {}, printer, shop: r.shop };
  }
  return pick ? { mode: pick.mode, blocks: pick.blocks, layout: pick.layout ?? {}, printer } : null;
}

/** نفس loadTemplate، ومعاينة المصمم (preview): مسودته من الجلسة (خانات بالترتيب) ومن غير ما الوثيقة تتجمّد */
export async function loadForPrint(doc: PrintDoc, branchId: string | null | undefined, ref: string | undefined, preview: boolean): Promise<LoadedTemplate | null> {
  const tmpl = await loadTemplate(doc, branchId, preview ? undefined : ref);
  if (!preview) return tmpl;
  let draft: unknown = null;
  try {
    draft = JSON.parse(sessionStorage.getItem(`tpl-preview:${doc}`) ?? 'null');
  } catch {
    draft = null;
  }
  return draft ? { ...(tmpl ?? { layout: {}, printer: null }), mode: 'flow', blocks: draft } : tmpl;
}

/** خطة الصفحة للمستند: المقاس والإزاحة والخلفية ولغة القالب (t بلغته)، والحقول لو القالب حر */
export function useDocPlan(doc: string, tmpl: LoadedTemplate | null | undefined) {
  const { i18n } = useTranslation();
  const { shop } = useMe();
  const plan = pagePlan(tmpl?.mode ?? 'flow', tmpl?.layout, tmpl?.printer, DOC_PAGE[doc] ?? DOC_PAGE.receipt, i18n.language);
  const free = tmpl?.mode === 'free' && !!plan.h;
  const fields = (free ? (tmpl?.layout.fields ?? []) : []) as FreeField[];
  const bgUrl = useBgUrl(shop.id, plan.bg?.file);
  return { plan, free, fields, bgUrl, bgReady: !plan.bg || bgUrl !== null, t: i18n.getFixedT(plan.lang) };
}

/** خلفية المستند بالترتيب (flow): من حافة الورقة (ورا الهامش)، وبتتطبع مع الورق الفاضي بس */
export const FlowBg = ({ plan, bgUrl }: { plan: PagePlan; bgUrl: string | null }) =>
  bgUrl && plan.bg && plan.h ? (
    <img src={bgUrl} alt="" data-testid="print-bg" className={plan.bg.print ? undefined : 'print:hidden'} style={{ position: 'absolute', top: `-${plan.margin}mm`, left: `-${plan.margin}mm`, width: `${plan.w}mm`, height: `${plan.h}mm`, maxWidth: 'none' }} />
  ) : null;

/** رابط مؤقت لصورة الخلفية (المكان خاص بالمحل، 0089): null = لسه بيحمّل، و'' = ما اتفتحتش (من غير خلفية) */
export function useBgUrl(shopId: string, file: string | null | undefined): string | null {
  const [url, setUrl] = useState<{ file: string; url: string } | null>(null);
  useEffect(() => {
    if (!file) return;
    let live = true;
    void supabase.storage
      .from('print-backgrounds')
      .createSignedUrl(`${shopId}/${file}`, 3600)
      .then(
        ({ data }) => {
          if (live) setUrl({ file, url: data?.signedUrl ?? '' });
        },
        () => {
          if (live) setUrl({ file, url: '' });
        },
      );
    return () => {
      live = false;
    };
  }, [shopId, file]);
  return file && url?.file === file ? url.url : null;
}

export const PageStyle = ({ plan }: { plan: PagePlan }) => <style>{`${planCss(plan)} @media print { html, body { margin: 0 !important; padding: 0 !important; } }`}</style>;

/** إزاحة الطابعة على المحتوى كله (flow أو free) */
export const Offset = ({ plan, children }: { plan: PagePlan; children: ReactNode }) => (
  <div style={plan.dx || plan.dy ? { transform: `translate(${plan.dx}mm, ${plan.dy}mm)` } : undefined}>{children}</div>
);

/** خطوط الإرشاد: حافة الورقة، والهامش، ومسطرة كل 5 مللي، والمقاس مكتوب (بالمقاس الحقيقي) */
export function Guides({ plan, height }: { plan: PagePlan; height: number }) {
  const line = { position: 'absolute' as const, background: '#000' };
  return (
    <div aria-hidden data-testid="print-guides" style={{ position: 'absolute', inset: 0, border: '0.3mm solid #000', pointerEvents: 'none' }}>
      {plan.margin > 0 && <div style={{ position: 'absolute', inset: `${plan.margin}mm`, border: '0.2mm dashed #000' }} />}
      {rulerTicks(plan.w).map((x) => (
        <span key={`x${x.at}`} style={{ ...line, left: `${x.at}mm`, top: 0, width: '0.2mm', height: x.long ? '3mm' : '1.5mm' }} />
      ))}
      {rulerTicks(height).map((y) => (
        <span key={`y${y.at}`} style={{ ...line, top: `${y.at}mm`, left: 0, height: '0.2mm', width: y.long ? '3mm' : '1.5mm' }} />
      ))}
      <span dir="ltr" style={{ position: 'absolute', bottom: '1mm', right: '1mm', fontSize: '7pt', fontWeight: 700 }}>
        {plan.w} × {plan.h ?? 'auto'} mm{plan.dx || plan.dy ? ` · ${plan.dx}, ${plan.dy}` : ''}
      </span>
    </div>
  );
}

/**
 * صفحة القالب الحر: كل حقل في مكانه بالمللي من حافة الورقة، والخلفية تحتهم (بتتطبع مع الورق الفاضي بس).
 * guides = الطباعة التجريبية: خطوط الإرشاد وإطار كل حقل.
 */
export function FreePage({ plan, fields, values, bgUrl, guides, testid = 'print-free' }: { plan: PagePlan; fields: FreeField[]; values: Partial<Record<string, ReactNode>>; bgUrl?: string | null; guides?: boolean; testid?: string }) {
  const h = plan.h ?? 0;
  return (
    <Offset plan={plan}>
      <article dir={plan.lang === 'en' ? 'ltr' : 'rtl'} lang={plan.lang} data-testid={testid} style={{ position: 'relative', width: `${plan.w}mm`, height: `${h}mm`, overflow: 'hidden', background: '#fff', color: '#000', boxSizing: 'border-box' }}>
        {bgUrl && plan.bg && <img src={bgUrl} alt="" data-testid="print-bg" data-print={plan.bg.print ? 'yes' : 'no'} className={plan.bg.print ? undefined : 'print:hidden'} style={{ position: 'absolute', inset: 0, width: '100%', height: '100%' }} />}
        {guides && <Guides plan={plan} height={h} />}
        {fields.map((f, i) => (
          <div key={`${f.key}-${i}`} data-field={f.key} style={{ ...freeStyle(f), ...(guides ? { outline: '0.2mm dotted #000' } : {}) }}>
            {f.key === 'text' ? f.text : values[f.key]}
          </div>
        ))}
      </article>
    </Offset>
  );
}
