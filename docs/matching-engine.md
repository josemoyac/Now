# Motor de matching

El motor es determinista para una misma foto de datos. Primero aplica filtros duros: mayoría de edad, intención activa, ventana temporal compatible, actividad compatible, radio, visibilidad autorizada, comunidad verificada cuando procede, ausencia de bloqueos y reportes incompatibles, y disponibilidad para no duplicar una propuesta.

Después calcula una puntuación normalizada con proximidad aproximada, solapamiento de tiempo, relación social, fiabilidad privada, preferencia de presupuesto y diversidad del grupo. Elige entre 3 y 6 personas y exige un lugar público abierto, seguro, con capacidad y compatible con la actividad. Si no existe lugar apto, no crea el grupo.

La creación se protege con una clave idempotente basada en miembros e intenciones. Un segundo proceso que evalúe el mismo conjunto obtiene el grupo existente. La aceptación es transaccional: solo la aceptación de todos confirma. Un rechazo o la caducidad libera a los participantes que siguen disponibles.

## Privacidad y equidad

- La distancia se expresa en bandas, nunca como posiciones individuales.
- El motor no usa atributos sensibles ni popularidad pública.
- Las comunidades limitan el conjunto solo cuando la persona elige ese alcance.
- Bloqueos y reportes tienen prioridad sobre cualquier puntuación.
- Las razones de exclusión se registran solo como contadores agregados para detectar sesgo sin crear perfiles paralelos.

## Operación

Las actividades y sus compatibilidades son configurables desde administración. Los pesos deben cambiarse detrás de un feature flag, compararse con tasa de propuesta, confirmación, asistencia, reportes e `IRL Hours`, y poder revertirse sin migrar datos.
