import { useLayoutEffect, useState } from 'react';
import { useTranslation } from 'react-i18next';
import { Building2, Pencil, Plus } from 'lucide-react';
import { useBranch, type Branch } from '../../app/branch';
import { opId, rpc } from '../../app/ledgerApi';
import { useLoad } from '../../app/useLoad';
import { supabase } from '../../lib/supabase';
import { errorMessage } from '../../lib/errors';
import { Panel, PanelHeader } from '../../ui/Panel';
import { Button } from '../../ui/Button';
import { Dialog } from '../../ui/Dialog';
import { Field, Input } from '../../ui/Field';
import { Alert } from '../../ui/Feedback';
import { useToast } from '../../ui/Toast';

/**
 * الإعدادات ← الفروع (صاحب المحل): إضافة فرع ببادئة لأرقام الطلبات، وتعديله، وقفله.
 * الفرع الجديد بيتعمله خزنة لكل طريقة دفع. والقفل مش حذف: بياناته وقيوده بتفضل.
 */
export function BranchesTab() {
  const { t } = useTranslation();
  const b = useBranch();
  const toast = useToast();
  const [edit, setEdit] = useState<Branch | 'new' | null>(null);
  const [closing, setClosing] = useState<Branch | null>(null);
  const [busy, setBusy] = useState(false);
  const year = new Date().getFullYear();
  const stats = useLoad(async () => {
    const [cb, dv] = await Promise.all([
      supabase.from('accounts').select('branch_id').eq('kind', 'cash').eq('active', true).is('deleted_at', null),
      supabase.from('devices').select('branch_id').is('deleted_at', null).not('status', 'in', '(delivered,unrepairable)'),
    ]);
    const count = (rows: { branch_id: string | null }[] | null) => (rows ?? []).reduce<Record<string, number>>((a, r) => ((a[r.branch_id ?? ''] = (a[r.branch_id ?? ''] ?? 0) + 1), a), {});
    return { cb: count(cb.data), dv: count(dv.data) };
  }, [b.all.length]);

  async function setKind(x: Branch, kind: string) {
    try {
      await rpc('set_branch_kind', { p_id: x.id, p_kind: kind });
      toast({ tone: 'ok', title: t('perm.kindSaved') });
      await b.reload();
    } catch (e) {
      toast({ tone: 'danger', title: errorMessage(e) });
    }
  }

  async function archive() {
    if (!closing) return;
    setBusy(true);
    try {
      await rpc('archive_branch', { p_id: closing.id });
      toast({ tone: 'ok', title: t('branch.archived') });
      setClosing(null);
      await b.reload();
    } catch (e) {
      toast({ tone: 'danger', title: errorMessage(e) });
    } finally {
      setBusy(false);
    }
  }

  return (
    <div className="flex flex-col gap-4" data-testid="branches-settings">
      <Panel>
        <PanelHeader
          index="01"
          title={t('branch.title')}
          actions={
            <Button size="sm" variant="primary" icon={<Plus className="size-4" />} needsNet onClick={() => setEdit('new')} data-testid="branch-add">
              {t('branch.add')}
            </Button>
          }
        />
        <div className="flex flex-col gap-3 p-4">
          <p className="text-xs text-fg-3">{t('branch.hint')}</p>
          {b.all.length <= 1 && <Alert tone="info">{t('branch.single')}</Alert>}
          <ul className="flex flex-col divide-y divide-glass-border rounded-md border border-glass-border">
            {b.all.map((x) => (
              <li key={x.id} className="flex flex-wrap items-center gap-3 px-3 py-2.5" data-testid="branch-row">
                <Building2 className="size-4 text-fg-3" aria-hidden />
                <div className="min-w-0 flex-1">
                  <div className="flex items-center gap-2 text-sm font-medium text-fg">
                    <bdi>{x.name}</bdi>
                    {x.is_main && <span className="rounded-sm bg-accent-soft px-1.5 text-2xs text-accent">{t('branch.main')}</span>}
                  </div>
                  <div className="num text-2xs text-fg-3" dir="ltr">
                    {x.prefix ? `${x.prefix}-${year}-0001` : `${year}-0001`}
                  </div>
                </div>
                {/* P: نوع الفرع (الأقسام اللي مالهاش علاقة بتختفي، والتغيير ما بيمسحش بيانات) */}
                <select
                  value={x.kind ?? 'both'}
                  onChange={(e) => void setKind(x, e.target.value)}
                  aria-label={`${t('perm.branchKind')} ${x.name}`}
                  title={t('perm.kindHint')}
                  className="h-8 rounded-md border border-line bg-sunken/60 px-2 text-xs text-fg"
                  data-testid="branch-kind"
                >
                  {(['both', 'repair', 'sales'] as const).map((k) => (
                    <option key={k} value={k}>
                      {t(`perm.kinds.${k}`)}
                    </option>
                  ))}
                </select>
                <span className="text-2xs text-fg-3">{t('branch.cashboxes', { n: stats.data?.cb[x.id] ?? 0 })}</span>
                <span className="text-2xs text-fg-3">{t('branch.devicesOpen', { n: stats.data?.dv[x.id] ?? 0 })}</span>
                <Button size="sm" variant="ghost" icon={<Pencil className="size-4" />} needsNet onClick={() => setEdit(x)} aria-label={`${t('branch.edit')} ${x.name}`}>
                  {t('edit.edit')}
                </Button>
                {!x.is_main && (
                  <Button size="sm" variant="ghost" needsNet onClick={() => setClosing(x)} className="text-fg-3 hover:text-danger" data-testid="branch-archive">
                    {t('branch.archive')}
                  </Button>
                )}
              </li>
            ))}
          </ul>
        </div>
      </Panel>
      <BranchDialog branch={edit} onOpenChange={(v) => !v && setEdit(null)} onDone={() => void b.reload()} />
      <Dialog
        open={!!closing}
        onOpenChange={(v) => !v && setClosing(null)}
        title={t('branch.archive')}
        guard={false}
        footer={
          <>
            <Button variant="ghost" onClick={() => setClosing(null)}>
              {t('common.cancel')}
            </Button>
            <Button variant="danger" loading={busy} needsNet onClick={() => void archive()} data-testid="branch-archive-confirm">
              {t('branch.archive')}
            </Button>
          </>
        }
      >
        <p className="text-sm text-fg-2">{closing && t('branch.archiveConfirm', { name: closing.name })}</p>
      </Dialog>
    </div>
  );
}

