import { describe, expect, it } from 'vitest';
import { chunks, parseCustomersCsv } from './customersCsv';

describe('استيراد العملاء من CSV', () => {
  it('عناوين عربي (زي ملف التصدير)، والموبايل بيتوحّد، والمنطقة اختيارية', () => {
    const r = parseCustomersCsv('العميل,الموبايل,المنطقة\nأحمد علي,01012345678,المعادي\nسارة,+20 111 222 3333,\n');
    expect(r.missingHeaders).toEqual([]);
    expect(r.errors).toEqual([]);
    expect(r.rows).toEqual([
      { line: 2, name: 'أحمد علي', phone: '01012345678', area: 'المعادي' },
      { line: 3, name: 'سارة', phone: '01112223333', area: null },
    ]);
  });

  it('عناوين إنجليزي بأي حروف، وفاصل ; وعلامة BOM، وعمود العنوان', () => {
    const r = parseCustomersCsv('\uFEFFName;Mobile;Address\nMona;01299998888;Giza');
    expect(r.rows).toEqual([{ line: 2, name: 'Mona', phone: '01299998888', area: 'Giza' }]);
  });

  it('أرقام عربي في الموبايل', () => {
    const r = parseCustomersCsv('الاسم,التليفون\nكريم,٠١٥٥٥٥٥٥٥٥٥');
    expect(r.rows[0]).toMatchObject({ name: 'كريم', phone: '01555555555' });
  });

  it('صف من غير اسم، وموبايل غلط: بيرجعوا بالسبب ورقم السطر، والباقي بيدخل', () => {
    const r = parseCustomersCsv('name,phone\n,01012345678\nعلي,0101234\nعلي,02123456789\nتمام,01098765432');
    expect(r.errors.map((e) => [e.line, e.reason])).toEqual([
      [2, 'name'],
      [3, 'phone'],
      [4, 'phone'],
    ]);
    expect(r.rows.map((x) => x.name)).toEqual(['تمام']);
  });

  it('المكرر في الملف: أول مرة بس، حتى لو مكتوب بشكل تاني', () => {
    const r = parseCustomersCsv('name,phone\nأ,01012345678\nب,+201012345678\nج,٠١٠١٢٣٤٥٦٧٨');
    expect(r.rows.map((x) => x.name)).toEqual(['أ']);
    expect(r.errors.map((e) => e.reason)).toEqual(['dupFile', 'dupFile']);
  });

  it('العميل الموجود في المحل بيتخطى', () => {
    const r = parseCustomersCsv('name,phone\nقديم,01012345678\nجديد,01112345678', new Set(['01012345678']));
    expect(r.rows.map((x) => x.name)).toEqual(['جديد']);
    expect(r.errors).toEqual([{ line: 2, reason: 'exists', name: 'قديم', phone: '01012345678' }]);
  });

  it('ملف من غير عمود الاسم أو الموبايل: مفيش صفوف، والسبب واضح. والملف الفاضي ما بيوقعش', () => {
    expect(parseCustomersCsv('city,notes\nx,y')).toEqual({
      rows: [],
      errors: [],
      missingHeaders: ['name', 'phone'],
    });
    expect(parseCustomersCsv('name\nعلي').missingHeaders).toEqual(['phone']);
    expect(parseCustomersCsv('')).toEqual({
      rows: [],
      errors: [],
      missingHeaders: [],
    });
  });

  it('الاسم الطويل جدًا غلط، والمسافات الزيادة بتتشال', () => {
    const r = parseCustomersCsv(`name,phone\n${'x'.repeat(121)},01012345678\n"  محمد   حسن ",01112345678`);
    expect(r.errors[0]).toMatchObject({ line: 2, reason: 'name' });
    expect(r.rows[0].name).toBe('محمد حسن');
  });

  it('الدفعات: 250 ← 100 و100 و50', () => {
    expect(
      chunks(
        Array.from({ length: 250 }, (_, i) => i),
        100,
      ).map((c) => c.length),
    ).toEqual([100, 100, 50]);
    expect(chunks([], 100)).toEqual([]);
    expect(() => chunks([1], 0)).toThrow();
  });
});
