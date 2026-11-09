// قراءة ملف Excel اللي البرنامج طلّعه (للاختبار): الشيت كسطور نصوص/أرقام، واتجاه الشيت، والمعادلات
import { readFileSync } from 'node:fs';
import { inflateRawSync } from 'node:zlib';

function unzip(buf: Buffer): Record<string, string> {
  const out: Record<string, string> = {};
  let p = 0;
  while (buf.readUInt32LE(p) === 0x04034b50) {
    const method = buf.readUInt16LE(p + 8);
    const size = buf.readUInt32LE(p + 18);
    const nl = buf.readUInt16LE(p + 26);
    const xl = buf.readUInt16LE(p + 28);
    const name = buf.subarray(p + 30, p + 30 + nl).toString('utf8');
    const data = buf.subarray(p + 30 + nl + xl, p + 30 + nl + xl + size);
    out[name] = (method === 8 ? inflateRawSync(data) : data).toString('utf8');
    p += 30 + nl + xl + size;
  }
  return out;
}

const unesc = (s: string) => s.replace(/&lt;/g, '<').replace(/&gt;/g, '>').replace(/&quot;/g, '"').replace(/&amp;/g, '&');

export interface Sheet {
  rtl: boolean;
  rows: (string | number | null)[][];
  formulas: string[];
  styles: string;
}

export function readXlsx(path: string): Sheet {
  const files = unzip(readFileSync(path));
  const x = files['xl/worksheets/sheet1.xml'];
  const rows: (string | number | null)[][] = [];
  for (const m of x.matchAll(/<row r="(\d+)"[^>]*>(.*?)<\/row>/g)) {
    const r: (string | number | null)[] = [];
    for (const c of m[2].matchAll(/<c r="([A-Z]+)\d+"([^>]*?)(?:\/>|>(.*?)<\/c>)/g)) {
      const col = c[1].split('').reduce((a, ch) => a * 26 + ch.charCodeAt(0) - 64, 0) - 1;
      const inner = c[3] ?? '';
      const t = /<t[^>]*>(.*?)<\/t>/.exec(inner);
      const v = /<v>(.*?)<\/v>/.exec(inner);
      r[col] = t ? unesc(t[1]) : v ? Number(v[1]) : null;
    }
    rows[Number(m[1]) - 1] = Array.from(r, (v) => v ?? null);
  }
  return { rtl: /<sheetView[^>]*rightToLeft="1"/.test(x), rows: Array.from(rows, (r) => r ?? []), formulas: [...x.matchAll(/<f>(.*?)<\/f>/g)].map((m) => m[1]), styles: files['xl/styles.xml'] };
}

/** السطور اللي بعد سطر العناوين (لحد سطر الإجمالي لو موجود) */
export function dataRows(s: Sheet, header: string, totalLabel = 'الإجمالي') {
  const h = s.rows.findIndex((r) => r[0] === header);
  const body = s.rows.slice(h + 1);
  const end = body.findIndex((r) => r[0] === totalLabel);
  return { head: s.rows[h], rows: end === -1 ? body : body.slice(0, end), total: end === -1 ? null : body[end] };
}
