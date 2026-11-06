import { useState } from 'react';
import { useTranslation } from 'react-i18next';
import { Check, Film, Upload, X } from 'lucide-react';
import { PageHeader, useLiveRefresh } from '../app/AppShell';
import { useLoad, must } from '../app/useLoad';
import { useMe } from '../app/auth';
import { rpc } from '../app/ledgerApi';
import { supabase } from '../lib/supabase';
import { errorMessage } from '../lib/errors';
import { useFormat } from '../i18n/format';
import { Panel, PanelHeader } from '../ui/Panel';
import { Button } from '../ui/Button';
import { Field, Input, Textarea } from '../ui/Field';
import { Alert, EmptyState, ErrorState, Skeleton } from '../ui/Feedback';
import { useToast } from '../ui/Toast';
import { cn } from '../ui/cn';

interface Video {
  id: string;
  technician_id: string;
  title: string;
  description: string | null;
  storage_path: string;
  status: 'pending' | 'approved' | 'rejected';
  points: number;
  review_note: string | null;
  created_at: string;
  profiles: { full_name: string } | null;
}
const MAX_VIDEO = 100 * 1024 * 1024;

/**
 * فيديوهات الإصلاح: الفني بيرفع فيديو لشغله (من غير بيانات العميل)، ومدير التسويق بيراجع،
 * والمقبول بيزوّد نقاط الفني. صاحب المحل بيشوف الكل ويقدر يراجع.
 */
export function VideosScreen() {
  const { t } = useTranslation();
  const f = useFormat();
  const { profile, shop } = useMe();
  const toast = useToast();
  const canUpload = profile.role === 'technician' || profile.role === 'owner';
  const canReview = profile.role === 'marketing' || profile.role === 'owner';
  const [title, setTitle] = useState('');
  const [desc, setDesc] = useState('');
  const [file, setFile] = useState<File | null>(null);
  const [busy, setBusy] = useState(false);
  const [err, setErr] = useState<string | null>(null);
  const [playing, setPlaying] = useState<{ id: string; url: string } | null>(null);
  const { data, error, loading, reload } = useLoad(
    async () => must(await supabase.from('repair_videos').select('id, technician_id, title, description, storage_path, status, points, review_note, created_at, profiles:technician_id(full_name)').is('deleted_at', null).order('created_at', { ascending: false })) as unknown as Video[],
    [],
  );
  useLiveRefresh(reload);

  async function upload() {
    setErr(null);
    if (!title.trim()) return setErr(t('videos.errTitle'));
    if (!file) return setErr(t('videos.errFile'));
    if (file.size > MAX_VIDEO) return setErr(t('videos.errSize'));
    setBusy(true);
    try {
      const id = crypto.randomUUID();
      const ext = file.type === 'video/webm' ? 'webm' : file.type === 'video/quicktime' ? 'mov' : 'mp4';
      const path = `${shop.id}/${id}.${ext}`;
      const up = await supabase.storage.from('repair-videos').upload(path, file, { contentType: file.type });
      if (up.error) throw up.error;
      await rpc('add_video', { p_id: id, p_title: title.trim(), p_path: path, p_description: desc.trim() || null });
      toast({ tone: 'ok', title: t('videos.uploaded') });
      setTitle('');
      setDesc('');
      setFile(null);
      reload();
    } catch (e) {
      setErr(errorMessage(e));
    } finally {
      setBusy(false);
    }
  }
  async function review(v: Video, approve: boolean) {
    try {
      await rpc('review_video', { p_video: v.id, p_approve: approve, p_points: approve ? 10 : 0 });
      toast({ tone: 'ok', title: t(approve ? 'videos.approved' : 'videos.rejected') });
      reload();
    } catch (e) {
      toast({ tone: 'danger', title: errorMessage(e) });
    }
  }
  async function play(v: Video) {
    const { data: s } = await supabase.storage.from('repair-videos').createSignedUrl(v.storage_path, 600);
    if (s?.signedUrl) setPlaying({ id: v.id, url: s.signedUrl });
  }

  return (
    <div className="max-w-4xl">
      <PageHeader title={t('videos.title')} sub={t(`videos.sub.${profile.role}`, { defaultValue: t('videos.sub.owner') })} />
      {canUpload && (
        <Panel className="mb-4">
          <PanelHeader title={t('videos.new')} />
          <div className="grid gap-3 p-4 sm:grid-cols-2">
            <Field label={t('videos.titleField')} required>
              <Input value={title} onChange={(e) => setTitle(e.target.value)} maxLength={120} />
            </Field>
            <label className="inline-flex h-9 cursor-pointer items-center gap-2 self-end rounded-md border border-line px-3 text-sm text-fg-2 hover:border-accent hover:text-fg">
              <Upload className="size-4" aria-hidden /> {file ? file.name : t('videos.pick')}
              <input type="file" accept="video/mp4,video/webm,video/quicktime" className="sr-only" aria-label={t('videos.pick')} onChange={(e) => { setFile(e.target.files?.[0] ?? null); e.target.value = ''; }} />
            </label>
            <Field label={t('videos.desc')} hint={t('videos.privacy')} className="sm:col-span-2">
              <Textarea rows={2} value={desc} onChange={(e) => setDesc(e.target.value)} maxLength={1000} />
            </Field>
            {err && <Alert tone="danger" className="sm:col-span-2">{err}</Alert>}
            <Button variant="primary" loading={busy} icon={<Upload className="size-4" />} onClick={() => void upload()} className="self-start">
              {t('videos.upload')}
            </Button>
          </div>
        </Panel>
      )}
      {error ? (
        <ErrorState message={error} onRetry={reload} />
      ) : loading ? (
        <Skeleton className="h-40 w-full" />
      ) : !data?.length ? (
        <Panel>
          <EmptyState line="scan" title={t('videos.empty')} />
        </Panel>
      ) : (
        <ul className="flex flex-col gap-2">
          {data.map((v) => (
            <li key={v.id}>
              <Panel className="p-3" data-testid="video-item">
                <div className="flex flex-wrap items-center gap-3">
                  <button type="button" onClick={() => void play(v)} className="grid size-10 place-items-center rounded-md border border-glass-border text-fg-2 hover:text-accent" aria-label={t('videos.play')}>
                    <Film className="size-5" aria-hidden />
                  </button>
                  <div className="min-w-0 flex-1">
                    <div className="truncate font-medium text-fg">{v.title}</div>
                    <div className="text-2xs text-fg-3">
                      {v.profiles?.full_name} · {f.dateTime(v.created_at)}
                    </div>
                  </div>
                  <span className={cn('rounded-full border px-2 py-0.5 text-2xs', v.status === 'approved' ? 'border-ok text-ok' : v.status === 'rejected' ? 'border-danger text-danger' : 'border-line text-fg-3')}>
                    {t(`videos.status.${v.status}`)}
                    {v.status === 'approved' && ` · +${v.points}`}
                  </span>
                  {canReview && v.status === 'pending' && (
                    <div className="flex gap-1">
                      <Button size="sm" icon={<Check className="size-4" />} onClick={() => void review(v, true)}>
                        {t('videos.approve')}
                      </Button>
                      <Button size="sm" variant="ghost" icon={<X className="size-4" />} onClick={() => void review(v, false)}>
                        {t('videos.reject')}
                      </Button>
                    </div>
                  )}
                </div>
                {v.description && <p className="mt-2 text-sm text-fg-2">{v.description}</p>}
                {playing?.id === v.id && <video src={playing.url} controls className="mt-3 max-h-80 w-full rounded-md bg-black" />}
              </Panel>
            </li>
          ))}
        </ul>
      )}
    </div>
  );
}
