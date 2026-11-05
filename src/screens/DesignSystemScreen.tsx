import { useState } from 'react';
import { Plus, Printer, Search } from 'lucide-react';
import { STATUSES } from '../lib/status';
import { Button } from '../ui/Button';
import { Field, Input, Select, Textarea } from '../ui/Field';
import { Checkbox, ChipToggle } from '../ui/Checkbox';
import { Panel, PanelHeader } from '../ui/Panel';
import { StatusBadge } from '../ui/StatusBadge';
import { Alert, EmptyState, Skeleton } from '../ui/Feedback';
import { Dialog } from '../ui/Dialog';
import { Kbd } from '../ui/Kbd';
import { Mark } from '../ui/Logo';
import { ThemeToggle } from '../ui/ThemeToggle';
import { AnimatedNumber } from '../ui/AnimatedNumber';

const SWATCHES = ['bg', 'surface', 'raised', 'overlay', 'sunken', 'line', 'line-strong', 'text', 'text-2', 'text-3', 'accent', 'ok', 'warn', 'danger'];

/** صفحة عرض نظام التصميم (في وضع التطوير بس) */
export default function DesignSystemScreen() {
  const [open, setOpen] = useState(false);
  const [chk, setChk] = useState(true);
  const [chip, setChip] = useState(true);
  const [n, setN] = useState(1250);
  return (
    <div className="min-h-dvh bg-bg px-6 py-6">
      <div className="mx-auto flex max-w-6xl flex-col gap-5">
        <div className="flex items-center justify-between">
          <div className="flex items-center gap-3">
            <Mark size={32} />
            <div>
              <h1 className="text-xl font-semibold">نظام التصميم</h1>
              <div className="readout-label">تقني حديث · داكن أساسي</div>
            </div>
          </div>
          <ThemeToggle />
        </div>

        <Panel>
          <PanelHeader index="01" title="الألوان" />
          <div className="grid grid-cols-4 gap-3 p-4 sm:grid-cols-7">
            {SWATCHES.map((s) => (
              <div key={s} className="flex flex-col gap-1.5">
                <div className="h-12 rounded-md border border-line" style={{ background: `var(--${s})` }} />
                <span className="num text-2xs text-fg-3" dir="ltr">--{s}</span>
              </div>
            ))}
          </div>
        </Panel>

        <div className="grid gap-5 lg:grid-cols-2">
          <Panel>
            <PanelHeader index="02" title="الخطوط والأرقام" />
            <div className="flex flex-col gap-2 p-4">
              <div className="text-2xl font-semibold">عنوان كبير</div>
              <div className="text-xl font-semibold">عنوان الصفحة</div>
              <div className="text-md">نص عادي مقروء للشاشات</div>
              <div className="text-base text-fg-2">نص الشغل اليومي المضغوط — 14px</div>
              <div className="text-sm text-fg-3">تلميح وتفاصيل صغيرة</div>
              <div className="readout-label">ملصق قراءة</div>
              <div className="num text-2xl" dir="ltr">
                <AnimatedNumber value={n} /> <span className="font-sans text-sm text-fg-3">ج.م</span>
              </div>
              <div className="num text-sm text-fg-2" dir="ltr">
                2026-0001 · 490154203237518 · 01012345678
              </div>
              <Button size="sm" className="self-start" onClick={() => setN((x) => x + 375)}>
                غيّر الرقم
              </Button>
            </div>
          </Panel>

          <Panel>
            <PanelHeader index="03" title="حالات الجهاز" />
            <div className="flex flex-wrap gap-2 p-4">
              {STATUSES.map((s) => (
                <StatusBadge key={s} status={s} />
              ))}
            </div>
            <div className="ruler mx-4 mb-3" />
          </Panel>
        </div>

        <Panel>
          <PanelHeader index="04" title="الأزرار" />
          <div className="flex flex-wrap items-center gap-2 p-4">
            <Button variant="primary" icon={<Plus className="size-4" />} shortcut="F2" tip="استلام جهاز">
              استلام جهاز
            </Button>
            <Button icon={<Printer className="size-4" />}>طباعة</Button>
            <Button variant="outline">تعديل</Button>
            <Button variant="ghost">إلغاء</Button>
            <Button variant="danger">حذف</Button>
            <Button variant="primary" loading>
              جاري الحفظ
            </Button>
            <Button size="sm">صغير</Button>
            <Button size="icon" aria-label="بحث" tip="بحث" shortcut="Ctrl+K">
              <Search className="size-4" />
            </Button>
            <span className="flex items-center gap-1 text-sm text-fg-3">
              <Kbd>Ctrl</Kbd>
              <Kbd>Enter</Kbd>
            </span>
          </div>
        </Panel>

        <div className="grid gap-5 lg:grid-cols-2">
          <Panel>
            <PanelHeader index="05" title="الحقول" />
            <div className="grid gap-3 p-4 sm:grid-cols-2">
              <Field label="الاسم" required>
                <Input placeholder="اسم العميل" />
              </Field>
              <Field label="الموبايل" error="رقم غير صحيح">
                <Input dir="ltr" mono defaultValue="0101234" className="text-start" />
              </Field>
              <Field label="الحالة" hint="اختيار من قائمة">
                <Select defaultValue="b">
                  <option value="a">الكل</option>
                  <option value="b">جاري الصيانة</option>
                </Select>
              </Field>
              <Field label="ملاحظات">
                <Textarea rows={2} />
              </Field>
              <div className="flex flex-wrap items-center gap-2 sm:col-span-2">
                <Checkbox checked={chk} onChange={setChk} label="اختيار" />
                <ChipToggle pressed={chip} onChange={setChip}>
                  شريحة
                </ChipToggle>
                <ChipToggle pressed={false} onChange={() => {}}>
                  جراب
                </ChipToggle>
              </div>
            </div>
          </Panel>

          <Panel>
            <PanelHeader index="06" title="التنبيهات والحالات" />
            <div className="flex flex-col gap-2 p-4">
              <Alert tone="info">معلومة للمستخدم.</Alert>
              <Alert tone="ok">اتحفظ بنجاح.</Alert>
              <Alert tone="warn" title="الجهاز ده دخل قبل كده">طلب 2026-0003</Alert>
              <Alert tone="danger">لازم تكتب التكلفة النهائية قبل التسليم.</Alert>
              <div className="flex gap-2">
                <Skeleton className="h-8 flex-1" />
                <Skeleton className="h-8 w-24" />
              </div>
              <Button onClick={() => setOpen(true)}>افتح نافذة</Button>
            </div>
          </Panel>
        </div>

        <Panel>
          <PanelHeader index="07" title="حالة فاضية" />
          <EmptyState icon={<Search className="size-5" />} title="مفيش نتايج" action={<Button size="sm">مسح البحث</Button>}>
            جرّب رقم الطلب أو آخر 4 أرقام من الموبايل.
          </EmptyState>
        </Panel>
      </div>

      <Dialog
        open={open}
        onOpenChange={setOpen}
        title="تأكيد التسليم"
        description="الجهاز هيتعلّم إنه اتسلّم للعميل."
        footer={
          <>
            <Button variant="ghost" onClick={() => setOpen(false)}>
              إلغاء
            </Button>
            <Button variant="primary" onClick={() => setOpen(false)}>
              تأكيد
            </Button>
          </>
        }
      >
        <p className="text-sm text-fg-2">العملية دي بتتسجل في سجل النشاط.</p>
      </Dialog>
    </div>
  );
}
