import { useEffect, useRef, useState } from 'react'
import { SendHorizontal, Mic } from 'lucide-react'
import { useUiStore } from '../../store/uiStore.js'
import { describeError } from '../../api/client.js'
import { ComposerBanner } from './ComposerBanner.jsx'
import { ComposerRecording } from './ComposerRecording.jsx'
import { ComposerAttachMenu } from './ComposerAttachMenu.jsx'
import styles from './Composer.module.css'

const MAX_VOICE_SECONDS = 600

function pickRecorderMime() {
  if (typeof MediaRecorder === 'undefined') return null
  const candidates = [
    'audio/webm;codecs=opus',
    'audio/webm',
    'audio/ogg;codecs=opus',
    'audio/ogg',
    'audio/mp4',
  ]
  for (const m of candidates) {
    if (MediaRecorder.isTypeSupported?.(m)) return m
  }
  return ''
}

function extensionFor(mime) {
  if (!mime) return 'bin'
  if (mime.includes('webm')) return 'webm'
  if (mime.includes('ogg')) return 'ogg'
  if (mime.includes('mp4')) return 'm4a'
  return 'bin'
}

export function Composer({
  reply,
  onCancelReply,
  edit,
  onCancelEdit,
  onSendText,
  onSendMedia,
  onTyping,
  disabled,
}) {
  const fileInputRef = useRef(null)
  const imageInputRef = useRef(null)
  const videoInputRef = useRef(null)
  const textareaRef = useRef(null)
  const recorderRef = useRef(null)
  const chunksRef = useRef([])
  const streamRef = useRef(null)
  const recordStartRef = useRef(0)
  const recordTimerRef = useRef(null)

  const [text, setText] = useState('')
  const [attachOpen, setAttachOpen] = useState(false)
  const [recording, setRecording] = useState(false)
  const [recordDuration, setRecordDuration] = useState(0)
  const [sending, setSending] = useState(false)
  const showToast = useUiStore((s) => s.showToast)

  useEffect(() => {
    if (edit) {
      setText(edit.content ?? '')
      textareaRef.current?.focus()
    } else {
      setText('')
    }
  }, [edit])

  useEffect(() => {
    const ta = textareaRef.current
    if (!ta) return
    ta.style.height = 'auto'
    ta.style.height = `${Math.min(ta.scrollHeight, 180)}px`
  }, [text])

  useEffect(() => {
    function close(e) {
      if (!e.target.closest('[data-attach-menu]')) setAttachOpen(false)
    }
    if (attachOpen) document.addEventListener('mousedown', close)
    return () => document.removeEventListener('mousedown', close)
  }, [attachOpen])

  useEffect(() => {
    return () => stopMediaStream()
  }, [])

  function stopMediaStream() {
    streamRef.current?.getTracks?.().forEach((t) => t.stop())
    streamRef.current = null
    if (recordTimerRef.current) {
      clearInterval(recordTimerRef.current)
      recordTimerRef.current = null
    }
  }

  async function submit(e) {
    e?.preventDefault?.()
    const value = text.trim()
    if (!value) return
    setSending(true)
    try {
      if (edit) {
        await onSendText({ mode: 'edit', content: value })
      } else {
        await onSendText({ mode: 'send', content: value, replyToId: reply?.id })
      }
      setText('')
      onTyping?.(false)
    } catch (err) {
      showToast(describeError(err), { kind: 'error' })
    } finally {
      setSending(false)
    }
  }

  function onKeyDown(e) {
    if (e.key === 'Enter' && !e.shiftKey) {
      e.preventDefault()
      submit()
    }
  }

  function onChange(e) {
    const v = e.target.value
    setText(v)
    onTyping?.(v.trim().length > 0)
  }

  async function handleFile(type, files) {
    const file = files?.[0]
    if (!file) return
    try {
      await onSendMedia({ type, file, replyToId: reply?.id })
    } catch (err) {
      showToast(describeError(err), { kind: 'error' })
    }
  }

  async function startRecording() {
    if (typeof MediaRecorder === 'undefined') {
      showToast('Запись недоступна в этом браузере', { kind: 'error' })
      return
    }
    try {
      const stream = await navigator.mediaDevices.getUserMedia({ audio: true })
      streamRef.current = stream
      const mime = pickRecorderMime()
      const recorder = new MediaRecorder(stream, mime ? { mimeType: mime } : undefined)
      chunksRef.current = []
      recorder.addEventListener('dataavailable', (ev) => {
        if (ev.data?.size > 0) chunksRef.current.push(ev.data)
      })
      recorderRef.current = recorder
      recordStartRef.current = Date.now()
      setRecordDuration(0)
      recordTimerRef.current = setInterval(() => {
        const elapsed = Math.floor((Date.now() - recordStartRef.current) / 1000)
        setRecordDuration(elapsed)
        if (elapsed >= MAX_VOICE_SECONDS) {
          finishRecording().catch((err) => {
            showToast(describeError(err), { kind: 'error' })
          })
        }
      }, 250)
      recorder.start(250)
      setRecording(true)
    } catch (err) {
      stopMediaStream()
      showToast(describeError(err) || 'Нужен доступ к микрофону', {
        kind: 'error',
      })
    }
  }

  async function finishRecording() {
    const recorder = recorderRef.current
    if (!recorder) return
    if (recorder.state === 'inactive') return
    const done = new Promise((resolve) => {
      recorder.addEventListener('stop', resolve, { once: true })
    })
    recorder.stop()
    await done

    const duration = Math.max(
      1,
      Math.round((Date.now() - recordStartRef.current) / 1000),
    )
    stopMediaStream()
    setRecording(false)
    recorderRef.current = null

    const mime = recorder.mimeType || pickRecorderMime() || 'audio/webm'
    const ext = extensionFor(mime)
    const blob = new Blob(chunksRef.current, { type: mime })
    if (blob.size < 256) {
      showToast('Запись слишком короткая', { kind: 'error' })
      return
    }
    const file = new File([blob], `voice.${ext}`, { type: mime })
    try {
      await onSendMedia({
        type: 'voice',
        file,
        durationSec: duration,
        replyToId: reply?.id,
        filename: file.name,
      })
    } catch (err) {
      showToast(describeError(err), { kind: 'error' })
    }
  }

  function cancelRecording() {
    const recorder = recorderRef.current
    if (recorder && recorder.state !== 'inactive') {
      try {
        recorder.stop()
      } catch {
        /* ignore */
      }
    }
    chunksRef.current = []
    stopMediaStream()
    recorderRef.current = null
    setRecording(false)
    setRecordDuration(0)
  }

  const hasText = text.trim().length > 0
  const showSend = hasText || edit

  return (
    <div className={styles.wrap}>
      {edit ? (
        <ComposerBanner mode="edit" target={edit} onCancel={onCancelEdit} />
      ) : reply ? (
        <ComposerBanner mode="reply" target={reply} onCancel={onCancelReply} />
      ) : null}

      <form className={styles.composer} onSubmit={submit}>
        {recording ? (
          <ComposerRecording
            duration={recordDuration}
            onCancel={cancelRecording}
            onFinish={finishRecording}
          />
        ) : (
          <>
            <ComposerAttachMenu
              open={attachOpen}
              disabled={disabled}
              onToggle={() => setAttachOpen((v) => !v)}
              onPickImage={() => {
                setAttachOpen(false)
                imageInputRef.current?.click()
              }}
              onPickVideo={() => {
                setAttachOpen(false)
                videoInputRef.current?.click()
              }}
              onPickFile={() => {
                setAttachOpen(false)
                fileInputRef.current?.click()
              }}
              onStartRecording={() => {
                setAttachOpen(false)
                startRecording()
              }}
            />

            <textarea
              ref={textareaRef}
              className={styles.textarea}
              value={text}
              onChange={onChange}
              onKeyDown={onKeyDown}
              placeholder={edit ? 'Изменить сообщение' : 'Сообщение'}
              rows={1}
              disabled={disabled || sending}
              aria-label="Сообщение"
            />

            {showSend ? (
              <button
                type="submit"
                className={styles.sendBtn}
                aria-label={edit ? 'Сохранить' : 'Отправить'}
                disabled={!hasText || sending}
              >
                <SendHorizontal size={22} />
              </button>
            ) : (
              <button
                type="button"
                className={styles.micBtn}
                aria-label="Записать голосовое"
                onClick={startRecording}
                disabled={disabled}
              >
                <Mic size={22} />
              </button>
            )}
          </>
        )}

        <input
          ref={imageInputRef}
          type="file"
          accept="image/*"
          className={styles.hiddenInput}
          onChange={(e) => handleFile('image', e.target.files)}
        />
        <input
          ref={videoInputRef}
          type="file"
          accept="video/*"
          className={styles.hiddenInput}
          onChange={(e) => handleFile('video', e.target.files)}
        />
        <input
          ref={fileInputRef}
          type="file"
          className={styles.hiddenInput}
          onChange={(e) => handleFile('file', e.target.files)}
        />
      </form>
    </div>
  )
}
