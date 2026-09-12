import { wsClient } from '../ws/client.js'
import { useCallStore } from '../store/callStore.js'
import { useAuthStore } from '../store/authStore.js'
import { useUiStore } from '../store/uiStore.js'
import { describeError } from '../api/client.js'

const ICE_SERVERS = [{ urls: 'stun:stun.l.google.com:19302' }]

let pc = null
let pendingOffer = null

function meId() {
  return useAuthStore.getState().user?.id
}

function patch(partial) {
  useCallStore.getState().patch(partial)
}

function showError(message) {
  useUiStore.getState().showToast(message, { kind: 'error' })
}

function newCallId() {
  if (crypto?.randomUUID) return crypto.randomUUID()
  return `call-${Date.now()}-${Math.random().toString(36).slice(2)}`
}

function cleanupTracks(stream) {
  stream?.getTracks?.().forEach((t) => t.stop())
}

function resetPeer() {
  if (pc) {
    try {
      pc.ontrack = null
      pc.onicecandidate = null
      pc.onconnectionstatechange = null
      pc.close()
    } catch {
      /* ignore */
    }
  }
  pc = null
  pendingOffer = null
}

function send(type, payload) {
  if (!wsClient.send(type, payload)) {
    showError('Нет соединения с сервером')
    return false
  }
  return true
}

async function getUserMedia(media) {
  const video = media === 'video'
  return navigator.mediaDevices.getUserMedia({
    audio: true,
    video: video ? { facingMode: 'user' } : false,
  })
}

function attachLocalStream(stream) {
  stream.getTracks().forEach((track) => {
    pc.addTrack(track, stream)
  })
  patch({ localStream: stream })
}

function wirePeerConnection(callId, peerUserId) {
  pc.onicecandidate = (ev) => {
    if (!ev.candidate) return
    send('call.ice', {
      callId,
      fromUserId: meId(),
      toUserId: peerUserId,
      candidate: ev.candidate.toJSON(),
    })
  }

  pc.ontrack = (ev) => {
    const [remote] = ev.streams
    if (remote) patch({ remoteStream: remote })
  }

  pc.onconnectionstatechange = () => {
    const state = pc?.connectionState
    if (state === 'connected') {
      patch({ status: 'active', startedAt: Date.now() })
    } else if (state === 'failed') {
      showError('Соединение прервано')
      callManager.endCall('failed')
    } else if (state === 'disconnected') {
      callManager.endCall('disconnected')
    }
  }
}

function endLocal(reason = 'hangup') {
  const state = useCallStore.getState()
  const { callId, peerUserId, localStream } = state
  if (callId && peerUserId) {
    send('call.end', {
      callId,
      fromUserId: meId(),
      toUserId: peerUserId,
      reason,
    })
  }
  cleanupTracks(localStream)
  cleanupTracks(state.remoteStream)
  resetPeer()
  useCallStore.getState().reset()
}

