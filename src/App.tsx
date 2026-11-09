import { Suspense, useEffect, useRef, useState } from 'react';
import { HashRouter, Navigate, Route, Routes, useLocation, type Location } from 'react-router';
import { AnimatePresence, MotionConfig, motion } from 'motion/react';
import { useTranslation } from 'react-i18next';
import { AuthProvider, useAuth } from './app/auth';
import { SyncProvider } from './offline/sync';
import { PrefsProvider, usePrefs } from './app/prefs';
import { EffectsGuard } from './app/EffectsGuard';
import { MotionDiagPanel } from './app/MotionDiagPanel';
import { isConfigured } from './lib/supabase';
import { TooltipProvider } from './ui/Tooltip';
import { ToastProvider } from './ui/Toast';
import { SplashScreen } from './screens/SplashScreen';
import { LoginScreen } from './screens/auth/LoginScreen';
import { draftMode, hasRegisterDraft, regMeta } from './screens/auth/registerDraft';
import { lazyScreen, markBackgroundLoaded, whenIdle } from './app/lazyScreen';
import { getHandoffMs, initSplashSpeed, SPLASH_ANIM_MS } from './lib/splashTiming';

// كل شاشة في ملف لوحدها، عشان الافتتاحية والدخول يحمّلوا الأساس بس.
// الشاشات الأساسية بتتحمّل في الخلفية بعد الافتتاحية على طول، والباقي لما الجهاز يفضى (preloadAll تحت)
const AppShell = lazyScreen(() => import('./app/AppShell').then((m) => m.AppShell));
const RegisterWizard = lazyScreen(() => import('./screens/auth/RegisterWizard').then((m) => m.RegisterWizard));
const JoinScreen = lazyScreen(() => import('./screens/auth/JoinScreen').then((m) => m.JoinScreen));
const TrackingScreen = lazyScreen(() => import('./screens/TrackingScreen').then((m) => m.TrackingScreen));
const DashboardScreen = lazyScreen(() => import('./screens/DashboardScreen').then((m) => m.DashboardScreen));
const IntakeScreen = lazyScreen(() => import('./screens/IntakeScreen').then((m) => m.IntakeScreen));
const DeviceDetailScreen = lazyScreen(() => import('./screens/DeviceDetailScreen').then((m) => m.DeviceDetailScreen));
const DevicesScreen = lazyScreen(() => import('./screens/DevicesScreen').then((m) => m.DevicesScreen));
const FinanceScreen = lazyScreen(() => import('./screens/finance/FinanceScreen').then((m) => m.FinanceScreen));
const DrawerScreen = lazyScreen(() => import('./screens/finance/DrawerScreen').then((m) => m.DrawerScreen));
const TeamScreen = lazyScreen(() => import('./screens/TeamScreen').then((m) => m.TeamScreen));
const AuditScreen = lazyScreen(() => import('./screens/AuditScreen').then((m) => m.AuditScreen));
const SettingsScreen = lazyScreen(() => import('./screens/SettingsScreen').then((m) => m.SettingsScreen));
const PrintScreen = lazyScreen(() => import('./screens/PrintScreen').then((m) => m.PrintScreen));
const CustomersScreen = lazyScreen(() => import('./screens/CustomersScreen').then((m) => m.CustomersScreen));
const CustomerProfileScreen = lazyScreen(() => import('./screens/CustomersScreen').then((m) => m.CustomerProfileScreen));
const PartnersScreen = lazyScreen(() => import('./screens/finance/PartnersScreen').then((m) => m.PartnersScreen));
const OpeningScreen = lazyScreen(() => import('./screens/finance/OpeningScreen').then((m) => m.OpeningScreen));
const BarcodePrint = lazyScreen(() => import('./screens/finance/BarcodePrint').then((m) => m.BarcodePrint));
const EntryScreen = lazyScreen(() => import('./screens/finance/EntryScreen').then((m) => m.EntryScreen));
const StatementScreen = lazyScreen(() => import('./screens/finance/StatementScreen').then((m) => m.StatementScreen));
const BalancesScreen = lazyScreen(() => import('./screens/finance/BalancesScreen').then((m) => m.BalancesScreen));
const ProfitScreen = lazyScreen(() => import('./screens/finance/BalancesScreen').then((m) => m.ProfitScreen));
const InventoryScreen = lazyScreen(() => import('./screens/finance/InventoryScreen').then((m) => m.InventoryScreen));
const WorkScreen = lazyScreen(() => import('./screens/WorkScreen').then((m) => m.WorkScreen));
const ReportsScreen = lazyScreen(() => import('./screens/ReportsScreen').then((m) => m.ReportsScreen));
const DayReportPrint = lazyScreen(() => import('./screens/finance/FinancePrint').then((m) => m.DayReportPrint));
const StatementPrint = lazyScreen(() => import('./screens/finance/FinancePrint').then((m) => m.StatementPrint));
const VideosScreen = lazyScreen(() => import('./screens/VideosScreen').then((m) => m.VideosScreen));
const CommunityScreen = lazyScreen(() => import('./screens/CommunityScreen').then((m) => m.CommunityScreen));
const AdminScreen = lazyScreen(() => import('./screens/AdminScreen').then((m) => m.AdminScreen));

