/** 50.3: صورة خلفية القالب: PNG أو JPG بس بمحتوى الملف (مش باسمه)، ونسبتها تطابق الورقة، وبتتعاد رسمها قبل الرفع */
export const BG_MAX_BYTES = 2 * 1024 * 1024;
export const BG_MAX_PX = 10000;
/** فوق كده canvas بيطلع فاضي على آيفون من غير خطأ (A4 بدقة 300 = 8.7 مليون) */
export const BG_MAX_AREA = 16_000_000;
export type BgType = 'png' | 'jpg';

const PNG = [0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a];
export function sniffImage(bytes: Uint8Array): BgType | null {
  if (PNG.every((b, i) => bytes[i] === b)) return 'png';
  if (bytes[0] === 0xff && bytes[1] === 0xd8 && bytes[2] === 0xff) return 'jpg';
  return null;
}

/** الصورة بعرض الورقة: طولها لازم يطلع طول الورقة بسماح نص مللي (أعداد صحيحة، ونفس الحساب في 0089) */
export function bgFits(px: { w: number; h: number }, paper: { w: number; h: number | null }): boolean {
  return paper.h != null && px.w > 0 && 2 * Math.abs(paper.w * px.h - paper.h * px.w) <= px.w;
}

export interface PreparedBg {
  blob: Blob;
  type: BgType;
  w: number;
  h: number;
}
export async function prepareBackground(file: File, paper: { w: number; h: number | null }): Promise<PreparedBg> {
  if (file.size > BG_MAX_BYTES) throw new Error('E_BG_SIZE');
  const type = sniffImage(new Uint8Array(await file.slice(0, 8).arrayBuffer()));
  if (!type) throw new Error('E_BG_TYPE');
  const mime = type === 'png' ? 'image/png' : 'image/jpeg';
  // النوع من المحتوى: متصفح ما يفسّرش الملف بحاجة تانية
  const bitmap = await createImageBitmap(new Blob([file], { type: mime })).catch(() => {
    throw new Error('E_BG_TYPE');
  });
  try {
    const { width: w, height: h } = bitmap;
    if (w > BG_MAX_PX || h > BG_MAX_PX || w * h > BG_MAX_AREA) throw new Error('E_BG_SIZE');
    if (!bgFits({ w, h }, paper)) throw new Error('E_BG_RATIO', { cause: paper });
    const canvas = document.createElement('canvas');
    canvas.width = w;
    canvas.height = h;
    canvas.getContext('2d')!.drawImage(bitmap, 0, 0);
    const blob = await new Promise<Blob>((ok, no) => canvas.toBlob((b) => (b ? ok(b) : no(new Error('E_BG_TYPE'))), mime, 0.92));
    if (blob.size > BG_MAX_BYTES) throw new Error('E_BG_SIZE');
    return { blob, type, w, h };
  } finally {
    bitmap.close();
  }
}
