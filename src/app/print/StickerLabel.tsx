import { useTranslation } from 'react-i18next';
import { useFormat } from '../../i18n/format';
import { remaining, STICKER_PAD_MM, LINE_HEIGHT, stickerFont, type StickerSettings } from '../../lib/printPlan';

export interface StickerData {
  no: string;
  name: string;
  phone: string;
  issue: string;
  /** بالقروش */
  cost: number | null;
  paid: number;
  date: string | Date;
}

/**
 * استيكر الجهاز (بيتلزق على الجهاز): بسيط، من غير لوجو ولا QR ولا باركود.
 * بالترتيب: رقم الصيانة (أكبر سطر)، والاسم، والتليفون، والعطل، والتكلفة والمقدم والباقي، والتاريخ.
 * الخط بيتحسب من المقاس، والكلام الطويل بيتقص بـ "..." ومايطلعش بره. أبيض وأسود بتباين عالي.
 */
export function StickerLabel({ st, data, testid = 'sticker' }: { st: StickerSettings; data: StickerData; testid?: string }) {
  const { t } = useTranslation();
  const f = useFormat();
  const fs = stickerFont(st);
  const due = remaining(data.cost, data.paid);
  const line = (size: number, extra?: React.CSSProperties): React.CSSProperties => ({ fontSize: `${size}mm`, lineHeight: LINE_HEIGHT, height: `${Math.floor(size * LINE_HEIGHT * 100) / 100}mm`, whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis', ...extra });
  return (
    <article
      dir="rtl"
      data-testid={testid}
      data-size={`${st.w}x${st.h}`}
      style={{
        width: `${st.w}mm`,
        height: `${st.h}mm`,
        padding: `${STICKER_PAD_MM}mm`,
        boxSizing: 'border-box',
        overflow: 'hidden',
        background: '#fff',
        color: '#000',
        border: st.frame ? '0.3mm solid #000' : undefined,
        transform: st.dx || st.dy ? `translate(${st.dx}mm, ${st.dy}mm)` : undefined,
        fontFamily: 'inherit',
      }}
    >
      <div data-testid="sticker-order" dir="ltr" style={line(fs.order, { fontWeight: 900, textAlign: 'right', fontFamily: 'var(--font-mono, monospace)' })}>
        {data.no}
      </div>
      <div data-testid="sticker-customer" style={line(fs.name, { fontWeight: 700 })}>
        <bdi>{data.name}</bdi>
      </div>
      <div data-testid="sticker-phone" dir="ltr" style={line(fs.phone, { textAlign: 'right', fontFamily: 'var(--font-mono, monospace)', fontWeight: 600 })}>
        {data.phone}
      </div>
      <div data-testid="sticker-issue" style={line(fs.issue)}>
        {data.issue}
      </div>
      <div data-testid="sticker-money" style={line(fs.money, { fontWeight: 700 })}>
        <span data-testid="sticker-total">{t('sticker.cost')} {data.cost != null ? f.money(data.cost) : '—'}</span>
        {' · '}
        <span data-testid="sticker-paid">{t('sticker.paid')} {f.money(data.paid)}</span>
        {' · '}
        <span data-testid="sticker-due">{t('sticker.due')} {due != null ? f.money(due) : '—'}</span>
      </div>
      <div data-testid="sticker-date" style={line(fs.date)}>
        {f.date(data.date)}
      </div>
    </article>
  );
}

/** طباعة اختبار: إطار ومسطرة صغيرة بالمليمتر بنفس المقاس والإزاحة، عشان تظبط الطابعة */
export function StickerTest({ st }: { st: StickerSettings }) {
  const ticks = Array.from({ length: Math.floor(st.w / 5) + 1 }, (_, i) => i * 5);
  return (
    <article
      data-testid="sticker-test"
      style={{ width: `${st.w}mm`, height: `${st.h}mm`, boxSizing: 'border-box', border: '0.3mm solid #000', position: 'relative', overflow: 'hidden', background: '#fff', color: '#000', transform: st.dx || st.dy ? `translate(${st.dx}mm, ${st.dy}mm)` : undefined }}
    >
      {ticks.map((x) => (
        <span key={x} style={{ position: 'absolute', left: `${x}mm`, top: 0, width: '0.2mm', height: x % 10 === 0 ? '3mm' : '1.5mm', background: '#000' }} />
      ))}
      <span dir="ltr" style={{ position: 'absolute', inset: 0, display: 'grid', placeItems: 'center', fontSize: `${Math.min(st.h / 4, 5)}mm`, fontWeight: 800 }}>
        {st.w} × {st.h} mm
      </span>
    </article>
  );
}
