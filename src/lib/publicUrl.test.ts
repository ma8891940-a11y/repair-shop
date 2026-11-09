import { describe, expect, it } from 'vitest';
import { appBase, cleanBase, readPublicUrl, urlProblem } from './publicUrl';
import { fillTemplate, linkOnOwnLine, trackingUrl } from './messages';

// البند 12: رابط البرنامج العام، والتنبيه لو localhost، ورابط التتبع في سطر لوحده
describe('رابط البرنامج العام', () => {
  it('https عام بس هو اللي ينفع للعميل', () => {
    expect(urlProblem('https://gawalak.pages.dev')).toBeNull();
    expect(urlProblem('https://my-shop.netlify.app/')).toBeNull();
    for (const u of ['http://localhost:5173', 'https://127.0.0.1', 'http://192.168.1.5:5173', 'https://10.0.0.2', 'https://172.20.1.1', 'https://myshop.local', 'https://intranet']) expect(urlProblem(u), u).toBe('local');
    expect(urlProblem('http://gawalak.pages.dev')).toBe('notHttps');
    for (const u of ['', 'gawalak', 'ftp://x.com', 'file:///C:/app/index.html']) expect(urlProblem(u), u).toBe('bad');
  });
  it('من غير الرابط العام بيستخدم العنوان الحالي، ومعاه بيستخدمه هو', () => {
    expect(cleanBase('https://a.dev/app/#/devices?x=1')).toBe('https://a.dev/app');
    expect(appBase({}, 'http://localhost:5173/#/devices')).toBe('http://localhost:5173');
    expect(appBase({ public_url: 'https://gawalak.pages.dev/' }, 'http://localhost:5173/#/x')).toBe('https://gawalak.pages.dev');
    expect(readPublicUrl({ public_url: 'http://localhost' })).toBe('');
    expect(trackingUrl(appBase({ public_url: 'https://g.dev' }, 'x'), 'abc')).toBe('https://g.dev/#/t/abc');
  });
  it('رابط التتبع في سطر لوحده في الرسالة', () => {
    const link = 'https://g.dev/#/t/abc';
    expect(fillTemplate('تقدر تتابعه من هنا: {link}\n{shop}', { link, shop: 'محل' })).toBe(`تقدر تتابعه من هنا:\n${link}\nمحل`);
    expect(fillTemplate('التفاصيل: {link}', { link })).toBe(`التفاصيل:\n${link}`);
    expect(fillTemplate('{link} شكرًا', { link })).toBe(`${link}\nشكرًا`);
    expect(linkOnOwnLine('من غير رابط', link)).toBe('من غير رابط');
    expect(fillTemplate('أهلًا {name}', { name: 'سامح' })).toBe('أهلًا سامح');
  });
});
