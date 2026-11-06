// بيولّد ملفات العلامة (SVG) من شبكة هندسية: الرموز الثلاثة، والاسم بالعربي والإنجليزي مرسوم بخطوط (مش نص)، والتركيبات.
// الاستخدام: node brand/build.mjs
// كل الرموز على شبكة 48×48 بوحدة 4، وسُمك الخط 3.5 (بيتقل لـ 4.5 في المقاسات الصغيرة).
import { mkdirSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';

const OUT = join(process.cwd(), 'brand', 'concepts');
mkdirSync(OUT, { recursive: true });

const ACCENT = '#38d6f0';
const rad = (deg) => (deg * Math.PI) / 180;
const pt = (cx, cy, r, deg) => [+(cx + r * Math.cos(rad(deg))).toFixed(2), +(cy + r * Math.sin(rad(deg))).toFixed(2)];

// ---------------- الرموز ----------------
// كل رمز: body (خطوط بلون العلامة) + mark (نقطة الإبراز: سماوي في النسخة الملونة، ونفس اللون في النسخة الواحدة)
const symbols = {
  // أ) المعيار: دايرة معايرة مفتوحة عند نقطة واحدة، ومؤشر ثابت عليها بالظبط. "مضبوط على العلامة"
  dial: (sw) => {
    const [x1, y1] = pt(24, 24, 17, -50);
    const [x2, y2] = pt(24, 24, 17, -100);
    const [nx, ny] = pt(24, 24, 17, -75);
    const [kx, ky] = pt(24, 24, 9.5, -75);
    return {
      body: `<path d="M${x1} ${y1}A17 17 0 1 1 ${x2} ${y2}" fill="none" stroke="currentColor" stroke-width="${sw}" stroke-linecap="round"/>
<path d="M24 24L${kx} ${ky}" stroke="currentColor" stroke-width="${sw}" stroke-linecap="round"/>
<circle cx="24" cy="24" r="${sw * 0.95}" fill="currentColor"/>`,
      mark: `<circle cx="${nx}" cy="${ny}" r="${sw * 0.95}" fill="MARK"/>`,
    };
  },
  // ب) المسار: خط دايرة إلكترونية واحد متصل بزوايا 45° بيكوّن W، بنقطتين لحام في الطرفين. "كل جهاز ماشي في مسار محسوب"
  trace: (sw) => ({
    body: `<path d="M9 9V29L16 36L24 28L32 36L39 29V9" fill="none" stroke="currentColor" stroke-width="${sw}" stroke-linecap="round" stroke-linejoin="round"/>
<circle cx="9" cy="9" r="${sw * 1.05}" fill="none" stroke="currentColor" stroke-width="${sw * 0.7}"/>`,
    mark: `<circle cx="39" cy="9" r="${sw * 1.05}" fill="MARK"/>`,
  }),
  // ج) البؤرة: أربع زوايا إطار فحص حوالين نقطة واحدة في النص. "الجهاز تحت العدسة: كل تفصيلة متشافة"
  focus: (sw) => ({
    body: `<path d="M8 17V12A4 4 0 0 1 12 8H17M31 8H36A4 4 0 0 1 40 12V17M40 31V36A4 4 0 0 1 36 40H31M17 40H12A4 4 0 0 1 8 36V31" fill="none" stroke="currentColor" stroke-width="${sw}" stroke-linecap="round" stroke-linejoin="round"/>`,
    mark: `<rect x="${24 - sw * 1.2}" y="${24 - sw * 1.2}" width="${sw * 2.4}" height="${sw * 2.4}" rx="${sw * 0.35}" transform="rotate(45 24 24)" fill="MARK"/>`,
  }),
};
const MEANING = {
  dial: 'المعيار: دايرة معايرة مفتوحة عند نقطة واحدة، والمؤشر ثابت عليها بالظبط. معناها "كل جهاز بيتظبط على العلامة": دقة القياس والثقة.',
  trace: 'المسار: خط دايرة إلكترونية واحد بزوايا 45° بيرسم حرف W، ونقطتين لحام في الطرفين. معناها "كل جهاز ماشي في مسار محسوب من الاستلام للتسليم".',
  focus: 'البؤرة: أربع زوايا إطار فحص حوالين نقطة واحدة. معناها "الجهاز تحت العدسة": الفحص الدقيق وإن مفيش تفصيلة بتفوت.',
};

// ---------------- الاسم (مرسوم بخطوط على شبكة) ----------------
// العربي "ورشة" بخط هندسي أحادي السُمك (كوفي مبسّط) على خط أساس y=30، والجسم من y=18. يتقرأ من اليمين للشمال.
function wordAr(sw = 3.2) {
  const s = `stroke="currentColor" stroke-width="${sw}" stroke-linecap="round" stroke-linejoin="round" fill="none"`;
  const dot = (x, y) => `<rect x="${x - sw * 0.6}" y="${y - sw * 0.6}" width="${sw * 1.2}" height="${sw * 1.2}" rx="${sw * 0.25}" fill="currentColor"/>`;
  return {
    w: 76,
    svg: [
      // و: رأس دايري ونزلة تحت خط الأساس
      `<path d="M72 30V22A4 4 0 0 0 64 22A4 4 0 0 0 68 26H72V31Q72 37 64 39" ${s}/>`,
      // ر
      `<path d="M57 24V31Q57 37 50 39" ${s}/>`,
      // شـ: تلات أسنان على خط الأساس متصلة بالتاء المربوطة
      `<path d="M43 24V30H37V24M37 30H31V24M31 30H22" ${s}/>`,
      dot(37, 13), dot(32.5, 13), dot(34.75, 9),
      // ة: حلقة مقفولة في الآخر
      `<path d="M22 30H10A4 4 0 0 1 6 26V24A4 4 0 0 1 10 20H14A4 4 0 0 1 18 24V30" ${s}/>`,
      dot(9.5, 13), dot(14.5, 13),
    ].join('\n'),
  };
}
// الإنجليزي "WARSHA" بحروف كبيرة هندسية بنفس السُمك، ارتفاعها = جسم العربي (y=18..30)
function wordEn(sw = 3.2) {
  const s = `stroke="currentColor" stroke-width="${sw}" stroke-linecap="round" stroke-linejoin="round" fill="none"`;
  const y0 = 18;
  const y1 = 30;
  const parts = [
    `<path d="M2 ${y0}L5 ${y1}L8.5 ${y0 + 5}L12 ${y1}L15 ${y0}" ${s}/>`, // W (الوسط أقصر، زي المسار)
    `<path d="M19 ${y1}L23.5 ${y0}L28 ${y1}" ${s}/><circle cx="23.5" cy="${y1 - 4.2}" r="${sw * 0.55}" fill="currentColor"/>`, // A بنقطة بدل الشَرطة
    `<path d="M32 ${y1}V${y0}H36.5A3.5 3.5 0 0 1 36.5 ${y0 + 7}H32M36 ${y0 + 7}L40 ${y1}" ${s}/>`, // R
    `<path d="M51 ${y0 + 1.5}Q49.5 ${y0} 47 ${y0}Q43.5 ${y0} 43.5 ${y0 + 3}Q43.5 ${y0 + 5.8} 47.3 ${y0 + 6}Q51.2 ${y0 + 6.3} 51.2 ${y0 + 9}Q51.2 ${y1} 47.3 ${y1}Q44.5 ${y1} 43 ${y1 - 1.8}" ${s}/>`, // S
    `<path d="M55 ${y0}V${y1}M63 ${y0}V${y1}M55 ${y0 + 6}H63" ${s}/>`, // H
    `<path d="M67 ${y1}L71.5 ${y0}L76 ${y1}" ${s}/><circle cx="71.5" cy="${y1 - 4.2}" r="${sw * 0.55}" fill="currentColor"/>`, // A
  ];
  return { w: 78, svg: parts.join('\n') };
}

// ---------------- التركيب ----------------
const svgWrap = (w, h, inner, extra = '') => `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ${w} ${h}" width="${w}" height="${h}"${extra}>\n${inner}\n</svg>\n`;
function symbolSvg(name, { mono = false, sw = 3.5, size = 48 } = {}) {
  const s = symbols[name](sw);
  return svgWrap(48, 48, `${s.body}\n${s.mark.replace('MARK', mono ? 'currentColor' : ACCENT)}`, size !== 48 ? ` style="width:${size}px;height:${size}px"` : '');
}
function lockup(name, lang, { mono = false } = {}) {
  const s = symbols[name](3.5);
  const word = lang === 'ar' ? wordAr() : wordEn();
  const gap = 10;
  const W = 48 + gap + word.w;
  // الرمز في الأول حسب اتجاه القراءة: يمين للعربي، وشمال للإنجليزي. والاسم متوسّط رأسيًا مع الرمز
  const sym = `<g>${s.body}\n${s.mark.replace('MARK', mono ? 'currentColor' : ACCENT)}</g>`;
  const wordG = `<g transform="translate(${lang === 'ar' ? 0 : 48 + gap} 0)">${word.svg}</g>`;
  const symG = lang === 'ar' ? `<g transform="translate(${word.w + gap} 0)">${sym}</g>` : sym;
  return svgWrap(W, 48, `${symG}\n${wordG}`);
}
// أيقونة التطبيق (maskable): الرمز جوه منطقة الأمان (80%) على خلفية graphite
function appIcon(name) {
  const s = symbols[name](4);
  return svgWrap(512, 512, `<rect width="512" height="512" fill="#0f1418"/>\n<g transform="translate(256 256) scale(6.4) translate(-24 -24)" color="#e9eef2">${s.body}\n${s.mark.replace('MARK', ACCENT)}</g>`);
}
// أيقونة المتصفح 16/32: خط أتقل عشان يتقري
function favicon(name) {
  const s = symbols[name](5);
  return svgWrap(48, 48, `<rect width="48" height="48" rx="10" fill="#0f1418"/>\n<g color="#e9eef2" transform="translate(24 24) scale(0.86) translate(-24 -24)">${s.body}\n${s.mark.replace('MARK', ACCENT)}</g>`);
}

const files = {};
for (const n of Object.keys(symbols)) {
  files[`${n}-symbol.svg`] = symbolSvg(n);
  files[`${n}-symbol-mono.svg`] = symbolSvg(n, { mono: true });
  files[`${n}-ar.svg`] = lockup(n, 'ar');
  files[`${n}-en.svg`] = lockup(n, 'en');
  files[`${n}-ar-mono.svg`] = lockup(n, 'ar', { mono: true });
  files[`${n}-en-mono.svg`] = lockup(n, 'en', { mono: true });
  files[`${n}-app-512.svg`] = appIcon(n);
  files[`${n}-favicon.svg`] = favicon(n);
}
for (const [f, c] of Object.entries(files)) writeFileSync(join(OUT, f), c);
writeFileSync(join(OUT, 'meaning.json'), JSON.stringify(MEANING, null, 2));
console.log(Object.keys(files).length, 'files');
export { files, MEANING };
