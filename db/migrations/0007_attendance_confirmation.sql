CREATE TABLE attendance_verifications (
  match_id uuid NOT NULL REFERENCES matches(id) ON DELETE CASCADE,
  subject_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  state text NOT NULL CHECK (state IN ('pending','verified','rejected')),
  required_yes integer NOT NULL DEFAULT 1 CHECK (required_yes BETWEEN 0 AND 2),
  yes_votes integer NOT NULL DEFAULT 0,
  no_votes integer NOT NULL DEFAULT 0,
  auto_verified boolean NOT NULL DEFAULT false,
  decided_at bigint,
  PRIMARY KEY(match_id,subject_id)
);

CREATE TABLE attendance_review_assignments (
  match_id uuid NOT NULL,
  reviewer_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  subject_id uuid NOT NULL,
  state text NOT NULL DEFAULT 'pending' CHECK (state IN ('pending','yes','no','cancelled')),
  created_at bigint NOT NULL,
  responded_at bigint,
  PRIMARY KEY(match_id,reviewer_id,subject_id),
  FOREIGN KEY(match_id,reviewer_id) REFERENCES match_members(match_id,user_id) ON DELETE CASCADE,
  FOREIGN KEY(match_id,subject_id) REFERENCES match_members(match_id,user_id) ON DELETE CASCADE,
  CHECK (reviewer_id<>subject_id)
);

CREATE INDEX attendance_reviews_pending ON attendance_review_assignments(reviewer_id,state,created_at);
CREATE INDEX attendance_verified_person ON attendance_verifications(subject_id,state,match_id);

-- Historical check-ins predate peer confirmation and remain trusted.
INSERT INTO attendance_verifications(match_id,subject_id,state,required_yes,auto_verified,decided_at)
SELECT mm.match_id,mm.user_id,'verified',0,true,COALESCE(m.ends_at,m.scheduled_at)
FROM match_members mm JOIN matches m ON m.id=mm.match_id
WHERE m.state='COMPLETED' AND mm.checked_in=true AND mm.safety_exit=false
ON CONFLICT(match_id,subject_id) DO NOTHING;
