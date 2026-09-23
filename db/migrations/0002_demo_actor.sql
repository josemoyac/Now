ALTER TABLE users ADD COLUMN is_demo_actor boolean NOT NULL DEFAULT false;
UPDATE users SET is_demo_actor=true WHERE is_demo=true AND role='user' AND username LIKE 'campus%';
