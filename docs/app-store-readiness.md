# Preparación para App Store

El proyecto iOS nativo usa `app.now.social`, versión 1.0, iOS 16.4+, manifiesto de privacidad, permiso de ubicación en uso y esquema `NOW`. El proyecto compila en simulador iPhone 16. La API de demostración se inicia automáticamente al ejecutar Debug desde Xcode; el log es `.local/xcode-api.log`.

## Funciones incluidas

- Acceso por código de correo y Sign in with Apple nativo (cuando `APPLE_CLIENT_ID` está configurado); web con Google y Apple OIDC cuando se configuran sus Client IDs. El botón Google nativo para Xcode sigue pendiente. Incluye comunidad verificada, radar y encuentros en lugares públicos. El acceso demo solo aparece con `DEMO_MODE=true`. La contraseña del panel demo se configura localmente y no se publica.
- Segunda pregunta de tipología para cada actividad, usada por el matching.
- Comunidades con número de miembros y NOWs, nombres solo de personas con asistencia mutua y asistentes de eventos solo para quienes asistieron.
- Perfil con foto, nombre, notificaciones, privacidad, eliminación de cuenta, histórico y personas conocidas. Las fotos nuevas requieren aprobación en el panel de operaciones.
- Historial de chats de los NOWs asistidos. Los mensajes caducan a los 30 días tras el encuentro; el chat queda cerrado después. Hay bloqueo y reporte contextual.

## Datos pendientes del propietario

1. URL pública HTTPS de la API y de la web. Sustituir `https://api.example.invalid` en `NOW_API_URL` de Release y configurar `PUBLIC_WEB_URL`, `API_INTERNAL_URL` y `APP_ORIGINS` según `.env.example`. La web debe servir `/privacy`, `/safety` y `/delete-account`. No archivar ni subir una build con la URL de ejemplo.
2. Apple Developer Team, App ID con Sign in with Apple habilitado, Service ID web y URL de retorno, certificado y perfil de distribución, acceso a App Store Connect y contacto de soporte/privacidad. Para producción, también registrar Google OAuth Client IDs por plataforma y los orígenes web autorizados. El botón Google nativo requiere integrar el SDK de Google Sign-In y su URL scheme después de obtener el Client ID de iOS. Configurar firma automática o los perfiles de distribución.
3. Infraestructura de producción: PostgreSQL, Redis, SMTP, proxy TLS, secretos y `DEMO_MODE=false`; seguir `docs/deployment.md`. Comprobar `/health`, registro y envío de códigos con la API desplegada.
4. Política de privacidad final revisada con responsable, retención y contacto; responder cuestionario de privacidad de App Store Connect para email, identificadores, ubicación aproximada, foto y mensajes, reportes y diagnósticos según lo que realmente se recoja.
5. Capturas reales de dispositivos admitidos, clasificación de edad, URL de soporte, descripción, territorios y cuenta o modo de demostración para revisión. Preparar instrucciones de acceso a la comunidad y al panel de moderación si se solicitan.
6. Operación humana de moderación de fotos y reportes, con tiempos de respuesta y canal de contacto publicados antes del lanzamiento.

## Archivo y envío

Tras configurar los datos anteriores, elegir el equipo de firma en Xcode y ejecutar:

```bash
xcodebuild -project NOW/NOW.xcodeproj -scheme NOW -configuration Release -destination 'generic/platform=iOS' -archivePath .local/NOW.xcarchive NOW_API_URL=https://api.TU-DOMINIO.example archive
xcodebuild -exportArchive -archivePath .local/NOW.xcarchive -exportOptionsPlist NOW/ExportOptions.plist -exportPath .local/app-store
```

Validar la IPA en Transporter/App Store Connect y probar una build de TestFlight en un dispositivo físico: alta, código, comunidad, radar, confirmación, check-in, chat posterior, carga y revisión de foto, bloqueo, reporte, eliminación y restauración de sesión. El envío final depende de los accesos y datos del propietario.

Texto propuesto: **NOW — planes espontáneos cerca de ti**. Subtítulo: **Menos pantalla. Más vida.** Descripción breve: “Di qué te apetece y cuánto tiempo tienes. NOW forma un grupo pequeño de personas compatibles y propone un lugar público cercano. Sin perfiles públicos, sin seguidores y sin compartir tu posición.”
