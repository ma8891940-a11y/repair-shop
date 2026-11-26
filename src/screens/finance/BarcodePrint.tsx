import { useEffect } from 'react';
import { useNavigate, useParams, useSearchParams } from 'react-router';
import { useTranslation } from 'react-i18next';
import { useBackground } from '../../app/stage';
import { useMe } from '../../app/auth';
import { useBranch } from '../../app/branch';
import { useLoad, must } from '../../app/useLoad';
import { supabase } from '../../lib/supabase';
import { isEan13 } from '../../lib/barcode';
import { defaultBlocks, normalizeBlocks, type Block, type Size } from '../../lib/printTemplate';
import { useFormat } from '../../i18n/format';
import { Barcode } from '../../ui/Barcode';
import { Skeleton } from '../../ui/Feedback';
import { cn } from '../../ui/cn';
import { blockStyle, type PrinterRow } from '../../lib/printEngine';
import { FreePage, Offset, PageStyle, loadForPrint, useDocPlan } from '../../app/print/engine';

const FONT: Record<Size, string> = { sm: 'text-[8px]', md: 'text-[9px]', lg: 'text-[10px]' };
const CODE_H: Record<Size, string> = { sm: 'h-[11mm]', md: 'h-[15mm]', lg: 'h-[19mm]' };

/**
 * ملصق باركود للصنف (طابعة ملصقات أو الحرارية): اسم المحل، والصنف، والباركود، والسعر. ?n= عدد النسخ.
 * 6ج: الشكل من مصمم الطباعة ("ملصق الباركود")، والمقاس من طابعة القالب لو اتحددت. السعر من الصنف زي ما هو.
 */
