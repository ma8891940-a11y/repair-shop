import { describe, expect, it } from 'vitest';
import { assistantState } from './assistantStatus';

describe('حالة المساعد الذكي', () => {
  it('شغال، ومحتاج مفتاح، والدالة مش منشورة، ومن غير نت', () => {
    expect(assistantState({ data: { enabled: true }, online: true })).toBe('on');
    expect(assistantState({ data: { enabled: false }, online: true })).toBe('no-key');
    expect(assistantState({ status: 503, online: true })).toBe('no-key');
    expect(assistantState({ status: 404, online: true })).toBe('no-function');
    expect(assistantState({ networkError: true, online: true })).toBe('no-function');
    expect(assistantState({ data: { enabled: true }, online: false })).toBe('offline');
  });
});
