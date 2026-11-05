import type { ReactNode } from 'react';
import { AlertTriangle, CheckCircle2, Info, OctagonAlert, RotateCw } from 'lucide-react';
import { motion } from 'motion/react';
import { cn } from './cn';
import { Button } from './Button';

type Tone = 'info' | 'ok' | 'warn' | 'danger';
const toneCls: Record<Tone, string> = {
  info: 'border-[color-mix(in_srgb,var(--accent)_30%,transparent)] bg-accent-soft text-fg',
  ok: 'border-[color-mix(in_srgb,var(--ok)_30%,transparent)] bg-ok-soft text-fg',
  warn: 'border-[color-mix(in_srgb,var(--warn)_35%,transparent)] bg-warn-soft text-fg',
  danger: 'border-[color-mix(in_srgb,var(--danger)_35%,transparent)] bg-danger-soft text-fg',
};
const toneIcon: Record<Tone, ReactNode> = {
  info: <Info className="size-4 text-accent" />,
  ok: <CheckCircle2 className="size-4 text-ok" />,
  warn: <AlertTriangle className="size-4 text-warn" />,
  danger: <OctagonAlert className="size-4 text-danger" />,
};

export function Alert({ tone = 'info', title, children, className, action }: { tone?: Tone; title?: ReactNode; children?: ReactNode; className?: string; action?: ReactNode }) {
  return (
    <motion.div
      initial={{ opacity: 0, y: -4 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ duration: 0.18 }}
      role={tone === 'danger' ? 'alert' : 'status'}
      className={cn('flex gap-2.5 rounded-md border px-3 py-2.5 text-sm', toneCls[tone], className)}
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
  return <div className={cn('animate-shimmer rounded-sm bg-raised', className)} aria-hidden />;
}

export function EmptyState({ icon, title, children, action }: { icon?: ReactNode; title: ReactNode; children?: ReactNode; action?: ReactNode }) {
  return (
    <div className="flex flex-col items-center justify-center gap-2 px-6 py-10 text-center">
      {icon && <div className="mb-1 grid size-11 place-items-center rounded-lg border border-line bg-raised text-fg-3">{icon}</div>}
      <div className="text-base font-semibold text-fg">{title}</div>
      {children && <p className="max-w-sm text-sm text-fg-3">{children}</p>}
      {action && <div className="mt-2">{action}</div>}
    </div>
  );
}

export function ErrorState({ message, onRetry }: { message: string; onRetry?: () => void }) {
  return (
    <EmptyState
      icon={<OctagonAlert className="size-5 text-danger" />}
      title="حصلت مشكلة"
      action={
        onRetry && (
          <Button size="sm" variant="outline" icon={<RotateCw className="size-3.5" />} onClick={onRetry}>
            حاول تاني
          </Button>
        )
      }
    >
      {message}
    </EmptyState>
  );
}
