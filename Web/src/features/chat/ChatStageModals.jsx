import { Modal } from '../../components/Modal.jsx'
import { Button } from '../../components/Button.jsx'
import { ConfirmDialog } from '../../components/ConfirmDialog.jsx'
import { MessageContextMenu } from './MessageContextMenu.jsx'
import { ForwardPickerModal } from './ForwardPickerModal.jsx'
import { CallStartModal } from './CallStartModal.jsx'
import { InChatSearch } from './InChatSearch.jsx'

export function ChatStageModals({
  chatId,
  chat,
  searchOpen,
  onCloseSearch,
  onSearchPick,
  ctxMenu,
  onCloseCtxMenu,
  isMine,
  canDelete,
  onReply,
  onCopy,
  onEdit,
  onDeleteRequest,
  onForward,
  onSaveToSaved,
  onTogglePin,
  forwardSource,
  onCloseForward,
  onPickForward,
  callStartOpen,
  onCloseCallStart,
  onStartCall,
  confirmClear,
  onCloseConfirmClear,
  onConfirmClear,
  confirmDelete,
  onCloseConfirmDelete,
  onConfirmDeleteChat,
  confirmDeleteMessage,
  onCloseConfirmDeleteMessage,
  onConfirmDeleteMessage,
  busyAction,
}) {
  return (
    <>
      {searchOpen ? (
        <InChatSearch
          chatId={chatId}
          onClose={onCloseSearch}
          onPick={onSearchPick}
        />
      ) : null}

      <MessageContextMenu
        open={!!ctxMenu}
        anchor={ctxMenu?.anchor}
        message={ctxMenu?.message}
        isMine={isMine}
        isDirect={chat?.type === 'direct'}
        canDelete={canDelete}
        onClose={onCloseCtxMenu}
        onReply={onReply}
        onCopy={onCopy}
        onEdit={onEdit}
        onDelete={onDeleteRequest}
        onForward={onForward}
        onSaveToSaved={onSaveToSaved}
        onTogglePin={onTogglePin}
      />

      <ForwardPickerModal
        open={!!forwardSource}
        excludeChatId={chatId}
        onClose={onCloseForward}
        onPick={onPickForward}
      />

      <CallStartModal
        open={callStartOpen}
        onClose={onCloseCallStart}
        onStart={onStartCall}
      />

      <ConfirmDialog
        open={!!confirmDeleteMessage}
        onClose={onCloseConfirmDeleteMessage}
        onConfirm={onConfirmDeleteMessage}
        title="Удалить сообщение"
        message="Удалить сообщение?"
        confirmLabel="Удалить"
      />

      <Modal
        open={confirmClear}
        onClose={onCloseConfirmClear}
        title="Очистить историю"
        size="sm"
        footer={
          <>
            <Button variant="ghost" onClick={onCloseConfirmClear}>
              Отмена
            </Button>
            <Button
              variant="danger"
              onClick={onConfirmClear}
              loading={busyAction}
            >
              Очистить
            </Button>
          </>
        }
      >
        <p style={{ margin: 0 }}>
          Очистить всю историю сообщений? Это действие нельзя отменить.
        </p>
      </Modal>

      <Modal
        open={confirmDelete}
        onClose={onCloseConfirmDelete}
        title="Удалить чат"
        size="sm"
        footer={
          <>
            <Button variant="ghost" onClick={onCloseConfirmDelete}>
              Отмена
            </Button>
            <Button
              variant="danger"
              onClick={onConfirmDeleteChat}
              loading={busyAction}
            >
              Удалить
            </Button>
          </>
        }
      >
        <p style={{ margin: 0 }}>Удалить чат? Сообщения будут удалены.</p>
      </Modal>
    </>
  )
}
