import { useEffect, useRef, useState, type ReactNode } from 'react';
import { SelectMenu } from '../../ui/SelectMenu';
import { Link } from 'react-router';
import { AnimatePresence, motion } from 'motion/react';
import { useTranslation } from 'react-i18next';
import { ArrowLeft, ArrowRight, Banknote, Building2, Check, CreditCard, ImagePlus, Landmark, Moon, Smartphone, Sun, Wallet, Zap, type LucideIcon } from 'lucide-react';
import { useAuth } from '../../app/auth';
import { usePrefs } from '../../app/prefs';
import { supabase } from '../../lib/supabase';
import { retryAfterSeconds, errorMessage } from '../../lib/errors';
import { checkPassword, isEmail } from '../../lib/password';
import { normalizeEgyptPhone } from '../../lib/phone';
import { COUNTRIES, PAYMENT_METHODS, REGIONS, type Country, type PaymentMethod } from '../../lib/regions';
import type { LineIconName } from '../../ui/fx/LineIcon';
import { Button } from '../../ui/Button';
import { Field, Input } from '../../ui/Field';
import { checkLogoFile, loadImage, logoUploadError, prepareLogoUpload, renderColor, renderThermal, trimCanvas } from '../../lib/brandImage';
import { toLatinDigits } from '../../lib/digits';
import { Alert } from '../../ui/Feedback';
import { OtpInput } from '../../ui/OtpInput';
import { useToast } from '../../ui/Toast';
import { cn } from '../../ui/cn';
import { AuthLayout } from './AuthLayout';

const STEPS = ['shop', 'account', 'verify', 'region', 'payments', 'layout', 'identity', 'brand'] as const;
type StepKey = (typeof STEPS)[number];
const STEP_ICON: Record<StepKey, LineIconName> = { shop: 'store', account: 'shield', verify: 'mail', region: 'globe', payments: 'wallet', layout: 'store', identity: 'receipt', brand: 'palette' };
const PAY_ICON: Record<PaymentMethod, LucideIcon> = { cash: Banknote, card: CreditCard, bank_transfer: Landmark, wallet: Wallet, instapay: Zap, installments: Smartphone };

import { draftMode, hasRegisterDraft, loadDraft, regMeta, saveDraft, type RegMeta, type WizardMode } from './registerDraft';
export { draftMode, hasRegisterDraft, regMeta, type RegMeta, type WizardMode };

/** الرابط اللي إيميل التأكيد بيرجّع عليه (نفس عنوان البرنامج) */
function confirmRedirect(): string {
  return `${window.location.origin}${window.location.pathname}`;
}

