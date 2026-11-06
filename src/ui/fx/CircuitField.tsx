import { useEffect, useRef } from 'react';
import { usePrefs } from '../../app/prefs';
import { cn } from '../cn';

/**
 * خلفية حية: خطوط لوحة دوائر إلكترونية رفيعة، وإشارات مضيئة بتمشي عليها، وخط "سكان" بطيء.
 * - الخطوط بتترسم مرة واحدة في canvas مخفي، وكل فريم بيرسم الإشارات بس (خفيف جدًا).
 * - بتقف لما التبويب مش ظاهر، وفي الوضع الخفيف و"تقليل الحركة" بتترسم ثابتة من غير حركة.
 * - glowFollow: توهج خفيف بيتبع الماوس (بيتحرك بـ transform بس).
 */

interface Trace {
  pts: [number, number][];
  len: number;
  segs: number[]; // الطول التراكمي عند كل نقطة
}
interface Pulse {
  trace: number;
  pos: number;
  speed: number;
  tail: number;
  /** اتجاه الحركة على الخط (1 أو -1) */
  dir?: number;
  /** إشارة متجمّعة: بتقف وتنطفي عند النقطة دي على الخط (الأقرب للوجو) */
  stop?: number;
  /** وقت ما بدأت تنطفي (بعد ما وصلت) */
  fadeAt?: number;
}

/**
 * بيخلي الإشارات تتجمع بنعومة ناحية نقطة على الشاشة (لحظة ظهور اللوجو في الافتتاحية).
 * الإشارات بتمشي على خطوط الدوائر نفسها لحد أقرب نقطة للوجو، وبعدين بتنطفي.
 */
export function convergeSignals(x: number, y: number, radius = 90) {
  window.dispatchEvent(new CustomEvent('circuit:converge', { detail: { x, y, radius } }));
}

const CELL = 26;

function seeded(seed: number) {
  let s = seed >>> 0;
  return () => {
    s = (s * 1664525 + 1013904223) >>> 0;
    return s / 4294967296;
  };
}

function buildTraces(w: number, h: number): Trace[] {
  const rnd = seeded(Math.floor(w * 7 + h * 13));
  const cols = Math.ceil(w / CELL) + 1;
  const rows = Math.ceil(h / CELL) + 1;
  const used = new Set<number>();
  const key = (c: number, r: number) => r * 10000 + c;
  const traces: Trace[] = [];
  const target = Math.min(70, Math.floor((cols * rows) / 22));
  const dirs: [number, number][] = [
    [1, 0], [-1, 0], [0, 1], [0, -1], [1, 1], [-1, -1], [1, -1], [-1, 1],
  ];
  for (let t = 0; t < target * 3 && traces.length < target; t++) {
    let c = Math.floor(rnd() * cols);
    let r = Math.floor(rnd() * rows);
    if (used.has(key(c, r))) continue;
    let d = dirs[Math.floor(rnd() * 4)]; // البداية أفقي أو رأسي
    const pts: [number, number][] = [[c * CELL, r * CELL]];
    used.add(key(c, r));
    const steps = 4 + Math.floor(rnd() * 14);
    for (let s = 0; s < steps; s++) {
      if (rnd() < 0.22) {
        // لفّة 45 درجة زي مسارات اللوحة
        const diag = dirs.slice(4).filter(([dx, dy]) => (dx === d[0] || dy === d[1]) && !(dx === d[0] && dy === d[1]));
        if (diag.length) d = diag[Math.floor(rnd() * diag.length)];
        else d = dirs[Math.floor(rnd() * 4)];
      } else if (Math.abs(d[0]) + Math.abs(d[1]) === 2 && rnd() < 0.6) {
        d = rnd() < 0.5 ? [d[0], 0] : [0, d[1]];
      }
      const nc = c + d[0];
      const nr = r + d[1];
      if (nc < 0 || nr < 0 || nc >= cols || nr >= rows || used.has(key(nc, nr))) break;
      c = nc;
      r = nr;
      used.add(key(c, r));
      pts.push([c * CELL, r * CELL]);
    }
    if (pts.length < 3) continue;
    const segs = [0];
    let len = 0;
    for (let i = 1; i < pts.length; i++) {
      len += Math.hypot(pts[i][0] - pts[i - 1][0], pts[i][1] - pts[i - 1][1]);
      segs.push(len);
    }
    traces.push({ pts, len, segs });
  }
  return traces;
}

