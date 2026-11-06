import { useState } from 'react';
import { useTranslation } from 'react-i18next';
import { CloudOff, RefreshCw, TriangleAlert, Wifi } from 'lucide-react';
import { useSync } from '../offline/sync';
import { failedItems, localDb, type OutboxItem } from '../offline/outbox';
import { errorMessage } from '../lib/errors';
import { useFormat } from '../i18n/format';
import { Dialog } from '../ui/Dialog';
import { Button } from '../ui/Button';
import { cn } from '../ui/cn';

/** مؤشر الاتصال في الشريط العلوي: متصل، أو بدون نت، أو بانتظار المزامنة (وعدد العمليات)، أو فيه عمليات اترفضت */
export function ConnectionBadge({ live }: { live: boolean }) {
  const { t } = useTranslation();
  const f = useFormat();
  const { online, pending, failed, syncing, syncNow, retry } = useSync();
  const [open, setOpen] = useState(false);
  const [items, setItems] = useState<OutboxItem[]>([]);
  const state = !online ? 'offline' : failed > 0 ? 'failed' : pending > 0 ? 'pending' : 'online';
  const Icon = state === 'offline' ? CloudOff : state === 'failed' ? TriangleAlert : state === 'pending' ? RefreshCw : Wifi;
  const label =
    state === 'offline' ? t('sync.offline', { n: pending }) : state === 'failed' ? t('sync.failed', { n: failed }) : state === 'pending' ? t('sync.pending', { n: pending }) : live ? t('common.live') : t('sync.online');
  return (
    <>
      <button
        type="button"
        onClick={async () => {
          setItems(await failedItems(localDb()));
          setOpen(true);
        }}
        className={cn(
          'inline-flex h-7 items-center gap-1.5 rounded-full border px-2.5 text-2xs',
          state === 'offline' ? 'border-[color-mix(in_srgb,var(--warn)_50%,transparent)] text-warn' : state === 'failed' ? 'border-[color-mix(in_srgb,var(--danger)_50%,transparent)] text-danger' : state === 'pending' ? 'border-accent text-accent' : 'border-glass-border text-fg-3',
        )}
        data-testid="connection"
        data-state={state}
        aria-live="polite"
      >
        <Icon className={cn('size-3.5', syncing && 'animate-spin')} aria-hidden />
        {label}
      </button>
      <Dialog
        open={open}
        onOpenChange={setOpen}
        title={t('sync.title')}
        description={t(`sync.desc.${state}`)}
        footer={
          <>
            {failed > 0 && (
              <Button onClick={() => void retry().then(() => setOpen(false))} icon={<RefreshCw className="size-4" />}>
                {t('sync.retry')}
              </Button>
            )}
            <Button variant="primary" disabled={!online || syncing} onClick={() => void syncNow()} icon={<RefreshCw className="size-4" />}>
              {t('sync.now')}
            </Button>
          </>
        }
      >
        <div className="flex flex-col gap-2 text-sm">
          <p className="text-fg-2">{t('sync.pendingLine', { n: pending })}</p>
          {items.length > 0 && (
            <ul className="divide-y divide-glass-border rounded-md border border-glass-border">
              {items.map((i) => (
                <li key={i.id} className="px-3 py-2">
                  <div className="text-fg">
                    {t(`sync.kinds.${i.kind}`)} · <span className="text-2xs text-fg-3">{f.dateTime(i.createdAt)}</span>
                  </div>
                  <div className="text-2xs text-danger">{errorMessage(i.lastError ?? '')}</div>
                </li>
              ))}
            </ul>
          )}
        </div>
      </Dialog>
    </>
  );
}
