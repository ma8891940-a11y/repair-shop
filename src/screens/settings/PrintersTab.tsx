import { useEffect, useMemo, useState } from 'react';
import { useTranslation } from 'react-i18next';
import { ArrowDown, ArrowUp, Eye, EyeOff, GripVertical, Plus, Printer, RotateCcw, Trash2 } from 'lucide-react';
import { useBranch } from '../../app/branch';
import { useLoad, must } from '../../app/useLoad';
import { supabase } from '../../lib/supabase';
import { errorMessage } from '../../lib/errors';
import { defaultBlocks, move, normalizeBlocks, PRINTER_PRESETS, type Block, type PrinterKind, type TemplateDoc } from '../../lib/printTemplate';
import { VOUCHER_SOURCES } from '../../lib/ledger';
import { Panel, PanelHeader } from '../../ui/Panel';
import { Button } from '../../ui/Button';
import { Field, Input, Select } from '../../ui/Field';
import { Alert, EmptyState } from '../../ui/Feedback';
import { useToast } from '../../ui/Toast';
import { cn } from '../../ui/cn';

interface PrinterRow {
  id: string;
  name: string;
  kind: PrinterKind;
  model: string | null;
  width_mm: number;
  height_mm: number | null;
  margin_mm: number;
}
interface TplRow {
  id: string;
  doc: TemplateDoc;
  branch_id: string | null;
  printer_id: string | null;
  name: string;
  blocks: unknown;
  is_default: boolean;
}
const DOCS: TemplateDoc[] = ['receipt', 'receipt-a4', 'invoice', 'statement', 'voucher', 'sale', 'barcode'];

/**
 * U5: الإعدادات ← الطابعات: ملفات الطابعات (بقوالب جاهزة لأشهر الموديلات) ومصمم الطباعة لكل نوع ورقة.
 * المتصفح ما بيعرضش الطابعات المتوصلة: الملف بيحدد المقاس والهوامش، والطباعة بتفتح نافذة الطباعة على المقاس الصح.
 */
