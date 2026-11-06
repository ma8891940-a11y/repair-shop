import { useState } from 'react';
import { useTranslation } from 'react-i18next';
import { Flag, MessageSquare, Send } from 'lucide-react';
import { PageHeader } from '../app/AppShell';
import { useLoad } from '../app/useLoad';
import { rpc } from '../app/ledgerApi';
import { errorMessage } from '../lib/errors';
import { useFormat } from '../i18n/format';
import { Panel } from '../ui/Panel';
import { Button } from '../ui/Button';
import { Field, Input, Textarea } from '../ui/Field';
import { Alert, EmptyState, ErrorState, Skeleton } from '../ui/Feedback';
import { useToast } from '../ui/Toast';

interface Post {
  id: string;
  parent_id: string | null;
  title: string | null;
  body: string;
  tags: string[];
  author: string;
  shop: string;
  created_at: string;
  replies: number;
  mine: boolean;
  hidden: boolean;
}

/**
 * مجتمع الفنيين: أسئلة وخبرات بين الفنيين في كل المحلات. ممنوع أي بيانات عملاء (رقم موبايل أو IMEI بيترفض لوحده).
 * أي حد يقدر يبلّغ عن منشور، والمشرف بيراجع.
 */
export function CommunityScreen() {
  const { t } = useTranslation();
  const f = useFormat();
  const toast = useToast();
  const [open, setOpen] = useState<string | null>(null);
  const [title, setTitle] = useState('');
  const [body, setBody] = useState('');
  const [reply, setReply] = useState('');
  const [err, setErr] = useState<string | null>(null);
  const feed = useLoad(() => rpc<Post[]>('community_feed', { p_parent: null, p_limit: 100 }), []);
  const thread = useLoad(async () => (open ? rpc<Post[]>('community_feed', { p_parent: open, p_limit: 200 }) : []), [open]);

  async function post(parent: string | null) {
    setErr(null);
    const text = parent ? reply : body;
    if (!text.trim()) return setErr(t('community.errEmpty'));
    try {
      await rpc('community_post', { p_id: crypto.randomUUID(), p_body: text.trim(), p_title: parent ? null : title.trim() || null, p_parent: parent });
      toast({ tone: 'ok', title: t('community.posted') });
      if (parent) {
        setReply('');
        thread.reload();
      } else {
        setTitle('');
        setBody('');
      }
      feed.reload();
    } catch (e) {
      setErr(errorMessage(e));
    }
  }
  async function report(id: string) {
    await rpc('community_report', { p_post: id, p_reason: null }).catch(() => null);
    toast({ tone: 'ok', title: t('community.reported') });
  }

  return (
    <div className="max-w-3xl">
      <PageHeader title={t('community.title')} sub={t('community.sub')} />
      <Panel className="mb-4 flex flex-col gap-3 p-4">
        <Field label={t('community.postTitle')}>
          <Input value={title} onChange={(e) => setTitle(e.target.value)} maxLength={160} />
        </Field>
        <Field label={t('community.body')} hint={t('community.privacy')}>
          <Textarea rows={3} value={body} onChange={(e) => setBody(e.target.value)} maxLength={4000} />
        </Field>
        {err && !open && <Alert tone="danger">{err}</Alert>}
        <Button variant="primary" icon={<Send className="size-4" />} onClick={() => void post(null)} className="self-start">
          {t('community.publish')}
        </Button>
      </Panel>
      {feed.error ? (
        <ErrorState message={feed.error} onRetry={feed.reload} />
      ) : feed.loading ? (
        <Skeleton className="h-40 w-full" />
      ) : !feed.data?.length ? (
        <Panel>
          <EmptyState line="chip" title={t('community.empty')} />
        </Panel>
      ) : (
        <ul className="flex flex-col gap-2">
          {feed.data.map((p) => (
            <li key={p.id}>
              <Panel className="p-4" data-testid="community-post">
                <div className="flex items-start gap-3">
                  <div className="min-w-0 flex-1">
                    {p.title && <div className="font-semibold text-fg">{p.title}</div>}
                    <p className="whitespace-pre-wrap text-sm text-fg-2">{p.body}</p>
                    <div className="mt-1 text-2xs text-fg-3">
                      {p.author} · {p.shop} · {f.dateTime(p.created_at)}
                      {p.hidden && <span className="ms-2 text-warn">{t('community.hidden')}</span>}
                    </div>
                  </div>
                  {!p.mine && (
                    <button type="button" onClick={() => void report(p.id)} className="rounded-sm p-1 text-fg-3 hover:text-danger" aria-label={t('community.report')} title={t('community.report')}>
                      <Flag className="size-4" aria-hidden />
                    </button>
                  )}
                </div>
                <button type="button" onClick={() => setOpen(open === p.id ? null : p.id)} className="mt-2 inline-flex items-center gap-1.5 text-xs text-accent hover:underline">
                  <MessageSquare className="size-3.5" aria-hidden /> {t('community.replies', { count: p.replies, n: p.replies })}
                </button>
                {open === p.id && (
                  <div className="mt-3 flex flex-col gap-2 border-t border-glass-border pt-3">
                    {(thread.data ?? [])
                      .filter((r) => r.id !== p.id)
                      .map((r) => (
                        <div key={r.id} className="rounded-md bg-sunken/40 px-3 py-2 text-sm">
                          <p className="whitespace-pre-wrap text-fg-2">{r.body}</p>
                          <div className="text-2xs text-fg-3">
                            {r.author} · {r.shop}
                          </div>
                        </div>
                      ))}
                    <div className="flex gap-2">
                      <Input value={reply} onChange={(e) => setReply(e.target.value)} placeholder={t('community.replyPh')} aria-label={t('community.reply')} className="flex-1" />
                      <Button size="sm" onClick={() => void post(p.id)}>
                        {t('community.reply')}
                      </Button>
                    </div>
                    {err && <Alert tone="danger">{err}</Alert>}
                  </div>
                )}
              </Panel>
            </li>
          ))}
        </ul>
      )}
    </div>
  );
}
