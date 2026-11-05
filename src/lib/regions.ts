/** البلاد المدعومة: اختيار البلد بيملا العملة والمنطقة الزمنية وكود الموبايل تلقائيًا */
export const REGIONS = {
  EG: { currency: 'EGP', tz: 'Africa/Cairo', dial: '+20' },
  SA: { currency: 'SAR', tz: 'Asia/Riyadh', dial: '+966' },
  AE: { currency: 'AED', tz: 'Asia/Dubai', dial: '+971' },
  KW: { currency: 'KWD', tz: 'Asia/Kuwait', dial: '+965' },
  QA: { currency: 'QAR', tz: 'Asia/Qatar', dial: '+974' },
  JO: { currency: 'JOD', tz: 'Asia/Amman', dial: '+962' },
} as const;
export type Country = keyof typeof REGIONS;
export const COUNTRIES = Object.keys(REGIONS) as Country[];

export const PAYMENT_METHODS = ['cash', 'card', 'bank_transfer', 'wallet', 'instapay', 'installments'] as const;
export type PaymentMethod = (typeof PAYMENT_METHODS)[number];
