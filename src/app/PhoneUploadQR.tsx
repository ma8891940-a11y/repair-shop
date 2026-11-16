import { useEffect, useRef, useState } from 'react';
import { useTranslation } from 'react-i18next';
import QRCode from 'qrcode';
import { Smartphone } from 'lucide-react';
import { supabase } from '../lib/supabase';
import { appBase } from '../lib/publicUrl';
import { errorMessage } from '../lib/errors';
import { useAuth } from './auth';
import { useFormat } from '../i18n/format';
import { useOnline } from '../ui/useOnline';
import { Button } from '../ui/Button';
import { Dialog } from '../ui/Dialog';
import { Alert, Skeleton } from '../ui/Feedback';

/** رابط صفحة الرفع من الموبايل (نفس قاعدة رابط التتبع: الرابط العام لو متسجّل) */
export function uploadUrl(base: string, token: string): string {
  return `${base.replace(/#.*$/, '').replace(/\/$/, '')}/#/up/${token}`;
}

/**
 * C1: زرار "صور من الموبايل": بيفتح جلسة رفع (30 دقيقة) ويعرض QR، والصور اللي بتترفع بتظهر على طول
 * (الشاشة بتسأل كل 3 ثواني وهي مفتوحة). محتاج نت.
 */
export function PhoneUploadQR({ deviceId, onPhotos, compact = false }: { deviceId: string; onPhotos: () => void; compact?: boolean }) {
  const { t } = useTranslation();
  const f = useFormat();
  const { shop } = useAuth();
  const online = useOnline();
  const [open, setOpen] = useState(false);
  const [s, setS] = useState<{ url: string; qr: string; until: string } | null>(null);
  const [err, setErr] = useState<string | null>(null);
  // ref عشان إعادة الرسم ما تفتحش جلسة جديدة
  const cb = useRef(onPhotos);
  cb.current = onPhotos;

  useEffect(() => {
    if (!open) return;
    let live = true;
    setS(null);
    setErr(null);
    void (async () => {
      const { data, error } = await supabase.rpc('start_photo_upload', { p_device: deviceId });
      if (!live) return;
      if (error) return setErr(errorMessage(error));
      const row = ((data ?? []) as { token: string; expires_at: string }[])[0];
      const url = uploadUrl(appBase(shop?.extras, window.location.href), row.token);
      const qr = await QRCode.toDataURL(url, { margin: 1, width: 320, errorCorrectionLevel: 'M' });
      if (live) setS({ url, qr, until: row.expires_at });
    })();
    // الصور بتظهر على الجهاز وهي بتترفع
    const tm = setInterval(() => cb.current(), 3000);
    return () => {
      live = false;
      clearInterval(tm);
      cb.current();
    };
  }, [open, deviceId, shop?.extras]);

  return (
    <>
      <Button size={compact ? 'sm' : 'md'} variant="secondary" disabled={!online} title={online ? undefined : t('upload.needOnline')} onClick={() => setOpen(true)} icon={<Smartphone className="size-4" />} data-testid="phone-upload-btn">
        {t('upload.fromPhone')}
      </Button>
      <Dialog open={open} onOpenChange={setOpen} title={t('upload.qrTitle')} description={t('upload.qrSub')} guard={false}>
        <div className="flex flex-col items-center gap-3 p-4" data-testid="phone-upload-qr">
          {err ? (
            <Alert tone="danger">{err}</Alert>
          ) : !s ? (
            <Skeleton className="size-56 rounded-lg" />
          ) : (
            <>
              <img src={s.qr} alt={t('upload.qrTitle')} className="size-56 rounded-lg bg-white p-2" />
              <a href={s.url} target="_blank" rel="noreferrer" className="max-w-full break-all text-center text-2xs text-fg-3 underline" dir="ltr" data-testid="phone-upload-link">
                {s.url}
              </a>
              <p className="text-xs text-fg-3">{t('upload.until', { time: f.time(s.until) })}</p>
            </>
          )}
        </div>
      </Dialog>
    </>
  );
}
