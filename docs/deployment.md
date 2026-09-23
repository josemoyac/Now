# Despliegue

## Servicios

Producción requiere PostgreSQL 17, Redis 7, SMTP y HTTPS. Define todas las variables de `.env.example`; usa un secreto aleatorio de 32 bytes o más, `DEMO_MODE=false`, orígenes exactos y correos reales de soporte/privacidad. Google, Apple, verificación de edad y Expo Push se activan al aportar sus credenciales.

Ejecuta migraciones como tarea única antes de desplegar la nueva API:

```bash
npm ci
npm run db:migrate
NODE_ENV=production node apps/api/dist/main.js
```

Los Dockerfiles están en `deploy/`. `compose.production.yml` sirve como referencia reproducible para base de datos, Redis y API; coloca un proxy TLS delante y ejecuta web/admin con `deploy/Dockerfile.web`. El admin debe ir en un subdominio restringido por SSO/VPN además del RBAC de la aplicación.

## Comprobaciones previas

1. `npm run check` y `npm run test:e2e` pasan en el commit a desplegar.
2. `/health` responde con base de datos preparada y `demo:false`.
3. SMTP, OIDC, edad y push se prueban en staging con cuentas reales de prueba.
4. El dominio de API aparece en CORS, CSP, apps móviles y enlaces de correo.
5. Se ejecutan copias de seguridad cifradas y una restauración de prueba.
6. Alertas cubren errores 5xx, latencia, cola de moderación, trabajos detenidos y caducidades atrasadas.

## Publicación móvil

Expo usa `apps/mobile/eas.json`. Sustituye `api.example.invalid`, crea el proyecto EAS y define `EXPO_PUBLIC_EAS_PROJECT_ID`. Para iOS nativo sustituye `NOW_API_URL` en Release, selecciona el equipo correcto y archiva con `NOW/ExportOptions.plist`. La subida a tiendas requiere credenciales del propietario y la aprobación final sobre ficha, privacidad y territorios.

## Reversión

Conserva la imagen anterior, despliega migraciones compatibles hacia atrás y usa feature flags para cambios de matching. Si una versión falla, revierte clientes web/API, desactiva el flag y deja que los clientes móviles antiguos sigan usando contratos compatibles.
