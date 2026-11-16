import { useEffect } from 'react';
import { useNavigate, useParams } from 'react-router';
import { useTranslation } from 'react-i18next';
import { useBackground } from '../app/stage';
import { useMe } from '../app/auth';
import { useLoad, must } from '../app/useLoad';
import { useDeviceTemplate, useItemLabel } from '../app/checkTemplates';
import { ColorHeader, PoweredBy, useBranding } from '../app/brand/branding';
import { supabase } from '../lib/supabase';
import { checkKeys, compareChecks, type CheckItems, type CheckValue } from '../lib/checks';
import type { Device } from '../lib/types';
import { useFormat } from '../i18n/format';
import { Skeleton } from '../ui/Feedback';
import { cn } from '../ui/cn';

interface CheckRow {
  stage: 'intake' | 'delivery';
  items: CheckItems;
  labels: Record<string, string> | null;
  created_at: string;
  updated_at: string;
}

/**
 * C2: ورقة الفحص (A4 ملونة باسم المحل ولوجوه): كل بند وقت الاستلام ووقت التسليم،
 * واللي كان شغال وباظ متعلّم، وتوقيع العميل في الاستلام والتسليم، ومكان توقيع على الورق.
 */
export function ChecklistPrint() {
  const { id = '' } = useParams();
  const { t } = useTranslation();
  const f = useFormat();
  const navigate = useNavigate();
  const { shop } = useMe();
  const branding = useBranding();
  const label = useItemLabel();
  useBackground('off');

  const { data, error } = useLoad(async () => {
    const d = must(await supabase.from('devices').select('*').eq('id', id).maybeSingle()) as (Device & { delivery_signature?: string | null }) | null;
    if (!d) throw new Error('E_NOT_FOUND');
    const checks = (must(await supabase.from('device_checks').select('stage, items, labels, created_at, updated_at').eq('device_id', id).is('deleted_at', null)) ?? []) as CheckRow[];
    return { d, intake: checks.find((c) => c.stage === 'intake') ?? null, delivery: checks.find((c) => c.stage === 'delivery') ?? null };
  }, [id]);
  const template = useDeviceTemplate(data?.d.brand);
  const ready = !!data && !branding.loading;
  useEffect(() => {
    if (!ready) return;
    const tm = setTimeout(() => window.print(), 350);
    return () => clearTimeout(tm);
  }, [ready]);

  const labels = { ...(data?.intake?.labels ?? {}), ...(data?.delivery?.labels ?? {}) };
  const rows = data ? compareChecks(data.intake?.items, data.delivery?.items, checkKeys(template, data.intake?.items, data.delivery?.items)) : [];
  const mark = (v: CheckValue | undefined) => (v ? t(`checks.${v}`) : '—');

  return (
    <div className="min-h-dvh bg-white text-black">
      <style>{'@page { size: A4; margin: 14mm; }'}</style>
      <div className="flex flex-wrap items-center gap-3 border-b border-neutral-200 bg-neutral-50 px-4 py-3 print:hidden">
        <button type="button" onClick={() => window.print()} className="h-9 rounded-md bg-accent px-4 text-sm font-semibold text-on-accent">
          {t('print.print')}
        </button>
        <button type="button" onClick={() => navigate(-1)} className="h-9 rounded-md border border-neutral-300 px-4 text-sm">
          {t('print.back')}
        </button>
      </div>
      {error ? (
        <p className="p-6 text-sm text-red-700">{error}</p>
      ) : !data ? (
        <div className="mx-auto max-w-[190mm] p-[10mm]">
          <Skeleton className="h-60 w-full" />
        </div>
      ) : (
        <article className="mx-auto max-w-[190mm] p-[10mm] text-[13px] print:max-w-none print:p-0" data-testid="print-checklist-sheet">
          <ColorHeader shop={shop} b={branding.data ?? null} title={t('checks.sheet')} sub={data.d.order_no ?? undefined} />
          <div className="mt-3 grid grid-cols-2 gap-x-6 gap-y-1 border-b border-neutral-300 pb-2">
            <div>
              <b>{t('print.device')}:</b> {data.d.brand} {data.d.model}
            </div>
            {data.d.imei && (
              <div>
                <b>IMEI:</b>{' '}
                <span className="font-mono" dir="ltr">
                  {data.d.imei}
                </span>
              </div>
            )}
            <div>
              <b>{t('checks.intake')}:</b> {data.intake ? f.dateTime(data.intake.updated_at) : t('common.none')}
            </div>
            <div>
              <b>{t('checks.delivery')}:</b> {data.delivery ? f.dateTime(data.delivery.updated_at) : t('common.none')}
            </div>
          </div>
          <table className="mt-3 w-full border-collapse text-[13px]">
            <thead>
              <tr className="bg-neutral-100">
                <th className="border border-neutral-300 px-2 py-1 text-start">{t('checks.item')}</th>
                <th className="w-[22%] border border-neutral-300 px-2 py-1">{t('checks.intake')}</th>
                <th className="w-[22%] border border-neutral-300 px-2 py-1">{t('checks.delivery')}</th>
              </tr>
            </thead>
            <tbody>
              {rows.map((r) => (
                <tr key={r.item} className={cn(r.regressed && 'bg-red-50')} data-testid="checklist-row">
                  <td className="border border-neutral-300 px-2 py-1">
                    {label(r.item, labels, template)}
                    {r.regressed && <span className="ms-2 text-[11px] font-bold text-red-700">{t('checks.regressed')}</span>}
                  </td>
                  <td className="border border-neutral-300 px-2 py-1 text-center">{mark(r.intake)}</td>
                  <td className="border border-neutral-300 px-2 py-1 text-center">{mark(r.delivery)}</td>
                </tr>
              ))}
            </tbody>
          </table>
          <p className="mt-3 text-[12px] text-neutral-700">{t('checks.sheetNote')}</p>
          <div className="mt-6 grid grid-cols-2 gap-6">
            {(
              [
                ['intake', data.d.intake_signature],
                ['delivery', data.d.delivery_signature],
              ] as const
            ).map(([k, sig]) => (
              <div key={k} className="border-t border-neutral-400 pt-2" data-testid={`checklist-sign-${k}`}>
                <b>{t(k === 'intake' ? 'signature.title' : 'signature.delivery')}</b>
                {sig ? <img src={sig} alt="" className="mt-1 h-[18mm] w-auto" /> : <div className="mt-6">..............................</div>}
              </div>
            ))}
          </div>
          <PoweredBy b={branding.data ?? null} />
        </article>
      )}
    </div>
  );
}
