/**
 * تصدير Excel حقيقي (xlsx): الشيت من اليمين للشمال، وعنوان وفترة فوق، وعناوين أعمدة،
 * والمبالغ أرقام بتنسيق #,##0.00، والتواريخ تواريخ، وسطر إجمالي بمعادلة SUM.
 * المبالغ بتيجي بالقروش (أعداد صحيحة) وبتتكتب بالجنيه كنص عشري من غير أي حساب بكسور (plainPounds).
 */
import { assertPiasters } from './money';
import { plainPounds } from './ledger';
import { cairoOffsetMinutes } from './dates';
import { zip } from './zip';

export type ColType = 'text' | 'money' | 'int' | 'date' | 'datetime';
export interface ExportColumn {
  header: string;
  type?: ColType;
  /** يتجمع في سطر الإجمالي (للمبالغ والأعداد) */
  total?: boolean;
  /** عرض العمود بالحروف (اختياري) */
  width?: number;
}
export type Cell = string | number | null | undefined;
export interface ExportTable {
  /** اسم الشيت والعنوان */
  title: string;
  /** سطور تحت العنوان: اسم المحل، والفترة، وتاريخ الطباعة... */
  meta?: string[];
  columns: ExportColumn[];
  rows: Cell[][];
  /** اسم الملف بالإنجليزي (من غير التاريخ) */
  file?: string;
  /** عنوان سطر الإجمالي (لو فيه أعمدة total) */
  totalLabel?: string;
}

// الحروف الخفية (تحت 32 غير Tab وسطر جديد) ممنوعة في XML: بتتشال
const stripControl = (s: string) => [...s].filter((ch) => { const c = ch.charCodeAt(0); return c >= 32 || c === 9 || c === 10 || c === 13; }).join('');
const esc = (s: string) => stripControl(s).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');

/** A, B, ... Z, AA ... */
export function colName(i: number): string {
  let s = '';
  for (let n = i + 1; n > 0; n = Math.floor((n - 1) / 26)) s = String.fromCharCode(65 + ((n - 1) % 26)) + s;
  return s;
}

/** رقم اليوم في Excel (من 1899-12-30) لتاريخ YYYY-MM-DD */
export function excelDay(day: string): number {
  const [y, m, d] = day.slice(0, 10).split('-').map(Number);
  return Math.round(Date.UTC(y, m - 1, d) / 86_400_000) + 25_569;
}
/** التاريخ والوقت بتوقيت القاهرة كرقم Excel (اليوم + جزء من اليوم للوقت). مش فلوس، فالكسر هنا عادي */
export function excelDateTime(at: string | Date): number {
  const t = typeof at === 'string' ? new Date(at) : at;
  const local = t.getTime() + cairoOffsetMinutes(t) * 60_000;
  const minutes = Math.floor(local / 60_000);
  // اليوم عدد صحيح + الدقايق ككسر بدقة كفاية إن Excel يقراها بالدقيقة بالظبط
  const day = Math.floor(minutes / 1440);
  const frac = (minutes - day * 1440) / 1440;
  return Number((day + 25_569 + frac).toFixed(10));
}

// أرقام الستايلات في styles.xml تحت
const S = { text: 0, head: 1, money: 2, int: 3, date: 4, datetime: 5, title: 6, totalLabel: 7, totalMoney: 8, totalInt: 9, meta: 10 } as const;

/** المبالغ والأعداد ساعات بتيجي من قاعدة البيانات كنص ("1500"): بتتقري رقم لو هي عدد صحيح بس */
function asInt(v: Cell): Cell {
  return typeof v === 'string' && /^-?\d+$/.test(v) ? Number(v) : v;
}

function cellXml(ref: string, raw: Cell, type: ColType): string {
  const v = type === 'money' || type === 'int' ? asInt(raw) : raw;
  if (v == null || v === '') return '';
  if (type === 'money' && typeof v === 'number') {
    assertPiasters(v);
    return `<c r="${ref}" s="${S.money}"><v>${plainPounds(v)}</v></c>`;
  }
  if (type === 'int' && typeof v === 'number' && Number.isFinite(v)) return `<c r="${ref}" s="${S.int}"><v>${v}</v></c>`;
  if (type === 'date' && typeof v === 'string' && /^\d{4}-\d{2}-\d{2}/.test(v)) {
    // تاريخ ووقت كامل (ISO) بيتحول لليوم بتوقيت القاهرة
    const n = v.length > 10 ? Math.floor(excelDateTime(v)) : excelDay(v);
    return `<c r="${ref}" s="${S.date}"><v>${n}</v></c>`;
  }
  if (type === 'datetime' && typeof v === 'string' && /^\d{4}-\d{2}-\d{2}/.test(v)) return `<c r="${ref}" s="${S.datetime}"><v>${excelDateTime(v)}</v></c>`;
  return `<c r="${ref}" t="inlineStr" s="${S.text}"><is><t xml:space="preserve">${esc(String(v))}</t></is></c>`;
}