export const callManager = {
  get isBusy() {
    const { status } = useCallStore.getState()
    return status !== 'idle' && status !== 'ending'
  },

  async startCall(toUserId, peerName, media = 'audio') {
    if (!toUserId) {
      showError('Невозможно начать звонок')
      return
    }
    if (this.isBusy) {
      showError('Уже идёт другой звонок')
      return
    }
    if (!window.RTCPeerConnection) {
      showError('Звонки не поддерживаются в этом браузере')
      return
    }

    const callId = newCallId()
    patch({
      status: 'outgoing',
      callId,
      peerUserId: toUserId,
      peerName: peerName || 'Собеседник',
      media,
      videoEnabled: media === 'video',
      error: null,
    })

    try {
      const stream = await getUserMedia(media)
      pc = new RTCPeerConnection({ iceServers: ICE_SERVERS })
      wirePeerConnection(callId, toUserId)
      attachLocalStream(stream)

      const offer = await pc.createOffer()
      await pc.setLocalDescription(offer)

      if (
        !send('call.offer', {
          callId,
          fromUserId: meId(),
          toUserId,
          sdp: pc.localDescription,
          media,
        })
      ) {
        endLocal('error')
      }
    } catch (err) {
      showError(describeError(err) || 'Нужен доступ к микрофону')
      endLocal('error')
    }
  },

  handleOffer(data) {
    const fromUserId = data.fromUserId ?? data.from_user_id
    const callId = data.callId ?? data.call_id
    const media = data.media ?? 'audio'
    const sdp = data.sdp

    if (!fromUserId || !callId || !sdp) return

    if (this.isBusy) {
      send('call.end', {
        callId,
        fromUserId: meId(),
        toUserId: fromUserId,
        reason: 'busy',
      })
      return
    }

    pendingOffer = { ...data, fromUserId, callId, media, sdp }
    patch({
      status: 'incoming',
      callId,
      peerUserId: fromUserId,
      peerName: data.peerName || data.peer_name || 'Входящий звонок',
      media,
      videoEnabled: media === 'video',
    })
  },

  async acceptCall() {
    const state = useCallStore.getState()
    const offer = pendingOffer ?? {}
    const { callId, peerUserId, media, sdp } = {
      callId: state.callId,
      peerUserId: state.peerUserId,
      media: state.media,
      sdp: offer.sdp,
    }

    if (!callId || !peerUserId || !sdp) {
      showError('Некорректное приглашение на звонок')
      this.rejectCall()
      return
    }

    try {
      const stream = await getUserMedia(media)
      pc = new RTCPeerConnection({ iceServers: ICE_SERVERS })
      wirePeerConnection(callId, peerUserId)
      attachLocalStream(stream)

      await pc.setRemoteDescription(new RTCSessionDescription(sdp))
      const answer = await pc.createAnswer()
      await pc.setLocalDescription(answer)

      patch({ status: 'active', startedAt: Date.now() })

      if (
        !send('call.answer', {
          callId,
          fromUserId: meId(),
          toUserId: peerUserId,
          sdp: pc.localDescription,
        })
      ) {
        endLocal('error')
      }
    } catch (err) {
      showError(describeError(err) || 'Не удалось принять звонок')
      endLocal('error')
    }
  },

  rejectCall() {
    const { callId, peerUserId } = useCallStore.getState()
    if (callId && peerUserId) {
      send('call.end', {
        callId,
        fromUserId: meId(),
        toUserId: peerUserId,
        reason: 'declined',
      })
    }
    endLocal('declined')
  },

  handleAnswer(data) {
    const callId = data.callId ?? data.call_id
    const sdp = data.sdp
    const state = useCallStore.getState()
    if (!pc || state.callId !== callId || !sdp) return

    pc.setRemoteDescription(new RTCSessionDescription(sdp)).catch((err) => {
      showError(describeError(err))
      endLocal('error')
    })
  },

  handleIce(data) {
    const callId = data.callId ?? data.call_id
    const candidate = data.candidate
    const state = useCallStore.getState()
    if (!pc || state.callId !== callId || !candidate) return

    pc.addIceCandidate(new RTCIceCandidate(candidate)).catch(() => {})
  },

  handleEnd(data) {
    const callId = data.callId ?? data.call_id
    const state = useCallStore.getState()
    if (state.callId && callId && state.callId !== callId) return

    const reason = data.reason
    if (reason === 'declined') {
      showError('Абонент отклонил звонок')
    } else if (reason === 'busy') {
      showError('Абонент занят')
    } else if (reason === 'disconnected' || reason === 'failed') {
      showError('Звонок завершён')
    }

    endLocal(reason || 'remote')
  },

  endCall(reason = 'hangup') {
    patch({ status: 'ending' })
    endLocal(reason)
  },

  toggleMute() {
    const { localStream, muted } = useCallStore.getState()
    const next = !muted
    localStream?.getAudioTracks?.().forEach((t) => {
      t.enabled = !next
    })
    patch({ muted: next })
  },

  toggleVideo() {
    const { localStream, videoEnabled } = useCallStore.getState()
    const next = !videoEnabled
    localStream?.getVideoTracks?.().forEach((t) => {
      t.enabled = next
    })
    patch({ videoEnabled: next })
  },
}
