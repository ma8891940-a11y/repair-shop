import { describe, expect, it } from 'vitest';
import { FLOW_BLOCKS, templateError, type PrintDoc } from './printLayout';
import { TEMPLATE_CASES } from './printLayoutCases';
import { DOC_BLOCKS, defaultBlocks, normalizeBlocks, type TemplateDoc } from './printTemplate';

describe('نموذج القالب (50.2)', () => {
  it.each(TEMPLATE_CASES.map((c) => [`${c.mode}: ${c.name}`, c] as const))('%s', (_n, c) => {
    expect(templateError(c.doc, c.mode, c.blocks, c.layout)).toBe(c.error);
  });
  it('خانات flow هي نفس خانات المصمم + نص حر', () => {
    for (const [doc, keys] of Object.entries(DOC_BLOCKS)) expect(FLOW_BLOCKS[doc as PrintDoc]).toEqual([...keys, 'text']);
  });
  it('كل قالب قديم بيعدّي الفحص وبيطلع زي ما هو', () => {
    for (const doc of Object.keys(DOC_BLOCKS) as TemplateDoc[]) {
      const old = [...defaultBlocks(doc), { key: 'text' as const, show: true, size: 'lg' as const, align: 'end' as const, bold: true, text: 'شكرًا' }].reverse();
      expect(normalizeBlocks(doc, old)).toEqual(old);
      expect(templateError(doc, 'flow', old, {})).toBeNull();
    }
  });
});
