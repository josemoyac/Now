# Modelo de datos

Las migraciones en `db/migrations` son la fuente de verdad. Las entidades principales son:

| Área | Entidades | Finalidad |
|---|---|---|
| Identidad | `users`, `auth_challenges`, `sessions`, `devices`, `consents` | Acceso, edad, dispositivos y consentimiento auditable |
| Red privada | `friendships`, `friend_invites`, `communities`, `community_members` | Amigos, amigos de amigos y pertenencia verificada |
| Radar | `activities`, `intents`, `matches`, `match_members`, `venues` | Intención efímera, formación del grupo y lugar público |
| Conversación | `messages`, `notifications` | Coordinación temporal y avisos accionables |
| Confianza | `blocks`, `reports`, `appeals`, `moderation_actions` | Prevención, revisión y trazabilidad |
| Operación | `feature_flags`, `analytics_events`, `audit_log` | Despliegue gradual, métricas agregadas y auditoría |

Las coordenadas exactas recibidas nunca se guardan: se transforman a una celda y un centro aproximado. Las relaciones de bloqueo se consultan en ambas direcciones. La fiabilidad es privada y solo alimenta el matching. La eliminación de cuenta anonimiza las referencias que deben conservarse por seguridad y borra los datos personales activos.

Los índices y restricciones evitan dos intenciones activas por persona, respuestas duplicadas y grupos fuera de tamaño. Las fechas se guardan como milisegundos UTC para mantener compatibilidad entre PostgreSQL y PGlite.
