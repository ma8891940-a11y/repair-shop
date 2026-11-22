import { useEffect, useState } from 'react';
import { useTranslation } from 'react-i18next';
import { supabase } from '../lib/supabase';
import { errorMessage } from '../lib/errors';
import { normalizeEgyptPhone } from '../lib/phone';
import { parseCsv } from '../lib/csv';
import { chunks, parseCustomersCsv, type CustomerImportResult } from '../lib/customersCsv';
import { Button } from '../ui/Button';
import { Dialog } from '../ui/Dialog';
import { Alert } from '../ui/Feedback';
import { useToast } from '../ui/Toast';
import { cn } from '../ui/cn';

const PREVIEW = 50;

/** أرقام عملاء المحل الموجودين من بين أرقام الملف (على دفعات، من غير ما نحمّل كل العملاء) */
async function existingPhones(text: string): Promise<Set<string>> {
  return lookupPhones([...new Set(parseCsv(text).flatMap((r) => r.map((c) => normalizeEgyptPhone(c)).filter((x): x is string => !!x)))]);
}

/** الأرقام دي، أنهي منها متسجّل فعلًا لعميل في المحل */
async function lookupPhones(phones: string[]): Promise<Set<string>> {
  const out = new Set<string>();
  for (const part of chunks(phones, 200)) {
    const { data, error } = await supabase.from('customers').select('phone').in('phone', part).is('deleted_at', null);
    if (error) throw error;
    for (const r of (data ?? []) as { phone: string }[]) out.add(r.phone);
  }
  return out;
}

