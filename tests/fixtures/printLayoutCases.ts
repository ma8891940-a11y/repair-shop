import { FREE_FIELDS, type PrintDoc } from '../../src/lib/printLayout';

/** حالات فحص القالب: نفسها في اختبار الواجهة واختبار السيرفر، عشان الاتنين يفضلوا متطابقين (للاختبارات بس) */
export interface TemplateCase {
  name: string;
  doc: string;
  mode: string;
  blocks: unknown;
  layout: unknown;
  error: string | null;
}
const block = (o: object = {}) => ({ key: 'customer', show: true, size: 'md', align: 'start', bold: false, ...o });
const field = (o: object = {}) => ({ key: 'customer', x: 2, y: 2.5, w: 30, h: 5, font: 'sans', pt: 10, align: 'start', bold: false, ...o });
const free = (name: string, f: object, error: string | null, o: object = {}): TemplateCase => ({ name, doc: 'sticker', mode: 'free', blocks: [], layout: { paper: { kind: '40x30' }, fields: [field(f)], ...o }, error });
const flow = (name: string, b: unknown, error: string | null, o: Partial<TemplateCase> = {}): TemplateCase => ({ name, doc: 'receipt', mode: 'flow', blocks: [b], layout: {}, error, ...o });
const BG = '0f8fad5b-d9cb-469f-a165-70867728950e';
const bg = (o: object = {}) => ({ file: `${BG}.png`, stock: 'blank', w: 2480, h: 3508, ...o });

