# Privacidad, retención y seguridad

NOW practica minimización por diseño. La ubicación se solicita al activar una intención, se redondea antes de persistirse y se borra al finalizar o retirar el consentimiento. No hay localización en segundo plano, mapa de personas ni historial de movimientos. Los clientes ofrecen exportación, retirada de ubicación, revocación de sesiones y eliminación de cuenta.

| Dato | Uso | Retención prevista |
|---|---|---|
| Coordenada aproximada de intención | Matching cercano | Hasta cerrar/caducar la intención, máximo 120 minutos |
| Propuesta y participantes | Coordinar encuentro y resolver incidentes | 90 días, después agregación/anominización |
| Chat del encuentro | Coordinación antes y después del NOW | 30 días tras finalizar; ampliable si existe reporte |
| OTP | Acceso | 10 minutos; solo hash |
| Foto de perfil | Identificación entre personas coincidentes | Hasta sustitución o eliminación de cuenta; nueva foto visible tras revisión humana |
| Sesiones | Seguridad de cuenta | Hasta revocación/caducidad |
| Reportes y auditoría | Confianza, apelación y obligaciones | Según política legal publicada y necesidad documentada |
| Analítica | Salud del producto | Agregada por día, actividad, comunidad y ciudad |

Los tokens de actualización rotan y la reutilización revoca la familia. En navegador, las cookies son `HttpOnly`, `SameSite=Lax` y `Secure` en producción; las mutaciones verifican origen. En móvil, los tokens quedan en Secure Store o Keychain para este dispositivo. La API aplica límites por IP y actor, validación Zod, consultas parametrizadas, autorización por recurso y RBAC administrativo.

La foto se reduce a JPEG de 256 píxeles sin metadatos y pasa por una cola de moderación antes de ser visible. Las comunidades muestran nombres únicamente de personas con asistencia mutua confirmada; otros miembros aparecen solo como total. Los asistentes de un NOW se revelan solo a quien asistió.

El centro de seguridad permite salida sin penalización, compartir el encuentro, bloquear y reportar en contexto. Los reportes entran en una cola con severidad, historial y apelación. El botón 112 solo abre el marcador tras confirmación y deja claro que NOW no es un servicio de emergencia.

Antes de producción deben fijarse responsable del tratamiento, base legal, plazos definitivos, contacto DPO/privacidad, proceso de solicitudes y acuerdos con proveedores. La política pública del producto está disponible en `/privacy` y las normas en `/safety`.
