import { describe, expect, it } from 'vitest';
import { alphaBounds, checkLogoFile, logoUploadError, placeImage, thermalThreshold, toThermal, uploadSize } from './brandImage';

describe('مكان اللوجو جوه الإطار (قص وتكبير)', () => {
  it('من غير تكبير: الصورة كلها جوه الإطار ومتوسّطة', () => {
    expect(placeImage(100, 100, 640, 320)).toEqual({ x: 160, y: 0, w: 320, h: 320 });
    expect(placeImage(1000, 250, 640, 320)).toEqual({ x: 0, y: 80, w: 640, h: 160 });
  });
  it('التكبير والتحريك جوه الحدود، وبقيم محصورة', () => {
    const p = placeImage(100, 100, 640, 320, 2, 1, 0);
    expect(p.w).toBe(640);
    expect(p.h).toBe(640);
    expect(p.x).toBe(0); // اتحرك لأقصى اليمين: حافة الصورة على حافة الإطار
    expect(placeImage(100, 100, 640, 320, 99, 5, -5)).toEqual(placeImage(100, 100, 640, 320, 4, 1, -1));
    expect(placeImage(0, 10, 640, 320)).toEqual({ x: 0, y: 0, w: 0, h: 0 });
  });
});

describe('النسخة الحرارية (أبيض وأسود)', () => {
  const px = (r: number, g: number, b: number, a = 255) => [r, g, b, a];
  it('كل بكسل يا أسود صريح يا شفاف، والتباين بيغيّر العتبة', () => {
    const src = new Uint8ClampedArray([...px(20, 20, 20), ...px(240, 240, 240), ...px(128, 128, 128), ...px(0, 0, 0, 0)]);
    const low = toThermal(src, 0);
    const high = toThermal(src, 100);
    expect(Array.from(low)).toEqual([0, 0, 0, 255, 255, 255, 255, 0, 255, 255, 255, 0, 255, 255, 255, 0]);
    // تباين عالي: الرمادي المتوسط بيبقى أسود
    expect(Array.from(high.slice(8, 12))).toEqual([0, 0, 0, 255]);
    // الشفاف دايمًا أبيض (على ورقة الإيصال)
    expect(high[15]).toBe(0);
    for (const v of high) expect([0, 255]).toContain(v);
  });
  it('اللون السماوي الفاتح بيظهر لما التباين يزيد', () => {
    const cyan = new Uint8ClampedArray(px(56, 214, 240));
    expect(toThermal(cyan, 20)[3]).toBe(0);
    expect(toThermal(cyan, 100)[3]).toBe(255);
    expect(thermalThreshold(-5)).toBe(thermalThreshold(0));
    expect(thermalThreshold(500)).toBe(thermalThreshold(100));
  });
  it('حدود الجزء المرسوم', () => {
    const w = 4;
    const d = new Uint8ClampedArray(w * 3 * 4);
    d[(1 * w + 2) * 4 + 3] = 255;
    d[(2 * w + 1) * 4 + 3] = 255;
    expect(alphaBounds(d, w, 3)).toEqual({ x: 1, y: 1, w: 2, h: 2 });
    expect(alphaBounds(new Uint8ClampedArray(16), 2, 2)).toBeNull();
  });
});

describe('ملف اللوجو', () => {
  it('PNG أو JPG أو SVG حتى 2 ميجا', () => {
    expect(checkLogoFile({ type: 'image/png', size: 1000 })).toBe('ok');
    expect(checkLogoFile({ type: 'image/svg+xml', size: 2 * 1024 * 1024 })).toBe('ok');
    expect(checkLogoFile({ type: 'image/gif', size: 10 })).toBe('type');
    // صورة موبايل عادية (3 ميجا) بتتقبل، وبتتصغّر قبل الرفع. الحد 15 ميجا للصور، و2 ميجا لملف SVG
    expect(checkLogoFile({ type: 'image/jpeg', size: 3 * 1024 * 1024 })).toBe('ok');
    expect(checkLogoFile({ type: 'image/jpeg', size: 15 * 1024 * 1024 + 1 })).toBe('size');
    expect(checkLogoFile({ type: 'image/svg+xml', size: 2 * 1024 * 1024 + 1 })).toBe('size');
    expect(checkLogoFile({ type: '', size: 10 })).toBe('type');
  });
});

describe('رفع اللوجو', () => {
  it('النسخة اللي بتترفع: أطول ضلع 1024 بنفس النسبة، ومن غير تكبير للصغيرة', () => {
    expect(uploadSize(4000, 3000)).toEqual({ w: 1024, h: 768 });
    expect(uploadSize(1000, 3000)).toEqual({ w: 341, h: 1024 });
    expect(uploadSize(500, 200)).toEqual({ w: 500, h: 200 });
  });
  it('سبب فشل الرفع بالعربي (مفتاح ترجمة) حسب رد Supabase', () => {
    expect(logoUploadError({ message: 'Bucket not found', statusCode: '404' })).toBe('identity.errBucket');
    expect(logoUploadError({ message: 'The object exceeded the maximum allowed size', statusCode: '413' })).toBe('identity.errSize');
    expect(logoUploadError({ message: 'mime type image/gif is not supported', statusCode: '415' })).toBe('identity.errType');
    expect(logoUploadError({ message: 'new row violates row-level security policy', statusCode: '403' })).toBe('identity.errPerm');
    expect(logoUploadError({ message: 'Failed to fetch' })).toBe('identity.errNet');
    expect(logoUploadError({ message: 'something else' })).toBe('identity.errUpload');
  });
});
