-- @notx
-- `ALTER TYPE ... ADD VALUE` cannot run inside a transaction block in
-- Postgres, so this whole migration opts out of the runner's tx wrapper.
-- All statements below are idempotent (`IF NOT EXISTS`) so partial-apply
-- + retry is safe.

-- Allow the new chat type
ALTER TYPE chat_type ADD VALUE IF NOT EXISTS 'saved';

-- Message forwarding + pinning
ALTER TABLE messages ADD COLUMN IF NOT EXISTS forwarded_from_user_id UUID NULL REFERENCES users(id) ON DELETE SET NULL;
ALTER TABLE messages ADD COLUMN IF NOT EXISTS forwarded_from_chat_id UUID NULL REFERENCES chats(id) ON DELETE SET NULL;
ALTER TABLE messages ADD COLUMN IF NOT EXISTS is_pinned BOOLEAN NOT NULL DEFAULT FALSE;
ALTER TABLE messages ADD COLUMN IF NOT EXISTS pinned_at TIMESTAMPTZ NULL;
CREATE INDEX IF NOT EXISTS idx_messages_pinned ON messages(chat_id) WHERE is_pinned = TRUE;

-- Per-chat mute
CREATE TABLE IF NOT EXISTS chat_mutes (
  user_id     UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  chat_id     UUID NOT NULL REFERENCES chats(id) ON DELETE CASCADE,
  muted_until TIMESTAMPTZ NULL,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (user_id, chat_id)
);