function pointAt(tr: Trace, d: number): [number, number] {
  const x = Math.max(0, Math.min(tr.len, d));
  let i = 1;
  while (i < tr.segs.length - 1 && tr.segs[i] < x) i++;
  const a = tr.pts[i - 1];
  const b = tr.pts[i];
  const seg = tr.segs[i] - tr.segs[i - 1] || 1;
  const k = (x - tr.segs[i - 1]) / seg;
  return [a[0] + (b[0] - a[0]) * k, a[1] + (b[1] - a[1]) * k];
}

function readColors() {
  const cs = getComputedStyle(document.documentElement);
  return {
    trace: cs.getPropertyValue('--trace').trim() || 'rgb(56 214 240 / 0.09)',
    pad: cs.getPropertyValue('--trace-pad').trim() || 'rgb(56 214 240 / 0.16)',
    rgb: cs.getPropertyValue('--accent-rgb').trim() || '56 214 240',
  };
}

export function CircuitField({ className, glowFollow = false, density = 1, still = false }: { className?: string; glowFollow?: boolean; density?: number; /** ترسم مرة واحدة من غير حركة (جوه البرنامج) */ still?: boolean }) {
  const { calm, rich, theme } = usePrefs();
  const canvasRef = useRef<HTMLCanvasElement>(null);
  const glowRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    const canvas = canvasRef.current;
    if (!canvas) return;
    const ctx = canvas.getContext('2d');
    if (!ctx) return;
    let raf = 0;
    let w = 0;
    let h = 0;
    let dpr = 1;
    let traces: Trace[] = [];
    let pulses: Pulse[] = [];
    let colors = readColors();
    const base = document.createElement('canvas');
    const bctx = base.getContext('2d')!;
    let last = performance.now();
    let scan = 0;
    let clock = 0;

    const setup = () => {
      const rect = canvas.getBoundingClientRect();
      w = Math.max(1, Math.floor(rect.width));
      h = Math.max(1, Math.floor(rect.height));
      dpr = Math.min(window.devicePixelRatio || 1, 1.5);
      for (const c of [canvas, base]) {
        c.width = Math.floor(w * dpr);
        c.height = Math.floor(h * dpr);
      }
      colors = readColors();
      traces = buildTraces(w, h);
      // الطبقة الثابتة: الخطوط والنقط
      bctx.setTransform(dpr, 0, 0, dpr, 0, 0);
      bctx.clearRect(0, 0, w, h);
      bctx.lineWidth = 1;
      bctx.lineJoin = 'round';
      bctx.strokeStyle = colors.trace;
      for (const tr of traces) {
        bctx.beginPath();
        bctx.moveTo(tr.pts[0][0] + 0.5, tr.pts[0][1] + 0.5);
        for (let i = 1; i < tr.pts.length; i++) bctx.lineTo(tr.pts[i][0] + 0.5, tr.pts[i][1] + 0.5);
        bctx.stroke();
      }
      bctx.strokeStyle = colors.pad;
      for (const tr of traces) {
        for (const p of [tr.pts[0], tr.pts[tr.pts.length - 1]]) {
          bctx.beginPath();
          bctx.arc(p[0] + 0.5, p[1] + 0.5, 2.2, 0, Math.PI * 2);
          bctx.stroke();
        }
      }
      const n = Math.max(4, Math.round(traces.length * 0.28 * density));
      pulses = Array.from({ length: n }, () => newPulse(true));
      draw(0);
    };

    const newPulse = (randomStart: boolean): Pulse => {
      const trace = Math.floor(Math.random() * traces.length);
      const tr = traces[trace];
      return { trace, pos: randomStart ? Math.random() * (tr?.len ?? 0) : -20, speed: 40 + Math.random() * 70, tail: 26 + Math.random() * 30 };
    };

    // التجمّع: خطوط بتعدّي قريب من النقطة، وإشارة على كل خط ماشية ناحية أقرب نقطة فيه
    const converge = (cx: number, cy: number, radius: number) => {
      if (calm || still || !traces.length) return;
      const near: { trace: number; at: number; d: number }[] = [];
      traces.forEach((tr, i) => {
        let best = Infinity;
        let at = 0;
        for (let k = 0; k <= tr.len; k += 6) {
          const [px, py] = pointAt(tr, k);
          const d = Math.hypot(px - cx, py - cy);
          if (d < best) {
            best = d;
            at = k;
          }
        }
        if (best > radius * 0.55 && best < radius * 3.2) near.push({ trace: i, at, d: best });
      });
      near.sort((a, b) => a.d - b.d);
      for (const n of near.slice(0, 14)) {
        const tr = traces[n.trace];
        // البداية من الطرف الأبعد عن النقطة، على مسافة كفاية إنها تبان وهي جاية
        const dir = n.at > tr.len / 2 ? 1 : -1;
        const travel = Math.min(220, dir === 1 ? n.at : tr.len - n.at);
        if (travel < 40) continue;
        pulses.push({ trace: n.trace, pos: n.at - dir * travel, speed: travel / 0.6 + Math.random() * 40, tail: 34, dir, stop: n.at });
      }
    };
    const onConverge = (e: Event) => {
      const { x, y, radius } = (e as CustomEvent<{ x: number; y: number; radius: number }>).detail;
      const rect = canvas.getBoundingClientRect();
      converge(x - rect.left, y - rect.top, radius);
    };
    window.addEventListener('circuit:converge', onConverge);

    const draw = (dt: number) => {
      clock += dt;
      ctx.setTransform(1, 0, 0, 1, 0, 0);
      ctx.clearRect(0, 0, canvas.width, canvas.height);
      ctx.drawImage(base, 0, 0);
      ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
      // الوضع الهادي (خفيف/تقليل الحركة/ثابت): الخطوط بس، من غير إشارات ولا سكان
      if (!traces.length || calm || still) return;
      // خط السكان: شريط أفقي باهت بينزل ببطء
      scan = (scan + dt * 0.035) % (h + 200);
      const sy = scan - 100;
      const g = ctx.createLinearGradient(0, sy - 60, 0, sy + 60);
      g.addColorStop(0, `rgb(${colors.rgb} / 0)`);
      g.addColorStop(0.5, `rgb(${colors.rgb} / 0.045)`);
      g.addColorStop(1, `rgb(${colors.rgb} / 0)`);
      ctx.fillStyle = g;
      ctx.fillRect(0, sy - 60, w, 120);
      // الإشارات
      ctx.lineCap = 'round';
      for (let i = 0; i < pulses.length; i++) {
        const p = pulses[i];
        const tr = traces[p.trace];
        if (!tr) continue;
        const dir = p.dir ?? 1;
        let fade = 1;
        if (p.stop != null) {
          // إشارة متجمّعة: بتبطّأ وهي بتقرب، وتقف عند النقطة وتنطفي في ربع ثانية
          if (p.fadeAt == null) {
            const left = (p.stop - p.pos) * dir;
            p.pos += dir * Math.min(left, (p.speed * dt) / 1000 * Math.max(0.35, Math.min(1, left / 60)));
            if (left <= 0.5) p.fadeAt = clock;
          } else {
            fade = 1 - (clock - p.fadeAt) / 260;
            if (fade <= 0) {
              pulses.splice(i, 1);
              i--;
              continue;
            }
          }
        } else {
          p.pos += (p.speed * dt) / 1000;
          if (p.pos - p.tail > tr.len) {
            pulses[i] = newPulse(false);
            continue;
          }
        }
        const [hx, hy] = pointAt(tr, p.pos);
        const steps = 6;
        for (let s = 0; s < steps; s++) {
          const a = pointAt(tr, p.pos - (dir * p.tail * s) / steps);
          const b = pointAt(tr, p.pos - (dir * p.tail * (s + 1)) / steps);
          ctx.strokeStyle = `rgb(${colors.rgb} / ${(p.stop != null ? 0.9 : 0.55) * (1 - s / steps) * fade})`;
          ctx.lineWidth = p.stop != null ? 2 : 1.4;
          ctx.beginPath();
          ctx.moveTo(a[0] + 0.5, a[1] + 0.5);
          ctx.lineTo(b[0] + 0.5, b[1] + 0.5);
          ctx.stroke();
        }
        const hr = p.stop != null ? 10 : 7;
        const rg = ctx.createRadialGradient(hx, hy, 0, hx, hy, hr);
        rg.addColorStop(0, `rgb(${colors.rgb} / ${(p.stop != null ? 1 : 0.85) * fade})`);
        rg.addColorStop(1, `rgb(${colors.rgb} / 0)`);
        ctx.fillStyle = rg;
        ctx.fillRect(hx - hr, hy - hr, hr * 2, hr * 2);
      }
    };

    const loop = (now: number) => {
      const dt = Math.min(64, now - last);
      last = now;
      draw(dt);
      raf = requestAnimationFrame(loop);
    };

    const start = () => {
      cancelAnimationFrame(raf);
      if (calm || still || document.hidden) return;
      last = performance.now();
      raf = requestAnimationFrame(loop);
    };

    setup();
    start();

    let resizeT = 0;
    const ro = new ResizeObserver(() => {
      clearTimeout(resizeT);
      resizeT = window.setTimeout(() => {
        setup();
        start();
      }, 150);
    });
    ro.observe(canvas);
    const onVis = () => (document.hidden ? cancelAnimationFrame(raf) : start());
    document.addEventListener('visibilitychange', onVis);
    return () => {
      cancelAnimationFrame(raf);
      clearTimeout(resizeT);
      ro.disconnect();
      document.removeEventListener('visibilitychange', onVis);
      window.removeEventListener('circuit:converge', onConverge);
    };
  }, [calm, theme, density, still]);

  // توهج بيتبع الماوس (transform بس، بتنعيم)
  useEffect(() => {
    if (!glowFollow || !rich) return;
    const el = glowRef.current;
    if (!el) return;
    let tx = window.innerWidth / 2;
    let ty = window.innerHeight / 3;
    let x = tx;
    let y = ty;
    let raf = 0;
    const onMove = (e: PointerEvent) => {
      tx = e.clientX;
      ty = e.clientY;
    };
    const tick = () => {
      x += (tx - x) * 0.12;
      y += (ty - y) * 0.12;
      el.style.transform = `translate3d(${x - 300}px, ${y - 300}px, 0)`;
      raf = requestAnimationFrame(tick);
    };
    window.addEventListener('pointermove', onMove, { passive: true });
    raf = requestAnimationFrame(tick);
    const onVis = () => {
      cancelAnimationFrame(raf);
      if (!document.hidden) raf = requestAnimationFrame(tick);
    };
    document.addEventListener('visibilitychange', onVis);
    return () => {
      cancelAnimationFrame(raf);
      window.removeEventListener('pointermove', onMove);
      document.removeEventListener('visibilitychange', onVis);
    };
  }, [glowFollow, rich]);

  return (
    <div className={cn('pointer-events-none absolute inset-0 overflow-hidden', className)} aria-hidden>
      <canvas ref={canvasRef} className="absolute inset-0 size-full" />
      {glowFollow && rich && (
        <div
          ref={glowRef}
          className="absolute left-0 top-0 size-[600px] rounded-full will-change-transform"
          style={{ background: 'radial-gradient(closest-side, rgb(var(--accent-rgb) / 0.13), transparent)' }}
        />
      )}
    </div>
  );
}
