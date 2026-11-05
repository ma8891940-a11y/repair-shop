import type { ReactNode } from 'react';
import { useTranslation } from 'react-i18next';
import { AlertTriangle, CheckCircle2, Info, OctagonAlert, RotateCw } from 'lucide-react';
import { motion } from 'motion/react';
import { cn } from './cn';
import { Button } from './Button';
import { LineIcon, type LineIconName } from './fx/LineIcon';

type Tone = 'info' | 'ok' | 'warn' | 'danger';
const toneCls: Record<Tone, string> = {
  info: 'border-[rgb(var(--accent-rgb)/0.3)] bg-accent-soft',
  ok: 'border-[color-mix(in_srgb,var(--ok)_30%,transparent)] bg-ok-soft',
  warn: 'border-[color-mix(in_srgb,var(--warn)_35%,transparent)] bg-warn-soft',
  danger: 'border-[color-mix(in_srgb,var(--danger)_35%,transparent)] bg-danger-soft',
};
export const toneIcon: Record<Tone, ReactNode> = {
  info: <Info className="size-4 text-accent" />,
  ok: <CheckCircle2 className="size-4 text-ok" />,
  warn: <AlertTriangle className="size-4 text-warn" />,
  danger: <OctagonAlert className="size-4 text-danger" />,
};

/** تنبيه داخل الصفحة. الخطأ بيهتز هزة خفيفة لما يظهر */
export function Alert({ tone = 'info', title, children, className, action }: { tone?: Tone; title?: ReactNode; children?: ReactNode; className?: string; action?: ReactNode }) {
  return (
    <motion.div
      initial={tone === 'danger' ? { x: 0, opacity: 0 } : { opacity: 0, y: -4 }}
      animate={tone === 'danger' ? { x: [0, -6, 6, -4, 4, -2, 0], opacity: 1 } : { opacity: 1, y: 0 }}
      transition={{ duration: tone === 'danger' ? 0.36 : 0.18 }}
      role={tone === 'danger' ? 'alert' : 'status'}
      className={cn('flex gap-2.5 rounded-md border px-3 py-2.5 text-sm text-fg', toneCls[tone], className)}
    >
      <span className="mt-0.5 shrink-0" aria-hidden>
        {toneIcon[tone]}
      </span>
      <div className="min-w-0 flex-1">
        {title && <div className="font-semibold">{title}</div>}
        {children && <div className={cn(title && 'mt-0.5 text-fg-2')}>{children}</div>}
      </div>
      {action}
    </motion.div>
  );
}

export function Skeleton({ className }: { className?: string }) {
  return <div className={cn('shimmer rounded-sm', className)} aria-hidden />;
}

export function EmptyState({ icon, line, title, children, action }: { icon?: ReactNode; line?: LineIconName; title: ReactNode; children?: ReactNode; action?: ReactNode }) {
  return (
    <div className="flex flex-col items-center justify-center gap-2 px-6 py-10 text-center">
      {line ? <LineIcon name={line} size={56} className="mb-1 opacity-90" /> : icon && <div className="mb-1 grid size-11 place-items-center rounded-lg border border-glass-border bg-raised text-fg-3">{icon}</div>}
      <div className="text-base font-semibold text-fg">{title}</div>
      {children && <p className="max-w-sm text-sm text-fg-3">{children}</p>}
      {action && <div className="mt-2">{action}</div>}
    </div>
  );
}

export function ErrorState({ message, onRetry }: { message: string; onRetry?: () => void }) {
  const { t } = useTranslation();
  return (
    <EmptyState
      line="scan"
      title={t('common.errorTitle')}
      action={
        onRetry && (
          <Button size="sm" variant="outline" icon={<RotateCw className="size-3.5" />} onClick={onRetry}>
            {t('common.retry')}
          </Button>
        )
      }
    >
      {message}
    </EmptyState>
  );
}
