import { Hammer } from 'lucide-react';
import { PageHeader } from '../app/AppShell';
import { Panel } from '../ui/Panel';
import { EmptyState } from '../ui/Feedback';

/** مؤقت لحد ما الشاشة تتبني (بعد موافقة التصميم) */
export function PendingScreen({ title }: { title: string }) {
  return (
    <div>
      <PageHeader title={title} />
      <Panel>
        <EmptyState icon={<Hammer className="size-5" />} title="الشاشة دي لسه بتتبني">
          هتكون جاهزة بعد موافقتك على التصميم.
        </EmptyState>
      </Panel>
    </div>
  );
}
