import { describe, expect, it } from 'vitest';
import { backupSummary, decryptBackup, encryptBackup } from './backupCrypto';

const sample = { format: 'warsha-backup', shop_id: 's', devices: [{ id: 1, issue: 'شاشة مكسورة' }], customers: [{ id: 2 }, { id: 3 }] };

describe('تشفير النسخة الاحتياطية', () => {
  it('بيتفك بنفس كلمة السر بالظبط، وما فيهوش البيانات كنص واضح', async () => {
    const f = await encryptBackup(sample, 'كلمة-سر-قوية-1', 1000);
    expect(f.format).toBe('gawalak-backup-enc');
    expect(JSON.stringify(f)).not.toContain('شاشة');
    expect(await decryptBackup(f, 'كلمة-سر-قوية-1')).toEqual(sample);
  });
  it('النسخ القديمة (قبل تغيير اسم التطبيق) بتتفتح برضه', async () => {
    const f = await encryptBackup(sample, 'كلمة-سر-قوية-1', 1000);
    expect(await decryptBackup({ ...f, format: 'warsha-backup-enc' }, 'كلمة-سر-قوية-1')).toEqual(sample);
  });
  it('كلمة سر غلط أو ملف متعدّل: ما بيتفكش', async () => {
    const f = await encryptBackup(sample, 'password-123', 1000);
    await expect(decryptBackup(f, 'password-124')).rejects.toThrow('E_BACKUP_PASSWORD');
    const bad = { ...f, data: f.data.slice(0, -4) + (f.data.endsWith('AAAA') ? 'BBBB' : 'AAAA') };
    await expect(decryptBackup(bad, 'password-123')).rejects.toThrow('E_BACKUP_PASSWORD');
    await expect(decryptBackup({ ...f, format: 'x' } as never, 'password-123')).rejects.toThrow('E_BACKUP_FORMAT');
  });
  it('كل مرة ملح ومتجه مختلفين (نفس البيانات بتطلع مختلفة)، وكلمة السر القصيرة مرفوضة', async () => {
    const a = await encryptBackup(sample, 'password-123', 1000);
    const b = await encryptBackup(sample, 'password-123', 1000);
    expect(a.data).not.toBe(b.data);
    expect(a.salt).not.toBe(b.salt);
    await expect(encryptBackup(sample, 'short')).rejects.toThrow('E_WEAK_BACKUP_PASSWORD');
  });
  it('الملخص بيعد صفوف كل جدول', () => {
    expect(backupSummary(sample)).toEqual({ devices: 1, customers: 2 });
  });
});
