# Estado de auditoría de dependencias

La auditoría de producción no contiene vulnerabilidades altas ni críticas. npm informa avisos moderados y uno bajo dentro de la cadena de herramientas de Expo (`@expo/config-plugins` → `xcode` → `uuid`). No afectan al servidor API ni al código que se ejecuta en el dispositivo; se usan durante configuración/build.

`npm audit` propone como supuesta corrección bajar Expo 57 a Expo 46. Esa regresión pierde soporte actual y no es una reparación segura. También se probó una sustitución forzada de `uuid`, pero npm la marca incompatible con el rango declarado por `xcode`, por lo que se descartó. La acción correcta es actualizar Expo/config-plugins cuando publique una dependencia compatible y mantener esta cadena fuera del runtime de producción.

Comando de seguimiento:

```bash
npm audit --omit=dev
```

El lanzamiento debe bloquearse si aparecen vulnerabilidades altas o críticas en dependencias de runtime, o si cambia el alcance del aviso actual.