export function PrintersTab() {
  const { t } = useTranslation();
  const toast = useToast();
  const br = useBranch();
  const { data, reload } = useLoad(async () => {
    const [p, tp, dev, cash, ent, sale, bc] = await Promise.all([
      supabase.from('printers').select('id, name, kind, model, width_mm, height_mm, margin_mm').is('deleted_at', null).order('created_at'),
      supabase.from('print_templates').select('id, doc, branch_id, printer_id, name, blocks, is_default').is('deleted_at', null).order('created_at'),
      supabase.from('devices').select('id').is('deleted_at', null).order('created_at', { ascending: false }).limit(1),
      // كشف الحساب: المعاينة على أول خزنة
      supabase.from('accounts').select('id').eq('kind', 'cash').is('deleted_at', null).order('created_at').limit(1),
      // السند: المعاينة على آخر قيد ليه سند
      supabase.from('journal_entries').select('id').in('source_type', VOUCHER_SOURCES).order('created_at', { ascending: false }).limit(1),
      // فاتورة البيع: المعاينة على آخر بيع
      supabase.from('journal_entries').select('id').eq('source_type', 'sale').order('created_at', { ascending: false }).limit(1),
      // ملصق الباركود: المعاينة على آخر صنف ليه باركود
      supabase.from('items').select('id').not('barcode', 'is', null).is('deleted_at', null).order('created_at', { ascending: false }).limit(1),
    ]);
    return {
      printers: must(p) as PrinterRow[],
      templates: must(tp) as TplRow[],
      lastDevice: ((dev.data ?? [])[0] as { id: string } | undefined)?.id ?? null,
      cashbox: ((cash.data ?? [])[0] as { id: string } | undefined)?.id ?? null,
      lastVoucher: ((ent.data ?? [])[0] as { id: string } | undefined)?.id ?? null,
      lastSale: ((sale.data ?? [])[0] as { id: string } | undefined)?.id ?? null,
      lastBarcode: ((bc.data ?? [])[0] as { id: string } | undefined)?.id ?? null,
    };
  }, []);
  const [preset, setPreset] = useState(0);
  async function addPrinter() {
    const p = PRINTER_PRESETS[preset];
    const { error } = await supabase.from('printers').insert({ id: crypto.randomUUID(), shop_id: crypto.randomUUID(), name: p.model, kind: p.kind, model: p.model, width_mm: p.width_mm, height_mm: p.height_mm, margin_mm: p.margin_mm });
    if (error) return toast({ tone: 'danger', title: errorMessage(error) });
    reload();
  }
  async function updPrinter(x: PrinterRow, patch: Partial<PrinterRow>) {
    const { error } = await supabase.from('printers').update(patch).eq('id', x.id);
    if (error) return toast({ tone: 'danger', title: errorMessage(error) });
    reload();
  }
  return (
    <div className="flex flex-col gap-4" data-testid="printers-settings">
      <Panel>
        <PanelHeader title={t('printers.title')} />
        <div className="flex flex-col gap-3 p-4">
          <p className="text-xs text-fg-3">{t('printers.hint')}</p>
          <div className="flex flex-wrap items-end gap-2">
            <Field label={t('printers.preset')}>
              <Select value={preset} onChange={(e) => setPreset(Number(e.target.value))} data-testid="printer-preset">
                {PRINTER_PRESETS.map((p, i) => (
                  <option key={p.model} value={i}>
                    {p.model} · {t(`printers.kinds.${p.kind}`)}
                  </option>
                ))}
              </Select>
            </Field>
            <Button icon={<Plus className="size-4" />} needsNet onClick={() => void addPrinter()} className="mb-5" data-testid="printer-add">
              {t('printers.add')}
            </Button>
          </div>
          {!data?.printers.length ? (
            <EmptyState line="chip" title={t('printers.none')} />
          ) : (
            <ul className="flex flex-col divide-y divide-glass-border rounded-md border border-glass-border">
              {data.printers.map((x) => (
                <li key={x.id} className="grid grid-cols-2 items-end gap-2 px-3 py-2 sm:grid-cols-[minmax(0,1fr)_auto_80px_80px_80px_auto]" data-testid="printer-row">
                  <Input defaultValue={x.name} onBlur={(e) => e.target.value.trim() && e.target.value !== x.name && void updPrinter(x, { name: e.target.value.trim() })} aria-label={t('printers.name')} maxLength={60} />
                  <span className="text-2xs text-fg-3">{t(`printers.kinds.${x.kind}`)}</span>
                  <Input mono inputMode="numeric" defaultValue={x.width_mm} onBlur={(e) => Number(e.target.value) !== x.width_mm && void updPrinter(x, { width_mm: Number(e.target.value) })} aria-label={t('printers.width')} suffix="mm" />
                  <Input mono inputMode="numeric" defaultValue={x.height_mm ?? ''} onBlur={(e) => void updPrinter(x, { height_mm: e.target.value ? Number(e.target.value) : null })} aria-label={t('printers.height')} placeholder={t('printers.auto')} suffix="mm" />
                  <Input mono inputMode="numeric" defaultValue={x.margin_mm} onBlur={(e) => Number(e.target.value) !== x.margin_mm && void updPrinter(x, { margin_mm: Number(e.target.value) })} aria-label={t('printers.margin')} suffix="mm" />
                  <button type="button" onClick={() => void updPrinter(x, { deleted_at: new Date().toISOString() } as Partial<PrinterRow>)} className="mb-1 grid size-8 place-items-center rounded-md text-fg-3 hover:text-danger" aria-label={t('printers.remove', { name: x.name })}>
                    <Trash2 className="size-4" aria-hidden />
                  </button>
                </li>
              ))}
            </ul>
          )}
          <Alert tone="info">{t('printers.direct')}</Alert>
        </div>
      </Panel>
      {data && <Designer key={data.templates.map((x) => x.id).join()} printers={data.printers} templates={data.templates} lastDevice={data.lastDevice} cashbox={data.cashbox} lastVoucher={data.lastVoucher} lastSale={data.lastSale} lastBarcode={data.lastBarcode} branches={br.multi ? br.all : []} onSaved={reload} />}
    </div>
  );
}

