import { Component } from 'react'
import { Button } from './Button.jsx'

export class ErrorBoundary extends Component {
  constructor(props) {
    super(props)
    this.state = { error: null }
  }

  static getDerivedStateFromError(error) {
    return { error }
  }

  componentDidCatch(error, info) {
    console.error('Uncaught render error:', error, info)
  }

  render() {
    const { error } = this.state
    if (error) {
      return (
        <div
          role="alert"
          style={{
            minHeight: '100dvh',
            display: 'flex',
            flexDirection: 'column',
            alignItems: 'center',
            justifyContent: 'center',
            padding: 24,
            textAlign: 'center',
            gap: 16,
            background: 'var(--bg)',
            color: 'var(--text)',
          }}
        >
          <h1 style={{ margin: 0, fontSize: 20, fontWeight: 600 }}>
            Что-то пошло не так
          </h1>
          <p style={{ margin: 0, color: 'var(--text-muted)', maxWidth: 420 }}>
            Произошла непредвиденная ошибка. Попробуйте перезагрузить страницу.
          </p>
          <Button
            variant="primary"
            onClick={() => window.location.reload()}
          >
            Перезагрузить
          </Button>
        </div>
      )
    }
    return this.props.children
  }
}
