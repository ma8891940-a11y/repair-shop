/**
 * تشفير ملف النسخة الاحتياطية على الجهاز قبل ما يتحفظ (WebCrypto، مدمج في المتصفح ومن غير مكتبات):
 * PBKDF2 (SHA-256، 310,000 مرة) بيحوّل كلمة السر لمفتاح، وAES-GCM 256 بيشفّر ويتأكد إن الملف ما اتلعبش فيه.
 * من غير كلمة السر الملف ما يتفتحش، حتى معانا.
 */
const ITER = 310_000;
const enc = new TextEncoder();
const dec = new TextDecoder();

export interface EncryptedBackup {
  format: 'warsha-backup-enc';
  v: 1;
  kdf: 'PBKDF2-SHA256';
  iter: number;
  salt: string;
  iv: string;
  data: string;
}

function b64(u: Uint8Array): string {
  let s = '';
  for (let i = 0; i < u.length; i += 0x8000) s += String.fromCharCode(...u.subarray(i, i + 0x8000));
  return btoa(s);
}
function unb64(s: string): Uint8Array<ArrayBuffer> {
  const bin = atob(s);
  const out = new Uint8Array(new ArrayBuffer(bin.length));
  for (let i = 0; i < bin.length; i++) out[i] = bin.charCodeAt(i);
  return out;
}
async function keyFrom(password: string, salt: Uint8Array<ArrayBuffer>, iter: number) {
  const base = await crypto.subtle.importKey('raw', enc.encode(password), 'PBKDF2', false, ['deriveKey']);
  return crypto.subtle.deriveKey({ name: 'PBKDF2', hash: 'SHA-256', salt, iterations: iter }, base, { name: 'AES-GCM', length: 256 }, false, ['encrypt', 'decrypt']);
}

export async function encryptBackup(data: unknown, password: string, iter = ITER): Promise<EncryptedBackup> {
  if (password.length < 8) throw new Error('E_WEAK_BACKUP_PASSWORD');
  const salt = crypto.getRandomValues(new Uint8Array(new ArrayBuffer(16)));
  const iv = crypto.getRandomValues(new Uint8Array(new ArrayBuffer(12)));
  const key = await keyFrom(password, salt, iter);
  const ct = new Uint8Array(await crypto.subtle.encrypt({ name: 'AES-GCM', iv }, key, enc.encode(JSON.stringify(data))));
  return { format: 'warsha-backup-enc', v: 1, kdf: 'PBKDF2-SHA256', iter, salt: b64(salt), iv: b64(iv), data: b64(ct) };
}

export async function decryptBackup<T = unknown>(file: EncryptedBackup, password: string): Promise<T> {
  if (file?.format !== 'warsha-backup-enc' || file.v !== 1) throw new Error('E_BACKUP_FORMAT');
  const key = await keyFrom(password, unb64(file.salt), file.iter);
  try {
    const pt = await crypto.subtle.decrypt({ name: 'AES-GCM', iv: unb64(file.iv) }, key, unb64(file.data));
    return JSON.parse(dec.decode(pt)) as T;
  } catch {
    throw new Error('E_BACKUP_PASSWORD'); // كلمة سر غلط أو الملف اتعدّل
  }
}

/** ملخص النسخة: عدد الصفوف في كل جدول */
export function backupSummary(b: Record<string, unknown>): Record<string, number> {
  const out: Record<string, number> = {};
  for (const [k, v] of Object.entries(b)) if (Array.isArray(v)) out[k] = v.length;
  return out;
}
