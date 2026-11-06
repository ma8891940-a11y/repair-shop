import { useEffect, useState } from 'react';
import { HashRouter, Navigate, Route, Routes, useLocation, type Location } from 'react-router';
import { AnimatePresence, MotionConfig } from 'motion/react';
import { useTranslation } from 'react-i18next';
import { AuthProvider, useAuth } from './app/auth';
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

// الافتتاحية بتتحسب من لحظة فتح الصفحة (مش من بعد تحميل الكود)، عشان البرنامج يبقى جاهز في أقل من ثانيتين
const SPLASH_MS = 1500;

function NotConfigured() {
  const { t } = useTranslation();
  return (
    <div className="grid min-h-dvh place-items-center px-4">
      <div className="glass-strong max-w-md rounded-xl p-6">
        <h1 className="text-lg font-semibold">{t('errors.notConfiguredTitle')}</h1>
        <p className="mt-2 text-sm text-fg-2">{t('errors.notConfigured')}</p>
      </div>
    </div>
  );
}

function Gate() {
  const { loading, session, profile, shop } = useAuth();
  const location = useLocation();
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
  if (!profile || profile.deleted_at || !shop) return <JoinScreen blocked={Boolean(profile?.deleted_at)} />;
  return <AppRoutes front={profile.role !== 'technician'} owner={profile.role === 'owner'} />;
}

function AppRoutes({ front, owner }: { front: boolean; owner: boolean }) {
  const location = useLocation();
  // لو الجهاز اتفتح من كارت، الشاشة اللي ورا بتفضل ظاهرة والتفاصيل تطلع فوقها
  const bg = (location.state as { bg?: Location } | null)?.bg;
  return (
    <>
      <Routes location={bg ?? location}>
        {front && <Route path="print/:kind/:id" element={<PrintScreen />} />}
        <Route element={<AppShell />}>
          <Route index element={<DashboardScreen />} />
          {front && <Route path="intake" element={<IntakeScreen />} />}
          <Route path="devices" element={<DevicesScreen />} />
          <Route path="devices/:id" element={<DeviceDetailScreen />} />
          {owner && <Route path="users" element={<TeamScreen />} />}
          {owner && <Route path="audit" element={<AuditScreen />} />}
          <Route path="settings" element={<SettingsScreen />} />
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
  const ms = calm ? 400 : SPLASH_MS;
  const [minDone, setMinDone] = useState(false);
  useEffect(() => {
    const left = Math.max(0, ms - performance.now());
    const tm = setTimeout(() => setMinDone(true), left);
    return () => clearTimeout(tm);
  }, [ms]);
  const show = !minDone || loading;
  return (
    <>
      <EffectsGuard />
      {!loading && <Gate />}
      <AnimatePresence>{show && <SplashScreen key="splash" duration={Math.max(300, ms - performance.now())} />}</AnimatePresence>
    </>
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
                  <Boot />
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
