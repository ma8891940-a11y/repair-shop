import { useState } from 'react';
import { useTranslation } from 'react-i18next';
import { ArrowLeftRight, Building2, PackageCheck, X } from 'lucide-react';
import { useBranch } from './branch';
import { rpc } from './ledgerApi';
import { errorMessage } from '../lib/errors';
import type { Device } from '../lib/types';
import { Panel } from '../ui/Panel';
import { Button } from '../ui/Button';
import { Dialog } from '../ui/Dialog';
import { Field, Select } from '../ui/Field';
import { Alert } from '../ui/Feedback';
import { useToast } from '../ui/Toast';

/**
 * B: فرع الجهاز، و"ابعت لفرع" (الجهاز بيفضل في فرعه لحد ما الفرع التاني يستلمه)، واستلام أو إلغاء الإرسال.
 * بيظهر بس لو المحل فيه أكتر من فرع.
 */
export function DeviceBranchPanel({ device, onChanged }: { device: Device; onChanged: () => void }) {
  const { t } = useTranslation();
  const br = useBranch();
  const toast = useToast();
  const [open, setOpen] = useState(false);
  const [to, setTo] = useState('');
  const [busy, setBusy] = useState(false);
  const [err, setErr] = useState<string | null>(null);
  if (!br.multi || !device.branch_id) return null;
  const others = br.all.filter((b) => b.id !== device.branch_id);
  const canReceive = !!device.transfer_to && br.mine.some((b) => b.id === device.transfer_to);
  const delivered = device.status === 'delivered';

  async function act(fn: string, args: Record<string, unknown>, ok: string) {
    setBusy(true);
    setErr(null);
    try {
      await rpc(fn, args);
      toast({ tone: 'ok', title: ok });
      setOpen(false);
      onChanged();
    } catch (e) {
      const m = errorMessage(e);
      if (open) setErr(m);
      else toast({ tone: 'danger', title: m });
    } finally {
      setBusy(false);
    }
  }

  return (
    <Panel className="flex flex-wrap items-center gap-2 p-3" data-testid="device-branch">
      <Building2 className="size-4 text-fg-3" aria-hidden />
      <span className="text-sm text-fg">{br.name(device.branch_id)}</span>
      {device.transfer_to ? (
        <>
          <span className="rounded-sm border border-[color-mix(in_srgb,var(--warn)_40%,transparent)] px-1.5 py-px text-2xs text-warn" data-testid="device-in-transit">
            {t('branch.inTransit', { name: br.name(device.transfer_to) })}
          </span>
          <span className="ms-auto flex gap-1.5">
            {canReceive && (
              <Button size="sm" variant="primary" icon={<PackageCheck className="size-4" />} loading={busy} needsNet onClick={() => void act('receive_device', { p_device: device.id }, t('branch.received', { name: br.name(device.transfer_to) }))} data-testid="device-receive">
                {t('branch.receive')}
              </Button>
            )}
            <Button size="sm" variant="ghost" icon={<X className="size-4" />} loading={busy} needsNet onClick={() => void act('cancel_device_transfer', { p_device: device.id }, t('branch.cancelled'))} data-testid="device-transfer-cancel">
              {t('branch.cancelTransfer')}
            </Button>
          </span>
        </>
      ) : (
        !delivered &&
        others.length > 0 && (
          <Button
            size="sm"
            variant="outline"
            className="ms-auto"
            icon={<ArrowLeftRight className="size-4" />}
            needsNet
            onClick={() => {
              setTo(others[0].id);
              setErr(null);
              setOpen(true);
            }}
            data-testid="device-send"
          >
            {t('branch.send')}
          </Button>
        )
      )}
      <Dialog
        open={open}
        onOpenChange={setOpen}
        title={t('branch.sendTo')}
        description={t('branch.sendHint')}
        guard={false}
        footer={
          <>
            <Button variant="ghost" onClick={() => setOpen(false)}>
              {t('common.cancel')}
            </Button>
            <Button variant="primary" loading={busy} needsNet disabled={!to} onClick={() => void act('send_device', { p_device: device.id, p_to: to }, t('branch.sent', { name: br.name(to) }))} data-testid="device-send-confirm">
              {t('branch.send')}
            </Button>
          </>
        }
      >
        <div className="flex flex-col gap-3">
          <Field label={t('branch.to')}>
            <Select value={to} onChange={(e) => setTo(e.target.value)} data-testid="device-send-to">
              {others.map((b) => (
                <option key={b.id} value={b.id}>
                  {b.name}
                </option>
              ))}
            </Select>
          </Field>
          {err && <Alert tone="danger">{err}</Alert>}
        </div>
      </Dialog>
    </Panel>
  );
}
