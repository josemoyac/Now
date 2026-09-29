# Registro, ubicación y mercados: auditoría de alpha

Estado: revisión de producto y código, 29 de septiembre de 2026. No es dictamen legal ni política definitiva.

## Hechos implementados

- Registro web, Expo y OIDC exige aceptación expresa de normas (`terms=true`) y registra versión `2026-09`. El enlace al aviso de privacidad es informativo y no se registra como consentimiento.
- Las altas reales requieren un país seleccionado entre ES, PT, FR, DE, IT, IE, NL, BE y AT. No se infiere ES por defecto. Las cuentas existentes conservan su país y pueden iniciar sesión sin volver a pasar por el registro.
- La ubicación solo se pide al entrar en un flujo que la necesita. La app solicita ubicación en primer plano; el API exige un registro de permiso vigente para iniciar una intención o guardar la celda de avisos por interés. La denegación/revocación limpia celdas e intenciones activas. El check-in manual sigue disponible; el check-in por proximidad GPS exige el mismo permiso registrado.
- La coordenada llega al servidor en la solicitud y se redondea antes de persistirse. La precisión de la celda es aproximada, alrededor de 500 m. No existe ubicación en segundo plano ni historial GPS. El sistema operativo y NOW mantienen permisos separados.
- Fecha de nacimiento y email se guardan en `identity.contacts`. La edad se declara; no hay proveedor externo de verificación funcional en esta alpha. El matching abierto sigue bloqueado por los controles de verificación reforzada.
- Los plazos visibles describen la implementación actual y siguen sujetos a revisión legal antes de un piloto.

## Requisitos y referencias UE

