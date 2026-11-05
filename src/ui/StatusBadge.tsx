import { STATUS_LABELS, type DeviceStatus } from '../lib/status';
import { cn } from './cn';

/** الحالات اللي الجهاز فيها "شغّال" عليه: النقطة بتنبض بهدوء */
const LIVE: readonly DeviceStatus[] = ['inspecting', 'in_repair'];

export function StatusBadge({ status, size = 'md', className }: { status: DeviceStatus; size?: 'sm' | 'md'; className?: string }) {
  const color = `var(--st-${status})`;
  return (
    <span
      className={cn(
        'inline-flex items-center gap-1.5 whitespace-nowrap rounded-full border font-medium',
        size === 'sm' ? 'h-5 px-2 text-2xs' : 'h-6 px-2.5 text-xs',
        className,
      )}
      style={{
        color,
        backgroundColor: `color-mix(in srgb, ${color} 12%, transparent)`,
        borderColor: `color-mix(in srgb, ${color} 28%, transparent)`,
      }}
    >
      <span className="relative flex size-1.5" aria-hidden>
        {LIVE.includes(status) && (
          <span className="absolute inline-flex size-full animate-ping rounded-full opacity-60" style={{ backgroundColor: color }} />
        )}
        <span className="relative inline-flex size-1.5 rounded-full" style={{ backgroundColor: color }} />
      </span>
      {STATUS_LABELS[status]}
    </span>
  );
}
