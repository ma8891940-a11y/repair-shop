import { useState } from 'react';
import { useTranslation } from 'react-i18next';
import { FlaskConical, Trash2 } from 'lucide-react';
import { useLoad } from '../../app/useLoad';
import { rpc } from '../../app/ledgerApi';
import { errorMessage } from '../../lib/errors';
import { Panel, PanelHeader } from '../../ui/Panel';
import { Button } from '../../ui/Button';
import { Dialog } from '../../ui/Dialog';
import { Alert, Skeleton } from '../../ui/Feedback';
import { useToast } from '../../ui/Toast';

/** C7: الإعدادات ← النسخ الاحتياطي: "جرّب ببيانات تجريبية" (محل فاضي بس) و"امسح بيانات التجربة" (بقيود عكسية وأرشفة) */
export function DemoPanel() {
  const { t } = useTranslation();
  const toast = useToast();
  const { data: state, reload } = useLoad(async () => ((await rpc('demo_state')) as string) ?? 'none', []);
  const [confirm, setConfirm] = useState(false);
  const [busy, setBusy] = useState(false);
  const [err, setErr] = useState<string | null>(null);
  async function run(fn: 'load_demo' | 'clear_demo') {
    setErr(null);
    setBusy(true);
    try {
      await rpc(fn);
      toast({ tone: 'ok', title: fn === 'load_demo' ? t('demo.loaded') : t('demo.cleared') });
      setConfirm(false);
      reload();
    } catch (e) {
      setErr(errorMessage(e));
    } finally {
      setBusy(false);
    }
  }
  return (
    <Panel data-testid="demo-panel">
      <PanelHeader title={t('demo.title')} />
      <div className="flex flex-col gap-3 p-4">
        <p className="text-xs text-fg-3">{t('demo.hint')}</p>
        {!state ? (
          <Skeleton className="h-9 w-48" />
        ) : state === 'loaded' ? (
          <Button variant="secondary" onClick={() => setConfirm(true)} icon={<Trash2 className="size-4" />} className="self-start" data-testid="demo-clear">
            {t('demo.clear')}
          </Button>
        ) : state === 'none' ? (
          <Button variant="secondary" loading={busy} onClick={() => void run('load_demo')} icon={<FlaskConical className="size-4" />} className="self-start" data-testid="demo-load">
            {t('demo.try')}
          </Button>
        ) : (
          <p className="text-sm text-fg-2" data-testid="demo-done">
            {t('demo.wasCleared')}
          </p>
        )}
        {err && <Alert tone="danger">{err}</Alert>}
      </div>
      <Dialog
        open={confirm}
        onOpenChange={setConfirm}
        title={t('demo.clear')}
        description={t('demo.clearText')}
        footer={
          <>
            <Button variant="ghost" onClick={() => setConfirm(false)}>
              {t('common.cancel')}
            </Button>
            <Button variant="primary" needsNet loading={busy} onClick={() => void run('clear_demo')} data-testid="demo-clear-confirm">
              {t('demo.clear')}
            </Button>
          </>
        }
      />
    </Panel>
  );
}