function Designer({ printers, templates, lastDevice, cashbox, lastVoucher, lastSale, lastBarcode, branches, onSaved }: { printers: PrinterRow[]; templates: TplRow[]; lastDevice: string | null; cashbox: string | null; lastVoucher: string | null; lastSale: string | null; lastBarcode: string | null; branches: { id: string; name: string }[]; onSaved: () => void }) {
  const { t } = useTranslation();
  const toast = useToast();
  const [doc, setDoc] = useState<TemplateDoc>('receipt');
  const [branch, setBranch] = useState<string>('');
  const current = templates.find((x) => x.doc === doc && x.is_default && (x.branch_id ?? '') === branch) ?? null;
  const [blocks, setBlocks] = useState<Block[]>(() => (current ? normalizeBlocks(doc, current.blocks) : defaultBlocks(doc)));
  const [printer, setPrinter] = useState<string>(current?.printer_id ?? '');
  const [drag, setDrag] = useState<number | null>(null);
  const [v, setV] = useState(0);
  useEffect(() => {
    setBlocks(current ? normalizeBlocks(doc, current.blocks) : defaultBlocks(doc));
    setPrinter(current?.printer_id ?? '');
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [doc, branch, current?.id]);
  // المعاينة الحية: القالب اللي بيتعدّل بيتحفظ مؤقتًا في الجلسة، والإطار بيقراه
  useEffect(() => {
    try {
      sessionStorage.setItem(`tpl-preview:${doc}`, JSON.stringify(blocks));
    } catch {
      /* مفيش تخزين: المعاينة بالقالب المحفوظ */
    }
    const tm = setTimeout(() => setV((x) => x + 1), 250);
    return () => clearTimeout(tm);
  }, [blocks, doc]);
  const pr = printers.find((x) => x.id === printer);
  const widthMm = pr?.width_mm ?? (doc === 'receipt' ? 76 : doc === 'barcode' ? 50 : 210);
  const upd = (i: number, p: Partial<Block>) => setBlocks((bs) => bs.map((b, j) => (j === i ? { ...b, ...p } : b)));
  async function save() {
    const row = { doc, branch_id: branch || null, printer_id: printer || null, name: t(`printers.docs.${doc}`), blocks, is_default: true };
    const { error } = current
      ? await supabase.from('print_templates').update(row).eq('id', current.id)
      : await supabase.from('print_templates').insert({ id: crypto.randomUUID(), shop_id: crypto.randomUUID(), ...row });
    if (error) return toast({ tone: 'danger', title: errorMessage(error) });
    toast({ tone: 'ok', title: t('printers.saved') });
    onSaved();
  }
  async function reset() {
    if (current) {
      const { error } = await supabase.from('print_templates').update({ deleted_at: new Date().toISOString(), is_default: false }).eq('id', current.id);
      if (error) return toast({ tone: 'danger', title: errorMessage(error) });
    }
    setBlocks(defaultBlocks(doc));
    toast({ tone: 'ok', title: t('printers.resetDone') });
    onSaved();
  }
  // الورقة اللي بتتعاين وبتتطبع تجربة: آخر جهاز، وكشف الحساب على أول خزنة
  const sample =
    doc === 'statement'
      ? cashbox
        ? `print/statement/cashbox/${cashbox}`
        : null
      : doc === 'voucher'
        ? lastVoucher
          ? `print/voucher/${lastVoucher}`
          : null
        : doc === 'sale'
          ? lastSale
            ? `print/sale/${lastSale}`
            : null
          : doc === 'barcode'
            ? lastBarcode
              ? `print/barcode/${lastBarcode}`
              : null
        : lastDevice
          ? `print/${doc}/${lastDevice}`
          : null;
  // الملصق: المقاس من الطابعة اللي متختارة دلوقتي (حتى قبل الحفظ)
  const previewUrl = useMemo(
    () => (sample ? `${window.location.pathname}#/${sample}?preview=1&embed=1&v=${v}${doc === 'barcode' ? `&printer=${printer}` : ''}` : null),
    [sample, v, doc, printer],
  );
  return (
    <Panel data-testid="print-designer">
      <PanelHeader title={t('printers.designer')} />
      <div className="grid grid-cols-1 gap-4 p-4 lg:grid-cols-[minmax(0,1fr)_minmax(0,1fr)]">
        <div className="flex min-w-0 flex-col gap-3">
          <div className="grid grid-cols-2 gap-2 sm:grid-cols-3">
            <Field label={t('printers.doc')}>
              <Select value={doc} onChange={(e) => setDoc(e.target.value as TemplateDoc)} data-testid="tpl-doc">
                {DOCS.map((d) => (
                  <option key={d} value={d}>
                    {t(`printers.docs.${d}`)}
                  </option>
                ))}
              </Select>
            </Field>
            <Field label={t('printers.printer')}>
              <Select value={printer} onChange={(e) => setPrinter(e.target.value)} data-testid="tpl-printer">
                <option value="">{t('printers.defaultSize')}</option>
                {printers.map((x) => (
                  <option key={x.id} value={x.id}>
                    {x.name}
                  </option>
                ))}
              </Select>
            </Field>
            {branches.length > 1 && (
              <Field label={t('printers.forBranch')}>
                <Select value={branch} onChange={(e) => setBranch(e.target.value)} data-testid="tpl-branch">
                  <option value="">{t('printers.allBranches')}</option>
                  {branches.map((b) => (
                    <option key={b.id} value={b.id}>
                      {b.name}
                    </option>
                  ))}
                </Select>
              </Field>
            )}
          </div>
          <ul className="flex flex-col gap-1" aria-label={t('printers.blocks')} data-testid="tpl-blocks">
            {blocks.map((b, i) => (
              <li
                key={`${b.key}-${i}`}
                draggable
                onDragStart={() => setDrag(i)}
                onDragOver={(e) => e.preventDefault()}
                onDrop={() => {
                  if (drag != null) setBlocks((bs) => move(bs, drag, i));
                  setDrag(null);
                }}
                className={cn('flex flex-wrap items-center gap-1.5 rounded-md border border-glass-border px-2 py-1 text-sm', !b.show && 'opacity-50', drag === i && 'border-accent')}
                data-testid="tpl-block"
                data-key={b.key}
              >
                <GripVertical className="size-4 cursor-grab text-fg-3" aria-hidden />
                <span className="min-w-0 flex-1 basis-[40%] truncate text-fg">{t(`printers.b.${b.key}`)}</span>
                {b.key === 'text' && <Input value={b.text ?? ''} onChange={(e) => upd(i, { text: e.target.value })} maxLength={300} className="h-7 w-40" aria-label={t('printers.b.text')} />}
                <select value={b.size} onChange={(e) => upd(i, { size: e.target.value as Block['size'] })} aria-label={t('printers.size')} className="h-7 rounded border border-line bg-sunken/60 px-1 text-2xs">
                  {(['sm', 'md', 'lg'] as const).map((z) => (
                    <option key={z} value={z}>
                      {t(`printers.sizes.${z}`)}
                    </option>
                  ))}
                </select>
                <select value={b.align} onChange={(e) => upd(i, { align: e.target.value as Block['align'] })} aria-label={t('printers.align')} className="h-7 rounded border border-line bg-sunken/60 px-1 text-2xs">
                  {(['start', 'center', 'end'] as const).map((z) => (
                    <option key={z} value={z}>
                      {t(`printers.aligns.${z}`)}
                    </option>
                  ))}
                </select>
                <button type="button" onClick={() => upd(i, { bold: !b.bold })} aria-pressed={b.bold} className={cn('h-7 rounded px-1.5 text-2xs font-bold', b.bold ? 'bg-accent-soft text-fg' : 'text-fg-3')} aria-label={t('printers.bold')}>
                  B
                </button>
                <button type="button" onClick={() => upd(i, { show: !b.show })} aria-pressed={b.show} className="grid size-7 place-items-center rounded text-fg-3 hover:text-fg" aria-label={`${b.show ? t('printers.hide') : t('printers.show')} ${t(`printers.b.${b.key}`)}`} data-testid="tpl-toggle">
                  {b.show ? <Eye className="size-4" aria-hidden /> : <EyeOff className="size-4" aria-hidden />}
                </button>
                <button type="button" onClick={() => setBlocks((bs) => move(bs, i, i - 1))} disabled={i === 0} className="grid size-7 place-items-center rounded text-fg-3 hover:text-fg disabled:opacity-30" aria-label={t('printers.up')}>
                  <ArrowUp className="size-3.5" aria-hidden />
                </button>
                <button type="button" onClick={() => setBlocks((bs) => move(bs, i, i + 1))} disabled={i === blocks.length - 1} className="grid size-7 place-items-center rounded text-fg-3 hover:text-fg disabled:opacity-30" aria-label={t('printers.down')}>
                  <ArrowDown className="size-3.5" aria-hidden />
                </button>
                {b.key === 'text' && (
                  <button type="button" onClick={() => setBlocks((bs) => bs.filter((_, j) => j !== i))} className="grid size-7 place-items-center rounded text-fg-3 hover:text-danger" aria-label={t('printers.removeText')}>
                    <Trash2 className="size-3.5" aria-hidden />
                  </button>
                )}
              </li>
            ))}
          </ul>
          <div className="flex flex-wrap gap-2">
            <Button size="sm" variant="ghost" icon={<Plus className="size-4" />} onClick={() => setBlocks((bs) => [...bs, { key: 'text', show: true, size: 'md', align: 'start', bold: false, text: '' }])} data-testid="tpl-add-text">
              {t('printers.addText')}
            </Button>
            <Button size="sm" variant="ghost" icon={<RotateCcw className="size-4" />} needsNet onClick={() => void reset()} data-testid="tpl-reset">
              {t('printers.reset')}
            </Button>
            <Button size="sm" variant="primary" needsNet onClick={() => void save()} data-testid="tpl-save">
              {t('printers.save')}
            </Button>
            {sample && (
              <a href={`#/${sample}`} target="_blank" rel="noopener noreferrer" className="inline-flex h-8 items-center gap-1.5 rounded-md border border-line px-3 text-sm text-fg-2 hover:border-accent" data-testid="tpl-test-print">
                <Printer className="size-4" aria-hidden /> {t('printers.testPrint')}
              </a>
            )}
          </div>
        </div>
        <div className="flex min-w-0 flex-col gap-2">
          <div className="readout-label">{t('printers.preview', { w: widthMm })}</div>
          {previewUrl ? (
            <div className="overflow-auto rounded-md border border-glass-border bg-white p-2">
              <iframe title={t('printers.preview', { w: widthMm })} src={previewUrl} style={{ width: `${widthMm + 10}mm`, height: '160mm', border: 0, background: 'white' }} data-testid="tpl-preview" />
            </div>
          ) : (
            <p className="text-xs text-fg-3">{t('printers.noDevice')}</p>
          )}
        </div>
      </div>
    </Panel>
  );
}
