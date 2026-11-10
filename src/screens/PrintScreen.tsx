import { useEffect, useState } from 'react';
import QRCode from 'qrcode';
import { useBackground } from '../app/stage';
import { trackingUrl, waLink } from '../lib/messages';
import { appBase } from '../lib/publicUrl';
import { useNavigate, useParams, useSearchParams } from 'react-router';
import { pageSize, readPrint, type PrintDoc } from '../lib/printPlan';
import { StickerLabel, StickerTest } from '../app/print/StickerLabel';
import { useTranslation } from 'react-i18next';
import { useMe } from '../app/auth';
import { useLoad, must } from '../app/useLoad';
import { supabase } from '../lib/supabase';
import type { Customer, Device, DeviceCost } from '../lib/types';
import { useFormat } from '../i18n/format';
import { Skeleton } from '../ui/Feedback';
import { ColorHeader, PoweredBy, ThermalHeader, useBranding } from '../app/brand/branding';

/**
 * الطباعة:
 *  receipt = إيصال استلام على الطابعة الحرارية 80مم (فيه شروط الاستلام)
 *  invoice = فاتورة على ورق A4
 * ألوان الورق أبيض وأسود ثابت (مش من الوضع الداكن)، عشان الطباعة تطلع واضحة.
 */
export function PrintScreen() {
  const { kind = 'receipt', id = '' } = useParams();
  useBackground('off');
  const { t } = useTranslation();
  const f = useFormat();
  const { shop } = useMe();
  const navigate = useNavigate();
  const isLabel = kind === 'label';
  const isSticker = kind === 'sticker';
  // طباعة اختبار للاستيكر (إطار ومسطرة) من الإعدادات ← الطباعة: من غير جهاز
  const isTest = kind === 'sticker-test';
  // isReceipt = محتوى إيصال الاستلام (الحراري 80مم أو الورقي A4)، وthermal = شكل الطابعة الحرارية
  const isPaperReceipt = kind === 'receipt-a4';
  const isReceipt = kind === 'receipt' || isPaperReceipt;
  const thermal = kind === 'receipt';
  const [params] = useSearchParams();
  // الطباعة ورا بعض (من الاستلام): بعد ما ده يتطبع، اللي بعده يفتح
  const next = (params.get('next') ?? '').split(',').filter((x): x is PrintDoc => ['sticker', 'receipt', 'receipt-a4', 'invoice'].includes(x));
  const settings = readPrint(shop.extras);
  const st = settings.sticker;
  // embed: جوه إطار مخفي من شاشة الاستلام أو الجهاز (الطباعة من غير ما تسيب الشاشة)
  const embed = params.get('embed') === '1';
  // "رقم محفوظ" بدل رقم الطلب على الاستيكر (لو اتختار)
  const noOverride = params.get('no');
  const [qr, setQr] = useState<string | null>(null);
  const branding = useBranding();
  const b = branding.data ?? null;

  const { data, error } = useLoad(async () => {
    if (isTest) return null;
    const d = must(await supabase.from('devices').select('*').eq('id', id).maybeSingle()) as Device | null;
    if (!d) throw new Error('E_NOT_FOUND');
    const [c, k] = await Promise.all([
      supabase.from('customers').select('id, name, phone, area').eq('id', d.customer_id).maybeSingle(),
      supabase.from('device_costs').select('id, device_id, estimated_cost, final_cost').eq('device_id', id).maybeSingle(),
    ]);
    const parts = kind === 'invoice' ? ((await supabase.rpc('device_parts', { p_device: id })).data ?? []) as { item_id: string; name: string; qty: number }[] : [];
    // المدفوع والفاضل (الاستيكر والفاتورة)
    const money = kind === 'sticker' || kind === 'invoice' ? ((await supabase.rpc('device_money', { p_device: id })).data as { final: number | null; paid: number; due: number } | null) : null;
    return { d, c: (c.data as Customer | null) ?? null, k: (k.data as DeviceCost | null) ?? null, parts, money };
  }, [id, kind]);

  // الـ QR بيفتح صفحة تتبع العميل بالرمز السري بتاع الجهاز (الإيصال وملصق الـ QR بس، الاستيكر من غيره)
  useEffect(() => {
    if (!data || (!isLabel && !isReceipt)) return;
    void QRCode.toDataURL(trackingUrl(appBase(shop.extras, window.location.href), data.d.tracking_token), { margin: 0, width: 360, errorCorrectionLevel: 'M' }).then(setQr);
  }, [data, isLabel, isReceipt, shop.extras]);

  const ready = isTest || (!!data && !branding.loading && (!(isLabel || isReceipt) || !!qr));
  useEffect(() => {
    if (!ready) return;
    const tm = setTimeout(() => {
      window.print();
      // جوه الإطار المخفي: بنقول للشاشة إنه اتطبع (نافذة الطباعة بتقفل الصفحة لحد ما تخلص)
      if (embed) window.parent?.postMessage({ type: 'gawalak-printed', kind, id }, window.location.origin);
    }, embed ? 150 : 350);
    return () => clearTimeout(tm);
  }, [ready, embed, kind, id]);
  // بعد ما نافذة الطباعة تتقفل: المستند اللي بعده (لو فيه)
  const nextUrl = next.length ? `/print/${next[0]}/${id}${next.length > 1 ? `?next=${next.slice(1).join(',')}` : ''}` : null;
  useEffect(() => {
    if (!nextUrl) return;
    const go = () => navigate(nextUrl, { replace: true });
    window.addEventListener('afterprint', go);
    return () => window.removeEventListener('afterprint', go);
  }, [nextUrl, navigate]);

  // الفاتورة كرسالة واتساب للعميل
  const invoiceLink =
    data && data.c
      ? waLink(
          data.c.phone,
          [
            `${shop.name} - ${t('print.invoice')} ${data.d.order_no}`,
            `${t('print.device')}: ${data.d.brand} ${data.d.model}`,
            `${t('print.issue')}: ${data.d.issue}`,
            data.parts.length ? `${t('print.parts')}: ${data.parts.map((x) => `${x.name} × ${Number(x.qty)}`).join(t('common.sep'))}` : '',
            data.k?.final_cost != null ? `${t('print.total')}: ${f.money(data.k.final_cost)} ${f.currency(shop.currency)}` : '',
            shop.warranty_days > 0 ? t('print.warrantyDays', { n: shop.warranty_days }) : '',
          ]
            .filter(Boolean)
            .join('\n'),
        )
      : null;
  const cur = f.currency(shop.currency);
  const terms = shop.receipt_terms
    .split('\n')
    .map((s) => s.trim())
    .filter(Boolean);

  return (
    <div className="min-h-dvh bg-white text-black">
      {/* الاستيكر: الصفحة بالمقاس بالظبط والهوامش صفر، وكل نسخة في صفحة لوحدها */}
      <style>{`@page { size: ${pageSize(isTest ? 'sticker' : (kind as PrintDoc), st)}; margin: ${isSticker || isTest ? '0' : isLabel ? '1mm' : thermal ? '3mm' : '14mm'}; }${isSticker || isTest ? ' @media print { html, body { margin: 0 !important; padding: 0 !important; } .sticker-page { break-after: page; page-break-after: always; } .sticker-page:last-child { break-after: auto; page-break-after: auto; } }' : ''}`}</style>
      <div className={`flex flex-wrap items-center gap-3 border-b border-neutral-200 bg-neutral-50 px-4 py-3 print:hidden${embed ? ' hidden' : ''}`}>
        <button type="button" onClick={() => window.print()} className="h-9 rounded-md bg-accent px-4 text-sm font-semibold text-on-accent">
          {t('print.print')}
        </button>
        <button type="button" onClick={() => navigate(-1)} className="h-9 rounded-md border border-neutral-300 px-4 text-sm">
          {t('print.back')}
        </button>
        {nextUrl && (
          <button type="button" onClick={() => navigate(nextUrl, { replace: true })} className="h-9 rounded-md border border-neutral-300 px-4 text-sm" data-testid="print-next">
            {t('print.next', { doc: t(`print.docs.${next[0]}`) })}
          </button>
        )}
        {kind === 'invoice' && invoiceLink && (
          <a href={invoiceLink} target="_blank" rel="noopener noreferrer" className="h-9 rounded-md border border-neutral-300 px-4 text-sm leading-9" data-testid="invoice-wa">
            {t('print.sendWa')}
          </a>
        )}
        <span className="text-xs text-neutral-600">{isSticker || isTest ? t('sticker.printerNote') : thermal || isLabel ? t('print.hintReceipt') : t('print.hintInvoice')}</span>
      </div>

      {isTest ? (
        <div className="sticker-page mx-auto my-4 w-fit print:m-0">
          <StickerTest st={st} />
        </div>
      ) : error ? (
        <p className="p-6 text-sm text-red-700">{error}</p>
      ) : !data ? (
        <div className="mx-auto w-[76mm] p-4">
          <Skeleton className="h-40 w-full" />
        </div>
      ) : isSticker ? (
        <div className="print-sticker" data-testid="print-sticker">
          {Array.from({ length: st.copies }, (_, i) => (
            <div key={i} className="sticker-page mx-auto my-4 w-fit print:m-0">
              <StickerLabel
                st={st}
                testid={i === 0 ? 'sticker' : `sticker-${i + 1}`}
                data={{
                  no: noOverride || data.d.order_no,
                  name: data.c?.name ?? '',
                  phone: data.c?.phone ?? '',
                  issue: [data.d.brand, data.d.model].filter(Boolean).join(' ') + (data.d.issue ? ` · ${data.d.issue}` : ''),
                  cost: data.money?.final != null ? Number(data.money.final) : (data.k?.estimated_cost ?? null),
                  paid: Number(data.money?.paid ?? 0),
                  date: data.d.received_at,
                }}
              />
            </div>
          ))}
        </div>
      ) : isLabel ? (
        <article className="mx-auto flex h-[28mm] w-[48mm] items-center gap-[1.5mm] overflow-hidden text-[9px] text-black" aria-label={t('label.title')} data-testid="qr-label">
          {qr ? <img src={qr} alt="" className="size-[24mm] shrink-0" data-testid="qr-img" /> : <div className="size-[24mm] shrink-0 bg-neutral-100" />}
          <div className="min-w-0">
            {b?.logo_thermal ? <img src={b.logo_thermal} alt={shop.name} className="mb-0.5 h-[7mm] w-auto max-w-full object-contain" data-testid="shop-logo-thermal" /> : <div className="truncate text-[13px] font-extrabold" data-testid="shop-name-big">{shop.name}</div>}
            <div className="font-mono text-[20px] font-bold leading-tight" dir="ltr">
              {data.d.order_no}
            </div>
            <div className="truncate">
              {data.d.brand} {data.d.model}
            </div>
            <div className="truncate">{data.c && <bdi>{data.c.name.split(' ')[0]}</bdi>}</div>
            <div className="mt-0.5 text-[9px] text-neutral-600">{t('label.scan')}</div>
          </div>
        </article>
      ) : (
        <article className={thermal ? 'mx-auto w-[76mm] p-[2mm] text-[12px] print:w-full print:p-0' : 'mx-auto max-w-[190mm] p-[10mm] text-[14px] print:max-w-none print:p-0'} data-testid={`print-${kind}`}>
          {thermal ? (
            <header className="border-b border-dashed border-black pb-2 text-center">
              <ThermalHeader shop={shop} b={b} />
              <div className="mt-1 font-semibold">{t('print.receipt')}</div>
              <div className="font-mono text-[20px] font-bold tracking-wide" dir="ltr">
                {data.d.order_no}
              </div>
            </header>
          ) : (
            <ColorHeader shop={shop} b={b} title={isPaperReceipt ? t('print.receiptA4') : t('print.invoice')} sub={data.d.order_no} />
          )}

          <table className={thermal ? 'mt-2 w-full' : 'mt-6 w-full'}>
            <tbody className="[&_td]:border-b [&_td]:border-dotted [&_td]:border-neutral-400 [&_td]:px-1 [&_td]:py-1 [&_th]:border-b [&_th]:border-dotted [&_th]:border-neutral-400 [&_th]:px-1 [&_th]:py-1 [&_th]:text-start [&_th]:align-top [&_th]:font-semibold">
              <tr>
                <th className="w-[36%]">{t('print.date')}</th>
                <td>{f.dateTime(isReceipt ? data.d.received_at : (data.d.delivered_at ?? new Date()))}</td>
              </tr>
              {data.c && (
                <>
                  <tr>
                    <th>{t('print.customer')}</th>
                    <td>
                      <bdi>{data.c.name}</bdi>
                    </td>
                  </tr>
                  <tr>
                    <th>{t('print.phone')}</th>
                    <td dir="ltr" className="text-start font-mono">
                      {data.c.phone}
                    </td>
                  </tr>
                </>
              )}
              <tr>
                <th>{t('print.device')}</th>
                <td>
                  {data.d.brand} {data.d.model} {data.d.color && `· ${data.d.color}`}
                </td>
              </tr>
              {data.d.imei && (
                <tr>
                  <th>IMEI</th>
                  <td dir="ltr" className="text-start font-mono">
                    {data.d.imei}
                  </td>
                </tr>
              )}
              <tr>
                <th>{t('print.issue')}</th>
                <td className="whitespace-pre-wrap">{data.d.issue}</td>
              </tr>
              {isReceipt ? (
                <>
                  <tr>
                    <th>{t('print.accessories')}</th>
                    <td>{data.d.accessories.length ? data.d.accessories.map((a) => t(`intake.acc.${a}`, { defaultValue: a })).join(t('common.sep')) : t('device.withoutAcc')}</td>
                  </tr>
                  <tr>
                    <th>{t('print.condition')}</th>
                    <td className="whitespace-pre-wrap">{data.d.cosmetic_condition || t('common.none')}</td>
                  </tr>
                  <tr>
                    <th>{t('print.estimate')}</th>
                    <td>{data.k?.estimated_cost != null ? `${f.money(data.k.estimated_cost)} ${cur}` : t('print.afterCheck')}</td>
                  </tr>
                </>
              ) : (
                <>
                  {data.parts.length > 0 && (
                    <tr>
                      <th>{t('print.parts')}</th>
                      <td>{data.parts.map((x) => `${x.name} × ${Number(x.qty)}`).join(t('common.sep'))}</td>
                    </tr>
                  )}
                  <tr className="text-[18px] font-bold">
                    <th className="!border-t-2 !border-solid !border-black">{t('print.total')}</th>
                    <td className="!border-t-2 !border-solid !border-black font-mono">{data.k?.final_cost != null ? `${f.money(data.k.final_cost)} ${cur}` : t('common.none')}</td>
                  </tr>
                  {data.money && (
                    <>
                      <tr>
                        <th>{t('print.paid')}</th>
                        <td className="font-mono" data-testid="invoice-paid">
                          {f.money(Number(data.money.paid))} {cur}
                        </td>
                      </tr>
                      <tr>
                        <th>{t('print.remaining')}</th>
                        <td className="font-mono" data-testid="invoice-due">
                          {f.money(Number(data.money.due))} {cur}
                        </td>
                      </tr>
                    </>
                  )}
                  <tr>
                    <th>{t('print.warranty')}</th>
                    <td>{shop.warranty_days > 0 ? t('print.warrantyDays', { n: shop.warranty_days }) : t('print.noWarranty')}</td>
                  </tr>
                </>
              )}
            </tbody>
          </table>

          {isReceipt && terms.length > 0 && (
            <section className={thermal ? 'mt-2 border-t border-dashed border-black pt-1.5 text-[11px]' : 'mt-6 border-t border-neutral-300 pt-3 text-[13px]'} data-testid="print-terms">
              <b>{t('print.terms')}</b>
              <ol className="mt-1 list-decimal ps-4">
                {terms.map((x, i) => (
                  <li key={i}>{x}</li>
                ))}
              </ol>
            </section>
          )}
          {isReceipt && data.d.intake_signature && (
            <div className="mt-2 border-t border-dashed border-black pt-1.5 text-[11px]">
              <b>{t('signature.title')}</b>
              <img src={data.d.intake_signature} alt="" className="mt-1 h-[16mm] w-auto" />
            </div>
          )}
          {isReceipt && qr && (
            <div className={thermal ? 'mt-2 flex items-center justify-center gap-2 border-t border-dashed border-black pt-2' : 'mt-6 flex items-center gap-3'}>
              <img src={qr} alt="" className={thermal ? 'size-[22mm]' : 'size-[28mm]'} />
              <span className="text-[10px]">{t('label.scan')}</span>
            </div>
          )}
          <footer className={thermal ? 'mt-3 text-center' : 'mt-12 flex items-end justify-between'}>
            <div className={thermal ? 'mb-2 text-start' : ''}>
              {t('print.sign')}: ..............................
            </div>
            <div className="text-[11px] text-neutral-600">{t('print.thanks')}</div>
          </footer>
          <PoweredBy b={b} />
        </article>
      )}
    </div>
  );
}
