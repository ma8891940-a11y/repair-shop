import { describe, expect, it } from 'vitest';
import { readFileSync } from 'node:fs';
import { AREA_ROLES, AREAS, canUse, DEFAULT_ASSISTANT, readAssistant } from './assistantSettings';

const sql = readFileSync(new URL('../../supabase/migrations/0033_assistant.sql', import.meta.url), 'utf8');

describe('إعدادات المساعد', () => {
  it('الافتراضي هنا = الافتراضي في قاعدة البيانات (المالية مقفولة)', () => {
    for (const a of AREAS) {
      const m = new RegExp(`'${a}', coalesce\\(\\(a -> 'areas' ->> '${a}'\\)::boolean, (true|false)\\)`).exec(sql);
      expect(m, a).not.toBeNull();
      expect(m![1] === 'true', a).toBe(DEFAULT_ASSISTANT.areas[a]);
    }
    expect(DEFAULT_ASSISTANT.areas.finance).toBe(false);
  });
  it('الأدوار هنا = الأدوار في قاعدة البيانات', () => {
    for (const a of AREAS) {
      const m = new RegExp(`when '${a}' then array\\[([^\\]]+)\\]`).exec(sql);
      expect(m, a).not.toBeNull();
      expect(m![1].replace(/'/g, '').split(',').map((x) => x.trim())).toEqual(AREA_ROLES[a]);
    }
  });
  it('القراءة: القيم الغلط بترجع للافتراضي، والفني مش بيوصل للمالية حتى لو اتفتحت', () => {
    const s = readAssistant({ assistant: { enabled: 'yes', areas: { finance: true, tech: 0 }, staff: { technician: false }, daily: -3 } });
    expect(s.enabled).toBe(true);
    expect(s.areas.finance).toBe(true);
    expect(s.areas.tech).toBe(true);
    expect(s.daily).toBeNull();
    expect(canUse(s, 'finance', 'owner')).toBe(true);
    expect(canUse(s, 'finance', 'technician')).toBe(false);
    expect(canUse(s, 'tech', 'technician')).toBe(false);
    expect(canUse(s, 'intake', 'reception')).toBe(true);
    expect(canUse({ ...s, enabled: false }, 'tech', 'owner')).toBe(false);
    expect(readAssistant({ assistant: { daily: 7.8 } }).daily).toBe(7);
  });
});
