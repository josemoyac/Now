# NOW.

NOW convierte un rato libre en un encuentro pequeño y cercano. Una persona indica qué le apetece, cuánto tiempo tiene y con quién quiere coincidir; el motor forma grupos de 3–6 personas, propone un lugar público y abre un chat de grupo contextual cuando todo el grupo confirma.

Este repositorio contiene el producto completo:

- `apps/web`: experiencia web responsive y páginas públicas de privacidad, seguridad y eliminación.
- `apps/mobile`: app Expo para iOS, Android y web.
- `NOW`: app iOS nativa SwiftUI que usa la misma API.
- `apps/admin`: consola de operaciones, moderación, comunidades, lugares y métricas.
- `apps/api`: API Fastify, WebSocket, tareas de caducidad, autenticación y motor de matching.
- `packages`: tipos, dominio, cliente API, configuración y UI compartidos.
- `db`: migraciones SQL y datos ficticios de demostración.

## Arranque local

Requiere macOS o Linux, Node 22.13+ (se recomienda Node 24) y npm 10+. No requiere Docker para la demo: PGlite ejecuta PostgreSQL de forma embebida.

```bash
cp .env.example .env
./scripts/runtime.sh npm install
./scripts/runtime.sh npm run db:migrate
./scripts/runtime.sh npm run db:seed
./scripts/runtime.sh npm run demo
```

Abre `http://localhost:3000` para el producto, `http://localhost:3002` para administración y `http://localhost:4000/docs` para OpenAPI. En demo puedes entrar como José, Ana, Carlos o Lucía. Configura `DEMO_ADMIN_PASSWORD` en tu `.env` local antes de usar el acceso rápido de administración; nunca se publica ni se incluye una contraseña compartida. Todos los perfiles, lugares y encuentros son ficticios.

Para Expo:

```bash
EXPO_PUBLIC_API_URL=http://IP-DE-TU-MAC:4000 ./scripts/runtime.sh npm run dev:mobile
```

Para iOS nativo, abre [NOW.xcodeproj](/Users/josemoyacarrasco/Documents/Mios/Codex/Now/NOW/NOW.xcodeproj) y selecciona el esquema compartido `NOW`. Al pulsar Run, Xcode migra/siembra la base demo e inicia la API en `http://127.0.0.1:4000` de forma idempotente. El log queda en `.local/xcode-api.log`; `./scripts/xcode-stop-api.sh` la detiene. En un iPhone físico configura `NOW_API_URL` con la IP LAN o un dominio HTTPS. La URL de producción vive en Release y debe reemplazarse antes del archivo de App Store.

## Verificación

```bash
./scripts/runtime.sh npm run lint
./scripts/runtime.sh npm run typecheck
./scripts/runtime.sh npm test
./scripts/runtime.sh npm run test:e2e
./scripts/runtime.sh npm run build
./scripts/runtime.sh npm run build:ios-native
```

La suite cubre reglas puras del matching, seguridad de autenticación, CSRF, IDOR, concurrencia, privacidad de ubicación, reportes, bloqueo, retención y el recorrido completo desde alta hasta encuentro.

## Producción

El servidor falla de forma segura si `NODE_ENV=production` y faltan PostgreSQL, Redis, SMTP o un secreto de al menos 32 caracteres. Copia `.env.example`, completa los proveedores y sigue [deployment.md](/Users/josemoyacarrasco/Documents/Mios/Codex/Now/docs/deployment.md). Las listas de publicación están en [app-store-readiness.md](/Users/josemoyacarrasco/Documents/Mios/Codex/Now/docs/app-store-readiness.md) y [play-store-readiness.md](/Users/josemoyacarrasco/Documents/Mios/Codex/Now/docs/play-store-readiness.md).

## Principios del producto

- Solo mayores de 18 años; edad declarada en V1 y adaptador de verificación reforzada preparado.
- La ubicación se solicita únicamente al activar el radar, se cuantiza y nunca se muestra a otras personas.
- No hay perfiles públicos, feed, seguidores ni puntuaciones visibles. El chat es contextual y caduca 30 días después del encuentro para quienes asistieron.
- Las propuestas caducan en 90 segundos; el chat se abre tras aceptación total y sigue disponible durante 30 días después del encuentro solo para asistentes.
- Lugares públicos revisables, salida segura sin penalización, bloqueo y reporte contextual.
- La métrica principal es `IRL Hours Created`, calculada con duración prevista y asistencia confirmada.

Consulta [architecture.md](/Users/josemoyacarrasco/Documents/Mios/Codex/Now/docs/architecture.md), [matching-engine.md](/Users/josemoyacarrasco/Documents/Mios/Codex/Now/docs/matching-engine.md) y [privacy-and-safety.md](/Users/josemoyacarrasco/Documents/Mios/Codex/Now/docs/privacy-and-safety.md) para las decisiones operativas.

El estado y tratamiento de avisos transitivos está documentado en [security-audit.md](/Users/josemoyacarrasco/Documents/Mios/Codex/Now/docs/security-audit.md).


### Acceso social y avisos por intereses

El inicio social web admite Google Identity Services y Sign in with Apple cuando se configuran sus identificadores públicos. `GOOGLE_CLIENT_ID` acepta las audiencias de Google separadas por comas y las verifica el API; `GOOGLE_WEB_CLIENT_ID` identifica el botón GIS web (si se omite, se usa el primero de la lista). `GOOGLE_IOS_CLIENT_ID` queda reservado para la integración nativa del SDK de Google, aún pendiente. `APPLE_CLIENT_ID` acepta el Service ID web y/o el Bundle ID nativo. Configura en Google Cloud el origen web autorizado y en Apple Developer el dominio/callback, el servicio Sign in with Apple y la dirección de retorno del dominio publicado. Los secretos de Apple/Google no se incluyen en la app. Sin esos IDs, el acceso por código email sigue disponible.

En el alta, el perfil guía la selección de actividades y tipologías. El usuario puede optar por alertas cercanas; se pide ubicación en primer plano, se conserva solo una celda de aproximadamente 500 m durante dos horas y se elimina al caducar o retirar el permiso. El matching respeta radio, preferencia de subtipo, privacidad del origen y bloqueos. La alerta se crea en el centro de notificaciones; las push fuera de la app requieren registrar credenciales del proveedor y tokens de dispositivo en producción.
