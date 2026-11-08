// بيطلّع حدود لوجو التطبيق من شفافية الصورة نفسها (من غير ما يغيّر اللوجو): مسار SVG للحركة "رسم".
// الاستخدام: node scripts/logo-outline.cjs   ← بيكتب src/assets/app-logo-outline.json
const { chromium } = require('@playwright/test');
const fs = require('fs');
const path = require('path');
(async () => {
  const png = fs.readFileSync(path.join(__dirname, '../src/assets/app-logo.png')).toString('base64');
  const browser = await chromium.launch();
  const page = await browser.newPage();
  const out = await page.evaluate(async (b64) => {
    const img = new Image();
    img.src = `data:image/png;base64,${b64}`;
    await img.decode();
    const W = img.naturalWidth, H = img.naturalHeight;
    // شبكة أصغر للحساب، والمسار بيتكبّر لمقاس الصورة
    const S = 3;
    const w = Math.ceil(W / S), h = Math.ceil(H / S);
    const c = document.createElement('canvas');
    c.width = w; c.height = h;
    const x = c.getContext('2d');
    x.drawImage(img, 0, 0, w, h);
    const a = x.getImageData(0, 0, w, h).data;
    const on = (i, j) => i >= 0 && j >= 0 && i < w && j < h && a[(j * w + i) * 4 + 3] > 110;
    // marching squares: أجزاء خطوط على الحدود، وبعدين بنوصّلها في مسارات
    const segs = [];
    for (let j = -1; j < h; j++) for (let i = -1; i < w; i++) {
      const tl = on(i, j), tr = on(i + 1, j), br = on(i + 1, j + 1), bl = on(i, j + 1);
      const k = (tl ? 8 : 0) | (tr ? 4 : 0) | (br ? 2 : 0) | (bl ? 1 : 0);
      if (k === 0 || k === 15) continue;
      const T = [i + 0.5, j], R = [i + 1, j + 0.5], B = [i + 0.5, j + 1], L = [i, j + 0.5];
      const map = { 1: [[L, B]], 2: [[B, R]], 3: [[L, R]], 4: [[T, R]], 5: [[L, T], [B, R]], 6: [[T, B]], 7: [[L, T]], 8: [[L, T]], 9: [[T, B]], 10: [[T, R], [L, B]], 11: [[T, R]], 12: [[L, R]], 13: [[B, R]], 14: [[L, B]] };
      for (const s of map[k]) segs.push(s);
    }
    const key = (p) => `${p[0]},${p[1]}`;
    const adj = new Map();
    for (const [p, q] of segs) {
      for (const [u, v] of [[p, q], [q, p]]) { if (!adj.has(key(u))) adj.set(key(u), []); adj.get(key(u)).push(v); }
    }
    const used = new Set();
    const ek = (u, v) => key(u) < key(v) ? key(u) + '|' + key(v) : key(v) + '|' + key(u);
    const loops = [];
    for (const [p, q] of segs) {
      if (used.has(ek(p, q))) continue;
      const line = [p, q]; used.add(ek(p, q));
      let cur = q, prev = p;
      for (;;) {
        const nx = (adj.get(key(cur)) || []).find((v) => !used.has(ek(cur, v)));
        if (!nx) break;
        used.add(ek(cur, nx)); line.push(nx); prev = cur; cur = nx;
      }
      if (line.length > 25) loops.push(line);
    }
    // تبسيط (Ramer–Douglas–Peucker)
    const rdp = (pts, eps) => {
      if (pts.length < 3) return pts;
      const [ax, ay] = pts[0], [bx, by] = pts[pts.length - 1];
      let md = 0, mi = 0;
      for (let i = 1; i < pts.length - 1; i++) {
        const [px, py] = pts[i];
        const d = Math.abs((by - ay) * px - (bx - ax) * py + bx * ay - by * ax) / (Math.hypot(bx - ax, by - ay) || 1);
        if (d > md) { md = d; mi = i; }
      }
      if (md <= eps) return [pts[0], pts[pts.length - 1]];
      return [...rdp(pts.slice(0, mi + 1), eps).slice(0, -1), ...rdp(pts.slice(mi), eps)];
    };
    const f = (n) => Math.round(n * S * 10) / 10;
    let d = '';
    for (const l of loops) {
      // الحلقة مقفولة (أولها = آخرها): بنبسّط كل نص لوحده
      const m = Math.floor(l.length / 2);
      const p = [...rdp(l.slice(0, m + 1), 0.6).slice(0, -1), ...rdp(l.slice(m), 0.6)];
      d += 'M' + p.map(([x0, y0]) => `${f(x0)} ${f(y0)}`).join('L') + 'Z';
    }
    const svg = document.createElementNS('http://www.w3.org/2000/svg', 'path');
    svg.setAttribute('d', d);
    const sv = document.createElementNS('http://www.w3.org/2000/svg', 'svg');
    sv.appendChild(svg); document.body.appendChild(sv);
    return { w: W, h: H, d, length: Math.round(svg.getTotalLength()), loops: loops.length };
  }, png);
  fs.writeFileSync(path.join(__dirname, '../src/assets/app-logo-outline.json'), JSON.stringify({ w: out.w, h: out.h, length: out.length, d: out.d }));
  console.log(`loops ${out.loops}, path length ${out.length}, d ${out.d.length} chars`);
  await browser.close();
})();
