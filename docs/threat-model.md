# Modelo de amenazas

| Amenaza | Control principal | Riesgo residual |
|---|---|---|
| Localizar o acosar a otra persona | Coordenadas cuantizadas, bandas de distancia, lugar solo tras propuesta, bloqueos bidireccionales | Inferencia por baja densidad; se mitiga con bandas amplias y umbral de grupo |
| Crear cuentas falsas o menores | OTP, rate limit, declaración 18+, adaptador de prueba reforzada, moderación | La edad declarada requiere control adicional antes de escala pública |
| Secuestrar una sesión | Tokens cortos, refresh rotatorio, detección de reuso, Keychain/Secure Store, cookies seguras | Dispositivo desbloqueado o email comprometido |
| Acceder a recursos ajenos | Autorización por miembro/recurso, RBAC, pruebas IDOR | Errores futuros de endpoint; mantener pruebas por módulo |
| Spam y abuso de chat | Chat solo confirmado y temporal, límites, reporte contextual, bloqueo | Contenido dañino antes de revisión humana |
| Manipular matching/concurrencia | Transacciones, idempotencia, una intención activa, consultas parametrizadas | Coordinación entre regiones si se escala sin consenso |
| Filtrar datos por logs/proveedores | Logs estructurados sin secretos/ubicación, minimización, contratos de encargado | Metadatos de infraestructura y correo |
| Abuso administrativo | Roles, auditoría append-only, revisión de acciones y acceso de red restringido | Cuenta admin comprometida; añadir MFA/SSO antes de producción |

Las prioridades previas al lanzamiento público son verificación reforzada de edad, MFA/SSO administrativo, monitorización de abuso, simulacro de incidente, revisión externa de privacidad y pruebas de penetración sobre el entorno final.
