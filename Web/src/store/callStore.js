import { create } from 'zustand'

/**
 * UI state for 1:1 WebRTC calls. WebRTC internals live in lib/callManager.js.
 */
export const useCallStore = create((set) => ({
  status: 'idle', // idle | outgoing | incoming | active | ending
  callId: null,
  peerUserId: null,
  peerName: '',
  media: 'audio',
  muted: false,
  videoEnabled: false,
  localStream: null,
  remoteStream: null,
  error: null,
  startedAt: null,

  reset() {
    set({
      status: 'idle',
      callId: null,
      peerUserId: null,
      peerName: '',
      media: 'audio',
      muted: false,
      videoEnabled: false,
      localStream: null,
      remoteStream: null,
      error: null,
      startedAt: null,
    })
  },

  patch(partial) {
    set(partial)
  },
}))
