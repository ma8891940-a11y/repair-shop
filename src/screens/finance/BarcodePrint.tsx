import { useEffect } from 'react';
import { useNavigate, useParams, useSearchParams } from 'react-router';
import { useTranslation } from 'react-i18next';
import { useBackground } from '../../app/stage';
import { useMe } from '../../app/auth';
import { useLoad, must } from '../../app/useLoad';
import { supabase } from '../../lib/supabase';
import { isEan13 } from '../../lib/barcode';
import { useFormat } from '../../i18n/format';
import { Barcode } from '../../ui/Barcode';
import { Skeleton } from '../../ui/Feedback';

/** ملصق باركود للصنف (طابعة ملصقات أو الحرارية): اسم المحل، والصنف، والسعر، والباركود. ?n= عدد النسخ */
export function BarcodePrint() {
  const { id = '' } = useParams();
  const [sp] = useSearchParams();
  const n = Math.min(100, Math.max(1, Number(sp.get('n')) || 1));
  useBackground('off');
  const { t } = useTranslation();
  const f = useFormat();
  const { shop } = useMe();
  const navigate = useNavigate();
  const { data, error } = useLoad(async () => must(await supabase.from('items').select('id, name, barcode, sale_price').eq('id', id).maybeSingle()) as { id: string; name: string; barcode: string | null; sale_price: number | null } | null, [id]);
  const ok = !!data?.barcode && isEan13(data.barcode);
  useEffect(() => {
    if (!ok) return;
    const tm = setTimeout(() => window.print(), 350);
    return () => clearTimeout(tm);
  }, [ok]);
  return (
    <div className="min-h-dvh bg-white text-black">
      <style>{'@page { size: 50mm 30mm; margin: 1mm; } @media print { .bc-label { break-after: page; } }'}</style>
      <div className="flex flex-wrap items-center gap-3 border-b border-neutral-200 bg-neutral-50 px-4 py-3 print:hidden">
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
            <article key={i} className="bc-label flex h-[28mm] w-[48mm] flex-col items-center justify-center border border-dashed border-neutral-300 px-[1mm] text-center print:border-0" data-testid="barcode-label">
              <div className="w-full truncate text-[8px] font-bold">{shop.name}</div>
              <div className="w-full truncate text-[9px]">{data.name}</div>
              <Barcode code={data.barcode!} className="h-[15mm] w-[40mm]" />
              {data.sale_price != null && (
                <div className="num text-[10px] font-bold" dir="ltr">
                  {f.money(data.sale_price)} {f.currency(shop.currency)}
                </div>
              )}
            </article>
          ))}
        </div>
      )}
    </div>
  );
}