/** تسجيل محل جديد على 6 خطوات. لو المستخدم رجع بعد التأكيد، بيكمّل من آخر خطوة. */
export function RegisterWizard({ mode: modeProp, resume = false }: { mode?: WizardMode; /** داخل بحساب ومالوش محل ولا دعوة: يكمّل تسجيل المحل من غير حساب جديد */ resume?: boolean } = {}) {
  const { t } = useTranslation();
  const { session, profile, shop, refresh, signOut } = useAuth();
  const { setTheme, theme } = usePrefs();
  const toast = useToast();
  const draft = loadDraft();
  const meta = regMeta(session);
  const mode: WizardMode = modeProp ?? draft?.mode ?? meta?.reg_mode ?? 'shop';
  const invite = mode === 'invite';
  const first = invite ? 1 : 0;
  // داخل بحساب متأكد ومن غير محل لسه (رجع من رابط التأكيد، أو دخل بعد ما أكد): بنكمّل من خطوة التأكيد، وهي بتعدّي لوحدها
  const confirmedNoProfile = Boolean(session) && !profile;
  const resumeAt =
    profile && shop && !shop.setup_completed_at
      ? Math.max(3, draft?.step ?? 3)
      : resume
        ? 0
        : confirmedNoProfile
          ? Math.max(2, draft?.step ?? 2)
          : Math.max(first, draft?.step ?? first);
  // C7: بيانات تجريبية في آخر خطوة (اختياري)
  const [demo, setDemo] = useState(false);
  const [step, setStep] = useState(resumeAt);
  // U1: شكل الشغل
  const [layout, setLayout] = useState<'single' | 'multi'>('single');
  const newRow = () => ({ id: crypto.randomUUID(), name: '', kind: 'both', address: '', phone: '' });
  const [branchRows, setBranchRows] = useState<{ id: string; name: string; kind: string; address: string; phone: string }[]>(() => [newRow(), newRow()]);
  const setRow = (i: number, p: Partial<{ name: string; kind: string; address: string; phone: string }>) => setBranchRows((rs) => rs.map((x, j) => (j === i ? { ...x, ...p } : x)));
  const [dir, setDir] = useState(1);

  const [shopName, setShopName] = useState(draft?.shopName ?? meta?.shop_name ?? '');
  const [ownerName, setOwnerName] = useState(draft?.ownerName ?? meta?.owner_name ?? '');
  const [shopPhone, setShopPhone] = useState(draft?.shopPhone ?? meta?.shop_phone ?? '');
  const [area, setArea] = useState(draft?.area ?? meta?.area ?? '');
  const [email, setEmail] = useState(draft?.email ?? session?.user.email ?? '');
  const [password, setPassword] = useState('');
  const [password2, setPassword2] = useState('');
  const [code, setCode] = useState('');
  const [codeBad, setCodeBad] = useState(0);
  const [cooldown, setCooldown] = useState(0);
  const [country, setCountry] = useState<Country>((shop?.country as Country) ?? 'EG');
  const [methods, setMethods] = useState<PaymentMethod[]>((shop?.payment_methods as PaymentMethod[]) ?? ['cash', 'wallet', 'instapay']);
  const [logo, setLogo] = useState<{ file: File; url: string } | null>(null);
  const [idNameEn, setIdNameEn] = useState('');
  const [idTagline, setIdTagline] = useState('');
  const [idWhatsapp, setIdWhatsapp] = useState('');
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [touched, setTouched] = useState<Record<string, boolean>>({});
  const [attempt, setAttempt] = useState(0);

  const key = STEPS[step];
  const shopIdRef = useRef<string | null>(shop?.id ?? null);
  function shopId(): string {
    return shopIdRef.current ?? '';
  }
  const { i18n } = useTranslation();
  const rtl = i18n.dir() === 'rtl';
  const pw = checkPassword(password);

  useEffect(() => {
    saveDraft({ mode, step, shopName, ownerName, shopPhone, area, email });
  }, [mode, step, shopName, ownerName, shopPhone, area, email]);

  useEffect(() => {
    if (cooldown <= 0) return;
    const tm = setTimeout(() => setCooldown((c) => c - 1), 1000);
    return () => clearTimeout(tm);
  }, [cooldown]);

  const go = (to: number) => {
    setDir(to > step ? 1 : -1);
    setError(null);
    setStep(to);
  };
  const fail = (e: unknown) => {
    setAttempt((a) => a + 1);
    setError(typeof e === 'string' ? e : errorMessage(e));
  };

  async function bootstrapAndContinue() {
    if (invite) return joinInvite();
    const { error: be } = await supabase.rpc('bootstrap_account', { p_full_name: ownerName.trim(), p_shop_name: shopName.trim() || null });
    // لو التأكيد اتفتح في تبويبين في نفس الوقت، التاني بيفشل لأن الحساب اتعمل خلاص (من غير ما يتعمل محل تاني): نكمّل عادي
    if (be && !(await hasProfile())) throw be;
    const { data: me } = await supabase.from('profiles').select('shop_id').single();
    if (me) {
      shopIdRef.current = me.shop_id;
      const phone = normalizeEgyptPhone(shopPhone) ?? (shopPhone.trim() || null);
      await supabase.from('shops').update({ phone, address: area.trim() || null }).eq('id', me.shop_id);
    }
    go(3);
  }

  async function hasProfile() {
    const { data } = await supabase.from('profiles').select('id').maybeSingle();
    return Boolean(data);
  }

  // موظف معاه دعوة: بينضم للمحل اللي عزمه، بالاسم اللي صاحب المحل كتبه
  async function joinInvite() {
    const { data: inv, error: ie } = await supabase.rpc('my_pending_invite');
    if (ie) throw ie;
    const row = Array.isArray(inv) ? (inv[0] as { shop_name: string; full_name: string } | undefined) : undefined;
    if (!row) throw new Error(t('onboarding.noInvite'));
    const { error: be } = await supabase.rpc('bootstrap_account', { p_full_name: row.full_name, p_shop_name: null });
    if (be && !(await hasProfile())) throw be;
    saveDraft(null);
    toast({ tone: 'ok', title: t('onboarding.joinTitle'), description: row.shop_name });
    await refresh();
  }

  async function next() {
    setError(null);
    try {
      setBusy(true);
      if (key === 'shop') {
        setTouched((x) => ({ ...x, ownerName: true }));
        if (!ownerName.trim()) return fail(t('common.required'));
        // الحساب موجود ومتأكد خلاص (تسجيل اتقطع في النص): نعمل المحل على طول من غير حساب تاني
        if (session && !profile) {
          autoRan.current = true;
          await bootstrapAndContinue();
        } else go(1);
      } else if (key === 'account') {
        setTouched((x) => ({ ...x, email: true, password: true, password2: true }));
        if (!isEmail(email)) return fail(t('register.emailInvalid'));
        if (!pw.rules.len) return fail(t('errors.weakPassword'));
        if (password !== password2) return fail(t('register.mismatch'));
        const regData: RegMeta = invite
          ? { reg_mode: 'invite' }
          : { reg_mode: 'shop', shop_name: shopName.trim(), owner_name: ownerName.trim(), shop_phone: shopPhone.trim(), area: area.trim() };
        const { data, error: se } = await supabase.auth.signUp({
          email: email.trim().toLowerCase(),
          password,
          // الإيميل ممكن يكون فيه رابط تأكيد (قالب Supabase الافتراضي) أو كود من 6 أرقام (القالب المتعدّل)، والاتنين شغالين
          options: { emailRedirectTo: confirmRedirect(), data: regData },
        });
        if (se) return fail(se);
        // إيميل عنده حساب متأكد: Supabase بيرد عادي من غير ما يبعت حاجة، فما نستناش كود
        if (!data.session && data.user?.identities?.length === 0) return fail(t('errors.exists'));
        if (data.session) {
          // "Confirm email" مقفول في المشروع: نكمّل على طول
          autoRan.current = true;
          await bootstrapAndContinue();
        } else {
          setCooldown(60);
          go(2);
        }
      } else if (key === 'verify') {
        await verify(code);
      } else if (key === 'region') {
        const r = REGIONS[country];
        const { error: ue } = await supabase.from('shops').update({ country, currency: r.currency }).eq('id', shopId());
        if (ue) return fail(ue);
        go(4);
      } else if (key === 'payments') {
        if (methods.length === 0) return fail(t('register.pickOne'));
        const { error: ue } = await supabase.from('shops').update({ payment_methods: methods }).eq('id', shopId());
        if (ue) return fail(ue);
        go(5);
      } else if (key === 'layout') {
        // U1: محل واحد (البرنامج يفضل بسيط) أو فروع (الرئيسي + اللي بعده بالاسم والنوع والعنوان والتليفون)
        if (layout === 'multi') {
          const rows = branchRows.map((b) => ({ ...b, name: b.name.trim() }));
          if (rows.length < 2 || rows.some((b) => !b.name)) return fail(t('register.layout.errRows'));
          const { data: mb, error: me } = await supabase.from('branches').select('id').eq('is_main', true).is('deleted_at', null).maybeSingle();
          if (me || !mb) return fail(me ?? t('register.layout.errRows'));
          for (let i = 0; i < rows.length; i++) {
            const b = rows[i];
            const bid = i === 0 ? (mb as { id: string }).id : b.id;
            const { error: se } = await supabase.rpc('save_branch', { p_id: bid, p_name: b.name, p_prefix: i === 0 ? '' : `B${i + 1}`, p_phone: b.phone.trim() || null, p_address: b.address.trim() || null });
            if (se && !/E_DUP/.test(se.message)) return fail(se);
            const { error: ke } = await supabase.rpc('set_branch_kind', { p_id: bid, p_kind: b.kind });
            if (ke) return fail(ke);
          }
        }
        go(6);
      } else if (key === 'identity') {
        // هوية المحل (اختيارية): اللوجو الأصلي في Storage تحت المحل، ونسخة ملونة ونسخة حرارية جاهزين للطباعة
        const id = shopId();
        if (logo || idNameEn.trim() || idTagline.trim() || idWhatsapp.trim()) {
          let logo_color: string | null = null;
          let logo_thermal: string | null = null;
          let img: HTMLImageElement | null = null;
          if (logo) {
            const c = checkLogoFile(logo.file);
            if (c !== 'ok') return fail(t(c === 'type' ? 'identity.errType' : 'identity.errSize'));
            img = await loadImage(logo.file);
            const color = trimCanvas(renderColor(img, 1, 0, 0));
            logo_color = color.toDataURL('image/png');
            logo_thermal = trimCanvas(renderThermal(color, 50)).toDataURL('image/png');
          }
          // اللوجو اللي بيتطبع بيتحفظ مع الهوية نفسها، فبيظهر على طول حتى لو رفع الأصل على Storage فشل
          const brandId = crypto.randomUUID();
          const { error: be } = await supabase.from('shop_branding').insert({
            id: brandId,
            shop_id: id,
            name_en: idNameEn.trim() || null,
            tagline: idTagline.trim() || null,
            whatsapp: toLatinDigits(idWhatsapp.trim()) || null,
            logo_color,
            logo_thermal,
          });
          if (be && !/duplicate key/i.test(be.message)) return fail(be);
          if (logo && img && !be) {
            try {
              const up0 = await prepareLogoUpload(logo.file, img);
              const path = `${id}/logo-${crypto.randomUUID()}.${up0.ext}`;
              const up = await supabase.storage.from('shop-logos').upload(path, up0.blob, { contentType: up0.type, upsert: false });
              if (up.error) throw up.error;
              await supabase.from('shop_branding').update({ logo_path: path }).eq('id', brandId);
            } catch (e) {
              toast({ tone: 'warn', title: t('identity.logo'), description: t('identity.savedNoOriginal', { why: t(logoUploadError(e)) }), duration: 10_000 });
            }
          }
        }
        go(7);
      } else if (key === 'brand') {
        const id = shopId();
        const { error: ue } = await supabase
          .from('shops')
          .update({ theme, setup_completed_at: new Date().toISOString() })
          .eq('id', id);
        if (ue) return fail(ue);
        // C7: بيانات تجريبية (اختياري): المحل لسه فاضي، فبتتحمّل وبتتمسح بعدين من الإعدادات
        if (demo) {
          const { error: de } = await supabase.rpc('load_demo');
          if (de) toast({ tone: 'warn', title: errorMessage(de) });
        }
        saveDraft(null);
        toast({ tone: 'ok', title: t('register.doneTitle'), description: t('register.doneText') });
        await refresh();
      }
    } catch (e) {
      fail(e);
    } finally {
      setBusy(false);
    }
  }

  useEffect(() => {
    if (step >= 3 && !shopIdRef.current) {
      void supabase
        .from('profiles')
        .select('shop_id')
        .maybeSingle()
        .then(({ data }) => {
          if (data) shopIdRef.current = data.shop_id;
        });
    }
  }, [step]);

  // الحساب اتأكد (رجعنا بجلسة): التسجيل بيكمّل لوحده مرة واحدة
  const autoRan = useRef(false);
  useEffect(() => {
    if (key !== 'verify' || !session || profile || autoRan.current) return;
    autoRan.current = true;
    setBusy(true);
    bootstrapAndContinue()
      .catch((e) => {
        autoRan.current = false;
        fail(e);
      })
      .finally(() => setBusy(false));
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [key, session, profile]);

  // اتأكد من الرابط (في تبويب تاني أو على جهاز تاني)؟ بنجرّب ندخل بنفس الإيميل وكلمة السر:
  // لما يرجع للبرنامج (focus)، وكل 15 ثانية، وبالزرار. لحد ما الإيميل يتأكد، الدخول بيترفض وبنكمّل استنى
  const [checking, setChecking] = useState(false);
  const [notYet, setNotYet] = useState(false);
  async function checkConfirmed(manual: boolean) {
    if (session || !password || checking) return;
    setChecking(true);
    const { error: le } = await supabase.auth.signInWithPassword({ email: email.trim().toLowerCase(), password });
    setChecking(false);
    if (le && manual) setNotYet(true);
  }
  useEffect(() => {
    if (key !== 'verify' || session || !password) return;
    const onFocus = () => void checkConfirmed(false);
    const onVis = () => document.visibilityState === 'visible' && onFocus();
    window.addEventListener('focus', onFocus);
    document.addEventListener('visibilitychange', onVis);
    const iv = window.setInterval(onFocus, 15_000);
    return () => {
      window.removeEventListener('focus', onFocus);
      document.removeEventListener('visibilitychange', onVis);
      clearInterval(iv);
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [key, session, password]);

  async function verify(token: string) {
    if (token.length !== 6) return;
    autoRan.current = true;
    setBusy(true);
    const { error: ve } = await supabase.auth.verifyOtp({ email: email.trim().toLowerCase(), token, type: 'signup' });
    if (ve) {
      autoRan.current = false;
      setBusy(false);
      setCodeBad((c) => c + 1);
      setCode('');
      return fail(t('register.codeWrong'));
    }
    try {
      await bootstrapAndContinue();
    } catch (e) {
      fail(e);
    } finally {
      setBusy(false);
    }
  }

  async function resend() {
    const { error: re } = await supabase.auth.resend({ type: 'signup', email: email.trim().toLowerCase(), options: { emailRedirectTo: confirmRedirect() } });
    if (re) {
      // Supabase بيقول "استنى N ثانية": العداد بيبدأ منها
      const wait = retryAfterSeconds(re);
      if (wait) setCooldown(wait);
      return fail(re);
    }
    setCooldown(60);
    toast({ tone: 'info', title: t('register.resent') });
  }

  const canBack = step > first && step !== 3 && step !== 2;
  const visible = invite ? (['account', 'verify'] as StepKey[]) : resume ? STEPS.filter((k) => k !== 'account' && k !== 'verify') : [...STEPS];
  const vIndex = Math.max(0, visible.indexOf(key));
  const title = invite && key === 'account' ? t('register.invite.title') : resume && key === 'shop' ? t('register.resume.title') : t(`register.steps.${key}.title`);
  const desc = invite && key === 'account' ? t('register.invite.desc') : resume && key === 'shop' ? t('register.resume.desc') : t(`register.steps.${key}.desc`);

  return (
    <AuthLayout asideIcon={STEP_ICON[key]} asideKey={key} asideTitle={title} asideText={desc}>
      <div className="glass edge-glow relative shadow-3 overflow-hidden rounded-2xl">
        {/* المؤشر وشريط التقدم */}
        <div className="px-7 pt-6">
          <div className="flex items-center justify-between text-xs">
            <span className="font-medium text-accent">{t('register.step', { n: vIndex + 1, total: visible.length })}</span>
            <span className="flex gap-1" aria-hidden>
              {visible.map((s, i) => (
                <span key={s} className={cn('h-1 w-5 rounded-full transition-colors duration-300', i <= vIndex ? 'bg-accent shadow-[0_0_8px_var(--accent-glow)]' : 'bg-line-strong')} />
              ))}
            </span>
          </div>
          <div className="mt-3 h-[3px] overflow-hidden rounded-full bg-sunken" role="progressbar" aria-valuemin={1} aria-valuemax={visible.length} aria-valuenow={vIndex + 1}>
            <motion.div className="h-full rounded-full bg-accent shadow-[0_0_10px_var(--accent-glow)]" style={{ transformOrigin: rtl ? 'right' : 'left' }} animate={{ scaleX: (vIndex + 1) / visible.length }} transition={{ duration: 0.4, ease: [0.2, 0.8, 0.2, 1] }} />
          </div>
          <h1 className="mt-5 text-xl font-semibold text-fg">{title}</h1>
          <p className="mt-1 text-sm text-fg-3">{desc}</p>
        </div>

        <form
          noValidate
          onSubmit={(e) => {
            e.preventDefault();
            void next();
          }}
        >
          <div className="relative min-h-[300px] px-7 py-5">
            <AnimatePresence mode="wait" custom={dir} initial={false}>
              <motion.div
                key={key}
                custom={dir}
                initial={{ opacity: 0, x: 24 * dir * (rtl ? -1 : 1) }}
                animate={{ opacity: 1, x: 0 }}
                exit={{ opacity: 0, x: -24 * dir * (rtl ? -1 : 1) }}
                transition={{ duration: 0.22, ease: [0.2, 0.8, 0.2, 1] }}
                className="flex flex-col gap-4"
              >
                {key === 'shop' && (
                  <>
                    {resume && (
                      <div className="flex flex-wrap items-center justify-between gap-2 rounded-md border border-glass-border bg-sunken/40 px-3 py-2 text-xs text-fg-2" data-testid="resume-account">
                        <span>
                          {t('register.resume.account')}{' '}
                          <b className="num text-fg" dir="ltr">
                            {session?.user.email}
                          </b>
                        </span>
                        <button type="button" onClick={() => void signOut()} className="text-fg-3 hover:text-fg">
                          {t('register.resume.other')}
                        </button>
                      </div>
                    )}
                    <Field label={t('register.shopName')} hint={t('register.shopNameHint')}>
                      <Input autoFocus value={shopName} onChange={(e) => setShopName(e.target.value)} maxLength={120} placeholder={t('register.shopNamePh')} />
                    </Field>
                    <Field label={t('register.ownerName')} required error={touched.ownerName && !ownerName.trim() ? t('common.required') : null}>
                      <Input value={ownerName} onChange={(e) => setOwnerName(e.target.value)} maxLength={120} onBlur={() => setTouched((x) => ({ ...x, ownerName: true }))} />
                    </Field>
                    <div className="grid gap-4 sm:grid-cols-2">
                      <Field label={t('register.shopPhone')} hint={t('common.optional')}>
                        <Input dir="ltr" mono inputMode="tel" value={shopPhone} onChange={(e) => setShopPhone(e.target.value)} className="text-start" />
                      </Field>
                      <Field label={t('register.shopArea')} hint={t('common.optional')}>
                        <Input value={area} onChange={(e) => setArea(e.target.value)} />
                      </Field>
                    </div>
                  </>
                )}

                {key === 'account' && (
                  <>
                    <Field
                      label={t('register.email')}
                      error={touched.email && email && !isEmail(email) ? t('register.emailInvalid') : null}
                      aside={isEmail(email) ? <Ok label={t('register.emailOk')} /> : undefined}
                    >
                      <Input type="email" dir="ltr" autoFocus autoComplete="email" value={email} onChange={(e) => setEmail(e.target.value)} onBlur={() => setTouched((x) => ({ ...x, email: true }))} className="text-start" />
                    </Field>
                    <Field label={t('register.password')}>
                      <Input type="password" dir="ltr" autoComplete="new-password" value={password} onChange={(e) => setPassword(e.target.value)} className="text-start" />
                    </Field>
                    <Strength score={password ? pw.score : -1} rules={pw.rules} />
                    <Field
                      label={t('register.password2')}
                      error={touched.password2 && password2 && password !== password2 ? t('register.mismatch') : null}
                      aside={password2 && password === password2 ? <Ok label={t('register.match')} /> : undefined}
                    >
                      <Input type="password" dir="ltr" autoComplete="new-password" value={password2} onChange={(e) => setPassword2(e.target.value)} onBlur={() => setTouched((x) => ({ ...x, password2: true }))} className="text-start" />
                    </Field>
                  </>
                )}

                {key === 'verify' && (
                  <div className="flex flex-col items-center gap-4 pt-2 text-center">
                    <p className="text-sm text-fg-2">
                      {t('register.codeSent')}{' '}
                      <b className="num text-fg" dir="ltr">
                        {email}
                      </b>
                    </p>
                    {/* الإيميل الافتراضي فيه رابط، والقالب المتعدّل فيه كود: الاتنين بيدخّلوا */}
                    <div className="w-full rounded-lg border border-glass-border bg-sunken/40 p-3 text-start text-sm text-fg-2" data-testid="verify-link-hint">
                      <div className="font-medium text-fg">{t('register.linkTitle')}</div>
                      <p className="mt-1 text-xs">{password ? t('register.linkText') : t('register.linkTextNoPw')}</p>
                      {password ? (
                        <Button size="sm" variant="secondary" className="mt-2" loading={checking} onClick={() => void checkConfirmed(true)}>
                          {t('register.linkDone')}
                        </Button>
                      ) : (
                        <a href="#/" className="mt-2 inline-block text-xs font-medium text-accent hover:underline">
                          {t('register.linkLogin')}
                        </a>
                      )}
                      {notYet && <p className="mt-2 text-xs text-warn" role="status">{t('register.linkNotYet')}</p>}
                    </div>
                    <div className="text-xs text-fg-3">{t('register.orCode')}</div>
                    <OtpInput
                      label={t('register.codeLabel')}
                      value={code}
                      invalid={codeBad > 0 && !!error}
                      disabled={busy}
                      onChange={(v) => {
                        setCode(v);
                        if (error) setError(null);
                        if (v.length === 6) void verify(v);
                      }}
                    />
                    <p className="text-xs text-fg-3">{t('register.paste')}</p>
                    <div className="flex items-center gap-3 text-sm">
                      {cooldown > 0 ? (
                        <span className="text-fg-3 tabular-nums">{t('register.resendIn', { s: cooldown })}</span>
                      ) : (
                        <button type="button" onClick={() => void resend()} className="font-medium text-accent hover:underline">
                          {t('register.resend')}
                        </button>
                      )}
                      <span className="text-line-strong">|</span>
                      <button type="button" onClick={() => go(1)} className="text-fg-3 hover:text-fg">
                        {t('register.changeEmail')}
                      </button>
                    </div>
                  </div>
                )}

                {key === 'region' && (
                  <>
                    <div className="grid grid-cols-2 gap-2 sm:grid-cols-3" role="radiogroup" aria-label={t('register.country')}>
                      {COUNTRIES.map((c) => (
                        <Choice key={c} selected={country === c} onClick={() => setCountry(c)} role="radio">
                          <span className="num text-2xs text-fg-3">{c}</span>
                          <span className="text-sm font-medium text-fg">{t(`countries.${c}`)}</span>
                        </Choice>
                      ))}
                    </div>
                    <div className="rounded-lg border border-glass-border bg-sunken/50 p-3">
                      <div className="mb-2 flex items-center gap-1.5 text-2xs text-accent">
                        <Check className="size-3" /> {t('register.autofilled')}
                      </div>
                      <dl className="grid grid-cols-3 gap-3">
                        <ReadoutItem label={t('register.currency')} value={`${REGIONS[country].currency} · ${t(`currency.${REGIONS[country].currency}`)}`} />
                        <ReadoutItem label={t('register.timezone')} value={REGIONS[country].tz} mono />
                        <ReadoutItem label={t('register.phoneCode')} value={REGIONS[country].dial} mono />
                      </dl>
                    </div>
                  </>
                )}

                {key === 'payments' && (
                  <div className="grid grid-cols-2 gap-2 sm:grid-cols-3" role="group" aria-label={t('register.steps.payments.title')}>
                    {PAYMENT_METHODS.map((m) => {
                      const Icon = PAY_ICON[m];
                      const on = methods.includes(m);
                      return (
                        <Choice key={m} selected={on} onClick={() => setMethods((cur) => (on ? cur.filter((x) => x !== m) : [...cur, m]))} role="checkbox">
                          <Icon className={cn('size-5 transition-colors', on ? 'text-accent' : 'text-fg-3')} aria-hidden />
                          <span className="text-sm font-medium text-fg">{t(`payments.${m}`)}</span>
                          <span className="text-2xs text-fg-3">{t(`payments.${m}_d`)}</span>
                        </Choice>
                      );
                    })}
                  </div>
                )}

                {key === 'layout' && (
                  <div className="flex flex-col gap-3" data-testid="layout-step">
                    <div className="grid grid-cols-2 gap-2" role="radiogroup" aria-label={t('register.steps.layout.title')}>
                      {(['single', 'multi'] as const).map((k) => (
                        <Choice key={k} selected={layout === k} onClick={() => setLayout(k)} role="radio">
                          <span className="text-sm font-medium text-fg">{t(`register.layout.${k}`)}</span>
                          <span className="text-2xs text-fg-3">{t(`register.layout.${k}_d`)}</span>
                        </Choice>
                      ))}
                    </div>
                    {layout === 'multi' && (
                      <div className="flex flex-col gap-2">
                        {branchRows.map((b, i) => (
                          <div key={b.id} className="grid grid-cols-2 gap-2 rounded-md border border-glass-border p-2 sm:grid-cols-4" data-testid="layout-branch">
                            <Input value={b.name} onChange={(e) => setRow(i, { name: e.target.value })} maxLength={80} placeholder={i === 0 ? t('register.layout.mainPh') : t('register.layout.branchPh', { n: i + 1 })} aria-label={t('register.layout.name', { n: i + 1 })} />
                            <SelectMenu wrapClassName="block min-w-0" value={b.kind} onChange={(e) => setRow(i, { kind: e.target.value })} aria-label={t('register.layout.kind', { n: i + 1 })} className="w-full h-9 rounded-md border border-line bg-sunken/60 pe-7 ps-2 text-sm text-fg">
                              {(['both', 'repair', 'sales'] as const).map((k) => (
                                <option key={k} value={k}>
                                  {t(`perm.kinds.${k}`)}
                                </option>
                              ))}
                            </SelectMenu>
                            <Input value={b.address} onChange={(e) => setRow(i, { address: e.target.value })} maxLength={200} placeholder={t('branch.address')} aria-label={`${t('branch.address')} ${i + 1}`} />
                            <Input value={b.phone} onChange={(e) => setRow(i, { phone: e.target.value })} dir="ltr" inputMode="tel" maxLength={40} placeholder={t('branch.phone')} aria-label={`${t('branch.phone')} ${i + 1}`} />
                          </div>
                        ))}
                        <div className="flex gap-2">
                          <Button size="sm" variant="ghost" onClick={() => setBranchRows((rs) => [...rs, newRow()])} data-testid="layout-add">
                            {t('register.layout.add')}
                          </Button>
                          {branchRows.length > 2 && (
                            <Button size="sm" variant="ghost" onClick={() => setBranchRows((rs) => rs.slice(0, -1))}>
                              {t('register.layout.removeLast')}
                            </Button>
                          )}
                        </div>
                        <p className="text-2xs text-fg-3">{t('register.layout.later')}</p>
                      </div>
                    )}
                    {layout === 'single' && <p className="text-2xs text-fg-3">{t('register.layout.singleLater')}</p>}
                  </div>
                )}

                {key === 'identity' && (
                  <>
                    <div className="flex items-center gap-4">
                      <div className="grid size-20 shrink-0 place-items-center overflow-hidden rounded-xl border border-dashed border-line-strong bg-sunken/50">
                        {logo ? <img src={logo.url} alt="" className="size-full object-contain p-1.5" /> : <Building2 className="size-7 text-fg-3" aria-hidden />}
                      </div>
                      <div className="flex flex-col gap-1.5">
                        <div className="text-sm font-medium text-fg">{t('register.logo')}</div>
                        <div className="text-xs text-fg-3">{t('register.logoHint')}</div>
                        <label className="w-fit">
                          <span className="glass inline-flex h-8 cursor-pointer items-center gap-1.5 rounded-sm px-3 text-sm text-fg hover:border-glass-border-strong">
                            <ImagePlus className="size-4" /> {logo ? t('register.logoChange') : t('register.logoPick')}
                          </span>
                          <input
                            type="file"
                            accept="image/png,image/jpeg,image/svg+xml,image/webp"
                            className="sr-only"
                            aria-label={t('identity.logo')}
                            onChange={(e) => {
                              const f = e.target.files?.[0];
                              if (f) setLogo({ file: f, url: URL.createObjectURL(f) });
                              e.target.value = '';
                            }}
                          />
                        </label>
                      </div>
                    </div>
                    <div className="grid gap-3 sm:grid-cols-2">
                      <Field label={t('identity.nameEn')}>
                        <Input dir="ltr" value={idNameEn} onChange={(e) => setIdNameEn(e.target.value)} maxLength={120} className="text-start" />
                      </Field>
                      <Field label={t('identity.whatsapp')}>
                        <Input dir="ltr" mono inputMode="tel" value={idWhatsapp} onChange={(e) => setIdWhatsapp(e.target.value)} className="text-start" />
                      </Field>
                      <Field label={t('identity.tagline')} className="sm:col-span-2">
                        <Input value={idTagline} onChange={(e) => setIdTagline(e.target.value)} maxLength={120} />
                      </Field>
                    </div>
                    <p className="text-xs text-fg-3">{t('register.identityLater')}</p>
                  </>
                )}

                {key === 'brand' && (
                  <>
                    {mode === 'shop' && (
                      <label className="flex items-start gap-2 rounded-md border border-glass-border p-3 text-sm" data-testid="register-demo">
                        <input type="checkbox" checked={demo} onChange={(e) => setDemo(e.target.checked)} className="mt-0.5 size-4 accent-[var(--accent)]" />
                        <span>
                          <span className="font-medium text-fg">{t('demo.try')}</span>
                          <span className="block text-xs text-fg-3">{t('demo.tryHint')}</span>
                        </span>
                      </label>
                    )}
                    <div>
                      <div className="mb-2 text-sm font-medium text-fg-2">{t('register.theme')}</div>
                      <div className="grid grid-cols-2 gap-2" role="radiogroup" aria-label={t('register.theme')}>
                        {(['dark', 'light'] as const).map((m) => (
                          <Choice key={m} selected={theme === m} onClick={() => setTheme(m)} role="radio">
                            <ThemePreview mode={m} />
                            <span className="flex items-center gap-1.5 text-sm font-medium text-fg">
                              {m === 'dark' ? <Moon className="size-3.5" /> : <Sun className="size-3.5" />}
                              {m === 'dark' ? t('register.themeDark') : t('register.themeLight')}
                            </span>
                          </Choice>
                        ))}
                      </div>
                    </div>
                  </>
                )}
              </motion.div>
            </AnimatePresence>
            {error && (
              <div key={attempt} className="mt-4">
                <Alert tone="danger">{error}</Alert>
              </div>
            )}
          </div>

          <div className="flex items-center justify-between gap-2 border-t border-glass-border px-7 py-4">
            {canBack ? (
              <Button variant="ghost" onClick={() => go(step - 1)} icon={<ArrowLeft className="size-4 rtl:-scale-x-100" />}>
                {t('common.back')}
              </Button>
            ) : step === first ? (
              <span className="text-sm text-fg-3">
                {t('register.haveAccount')}{' '}
                <Link to="/" className="font-medium text-accent hover:underline">
                  {t('register.signIn')}
                </Link>
              </span>
            ) : (
              <span />
            )}
            {key === 'identity' && (
              <Button variant="ghost" className="ms-auto" onClick={() => go(7)} disabled={busy}>
                {t('register.skip')}
              </Button>
            )}
            {key !== 'verify' && (
              <Button type="submit" variant="primary" loading={busy}>
                {key === 'brand' ? t('register.finish') : t('common.next')}
                {!busy && <ArrowRight className="size-4 rtl:-scale-x-100" aria-hidden />}
              </Button>
            )}
            {key === 'verify' && busy && <span className="text-sm text-fg-3">{t('register.verifying')}</span>}
          </div>
        </form>
      </div>
    </AuthLayout>
  );
}

function Ok({ label }: { label: string }) {
  return (
    <motion.span initial={{ opacity: 0, scale: 0.8 }} animate={{ opacity: 1, scale: 1 }} className="flex items-center gap-1 text-2xs text-ok">
      <Check className="size-3" /> {label}
    </motion.span>
  );
}

function Strength({ score, rules }: { score: number; rules: Record<'len' | 'num' | 'case' | 'sym', boolean> }) {
  const { t } = useTranslation();
  const colors = ['var(--danger)', 'var(--danger)', 'var(--warn)', 'var(--ok)', 'var(--accent)'];
  return (
    <div className="-mt-1">
      <div className="flex items-center justify-between text-2xs">
        <span className="text-fg-3">{t('register.strength.label')}</span>
        {score >= 0 && (
          <span style={{ color: colors[score] }} className="font-medium">
            {t(`register.strength.${score}`)}
          </span>
        )}
      </div>
      <div className="mt-1.5 grid grid-cols-4 gap-1" aria-hidden>
        {[1, 2, 3, 4].map((i) => (
          <div key={i} className="h-1 overflow-hidden rounded-full bg-sunken">
            <motion.div className="h-full rounded-full" initial={false} animate={{ scaleX: score >= i ? 1 : 0, backgroundColor: colors[Math.max(0, score)] }} style={{ transformOrigin: 'var(--start-origin)' }} transition={{ duration: 0.25 }} />
          </div>
        ))}
      </div>
      <ul className="mt-2 grid grid-cols-2 gap-x-3 gap-y-1">
        {(['len', 'num', 'case', 'sym'] as const).map((r) => (
          <li key={r} className={cn('flex items-center gap-1.5 text-2xs transition-colors', rules[r] ? 'text-ok' : 'text-fg-3')}>
            <span className={cn('grid size-3 place-items-center rounded-full border', rules[r] ? 'border-ok bg-ok-soft' : 'border-line-strong')}>{rules[r] && <Check className="size-2" strokeWidth={4} />}</span>
            {t(`register.rules.${r}`)}
          </li>
        ))}
      </ul>
    </div>
  );
}

function Choice({ selected, onClick, children, role }: { selected: boolean; onClick: () => void; children: ReactNode; role: 'radio' | 'checkbox' }) {
  return (
    <button
      type="button"
      role={role}
      aria-checked={selected}
      onClick={onClick}
      className={cn(
        'lift relative flex flex-col items-start gap-1 rounded-lg border p-3 text-start',
        selected ? 'border-[rgb(var(--accent-rgb)/0.6)] bg-accent-soft' : 'border-glass-border bg-sunken/40 hover:bg-raised/60',
      )}
    >
      {selected && (
        <motion.span initial={{ scale: 0 }} animate={{ scale: 1 }} className="absolute end-2 top-2 grid size-4 place-items-center rounded-full bg-accent text-on-accent">
          <Check className="size-2.5" strokeWidth={4} />
        </motion.span>
      )}
      {children}
    </button>
  );
}

function ReadoutItem({ label, value, mono }: { label: string; value: string; mono?: boolean }) {
  return (
    <div className="min-w-0">
      <dt className="readout-label">{label}</dt>
      <dd className={cn('mt-0.5 truncate text-sm text-fg', mono && 'num')} dir={mono ? 'ltr' : undefined}>
        {value}
      </dd>
    </div>
  );
}

function ThemePreview({ mode }: { mode: 'dark' | 'light' }) {
  // data-theme على المعاينة نفسها: بتاخد ألوان الوضع ده من نظام التصميم، مهما كان الوضع الحالي
  return (
    <div data-theme={mode} className="mb-1 h-16 w-full overflow-hidden rounded-md border border-glass-border bg-bg" aria-hidden>
      <div className="flex h-full gap-1.5 p-1.5">
        <div className="w-1/4 rounded-sm bg-surface" />
        <div className="flex flex-1 flex-col gap-1.5">
          <div className="h-3 rounded-sm bg-raised" />
          <div className="flex flex-1 gap-1.5">
            <div className="flex-1 rounded-sm bg-raised" />
            <div className="flex-1 rounded-sm bg-raised shadow-[inset_0_-3px_0_var(--accent)]" />
          </div>
        </div>
      </div>
    </div>
  );
}
