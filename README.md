# Public Wi-Fi Cybershow

Aplicación Qt escénica para presentar riesgos de privacidad en redes Wi‑Fi públicas de forma controlada y teatral. Visualiza actividad de router, descubrimiento de dispositivos, portal cautivo, mapa, perfil de riesgo y una secuencia guionizada de análisis de cifrado.

## Qué es

Es una app autónoma dentro de la suite CuarzoPolar/Bajo Ataque. Usa un router dedicado y, según el modo, puede funcionar con datos reales controlados o en simulación completa.

## Modos de operación

- `live`: usa router, portal y helpers SSH
- `demo`: todo simulado, sin router

## Pantallas del show

| # | Pantalla | Función |
|---|---|---|
| 1 | `Principal` | dashboard, consolas SSH y estado del router |
| 2 | `Dispositivos + trafico` | dispositivos, tráfico bruto, portal y credenciales |
| 3 | `Mapa / conexiones` | mapa, trazas de paquetes y eventos del dispositivo |
| 4 | `Perfil de riesgo` | score, categorías, servicios y explicación |
| 5 | `Analisis de cifrado` | secuencia escénica controlada de fallo de descifrado |

## Comportamiento funcional

- En `live`, la app habla con un router GL.iNet preparado para la demo.
- En `demo`, simula tráfico, dispositivos y secuencias.
- La navegación es siempre controlada por operador.
- No existe pantalla de setup.
- La app arranca en `live` por defecto si no se indica otro modo.

## Arquitectura y dependencias externas

- Aplicación Qt para Windows.
- Puede lanzar y parar helpers del router por SSH.
- Recibe eventos de tráfico y dispositivos por TCP.
- Expone un portal cautivo falso para la narrativa escénica.

Servicios esperados en live:

- SSH a `root@192.168.8.1`
- eventos de tráfico en `5555`
- eventos de dispositivos en `5556`
- portal en `8080`

## Recursos requeridos

La app necesita estos recursos al arrancar:

- `:/world_map.svg`
- `:/flying-cuarzito.png`
- `:/demo_events.json`
- `resources/regions.json`
- `resources/services.json`

Si alguno falta o está corrupto, el arranque debe fallar de forma clara.

## Tecnología

| Capa | Tecnología |
|---|---|
| Plataforma | Windows |
| Framework | Qt |
| Build | CMake |
| Compilador | MSVC |
| Integración live | SSH + TCP + portal HTTP local |

## Contrato de operación

- No debe mostrar datos personales reales salvo que sean controlados, consentidos o simulados.
- No se deben escribir credenciales ni payloads crudos en el log operativo.
- Debe emitir líneas `CYBERSHOW_*` para orquestación.

## Estado actual

- Cinco pantallas runtime definidas.
- Modos `live` y `demo` activos.
- Navegación por teclas y barra inferior.
- `demo` controlado por operador, sin auto-ciclo.
- Tamaño de ventana y escalado ajustados para laptops y proyector.
- Considerada la app de referencia para pantallas operativas de la familia.
