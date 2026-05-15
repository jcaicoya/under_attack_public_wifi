# Public Wi-Fi Cybershow

Public Wi-Fi Cybershow is a Qt stage application for presenting public Wi-Fi privacy risks in a controlled, theatrical way. It visualizes router activity, device discovery, portal captures, map trails, risk scoring, and a scripted encryption analysis screen.

The app supports two operating profiles:

- `live`: used with the router, portal, and SSH helpers
- `demo`: fully simulated, no router required

The app supports these launch modes:

- no arguments: enter runtime in live mode
- `--demo`: enter runtime in demo mode
- `--live`: enter runtime in live mode

Launching with the removed `--configure` mode fails with a startup error.

## Screen Contract

1. `Principal` - control dashboard, SSH consoles, router status
2. `Dispositivos + trafico` - devices, raw traffic, portal URL, credential reveal
3. `Mapa / conexiones` - world map, packet trails, selected-device events
4. `Perfil de riesgo` - score, categories, services, risk explanation
5. `Analisis de cifrado` - controlled demo playback, always fails, then reassurance

## How To Operate It

### Runtime Navigation

During execution the navigation is always operator-controlled:

- `1` to `5` jump to a screen
- `Left Arrow` and `Right Arrow` move between screens
- clicking the bottom navigation bar changes screens
- `Esc` does nothing
- `F9` shows or hides the bottom navigation bar
- `F10` shows or hides the `DEMO` / `LIVE` badge

There are no letter-based navigation shortcuts. Demo mode does not auto-cycle screens.
The runtime shell is screen-aware: windowed mode sizes itself from the selected display, the minimum window floor is lower than the original release, and the read-only dashboards do not take keyboard focus.

### Screen Summary

1. `Principal`
   - control dashboard
   - SSH consoles and router status
   - live/demo operational state

2. `Dispositivos + trafico`
   - connected and known devices
   - raw traffic stream
   - portal URL banner
   - captured credential alert

3. `Mapa / conexiones`
   - world map
   - animated packet trails
   - selected-device traffic view

4. `Perfil de riesgo`
   - score and risk tier
   - detected categories
   - observed services
   - risk factors and operator summary

5. `Analisis de cifrado`
   - controlled demo sequence
   - terminal playback
   - always ends in a failed-decryption reassurance

Demo mode adds a non-interactive pulsing `DEMO` watermark in the center-right of the window.

## Requirements And Constraints

### Build And Runtime

- Qt 6.7.3
- CMake 3.28+
- MSVC on Windows
- Visual C++ Redistributable on target machines

### Live Mode

Live mode expects a private GL.iNet GL-MT300N-V2 router running the companion scripts.

Required services:

- SSH access to `root@192.168.8.1`
- traffic events on port `5555`
- device events on port `5556`
- fake portal on port `8080`

The app starts and stops the router-side helpers through SSH when the operator uses the controls on Screen 1. Live mode also expects the local machine to be reachable from the router scripts.

### Demo Mode

Demo mode is self-contained:

- no router required
- no SSH dependency
- simulated devices and traffic
- operator-controlled navigation only

### Operational Constraints

- The app must never show real personal data unless it is controlled, consented, or simulated.
- Credential values and raw traffic payloads are not written to the operational log.
- Runtime launches in live mode by default, or in demo mode with `--demo`.
- Screen changes and key runtime events are emitted through the Cybershow stdout protocol.
- Operational logging goes to `logs/under_attack_public_wifi.log`.

### Resources

Startup requires these resources:

- `:/world_map.svg`
- `:/flying-cuarzito.png`
- `:/demo_events.json`
- `resources/regions.json`
- `resources/services.json`

If any required resource is missing or corrupted, startup fails clearly.

### Protocol And Logging

Stdout is reserved for `CYBERSHOW_*` orchestration lines where possible:

- `CYBERSHOW_STATUS READY`
- `CYBERSHOW_STATUS RUNNING`
- `CYBERSHOW_SCREEN <n> <id>`
- `CYBERSHOW_STATUS ERROR <code>`

Operational logging uses:

```text
timestamp | under_attack_public_wifi | launchMode | profile | level | component | message
```

## Release Packaging

Use `package-release.ps1` to create a deployable zip and record the release.

```powershell
.\package-release.ps1
.\package-release.ps1 -Force
```

What the script does:

1. Checks the current `HEAD` commit against the last recorded release
2. Builds the Release configuration
3. Stages the executable, Qt runtime files, plugins, and runtime resources
4. Creates `dist\bajo-ataque-under_attack_public_wifi-vNN.zip`
5. Appends the release entry to `releases.json`
6. Creates a matching git tag

The resulting zip is what we deploy. After packaging, push tags when needed:

```powershell
git push --tags
```

Each zip includes `RUNBOOK.md` as the live-mode operator checklist.

## Look And Feel

The app follows the Cybershow shared visual standard:

- dark technical background
- Spanish UI text
- operator-first dashboards
- common bottom navigation
- consistent panel styling
- monospaced terminal areas
- operative screens for dashboards, maps, logs, and analysis
- scenic screens only where the effect is the point
- screen-aware startup sizing and splitter weights for laptop and projector layouts
- shared typography scaling from the selected display height

The Public Wi-Fi app is the reference implementation for operative screens in the Cybershow family.

## Ethics

This is a controlled demonstration. It is intended for awareness, not intrusion.

- no real attack traffic
- no audience device inspection
- no uncontrolled disclosure of sensitive data
- only the controlled show phone and the dedicated router are used
