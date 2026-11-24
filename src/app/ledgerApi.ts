import { useTranslation } from 'react-i18next';
import { cacheGet, cacheSet, localDb } from '../offline/outbox';
import { supabase } from '../lib/supabase';
import { BRANCH_HEADER, getBranchHeader } from '../lib/branchHeader';
import type { SourceType } from '../lib/ledger';
import { useBranch } from './branch';
import { withMaster } from './masterAsk';

export interface Cashbox {
  id: string;
  code: string | null;
  name: string | null;
  method: string;
  holder_id?: string | null;
  active?: boolean;
  balance?: number;
  /** B: الفرع اللي الخزنة فيه */
  branch_id?: string | null;
}
export interface Account {
  id: string;
  code: string | null;
  name: string | null;
  type: 'asset' | 'liability' | 'equity' | 'revenue' | 'expense';
  kind: string;
  method: string | null;
  holder_id: string | null;
  active: boolean;
}
export interface Position {
  cash: number;
  receivables: number;
  payables: number;
  inventory: number;
  /** أصول ثابتة (معدات) */
  fixed_assets?: number;
  /** أرباح اتوزعت على الشركاء ولسه ما اتسحبتش (حقوق ملكية) */
  partners_due?: number | null;
  /** R5: ضريبة القيمة المضافة المستحقة للمصلحة (من ضمن "عليّا") */
  vat_due?: number;
  equity_parts?: null | { owner_capital: number; drawings: number; retained: number; partners: { id: string; name: string; share_bp: number; capital: number; current: number }[] };
  revenue: number;
  expenses: number;
  profit: number;
  /** صاحب المحل بس (0086) */
  net_worth: number | null;
  /** المحل كله: لصاحب المحل بس (0085) */
  equation: { assets: number; liabilities: number; equity: number; earnings: number } | null;
  debits: number;
  credits: number;
  unbalanced_entries: number;
  balanced: boolean;
  cashboxes: (Cashbox & { balance: number })[];
  top_customers: { id: string; name: string; balance: number }[];
  top_suppliers: { id: string; name: string; balance: number }[];
  daily: { day: string; revenue: number; expenses: number; profit: number }[];
  by_method: Record<string, number>;
  delivered: number;
  closings: { cashbox: string; expected: number; counted: number; diff: number; at: string; by: string | null }[];
}
// 0064: التقرير اليومي: التحصيل كله (صيانة + بيع) وتسوية كل خزنة
export interface DayCash {
  collections: { method: string; payments: number; sales: number; cheques: number; refunds: number; total: number }[];
  cashboxes: (Cashbox & { opening: number; in: number; out: number; closing: number;
    entries: { entry_id: string; entry_no: number; source_type: SourceType; memo: string | null; at: string; in: number; out: number; cancelled: boolean }[] })[];
}
export interface Move {
  entry_id: string;
  entry_no: number;
  at: string;
  source_type: SourceType;
  source_id: string | null;
  device_id: string | null;
  order_no: string | null;
  memo: string | null;
  by: string | null;
  account: string | null;
  amount: number;
  balance: number;
  reversed: boolean;
  reverses: string | null;
}
export interface Statement {
  opening: number;
  moves: Move[];
}
export interface StockRow {
  id: string;
  kind: 'part' | 'accessory' | 'used' | 'service';
  name: string;
  sku: string | null;
  sale_price: number | null;
  qty: number;
  avg_cost: number | null;
  value: number | null;
  min_qty?: number;
  supplier_id?: string | null;
  short?: boolean;
  category?: string | null;
  barcode?: string | null;
  brand?: string | null;
  image_path?: string | null;
  /** S6: تفاصيل الصنف */
  item_type?: string | null;
  model?: string | null;
  quality?: string | null;
  color?: string | null;
  /** S6: كمية اتباعت من غير رصيد ولسه محتاجة تسوية */
  unsettled?: number;
}
export interface DeviceMoney {
  final: number | null;
  paid: number;
  due: number;
  parts_cost: number | null;
  payments: { id: string; amount: number; method: string; created_at: string; entry_id: string; by: string | null; reversed: boolean }[];
}
export type StatementKind = 'cashbox' | 'customer' | 'supplier' | 'employee' | 'partner' | 'linked';

/** فرع كل خزنة (من آخر قايمة خزن اتحمّلت) */
const cashboxBranch = new Map<string, string>();

