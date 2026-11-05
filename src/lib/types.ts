import type { DeviceStatus, Role } from './status';

export interface Shop {
  id: string;
  name: string;
  phone: string | null;
  address: string | null;
  receipt_terms: string;
  warranty_days: number;
  country: string;
  currency: string;
  payment_methods: string[];
  logo_path: string | null;
  theme: 'dark' | 'light';
  locale: 'ar' | 'en';
  setup_completed_at: string | null;
}

export const SHOP_COLUMNS = 'id, name, phone, address, receipt_terms, warranty_days, country, currency, payment_methods, logo_path, theme, locale, setup_completed_at';

export interface Profile {
  id: string;
  shop_id: string;
  full_name: string;
  email: string;
  role: Role;
  deleted_at: string | null;
}

export interface Customer {
  id: string;
  name: string;
  phone: string;
  area: string | null;
}

export interface Device {
  id: string;
  shop_id: string;
  customer_id: string;
  order_no: string;
  brand: string;
  model: string;
  imei: string | null;
  color: string | null;
  accessories: string[];
  issue: string;
  cosmetic_condition: string | null;
  status: DeviceStatus;
  received_by: string | null;
  received_at: string;
  delivered_at: string | null;
}

/** صف من عرض devices_list (الأجهزة + اسم العميل + الأسعار لو مسموح) */
export interface DeviceListRow {
  id: string;
  order_no: string;
  brand: string;
  model: string;
  imei: string | null;
  color: string | null;
  status: DeviceStatus;
  received_at: string;
  delivered_at: string | null;
  customer_id: string;
  customer_name: string | null;
  customer_phone: string | null;
  estimated_cost: number | null;
  final_cost: number | null;
}

export interface DeviceCost {
  id: string;
  device_id: string;
  estimated_cost: number | null;
  final_cost: number | null;
}