function textCell(ref: string, s: string, style: number) {
  return `<c r="${ref}" t="inlineStr" s="${style}"><is><t xml:space="preserve">${esc(s)}</t></is></c>`;
}

export function sheetXml(t: ExportTable): string {
  const cols = t.columns;
  const last = colName(Math.max(cols.length - 1, 0));
  const rows: string[] = [];
  let r = 1;
  rows.push(`<row r="${r}" ht="22" customHeight="1">${textCell(`A${r}`, t.title, S.title)}</row>`);
  r++;
  for (const m of t.meta ?? []) {
    rows.push(`<row r="${r}">${textCell(`A${r}`, m, S.meta)}</row>`);
    r++;
  }
  r++; // سطر فاضي
  const headRow = r;
  rows.push(`<row r="${r}">${cols.map((c, i) => textCell(`${colName(i)}${r}`, c.header, S.head)).join('')}</row>`);
  r++;
  const first = r;
  for (const row of t.rows) {
    rows.push(`<row r="${r}">${cols.map((c, i) => cellXml(`${colName(i)}${r}`, row[i], c.type ?? 'text')).join('')}</row>`);
    r++;
  }
  const lastData = r - 1;
  const hasTotal = cols.some((c) => c.total);
  if (hasTotal) {
    const cells = cols.map((c, i) => {
      const ref = `${colName(i)}${r}`;
      if (c.total && (c.type === 'money' || c.type === 'int')) {
        // الإجمالي بيتحسب بأعداد صحيحة (قروش) ومكتوب كقيمة جاهزة جنب المعادلة
        let sum = 0;
        for (const row of t.rows) {
          const v = asInt(row[i]);
          if (typeof v === 'number') sum += v;
        }
        const val = c.type === 'money' ? (assertPiasters(sum), plainPounds(sum)) : String(sum);
        const f = lastData >= first ? `<f>SUM(${colName(i)}${first}:${colName(i)}${lastData})</f>` : '';
        return `<c r="${ref}" s="${c.type === 'money' ? S.totalMoney : S.totalInt}">${f}<v>${val}</v></c>`;
      }
      return i === 0 ? textCell(ref, t.totalLabel ?? 'Total', S.totalLabel) : `<c r="${ref}" s="${S.totalLabel}"/>`;
    });
    rows.push(`<row r="${r}">${cells.join('')}</row>`);
  }
  const width = (c: ExportColumn) => c.width ?? (c.type === 'money' ? 16 : c.type === 'date' ? 13 : c.type === 'datetime' ? 18 : c.type === 'int' ? 10 : Math.min(Math.max(c.header.length + 4, 14), 40));
  const colsXml = `<cols>${cols.map((c, i) => `<col min="${i + 1}" max="${i + 1}" width="${width(c)}" customWidth="1"/>`).join('')}</cols>`;
  const filter = t.rows.length ? `<autoFilter ref="A${headRow}:${last}${lastData}"/>` : '';
  return (
    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>' +
    '<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">' +
    `<sheetViews><sheetView rightToLeft="1" workbookViewId="0"><pane ySplit="${headRow}" topLeftCell="A${headRow + 1}" activePane="bottomLeft" state="frozen"/></sheetView></sheetViews>` +
    `<sheetFormatPr defaultRowHeight="18"/>${colsXml}<sheetData>${rows.join('')}</sheetData>${filter}` +
    '<pageMargins left="0.4" right="0.4" top="0.5" bottom="0.5" header="0.3" footer="0.3"/>' +
    '<pageSetup orientation="landscape" fitToWidth="1" fitToHeight="0"/>' +
    '</worksheet>'
  );
}

