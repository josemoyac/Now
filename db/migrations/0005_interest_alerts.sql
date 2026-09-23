ALTER TABLE users ADD COLUMN interest_cell_x integer;
ALTER TABLE users ADD COLUMN interest_cell_y integer;
ALTER TABLE users ADD COLUMN interest_location_expires_at bigint;
CREATE INDEX users_interest_location ON users(interest_cell_x,interest_cell_y,interest_location_expires_at) WHERE interest_location_expires_at IS NOT NULL;
