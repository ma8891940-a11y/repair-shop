import { useState } from 'react';
import { useTranslation } from 'react-i18next';
import { PageHeader } from '../app/AppShell';
import { AssistantPanel } from '../app/AssistantPanel';
import { Panel } from '../ui/Panel';
import { Field, Input, Textarea } from '../ui/Field';

/**
 * المساعد الذكي في صفحة لوحده (من القايمة الجانبية): للفني وصاحب المحل. نفس المساعد اللي في صفحة كل جهاز،
 * بس هنا تكتب الموديل والعطل بنفسك. ولو مش شغال، بيقول السبب بالظبط وخطوات الحل (مش بيختفي).
 */
export function AssistantScreen() {
  const { t } = useTranslation();
  const [brand, setBrand] = useState('');
  const [model, setModel] = useState('');
  const [issue, setIssue] = useState('');
  return (
    <div className="max-w-3xl">
      <PageHeader title={t('assistant.pageTitle')} sub={t('assistant.pageSub')} />
      <Panel className="mb-3 grid gap-3 p-4 sm:grid-cols-2">
        <Field label={t('intake.brand')}>
          <Input value={brand} onChange={(e) => setBrand(e.target.value)} maxLength={40} data-testid="assistant-brand" />
        </Field>
        <Field label={t('intake.model')}>
          <Input value={model} onChange={(e) => setModel(e.target.value)} maxLength={60} data-testid="assistant-model" />
        </Field>
        <Field label={t('assistant.issue')} className="sm:col-span-2">
          <Textarea rows={3} maxLength={500} value={issue} onChange={(e) => setIssue(e.target.value)} data-testid="assistant-issue" />
        </Field>
      </Panel>
      <AssistantPanel brand={brand} model={model} issue={issue} names={[]} />
    </div>
  );
}
