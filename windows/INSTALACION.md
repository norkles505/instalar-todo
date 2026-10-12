# Teclado Móvil – Qué instalar y hacer en una PC nueva

Guía para dejar el proyecto funcionando igual que ahora después de formatear/resetear Windows.

El proyecto tiene dos partes:
- `android-app/`: la app del celular (Kotlin).
- `windows-agent/`: el agente de Windows (.NET), que recibe teclas/mouse y manda la pantalla.

## 1. Antes de resetear (respaldo)
Lo más fácil es `respaldo.ps1`, que guarda tus datos personales en un USB (no hace falta ser Administrador):

```powershell
# ANTES de resetear, con el USB conectado (el destino NO debe ser el disco que vas a formatear)
powershell -ExecutionPolicy Bypass -File .\respaldo.ps1 respaldar E:\ [-ConProyectos]

# DESPUÉS de resetear y de correr el instalador
powershell -ExecutionPolicy Bypass -File .\respaldo.ps1 restaurar E:\respaldo-AAAA-MM-DD_HHMM.tar.gz
```

- **Qué guarda:** claves SSH y GPG, `.gitconfig`, `C:\Users\HP\.android\debug.keystore`, ajustes, atajos y snippets de VS Code, la lista de extensiones, la config de Claude Desktop y `Documents\MCP`. Con `-ConProyectos` también `Desktop\proyectos` (sin `node_modules`, `target`, `venv`, `.venv`, `__pycache__` ni `.gradle`).
- **Es seguro:** respaldar solo lee y copia. Al restaurar, si un archivo ya existe y es distinto, el actual queda guardado como `archivo.bak1`; los proyectos que ya tengas no se tocan.
- **Cuidado:** el respaldo incluye tus claves privadas. Guárdalo en un lugar de confianza.
- **No es intercambiable** con el `respaldo.sh` de Linux: cada uno guarda las rutas de su sistema.

Lo que el respaldo no cubre (hazlo a mano):
- [ ] Hacer push de los repos con cambios sin subir (si no usas `-ConProyectos`, el instalador vuelve a clonar los de GitHub, pero lo que no subiste se pierde).
- [ ] Guardar `android-app\wifi_device.txt` y `android-app\local.properties` si quieres conservarlos (se pueden recrear).

## 2. Instalar en la PC nueva

**Automático:** doble clic en `INSTALAR-TODO.bat` (pide permiso de administrador solo) y reinicia la PC al terminar. Instala todo lo de la tabla de abajo y más (Python, Node, Blender, Unity, programas extra), y al final muestra una lista de lo que falló. Si quieres opciones, abre PowerShell como Administrador y corre:

```powershell
powershell -ExecutionPolicy Bypass -File .\instalar-todo.ps1                   # todo
powershell -ExecutionPolicy Bypass -File .\instalar-todo.ps1 -SoloDesarrollo   # sin Photoshop, FL Studio, etc.
powershell -ExecutionPolicy Bypass -File .\instalar-todo.ps1 -SinProyectos     # sin descargar los proyectos de GitHub
```

Lo mínimo para este proyecto, por si lo instalas a mano:

| Qué | Versión / detalle | Para qué |
|---|---|---|
| **.NET SDK** | **10** (el proyecto apunta a `net10.0-windows`) | Compilar/ejecutar el agente de Windows. Las librerías (QRCoder 1.4.3, System.Management 8.0.0) se restauran solas con `dotnet run` |
| **JDK** | **17** (Temurin / Eclipse Adoptium) | Compilar la app Android |
| **Android SDK** | En `C:\Android\android-sdk`, con `platforms;android-34`, `build-tools` y `platform-tools` (adb) | Compilar e instalar la app en el celular |
| **VS Code** | Con las extensiones que uses (Kotlin, C#, etc.) | Editar |
| **Git** | Última | Control de versiones |

Además, el instalador deja listo esto (no hace falta para el agente ni la app Android):

| Qué | Detalle |
|---|---|
| **Rust** | `Rustup` + `rustup default stable`. Para compilar necesita **Visual Studio Build Tools (C++)**, que el instalador también pone |
| **Proyectos de GitHub** | Se clonan en `Escritorio\proyectos`: 12 repos tuyos (norkles505) + 12 alternativas de ArtCraft (storytold: PhotoCraft, WordCraft, etc.). Solo se descarga el código; las de ArtCraft las compilas tú con `cargo run --release`. Lo ya descargado no se toca. Se omiten con `-SinProyectos` |

Gradle **8.7**, Android Gradle Plugin **8.5.0** y Kotlin **1.9.24** NO se instalan a mano: el wrapper (`gradlew.bat`) los descarga la primera vez. Hace falta internet.

Valores del proyecto que dependen de la PC:
- `android-app\local.properties` → `sdk.dir=C\:\\Android\\android-sdk`. Si el SDK queda en otra ruta, cambiar esa línea.
- `android-app\compilar.bat` → `JAVA_HOME` apunta a `C:\Program Files\Eclipse Adoptium\jdk-17.0.19.10-hotspot` y `ANDROID_HOME` a `C:\Android\android-sdk`. Si la versión del JDK o las rutas cambian, editar esas líneas.

## 3. Pasos de configuración
1. Abrir `C:\Users\HP\Desktop\proyectos\keyboardmovil` en VS Code.
2. **Agente de Windows**: ejecutar `iniciar-agente.bat` (hace `dotnet run` dentro de `windows-agent`).
   - La primera vez Windows pregunta por el **Firewall**: permitir en **redes privadas**. Sin esto el celular no puede conectarse.
   - Si sale error al iniciar el servidor (puerto 8765), ejecutar como Administrador o reservar el puerto con `netsh`.
3. **App del celular**: conectar el celular y ejecutar `android-app\compilar.bat`.
   - Por USB: activar **Depuración USB** en Opciones de desarrollador.
   - Por WiFi: activar **Depuración inalámbrica**, emparejar con `adb pair IP:PUERTO_DE_EMPAREJAMIENTO` y poner en `android-app\wifi_device.txt` una sola línea con la IP:puerto de la pantalla principal de Depuración inalámbrica (cambia cada vez que se apaga/prende).
4. En la app: escanear el QR que muestra el agente (o escribir IP, puerto 8765 y PIN) y aceptar los permisos (notificaciones, cámara, ignorar optimización de batería, y "mostrar sobre otras apps" para el botón flotante de captura).

## 4. Requisitos de red
- PC y celular en la **misma red WiFi**.
- Si la PC tiene VirtualBox, Hyper-V, VMware o VPN, el agente ya ignora esos adaptadores al elegir la IP.

## 5. Cosas que cambian al reinstalar
- La **debug.keystore** nueva tiene otra firma: si la app ya estaba instalada en el celular, **desinstalarla antes** de volver a instalar (o restaurar el keystore respaldado).
- La IP:puerto de la depuración inalámbrica es distinta: actualizar `wifi_device.txt`.
- El PIN del agente cambia en cada arranque (se muestra en la consola y en el QR).

## 6. Si algo falla
- *No conecta*: revisar firewall (red privada) y que ambos estén en la misma WiFi.
- *Gradle falla*: confirmar JDK 17 y la ruta `sdk.dir`.
- *Win+V (portapapeles) no abre nada*: activar el historial del portapapeles en Configuración → Sistema → Portapapeles.
- *`cargo` no se encuentra o falla al compilar una app Rust*: cierra y abre la consola (para que cargue el PATH) y corre `rustup default stable`. Si el error habla de `link.exe`, falta Visual Studio Build Tools (C++): vuelve a correr el instalador.
