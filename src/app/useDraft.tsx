import { useEffect, useRef, useState } from 'react';
import { useTranslation } from 'react-i18next';
import { History } from 'lucide-react';
import { clearDraft, hasContent, loadDraft, saveDraft, type Draft } from '../lib/draft';
import { useFormat } from '../i18n/format';
import { Button } from '../ui/Button';

/**
 * البند 9: حفظ تلقائي للمسودة على الجهاز وانت بتكتب (كل نص ثانية). لو فيه مسودة قديمة ما اتحفظتش،
 * بتظهر في شريط "رجّعها / امسحها" (ما بترجعش لوحدها). الكتابة الجديدة بتتحفظ عادي، والقديمة فاضلة في الشريط لحد ما تقرر.
 */
export function useDraft<T>(key: string, value: T, enabled = true, filled = hasContent(value)) {
  const [pending, setPending] = useState<Draft<T> | null>(() => {
    const d = loadDraft<T>(key);
    return d ? d : null;
  });
  const json = JSON.stringify(value);
  const first = useRef(true);
  // الحفظ المتأخر (نص ثانية): بيتلغي مع "clear" عشان ما يرجّعش المسودة بعد الحفظ الناجح
  const timer = useRef<ReturnType<typeof setTimeout> | null>(null);
  useEffect(() => {
    // أول رسم: الفورم فاضي، فما نمسحش المسودة القديمة قبل ما المستخدم يقرر
    if (first.current) {
      first.current = false;
      return;
    }
    if (!enabled) return;
    const tm = setTimeout(() => {
      timer.current = null;
      if (filled) saveDraft(key, value);
      else if (!pending) clearDraft(key);
    }, 500);
    timer.current = tm;
    return () => clearTimeout(tm);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [key, json, enabled, filled]);
  return {
    pending,
    /** بيرجّع المسودة القديمة (والشريط بيختفي) */
    take(): T | null {
      const v = pending?.value ?? null;
      setPending(null);
      return v;
    },
    discard() {
      if (!filled) clearDraft(key);
      setPending(null);
    },
    /** بعد الحفظ الناجح */
    clear() {
      if (timer.current) clearTimeout(timer.current);
      timer.current = null;
      clearDraft(key);
      setPending(null);
    },
  };
}

export function DraftBanner({ at, onRestore, onDiscard }: { at: number; onRestore: () => void; onDiscard: () => void }) {
  const { t } = useTranslation();
  const f = useFormat();
  return (
    <div className="glass mb-3 flex flex-wrap items-center gap-3 rounded-lg border-[color-mix(in_srgb,var(--warn)_40%,var(--glass-border))] p-3" role="status" data-testid="draft-banner">
      <History className="size-4 shrink-0 text-warn" aria-hidden />
      <span className="min-w-0 flex-1 text-sm text-fg">{t('draft.found', { at: f.dateTime(new Date(at)) })}</span>
      <Button size="sm" variant="primary" onClick={onRestore} data-testid="draft-restore">
        {t('draft.restore')}
      </Button>
      <Button size="sm" variant="ghost" onClick={onDiscard} data-testid="draft-discard">
        {t('draft.discard')}
      </Button>
    </div>
  );
}
