import { HashRouter, Navigate, Route, Routes } from 'react-router';
import { AuthProvider, useAuth } from './auth/AuthContext';
import { isConfigured } from './lib/supabase';
import { Layout } from './components/Layout';
import { LoginPage } from './pages/LoginPage';
import { OnboardingPage } from './pages/OnboardingPage';
import { DashboardPage } from './pages/DashboardPage';
import { DevicesPage } from './pages/DevicesPage';
import { NewDevicePage } from './pages/NewDevicePage';
import { DeviceDetailPage } from './pages/DeviceDetailPage';
import { SettingsPage } from './pages/SettingsPage';
import { UsersPage } from './pages/UsersPage';
import { AuditPage } from './pages/AuditPage';
import { PrintPage } from './pages/PrintPage';

function NotConfigured() {
  return (
    <div className="center-screen">
      <div className="card narrow">
        <h1>البرنامج محتاج إعداد</h1>
        <p>
          ملف <code>.env.local</code> مش موجود أو ناقص. اعمل نسخة من <code>.env.example</code> باسم{' '}
          <code>.env.local</code>، واكتب فيها رابط مشروع Supabase والـ anon key، وبعدين شغّل البرنامج تاني.
        </p>
      </div>
    </div>
  );
}

function Gate() {
  const { loading, session, profile, shop, error } = useAuth();
  if (loading) return <div className="center-screen">جاري التحميل...</div>;
  if (!session) {
    return (
      <Routes>
        <Route path="*" element={<LoginPage />} />
      </Routes>
    );
  }
  if (!profile || profile.deleted_at || !shop) {
    return <OnboardingPage blocked={Boolean(profile?.deleted_at)} loadError={error} />;
  }
  const owner = profile.role === 'owner';
  const front = profile.role !== 'technician';
  return (
    <Routes>
      <Route path="/print/:kind/:id" element={<PrintPage />} />
      <Route element={<Layout />}>
        <Route index element={<DashboardPage />} />
        <Route path="devices" element={<DevicesPage />} />
        {front && <Route path="devices/new" element={<NewDevicePage />} />}
        <Route path="devices/:id" element={<DeviceDetailPage />} />
        {owner && <Route path="settings" element={<SettingsPage />} />}
        {owner && <Route path="users" element={<UsersPage />} />}
        {owner && <Route path="audit" element={<AuditPage />} />}
        <Route path="*" element={<Navigate to="/" replace />} />
      </Route>
    </Routes>
  );
}

export function App() {
  if (!isConfigured) return <NotConfigured />;
  return (
    <HashRouter>
      <AuthProvider>
        <Gate />
      </AuthProvider>
    </HashRouter>
  );
}
