import { useEffect } from 'react'
import {
  BrowserRouter,
  Navigate,
  Outlet,
  Route,
  Routes,
  useLocation,
} from 'react-router-dom'
import { useAuthStore } from './store/authStore.js'
import { installWsBridge } from './ws/bridge.js'
import { LoginPage } from './features/auth/LoginPage.jsx'
import { OtpPage } from './features/auth/OtpPage.jsx'
import { CompleteProfilePage } from './features/auth/CompleteProfilePage.jsx'
import { AppLayout } from './routes/AppLayout.jsx'
import { NewChatModal } from './features/chats/NewChatModal.jsx'
import { NewGroupModal } from './features/chats/NewGroupModal.jsx'
import { ProfileModal } from './features/profile/ProfileModal.jsx'
import { SettingsModal } from './features/profile/SettingsModal.jsx'
import { UserProfileModal } from './features/profile/UserProfileModal.jsx'
import { GroupInfoModal } from './features/profile/GroupInfoModal.jsx'
import { Toast } from './components/Toast.jsx'
import { Spinner } from './components/Spinner.jsx'

function BootGate({ children }) {
  const bootstrapped = useAuthStore((s) => s.bootstrapped)
  const bootstrap = useAuthStore((s) => s.bootstrap)

  useEffect(() => {
    bootstrap()
  }, [bootstrap])

  if (!bootstrapped) {
    return (
      <div
        style={{
          flex: 1,
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
          minHeight: '100dvh',
        }}
      >
        <Spinner size={32} label="Загрузка" />
      </div>
    )
  }
  return children
}

function ProtectedShell() {
  const status = useAuthStore((s) => s.status)
  const location = useLocation()
  if (status !== 'authenticated') {
    return <Navigate to="/auth/login" replace state={{ from: location }} />
  }
  return <Outlet />
}

function PublicRoute({ children }) {
  const status = useAuthStore((s) => s.status)
  if (status === 'authenticated') {
    return <Navigate to="/" replace />
  }
  return children
}

/**
 * Background-location pattern: when a navigation passes
 * `state: { backgroundLocation }`, the AppLayout is rendered against the
 * background URL and the foreground route is overlaid as a modal.
 *
 * When a modal route is opened directly (no backgroundLocation), we still
 * render the modal but fall AppLayout back to "/" so the shell stays visible.
 */
const MODAL_PATTERNS = [
  /^\/new-chat$/,
  /^\/new-group$/,
  /^\/profile$/,
  /^\/settings$/,
  /^\/user\/[^/]+$/,
  /^\/group\/[^/]+$/,
]

function isModalPath(pathname) {
  return MODAL_PATTERNS.some((re) => re.test(pathname))
}

function RoutedApp() {
  const location = useLocation()
  const state = location.state
  const explicitBackground = state?.backgroundLocation
  const isModal = isModalPath(location.pathname)
  const status = useAuthStore((s) => s.status)
  const baseLocation =
    explicitBackground || (isModal ? { pathname: '/' } : location)

  return (
    <>
      <Routes location={baseLocation}>
        <Route
          path="/auth/login"
          element={
            <PublicRoute>
              <LoginPage />
            </PublicRoute>
          }
        />
        <Route
          path="/auth/otp"
          element={
            <PublicRoute>
              <OtpPage />
            </PublicRoute>
          }
        />
        <Route
          path="/auth/complete"
          element={
            <PublicRoute>
              <CompleteProfilePage />
            </PublicRoute>
          }
        />
        <Route element={<ProtectedShell />}>
          <Route path="/" element={<AppLayout />} />
          <Route path="/chats/:chatId" element={<AppLayout />} />
        </Route>
        <Route path="*" element={<Navigate to="/" replace />} />
      </Routes>

      {isModal && status === 'authenticated' ? (
        <Routes>
          <Route path="/new-chat" element={<NewChatModal />} />
          <Route path="/new-group" element={<NewGroupModal />} />
          <Route path="/profile" element={<ProfileModal />} />
          <Route path="/settings" element={<SettingsModal />} />
          <Route path="/user/:userId" element={<UserProfileModal />} />
          <Route path="/group/:chatId" element={<GroupInfoModal />} />
        </Routes>
      ) : null}
    </>
  )
}

export default function App() {
  useEffect(() => {
    installWsBridge()
  }, [])

  return (
    <BrowserRouter>
      <BootGate>
        <RoutedApp />
        <Toast />
      </BootGate>
    </BrowserRouter>
  )
}
