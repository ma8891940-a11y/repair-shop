import { useEffect, useRef, useState } from 'react';
import { useTranslation } from 'react-i18next';
import { Eraser } from 'lucide-react';

/**
 * توقيع العميل على الشاشة (ماوس أو لمس أو قلم). بيرجّع صورة PNG صغيرة (data URL) أو null لو فاضي.
 * الخط بلون النص الحالي على خلفية شفافة، وبيتحفظ بالأسود للطباعة.
 */
export function SignaturePad({ value, onChange }: { value: string | null; onChange: (v: string | null) => void }) {
  const { t } = useTranslation();
  const ref = useRef<HTMLCanvasElement>(null);
  const drawing = useRef(false);
  const last = useRef<{ x: number; y: number } | null>(null);
  const [empty, setEmpty] = useState(!value);
  const W = 600;
  const H = 180;

  useEffect(() => {
    if (value) return;
    const c = ref.current;
    c?.getContext('2d')?.clearRect(0, 0, W, H);
    setEmpty(true);
  }, [value]);

  const pos = (e: React.PointerEvent<HTMLCanvasElement>) => {
    const r = e.currentTarget.getBoundingClientRect();
    return { x: ((e.clientX - r.left) / r.width) * W, y: ((e.clientY - r.top) / r.height) * H };
  };
  const line = (a: { x: number; y: number }, b: { x: number; y: number }) => {
    const ctx = ref.current?.getContext('2d');
    if (!ctx) return;
    ctx.strokeStyle = '#000';
    ctx.lineWidth = 3;
    ctx.lineCap = 'round';
    ctx.lineJoin = 'round';
    ctx.beginPath();
    ctx.moveTo(a.x, a.y);
    ctx.lineTo(b.x, b.y);
    ctx.stroke();
  };
  const finish = () => {
    if (!drawing.current) return;
    drawing.current = false;
    last.current = null;
    const url = ref.current?.toDataURL('image/png') ?? null;
    if (url) onChange(url);
  };

  return (
    <div>
      <div className="relative overflow-hidden rounded-md border border-dashed border-line-strong bg-white">
        <canvas
          ref={ref}
          width={W}
          height={H}
          className="block h-[140px] w-full touch-none"
          role="img"
          aria-label={t('signature.area')}
          onPointerDown={(e) => {
            e.currentTarget.setPointerCapture(e.pointerId);
            drawing.current = true;
            last.current = pos(e);
            line(last.current, { x: last.current.x + 0.1, y: last.current.y + 0.1 });
            setEmpty(false);
          }}
          onPointerMove={(e) => {
            if (!drawing.current || !last.current) return;
            const p = pos(e);
            line(last.current, p);
            last.current = p;
          }}
          onPointerUp={finish}
          onPointerLeave={finish}
        />
        {empty && <span className="pointer-events-none absolute inset-0 grid place-items-center text-sm text-neutral-500">{t('signature.hint')}</span>}
      </div>
      <button
        type="button"
        onClick={() => {
          ref.current?.getContext('2d')?.clearRect(0, 0, W, H);
          setEmpty(true);
          onChange(null);
        }}
        className="mt-1.5 inline-flex items-center gap-1.5 text-xs text-fg-3 hover:text-fg"
      >
        <Eraser className="size-3.5" aria-hidden /> {t('signature.clear')}
      </button>
    </div>
  );
}
