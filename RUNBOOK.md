# RUNBOOK — Public Wi-Fi Cybershow

Este documento resume la operativa del show en modo `live`. Está pensado para el equipo técnico que monta, arranca y cierra la función.

## 1. Objetivo

El show usa un router GL.iNet como punto de acceso controlado. La aplicación Qt muestra en pantalla la actividad de red, los dispositivos conectados, el portal cautivo, el mapa, el perfil de riesgo y el análisis de cifrado.

La idea es siempre la misma:

- un router dedicado;
- un móvil controlado;
- un portátil de operador;
- la aplicación en modo `live`.

## 2. Antes de abrir puertas

1. Encender el router Mango / GL.iNet GL-MT300N-V2.
2. Conectar su alimentación por USB.
3. Esperar a que el router arranque por completo.
4. Comprobar que el portátil del operador puede llegar a `http://192.168.8.1`.
5. Comprobar que el móvil de prueba está disponible y listo para conectarse.
6. Verificar que el acceso SSH al router funciona con `root@192.168.8.1`.

Si algo de esto falla, no conviene empezar el show todavía.

## 3. Red Wi-Fi del show

SSID habitual:

- `GL-MT300N-V2-28e`

La contraseña debe estar guardada en la libreta operativa o en el soporte acordado por el equipo. En algunos montajes iniciales fue `goodlife`, pero no debe darse por fija: hay que usar la que corresponda al router preparado para esa función.

## 4. Arranque del show

1. Encender router.
2. Conectar el portátil del operador a la red LAN del router. Puede ser por Wi-Fi del Mango o por cable Ethernet al Mango.
3. Abrir el panel del router en el navegador:
   - `http://192.168.8.1`
4. Conectar el móvil controlado a la misma Wi-Fi.
5. Lanzar la aplicación:

```powershell
public_wifi.exe --live --fullscreen
```

La aplicación debe abrir directamente la ejecución, no la pantalla de configuración.

### Topología obligatoria

El portátil que ejecuta la aplicación debe estar dentro de la red del Mango, con una IP `192.168.8.x` y puerta de enlace `192.168.8.1`.

No basta con que el móvil esté conectado al Mango. La app escucha en el portátil, y los scripts del router tienen que poder abrir conexiones TCP hacia el portátil en los puertos `5555`, `5556` y `8080`.

Formas válidas:

- portátil conectado a la Wi-Fi del Mango;
- portátil conectado por cable Ethernet al Mango;
- móvil conectado a la Wi-Fi del Mango.

Si el portátil está en otra Wi-Fi y solo el móvil está en el Mango, la app no recibirá eventos del router.

En Windows, comprobar la IP real del portátil:

```powershell
ipconfig
```

Buscar el adaptador conectado al Mango. Debe mostrar algo parecido a:

```text
IPv4 Address . . . . . . . . . . . : 192.168.8.182
Default Gateway . . . . . . . . . : 192.168.8.1
```

La IP del ejemplo, `192.168.8.182`, no es fija. En otro portátil o en otra sesión puede ser distinta.

## 5. Comprobaciones en vivo

### Pantalla 1: Principal

Aquí se controla el estado general.

Hay que comprobar:

- que el router aparece como listo;
- que la app reconoce el modo `LIVE`;
- que los puertos `5555`, `5556` y `8080` están preparados;
- que los contadores y estados cambian cuando hay actividad.

### Pantalla 2: Dispositivos + tráfico

En esta pantalla se ve:

- la lista de dispositivos conectados;
- el tráfico bruto del router;
- la URL del portal cautivo;
- la alerta de credenciales cuando el móvil usa el portal.

Flujo habitual:

1. Mostrar la URL del portal.
2. Hacer que el teléfono entre al portal.
3. Pedir el nombre y el correo.
4. Ver la credencial interceptada en la pantalla.

### Pantalla 3: Mapa / conexiones

Se usa para enseñar:

- las conexiones activas;
- el mapa de origen/destino;
- el dispositivo objetivo seleccionado;
- los eventos asociados a ese dispositivo.

### Pantalla 4: Perfil de riesgo

Se usa para explicar el riesgo operativo:

- puntuación;
- categorías detectadas;
- servicios observados;
- factores de riesgo;
- resumen para el operador.

### Pantalla 5: Análisis de cifrado

Se usa como momento escénico controlado.

En esta pantalla:

- conviene dejar abierto el chat de WhatsApp antes de entrar en la pantalla;
- la app arma el filtro de mensajería cifrada;
- el voluntario envía el mensaje cuando la pantalla ya está esperando señal;
- la consola escribe el flujo paso a paso;
- la secuencia termina en fallo controlado;
- el resultado deja claro que el cifrado no se rompe.

## 6. Atajos del operador

- `1` a `5`: ir directamente a una pantalla
- `Left Arrow` / `Right Arrow`: moverse entre pantallas
- `F9`: mostrar u ocultar la barra inferior
- `F10`: mostrar u ocultar el indicador `DEMO` / `LIVE`
- `Esc`: no hace nada

## 7. Comandos SSH útiles

Entrar al router:

