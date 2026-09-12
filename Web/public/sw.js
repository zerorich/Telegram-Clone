self.addEventListener('notificationclick', (event) => {
  event.notification.close()
  const chatId = event.notification.data?.chatId
  const url = chatId ? `/chats/${chatId}` : '/'
  event.waitUntil(
    clients.matchAll({ type: 'window', includeUncontrolled: true }).then((list) => {
      for (const client of list) {
        if ('focus' in client) {
          client.navigate(url)
          return client.focus()
        }
      }
      if (clients.openWindow) return clients.openWindow(url)
      return undefined
    }),
  )
})
