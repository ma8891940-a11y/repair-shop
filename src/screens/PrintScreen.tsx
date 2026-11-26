import { Fragment, useEffect, useState, type ReactNode } from 'react';
import QRCode from 'qrcode';
import { useBackground } from '../app/stage';
import { trackingUrl, waLink } from '../lib/messages';
import { appBase } from '../lib/publicUrl';
import { useNavigate, useParams, useSearchParams } from 'react-router';
import { pageSize, readPrint, type PrintDoc } from '../lib/printPlan';
import { defaultBlocks, normalizeBlocks, type Block, type BlockKey, type Size, type TemplateDoc } from '../lib/printTemplate';
import { blockStyle } from '../lib/printEngine';
import { FlowBg, FreePage, Offset, PageStyle, loadForPrint, useDocPlan, type LoadedTemplate } from '../app/print/engine';
import { readVat } from '../lib/vat';
import { cn } from '../ui/cn';
import { StickerLabel, StickerTest } from '../app/print/StickerLabel';
import { useTranslation } from 'react-i18next';
import { useMe } from '../app/auth';
import { useBranch } from '../app/branch';
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
  const shopRow = shop;
  const br = useBranch();
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
  // U5: معاينة مصمم الطباعة: القالب اللي لسه بيتعدّل (من غير حفظ ومن غير طباعة تلقائي)
  const preview = params.get('preview') === '1';
  const previewV = params.get('v');
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
    const money = kind === 'sticker' || kind === 'invoice' || kind === 'receipt-a4' ? ((await supabase.rpc('device_money', { p_device: id })).data as { final: number | null; paid: number; due: number } | null) : null;
    // R5: الضريبة من قيد التسليم نفسه (لو المحل مسجّل والجهاز اتسلّم)
    const vat = kind === 'invoice' ? ((await supabase.rpc('device_vat', { p_device: id })).data as { vat: number; gross: number; net: number } | null) : null;
    // U5: قالب الفرع (أو المحل) الافتراضي لنوع الورقة ده، وملف الطابعة بتاعه
    let tpl: Block[] | null = null;
    let tmpl: LoadedTemplate | null = null;
    if (kind === 'receipt' || kind === 'receipt-a4' || kind === 'invoice') {
      // 50.6: الفاتورة بشكلها من أول طباعة (آخر فاتورة مش متلغية)، والمعاينة من غير ما تتجمّد
      let ref: string | undefined;
      if (kind === 'invoice' && !preview && params.get('test') !== '1') {
        const inv = ((await supabase.rpc('repair_invoices_of', { p_device: id })).data ?? []) as { id: string; reversed: boolean }[];
        ref = [...inv].reverse().find((x) => !x.reversed)?.id;
      }
      tmpl = await loadForPrint(kind, (d as { branch_id?: string }).branch_id, ref, preview);
      if (tmpl?.mode === 'flow' && tmpl.blocks != null) tpl = normalizeBlocks(kind, tmpl.blocks);
    }
    return { d, c: (c.data as Customer | null) ?? null, k: (k.data as DeviceCost | null) ?? null, parts, money, vat, tpl, tmpl };
  }, [id, kind, preview, previewV]);

  // 50.6: المقاس والإزاحة والخلفية واللغة من القالب والطابعة (الإيصالات والفاتورة)
  const isDoc = isReceipt || kind === 'invoice';
  const tmpl = data?.tmpl ?? null;
  const { plan, free, fields, bgUrl, bgReady, t: tl } = useDocPlan(kind, tmpl);
  const needQr = isLabel || isReceipt || fields.some((x) => x.key === 'qr');
  // الـ QR بيفتح صفحة تتبع العميل بالرمز السري بتاع الجهاز (الإيصال وملصق الـ QR بس، الاستيكر من غيره)
  useEffect(() => {
    if (!data || !needQr) return;
    void QRCode.toDataURL(trackingUrl(appBase(shop.extras, window.location.href), data.d.tracking_token), { margin: 0, width: 360, errorCorrectionLevel: 'M' }).then(setQr);
  }, [data, needQr, shop.extras]);

  // B: تليفون وعنوان فرع الجهاز على الإيصال والفاتورة (لو اتكتبوا)، واسم المحل ولوجوه زي ما هم
  const dev = data?.d as { branch_id?: string } | undefined;
  const branchRow = br.multi ? br.all.find((x) => x.id === dev?.branch_id) : undefined;
  const shopLive = branchRow ? { ...shopRow, phone: branchRow.phone || shopRow.phone, address: branchRow.address || shopRow.address } : shopRow;
  const fz = tmpl?.shop as { name?: string; phone?: string | null; address?: string | null; terms?: string; logo_color?: string | null; logo_thermal?: string | null } | undefined;
  const shopFor = fz ? { ...shopLive, name: fz.name ?? shopLive.name, phone: fz.phone ?? '', address: fz.address ?? '', receipt_terms: fz.terms ?? shopLive.receipt_terms } : shopLive;
  const bFor = fz && b ? { ...b, logo_color: fz.logo_color ?? null, logo_thermal: fz.logo_thermal ?? null } : b;
  const ready = isTest || (!!data && !branding.loading && (!needQr || !!qr) && bgReady);
  useEffect(() => {
    if (!ready || preview) return;
    const tm = setTimeout(() => {
      window.print();
      // جوه الإطار المخفي: بنقول للشاشة إنه اتطبع (نافذة الطباعة بتقفل الصفحة لحد ما تخلص)
      if (embed) window.parent?.postMessage({ type: 'gawalak-printed', kind, id }, window.location.origin);
    }, embed ? 150 : 350);
    return () => clearTimeout(tm);
  }, [ready, embed, kind, id, preview]);
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
  const freeValues = (): Partial<Record<string, ReactNode>> => {
    if (!data) return {};
    const money = (n: number | null | undefined) => (n == null ? '' : <span className="num" dir="ltr">{f.money(Number(n))} {cur}</span>);
    const logo = (thermal ? bFor?.logo_thermal : (bFor?.logo_color ?? bFor?.logo_thermal)) ?? null;
    const total = data.vat && Number(data.vat.vat) > 0 ? Number(data.vat.gross) : (data.k?.final_cost ?? null);
    return {
      shopName: shopFor.name,
      shopPhone: shopFor.phone,
      shopAddress: shopFor.address,
      logo: logo ? <img src={logo} alt={shopFor.name} style={{ height: '100%', width: 'auto', maxWidth: '100%', objectFit: 'contain' }} /> : null,
      orderNo: <span dir="ltr">{data.d.order_no}</span>,
      date: f.dateTime(isReceipt ? data.d.received_at : (data.d.delivered_at ?? new Date())),
      customer: data.c ? <bdi>{data.c.name}</bdi> : '',
      phone: data.c ? <span dir="ltr">{data.c.phone}</span> : '',
      device: `${data.d.brand} ${data.d.model}`,
      imei: data.d.imei ? <span dir="ltr">{data.d.imei}</span> : '',
      issue: data.d.issue,
      warranty: shop.warranty_days > 0 ? tl('print.warrantyDays', { n: shop.warranty_days }) : '',
      terms: terms.join(' - '),
      qr: qr ? <img src={qr} alt="" style={{ height: '100%', width: 'auto' }} /> : null,
      price: isReceipt ? money(data.k?.estimated_cost) : money(total),
      paid: money(data.money?.paid),
      remaining: money(data.money?.due),
      parts: data.parts.map((x) => `${x.name} × ${Number(x.qty)}`).join(tl('common.sep')),
    };
  };
  const terms = shopFor.receipt_terms
    .split('\n')
    .map((s) => s.trim())
    .filter(Boolean);

  return (
    <div className="min-h-dvh bg-white text-black">
      {/* الاستيكر: الصفحة بالمقاس بالظبط والهوامش صفر، وكل نسخة في صفحة لوحدها */}
      {isDoc ? <PageStyle plan={plan} /> : <style>{`@page { size: ${pageSize(isTest ? 'sticker' : (kind as PrintDoc), st)}; margin: ${isSticker || isTest ? '0' : isLabel ? '1mm' : thermal ? '3mm' : '14mm'}; }${isSticker || isTest ? ' @media print { html, body { margin: 0 !important; padding: 0 !important; } .sticker-page { break-after: page; page-break-after: always; } .sticker-page:last-child { break-after: auto; page-break-after: auto; } }' : ''}`}</style>}
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
      ) : free ? (
        <FreePage plan={plan} fields={fields} bgUrl={bgUrl} testid={`print-${kind}`} values={freeValues()} />
      ) : (
        <Offset plan={plan}>
        <div style={{ position: 'relative' }}>
        <FlowBg plan={plan} bgUrl={bgUrl} />
        <article dir={plan.lang === 'en' ? 'ltr' : 'rtl'} lang={plan.lang} style={{ position: 'relative' }} className={thermal ? 'mx-auto w-[76mm] p-[2mm] text-[12px] print:w-full print:p-0' : 'mx-auto max-w-[190mm] p-[10mm] text-[14px] print:max-w-none print:p-0'} data-testid={`print-${kind}`}>
          {/* U5: الخانات بترتيب القالب (المبالغ والبيانات دايمًا من البرنامج، والقالب بيتحكم في الشكل بس) */}
          {(() => {
            // نصوص المستند بلغة القالب (الشريط اللي فوق بلغة البرنامج)
            const t = tl;
            const doc = kind as TemplateDoc;
            const blocks = data.tpl ?? defaultBlocks(doc);
            const fs: Record<Size, string> = thermal ? { sm: 'text-[10px]', md: 'text-[12px]', lg: 'text-[18px]' } : { sm: 'text-[12px]', md: 'text-[14px]', lg: 'text-[20px]' };
            const cls = (x: Block) => cn(fs[x.size], x.bold && 'font-bold', x.align === 'center' ? 'text-center' : x.align === 'end' ? 'text-end' : 'text-start');
            const row = (x: Block, label: ReactNode, value: ReactNode, extra?: { testid?: string; mono?: boolean; ltr?: boolean; pre?: boolean }) => (
              <div key={x.key} className={cn('flex gap-2 border-b border-dotted border-neutral-400 px-1 py-1', fs[x.size], x.bold && 'font-bold', x.align === 'center' && 'justify-center', x.align === 'end' && 'justify-end')} style={blockStyle(x)} data-block={x.key}>
                <span className="w-[36%] shrink-0 font-semibold">{label}</span>
                <span className={cn('min-w-0', extra?.mono && 'font-mono', extra?.pre && 'whitespace-pre-wrap')} dir={extra?.ltr ? 'ltr' : undefined} data-testid={extra?.testid}>
                  {value}
                </span>
              </div>
            );
            const render = (x: Block): ReactNode => {
              switch (x.key) {
                case 'header':
                  return thermal ? (
                    <header key={x.key} className={cn('border-b border-dashed border-black pb-2', cls(x))} style={blockStyle(x)} data-block="header">
                      <ThermalHeader shop={shopFor} b={bFor} />
                    </header>
                  ) : (
                    <div key={x.key} style={blockStyle(x)} data-block="header">
                      <ColorHeader shop={shopFor} b={bFor} title={isPaperReceipt ? t('print.receiptA4') : t('print.invoice')} sub={data.d.order_no} />
                    </div>
                  );
                case 'title':
                  return thermal ? <div key={x.key} className={cn('mt-1', cls(x))} style={blockStyle(x)} data-block="title">{t(isReceipt ? 'print.receipt' : 'print.invoice')}</div> : null;
                case 'orderNo':
                  return thermal ? (
                    <div key={x.key} className={cn('font-mono tracking-wide', cls(x))} dir="ltr" style={blockStyle(x)} data-block="orderNo">
                      {data.d.order_no}
                    </div>
                  ) : null;
                case 'date':
                  return row(x, t('print.date'), f.dateTime(isReceipt ? data.d.received_at : (data.d.delivered_at ?? new Date())));
                case 'customer':
                  return data.c ? row(x, t('print.customer'), <bdi>{data.c.name}</bdi>) : null;
                case 'phone':
                  return data.c ? row(x, t('print.phone'), data.c.phone, { mono: true, ltr: true }) : null;
                case 'device':
                  return row(x, t('print.device'), `${data.d.brand} ${data.d.model}${data.d.color ? ` · ${data.d.color}` : ''}`);
                case 'imei':
                  return data.d.imei ? row(x, 'IMEI', data.d.imei, { mono: true, ltr: true }) : null;
                case 'issue':
                  return row(x, t('print.issue'), data.d.issue, { pre: true });
                case 'accessories':
                  return isReceipt ? row(x, t('print.accessories'), data.d.accessories.length ? data.d.accessories.map((a) => t(`intake.acc.${a}`, { defaultValue: a })).join(t('common.sep')) : t('device.withoutAcc')) : null;
                case 'condition':
                  return isReceipt ? row(x, t('print.condition'), data.d.cosmetic_condition || t('common.none'), { pre: true }) : null;
                case 'estimate':
                  return isReceipt ? row(x, t('print.estimate'), data.k?.estimated_cost != null ? `${f.money(data.k.estimated_cost)} ${cur}` : t('print.afterCheck')) : null;
                case 'parts':
                  return !isReceipt && data.parts.length > 0 ? row(x, t('print.parts'), data.parts.map((p) => `${p.name} × ${Number(p.qty)}`).join(t('common.sep'))) : null;
                case 'total':
                  if (isReceipt) return null;
                  // R5: الصافي والضريبة قبل الإجمالي الشامل، ورقم التسجيل
                  if (data.vat && Number(data.vat.vat) > 0) {
                    const vr = readVat(shop.extras);
                    return (
                      <Fragment key="total">
                        {row({ ...x, key: 'net' as BlockKey, bold: false }, t('vat.net'), `${f.money(Number(data.vat.net))} ${cur}`, { mono: true, testid: 'invoice-net' })}
                        {row({ ...x, key: 'vat' as BlockKey, bold: false }, t('vat.line'), `${f.money(Number(data.vat.vat))} ${cur}`, { mono: true, testid: 'invoice-vat' })}
                        {row(x, t('vat.totalIncl'), `${f.money(Number(data.vat.gross))} ${cur}`, { mono: true, testid: 'invoice-total' })}
                        {vr.reg_no && row({ ...x, key: 'vatNo' as BlockKey, bold: false }, t('vat.reg'), vr.reg_no, { mono: true, testid: 'invoice-vat-no' })}
                      </Fragment>
                    );
                  }
                  return row(x, t('print.total'), data.k?.final_cost != null ? `${f.money(data.k.final_cost)} ${cur}` : t('common.none'), { mono: true, testid: 'invoice-total' });
                case 'paid':
                  return !isReceipt && data.money ? row(x, t('print.paid'), `${f.money(Number(data.money.paid))} ${cur}`, { mono: true, testid: 'invoice-paid' }) : null;
                case 'remaining':
                  return !isReceipt && data.money ? row(x, t('print.remaining'), `${f.money(Number(data.money.due))} ${cur}`, { mono: true, testid: 'invoice-due' }) : null;
                case 'warranty':
                  return !isReceipt ? row(x, t('print.warranty'), shop.warranty_days > 0 ? t('print.warrantyDays', { n: shop.warranty_days }) : t('print.noWarranty')) : null;
                case 'terms':
                  return isReceipt && terms.length > 0 ? (
                    <section key={x.key} className={cn(thermal ? 'mt-2 border-t border-dashed border-black pt-1.5' : 'mt-6 border-t border-neutral-300 pt-3', cls(x))} data-testid="print-terms" style={blockStyle(x)} data-block="terms">
                      <b>{t('print.terms')}</b>
                      <ol className="mt-1 list-decimal ps-4">
                        {terms.map((tx, i) => (
                          <li key={i}>{tx}</li>
                        ))}
                      </ol>
                    </section>
                  ) : null;
                case 'signature':
                  // C2: الإيصال بتوقيع الاستلام، والفاتورة بتوقيع التسليم
                  if (!isReceipt) {
                    const sig = (data.d as { delivery_signature?: string | null }).delivery_signature;
                    return sig ? (
                      <div key={x.key} className={cn('mt-3 border-t border-neutral-300 pt-2', cls(x))} style={blockStyle(x)} data-block="signature" data-testid="invoice-signature">
                        <b>{t('signature.delivery')}</b>
                        <img src={sig} alt="" className="mt-1 h-[16mm] w-auto" />
                      </div>
                    ) : null;
                  }
                  return isReceipt && data.d.intake_signature ? (
                    <div key={x.key} className={cn('mt-2 border-t border-dashed border-black pt-1.5', cls(x))} style={blockStyle(x)} data-block="signature">
                      <b>{t('signature.title')}</b>
                      <img src={data.d.intake_signature} alt="" className="mt-1 h-[16mm] w-auto" />
                    </div>
                  ) : null;
                case 'qr':
                  return isReceipt && qr ? (
                    <div key={x.key} className={cn(thermal ? 'mt-2 flex items-center gap-2 border-t border-dashed border-black pt-2' : 'mt-6 flex items-center gap-3', x.align === 'center' ? 'justify-center' : x.align === 'end' ? 'justify-end' : '')} style={blockStyle(x)} data-block="qr">
                      <img src={qr} alt="" className={thermal ? 'size-[22mm]' : 'size-[28mm]'} />
                      <span className="text-[10px]">{t('label.scan')}</span>
                    </div>
                  ) : null;
                case 'sign':
                  return (
                    <div key={x.key} className={cn('mt-3', cls(x))} style={blockStyle(x)} data-block="sign">
                      {t('print.sign')}: ..............................
                    </div>
                  );
                case 'thanks':
                  return (
                    <div key={x.key} className={cn('mt-2 text-neutral-600', cls(x))} style={blockStyle(x)} data-block="thanks">
                      {t('print.thanks')}
                    </div>
                  );
                case 'text':
                  return x.text ? (
                    <p key={`text-${blocks.indexOf(x)}`} className={cn('mt-2 whitespace-pre-wrap', cls(x))} style={blockStyle(x)} data-block="text">
                      {x.text}
                    </p>
                  ) : null;
                default:
                  return null;
              }
            };
            return <div className={thermal ? '' : 'flex flex-col gap-0'}>{blocks.filter((x) => x.show).map(render)}</div>;
          })()}
          <PoweredBy b={b} />
        </article>
        </div>
        </Offset>
      )}
    </div>
  );
}
