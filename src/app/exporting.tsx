import { useNavigate } from 'react-router';
import { useTranslation } from 'react-i18next';
import * as DropdownMenu from '@radix-ui/react-dropdown-menu';
import { Download, FileSpreadsheet, FileText, Sheet } from 'lucide-react';
import { useMe } from './auth';
import { buildXlsx, exportFileName, type ExportTable } from '../lib/xlsx';
import { toCsv } from '../lib/ledger';
import { plainPounds } from '../lib/ledger';
import { cairoDay } from '../lib/dates';
import { useFormat } from '../i18n/format';
import { Button } from '../ui/Button';

/**
 * التصدير من أي شاشة: Excel حقيقي (xlsx)، وPDF (صفحة A4 بلوجو المحل بتتطبع أو تتحفظ PDF)، وCSV.
 * الشاشة بتدّي نفس الصفوف اللي ظاهرة قدامها (بنفس الفلتر والترتيب)، والمبالغ بالقروش.
 */
const KEY = 'export-table';
let pending: ExportTable | null = null;

export function setPendingTable(t: ExportTable) {
  pending = t;
  try {
    sessionStorage.setItem(KEY, JSON.stringify(t));
  } catch {
    /* التخزين مقفول: الذاكرة كفاية طول ما البرنامج مفتوح */
  }
}
export function getPendingTable(): ExportTable | null {
  if (pending) return pending;
  try {
    const s = sessionStorage.getItem(KEY);
    return s ? (JSON.parse(s) as ExportTable) : null;
  } catch {
    return null;
  }
}

export function downloadFile(data: Uint8Array | string, name: string, type: string) {
  const blob = new Blob([data as BlobPart], { type });
  const a = document.createElement('a');
  a.href = URL.createObjectURL(blob);
  a.download = name;
  document.body.appendChild(a);
  a.click();
  a.remove();
  setTimeout(() => URL.revokeObjectURL(a.href), 2000);
}

/** CSV من نفس الجدول (للي متعود عليه): المبالغ بالجنيه بنقطة عشرية */
export function tableToCsv(t: ExportTable): string {
  const rows = t.rows.map((r) => t.columns.map((c, i) => {
    const v = r[i];
    return c.type === 'money' && typeof v === 'number' ? plainPounds(v) : v;
  }));
  return toCsv([[t.title], ...(t.meta ?? []).map((m) => [m]), t.columns.map((c) => c.header), ...rows]);
}

/** بيزوّد اسم المحل وتاريخ الطباعة فوق الجدول */
export function useExporter() {
  const { t } = useTranslation();
  const f = useFormat();
  const { shop } = useMe();
  const navigate = useNavigate();
  const withMeta = (tb: ExportTable): ExportTable => ({
    ...tb,
    totalLabel: tb.totalLabel ?? t('export.total'),
    meta: [shop.name, ...(tb.meta ?? []), t('export.printedAt', { at: f.dateTime(new Date(), { plain: true }) })],
  });
  const day = cairoDay(new Date());
  return {
    xlsx(tb: ExportTable) {
      downloadFile(buildXlsx(withMeta(tb)), exportFileName(tb.file ?? 'export', day, 'xlsx'), 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
    },
    csv(tb: ExportTable) {
      downloadFile(tableToCsv(withMeta(tb)), exportFileName(tb.file ?? 'export', day, 'csv'), 'text/csv;charset=utf-8');
    },
    pdf(tb: ExportTable) {
      setPendingTable(withMeta(tb));
      navigate('/print/table');
    },
  };
}

/** زرار "تصدير": Excel وPDF وCSV. table بيتبني ساعة الضغط من الصفوف اللي على الشاشة */
export function ExportMenu({ table, testid = 'export', disabled, csv }: {
  table: () => ExportTable | null | undefined | false;
  testid?: string;
  disabled?: boolean;
  /** CSV بشكل خاص (زي ملف المخزون اللي بيرجع يدخل بالاستيراد) بدل CSV الجدول */
  csv?: () => void;
}) {
  const { t } = useTranslation();
  const ex = useExporter();
  const run = (kind: 'xlsx' | 'pdf' | 'csv') => {
    if (kind === 'csv' && csv) return csv();
    const tb = table();
    if (tb) ex[kind]({ file: testid.replace(/-export$/, ''), ...tb });
  };
  const item = 'flex h-8 cursor-pointer select-none items-center gap-2 rounded-sm px-2.5 text-sm text-fg outline-none data-[highlighted]:bg-raised data-[highlighted]:text-fg';
  return (
    <DropdownMenu.Root>
      <DropdownMenu.Trigger asChild disabled={disabled}>
        <Button size="sm" variant="ghost" icon={<Download className="size-4" />} data-testid={testid} disabled={disabled}>
          {t('export.button')}
        </Button>
      </DropdownMenu.Trigger>
      <DropdownMenu.Portal>
        <DropdownMenu.Content align="end" sideOffset={6} className="glass z-50 min-w-44 rounded-md p-1 shadow-2" data-testid={`${testid}-menu`}>
          <DropdownMenu.Item className={item} onSelect={() => run('xlsx')} data-testid={`${testid}-xlsx`}>
            <FileSpreadsheet className="size-4 text-accent" aria-hidden />
            {t('export.xlsx')}
          </DropdownMenu.Item>
          <DropdownMenu.Item className={item} onSelect={() => run('pdf')} data-testid={`${testid}-pdf`}>
            <FileText className="size-4 text-fg-3" aria-hidden />
            {t('export.pdf')}
          </DropdownMenu.Item>
          <DropdownMenu.Item className={item} onSelect={() => run('csv')} data-testid={`${testid}-csv`}>
            <Sheet className="size-4 text-fg-3" aria-hidden />
            {t('export.csv')}
          </DropdownMenu.Item>
        </DropdownMenu.Content>
      </DropdownMenu.Portal>
    </DropdownMenu.Root>
  );
}