export const TEMPLATE_CASES: TemplateCase[] = [
  // flow
  flow('خانة عادية', block(), null),
  flow('نص حر', block({ key: 'text', text: 'أهلا' }), null),
  flow('نصين حر', block(), null, { blocks: [block({ key: 'text', text: 'أ' }), block({ key: 'text', text: 'ب' })] }),
  flow('خط وحجم', block({ font: 'mono', pt: 12 }), null),
  flow('فاضي', null, null, { blocks: [] }),
  flow('لغة ومقاس وخلفية', block(), null, { layout: { lang: 'en', paper: { kind: 'a4' }, bg: bg() } }),
  flow('مقاس مخصوص من غير طول', block(), null, { layout: { paper: { kind: 'custom', w: 72, h: null } } }),
  flow('خلفية فاضية', block(), null, { layout: { bg: null } }),
  flow('خانة مش بتاعة النوع', block({ key: 'imei' }), 'field', { doc: 'statement' }),
  flow('خانة مجهولة', block({ key: 'script' }), 'field'),
  flow('خانة مكررة', block(), 'duplicate', { blocks: [block(), block()] }),
  flow('مفتاح مجهول', block({ onclick: 'x' }), 'key'),
  flow('نوع غلط', block({ show: 'yes' }), 'value'),
  flow('حجم غلط', block({ size: 'xl' }), 'value'),
  flow('ناقص', { key: 'customer' }, 'value'),
  flow('خط مجهول', block({ font: 'url(x)' }), 'font'),
  flow('حجم بره الحدود', block({ pt: 500 }), 'pt'),
  flow('حجم بكسر', block({ pt: 10.5 }), 'pt'),
  flow('نص طويل', block({ key: 'text', text: 'ط'.repeat(301) }), 'text'),
  flow('نص 300', block({ key: 'text', text: 'ط'.repeat(300) }), null),
  flow('نص في خانة عادية', block({ text: 'x' }), 'text'),
  flow('نص حر من غير نص', block({ key: 'text' }), 'text'),
  flow('مش كائن', 5, 'type'),
  flow('61 خانة', null, 'count', { blocks: Array.from({ length: 61 }, () => block({ key: 'text', text: '' })) }),
  flow('blocks مش قايمة', null, 'type', { blocks: {} }),
  flow('layout مش كائن', null, 'type', { blocks: [], layout: [] }),
  flow('مفتاح مجهول في layout', block(), 'key', { layout: { html: '<b>' } }),
  flow('حقول في flow', block(), 'key', { layout: { fields: [] } }),
  flow('لغة غلط', block(), 'lang', { layout: { lang: 'fr' } }),
  flow('لغة null', block(), 'lang', { layout: { lang: null } }),
  flow('خلفية SVG', block(), 'bg', { layout: { paper: { kind: 'a4' }, bg: bg({ file: `${BG}.svg` }) } }),
  flow('خلفية رابط', block(), 'bg', { layout: { paper: { kind: 'a4' }, bg: bg({ file: 'https://x/a.png' }) } }),
  flow('خلفية رقم', block(), 'bg', { layout: { bg: 5 } }),
  flow('خلفية نص', block(), 'bg', { layout: { paper: { kind: 'a4' }, bg: `${BG}.png` } }),
  flow('ورق مطبوع جاهز', block(), null, { layout: { paper: { kind: 'a4' }, bg: bg({ stock: 'preprinted', file: `${BG}.jpg` }) } }),
  flow('طريقة ورق مجهولة', block(), 'bg', { layout: { paper: { kind: 'a4' }, bg: bg({ stock: 'other' }) } }),
  flow('خلفية بمفتاح زيادة', block(), 'bg', { layout: { paper: { kind: 'a4' }, bg: bg({ url: 'x' }) } }),
  flow('خلفية من غير مقاس', block(), 'bg', { layout: { paper: { kind: 'a4' }, bg: bg({ w: undefined }) } }),
  flow('خلفية ضخمة', block(), 'bg', { layout: { paper: { kind: 'a4' }, bg: bg({ w: 10001, h: 10001 }) } }),
  flow('خلفية مش بنسبة الورقة', block(), 'bgsize', { layout: { paper: { kind: 'a4' }, bg: bg({ w: 3508, h: 2480 }) } }),
  flow('خلفية على حد النص مللي', block(), null, { layout: { paper: { kind: '40x30' }, bg: bg({ w: 400, h: 305 }) } }),
  flow('خلفية بعد النص مللي', block(), 'bgsize', { layout: { paper: { kind: '40x30' }, bg: bg({ w: 400, h: 306 }) } }),
  flow('خلفية من غير مقاس ورقة', block(), 'bgsize', { layout: { bg: bg() } }),
  flow('خلفية على رول', block(), 'bgsize', { layout: { paper: { kind: '80' }, bg: bg() } }),
  flow('مقاس مجهول', block(), 'paper', { layout: { paper: { kind: 'a3' } } }),
  flow('مقاس null', block(), 'paper', { layout: { paper: null } }),
  flow('مقاس ومعاه مفتاح', block(), 'paper', { layout: { paper: { kind: 'a4', w: 5 } } }),
  flow('مخصوص من غير طول خالص', block(), 'paper', { layout: { paper: { kind: 'custom', w: 72 } } }),
  flow('عرض كبير', block(), 'paper', { layout: { paper: { kind: 'custom', w: 301, h: 100 } } }),
  flow('عرض بكسر', block(), 'paper', { layout: { paper: { kind: 'custom', w: 72.5, h: 100 } } }),
  flow('نوع مجهول', block(), 'doc', { doc: 'html' }),
  flow('طريقة مجهولة', block(), 'mode', { mode: 'html' }),
  flow('ستيكر بالترتيب', block(), 'field', { doc: 'sticker' }),
  flow('حجم JSON', null, 'size', { blocks: [], layout: { bg: 'x'.repeat(70000) } }),
  // free
  free('حقل عادي', {}, null),
  free('على الحد بالظبط', { x: 0.1, y: 0.2, w: 39.9, h: 29.8 }, null),
  free('نص حر', { key: 'text', text: 'ضمان' }, null),
  free('بره الورقة يمين', { x: 10.1, w: 30 }, 'bounds'),
  free('بره الورقة تحت', { y: 26, h: 4.1 }, 'bounds'),
  free('سالب', { x: -0.1 }, 'bounds'),
  free('صغير', { w: 0.9 }, 'bounds'),
  free('كسر صغير', { x: 1.25 }, 'number'),
  free('0.1+0.2', { x: 0.1 + 0.2 }, 'number'),
  free('رقم نص', { x: '2' }, 'number'),
  free('رقم null', { h: null }, 'number'),
  free('رقم ضخم', { x: 1e6 }, 'bounds'),
  free('خط مجهول', { font: 'Arial' }, 'font'),
  free('حجم صغير', { pt: 4 }, 'pt'),
  free('محاذاة غلط', { align: 'left' }, 'value'),
  free('مفتاح مجهول', { style: 'x' }, 'key'),
  free('حقل مش بتاع النوع', { key: 'price' }, 'field'),
  free('نص طويل', { key: 'text', text: 'x'.repeat(301) }, 'text'),
  free('من غير مقاس', {}, 'paper', { paper: undefined }),
  free('مقاس من غير طول', {}, 'paper', { paper: { kind: '80' } }),
  free('من غير حقول', {}, 'count', { fields: [] }),
  free('حقول مش قايمة', {}, 'type', { fields: {} }),
  free('حقل مش كائن', {}, 'type', { fields: ['x'] }),
  free('مكرر', {}, 'duplicate', { fields: [field(), field()] }),
  { ...free('خانات في free', {}, 'key'), blocks: [block()] },
  { ...free('كشف الحساب حر', {}, 'mode'), doc: 'statement' },
  { ...free('إيصال حراري حر', {}, 'mode'), doc: 'receipt' },
  // كل حقل مسموح في كل نوع
  ...(Object.keys(FREE_FIELDS) as PrintDoc[]).flatMap((doc) =>
    FREE_FIELDS[doc].map((key): TemplateCase => ({ name: `${doc}: ${key}`, doc, mode: 'free', blocks: [], layout: { paper: { kind: 'a4' }, fields: [field({ key, ...(key === 'text' ? { text: '' } : {}) })] }, error: null })),
  ),
].map((c) => JSON.parse(JSON.stringify(c)) as TemplateCase);
