import { useCallback, useEffect, useRef, useState } from 'react';
import { useParams } from 'react-router';
import { useTranslation } from 'react-i18next';
import { Camera, Check, ShieldCheck } from 'lucide-react';
import { supabase } from '../lib/supabase';
import { uploadSessionPhoto } from '../lib/photos';
import { useFormat } from '../i18n/format';
import { LangToggle, ThemeToggle } from '../ui/ThemeToggle';
import { Button } from '../ui/Button';
import { Alert, Skeleton } from '../ui/Feedback';

interface Session {
  shop_name: string;
  order_no: string;
  brand: string;
  model: string;
  photos: number;
  max_photos: number;
  expires_at: string;
  folder: string;
}

/**
 * C1: صفحة رفع صور الاستلام من موبايل الفني (بتتفتح من QR على شاشة الاستلام أو صفحة الجهاز).
 * من غير تسجيل دخول: الـ token صالح 30 دقيقة لجهاز واحد بس، ومفيش أي بيانات للعميل هنا.
 */
export function PhoneUploadScreen() {
  const { token = '' } = useParams();
  const { t } = useTranslation();
  const f = useFormat();
  const [s, setS] = useState<Session | null | undefined>(undefined);
  const [busy, setBusy] = useState(false);
  const [sent, setSent] = useState(0);
  const [err, setErr] = useState<string | null>(null);
  const input = useRef<HTMLInputElement>(null);

  const load = useCallback(async () => {
    const { data, error } = await supabase.rpc('photo_session', { p_token: token });
    if (error) return setS(null);
    setS(((data ?? []) as Session[])[0] ?? null);
  }, [token]);
  useEffect(() => {
    void load();
  }, [load]);

  async function pick(files: FileList | null) {
    if (!s || !files?.length) return;
    setErr(null);
    setBusy(true);
    const room = Math.max(0, s.max_photos - s.photos);
    try {
      for (const file of Array.from(files).slice(0, room)) {
        await uploadSessionPhoto(token, s.folder, file);
        setSent((n) => n + 1);
      }
    } catch (e) {
      const m = e instanceof Error ? e.message : '';
      setErr(/E_UPLOAD_EXPIRED|row-level|security/i.test(m) ? t('upload.expired') : /E_PHOTO_LIMIT/.test(m) ? t('upload.full') : t('upload.failed'));
    } finally {
      setBusy(false);
      if (input.current) input.current.value = '';
      await load();
    }
  }

  const left = s ? Math.max(0, s.max_photos - s.photos) : 0;
  return (
    <div className="relative min-h-dvh">
      <div className="relative z-10 mx-auto flex min-h-dvh w-full max-w-lg flex-col px-4 pb-10">
        <header className="flex items-center justify-between py-4">
          <div className="text-lg font-bold text-fg">{s?.shop_name ?? t('upload.title')}</div>
          <div className="flex items-center gap-1">
            <LangToggle />
            <ThemeToggle />
          </div>
        </header>
        {s === undefined ? (
          <Skeleton className="mt-6 h-48 w-full rounded-2xl" />
        ) : s === null ? (
          <div className="mt-6" data-testid="upload-expired">
            <Alert tone="danger">{t('upload.expired')}</Alert>
          </div>
        ) : (
          <section className="glass edge-glow shadow-3 relative mt-6 flex flex-col gap-4 rounded-2xl p-6" data-testid="phone-upload">
            <div>
              <h1 className="text-xl font-semibold text-fg">{t('upload.title')}</h1>
              <p className="mt-1 text-sm text-fg-2">
                <span className="num" dir="ltr">
                  {s.order_no}
                </span>{' '}
                · {s.brand} {s.model}
              </p>
            </div>
            <div className="flex items-baseline justify-between text-sm">
              <span className="text-fg-3">{t('upload.count')}</span>
              <span className="num text-fg" data-testid="upload-count">
                {s.photos}/{s.max_photos}
              </span>
            </div>
            <input
              ref={input}
              type="file"
              accept="image/*"
              capture="environment"
              multiple
              className="sr-only"
              data-testid="upload-input"
              onChange={(e) => void pick(e.target.files)}
              aria-label={t('upload.take')}
            />
            <Button variant="primary" size="lg" className="w-full justify-center" loading={busy} disabled={left === 0} onClick={() => input.current?.click()} icon={<Camera className="size-5" />}>
              {left === 0 ? t('upload.full') : t('upload.take')}
            </Button>
            {sent > 0 && !err && (
              <Alert tone="ok">
                <span className="inline-flex items-center gap-1.5" data-testid="upload-done">
                  <Check className="size-4" aria-hidden /> {t('upload.sent', { n: sent })}
                </span>
              </Alert>
            )}
            {err && <Alert tone="danger">{err}</Alert>}
            <p className="flex items-center gap-1.5 text-2xs text-fg-3">
              <ShieldCheck className="size-3.5 shrink-0" aria-hidden /> {t('upload.until', { time: f.time(s.expires_at) })}
            </p>
          </section>
        )}
      </div>
    </div>
  );
}
