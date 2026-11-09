import { describe, expect, it } from 'vitest';
import { buildXlsx, colName, excelDateTime, excelDay, sheetName, sheetXml, type ExportTable } from './xlsx';
import { crc32 } from './zip';

// قارئ zip صغير للاختبار بس (الملفات من غير ضغط)
function unzip(buf: Uint8Array): Record<string, string> {
  const v = new DataView(buf.buffer, buf.byteOffset, buf.byteLength);
  const out: Record<string, string> = {};
  let p = 0;
  const dec = new TextDecoder();
  while (v.getUint32(p, true) === 0x04034b50) {
    const crc = v.getUint32(p + 14, true);
    const size = v.getUint32(p + 18, true);
    const nl = v.getUint16(p + 26, true);
    const name = dec.decode(buf.subarray(p + 30, p + 30 + nl));
    const data = buf.subarray(p + 30 + nl, p + 30 + nl + size);
    expect(crc32(data)).toBe(crc);
    out[name] = dec.decode(data);
    p += 30 + nl + size;
  }
  return out;
}

const table: ExportTable = {
  title: 'المصروفات',
  meta: ['محل الصيانة', 'الفترة: 2026-11-01 ← 2026-11-09'],
  columns: [{ header: 'البيان' }, { header: 'التاريخ', type: 'date' }, { header: 'المبلغ', type: 'money', total: true }, { header: 'العدد', type: 'int', total: true }],
  rows: [
    ['إيجار <المحل>', '2026-11-01', 500_000, 1],
    ['=HYPERLINK("x")', '2026-11-03T22:30:00Z', 12_345, 2],
    ['كهربا', '2026-11-05', -5, 3],
  ],
};

describe('تصدير Excel (xlsx)', () => {
  it('الملف فيه كل الأجزاء اللي Excel محتاجها، والـ CRC صح', () => {
    const files = unzip(buildXlsx(table));
    expect(Object.keys(files).sort()).toEqual(['[Content_Types].xml', '_rels/.rels', 'xl/_rels/workbook.xml.rels', 'xl/styles.xml', 'xl/workbook.xml', 'xl/worksheets/sheet1.xml']);
    expect(files['xl/workbook.xml']).toContain('name="المصروفات"');
  });
  it('من اليمين للشمال، والمبالغ أرقام بالجنيه من غير كسور في الحساب، والإجمالي صح', () => {
    const x = sheetXml(table);
    expect(x).toContain('rightToLeft="1"');
    expect(x).toContain('<v>5000.00</v>');
    expect(x).toContain('<v>123.45</v>');
    expect(x).toContain('<v>-0.05</v>');
    // الإجمالي: 500000 + 12345 - 5 = 512340 قرش
    expect(x).toMatch(/<f>SUM\(C\d+:C\d+\)<\/f><v>5123.40<\/v>/);
    expect(x).toMatch(/<f>SUM\(D\d+:D\d+\)<\/f><v>6<\/v>/);
  });
  it('النصوص متأمّنة (مفيش XML مكسور ولا صيغ بتتنفذ)، والتواريخ أرقام Excel', () => {
    const x = sheetXml(table);
    expect(x).toContain('إيجار &lt;المحل&gt;');
    // النص اللي شكله معادلة بيتكتب نص، مش <f>
    expect(x).toContain('<t xml:space="preserve">=HYPERLINK(&quot;x&quot;)</t>');
    expect(x.match(/<f>/g)?.length).toBe(2);
    expect(excelDay('2026-11-01')).toBe(46_327);
    // 22:30 UTC = 00:30 بتوقيت القاهرة يوم 4 (الشتا +2)
    expect(Math.floor(excelDateTime('2026-11-03T22:30:00Z'))).toBe(46_330);
    expect(x).toContain('<v>46330</v>');
  });
  it('مبلغ مش عدد صحيح بيترفض (ممنوع كسور في الفلوس)', () => {
    expect(() => sheetXml({ ...table, rows: [['x', '2026-11-01', 10.5, 1]] })).toThrow();
  });
  it('أسماء الأعمدة واسم الشيت', () => {
    expect([colName(0), colName(25), colName(26), colName(701)]).toEqual(['A', 'Z', 'AA', 'ZZ']);
    expect(sheetName('كشف: عميل/1 [x]')).toBe('كشف  عميل 1  x');
    expect(sheetName('أ'.repeat(40)).length).toBe(31);
  });
  it('من غير صفوف: الملف سليم ومن غير فلتر', () => {
    const x = sheetXml({ ...table, rows: [] });
    expect(x).not.toContain('autoFilter');
    expect(x).not.toContain('<f>');
  });
});