/** الأساسية: لوحة التحكم، والأجهزة وتفاصيل الجهاز، والاستلام، والخزنة (الوضع المالي والدرج)، وشاشة الفني */
const CORE = [AppShell, DashboardScreen, DevicesScreen, DeviceDetailScreen, IntakeScreen, FinanceScreen, DrawerScreen, WorkScreen];
const REST = [CustomersScreen, CustomerProfileScreen, InventoryScreen, SettingsScreen, PrintScreen, StatementScreen, EntryScreen, BarcodePrint, OpeningScreen, PartnersScreen, BalancesScreen, ProfitScreen, ReportsScreen, TeamScreen, AuditScreen, DayReportPrint, StatementPrint, VideosScreen, CommunityScreen, AdminScreen];
let preloaded = false;
/** بعد الافتتاحية على طول: الأساسية مع بعض، وبعدها الباقي واحدة واحدة لما الجهاز يفضى (عشان كله يشتغل من غير نت كمان) */
function preloadAll() {
  if (preloaded) return;
  preloaded = true;
  performance.mark('preload-start');
  void Promise.allSettled(CORE.map((c) => c.preload())).then(() => {
    const next = (i: number) => {
      if (i >= REST.length) return markBackgroundLoaded();
      whenIdle(() => void REST[i].preload().catch(() => undefined).finally(() => next(i + 1)));
    };
    next(0);
  });
}
import { Button } from './ui/Button';
import { StageProvider, useStage, type SplashPhase } from './app/stage';
import type { Role } from './lib/status';

// الافتتاحية: ظهور اللوجو والتجمّع والسكان في 0.8 ثانية، وبعدها اللوجو بيطير لمكانه (0.45 ثانية).
// المجموع حوالي 1.3 ثانية، وده سايب هامش لحد الثانية ونص حتى لو الجهاز مشغول
const SPLASH_MS = SPLASH_ANIM_MS;
const CALM_SPLASH_MS = 350;

function NotConfigured() {
  const { t } = useTranslation();
  useEffect(() => document.getElementById('boot')?.remove(), []);
  return (
    <div className="grid min-h-dvh place-items-center px-4">
      <div className="glass-strong max-w-md rounded-xl p-6">
        <h1 className="text-lg font-semibold">{t('errors.notConfiguredTitle')}</h1>
        <p className="mt-2 text-sm text-fg-2">{t('errors.notConfigured')}</p>
      </div>
    </div>
  );
}

/** المحل موقوف من المشرف: رسالة واضحة والبيانات محفوظة */
function Suspended() {
  const { t } = useTranslation();
  const { signOut } = useAuth();
  return (
    <div className="grid min-h-dvh place-items-center px-4">
      <div className="glass-strong max-w-md rounded-xl p-6" role="alert">
        <h1 className="text-lg font-semibold">{t('suspended.title')}</h1>
        <p className="mt-2 text-sm text-fg-2">{t('suspended.body')}</p>
        <Button className="mt-4" onClick={() => void signOut()}>
          {t('suspended.signOut')}
        </Button>
      </div>
    </div>
  );
}

