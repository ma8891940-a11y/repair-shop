import { useCallback, useEffect, useId, useState, useSyncExternalStore } from 'react';
import { useNavigate, type NavigateOptions, type To } from 'react-router';
import { useTranslation } from 'react-i18next';
import { Dialog } from '../ui/Dialog';
import { Button } from '../ui/Button';

/**
 * البند 9: تنبيه قبل الخروج من غير حفظ. الشاشة اللي فيها بيانات ما اتحفظتش بتقول useLeaveGuard(true)،
 * وأي خروج منها (لينك في القايمة، أو اختصار، أو لوحة الأوامر) بيسأل الأول. وقفل الصفحة أو تحديثها بيسأل المتصفح.
 * المسودة محفوظة على الجهاز في كل الحالات، فحتى لو خرج، يقدر يرجّعها.
 */
const dirty = new Set<string>();
let pending: (() => void) | null = null;
const subs = new Set<() => void>();
const emit = () => subs.forEach((f) => f());
const subscribe = (f: () => void) => {
  subs.add(f);
  return () => subs.delete(f);
};

export function isDirty(): boolean {
  return dirty.size > 0;
}

/** لو فيه بيانات ما اتحفظتش: بيسأل، وبعد الموافقة بينفذ go */
export function requestLeave(go: () => void): void {
  if (!isDirty()) return go();
  pending = go;
  emit();
}

export function useLeaveGuard(active: boolean) {
  const id = useId();
  useEffect(() => {
    if (!active) return;
    dirty.add(id);
    const onUnload = (e: BeforeUnloadEvent) => {
      e.preventDefault();
      e.returnValue = '';
    };
    window.addEventListener('beforeunload', onUnload);
    return () => {
      dirty.delete(id);
      window.removeEventListener('beforeunload', onUnload);
    };
  }, [active, id]);
}

/** التنقل من القايمة والاختصارات ولوحة الأوامر: بيسأل لو فيه حاجة ما اتحفظتش */
export function useGuardedNavigate() {
  const navigate = useNavigate();
  return useCallback((to: To, o?: NavigateOptions) => requestLeave(() => navigate(to, o)), [navigate]);
}

/** في AppShell: نافذة التأكيد، واللينكات (#/...) اللي بتتداس وفيه بيانات ما اتحفظتش */
export function LeaveGuardHost() {
  const { t } = useTranslation();
  const navigate = useNavigate();
  const ask = useSyncExternalStore(subscribe, () => pending);
  const [, force] = useState(0);
  useEffect(() => {
    const onClick = (e: MouseEvent) => {
      if (!isDirty() || e.defaultPrevented || e.button !== 0 || e.metaKey || e.ctrlKey || e.shiftKey || e.altKey) return;
      const a = (e.target as Element | null)?.closest?.('a[href]') as HTMLAnchorElement | null;
      if (!a || a.target === '_blank') return;
      const href = a.getAttribute('href') ?? '';
      if (!href.startsWith('#/')) return;
      e.preventDefault();
      e.stopPropagation();
      requestLeave(() => navigate(href.slice(1)));
    };
    document.addEventListener('click', onClick, true);
    return () => document.removeEventListener('click', onClick, true);
  }, [navigate]);
  const close = () => {
    pending = null;
    emit();
    force((n) => n + 1);
  };
  return (
    <Dialog
      open={!!ask}
      onOpenChange={(v) => !v && close()}
      title={t('leave.title')}
      description={t('leave.text')}
      footer={
        <>
          <Button variant="primary" onClick={close} data-testid="leave-stay">
            {t('leave.stay')}
          </Button>
          <Button
            variant="danger"
            onClick={() => {
              const go = pending;
              dirty.clear();
              close();
              go?.();
            }}
            data-testid="leave-go"
          >
            {t('leave.go')}
          </Button>
        </>
      }
    />
  );
}
