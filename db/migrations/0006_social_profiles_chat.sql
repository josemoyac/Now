ALTER TABLE messages ADD COLUMN delivered_at bigint;
ALTER TABLE messages ADD COLUMN read_at bigint;
CREATE TABLE chat_typing (
  match_id uuid NOT NULL REFERENCES matches(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  updated_at bigint NOT NULL,
  PRIMARY KEY(match_id,user_id)
);
CREATE INDEX chat_typing_recent ON chat_typing(match_id,updated_at);
CREATE TABLE direct_messages (
  id uuid PRIMARY KEY,
  sender_id uuid NOT NULL REFERENCES users(id),
  recipient_id uuid NOT NULL REFERENCES users(id),
  body text NOT NULL,
  created_at bigint NOT NULL,
  delivered_at bigint,
  read_at bigint,
  expires_at bigint NOT NULL,
  CHECK(sender_id<>recipient_id)
);
CREATE INDEX direct_messages_pair ON direct_messages(sender_id,recipient_id,created_at);
