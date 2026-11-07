import { createElement, lazy, useState, type ComponentType } from 'react';

/**
 * شاشة بتتحمّل لوحدها (ملف منفصل)، ومعاها preload() عشان تتحمّل في الخلفية قبل ما تتفتح.
 * لو اتحمّلت خلاص، بتظهر على طول من غير أي لحظة تحميل (React.lazy لوحده بيستنى خطوة حتى لو الملف جاهز).
 */
// eslint-disable-next-line @typescript-eslint/no-explicit-any
type AnyComponent = ComponentType<any>;
export type LazyScreen<C extends AnyComponent> = C & { preload: () => Promise<void> };

export function lazyScreen<C extends AnyComponent>(load: () => Promise<C>): LazyScreen<C> {
  let mod: C | undefined;
  let pending: Promise<void> | undefined;
  const preload = () =>
    (pending ??= load().then(
      (m) => {
        mod = m;
      },
      (e) => {
        // لو التحميل فشل (النت قطع مثلًا) نسمح بمحاولة تانية
        pending = undefined;
        throw e;
      },
    ));
  const Lazy = lazy(() => preload().then(() => ({ default: mod! })));
  // كل شاشة مفتوحة بتفضل على نفس الشكل اللي اتفتحت بيه لحد ما تتقفل: لو اتبدّلت من Lazy للملف نفسه وسط الشغل،
  // React هيعتبرها شاشة جديدة ويمسح اللي اتكتب فيها
  const Screen = (props: object) => {
    const [C] = useState<AnyComponent>(() => (mod ?? Lazy) as AnyComponent);
    return createElement(C, props);
  };
  return Object.assign(Screen, { preload }) as unknown as LazyScreen<C>;
}

/** بيشغّل الحاجة لما الجهاز يفضى (أو بعد شوية لو المتصفح ما بيدعمش requestIdleCallback) */
export function whenIdle(fn: () => void, timeout = 1500) {
  const w = window as Window & { requestIdleCallback?: (cb: () => void, o?: { timeout: number }) => number };
  if (w.requestIdleCallback) w.requestIdleCallback(fn, { timeout });
  else setTimeout(fn, 200);
}
