import { useEffect, useRef, useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { AuthLayout } from './AuthLayout.jsx'
import { Button } from '../../components/Button.jsx'
import { Spinner } from '../../components/Spinner.jsx'
import { useAuthStore } from '../../store/authStore.js'
import { useUiStore } from '../../store/uiStore.js'
import { describeError } from '../../api/client.js'
import styles from './OtpPage.module.css'

const CODE_LENGTH = 6

export function OtpPage() {
  const navigate = useNavigate()
  const email = useAuthStore((s) => s.draftEmail)
  const verifyCode = useAuthStore((s) => s.verifyCode)
  const sendCode = useAuthStore((s) => s.sendCode)
  const showToast = useUiStore((s) => s.showToast)

  const [digits, setDigits] = useState(() => Array(CODE_LENGTH).fill(''))
  const [submitting, setSubmitting] = useState(false)
  const [error, setError] = useState(null)
  const [resending, setResending] = useState(false)
  const inputsRef = useRef([])
  const submittingRef = useRef(false)

  useEffect(() => {
    if (!email) navigate('/auth/login', { replace: true })
  }, [email, navigate])

  useEffect(() => {
    inputsRef.current[0]?.focus()
  }, [])

  function setDigit(idx, value) {
    const cleaned = value.replace(/\D/g, '')
    if (!cleaned) {
      setDigits((prev) => {
        const next = [...prev]
        next[idx] = ''
        return next
      })
      return
    }
    if (cleaned.length > 1) {
      paste(cleaned, idx)
      return
    }
    setDigits((prev) => {
      const next = [...prev]
      next[idx] = cleaned
      if (next.every((d) => d !== '')) submit(null, next.join(''))
      return next
    })
    if (idx < CODE_LENGTH - 1) inputsRef.current[idx + 1]?.focus()
  }

  function paste(text, startIdx = 0) {
    const cleaned = text.replace(/\D/g, '').slice(0, CODE_LENGTH - startIdx)
    if (!cleaned) return
    setDigits((prev) => {
      const next = [...prev]
      for (let i = 0; i < cleaned.length; i += 1) {
        next[startIdx + i] = cleaned[i]
      }
      if (next.every((d) => d !== '')) submit(null, next.join(''))
      return next
    })
    const lastIdx = Math.min(startIdx + cleaned.length, CODE_LENGTH - 1)
    inputsRef.current[lastIdx]?.focus()
  }

  function onKeyDown(idx, e) {
    if (e.key === 'Backspace' && !digits[idx] && idx > 0) {
      inputsRef.current[idx - 1]?.focus()
    } else if (e.key === 'ArrowLeft' && idx > 0) {
      inputsRef.current[idx - 1]?.focus()
    } else if (e.key === 'ArrowRight' && idx < CODE_LENGTH - 1) {
      inputsRef.current[idx + 1]?.focus()
    }
  }

  async function submit(e, codeOverride) {
    e?.preventDefault?.()
    if (submittingRef.current) return
    const code = codeOverride ?? digits.join('')
    if (code.length !== CODE_LENGTH) {
      setError('Введите все 6 цифр')
      return
    }
    submittingRef.current = true
    setError(null)
    setSubmitting(true)
    try {
      const isNewUser = await verifyCode(email, code)
      if (isNewUser) navigate('/auth/complete')
      else navigate('/', { replace: true })
    } catch (err) {
      const message = describeError(err)
      setError(message)
      showToast(message, { kind: 'error' })
    } finally {
      submittingRef.current = false
      setSubmitting(false)
    }
  }

  async function resend() {
    setResending(true)
    try {
      await sendCode(email)
      showToast('Код отправлен повторно', { kind: 'success' })
    } catch (err) {
      showToast(describeError(err), { kind: 'error' })
    } finally {
      setResending(false)
    }
  }

  return (
    <AuthLayout
      title="Введите код"
      subtitle={`Мы отправили 6-значный код на ${email || 'ваш email'}`}
    >
      <form onSubmit={submit} className={styles.form} noValidate>
        <div className={styles.row} onPaste={(e) => paste(e.clipboardData.getData('text'))}>
          {digits.map((d, i) => (
            <input
              key={i}
              ref={(el) => {
                inputsRef.current[i] = el
              }}
              className={`${styles.cell} ${error ? styles.cellError : ''}`}
              inputMode="numeric"
              autoComplete="one-time-code"
              maxLength={1}
              value={d}
              onChange={(e) => setDigit(i, e.target.value)}
              onKeyDown={(e) => onKeyDown(i, e)}
              aria-label={`Цифра ${i + 1}`}
            />
          ))}
        </div>
        {error ? <div className={styles.error}>{error}</div> : null}
        {submitting ? (
          <div className={styles.spinner}>
            <Spinner label="Проверка" />
          </div>
        ) : null}
        <div className={styles.actions}>
          <Button
            type="button"
            variant="ghost"
            size="sm"
            loading={resending}
            onClick={resend}
          >
            Отправить код повторно
          </Button>
          <Button
            type="button"
            variant="ghost"
            size="sm"
            onClick={() => navigate('/auth/login')}
          >
            Изменить email
          </Button>
        </div>
      </form>
    </AuthLayout>
  )
}
