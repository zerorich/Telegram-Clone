import { ArrowLeft, MoreVertical } from 'lucide-react'
import { Avatar } from '../../components/Avatar.jsx'
import { ChatHeaderMenu } from './ChatHeaderMenu.jsx'
import { memberCountLabel, userDisplayName } from '../../lib/chat.js'
import styles from './ChatStage.module.css'

export function ChatStageHeader({
  showBack,
  onBack,
  chat,
  isSaved,
  isGroup,
  title,
  avatar,
  membersCount,
  peer,
  peerOnline,
  someoneTyping,
  typingMember,
  headerMenuOpen,
  onToggleHeaderMenu,
  onOpenProfile,
  onToggleSearch,
  onCall,
  onScrollToTop,
  onClearHistory,
  onDeleteChat,
  onMute,
  onUnmute,
}) {
  return (
    <header className={styles.header}>
      {showBack ? (
        <button
          type="button"
          className={styles.iconBtn}
          aria-label="Назад"
          onClick={onBack}
        >
          <ArrowLeft size={22} />
        </button>
      ) : null}
      <button
        type="button"
        className={styles.titleLink}
        onClick={onOpenProfile}
        disabled={!chat || isSaved}
      >
        <Avatar src={avatar} name={title} size={42} saved={isSaved} />
        <div className={styles.titleBody}>
          <div className={styles.titleText}>{title || 'Чат'}</div>
          <div className={styles.subtitle}>
            {isSaved ? (
              'личное пространство'
            ) : someoneTyping ? (
              <span className={styles.subtitleTyping}>
                {typingMember?.user
                  ? `${userDisplayName(typingMember.user)} печатает…`
                  : 'печатает…'}
              </span>
            ) : isGroup ? (
              memberCountLabel(membersCount)
            ) : peerOnline ? (
              <span className={styles.subtitleOnline}>в сети</span>
            ) : peer ? (
              'был(а) недавно'
            ) : (
              ''
            )}
          </div>
        </div>
      </button>

      <div className={styles.headerActions}>
        <button
          type="button"
          className={styles.iconBtn}
          aria-label="Меню чата"
          aria-expanded={headerMenuOpen}
          aria-haspopup="menu"
          onClick={onToggleHeaderMenu}
        >
          <MoreVertical size={22} />
        </button>
      </div>

      <ChatHeaderMenu
        open={headerMenuOpen}
        chat={chat}
        isSaved={isSaved}
        onClose={() => onToggleHeaderMenu(false)}
        onToggleSearch={onToggleSearch}
        onCall={onCall}
        onScrollToTop={onScrollToTop}
        onClearHistory={onClearHistory}
        onDeleteChat={onDeleteChat}
        onMute={onMute}
        onUnmute={onUnmute}
      />
    </header>
  )
}
