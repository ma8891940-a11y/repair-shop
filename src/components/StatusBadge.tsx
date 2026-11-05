import { STATUS_LABELS, type DeviceStatus } from '../lib/status';

export function StatusBadge({ status }: { status: DeviceStatus }) {
  return <span className={`badge st-${status}`}>{STATUS_LABELS[status]}</span>;
}
