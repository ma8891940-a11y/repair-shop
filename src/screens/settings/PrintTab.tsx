import { useEffect, useRef, useState } from 'react';
import { useTranslation } from 'react-i18next';
import { Ruler } from 'lucide-react';
import { useMe } from '../../app/auth';
import { supabase } from '../../lib/supabase';
import { errorMessage } from '../../lib/errors';
import { toLatinDigits } from '../../lib/digits';
import { ACTIONS, readPrint, readSticker, STICKER_PRESETS, type PrintAction, type PrintSettings, type StickerSettings } from '../../lib/printPlan';
import { StickerLabel } from '../../app/print/StickerLabel';
import { printInFrame } from '../../app/print/PrintSendPanel';
import { Panel, PanelHeader } from '../../ui/Panel';
import { Checkbox } from '../../ui/Checkbox';
import { Field, Input } from '../../ui/Field';
import { Alert } from '../../ui/Feedback';
import { Button } from '../../ui/Button';
import { useToast } from '../../ui/Toast';
import { cn } from '../../ui/cn';

/**
 * الإعدادات ← الطباعة: اللي بيتعمل تلقائي بعد الاستلام، ومقاس الاستيكر (جاهز أو باليد) والإطار والإزاحة والنسخ،
 * ومعاينة حية بالمقاس الحقيقي، و"طباعة اختبار". الطابعة نفسها بتتختار من نافذة الطباعة.
 */
