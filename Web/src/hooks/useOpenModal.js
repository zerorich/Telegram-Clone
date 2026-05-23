import { useCallback } from 'react'
import { useLocation, useNavigate } from 'react-router-dom'

/**
 * Open a modal route while keeping the current chat shell visible behind it.
 * The current location is stashed in history state so a back-navigation
 * dismisses the modal.
 */
export function useOpenModal() {
  const navigate = useNavigate()
  const location = useLocation()

  return useCallback(
    (to, options = {}) => {
      navigate(to, {
        ...options,
        state: {
          ...(options.state ?? {}),
          backgroundLocation: location.state?.backgroundLocation || location,
        },
      })
    },
    [navigate, location],
  )
}
