# Preparación para Google Play

La app Expo usa el paquete `app.now.social`, ubicación solo en primer plano y bloquea ubicación en segundo plano, contactos, cámara y micrófono. EAS genera AAB de producción cuando se configura el proyecto.

Antes de subir:

- Sustituir `api.example.invalid` y crear `EXPO_PUBLIC_EAS_PROJECT_ID`.
- Crear la aplicación en Play Console, App Signing y pista de prueba cerrada.
- Completar Data Safety según el comportamiento real: cuenta, email, ubicación aproximada, contenido de chat, reportes y diagnósticos.
- Publicar política de privacidad y URL web de eliminación de cuenta; la eliminación también existe en la app.
- Declarar audiencia exclusivamente adulta y evitar segmentación o creatividades dirigidas a menores.
- Completar clasificación de contenido, acceso de revisión, formulario de contenido generado por usuarios y proceso de moderación.
- Subir capturas de teléfono y gráfico destacado; verificar contraste, TalkBack y escalado de texto.
- Ejecutar prueba cerrada con distintos fabricantes, permisos denegados y conectividad intermitente.

Comandos, después de iniciar sesión en EAS:

```bash
cd apps/mobile
npx eas-cli build --platform android --profile production
npx eas-cli submit --platform android --profile production
```

La segunda orden publica externamente y debe ejecutarla el propietario con la ficha y credenciales ya revisadas.
