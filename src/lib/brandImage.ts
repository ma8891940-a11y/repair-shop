/**
 * تجهيز لوجو المحل للطباعة (من غير مكتبات):
 * - placeImage: مكان الصورة جوه الإطار مع التكبير والتحريك (قص بسيط).
 * - toThermal: نسخة أبيض وأسود صريحة للطابعة الحرارية (من غير رمادي، عشان الحبر الحراري)، والتباين بيتحكم فيه.
 */
export const LOGO_W = 640;
export const LOGO_H = 320;
export const MAX_LOGO_BYTES = 2 * 1024 * 1024;
export const LOGO_TYPES = ['image/png', 'image/jpeg', 'image/svg+xml', 'image/webp'] as const;

export interface Placement {
  x: number;
  y: number;
  w: number;
  h: number;
}

/**
 * الصورة بتتحط "contain" جوه الإطار، وبعدين بتتكبر (zoom من 1 لـ 4) وتتحرك (pan من -1 لـ 1 من المساحة الزيادة).
 */
export function placeImage(srcW: number, srcH: number, outW: number, outH: number, zoom = 1, panX = 0, panY = 0): Placement {
  if (srcW <= 0 || srcH <= 0) return { x: 0, y: 0, w: 0, h: 0 };
  const z = Math.min(4, Math.max(1, zoom));
  const base = Math.min(outW / srcW, outH / srcH);
  const w = srcW * base * z;
  const h = srcH * base * z;
  const clamp = (v: number) => Math.min(1, Math.max(-1, v));
  // المساحة اللي ينفع الصورة تتحرك فيها (لو أكبر من الإطار: تتحرك جوه حدودها، ولو أصغر: تتحرك في الفراغ)
  const spanX = Math.abs(w - outW) / 2;
  const spanY = Math.abs(h - outH) / 2;
  return { x: (outW - w) / 2 + clamp(panX) * spanX, y: (outH - h) / 2 + clamp(panY) * spanY, w, h };
}

/** العتبة: تباين 0 = فاتح (أقل أسود)، و100 = غامق (أي درجة متوسطة بتبقى أسود) */
export function thermalThreshold(contrast: number): number {
  const c = Math.min(100, Math.max(0, contrast));
  return Math.round(80 + c * 1.5); // 80..230
}

/**
 * RGBA => أبيض وأسود. الشفاف بيتحسب على ورقة بيضا. الأسود: (0,0,0,255)، والأبيض: شفاف (عشان ورق الإيصال هو الأبيض).
 */
export function toThermal(rgba: Uint8ClampedArray, contrast: number): Uint8ClampedArray {
  const out = new Uint8ClampedArray(rgba.length);
  const th = thermalThreshold(contrast);
  for (let i = 0; i < rgba.length; i += 4) {
    const a = rgba[i + 3] / 255;
    // على ورقة بيضا
    const r = rgba[i] * a + 255 * (1 - a);
    const g = rgba[i + 1] * a + 255 * (1 - a);
    const b = rgba[i + 2] * a + 255 * (1 - a);
    const lum = 0.2126 * r + 0.7152 * g + 0.0722 * b;
    if (lum < th) {
      out[i] = 0;
      out[i + 1] = 0;
      out[i + 2] = 0;
      out[i + 3] = 255;
    } else {
      out[i] = 255;
      out[i + 1] = 255;
      out[i + 2] = 255;
      out[i + 3] = 0;
    }
  }
  return out;
}

/** التحقق من الملف قبل المعالجة */
export function checkLogoFile(f: { type: string; size: number }): 'ok' | 'type' | 'size' {
  if (!(LOGO_TYPES as readonly string[]).includes(f.type)) return 'type';
  if (f.size > MAX_LOGO_BYTES) return 'size';
  return 'ok';
}

// ---------------- المتصفح ----------------
export async function loadImage(src: Blob | string): Promise<HTMLImageElement> {
  const url = typeof src === 'string' ? src : URL.createObjectURL(src);
  try {
    const img = new Image();
    img.decoding = 'async';
    img.src = url;
    await img.decode();
    return img;
  } finally {
    if (typeof src !== 'string') setTimeout(() => URL.revokeObjectURL(url), 1000);
  }
}

/** اللوجو الملون جوه الإطار (PNG شفاف) */
export function renderColor(img: HTMLImageElement, zoom: number, panX: number, panY: number): HTMLCanvasElement {
  const c = document.createElement('canvas');
  c.width = LOGO_W;
  c.height = LOGO_H;
  const ctx = c.getContext('2d')!;
  const p = placeImage(img.naturalWidth || img.width, img.naturalHeight || img.height, LOGO_W, LOGO_H, zoom, panX, panY);
  ctx.imageSmoothingQuality = 'high';
  ctx.drawImage(img, p.x, p.y, p.w, p.h);
  return c;
}

/** النسخة الحرارية من صورة ملونة جاهزة */
export function renderThermal(color: HTMLCanvasElement | HTMLImageElement, contrast: number): HTMLCanvasElement {
  const c = document.createElement('canvas');
  c.width = LOGO_W;
  c.height = LOGO_H;
  const ctx = c.getContext('2d')!;
  const w = color instanceof HTMLImageElement ? color.naturalWidth : color.width;
  const h = color instanceof HTMLImageElement ? color.naturalHeight : color.height;
  const p = placeImage(w, h, LOGO_W, LOGO_H);
  ctx.drawImage(color, p.x, p.y, p.w, p.h);
  const data = ctx.getImageData(0, 0, LOGO_W, LOGO_H);
  data.data.set(toThermal(data.data, contrast));
  ctx.putImageData(data, 0, 0);
  return c;
}

/** بيقص الفراغ الشفاف حوالين الصورة (عشان اللوجو ما يبقاش صغير جوه مساحة فاضية) */
export function trimCanvas(c: HTMLCanvasElement): HTMLCanvasElement {
  const ctx = c.getContext('2d')!;
  const { data, width, height } = ctx.getImageData(0, 0, c.width, c.height);
  const b = alphaBounds(data, width, height);
  if (!b) return c;
  const out = document.createElement('canvas');
  out.width = b.w;
  out.height = b.h;
  out.getContext('2d')!.drawImage(c, b.x, b.y, b.w, b.h, 0, 0, b.w, b.h);
  return out;
}

/** حدود الجزء المرسوم (غير الشفاف) في الصورة */
export function alphaBounds(data: Uint8ClampedArray, width: number, height: number): Placement | null {
  let minX = width;
  let minY = height;
  let maxX = -1;
  let maxY = -1;
  for (let y = 0; y < height; y++) {
    for (let x = 0; x < width; x++) {
      if (data[(y * width + x) * 4 + 3] > 8) {
        if (x < minX) minX = x;
        if (y < minY) minY = y;
        if (x > maxX) maxX = x;
        if (y > maxY) maxY = y;
      }
    }
  }
  return maxX < 0 ? null : { x: minX, y: minY, w: maxX - minX + 1, h: maxY - minY + 1 };
}
