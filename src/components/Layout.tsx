import { useEffect } from 'react';
import { NavLink, Outlet, useNavigate } from 'react-router';
import { useAuth, useMe } from '../auth/AuthContext';
import { ROLE_LABELS } from '../lib/types';

export function Layout() {
  const { profile, shop } = useMe();
  const { signOut } = useAuth();
  const navigate = useNavigate();
  const isOwner = profile.role === 'owner';
  const canReceive = profile.role !== 'technician';

  // اختصارات لوحة المفاتيح
  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      if (e.key === 'F2' && canReceive) {
        e.preventDefault();
        navigate('/devices/new');
      } else if (e.key === 'F3') {
        e.preventDefault();
        navigate('/devices?focus=1');
      } else if (e.key === 'F1') {
        e.preventDefault();
        navigate('/');
      }
    };
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  }, [navigate, canReceive]);

  return (
    <div className="app">
      <aside className="sidebar">
        <div className="brand">{shop.name}</div>
        <nav>
          <NavLink to="/" end>
            لوحة التحكم <kbd>F1</kbd>
          </NavLink>
          <NavLink to="/devices" end>
            الأجهزة <kbd>F3</kbd>
          </NavLink>
          {canReceive && (
            <NavLink to="/devices/new">
              استلام جهاز <kbd>F2</kbd>
            </NavLink>
          )}
          {isOwner && (
            <>
              <div className="nav-sep" />
              <NavLink to="/users">المستخدمين</NavLink>
              <NavLink to="/audit">سجل النشاط</NavLink>
              <NavLink to="/settings">الإعدادات</NavLink>
            </>
          )}
        </nav>
        <div className="me">
          <div>{profile.full_name}</div>
          <small>{ROLE_LABELS[profile.role]}</small>
          <button className="link" onClick={() => void signOut()}>
            خروج
          </button>
        </div>
      </aside>
      <main className="content">
        <Outlet />
      </main>
    </div>
  );
}
