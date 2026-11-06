import { useEffect, useRef, useState } from 'react';
import { HashRouter, Navigate, Route, Routes, useLocation, type Location } from 'react-router';
import { AnimatePresence, MotionConfig, motion } from 'motion/react';
import { useTranslation } from 'react-i18next';
import { AuthProvider, useAuth } from './app/auth';
import { SyncProvider } from './offline/sync';
import { PrefsProvider, usePrefs } from './app/prefs';
import { AppShell } from './app/AppShell';
import { EffectsGuard } from './app/EffectsGuard';
import { isConfigured } from './lib/supabase';
import { TooltipProvider } from './ui/Tooltip';
import { ToastProvider } from './ui/Toast';
import { SplashScreen } from './screens/SplashScreen';
import { LoginScreen } from './screens/auth/LoginScreen';
import { RegisterWizard, draftMode, hasRegisterDraft } from './screens/auth/RegisterWizard';
import { JoinScreen } from './screens/auth/JoinScreen';
import { DashboardScreen } from './screens/DashboardScreen';
import { IntakeScreen } from './screens/IntakeScreen';
import { DeviceDetailScreen } from './screens/DeviceDetailScreen';
import { DevicesScreen } from './screens/DevicesScreen';
import { TeamScreen } from './screens/TeamScreen';
import { AuditScreen } from './screens/AuditScreen';
import { SettingsScreen } from './screens/SettingsScreen';
import { PrintScreen } from './screens/PrintScreen';
import { TrackingScreen } from './screens/TrackingScreen';
import { CustomersScreen, CustomerProfileScreen } from './screens/CustomersScreen';
import { FinanceScreen } from './screens/finance/FinanceScreen';
import { StatementScreen } from './screens/finance/StatementScreen';
import { BalancesScreen, ProfitScreen } from './screens/finance/BalancesScreen';
import { InventoryScreen } from './screens/finance/InventoryScreen';
import { DrawerScreen } from './screens/finance/DrawerScreen';
import { WorkScreen } from './screens/WorkScreen';
import { ReportsScreen } from './screens/ReportsScreen';
import { DayReportPrint, StatementPrint } from './screens/finance/FinancePrint';
import { VideosScreen } from './screens/VideosScreen';
import { CommunityScreen } from './screens/CommunityScreen';
import { AdminScreen } from './screens/AdminScreen';
import { Button } from './ui/Button';
import { HANDOFF_S, StageProvider, type SplashPhase } from './app/stage';
import type { Role } from './lib/status';

// الافتتاحية: ظهور اللوجو والتجمّع والسكان في 0.85 ثانية، وبعدها اللوجو بيطير لمكانه (0.45 ثانية). المجموع أقل من ثانية ونص
const SPLASH_MS = 850;
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
    (session && !profile && hasRegisterDraft()) ||
    (session && profile?.role === 'owner' && shop && !shop.setup_completed_at);
  if (wizard) return <RegisterWizard mode={joinPath ? 'invite' : session ? draftMode() : 'shop'} />;

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
  const ms = calm ? CALM_SPLASH_MS : SPLASH_MS;
  const [minDone, setMinDone] = useState(false);
  const mounted = useRef(performance.now());
  useEffect(() => {
    const left = Math.max(0, ms - (performance.now() - mounted.current));
    const tm = setTimeout(() => setMinDone(true), left);
    return () => clearTimeout(tm);
  }, [ms]);
  const location = useLocation();
  // العميل اللي بيفتح صفحة التتبع ما يستناش الشاشة الافتتاحية
  const publicPage = location.pathname === '/t' || location.pathname.startsWith('/t/');
  const show = !publicPage && (!minDone || loading);
  // بعد الافتتاحية: اللوجو بيطير لمكانه، وبعدين بيستقر هناك
  const [settled, setSettled] = useState(false);
  useEffect(() => {
    if (show || settled) return;
    const tm = setTimeout(() => setSettled(true), calm ? 0 : HANDOFF_S * 1000 + 30);
    return () => clearTimeout(tm);
  }, [show, settled, calm]);
  const phase: SplashPhase = publicPage || settled ? 'done' : show ? 'splash' : calm ? 'done' : 'handoff';
  // صفحة التتبع العامة ما فيهاش افتتاحية، فاللوجو الثابت بتاع index.html بيتشال على طول
  useEffect(() => {
    if (publicPage) document.getElementById('boot')?.remove();
  }, [publicPage]);
  return (
    <StageProvider phase={phase}>
      <EffectsGuard />
      {(!loading || publicPage) && (
        // الشاشة اللي تحت بتظهر بنعومة لما الافتتاحية تخلص، والخلفية نفسها ما بتتغيرش
        <motion.div className="relative z-[1]" initial={false} animate={{ opacity: phase === 'splash' ? 0 : 1 }} transition={{ duration: 0.35 }} inert={phase === 'splash' ? true : undefined}>
          <Gate />
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