export function BarcodePrint() {
  const { id = '' } = useParams();
  const [sp] = useSearchParams();
  const n = Math.min(100, Math.max(1, Number(sp.get('n')) || 1));
  const preview = sp.get('preview') === '1';
  const embed = sp.get('embed') === '1';
  const previewV = sp.get('v');
  useBackground('off');
  const { t } = useTranslation();
  const f = useFormat();
  const { shop } = useMe();
  const br = useBranch();
  const navigate = useNavigate();
  const { data, error } = useLoad(async () => {
    const item = must(await supabase.from('items').select('id, name, barcode, sale_price').eq('id', id).maybeSingle()) as { id: string; name: string; barcode: string | null; sale_price: number | null } | null;
    const tmpl = await loadForPrint('barcode', br.working?.id, undefined, preview);
    const tpl = tmpl?.mode === 'flow' && tmpl.blocks != null ? normalizeBlocks('barcode', tmpl.blocks) : null;
    // في المعاينة: الطابعة اللي متختارة في المصمم دلوقتي (حتى قبل الحفظ)
    let printer = tmpl?.printer ?? null;
    if (preview && sp.has('printer')) {
      const pid = sp.get('printer') || null;
      printer = pid ? ((await supabase.from('printers').select('kind, width_mm, height_mm, margin_mm, offset_x, offset_y').eq('id', pid).is('deleted_at', null).maybeSingle()).data as PrinterRow | null) : null;
    }
    // طابعة الملصقات بس (الحرارية أو الورق مالهمش مقاس ملصق)
    const label = printer?.kind === 'label' && printer.height_mm ? printer : null;
    return { item, tpl, tmpl: tmpl || label ? { ...(tmpl ?? { mode: 'flow' as const, blocks: null, layout: {} }), printer: label } : null };
  }, [id, preview, previewV, br.working?.id, sp.get('printer')]);
  const item = data?.item ?? null;
  const ok = !!item?.barcode && isEan13(item.barcode);
  const { plan, free, fields, bgUrl, bgReady } = useDocPlan('barcode', data?.tmpl);
  const ready = ok && br.ready && bgReady;
  useEffect(() => {
    if (!ready || preview) return;
    const tm = setTimeout(() => window.print(), 350);
    return () => clearTimeout(tm);
  }, [ready, preview]);
  // المقاس: من القالب أو طابعة الملصقات (العرض والطول والهامش)، أو الافتراضي 50×30 بهامش 1، والملصق ما يصغرش عن 10مم
  const page = { ...plan, h: plan.h ?? 30 };
  const w = Math.max(10, page.w - 2 * page.margin);
  const h = Math.max(10, page.h - 2 * page.margin);
  const blocks = data ? (data.tpl ?? defaultBlocks('barcode')) : [];
  const align = (x: Block) => (x.align === 'start' ? 'self-start text-start' : x.align === 'end' ? 'self-end text-end' : 'self-center text-center');
  const render = (x: Block, j: number) => {
    if (!x.show || !item) return null;
    const c = cn(FONT[x.size], x.bold && 'font-bold', align(x));
    switch (x.key) {
      case 'header':
        return (
          <div key="header" className={cn('w-full truncate', c)} style={blockStyle(x)} data-block="header">
            {shop.name}
          </div>
        );
      case 'itemName':
        return (
          <div key="itemName" className={cn('w-full truncate', c)} style={blockStyle(x)} data-block="itemName" data-testid="barcode-name">
            {item.name}
          </div>
        );
      case 'code':
        return (
          // block: من غير مسافة السطر تحت الباركود (نفس ارتفاع الملصق القديم)
          <div key="code" className={cn('leading-none', align(x))} style={blockStyle(x)} data-block="code">
            <Barcode code={item.barcode!} className={cn('block', CODE_H[x.size], 'w-[40mm] max-w-full')} />
          </div>
        );
      case 'price':
        return item.sale_price != null ? (
          <div key="price" className={cn('num', c)} dir="ltr" style={blockStyle(x)} data-block="price" data-testid="barcode-price">
            {f.money(item.sale_price)} {f.currency(shop.currency)}
          </div>
        ) : null;
      case 'text':
        return x.text ? (
          <div key={`text-${j}`} className={cn('w-full truncate', c)} style={blockStyle(x)} data-block="text">
            {x.text}
          </div>
        ) : null;
      default:
        return null;
    }
  };
  return (
    <div className="min-h-dvh bg-white text-black">
      <PageStyle plan={page} />
      <style>{'@media print { .bc-label { break-after: page; } }'}</style>
      <div className={cn('flex flex-wrap items-center gap-3 border-b border-neutral-200 bg-neutral-50 px-4 py-3 print:hidden', embed && 'hidden')}>
        <button type="button" onClick={() => window.print()} className="h-9 rounded-md bg-accent px-4 text-sm font-semibold text-on-accent">
          {t('print.print')}
        </button>
        <button type="button" onClick={() => navigate(-1)} className="h-9 rounded-md border border-neutral-300 px-4 text-sm">
          {t('print.back')}
        </button>
        <span className="text-xs text-neutral-600">{t('barcode.printHint')}</span>
      </div>
      {error ? (
        <p className="p-6 text-sm text-red-700">{error}</p>
      ) : !data ? (
        <Skeleton className="m-4 h-24 w-48" />
      ) : !ok ? (
        <p className="p-6 text-sm text-red-700">{t('barcode.none')}</p>
      ) : (
        <div className="flex flex-wrap gap-2 p-4 print:block print:p-0">
          {Array.from({ length: n }, (_, i) =>
            free ? (
              <div key={i} className="bc-label" data-testid="barcode-label">
                <FreePage
                  plan={page}
                  fields={fields}
                  bgUrl={bgUrl}
                  values={{
                    shopName: shop.name,
                    shopPhone: shop.phone,
                    shopAddress: shop.address,
                    itemName: item!.name,
                    code: <span dir="ltr">{item!.barcode}</span>,
                    price: item!.sale_price != null ? <span className="num" dir="ltr">{f.money(item!.sale_price)} {f.currency(shop.currency)}</span> : '',
                    barcode: <Barcode code={item!.barcode!} className="block h-full w-full" />,
                  }}
                />
              </div>
            ) : (
            <Offset key={i} plan={page}>
            <article
              key={i}
              className="bc-label flex flex-col items-center justify-center border border-dashed border-neutral-300 px-[1mm] print:border-0"
              style={{ width: `${w}mm`, height: `${h}mm` }}
              data-testid="barcode-label"
            >
              {blocks.map((x, j) => render(x, j))}
            </article>
            </Offset>
            ),
          )}
        </div>
      )}
    </div>
  );
}