const STYLES =
  '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>' +
  '<styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">' +
  '<numFmts count="3"><numFmt numFmtId="164" formatCode="#,##0.00"/><numFmt numFmtId="165" formatCode="yyyy-mm-dd"/><numFmt numFmtId="166" formatCode="yyyy-mm-dd hh:mm"/></numFmts>' +
  '<fonts count="4"><font><sz val="11"/><name val="Arial"/></font><font><b/><sz val="11"/><name val="Arial"/></font><font><b/><sz val="14"/><name val="Arial"/></font><font><sz val="10"/><color rgb="FF555555"/><name val="Arial"/></font></fonts>' +
  '<fills count="3"><fill><patternFill patternType="none"/></fill><fill><patternFill patternType="gray125"/></fill><fill><patternFill patternType="solid"><fgColor rgb="FFE8EAED"/><bgColor indexed="64"/></patternFill></fill></fills>' +
  '<borders count="3"><border><left/><right/><top/><bottom/><diagonal/></border><border><left/><right/><top/><bottom style="thin"><color rgb="FF9AA0A6"/></bottom><diagonal/></border><border><left/><right/><top style="medium"><color rgb="FF202124"/></top><bottom/><diagonal/></border></borders>' +
  '<cellStyleXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0"/></cellStyleXfs>' +
  '<cellXfs count="11">' +
  '<xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"><alignment horizontal="right" vertical="center"/></xf>' + // 0 نص
  '<xf numFmtId="0" fontId="1" fillId="2" borderId="1" xfId="0" applyFont="1" applyFill="1" applyBorder="1"><alignment horizontal="center" vertical="center" wrapText="1"/></xf>' + // 1 عنوان عمود
  '<xf numFmtId="164" fontId="0" fillId="0" borderId="0" xfId="0" applyNumberFormat="1"/>' + // 2 مبلغ
  '<xf numFmtId="3" fontId="0" fillId="0" borderId="0" xfId="0" applyNumberFormat="1"/>' + // 3 عدد
  '<xf numFmtId="165" fontId="0" fillId="0" borderId="0" xfId="0" applyNumberFormat="1"><alignment horizontal="center"/></xf>' + // 4 تاريخ
  '<xf numFmtId="166" fontId="0" fillId="0" borderId="0" xfId="0" applyNumberFormat="1"><alignment horizontal="center"/></xf>' + // 5 تاريخ ووقت
  '<xf numFmtId="0" fontId="2" fillId="0" borderId="0" xfId="0" applyFont="1"><alignment horizontal="right"/></xf>' + // 6 العنوان
  '<xf numFmtId="0" fontId="1" fillId="0" borderId="2" xfId="0" applyFont="1" applyBorder="1"><alignment horizontal="right"/></xf>' + // 7 الإجمالي
  '<xf numFmtId="164" fontId="1" fillId="0" borderId="2" xfId="0" applyNumberFormat="1" applyFont="1" applyBorder="1"/>' + // 8 إجمالي مبلغ
  '<xf numFmtId="3" fontId="1" fillId="0" borderId="2" xfId="0" applyNumberFormat="1" applyFont="1" applyBorder="1"/>' + // 9 إجمالي عدد
  '<xf numFmtId="0" fontId="3" fillId="0" borderId="0" xfId="0" applyFont="1"><alignment horizontal="right"/></xf>' + // 10 سطور المعلومات
  '</cellXfs><cellStyles count="1"><cellStyle name="Normal" xfId="0" builtinId="0"/></cellStyles></styleSheet>';

/** اسم الشيت: Excel بيرفض \ / ? * [ ] : وأكتر من 31 حرف */
export function sheetName(s: string): string {
  return s.replace(/[\\/?*[\]:]/g, ' ').trim().slice(0, 31) || 'Sheet1';
}

export function buildXlsx(t: ExportTable): Uint8Array {
  const name = esc(sheetName(t.title));
  return zip([
    {
      name: '[Content_Types].xml',
      data:
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">' +
        '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Default Extension="xml" ContentType="application/xml"/>' +
        '<Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>' +
        '<Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>' +
        '<Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/></Types>',
    },
    {
      name: '_rels/.rels',
      data: '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/></Relationships>',
    },
    {
      name: 'xl/workbook.xml',
      data: `<?xml version="1.0" encoding="UTF-8" standalone="yes"?><workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><bookViews><workbookView/></bookViews><sheets><sheet name="${name}" sheetId="1" r:id="rId1"/></sheets><calcPr calcId="191029" fullCalcOnLoad="1"/></workbook>`,
    },
    {
      name: 'xl/_rels/workbook.xml.rels',
      data: '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/><Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/></Relationships>',
    },
    { name: 'xl/styles.xml', data: STYLES },
    { name: 'xl/worksheets/sheet1.xml', data: sheetXml(t) },
  ]);
}

/** اسم الملف: كلمة إنجليزي + التاريخ (devices-2026-11-09.xlsx). الأسماء العربي بتتحول "download" في بعض المتصفحات والأغلفة */
export function exportFileName(slug: string, day: string, ext: 'xlsx' | 'csv'): string {
  const safe = slug.toLowerCase().replace(/[^a-z0-9_-]+/g, '-').replace(/^-+|-+$/g, '') || 'export';
  return `${safe}-${day}.${ext}`;
}
