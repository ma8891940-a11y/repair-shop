import { afterEach, describe, expect, it, vi } from 'vitest';
import { BG_MAX_BYTES, bgFits, prepareBackground, sniffImage } from './printBackground';

const PNG = [0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a];
const JPG = [0xff, 0xd8, 0xff, 0xe0, 0, 0, 0, 0];
const text = (s: string) => [...new TextEncoder().encode(s)];
const file = (bytes: number[], name = 'a.png', type = 'image/png') => new File([new Uint8Array(bytes)], name, { type });
const paper = { w: 40, h: 30 };
afterEach(() => vi.unstubAllGlobals());

describe('صورة خلفية القالب (50.3)', () => {
  it('النوع بالمحتوى مش بالاسم', () => {
    expect(sniffImage(new Uint8Array(PNG))).toBe('png');
    expect(sniffImage(new Uint8Array(JPG))).toBe('jpg');
    for (const s of ['<svg xmlns="x">', '<!doctype html>', '<?xml', 'GIF89a..', 'RIFF....WEBP', '%PDF-1.7', '']) expect(sniffImage(new Uint8Array(text(s))), s).toBeNull();
  });
  it('النسبة بسماح نص مللي، والورقة من غير طول مرفوضة', () => {
    expect(bgFits({ w: 400, h: 300 }, paper)).toBe(true);
    expect(bgFits({ w: 400, h: 305 }, paper)).toBe(true);
    expect(bgFits({ w: 400, h: 306 }, paper)).toBe(false);
    expect(bgFits({ w: 400, h: 294 }, paper)).toBe(false);
    expect(bgFits({ w: 300, h: 400 }, paper)).toBe(false);
    expect(bgFits({ w: 2480, h: 3508 }, { w: 210, h: 297 })).toBe(true);
    expect(bgFits({ w: 400, h: 300 }, { w: 80, h: null })).toBe(false);
  });
  it('HTML وSVG متسمّيين png، والكبير، مرفوضين قبل أي فك', async () => {
    const decode = vi.fn();
    vi.stubGlobal('createImageBitmap', decode);
    for (const s of ['<svg onload="x">', '<html><script>']) await expect(prepareBackground(file(text(s)), paper)).rejects.toThrow('E_BG_TYPE');
    await expect(prepareBackground(file(new Array(BG_MAX_BYTES + 1).fill(0)), paper)).rejects.toThrow('E_BG_SIZE');
    expect(decode).not.toHaveBeenCalled();
  });
  it('صورة بايظة أو مقاسها غلط أو ضخمة مرفوضة', async () => {
    vi.stubGlobal('createImageBitmap', async () => {
      throw new Error('decode');
    });
    await expect(prepareBackground(file(PNG), paper)).rejects.toThrow('E_BG_TYPE');
    const close = vi.fn();
    vi.stubGlobal('createImageBitmap', async () => ({ width: 300, height: 400, close }));
    await expect(prepareBackground(file(PNG), paper)).rejects.toThrow('E_BG_RATIO');
    vi.stubGlobal('createImageBitmap', async () => ({ width: 40000, height: 30000, close }));
    await expect(prepareBackground(file(JPG), paper)).rejects.toThrow('E_BG_SIZE');
    vi.stubGlobal('createImageBitmap', async () => ({ width: 4960, height: 3720, close }));
    await expect(prepareBackground(file(JPG), paper)).rejects.toThrow('E_BG_SIZE');
    expect(close).toHaveBeenCalledTimes(3);
  });
  it('اللي بيترفع هو الرسم الجديد مش الملف الأصلي', async () => {
    const clean = new Blob(['clean'], { type: 'image/png' });
    const drawImage = vi.fn();
    vi.stubGlobal('createImageBitmap', async () => ({ width: 400, height: 300, close: () => undefined }));
    vi.stubGlobal('document', { createElement: () => ({ getContext: () => ({ drawImage }), toBlob: (cb: (b: Blob) => void) => cb(clean) }) });
    expect(await prepareBackground(file([...PNG, ...text('<script>')]), paper)).toEqual({ blob: clean, type: 'png', w: 400, h: 300 });
    expect(drawImage).toHaveBeenCalledOnce();
  });
});
