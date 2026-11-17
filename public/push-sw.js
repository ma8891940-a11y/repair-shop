/* إشعارات على الجهاز (Web Push): الجزء ده بيتضاف للـ service worker بتاع البرنامج (vite.config.ts ← importScripts).
 * - الرسالة بتوصل متشفّرة وجاهزة (العنوان والكلام بلغة الجهاز) من Edge Function اسمها push.
 * - "افتح": بيفتح البرنامج على الحاجة نفسها (أو بيرجّع للنافذة المفتوحة).
 * - "اتقرا": بيعلّم الإشعار مقروء بالـ token بتاعه بس (push_ack)، من غير ما يفتح البرنامج.
 * من غير أي مكتبة ولا أي بيانات تانية. */
self.addEventListener('push', function (event) {
  var d = {};
  try {
    d = event.data ? event.data.json() : {};
  } catch (e) {
    d = {};
  }
  var base = self.registration.scope;
  event.waitUntil(
    self.registration.showNotification(d.title || 'Gawalak', {
      body: d.body || '',
      tag: d.tag || undefined,
      lang: d.lang || 'ar',
      dir: d.dir || 'rtl',
      icon: base + 'icon-192.png',
      badge: base + 'favicon-32.png',
      data: { url: typeof d.url === 'string' && d.url.charAt(0) === '/' ? d.url : '/', ack: d.ack || null },
      actions: Array.isArray(d.actions) ? d.actions.slice(0, 2) : [],
    }),
  );
});

self.addEventListener('notificationclick', function (event) {
  var n = event.notification;
  var data = n.data || {};
  n.close();
  var ack = data.ack;
  if (event.action === 'read' && ack && /^https:\/\//.test(ack.url) && /^[0-9a-f]{32}$/.test(ack.token)) {
    event.waitUntil(
      fetch(ack.url, {
        method: 'POST',
        headers: { apikey: ack.key, Authorization: 'Bearer ' + ack.key, 'Content-Type': 'application/json' },
        body: JSON.stringify({ p_token: ack.token }),
      }).catch(function () {}),
    );
    return;
  }
  var target = self.registration.scope + '#' + (data.url || '/');
  event.waitUntil(
    self.clients.matchAll({ type: 'window', includeUncontrolled: true }).then(function (list) {
      for (var i = 0; i < list.length; i++) {
        var c = list[i];
        if (c.url.indexOf(self.registration.scope) === 0 && 'focus' in c) {
          return c.focus().then(function (w) {
            return w && 'navigate' in w ? w.navigate(target) : w;
          });
        }
      }
      return self.clients.openWindow(target);
    }),
  );
});