```powershell
ssh root@192.168.8.1
```

Desde el router se pueden lanzar los scripts de eventos. Sustituir `<IP_DEL_PORTATIL>` por la IP `192.168.8.x` que haya mostrado `ipconfig`:

```bash
/root/send_traffic_events.sh <IP_DEL_PORTATIL> 5555
/root/device_watch.sh <IP_DEL_PORTATIL> 5556
/root/whatsapp_watch.sh <IP_DEL_PORTATIL> 5555
```

Si se ha actualizado una release, copiar primero los scripts incluidos en `scripts/` al router:

```powershell
scp -O .\scripts\device_watch.sh root@192.168.8.1:/root/device_watch.sh
scp -O .\scripts\send_traffic_events.sh root@192.168.8.1:/root/send_traffic_events.sh
scp -O .\scripts\cybershow_events.awk root@192.168.8.1:/root/cybershow_events.awk
scp -O .\scripts\sniff_payload.sh root@192.168.8.1:/root/sniff_payload.sh
scp -O .\scripts\whatsapp_watch.sh root@192.168.8.1:/root/whatsapp_watch.sh
ssh root@192.168.8.1 "chmod +x /root/device_watch.sh /root/send_traffic_events.sh /root/sniff_payload.sh /root/whatsapp_watch.sh"
```

Y, si hace falta, observar la actividad del sistema:

```bash
logread -f
```

## 8. Diagnóstico si la app no ve el móvil

### La app no conecta con el router

Comprobar primero que el portátil está realmente en la red del Mango:

```powershell
ipconfig
ping 192.168.8.1
ssh root@192.168.8.1
```

Si `ipconfig` no muestra ninguna interfaz con IP `192.168.8.x`, el portátil no está conectado al Mango. Conectar el portátil a la Wi-Fi del Mango o por cable Ethernet.

Si el navegador no abre `http://192.168.8.1`, la aplicación tampoco podrá arrancar los scripts por SSH.

Si el navegador abre el router pero la app no recibe eventos, revisar el firewall de Windows. La app necesita recibir conexiones entrantes desde `192.168.8.1` en:

- `5555`: eventos de tráfico;
- `5556`: eventos de dispositivos;
- `8080`: portal.

En un ordenador backup o en una red marcada como pública, Windows puede bloquear esas conexiones aunque el portátil pueda navegar.

### El router ve el móvil, pero la app no

La pantalla de clientes del GL.iNet no es la fuente directa de la app. La app recibe eventos de estos scripts del router:

- `/root/device_watch.sh`: genera el inventario de dispositivos. Al arrancar manda un `snapshot` completo; después revisa cada segundo `iwinfo ra0 assoclist`, `/tmp/dhcp.leases` e `ip neigh`, y envía `connected`, `updated`, `disconnected` y snapshots periódicos;
- `/root/send_traffic_events.sh`: convierte logs de `dnsmasq` en eventos de tráfico.
- `/root/whatsapp_watch.sh`: observa paquetes compatibles con WhatsApp y emite eventos `WHATSAPP` hacia la app.

Entrar por SSH al router y comprobar lo que ve cada fuente:

```bash
iwinfo ra0 assoclist
cat /tmp/dhcp.leases
ip neigh
logread -f | grep dnsmasq
```

El móvil debe aparecer como mínimo en `iwinfo ra0 assoclist`. Si también aparece en `/tmp/dhcp.leases` o `ip neigh`, la app podrá mostrar IP y nombre. Si aparece en el panel web del router pero no en `iwinfo ra0 assoclist`, el script de inventario no lo considerará conectado.

Si el móvil aparece en esos comandos, probar el envío manual hacia el portátil:

```bash
/root/device_watch.sh <IP_DEL_PORTATIL> 5556
```

En la consola de la app deben aparecer líneas JSON con `"type":"device"`. Si salen en SSH pero no llegan a la app, el problema suele ser la IP de destino equivocada o el firewall de Windows.

Si el móvil navega pero no genera eventos de tráfico visibles, abrir desde el móvil varias páginas web distintas y mirar:

```bash
logread -f | grep dnsmasq
```

Algunos móviles pueden reducir las consultas DNS visibles por caché, VPN, relay privado o DNS cifrado. Para la demo conviene desactivar VPN/relay privado en el móvil de show y usar navegación web normal.

## 9. Cierre del show

1. Parar la app.
2. Entrar por SSH al router si sigue activo.
3. Detener los procesos de eventos si están en ejecución.
4. Cerrar la sesión SSH.
5. Apagar el router si toca desmontaje.
6. Desconectar la alimentación USB.

## 10. Apagado recomendado

Si se está dentro de SSH:

```bash
Ctrl + C
exit
```

Si el equipo ya no se va a usar:

```bash
poweroff
```

## 11. Puntos importantes

- El modo `live` depende del router y de sus scripts.
- El modo `demo` no necesita router.
- El teléfono del show debe ser el único dispositivo controlado que genere la actividad visible.
- No hay que exponer datos reales de público ni credenciales fuera del flujo previsto.
- Si la red no está lista, es mejor retrasar el arranque que improvisar.