function Gate() {
  const { loading, session, profile, shop, suspended, isAdmin } = useAuth();
  const location = useLocation();
  // صفحة تتبع العميل: عامة، بتشتغل بتسجيل دخول أو من غيره
  if (location.pathname === '/t' || location.pathname.startsWith('/t/')) {
    return (
      <Routes>
        <Route path="/t" element={<TrackingScreen key="form" />} />
        <Route path="/t/:token" element={<TrackingScreen key="token" />} />
      </Routes>
    );
  }
  if (loading) return null;

  // المعالج بيفضل في نفس المكان من الشجرة طول الخطوات، فحالته ما بتضيعش وقت تأكيد الإيميل
  const joinPath = !session && location.pathname === '/join';
  const wizard =
    joinPath ||
    (!session && location.pathname === '/register') ||
    // رجع من رابط التأكيد (حتى في تبويب أو جهاز تاني): بيانات التسجيل محفوظة مع الحساب
    (session && !profile && (hasRegisterDraft() || regMeta(session) !== null)) ||
    (session && profile?.role === 'owner' && shop && !shop.setup_completed_at);
  if (wizard) return <RegisterWizard mode={joinPath ? 'invite' : session ? draftMode(session) : 'shop'} />;

  if (!session) {
    return (
      <Routes>
        <Route path="*" element={<LoginScreen />} />
      </Routes>
    );
  }
  if (profile && !profile.deleted_at && shop && suspended && !isAdmin) return <Suspended />;
  if (!profile || profile.deleted_at || !shop) return <JoinScreen blocked={Boolean(profile?.deleted_at)} />;
  if (profile.role === 'marketing') return <MarketingRoutes />;
  return <AppRoutes role={profile.role} admin={isAdmin} />;
}

/**
 * التحميل في الخلفية بيبدأ بعد الافتتاحية على طول (مش أثناءها، عشان حركتها ما تتأثرش على الأجهزة الضعيفة).
 * لو المستخدم لسه في شاشة الدخول، الشاشات بتكون جاهزة على ما يكتب الإيميل وكلمة السر.
 */
function PreloadAfterSplash({ enabled }: { enabled: boolean }) {
  const { phase } = useStage();
  useEffect(() => {
    if (enabled && phase === 'done') preloadAll();
    // من غير تحميل في الخلفية (صفحة التتبع): مفيش حاجة نستناها
    if (!enabled) markBackgroundLoaded();
  }, [enabled, phase]);
  return null;
}

/** مدير التسويق: الفيديوهات والمظهر بس */
function MarketingRoutes() {
  return (
    <Routes>
      <Route element={<AppShell />}>
        <Route path="videos" element={<VideosScreen />} />
        <Route path="settings" element={<SettingsScreen />} />
        <Route path="*" element={<Navigate to="/videos" replace />} />
      </Route>
    </Routes>
  );
}

function AppRoutes({ role, admin }: { role: Role; admin: boolean }) {
  const owner = role === 'owner';
  const front = role === 'owner' || role === 'reception';
  const location = useLocation();
  // لو الجهاز اتفتح من كارت، الشاشة اللي ورا بتفضل ظاهرة والتفاصيل تطلع فوقها
  const bg = (location.state as { bg?: Location } | null)?.bg;
  return (
    <>
      <Routes location={bg ?? location}>
        {owner && <Route path="print/statement/:kind/:id" element={<StatementPrint />} />}
        {owner && <Route path="print/day/:day" element={<DayReportPrint />} />}
        {front && <Route path="print/barcode/:id" element={<BarcodePrint />} />}
        {front && <Route path="print/:kind/:id" element={<PrintScreen />} />}
        <Route element={<AppShell />}>
          <Route index element={<DashboardScreen />} />
          {front && <Route path="intake" element={<IntakeScreen />} />}
          <Route path="devices" element={<DevicesScreen />} />
          <Route path="devices/:id" element={<DeviceDetailScreen />} />
          {front && <Route path="customers" element={<CustomersScreen />} />}
          {front && <Route path="customers/:id" element={<CustomerProfileScreen />} />}
          {owner && <Route path="finance" element={<FinanceScreen />} />}
          {owner && <Route path="finance/pl" element={<ProfitScreen />} />}
          {owner && <Route path="finance/balances/:kind" element={<BalancesScreen />} />}
          {owner && <Route path="opening" element={<OpeningScreen />} />}
          {owner && <Route path="partners" element={<PartnersScreen />} />}
          {owner && <Route path="finance/entry/:id" element={<EntryScreen />} />}
          {owner && <Route path="finance/:kind/:id" element={<StatementScreen />} />}
          <Route path="inventory" element={<InventoryScreen />} />
          <Route path="work" element={<WorkScreen />} />
          {owner && <Route path="reports" element={<ReportsScreen />} />}
          {front && <Route path="drawer" element={<DrawerScreen />} />}
          {owner && <Route path="users" element={<TeamScreen />} />}
          {owner && <Route path="audit" element={<AuditScreen />} />}
          <Route path="settings" element={<SettingsScreen />} />
          {role !== 'reception' && <Route path="videos" element={<VideosScreen />} />}
          <Route path="community" element={<CommunityScreen />} />
          {admin && <Route path="admin" element={<AdminScreen />} />}
          <Route path="*" element={<Navigate to="/" replace />} />
        </Route>
      </Routes>
      <AnimatePresence>
        {bg && (
          <Routes location={location} key={location.pathname}>
            <Route path="/devices/:id" element={<DeviceDetailScreen overlay />} />
          </Routes>
        )}
      </AnimatePresence>
    </>
  );
}

