import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { deferUndoable, UNDO_MS } from './undo';

describe('تراجع: الحذف بيستنى شوية قبل ما يتنفذ', () => {
  beforeEach(() => vi.useFakeTimers());
  afterEach(() => vi.useRealTimers());

  it('من غير تراجع: بيتنفذ مرة واحدة بعد المدة', () => {
    const run = vi.fn();
    const d = deferUndoable(run, UNDO_MS, null);
    vi.advanceTimersByTime(UNDO_MS - 1);
    expect(run).not.toHaveBeenCalled();
    vi.advanceTimersByTime(1);
    expect(run).toHaveBeenCalledTimes(1);
    expect(d.undo()).toBe(false);
    d.flush();
    expect(run).toHaveBeenCalledTimes(1);
  });

  it('تراجع قبل المدة: ما بيتنفذش خالص', () => {
    const run = vi.fn();
    const d = deferUndoable(run, UNDO_MS, null);
    vi.advanceTimersByTime(2000);
    expect(d.undo()).toBe(true);
    vi.advanceTimersByTime(UNDO_MS * 2);
    expect(run).not.toHaveBeenCalled();
    expect(d.state).toBe('undone');
  });

  it('قفل الصفحة قبل المدة: بيتنفذ على طول عشان ما يضيعش', () => {
    const run = vi.fn();
    const ev = new EventTarget();
    deferUndoable(run, UNDO_MS, ev as unknown as Window);
    ev.dispatchEvent(new Event('pagehide'));
    expect(run).toHaveBeenCalledTimes(1);
    vi.advanceTimersByTime(UNDO_MS);
    expect(run).toHaveBeenCalledTimes(1);
  });
});
