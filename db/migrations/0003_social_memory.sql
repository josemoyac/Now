ALTER TABLE users ADD COLUMN avatar text;
ALTER TABLE activities ADD COLUMN options jsonb NOT NULL DEFAULT '[]';
ALTER TABLE intents ADD COLUMN subtype text;
ALTER TABLE matches ADD COLUMN subtype text;
ALTER TABLE matches ADD COLUMN community_id uuid REFERENCES communities(id);
UPDATE matches m SET community_id = i.community_id FROM match_members mm JOIN intents i ON i.id=mm.intent_id WHERE mm.match_id=m.id AND i.community_id IS NOT NULL;
UPDATE matches SET community_id=(SELECT id FROM communities WHERE name='Universidad de Sevilla' LIMIT 1) WHERE is_demo=true AND community_id IS NULL AND state='COMPLETED';

UPDATE activities SET options = CASE id
  WHEN 'coffee' THEN '[{"id":"tranquilo","label":"Café tranquilo","emoji":"☕"},{"id":"especialidad","label":"Café de especialidad","emoji":"🫘"},{"id":"para_llevar","label":"Para llevar y pasear","emoji":"🥤"}]'::jsonb
  WHEN 'social' THEN '[{"id":"cerveza","label":"Una cerveza","emoji":"🍺"},{"id":"vino","label":"Una copa de vino","emoji":"🍷"},{"id":"sin_alcohol","label":"Algo sin alcohol","emoji":"🧃"},{"id":"terraza","label":"Sentarnos en una terraza","emoji":"🌤️"}]'::jsonb
  WHEN 'food' THEN '[{"id":"tapas","label":"Tapas","emoji":"🥘"},{"id":"pizza","label":"Pizza","emoji":"🍕"},{"id":"asiatica","label":"Comida asiática","emoji":"🍜"},{"id":"vegana","label":"Vegana o vegetariana","emoji":"🥗"},{"id":"postre","label":"Un postre","emoji":"🍰"}]'::jsonb
  WHEN 'sport' THEN '[{"id":"futbol","label":"Fútbol","emoji":"⚽"},{"id":"padel","label":"Pádel","emoji":"🎾"},{"id":"running","label":"Running","emoji":"🏃"},{"id":"gimnasio","label":"Entrenar juntos","emoji":"🏋️"},{"id":"otro","label":"Otro deporte","emoji":"🏅"}]'::jsonb
  WHEN 'move' THEN '[{"id":"running","label":"Salir a correr","emoji":"🏃"},{"id":"bici","label":"Bici","emoji":"🚲"},{"id":"patines","label":"Patines","emoji":"🛼"},{"id":"entrenar","label":"Mover el cuerpo","emoji":"💪"}]'::jsonb
  WHEN 'study' THEN '[{"id":"biblioteca","label":"Ir a la biblioteca","emoji":"📚"},{"id":"coworking","label":"Coworking","emoji":"💻"},{"id":"idiomas","label":"Practicar idiomas","emoji":"🗣️"},{"id":"proyecto","label":"Avanzar un proyecto","emoji":"✏️"}]'::jsonb
  WHEN 'game' THEN '[{"id":"mesa","label":"Juegos de mesa","emoji":"🎲"},{"id":"cartas","label":"Cartas","emoji":"🃏"},{"id":"videojuegos","label":"Videojuegos","emoji":"🎮"},{"id":"ajedrez","label":"Ajedrez","emoji":"♟️"}]'::jsonb
  WHEN 'music' THEN '[{"id":"concierto","label":"Ir a un concierto","emoji":"🎤"},{"id":"jam","label":"Tocar juntos","emoji":"🎸"},{"id":"escuchar","label":"Compartir música","emoji":"🎧"},{"id":"bailar","label":"Bailar","emoji":"💃"}]'::jsonb
  WHEN 'walk' THEN '[{"id":"parque","label":"Por un parque","emoji":"🌳"},{"id":"ciudad","label":"Descubrir la ciudad","emoji":"🏙️"},{"id":"naturaleza","label":"Naturaleza","emoji":"🥾"},{"id":"fotografia","label":"Paseo con fotos","emoji":"📷"}]'::jsonb
  WHEN 'surprise' THEN '[{"id":"sorpresa","label":"Elige por mí","emoji":"✨"}]'::jsonb
  ELSE '[]'::jsonb
END;

CREATE INDEX matches_community_history ON matches(community_id, state, scheduled_at DESC);
CREATE INDEX messages_active_history ON messages(match_id, expires_at);
