# RUNBOOK — Public Wi-Fi Cybershow

## Objetivo operativo

La app muestra la actividad de una Wi‑Fi pública controlada usando un router GL.iNet, un móvil de show y un portátil de operador.

## Antes de abrir puertas

1. Encender el router GL.iNet GL-MT300N-V2.
2. Verificar alimentación.
3. Esperar a que arranque.
4. Comprobar acceso a `http://192.168.8.1`.
5. Verificar que el móvil de show está disponible.
6. Verificar acceso SSH a `root@192.168.8.1`.

## Red del show

- SSID habitual: `GL-MT300N-V2-28e`
- La contraseña debe comprobarse en la documentación operativa vigente del equipo.

## Arranque del show

1. Encender el router.
2. Conectar el portátil del operador a la red del router.
3. Abrir `http://192.168.8.1`.
4. Conectar el móvil controlado a la misma Wi‑Fi.
5. Lanzar la app:

```powershell
under_attack_public_wifi.exe --live --fullscreen
```

## Topología obligatoria

El portátil que ejecuta la app debe estar dentro de la red `192.168.8.x` del router.

Comprobar con:

```powershell
ipconfig
```

Debe existir una interfaz con IP `192.168.8.x` y gateway `192.168.8.1`.

## Manejo de la aplicación

### Navegación

- `1` a `5`: ir a pantalla
- `Left Arrow` / `Right Arrow`: moverse entre pantallas
- `F9`: mostrar u ocultar la barra inferior
- `F10`: mostrar u ocultar el indicador `DEMO` / `LIVE`
- `Esc`: no hace nada

### Uso por pantallas

#### 1. Principal

- comprobar estado del router
- comprobar modo `LIVE`
- comprobar que los puertos `5555`, `5556` y `8080` están operativos

#### 2. Dispositivos + tráfico

- mostrar dispositivos conectados
- mostrar tráfico bruto
- mostrar URL del portal
- visualizar alerta de credenciales capturadas

#### 3. Mapa / conexiones

- mostrar conexiones activas
- mostrar mapa de origen/destino
- centrar narrativa en el dispositivo objetivo

#### 4. Perfil de riesgo

- explicar score, categorías, servicios y factores de riesgo

#### 5. Análisis de cifrado

- preparar el momento escénico
- dejar el chat de WhatsApp listo antes de entrar si aplica
- lanzar la secuencia de fallo controlado

## Comandos SSH útiles

Entrar al router:

```powershell
ssh root@192.168.8.1
```

Lanzar scripts de eventos desde el router:

```bash
/root/device_watch.sh <IP_DEL_PORTATIL> 5556
/root/traffic_watch.sh <IP_DEL_PORTATIL> 5555
```

Actualizar scripts del router si hace falta:

```powershell
scp -O .\scripts\device_watch.sh root@192.168.8.1:/root/device_watch.sh
scp -O .\scripts\traffic_watch.sh root@192.168.8.1:/root/traffic_watch.sh
scp -O .\scripts\cybershow_events.awk root@192.168.8.1:/root/cybershow_events.awk
scp -O .\scripts\oui.txt root@192.168.8.1:/root/oui.txt
scp -O .\scripts\sniff_payload.sh root@192.168.8.1:/root/sniff_payload.sh
ssh root@192.168.8.1 "chmod +x /root/device_watch.sh /root/traffic_watch.sh /root/sniff_payload.sh"
ssh root@192.168.8.1 "rm -f /root/send_traffic_events.sh /root/whatsapp_watch.sh /root/cybershow_events_v3_json.awk"
```

## Diagnóstico

### La app no conecta con el router

- comprobar `ipconfig`
- comprobar `ping 192.168.8.1`
- comprobar `ssh root@192.168.8.1`
- revisar firewall de Windows para `5555`, `5556` y `8080`

### El router ve el móvil pero la app no

Comprobar en el router:

```bash
iwinfo ra0 assoclist
cat /tmp/dhcp.leases
ip neigh
logread -f | grep dnsmasq
```

Si hace falta, lanzar manualmente:

```bash
/root/device_watch.sh <IP_DEL_PORTATIL> 5556
```

### No hay tráfico visible

- abrir varias webs desde el móvil
- revisar `logread -f | grep dnsmasq`
- desactivar VPN o relays privados si interfieren con la demo

## Deploy y releases

```powershell
.\package-release.ps1
.\package-release.ps1 -Force
```

El zip generado en `dist\` es el artefacto desplegable.

## Cierre del show

1. Parar la app.
2. Entrar por SSH al router si sigue activo.
3. Detener procesos de eventos si están corriendo.
4. Cerrar sesión SSH.
5. Apagar el router si corresponde.

## Consideraciones operativas

- `live` depende del router y sus scripts.
- `demo` no necesita router.
- El móvil del show debe ser el único dispositivo controlado con actividad visible.
- No improvisar si la red no está lista.
