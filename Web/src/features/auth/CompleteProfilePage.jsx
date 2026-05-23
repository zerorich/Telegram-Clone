import { useEffect, useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { AuthLayout } from './AuthLayout.jsx'
import { Input } from '../../components/Input.jsx'
import { Button } from '../../components/Button.jsx'
import { useAuthStore } from '../../store/authStore.js'
import { useUiStore } from '../../store/uiStore.js'
import { describeError } from '../../api/client.js'

export function CompleteProfilePage() {
  const navigate = useNavigate()
  const email = useAuthStore((s) => s.draftEmail)
  const completeProfile = useAuthStore((s) => s.completeProfile)
  const showToast = useUiStore((s) => s.showToast)

  const [name, setName] = useState('')
  const [surname, setSurname] = useState('')
  const [phone, setPhone] = useState('')
  const [error, setError] = useState(null)
  const [loading, setLoading] = useState(false)

  useEffect(() => {
    if (!email) navigate('/auth/login', { replace: true })
  }, [email, navigate])

  async function submit(e) {
    e.preventDefault()
    const trimmedName = name.trim()
    if (!trimmedName) {
      setError('Введите имя')
      return
    }
    setError(null)
    setLoading(true)
    try {
      await completeProfile({
        email,
        name: trimmedName,
        surname: surname.trim() || undefined,
        phone: phone.trim() || undefined,
      })
      navigate('/', { replace: true })
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
      title="Расскажите о себе"
      subtitle="Заполните профиль, чтобы начать общение"
    >
      <form
        onSubmit={submit}
        style={{ display: 'flex', flexDirection: 'column', gap: 14 }}
        noValidate
      >
        <Input
          label="Имя"
          autoComplete="given-name"
          autoFocus
          value={name}
          onChange={(e) => setName(e.target.value)}
          error={error}
          placeholder="Иван"
        />
        <Input
          label="Фамилия"
          autoComplete="family-name"
          value={surname}
          onChange={(e) => setSurname(e.target.value)}
          placeholder="Иванов"
        />
        <Input
          label="Телефон (необязательно)"
          type="tel"
          inputMode="tel"
          autoComplete="tel"
          value={phone}
          onChange={(e) => setPhone(e.target.value)}
          placeholder="+7 999 123-45-67"
        />
        <Button
          type="submit"
          size="lg"
          loading={loading}
          style={{ width: '100%' }}
        >
          Начать общение
        </Button>
      </form>
    </AuthLayout>
  )
}
