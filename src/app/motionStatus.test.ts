import { describe, expect, it } from 'vitest';
import { guardAllowed, isSoftwareRenderer, motionReasons } from './motionStatus';

describe('أسباب وقوف حركة الخلفية', () => {
  it('كارت الشاشة: الرسم بالمعالج بيتعرف من اسمه', () => {
    for (const r of ['Google SwiftShader', 'ANGLE (Google, Vulkan 1.3.0 (SwiftShader Device (Subzero)), SwiftShader driver)', 'llvmpipe (LLVM 15.0.7, 256 bits)', 'Microsoft Basic Render Driver'])
      expect(isSoftwareRenderer(r), r).toBe(true);
    for (const r of ['ANGLE (Intel, Intel(R) UHD Graphics 770 Direct3D11 vs_5_0 ps_5_0, D3D11)', 'ANGLE (NVIDIA, NVIDIA GeForce RTX 3060)', 'Apple M2', '', null])
      expect(isSoftwareRenderer(r), String(r)).toBe(false);
  });
  it('الأسباب بالترتيب: تقليل الحركة، والتثبيت التلقائي، وتسريع الرسومات', () => {
    expect(motionReasons({ reduced: false, autoStill: false, software: false })).toEqual([]);
    expect(motionReasons({ reduced: false, autoStill: false, software: null })).toEqual([]);
    expect(motionReasons({ reduced: true, autoStill: true, software: true })).toEqual(['reduced', 'auto', 'software']);
    expect(motionReasons({ reduced: false, autoStill: true, software: false })).toEqual(['auto']);
  });
  it('حارس الأداء ما بيشتغلش في npm run dev (إلا للاختبارات بمفتاح خاص)', () => {
    expect(import.meta.env.DEV).toBe(true);
    expect(guardAllowed()).toBe(false);
  });
});
