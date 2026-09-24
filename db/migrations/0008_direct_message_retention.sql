-- Direct-message evidence is retained only while a linked safety report is
-- active or within the configured post-resolution retention window.
ALTER TABLE reports ADD COLUMN direct_message_id uuid REFERENCES direct_messages(id) ON DELETE SET NULL;
CREATE INDEX reports_direct_message ON reports(direct_message_id) WHERE direct_message_id IS NOT NULL;
CREATE INDEX direct_messages_expiry ON direct_messages(expires_at);
