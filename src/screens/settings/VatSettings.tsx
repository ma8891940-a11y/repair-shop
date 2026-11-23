import { useEffect, useState } from 'react';
import { useTranslation } from 'react-i18next';
import { useMe } from '../../app/auth';
import { saveExtras } from '../../app/shopExtras';
import { errorMessage } from '../../lib/errors';
import { bpToPercent, parsePercentBp, readVat } from '../../lib/vat';
import { Panel, PanelHeader } from '../../ui/Panel';
import { Button } from '../../ui/Button';
import { Checkbox } from '../../ui/Checkbox';
import { Field, Input } from '../../ui/Field';
import { Alert } from '../../ui/Feedback';
import { useToast } from '../../ui/Toast';

/**
 * R5: ضريبة القيمة المضافة (لو المحل مسجّل). السعر شامل الضريبة دايمًا، والقيد بيفصلها لوحده.
 * التغيير بيسري على البيع والتسليم من دلوقتي، والقديم زي ما اتسجّل.
 */
export function VatSettings() {
  const { t } = useTranslation();
  const toast = useToast();
  const { shop, refresh } = useMe();
  const cur = readVat(shop.extras);
  const [on, setOn] = useState(cur.enabled);
  const [rate, setRate] = useState(bpToPercent(cur.rate_bp));
  const [reg, setReg] = useState(cur.reg_no);
  const [err, setErr] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);
  useEffect(() => {
    setOn(cur.enabled);
    setRate(bpToPercent(cur.rate_bp));
    setReg(cur.reg_no);
  }, [cur.enabled, cur.rate_bp, cur.reg_no]);

  async function save() {
    setErr(null);
    const bp = parsePercentBp(rate);
    if (bp == null || (on && bp === 0)) return setErr(t('vat.errRate'));
    if (on && !reg.trim()) return setErr(t('vat.errReg'));
    setBusy(true);
    const { error } = await saveExtras({ vat: { enabled: on, rate_bp: bp, reg_no: reg.trim().slice(0, 40) } });
    setBusy(false);
    if (error) return setErr(errorMessage(error));
    await refresh();
    toast({ tone: 'ok', title: t('settings.saved') });
  }

  return (
    <Panel data-testid="vat-settings">
      <PanelHeader title={t('vat.title')} />
      <div className="flex flex-col gap-3 p-4">
        <p className="text-xs text-fg-3">{t('vat.hint')}</p>
        <Checkbox checked={on} onChange={setOn} label={t('vat.enable')} />
        <div className="flex flex-wrap items-end gap-3">
          <Field label={t('vat.rate')}>
            <Input mono inputMode="decimal" value={rate} onChange={(e) => setRate(e.target.value)} suffix="%" className="w-24" disabled={!on} data-testid="vat-rate" />
          </Field>
          <Field label={t('vat.reg')} hint={t('vat.regHint')}>
            <Input mono dir="ltr" value={reg} onChange={(e) => setReg(e.target.value)} maxLength={40} className="w-48" disabled={!on} data-testid="vat-reg" />
          </Field>
          <Button variant="primary" loading={busy} needsNet onClick={() => void save()} className="mb-5" data-testid="vat-save">
            {t('common.save')}
          </Button>
        </div>
        {err && <Alert tone="danger">{err}</Alert>}
      </div>
    </Panel>
  );
}
