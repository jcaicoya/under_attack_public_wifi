# CLAUDE.md — Public Wi-Fi Cybershow

Instrucciones de trabajo específicas para este subproyecto.

## Lectura obligatoria al empezar

Antes de trabajar aquí, lee y aplica también:

- `README.md`
- `RUNBOOK.md`
- `NEXT_STEPS.md`

## Qué contiene cada archivo

- `README.md`: qué es la app, pantallas, modos, arquitectura y restricciones.
- `RUNBOOK.md`: operativa de show, arranque, red, diagnóstico y release.
- `NEXT_STEPS.md`: pendientes actuales.
- `.claude/CLAUDE.md`: reglas de trabajo específicas de este directorio.

No dupliques información entre estos archivos. Cada dato debe vivir en un único sitio.

## Forma de trabajar en este directorio

- El usuario se encarga de compilar, probar, empaquetar, hacer commits y hacer push.
- Si cambias comportamiento runtime, dependencias live, contrato de logs u orquestación, actualiza el archivo correspondiente.
- Tras cada commit, `README.md`, `RUNBOOK.md` y `NEXT_STEPS.md` deben seguir reflejando el estado real del proyecto.
- Hay que preservar la restricción de no registrar credenciales reales ni payloads crudos en logs.

## Reglas importantes de esta app

- No reintroducir `--configure`.
- No reintroducir auto-ciclo de pantallas en demo.
- Mantener el watermark `DEMO` como no interactivo.
- Mantener la app alineada con el contrato `CYBERSHOW_*` y con el uso controlado de datos.

## Alcance de este archivo

Este archivo no debe repetir documentación general de producto ni instrucciones operativas de uso; eso pertenece a `README.md` o `RUNBOOK.md`.