function BranchDialog({ branch, onOpenChange, onDone }: { branch: Branch | 'new' | null; onOpenChange: (v: boolean) => void; onDone: () => void }) {
  const { t } = useTranslation();
  const toast = useToast();
  const [name, setName] = useState('');
  const [prefix, setPrefix] = useState('');
  const [phone, setPhone] = useState('');
  const [address, setAddress] = useState('');
  const [err, setErr] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);
  const existing = branch && branch !== 'new' ? branch : null;
  useLayoutEffect(() => {
    setName(existing?.name ?? '');
    setPrefix(existing?.prefix ?? '');
    setPhone(existing?.phone ?? '');
    setAddress(existing?.address ?? '');
    setErr(null);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [branch]);
  const pre = prefix.trim().toUpperCase();
  async function save() {
    setErr(null);
    setBusy(true);
    try {
      await rpc('save_branch', { p_id: existing?.id ?? opId(), p_name: name, p_prefix: pre, p_phone: phone || null, p_address: address || null });
      toast({ tone: 'ok', title: t('branch.saved') });
      onOpenChange(false);
      onDone();
    } catch (e) {
      setErr(errorMessage(e));
    } finally {
      setBusy(false);
    }
  }
  return (
    <Dialog
      open={!!branch}
      onOpenChange={onOpenChange}
      title={existing ? t('branch.edit') : t('branch.add')}
      footer={
        <>
          <Button variant="ghost" onClick={() => onOpenChange(false)}>
            {t('common.cancel')}
          </Button>
          <Button variant="primary" type="submit" form="branch-form" loading={busy} needsNet data-testid="branch-save">
            {t('common.save')}
          </Button>
        </>
      }
    >
      <form
        id="branch-form"
        className="flex flex-col gap-3"
        onSubmit={(e) => {
          e.preventDefault();
          void save();
        }}
      >
        <Field label={t('branch.name')} required>
          <Input value={name} onChange={(e) => setName(e.target.value)} maxLength={80} data-testid="branch-name" />
        </Field>
        {existing?.is_main ? (
          <p className="text-xs text-fg-3">{t('branch.mainPrefix')}</p>
        ) : (
          <Field label={t('branch.prefix')} hint={t('branch.prefixHint', { sample: `${pre || 'B2'}-${new Date().getFullYear()}-0001` })} required>
            <Input value={prefix} onChange={(e) => setPrefix(e.target.value.toUpperCase().replace(/[^A-Z0-9]/g, '').slice(0, 4))} dir="ltr" mono className="w-28" data-testid="branch-prefix" />
          </Field>
        )}
        <Field label={t('branch.phone')}>
          <Input value={phone} onChange={(e) => setPhone(e.target.value)} dir="ltr" inputMode="tel" maxLength={40} />
        </Field>
        <Field label={t('branch.address')}>
          <Input value={address} onChange={(e) => setAddress(e.target.value)} maxLength={200} />
        </Field>
        {err && <Alert tone="danger">{err}</Alert>}
      </form>
    </Dialog>
  );
}
