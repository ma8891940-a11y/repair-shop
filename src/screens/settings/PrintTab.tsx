import { useTranslation } from 'react-i18next';
import { useMe } from '../../app/auth';
import { supabase } from '../../lib/supabase';
import { errorMessage } from '../../lib/errors';
import { readPrint, type PrintSettings, type StickerSize } from '../../lib/printPlan';
import { Panel, PanelHeader } from '../../ui/Panel';
import { Checkbox } from '../../ui/Checkbox';
import { Field, Select } from '../../ui/Field';
import { useToast } from '../../ui/Toast';
import { cn } from '../../ui/cn';

/**
 * الإعدادات ← الطباعة: يطبع إيه في كل خطوة. الافتراضي: الاستيكر الحراري في الاستلام بس، والورقي في الاستلام والتسليم.
 * الطابعة نفسها بتتختار من نافذة الطباعة (كل مستند بمقاسه: الحراري 80مم أو ملصق، والورقي A4)، والمتصفح بيفتكر آخر اختيار.
 */
export function PrintTab() {
  const { t } = useTranslation();
  const { shop, refresh } = useMe();
  const toast = useToast();
  const p = readPrint(shop.extras);
  async function set(patch: Partial<PrintSettings>) {
    const ex = (shop.extras && typeof shop.extras === 'object' ? shop.extras : {}) as Record<string, unknown>;
    const next = { ...p, ...patch };
    // "اطبع تلقائي" هو نفس مفتاح الإضافات القديم: بيتحفظ في المكانين عشان الاتنين يفضلوا متطابقين
    const { error } = await supabase.from('shops').update({ extras: { ...ex, print: next, auto_print: next.autoAfterIntake } }).eq('id', shop.id);
    if (error) return toast({ tone: 'danger', title: errorMessage(error) });
    await refresh();
    toast({ tone: 'ok', title: t('settings.saved') });
  }
  const box = (k: keyof PrintSettings, label: string, hint: string) => (
    <div>
      <Checkbox checked={p[k] as boolean} onChange={(v) => void set({ [k]: v })} label={label} />
      <p className="ms-7 mt-0.5 text-2xs text-fg-3">{hint}</p>
    </div>
  );
  return (
    <div className="flex flex-col gap-4" data-testid="print-settings">
      <Panel>
        <PanelHeader index="01" title={t('printSet.intake')} />
        <div className="flex flex-col gap-4 p-4">
          {box('intakeSticker', t('printSet.sticker'), t('printSet.stickerHint'))}
          <div className={cn('ms-7 max-w-xs', !p.intakeSticker && 'opacity-60')}>
            <Field label={t('printSet.size')}>
              <Select value={p.stickerSize} onChange={(e) => void set({ stickerSize: e.target.value as StickerSize })} data-testid="sticker-size">
                <option value="80">{t('printSet.sizes.80')}</option>
                <option value="50x30">{t('printSet.sizes.50x30')}</option>
                <option value="58x40">{t('printSet.sizes.58x40')}</option>
              </Select>
            </Field>
          </div>
          {box('intakePaper', t('printSet.paperReceipt'), t('printSet.paperReceiptHint'))}
          {box('intakeThermal', t('printSet.thermalReceipt'), t('printSet.thermalReceiptHint'))}
          {box('autoAfterIntake', t('printSet.auto'), t('printSet.autoHint'))}
        </div>
      </Panel>
      <Panel>
        <PanelHeader index="02" title={t('printSet.delivery')} />
        <div className="flex flex-col gap-4 p-4">{box('deliveryPaper', t('printSet.invoice'), t('printSet.invoiceHint'))}</div>
      </Panel>
      <p className="text-xs text-fg-3">{t('printSet.printerNote')}</p>
    </div>
  );
}
