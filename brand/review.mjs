// صفحة مراجعة الأفكار الثلاثة: الوضعين، والأسود بس، والمقاسات 16/32/512، وعلى إيصال 80مم وأيقونة تطبيق.
// الاستخدام: node brand/build.mjs && node brand/review.mjs <مجلد الصور>
import { readFileSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';
import { createRequire } from 'node:module';

const require = createRequire(import.meta.url);
const { chromium } = require('playwright');
const DIR = join(process.cwd(), 'brand', 'concepts');
const OUT = process.argv[2] ?? DIR;
const read = (f) => readFileSync(join(DIR, f), 'utf8').replace(/<svg /, '<svg class="x" ');
const meaning = JSON.parse(readFileSync(join(DIR, 'meaning.json'), 'utf8'));
const TITLE = { dial: 'أ) المعيار', trace: 'ب) المسار', focus: 'ج) البؤرة' };

function page(n) {
  const sym = read(`${n}-symbol.svg`);
  const ar = read(`${n}-ar.svg`);
  const en = read(`${n}-en.svg`);
  const arM = read(`${n}-ar-mono.svg`);
  const symM = read(`${n}-symbol-mono.svg`);
  const fav = read(`${n}-favicon.svg`);
  const app = read(`${n}-app-512.svg`);
  return `<!doctype html><html dir="rtl"><meta charset="utf-8"><style>
  body{margin:0;font-family:'IBM Plex Sans Arabic',Tahoma,sans-serif;background:#e8edf2;color:#13181c;width:1400px}
  h1{font-size:26px;margin:0 0 4px} p.m{margin:0 0 16px;color:#3a4650;font-size:15px;max-width:1100px}
  .wrap{padding:28px}
  .row{display:grid;grid-template-columns:1fr 1fr;gap:14px;margin-bottom:14px}
  .card{border-radius:14px;padding:22px;display:flex;align-items:center;gap:28px;flex-wrap:wrap;min-height:120px}
  .dark{background:#0f1418;color:#e9eef2}.light{background:#f6f9fc;color:#13181c;border:1px solid #d5dee7}
  .lbl{font-size:12px;opacity:.7;width:100%;margin-bottom:-14px}
  .x{display:block} .s96 .x{width:96px;height:96px} .lk .x{height:64px;width:auto}
  .sizes{display:flex;align-items:end;gap:18px}.sizes .a16 .x{width:16px;height:16px}.sizes .a32 .x{width:32px;height:32px}.sizes .a96 .x{width:96px;height:96px;border-radius:22px;overflow:hidden}
  .receipt{background:#fff;color:#000;width:302px;padding:14px 12px;font-family:Tahoma;font-size:12px;border:1px solid #ccc;box-shadow:0 6px 20px rgba(0,0,0,.15)}
  .receipt .lk .x{height:40px;margin:0 auto 6px}
  .receipt hr{border:0;border-top:1px dashed #000;margin:8px 0}
  .tbl{display:grid;grid-template-columns:auto 1fr;gap:3px 10px}
  .phone{width:220px;height:150px;border-radius:26px;background:linear-gradient(#1d2a33,#0f1418);padding:16px;display:grid;grid-template-columns:repeat(4,1fr);gap:12px;align-content:start}
  .ic{width:40px;height:40px;border-radius:10px;background:#2b3a44}.ic.me{background:none}.ic.me .x{width:40px;height:40px;border-radius:10px;overflow:hidden}
  .stamp{color:#000}.stamp .x{height:44px;width:auto}
  </style><div class="wrap">
  <h1>${TITLE[n]}</h1><p class="m">${meaning[n]}</p>
  <div class="row">
    <div class="card dark"><div class="lbl">الرمز · داكن</div><div class="s96">${sym}</div><div class="lk">${ar}</div></div>
    <div class="card light"><div class="lbl">الرمز · فاتح</div><div class="s96">${sym}</div><div class="lk">${ar}</div></div>
  </div>
  <div class="row">
    <div class="card dark"><div class="lbl">الرمز مع الاسم بالإنجليزي · داكن</div><div class="lk" dir="ltr">${en}</div></div>
    <div class="card light"><div class="lbl">الرمز مع الاسم بالإنجليزي · فاتح</div><div class="lk" dir="ltr">${en}</div></div>
  </div>
  <div class="row">
    <div class="card light"><div class="lbl">أسود بس (طابعة حرارية / ختم) · لون واحد من غير تدرجات</div><div class="stamp s96">${symM}</div><div class="stamp lk">${arM}</div></div>
    <div class="card dark"><div class="lbl">المقاسات: 16 و32 (أيقونة المتصفح) و512 (أيقونة التطبيق maskable، معروضة 96)</div>
      <div class="sizes"><div class="a16">${fav}</div><div class="a32">${fav}</div><div class="a96">${app}</div></div>
      <div class="phone"><div class="ic"></div><div class="ic me">${app}</div><div class="ic"></div><div class="ic"></div><div class="ic"></div><div class="ic"></div></div></div>
  </div>
  <div class="row">
    <div class="card light" style="justify-content:center"><div class="lbl">على إيصال 80مم (أسود بس)</div>
      <div class="receipt"><div class="lk stamp">${arM}</div><div style="text-align:center;font-weight:bold">إيصال استلام جهاز</div><div style="text-align:center;font-family:monospace;font-size:18px;font-weight:bold">2026-0042</div><hr>
      <div class="tbl"><b>العميل</b><span>أحمد علي</span><b>الجهاز</b><span>Samsung A54</span><b>العطل</b><span>شاشة مكسورة</span><b>التقدير</b><span>850 ج.م</span></div><hr><div style="text-align:center;font-size:10px">امسح لمتابعة جهازك</div></div></div>
    <div class="card dark" style="justify-content:center"><div class="lbl">صفحة التتبع (موبايل)</div>
      <div style="width:300px;background:#12181c;border-radius:18px;padding:18px;border:1px solid rgba(255,255,255,.08)"><div class="lk" style="margin-bottom:14px">${ar}</div><div style="font-size:12px;opacity:.7">رقم الطلب</div><div style="font-family:monospace;font-size:22px">2026-0042</div><div style="margin-top:10px;height:6px;border-radius:3px;background:linear-gradient(90deg,#38d6f0 60%,#2b3a44 60%)"></div></div></div>
  </div></div></html>`;
}

const b = await chromium.launch();
const p = await b.newPage({ viewport: { width: 1400, height: 900 }, deviceScaleFactor: 2 });
for (const n of ['dial', 'trace', 'focus']) {
  const html = page(n);
  writeFileSync(join(DIR, `review-${n}.html`), html);
  await p.setContent(html);
  await p.screenshot({ path: join(OUT, `concept-${n}.png`), fullPage: true });
}
await b.close();
console.log('ok');