/**
 * بينادي دالة في قاعدة البيانات وبيرمي الخطأ لو فشلت.
 * B: لو العملية على خزنة، بتتسجل في فرع الخزنة دي (مش لازم يكون الفرع المعروض)، و branch بيحدد الفرع صراحة.
 */
export async function rpc<T>(fn: string, args: Record<string, unknown> = {}, o: { branch?: string | null } = {}): Promise<T> {
  // خزنة فاضية (القايمة لسه ما وصلتش): رسالة واضحة بدل خطأ 400 من السيرفر
  if (args.p_cashbox === '') throw { message: 'E_BAD_ACCOUNT', code: 'P0001' };
  const b = o.branch ?? (typeof args.p_cashbox === 'string' ? cashboxBranch.get(args.p_cashbox) : undefined);
  // C3: لو العملية محتاجة كلمة السر الرئيسية، بتتسأل وبتتعاد مرة واحدة
  return withMaster(async () => {
    let q = supabase.rpc(fn, args);
    if (b && getBranchHeader()) q = q.setHeader(BRANCH_HEADER, b);
    const { data, error } = await q;
    if (error) throw error;
    return data as T;
  });
}

/** id جديد لكل عملية من التطبيق (نفس العملية لو اتبعتت مرتين ما تتسجلش مرتين) */
export const opId = () => crypto.randomUUID();

/** اسم الحساب: المضاف بالاسم اللي اتكتب، والأساسي مترجم. ولو المحل فيه فروع: الخزنة باسم فرعها */
export function useAccountName() {
  const { t } = useTranslation();
  const br = useBranch();
  return (a: { code: string | null; name: string | null; method?: string | null; branch_id?: string | null } | null | undefined) => {
    if (!a) return '';
    const bn = br.multi && a.branch_id ? br.name(a.branch_id) : '';
    // خزنة اتعملت مع فرع جديد: اسمها اسم الفرع، فبتتعرض بطريقة الدفع + الفرع
    if (bn && a.name === bn && a.method) return `${t(`payments.${a.method}`, { defaultValue: a.method })} · ${bn}`;
    const base = a.name || t(`ledger.acc.${a.code}`, { defaultValue: a.code ?? '' });
    return bn ? `${base} · ${bn}` : base;
  };
}

/** خزن فرع معيّن (null = كل الخزن: محل بفرع واحد، أو تحويل بين الفروع) */
export function cashboxesFor<T extends { branch_id?: string | null }>(list: T[], branch: string | null | undefined): T[] {
  if (!branch) return list;
  return list.filter((c) => !c.branch_id || c.branch_id === branch);
}

/** الخزن اللي ينفع تستقبل فلوس (لصاحب المحل والاستقبال) */
export async function loadCashboxes(): Promise<Cashbox[]> {
  // البند 14: آخر قايمة خزن بتتحفظ على الجهاز، فالبيع والدفعة من غير نت بيتسجلوا على خزنة صح
  try {
    const { data, error } = await supabase.from('accounts').select('id, code, name, method, holder_id, active, branch_id').eq('kind', 'cash').eq('active', true).is('deleted_at', null).order('created_at');
    if (error) throw error;
    const list = sortCashboxes((data ?? []) as Cashbox[]);
    for (const c of list) if (c.branch_id) cashboxBranch.set(c.id, c.branch_id);
    void cacheSet(localDb(), 'cashboxes', list).catch(() => undefined);
    return list;
  } catch (e) {
    const c = await cacheGet<Cashbox[]>(localDb(), 'cashboxes').catch(() => null);
    if (c) {
      for (const x of c.value) if (x.branch_id) cashboxBranch.set(x.id, x.branch_id);
      return c.value;
    }
    throw e;
  }
}

/** ترتيب ثابت للخزن: كاش الدرج الأول، وبعدين باقي الأساسية بالترتيب ده، وبعدين المضافة */
const CASH_ORDER = ['cash_cash', 'cash_wallet', 'cash_instapay', 'cash_bank_transfer', 'cash_card', 'cash_installments'];
export function sortCashboxes<T extends { code: string | null }>(list: T[]): T[] {
  const rank = (c: T) => (c.code && CASH_ORDER.includes(c.code) ? CASH_ORDER.indexOf(c.code) : CASH_ORDER.length);
  return [...list].sort((a, b) => rank(a) - rank(b));
}
