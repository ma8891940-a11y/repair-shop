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

// مقاس الملصق الافتراضي (من غير طابعة ملصقات في المصمم): 50×30مم بهامش 1مم
const DEFAULT_LABEL = { width_mm: 50, height_mm: 30, margin_mm: 1 };
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
    const { data: ts } = await supabase.from('print_templates').select('branch_id, blocks, printer_id').eq('doc', 'barcode').eq('is_default', true).is('deleted_at', null);
    const list = (ts ?? []) as { branch_id: string | null; blocks: unknown; printer_id: string | null }[];
    const pick = list.find((x) => x.branch_id && x.branch_id === br.working?.id) ?? list.find((x) => !x.branch_id);
    let draft: unknown = null;
    if (preview) {
      try {
        draft = JSON.parse(sessionStorage.getItem('tpl-preview:barcode') ?? 'null');
      } catch {
        draft = null;
      }
    }
    const tpl = draft ? normalizeBlocks('barcode', draft) : pick ? normalizeBlocks('barcode', pick.blocks) : null;
    const printer = pick?.printer_id
      ? ((await supabase.from('printers').select('width_mm, height_mm, margin_mm').eq('id', pick.printer_id).is('deleted_at', null).maybeSingle()).data as { width_mm: number; height_mm: number | null; margin_mm: number } | null)
      : null;
    return { item, tpl, printer };
  }, [id, preview, previewV, br.working?.id]);
  const item = data?.item ?? null;
  const ok = !!item?.barcode && isEan13(item.barcode);
  const ready = ok && br.ready;
  useEffect(() => {
    if (!ready || preview) return;
    const tm = setTimeout(() => window.print(), 350);
    return () => clearTimeout(tm);
  }, [ready, preview]);
  // المقاس: من طابعة الملصقات في القالب (العرض والطول والهامش)، أو الافتراضي
  const p = data?.printer?.height_mm ? data.printer : DEFAULT_LABEL;
  const w = p.width_mm - 2 * p.margin_mm;
  const h = (p.height_mm ?? DEFAULT_LABEL.height_mm) - 2 * p.margin_mm;
  const blocks = data ? (data.tpl ?? defaultBlocks('barcode')) : [];
  const align = (x: Block) => (x.align === 'start' ? 'self-start text-start' : x.align === 'end' ? 'self-end text-end' : 'self-center text-center');
  const render = (x: Block) => {
    if (!x.show || !item) return null;
    const c = cn(FONT[x.size], x.bold && 'font-bold', align(x));
    switch (x.key) {
      case 'header':
        return (
          <div key="header" className={cn('w-full truncate', c)} data-block="header">
            {shop.name}
          </div>
        );
      case 'itemName':
        return (
          <div key="itemName" className={cn('w-full truncate', c)} data-block="itemName" data-testid="barcode-name">
            {item.name}
          </div>
        );
      case 'code':
        return (
          <div key="code" className={align(x)} data-block="code">
            <Barcode code={item.barcode!} className={cn(CODE_H[x.size], 'w-[40mm] max-w-full')} />
          </div>
        );
      case 'price':
        return item.sale_price != null ? (
          <div key="price" className={cn('num', c)} dir="ltr" data-block="price" data-testid="barcode-price">
            {f.money(item.sale_price)} {f.currency(shop.currency)}
          </div>
        ) : null;
      case 'text':
        return x.text ? (
          <div key={`text-${blocks.indexOf(x)}`} className={cn('w-full truncate', c)} data-block="text">
            {x.text}
          </div>
        ) : null;
      default:
        return null;
    }
  };
  return (
    <div className="min-h-dvh bg-white text-black">
      <style>{`@page { size: ${p.width_mm}mm ${p.height_mm ?? DEFAULT_LABEL.height_mm}mm; margin: ${p.margin_mm}mm; } @media print { .bc-label { break-after: page; } }`}</style>
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
          {Array.from({ length: n }, (_, i) => (
            <article
              key={i}
              className="bc-label flex flex-col items-center justify-center overflow-hidden border border-dashed border-neutral-300 px-[1mm] print:border-0"
              style={{ width: `${w}mm`, height: `${h}mm` }}
              data-testid="barcode-label"
            >
              {blocks.map(render)}
            </article>
          ))}
        </div>
      )}
    </div>
  );
}
