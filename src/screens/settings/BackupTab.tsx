import { useState } from 'react';
import { useTranslation } from 'react-i18next';
import { Download, FileLock2, FolderOpen } from 'lucide-react';
import { useLoad } from '../../app/useLoad';
import { rpc } from '../../app/ledgerApi';
import { backupSummary, decryptBackup, encryptBackup, type EncryptedBackup } from '../../offline/backupCrypto';
import { errorMessage } from '../../lib/errors';
import { useFormat } from '../../i18n/format';
import { Panel, PanelHeader } from '../../ui/Panel';
import { Button } from '../../ui/Button';
import { Field, Input } from '../../ui/Field';
import { Alert } from '../../ui/Feedback';
import { useToast } from '../../ui/Toast';

function save(name: string, text: string) {
  const a = document.createElement('a');
  a.href = URL.createObjectURL(new Blob([text], { type: 'application/octet-stream' }));
  a.download = name;
  a.click();
  setTimeout(() => URL.revokeObjectURL(a.href), 1000);
}

/** النسخ الاحتياطي (صاحب المحل): تصدير ملف مشفّر بكلمة سر على الجهاز، والنسخ اليومية على السيرفر، وفتح ملف للتأكد منه */
export function BackupTab() {
  const { t } = useTranslation();
  const f = useFormat();
  const toast = useToast();
  const [pw, setPw] = useState('');
  const [pw2, setPw2] = useState('');
  const [busy, setBusy] = useState(false);
  const [err, setErr] = useState<string | null>(null);
  const [openPw, setOpenPw] = useState('');
  const [summary, setSummary] = useState<Record<string, number> | null>(null);
  const list = useLoad(() => rpc<{ id: string; created_at: string; size_kb: number }[]>('list_backups'), []);

  async function exportNow(data?: unknown, label = 'manual') {
    setErr(null);
    if (pw.length < 8) return setErr(t('backup.errShort'));
    if (pw !== pw2) return setErr(t('backup.errMatch'));
    setBusy(true);
    try {
      const raw = data ?? (await rpc('export_backup'));
      const file = await encryptBackup(raw, pw);
      save(`warsha-backup-${label}-${new Date().toISOString().slice(0, 10)}.warsha`, JSON.stringify(file));
      toast({ tone: 'ok', title: t('backup.saved') });
    } catch (e) {
      setErr(errorMessage(e));
    } finally {
      setBusy(false);
    }
  }
  async function openFile(file: File) {
    setErr(null);
    setSummary(null);
    try {
      const data = await decryptBackup<Record<string, unknown>>(JSON.parse(await file.text()) as EncryptedBackup, openPw);
      setSummary(backupSummary(data));
    } catch (e) {
      setErr(t(`backup.${(e as Error).message === 'E_BACKUP_PASSWORD' ? 'errPassword' : 'errFormat'}`));
    }
  }

  return (
    <div className="flex flex-col gap-4">
      <Panel>
        <PanelHeader title={t('backup.export')} />
        <div className="flex flex-col gap-3 p-4">
          <p className="text-xs text-fg-3">{t('backup.exportHint')}</p>
          <div className="grid gap-3 sm:grid-cols-2">
            <Field label={t('backup.password')}>
              <Input type="password" autoComplete="new-password" value={pw} onChange={(e) => setPw(e.target.value)} />
            </Field>
            <Field label={t('backup.password2')}>
              <Input type="password" autoComplete="new-password" value={pw2} onChange={(e) => setPw2(e.target.value)} />
            </Field>
          </div>
          <Button variant="primary" className="self-start" loading={busy} icon={<FileLock2 className="size-4" />} onClick={() => void exportNow()}>
            {t('backup.exportNow')}
          </Button>
        </div>
      </Panel>
      <Panel>
        <PanelHeader title={t('backup.daily')} />
        <div className="p-4">
          <p className="mb-2 text-xs text-fg-3">{t('backup.dailyHint')}</p>
          {(list.data ?? []).length === 0 ? (
            <p className="text-sm text-fg-3">{t('backup.noDaily')}</p>
          ) : (
            <ul className="divide-y divide-glass-border rounded-md border border-glass-border text-sm">
              {list.data!.map((b) => (
                <li key={b.id} className="flex items-center gap-3 px-3 py-2">
                  <span className="flex-1 text-fg">{f.dateTime(b.created_at)}</span>
                  <span className="num text-2xs text-fg-3">{f.number(b.size_kb)} KB</span>
                  <Button size="sm" variant="ghost" icon={<Download className="size-3.5" />} onClick={async () => void exportNow(await rpc('get_backup', { p_id: b.id }), 'daily')}>
                    {t('backup.download')}
                  </Button>
                </li>
              ))}
            </ul>
          )}
        </div>
      </Panel>
      <Panel>
        <PanelHeader title={t('backup.open')} />
        <div className="flex flex-col gap-3 p-4">
          <p className="text-xs text-fg-3">{t('backup.openHint')}</p>
          <div className="grid items-end gap-3 sm:grid-cols-2">
            <Field label={t('backup.password')}>
              <Input type="password" value={openPw} onChange={(e) => setOpenPw(e.target.value)} />
            </Field>
            <label className="inline-flex h-9 cursor-pointer items-center gap-2 self-end rounded-md border border-line px-3 text-sm text-fg-2 hover:border-accent hover:text-fg">
              <FolderOpen className="size-4" aria-hidden /> {t('backup.pick')}
              <input type="file" accept=".warsha,application/json" className="sr-only" onChange={(e) => {
                  const file = e.target.files?.[0];
                  e.target.value = ''; // عشان نفس الملف يتفتح تاني (مثلًا بكلمة سر مختلفة)
                  if (file) void openFile(file);
                }}
              />
            </label>
          </div>
          {summary && (
            <Alert tone="ok" title={t('backup.valid')}>
              <span data-testid="backup-summary">{Object.entries(summary).map(([k, v]) => `${k}: ${v}`).join(' · ')}</span>
            </Alert>
          )}
        </div>
      </Panel>
      {err && <Alert tone="danger">{err}</Alert>}
    </div>
  );
}