export function PrintTab() {
  const { t } = useTranslation();
  const { shop, refresh } = useMe();
  const toast = useToast();
  const p = readPrint(shop.extras);
  const [st, setSt] = useState<StickerSettings>(p.sticker);
  const [w, setW] = useState(String(p.sticker.w));
  const [h, setH] = useState(String(p.sticker.h));
  // رد حفظ قديم ما يكتبش فوق اللي المستخدم لسه غيّره: مفيش مزامنة من السيرفر والحفظ شغال أو المقاس بيتكتب
  const pending = useRef(0);
  const editingSize = useRef(false);
  useEffect(() => {
    if (pending.current > 0) return;
    setSt(p.sticker);
    if (!editingSize.current) {
      setW(String(p.sticker.w));
      setH(String(p.sticker.h));
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [JSON.stringify(p.sticker)]);

  // الحفظ بالترتيب: كل حفظ بيستنى اللي قبله، عشان حفظ قديم ما يوصلش متأخر ويكتب فوق الأحدث
  const queue = useRef<Promise<void>>(Promise.resolve());
  function save(patch: Partial<PrintSettings>) {
    const run = queue.current.then(() => saveNow(patch));
    queue.current = run.catch(() => undefined);
    return run;
  }
  async function saveNow(patch: Partial<PrintSettings>) {
    const ex = (shop.extras && typeof shop.extras === 'object' ? shop.extras : {}) as Record<string, unknown>;
    const prev = (ex.print && typeof ex.print === 'object' ? ex.print : {}) as Record<string, unknown>;
    const next = { ...prev, deliveryPaper: p.deliveryPaper, auto: p.auto, sticker: st, ...patch };
    const anyAuto = ACTIONS.some((a) => next.auto[a as PrintAction]);
    pending.current += 1;
    try {
      const { error } = await supabase.from('shops').update({ extras: { ...ex, print: next, auto_print: anyAuto } }).eq('id', shop.id);
      if (error) return toast({ tone: 'danger', title: errorMessage(error) });
      await refresh();
    } finally {
      pending.current -= 1;
    }
    toast({ tone: 'ok', title: t('settings.saved') });
  }
  const saveSticker = (s: Partial<StickerSettings>) => {
    const v = readSticker({ ...st, ...s });
    setSt(v);
    void save({ sticker: v });
  };
  const mm = (v: string) => Number(toLatinDigits(v.replace(',', '.')));

  return (
    <div className="flex flex-col gap-4" data-testid="print-settings">
      <Panel>
        <PanelHeader index="01" title={t('printSet.autoTitle')} />
        <div className="flex flex-col gap-3 p-4">
          <p className="text-xs text-fg-3">{t('printSet.autoHint')}</p>
          <div className="grid gap-2 sm:grid-cols-2">
            {ACTIONS.map((a) => (
              <Checkbox key={a} checked={p.auto[a]} onChange={(v) => void save({ auto: { ...p.auto, [a]: v } })} label={t(`printSend.actions.${a}`)} />
            ))}
          </div>
          <div className="border-t border-glass-border pt-3">
            <Checkbox checked={p.deliveryPaper} onChange={(v) => void save({ deliveryPaper: v })} label={t('printSet.invoice')} />
            <p className="ms-7 mt-0.5 text-2xs text-fg-3">{t('printSet.invoiceHint')}</p>
          </div>
        </div>
      </Panel>

      <Panel>
        <PanelHeader index="02" title={t('printSet.stickerTitle')} />
        <div className="grid gap-4 p-4 lg:grid-cols-[minmax(0,1fr)_auto]">
          <div className="flex flex-col gap-3">
            <div className="flex flex-wrap gap-1.5" role="group" aria-label={t('printSet.presets')}>
              {STICKER_PRESETS.map(([pw, ph]) => {
                const on = st.w === pw && st.h === ph;
                return (
                  <button
                    key={`${pw}x${ph}`}
                    type="button"
                    aria-pressed={on}
                    onClick={() => {
                      editingSize.current = false;
                      setW(String(pw));
                      setH(String(ph));
                      saveSticker({ w: pw, h: ph });
                    }}
                    className={cn('num h-8 rounded-md border px-2.5 text-xs', on ? 'border-[rgb(var(--accent-rgb)/0.6)] bg-accent-soft text-accent' : 'border-line text-fg-2 hover:text-fg')}
                    data-testid={`preset-${pw}x${ph}`}
                    dir="ltr"
                  >
                    {pw}×{ph}
                  </button>
                );
              })}
            </div>
            <form
              className="flex flex-wrap items-end gap-2"
              onSubmit={(e) => {
                e.preventDefault();
                editingSize.current = false;
                saveSticker({ w: mm(w), h: mm(h) });
              }}
            >
              <Field label={t('printSet.width')}>
                <Input value={w} onChange={(e) => ((editingSize.current = true), setW(e.target.value))} inputMode="decimal" mono className="w-24" dir="ltr" data-testid="sticker-w" />
              </Field>
              <Field label={t('printSet.height')}>
                <Input value={h} onChange={(e) => ((editingSize.current = true), setH(e.target.value))} inputMode="decimal" mono className="w-24" dir="ltr" data-testid="sticker-h" />
              </Field>
              <Field label={t('printSet.copies')}>
                <Input value={String(st.copies)} onChange={(e) => saveSticker({ copies: mm(e.target.value) || 1 })} inputMode="numeric" mono className="w-20" dir="ltr" data-testid="sticker-copies" />
              </Field>
              <Button type="submit" variant="primary" needsNet>
                {t('printSet.applySize')}
              </Button>
            </form>
            <Checkbox checked={st.frame} onChange={(v) => saveSticker({ frame: v })} label={t('printSet.frame')} />
            <div className="flex flex-wrap items-end gap-2">
              <Field label={t('printSet.dx')}>
                <Input defaultValue={String(st.dx)} key={`dx${st.dx}`} onBlur={(e) => saveSticker({ dx: mm(e.target.value) || 0 })} inputMode="decimal" mono className="w-24" dir="ltr" data-testid="sticker-dx" />
              </Field>
              <Field label={t('printSet.dy')}>
                <Input defaultValue={String(st.dy)} key={`dy${st.dy}`} onBlur={(e) => saveSticker({ dy: mm(e.target.value) || 0 })} inputMode="decimal" mono className="w-24" dir="ltr" data-testid="sticker-dy" />
              </Field>
              <Button icon={<Ruler className="size-4" />} onClick={() => void printInFrame('/print/sticker-test/test?embed=1')} data-testid="sticker-test-print">
                {t('printSet.testPrint')}
              </Button>
            </div>
            <Alert tone="info">{t('sticker.printerNote')}</Alert>
          </div>
          {/* معاينة حية بالمقاس الحقيقي */}
          <div className="flex flex-col items-center gap-2">
            <span className="text-2xs text-fg-3">{t('printSet.preview', { w: st.w, h: st.h })}</span>
            <div className="rounded-md bg-white p-3 shadow-1" data-testid="sticker-preview">
              <StickerLabel
                st={{ ...st, frame: true }}
                testid="preview-sticker"
                data={{ no: '2026-0042', name: t('printSet.sampleName'), phone: '01012345678', issue: t('printSet.sampleIssue'), cost: 150_000, paid: 50_000, date: new Date() }}
              />
            </div>
          </div>
        </div>
      </Panel>
    </div>
  );
}