function Boot() {
  const { calm } = usePrefs();
  const { loading } = useAuth();
  // الميزانية محسوبة من لحظة فتح البرنامج: على جهاز ضعيف نفس الحركة بتمشي أسرع (src/lib/splashTiming.ts)
  const [speed] = useState(() => initSplashSpeed(performance.now()));
  const ms = calm ? CALM_SPLASH_MS : SPLASH_MS * speed;
  const [minDone, setMinDone] = useState(false);
  const mounted = useRef(performance.now());
  useEffect(() => {
    const left = Math.max(0, ms - (performance.now() - mounted.current));
    const tm = setTimeout(() => {
      performance.mark('splash-min');
      setMinDone(true);
    }, left);
    return () => clearTimeout(tm);
  }, [ms]);
  const location = useLocation();
  // العميل اللي بيفتح صفحة التتبع ما يستناش الشاشة الافتتاحية
  const publicPage = location.pathname === '/t' || location.pathname.startsWith('/t/');
  const show = !publicPage && (!minDone || loading);
  useEffect(() => {
    if (!loading) performance.mark('auth-ready');
  }, [loading]);
  // بعد الافتتاحية: اللوجو بيطير لمكانه، وبعدين بيستقر هناك
  const [settled, setSettled] = useState(false);
  useEffect(() => {
    if (show || settled) return;
    const tm = setTimeout(() => setSettled(true), calm ? 0 : getHandoffMs() + 30);
    return () => clearTimeout(tm);
  }, [show, settled, calm]);
  const phase: SplashPhase = publicPage || settled ? 'done' : show ? 'splash' : calm ? 'done' : 'handoff';
  // صفحة التتبع العامة ما فيهاش افتتاحية، فاللوجو الثابت بتاع index.html بيتشال على طول
  useEffect(() => {
    if (publicPage) document.getElementById('boot')?.remove();
  }, [publicPage]);
  return (
    <StageProvider phase={phase}>
      {/* صفحة تتبع العميل: بتحمّل نفسها بس (العميل غالبًا على باقة موبايل) */}
      <PreloadAfterSplash enabled={!publicPage} />
      <EffectsGuard />
      <MotionDiagPanel />
      {(!loading || publicPage) && (
        // الشاشة اللي تحت بتظهر بنعومة لما الافتتاحية تخلص، والخلفية نفسها ما بتتغيرش
        <motion.div className="relative z-[1]" initial={false} animate={{ opacity: phase === 'splash' ? 0 : 1 }} transition={{ duration: 0.35 }} inert={phase === 'splash' ? true : undefined}>
          <Suspense fallback={null}>
            <Gate />
          </Suspense>
        </motion.div>
      )}
      <AnimatePresence>{show && <SplashScreen key="splash" />}</AnimatePresence>
    </StageProvider>
  );
}

export function App() {
  return (
    <PrefsProvider>
      <MotionConfig reducedMotion="user">
        <TooltipProvider>
          <ToastProvider>
            {isConfigured ? (
              <HashRouter>
                <AuthProvider>
                  <SyncProvider>
                    <Boot />
                  </SyncProvider>
                </AuthProvider>
              </HashRouter>
            ) : (
              <NotConfigured />
            )}
          </ToastProvider>
        </TooltipProvider>
      </MotionConfig>
    </PrefsProvider>
  );
}
