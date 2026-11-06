import { useEffect, useState } from 'react';
import { useTranslation } from 'react-i18next';
import { Star } from 'lucide-react';
import { supabase } from '../lib/supabase';
import { errorMessage } from '../lib/errors';
import { Button } from '../ui/Button';
import { Textarea } from '../ui/Field';
import { Alert } from '../ui/Feedback';
import { cn } from '../ui/cn';

/** تقييم العميل بعد التسليم (من رابط الـ QR بس، لأنه سري). مرة واحدة لكل جهاز */
export function RatingBox({ token }: { token: string }) {
  const { t } = useTranslation();
  const [state, setState] = useState<{ can_rate: boolean; stars: number | null } | null>(null);
  const [stars, setStars] = useState(0);
  const [comment, setComment] = useState('');
  const [busy, setBusy] = useState(false);
  const [err, setErr] = useState<string | null>(null);

  useEffect(() => {
    void supabase.rpc('rating_state', { p_token: token }).then(({ data }) => setState((data as typeof state) ?? null));
  }, [token]);

  async function send() {
    if (!stars) return;
    setBusy(true);
    setErr(null);
    const { error } = await supabase.rpc('rate_device', { p_token: token, p_stars: stars, p_comment: comment.trim() || null });
    setBusy(false);
    if (error) return setErr(errorMessage(error));
    setState({ can_rate: false, stars });
  }

  if (!state) return null;
  if (!state.can_rate) return state.stars ? <Alert tone="ok">{t('rating.done', { n: state.stars })}</Alert> : null;
  return (
    <div className="glass rounded-2xl p-5" data-testid="rating-box">
      <div className="text-md font-semibold text-fg">{t('rating.title')}</div>
      <p className="mt-1 text-sm text-fg-2">{t('rating.sub')}</p>
      <div className="mt-3 flex gap-1" role="radiogroup" aria-label={t('rating.title')}>
        {[1, 2, 3, 4, 5].map((n) => (
          <button
            key={n}
            type="button"
            role="radio"
            aria-checked={stars === n}
            aria-label={t('rating.star', { n })}
            onClick={() => setStars(n)}
            className="rounded-md p-1 text-fg-3 transition-colors hover:text-warn"
          >
            <Star className={cn('size-7', n <= stars && 'fill-[var(--warn)] text-warn')} aria-hidden />
          </button>
        ))}
      </div>
      <Textarea rows={2} value={comment} onChange={(e) => setComment(e.target.value)} placeholder={t('rating.comment')} aria-label={t('rating.comment')} maxLength={500} className="mt-3" />
      {err && <Alert tone="danger" className="mt-3">{err}</Alert>}
      <Button variant="primary" className="mt-3" disabled={!stars} loading={busy} onClick={() => void send()}>
        {t('rating.send')}
      </Button>
    </div>
  );
}
