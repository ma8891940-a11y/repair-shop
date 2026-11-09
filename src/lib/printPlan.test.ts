import { describe, expect, it } from 'vitest';
import { DEFAULT_PRINT, intakeDocs, pageSize, printChain, readPrint } from './printPlan';

describe('الطباعة: يطبع إيه في كل خطوة', () => {
  it('الافتراضي: استيكر حراري وإيصال ورقي في الاستلام، وفاتورة ورقية في التسليم', () => {
    expect(readPrint(null)).toEqual(DEFAULT_PRINT);
    expect(intakeDocs(DEFAULT_PRINT)).toEqual(['sticker', 'receipt-a4']);
    expect(DEFAULT_PRINT.deliveryPaper).toBe(true);
  });
  it('مفتاح "اطبع تلقائي" القديم (auto_print) بيفضل شغال، والإعداد الجديد بيغلبه', () => {
    expect(readPrint({ auto_print: true }).autoAfterIntake).toBe(true);
    expect(readPrint({ auto_print: true, print: { autoAfterIntake: false } }).autoAfterIntake).toBe(false);
  });
  it('الترتيب ورا بعض، والمقاسات، والقيم الغلط بترجع للافتراضي', () => {
    expect(printChain('d1', ['sticker', 'receipt', 'receipt-a4'])).toBe('/print/sticker/d1?next=receipt,receipt-a4');
    expect(printChain('d1', ['receipt-a4'])).toBe('/print/receipt-a4/d1');
    expect(printChain('d1', [])).toBeNull();
    expect(pageSize('sticker', '50x30')).toBe('50mm 30mm');
    expect(pageSize('sticker', '58x40')).toBe('58mm 40mm');
    expect(pageSize('sticker', '80')).toBe('80mm auto');
    expect(pageSize('invoice', '80')).toBe('A4');
    expect(readPrint({ print: { stickerSize: '99', intakeSticker: 'yes' } })).toMatchObject({ stickerSize: '80', intakeSticker: true });
    expect(intakeDocs(readPrint({ print: { intakeSticker: false, intakePaper: false } }))).toEqual([]);
  });
});
