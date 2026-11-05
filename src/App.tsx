import { lazy, Suspense } from 'react';
import { HashRouter, Navigate, Route, Routes } from 'react-router';
import { MotionConfig } from 'motion/react';
import { AuthProvider, useAuth } from './app/auth';
import { ThemeProvider } from './app/theme';
import { AppShell } from './app/AppShell';
import { isConfigured } from './lib/supabase';
import { TooltipProvider } from './ui/Tooltip';
import { Mark } from './ui/Logo';
import { LoginScreen } from './screens/LoginScreen';
import { OnboardingScreen } from './screens/OnboardingScreen';
import { DashboardScreen } from './screens/DashboardScreen';
import { IntakeScreen } from './screens/IntakeScreen';
import { PendingScreen } from './screens/PendingScreen';

const DesignSystemScreen = import.meta.env.DEV ? lazy(() => import('./screens/DesignSystemScreen')) : null;

function Splash() {
  return (
    <div className="grid min-h-dvh place-items-center bg-bg">
      <div className="animate-shimmer">
        <Mark size={40} />
      </div>
    </div>
  );
}

function NotConfigured() {
  return (
    <div className="bg-grid grid min-h-dvh place-items-center bg-bg px-4">
      <div className="max-w-md rounded-xl border border-line bg-surface p-6 shadow-2">
        <h1 className="text-lg font-semibold">البرنامج محتاج إعداد</h1>
        <p className="mt-2 text-sm text-fg-2">
          ملف <code className="num">.env.local</code> مش موجود أو ناقص. انسخ <code className="num">.env.example</code> باسم{' '}
          <code className="num">.env.local</code> واكتب فيه رابط مشروع Supabase والـ anon key، وشغّل البرنامج تاني.
        </p>
      </div>
    </div>
  );
}

function Gate() {
  const { loading, session, profile, shop, error } = useAuth();
  if (loading) return <Splash />;
  if (!session) {
    return (
      <Routes>
        {DesignSystemScreen && <Route path="/design" element={<Suspense fallback={<Splash />}><DesignSystemScreen /></Suspense>} />}
        <Route path="*" element={<LoginScreen />} />
      </Routes>
    );
  }
  if (!profile || profile.deleted_at || !shop) return <OnboardingScreen blocked={Boolean(profile?.deleted_at)} loadError={error} />;
  const front = profile.role !== 'technician';
  return (
    <Routes>
      {DesignSystemScreen && <Route path="/design" element={<Suspense fallback={<Splash />}><DesignSystemScreen /></Suspense>} />}
      <Route element={<AppShell />}>
        <Route index element={<DashboardScreen />} />
        {front && <Route path="intake" element={<IntakeScreen />} />}
        <Route path="devices" element={<PendingScreen title="الأجهزة" />} />
        <Route path="devices/:id" element={<PendingScreen title="تفاصيل الجهاز" />} />
        <Route path="users" element={<PendingScreen title="الفريق" />} />
        <Route path="audit" element={<PendingScreen title="سجل النشاط" />} />
        <Route path="settings" element={<PendingScreen title="الإعدادات" />} />
        <Route path="*" element={<Navigate to="/" replace />} />
      </Route>
    </Routes>
  );
}

export function App() {
  return (
    <ThemeProvider>
      <MotionConfig reducedMotion="user">
        <TooltipProvider>
          {isConfigured ? (
            <HashRouter>
              <AuthProvider>
                <Gate />
              </AuthProvider>
            </HashRouter>
          ) : (
            <NotConfigured />
          )}
        </TooltipProvider>
      </MotionConfig>
    </ThemeProvider>
  );
}
