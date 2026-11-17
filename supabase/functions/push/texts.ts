// الملف ده بيتولد تلقائيًا من src/i18n (notify.kinds و push). ما تعدّلوش بإيدك: npm run db:setup-file
export const TEXTS = {
  "ar": {
    "kinds": {
      "overdue": "{{name}}: قسط متأخر {{amount}} (ميعاده كان {{due}})",
      "due_soon": "{{name}}: قسط {{amount}} ميعاده {{due}}",
      "ready_old": "الجهاز {{order}} جاهز من {{days}} يوم ومحدش استلمه",
      "short": "{{name}} قرب يخلص (فاضل {{qty}})",
      "unsettled": "{{name}}: {{qty}} اتباعوا من غير رصيد ومحتاجين تسوية"
    },
    "titles": {
      "overdue": "قسط متأخر",
      "due_soon": "قسط قرب ميعاده",
      "ready_old": "جهاز مستني من بدري",
      "short": "صنف قرب يخلص",
      "unsettled": "بيع محتاج تسوية",
      "summary": "تنبيهات جديدة",
      "test": "تجربة الإشعارات"
    },
    "summary": "عندك {{n}} تنبيهات جديدة. افتح البرنامج تشوفها.",
    "test": "الإشعارات شغالة على الجهاز ده.",
    "open": "افتح",
    "read": "اتقرا"
  },
  "en": {
    "kinds": {
      "overdue": "{{name}}: overdue installment {{amount}} (was due {{due}})",
      "due_soon": "{{name}}: installment {{amount}} due {{due}}",
      "ready_old": "Device {{order}} has been ready for {{days}} days and not picked up",
      "short": "{{name}} is running low ({{qty}} left)",
      "unsettled": "{{name}}: {{qty}} sold without stock and need settlement"
    },
    "titles": {
      "overdue": "Overdue installment",
      "due_soon": "Installment due soon",
      "ready_old": "Device waiting too long",
      "short": "Item running low",
      "unsettled": "Sale needs settlement",
      "summary": "New notifications",
      "test": "Notification test"
    },
    "summary": "You have {{n}} new notifications. Open the app to see them.",
    "test": "Notifications work on this device.",
    "open": "Open",
    "read": "Mark read"
  }
} as const;
