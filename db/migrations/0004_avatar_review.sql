ALTER TABLE users ADD COLUMN avatar_pending text;
ALTER TABLE users ADD COLUMN avatar_pending_at bigint;
CREATE INDEX users_avatar_review ON users(avatar_pending_at) WHERE avatar_pending IS NOT NULL;
