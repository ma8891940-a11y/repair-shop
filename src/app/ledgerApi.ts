import { useTranslation } from 'react-i18next';
import { supabase } from '../lib/supabase';
import type { SourceType } from '../lib/ledger';

export interface Cashbox {
  id: string;
  code: string | null;
  name: string | null;
  method: string;
  holder_id?: string | null;
  active?: boolean;
  balance?: number;
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
  revenue: number;
  expenses: number;
  profit: number;
  net_worth: number;
  equation: { assets: number; liabilities: number; equity: number; earnings: number };
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
  kind: 'part' | 'accessory';
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
  image_path?: string | null;
}
export interface DeviceMoney {
  final: number | null;
  paid: number;
  due: number;
  parts_cost: number | null;
  payments: { id: string; amount: number; method: string; created_at: string; entry_id: string; by: string | null; reversed: boolean }[];
}
export type StatementKind = 'cashbox' | 'customer' | 'supplier' | 'employee' | 'partner' | 'linked';

/** بينادي دالة في قاعدة البيانات وبيرمي الخطأ لو فشلت */
export async function rpc<T>(fn: string, args: Record<string, unknown> = {}): Promise<T> {
  const { data, error } = await supabase.rpc(fn, args);
  if (error) throw error;
  return data as T;
}

/** id جديد لكل عملية من التطبيق (نفس العملية لو اتبعتت مرتين ما تتسجلش مرتين) */
export const opId = () => crypto.randomUUID();

/** اسم الحساب: المضاف بالاسم اللي اتكتب، والأساسي مترجم */
export function useAccountName() {
  const { t } = useTranslation();
  return (a: { code: string | null; name: string | null } | null | undefined) => (!a ? '' : a.name || t(`ledger.acc.${a.code}`, { defaultValue: a.code ?? '' }));
}

/** الخزن اللي ينفع تستقبل فلوس (لصاحب المحل والاستقبال) */
export async function loadCashboxes(): Promise<Cashbox[]> {
  const { data, error } = await supabase.from('accounts').select('id, code, name, method, holder_id, active').eq('kind', 'cash').eq('active', true).is('deleted_at', null).order('created_at');
  if (error) throw error;
  return sortCashboxes((data ?? []) as Cashbox[]);
}

/** ترتيب ثابت للخزن: كاش الدرج الأول، وبعدين باقي الأساسية بالترتيب ده، وبعدين المضافة */
const CASH_ORDER = ['cash_cash', 'cash_wallet', 'cash_instapay', 'cash_bank_transfer', 'cash_card', 'cash_installments'];
export function sortCashboxes<T extends { code: string | null }>(list: T[]): T[] {
  const rank = (c: T) => (c.code && CASH_ORDER.includes(c.code) ? CASH_ORDER.indexOf(c.code) : CASH_ORDER.length);
  return [...list].sort((a, b) => rank(a) - rank(b));
}
