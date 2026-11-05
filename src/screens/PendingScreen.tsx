import { useTranslation } from 'react-i18next';
import { PageHeader } from '../app/AppShell';
import { Panel } from '../ui/Panel';
import { EmptyState } from '../ui/Feedback';

/** مؤقت لحد ما الشاشة تتبني (بعد موافقة التصميم) */
export function PendingScreen({ titleKey }: { titleKey: string }) {
  const { t } = useTranslation();
  return (
    <div>
      <PageHeader title={t(titleKey)} />
      <Panel>
        <EmptyState line="tool" title={t('shell.pending')}>
          {t('shell.pendingHint')}
        </EmptyState>
      </Panel>
    </div>
  );
}
