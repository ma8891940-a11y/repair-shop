import { ean13Bits } from '../lib/barcode';

/** باركود EAN-13 كـ SVG (أسود على أبيض، للطباعة). الأرقام تحته */
export function Barcode({ code, className }: { code: string; className?: string }) {
  const bits = ean13Bits(code);
  const rects: { x: number; w: number }[] = [];
  for (let i = 0; i < bits.length; i++) {
    if (bits[i] !== '1') continue;
    const last = rects[rects.length - 1];
    if (last && last.x + last.w === i) last.w++;
    else rects.push({ x: i, w: 1 });
  }
  // هامش 9 وحدات على كل ناحية (المساحة الهادية المطلوبة للقارئ)
  return (
    <svg viewBox="0 0 113 62" className={className} role="img" aria-label={code} data-testid="barcode-svg" shapeRendering="crispEdges">
      <rect width="113" height="62" fill="#fff" />
      {rects.map((r) => (
        <rect key={r.x} x={9 + r.x} y={2} width={r.w} height={48} fill="#000" />
      ))}
      <text x="56.5" y="60" textAnchor="middle" fontFamily="IBM Plex Mono, monospace" fontSize="10" fill="#000" letterSpacing="1.2">
        {code}
      </text>
    </svg>
  );
}