/** R3: استيراد العملاء من Excel (CSV): معاينة بالسليم والغلط والمكرر، وبعدين الحفظ على دفعات (100 في المرة) */
export function CustomersImportDialog({ open, onOpenChange, onDone }: { open: boolean; onOpenChange: (v: boolean) => void; onDone: () => void }) {
  const { t } = useTranslation();
  const toast = useToast();
  const [res, setRes] = useState<CustomerImportResult | null>(null);
  const [reading, setReading] = useState(false);
  const [busy, setBusy] = useState(false);
  const [err, setErr] = useState<string | null>(null);
  useEffect(() => {
    setRes(null);
    setErr(null);
  }, [open]);

  async function read(file: File) {
    setErr(null);
    setRes(null);
    setReading(true);
    try {
      const text = await file.text();
      setRes(parseCustomersCsv(text, await existingPhones(text)));
    } catch (e) {
      setErr(errorMessage(e));
    } finally {
      setReading(false);
    }
  }

  async function save() {
    if (!res?.rows.length) return;
    setBusy(true);
    setErr(null);
    let done = 0;
    let fail: string | null = null;
    // shop_id أي UUID: قاعدة البيانات بتحط المحل الصح (نفس إضافة العميل من الاستلام)
    for (const part of chunks(res.rows, 100)) {
      const rows = part.map((r) => ({
        id: crypto.randomUUID(),
        shop_id: crypto.randomUUID(),
        name: r.name,
        phone: r.phone,
        area: r.area,
      }));
      const { error } = await supabase.from('customers').insert(rows);
      if (error) {
        fail = errorMessage(error);
        break;
      }
      done += rows.length;
    }
    setBusy(false);
    if (done > 0) onDone();
    if (fail) {
      setErr(done ? t('custImport.partial', { n: done, why: fail }) : fail);
      // اللي اتحفظ ما يتبعتش تاني لو داس استيراد تاني. واللي اتسجّل في النص (مستخدم تاني، أو حفظ وصل والرد ضاع)
      // بيتشال من الباقي ويتعلّم "موجود"، عشان المحاولة التانية تنجح
      const left = res.rows.slice(done);
      let now = new Set<string>();
      try {
        now = await lookupPhones(left.map((r) => r.phone));
      } catch {
        now = new Set();
      }
      setRes({
        ...res,
        rows: left.filter((r) => !now.has(r.phone)),
        errors: [...res.errors, ...left.filter((r) => now.has(r.phone)).map((r) => ({ line: r.line, reason: 'exists' as const, name: r.name, phone: r.phone }))],
      });
      return;
    }
    toast({ tone: 'ok', title: t('custImport.done', { n: done }) });
    onOpenChange(false);
  }

  const bad = res ? res.errors.filter((e) => e.reason === 'name' || e.reason === 'phone').length : 0;
  const dup = res ? res.errors.length - bad : 0;
  const preview = res
    ? [
        ...res.rows.map((r) => ({
          line: r.line,
          name: r.name,
          phone: r.phone,
          why: null as string | null,
        })),
        ...res.errors.map((e) => ({
          line: e.line,
          name: e.name,
          phone: e.phone,
          why: e.reason as string,
        })),
      ].sort((a, b) => a.line - b.line)
    : [];

  return (
    <Dialog
      open={open}
      onOpenChange={onOpenChange}
      title={t('custImport.title')}
      description={t('custImport.hint')}
      className="max-w-2xl"
      footer={
        <>
          <Button variant="ghost" onClick={() => onOpenChange(false)}>
            {t('common.cancel')}
          </Button>
          <Button variant="primary" needsNet loading={busy} disabled={!res?.rows.length || reading} onClick={() => void save()} data-testid="cimport-save">
            {t('custImport.save', { n: res?.rows.length ?? 0 })}
          </Button>
        </>
      }
    >
      <div className="flex flex-col gap-3">
        <input
          type="file"
          disabled={busy}
          accept=".csv,text/csv"
          aria-label={t('custImport.file')}
          onChange={(e) => e.target.files?.[0] && void read(e.target.files[0])}
          className="text-sm text-fg-2 file:me-3 file:rounded-md file:border file:border-line file:bg-raised file:px-3 file:py-1.5 file:text-fg"
          data-testid="cimport-file"
        />
        {res && res.missingHeaders.length > 0 && (
          <Alert tone="danger">
            {t('custImport.missing', {
              cols: res.missingHeaders.map((c) => t(`customers.cols.${c}`)).join(' / '),
            })}
          </Alert>
        )}
        {res && res.missingHeaders.length === 0 && (
          <div className="flex flex-col gap-2" data-testid="cimport-preview">
            <div className="flex flex-wrap gap-x-4 gap-y-1 text-sm">
              <span className="text-fg" data-testid="cimport-ok">
                {t('custImport.ok', { n: res.rows.length })}
              </span>
              <span className={cn(bad ? 'text-danger' : 'text-fg-3')} data-testid="cimport-bad">
                {t('custImport.bad', { n: bad })}
              </span>
              <span className="text-fg-3" data-testid="cimport-dup">
                {t('custImport.dup', { n: dup })}
              </span>
            </div>
            {preview.length > 0 && (
              <div className="max-h-72 overflow-auto rounded-md border border-line">
                <table className="w-full text-sm [&_td]:px-3 [&_td]:py-1.5 [&_th]:px-3 [&_th]:py-1.5 [&_th]:text-start [&_th]:font-medium">
                  <thead className="sticky top-0 bg-surface text-2xs text-fg-3">
                    <tr>
                      <th>{t('custImport.line')}</th>
                      <th>{t('customers.cols.name')}</th>
                      <th>{t('customers.cols.phone')}</th>
                      <th>{t('custImport.status')}</th>
                    </tr>
                  </thead>
                  <tbody className="divide-y divide-line">
                    {preview.slice(0, PREVIEW).map((x) => (
                      <tr key={x.line} data-testid="cimport-row" data-state={x.why ?? 'ok'}>
                        <td className="num text-fg-3">{x.line}</td>
                        <td>
                          <bdi>{x.name}</bdi>
                        </td>
                        <td className="num" dir="ltr">
                          {x.phone}
                        </td>
                        <td className={cn('text-xs', !x.why ? 'text-ok' : x.why === 'name' || x.why === 'phone' ? 'text-danger' : 'text-fg-3')}>
                          {x.why ? t(`custImport.why.${x.why}`) : t('custImport.ready')}
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
                {preview.length > PREVIEW && <p className="px-3 py-2 text-xs text-fg-3">{t('custImport.more', { n: preview.length - PREVIEW })}</p>}
              </div>
            )}
          </div>
        )}
        {err && <Alert tone="danger">{err}</Alert>}
      </div>
    </Dialog>
  );
}