- El GDPR exige información accesible sobre responsable, fines, base jurídica, destinatarios y conservación cuando se recogen datos directamente (arts. 12–14), y que cada tratamiento tenga una base jurídica adecuada (art. 6). En esta alpha faltan responsable identificado, análisis de bases por finalidad, encargados y canal operativo de derechos. [Reglamento (UE) 2016/679, texto consolidado EUR-Lex](https://eur-lex.europa.eu/eli/reg/2016/679).
- Si se usa consentimiento como base, debe ser libre, específico, informado e inequívoco, diferenciable de otras condiciones y revocable. Por eso el aviso informativo no se presenta como consentimiento; la elección de ubicación está en su propio flujo. La base jurídica final de ubicación aún requiere decisión. [EDPB, guía para pequeñas organizaciones](https://www.edpb.europa.eu/sme/be-compliant/process-personal-data-lawfully_en) y [Guidelines 05/2020](https://www.edpb.europa.eu/our-work-tools/our-documents/guidelines/guidelines-052020-consent-under-regulation-2016679_en).
- Para operaciones que probablemente entrañen alto riesgo, el responsable debe evaluar si corresponde una EIPD antes de comenzar. No hay una EIPD aprobada en este repositorio; debe decidirse con asesoría conforme a las características y escala reales del piloto. [GDPR, art. 35](https://eur-lex.europa.eu/eli/reg/2016/679).
- 112 es el número de emergencia común al que se puede llamar gratuitamente en toda la UE. [Comisión Europea, 112](https://digital-strategy.ec.europa.eu/en/policies/112).

## DSA y contenido de usuarios

NOW no tiene un feed público: las intenciones de matching se muestran en un ámbito limitado y los chats se envían a participantes identificados. La mensajería privada de un grupo finito puede quedar fuera de la definición de “plataforma en línea”, que exige alojar y difundir información al público; la clasificación del servicio completo depende de sus funciones reales y debe confirmarse legalmente antes del piloto, especialmente si se añade cualquier superficie pública. [Reglamento de Servicios Digitales, Reglamento (UE) 2022/2065, art. 3 y considerandos](https://eur-lex.europa.eu/legal-content/EN/TXT/?uri=CELEX%3A32022R2065).

## Apple App Review 1.2 y contenido de usuarios

La alpha tiene filtro de texto, reportes contextualizados y bloqueo. Aún faltan contacto público y capacidad de respuesta humana oportuna; la consola de moderación local no equivale a un equipo con cobertura. No declarar cumplimiento de App Review 1.2 hasta habilitar contacto publicado y proceso de atención con responsables, tiempos y escalado. [Apple App Review Guidelines, 1.2](https://developer.apple.com/app-store/review/guidelines/).

## Gate condicional para Estados Unidos

Esta revisión interpreta «América» como Estados Unidos. Los países de Latinoamérica y Canadá requerirán evaluaciones por jurisdicción antes de habilitarlos. Estados Unidos no es un mercado habilitado ni aparece como opción de registro. No añadir US hasta que fundador y asesoría definan disponibilidad geográfica, entidad/responsables, avisos y derechos estatales, conservación, contacto, moderación, cobertura operativa y tratamiento de menores. Si se autoriza US en el futuro, el flujo de emergencia debe usar 911 en esa jurisdicción y mantener 112 en países UE; no publicar una opción ni promesa de servicio US antes de esa decisión. La aplicabilidad de COPPA y leyes estatales depende de los criterios legales y hechos concretos, no solo de que el producto marque 18+.

| Marco | Activador a validar antes de US | Fuente primaria |
|---|---|---|
| CCPA/CPRA California | Cobertura sujeta a definiciones y umbrales de negocio; validar derechos, notice at collection, eliminación/acceso y opt-outs aplicables. | [CPPA: leyes y reglamentos vigentes](https://cppa.ca.gov/regulations/) |
| Colorado Privacy Act | Cobertura y deberes del responsable/procesador dependen de umbrales y actividad; revisar derechos y mecanismo de opt-out universal cuando proceda. | [Colorado Attorney General](https://coag.gov/resources/colorado-privacy-act/) |
| Connecticut Data Privacy Act | Validar umbrales, derechos y obligaciones del controlador según consumidores/actividad; no asumir cobertura automática. | [Connecticut General Statutes, Chapter 743jj](https://www.cga.ct.gov/current/pub/chap_743jj.htm) |
| COPPA | Evaluar si servicio se dirige a menores de 13 o tiene conocimiento real recogiendo datos personales de menores; no asumir que una auto declaración 18+ resuelve el análisis. | [FTC COPPA Rule](https://www.ftc.gov/legal-library/browse/rules/childrens-online-privacy-protection-rule-coppa) |
| NCMEC / CyberTipline | Diseñar proceso solo tras asesoría que determine obligaciones aplicables si el proveedor obtiene conocimiento real de hechos denunciables de abuso/explotación sexual infantil; no afirmar una obligación universal ni que el piloto ya tenga ese flujo. | [18 U.S.C. § 2258A](https://uscode.house.gov/view.xhtml?req=granuleid:USC-prelim-title18-section2258A&num=0&edition=prelim) |

## Apple: UX de permisos

Apple requiere que la ubicación sea pertinente, explicada y autorizada antes de recopilarla, transmitirla o usarla. La solicitud debe aparecer cuando la persona inicia la función que la necesita; una explicación previa y específica ayuda a que el permiso tenga contexto. Si el permiso falta, la función dependiente debe ofrecer alternativa o quedar desactivada. NOW no necesita ubicación permanente para el flujo descrito. [App Review Guidelines, sección 5.1](https://developer.apple.com/app-store/review/guidelines/) · [Core Location authorization](https://developer.apple.com/documentation/corelocation/requesting-authorization-to-use-location-services).

## Decisiones pendientes del fundador

1. Entidad responsable del tratamiento y domicilio/publicación.
2. Base jurídica para cuenta, edad, matching, coordenadas efímeras, avisos de intereses, seguridad y métricas; identificar cuáles requieren consentimiento separado.
3. Aprobación de plazos y excepciones de conservación, incluidas pruebas de seguridad y obligaciones legales.
4. Contacto público de privacidad y soporte; proceso y SLA para derechos, reclamaciones y brechas.
5. Proveedores, transferencias internacionales, contratos y evaluación de impacto antes del piloto.
6. Países UE concretos para el primer piloto y operación local disponible.
7. Gate US independiente con decisión legal, operación de seguridad y cobertura de emergencias antes de habilitar mercado.
8. Verificación de edad real, reglas de menores, apelaciones y controles de fraude.
9. Conciliar el manifiesto `PrivacyInfo.xcprivacy`, las fichas de privacidad de App Store Connect y Play Console, y los proveedores/SDKs efectivamente integrados antes de distribuir. El manifiesto por sí solo no completa esas declaraciones.
