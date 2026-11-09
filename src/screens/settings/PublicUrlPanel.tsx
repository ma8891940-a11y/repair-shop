import { useState } from 'react';
import { useTranslation } from 'react-i18next';
import { useMe } from '../../app/auth';
import { supabase } from '../../lib/supabase';
import { errorMessage } from '../../lib/errors';
import { cleanBase, readPublicUrl, urlProblem } from '../../lib/publicUrl';
import { trackingUrl } from '../../lib/messages';
import { Panel, PanelHeader } from '../../ui/Panel';
import { Field, Input } from '../../ui/Field';
import { Alert } from '../../ui/Feedback';
import { Button } from '../../ui/Button';
import { useToast } from '../../ui/Toast';

/**
 * البند 12: "رابط البرنامج العام": العنوان اللي البرنامج مرفوع عليه (https). منه بتتعمل روابط التتبع
 * في رسايل واتساب والـ QR على الإيصال والاستيكر. لو البرنامج مفتوح من localhost ومفيش رابط عام، بيظهر تنبيه.
 */
export function PublicUrlPanel() {
  const { t } = useTranslation();
  const { shop, refresh } = useMe();
  const toast = useToast();
  const saved = readPublicUrl(shop.extras);
  const [v, setV] = useState(saved);
  const [busy, setBusy] = useState(false);
  const current = cleanBase(window.location.href);
  const currentProblem = urlProblem(current);
  const typedProblem = v.trim() ? urlProblem(v) : null;
  async function save() {
    if (v.trim() && typedProblem) return;
    setBusy(true);
    const ex = (shop.extras && typeof shop.extras === 'object' ? shop.extras : {}) as Record<string, unknown>;
    const { error } = await supabase.from('shops').update({ extras: { ...ex, public_url: v.trim() ? cleanBase(v) : null } }).eq('id', shop.id);
    setBusy(false);
    if (error) return toast({ tone: 'danger', title: errorMessage(error) });
    await refresh();
    toast({ tone: 'ok', title: t('settings.saved') });
  }
  const base = saved || current;
  return (
    <Panel data-testid="public-url">
      <PanelHeader title={t('publicUrl.title')} />
      <div className="flex flex-col gap-3 p-4">
        <p className="text-xs text-fg-3">{t('publicUrl.hint')}</p>
        {!saved && currentProblem && (
          <div data-testid="public-url-warn">
            <Alert tone="warn" title={t('publicUrl.warnTitle')}>
              {t(`publicUrl.problem.${currentProblem}`, { url: current })} {t('publicUrl.warnFix')}
            </Alert>
          </div>
        )}
        <form
          className="flex flex-wrap items-end gap-2"
          onSubmit={(e) => {
            e.preventDefault();
            void save();
          }}
        >
          <Field label={t('publicUrl.label')} error={typedProblem ? t(`publicUrl.problem.${typedProblem}`, { url: v.trim() }) : undefined} className="min-w-[260px] flex-1">
            <Input value={v} onChange={(e) => setV(e.target.value)} placeholder="https://gawalak.pages.dev" dir="ltr" inputMode="url" data-testid="public-url-input" />
          </Field>
          <Button type="submit" variant="primary" loading={busy} disabled={!!typedProblem}>
            {t('publicUrl.save')}
          </Button>
        </form>
        <p className="text-2xs text-fg-3">
          {t('publicUrl.example')}{' '}
          <span className="num" dir="ltr" data-testid="public-url-example">
            {trackingUrl(base, '…')}
          </span>
        </p>
      </div>
    </Panel>
  );
}
