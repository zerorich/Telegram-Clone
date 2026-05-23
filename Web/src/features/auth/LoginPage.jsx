import { useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { AuthLayout } from './AuthLayout.jsx'
import { Input } from '../../components/Input.jsx'
import { Button } from '../../components/Button.jsx'
import { useAuthStore } from '../../store/authStore.js'
import { useUiStore } from '../../store/uiStore.js'
import { describeError } from '../../api/client.js'

const EMAIL_RE = /^[^\s@]+@[^\s@]+\.[^\s@]+$/

export function LoginPage() {
  const navigate = useNavigate()
  const sendCode = useAuthStore((s) => s.sendCode)
  const showToast = useUiStore((s) => s.showToast)

  const [email, setEmail] = useState('')
  const [error, setError] = useState(null)
  const [loading, setLoading] = useState(false)

  async function submit(e) {
    e.preventDefault()
    setError(null)
    const trimmed = email.trim()
    if (!EMAIL_RE.test(trimmed)) {
      setError('Введите корректный email')
      return
    }
    setLoading(true)
    try {
      await sendCode(trimmed)
      navigate('/auth/otp')
    } catch (err) {
      const message = describeError(err)
      setError(message)
      showToast(message, { kind: 'error' })
    } finally {
      setLoading(false)
    }
  }

  return (
    <AuthLayout
      title="Telegram"
      subtitle="Введите email — мы пришлём код подтверждения"
    >
      <form onSubmit={submit} noValidate>
        <Input
          label="Email"
          type="email"
          autoComplete="email"
          placeholder="you@example.com"
          value={email}
          onChange={(e) => setEmail(e.target.value)}
          error={error}
          autoFocus
          inputMode="email"
        />
        <div style={{ height: 18 }} />
        <Button type="submit" size="lg" loading={loading} style={{ width: '100%' }}>
          Продолжить
        </Button>
      </form>
    </AuthLayout>
  )
}
