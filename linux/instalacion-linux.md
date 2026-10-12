# Teclado Móvil – Qué instalar y hacer en Linux Mint

Versión para Linux Mint (22, base Ubuntu 24.04) de `instalacion.md`.

El proyecto tiene dos partes:
- `android-app/`: la app del celular (Kotlin). **Se puede compilar en Linux sin problema.**
- `windows-agent/`: el agente de Windows (.NET). **No corre en Linux tal cual** (ver sección 2).

## 1. Instalación automática

Lo más fácil es la ventana, donde marcas lo que quieres instalar (si falta `python3-tk`, el lanzador lo instala):

```bash
chmod +x instalar-todo-gui.sh instalar-todo.sh respaldo.sh
./instalar-todo-gui.sh
```

También se puede desde la terminal, sin ventana, **como usuario normal** (no root; el script pide `sudo` solo):

```bash
./instalar-todo.sh                             # todo
./instalar-todo.sh --solo-desarrollo           # sin Brave, GIMP, OBS, etc.
./instalar-todo.sh --solo=vscode,node,python   # solo esos componentes (más la base del sistema)
```

Los nombres (ids) de los componentes están en la lista `CATALOGO` de `instalar-todo-gui.py`. No borres ningún archivo de esta carpeta: la ventana usa `instalar-todo.sh` por dentro.

Después de terminar: **cerrar sesión y volver a entrar** (para el PATH y los grupos `kvm` y `plugdev`).

| Qué | Cómo se instala en Linux | Ruta / detalle |
|---|---|---|
| .NET SDK 10 | apt (`dotnet-sdk-10.0`) o PPA o script oficial | Si cae al script oficial queda en `~/.dotnet` |
| JDK 17 y 21 | apt (`openjdk-17-jdk`, `openjdk-21-jdk`) | `/usr/lib/jvm/...` |
| Android SDK | Command-line tools de Google | `~/Android/android-sdk` (antes `C:\Android\android-sdk`) |
| VS Code | Repositorio apt de Microsoft | Mismas extensiones que en Windows |
| Python | `python3` + venv en `~/.venvs/dev` | En Ubuntu 24.04 `pip` global está bloqueado (PEP 668); `pywin32` se omite |
| XAMPP | `apache2` + `php` + `mariadb-server` | No arrancan solos: `sudo systemctl start apache2 mariadb` |
| MSYS2 / Build Tools C++ | `build-essential`, `clang`, `cmake`, `ninja-build` | Ya incluyen gcc/make |
| Blender | Flatpak | |
| Unity Hub | Repositorio apt oficial de Unity | |
| Rust | `rustup` (incluye `cargo`) | `~/.cargo/bin` |
| Librerías para compilar apps Rust | apt: `libxkbcommon-dev`, `libwayland-dev`, `libx11-dev`, `libxrandr-dev`, `libxi-dev`, `libxcursor-dev`, `libgl1-mesa-dev`, `libgtk-3-dev`, `libfontconfig1-dev`, `libfreetype-dev`, `libasound2-dev`, `libssl-dev`, `libudev-dev` | Sin ellas `cargo` se detiene con errores tipo «no encuentro xkbcommon». Se marcan solas junto con las apps de ArtCraft |
| Proyectos de GitHub | `git clone` en `~/Escritorio/proyectos` | 12 repos tuyos (norkles505) + 12 alternativas de ArtCraft (storytold: PhotoCraft, WordCraft, etc.). Solo se descarga el código; las de ArtCraft las compilas tú con `cargo run --release`. Lo ya descargado no se toca |
| Claude Desktop y puentes MCP | Repositorio apt de Anthropic; `vscode-mcp` y `blender-mcp` | Hay que abrir Claude Desktop e iniciar sesión a mano |
| WinRAR | `p7zip-full`, `unrar` | |
| Photoshop / CapCut / FL Studio | No existen en Linux | Alternativas: GIMP + Krita / Kdenlive o Concat / LMMS |
| Concat (alternativa a CapCut) | `.deb` de la última versión en GitHub Releases (el instalador lo busca solo) | Editor de video open source, en beta. Es un programa ya compilado: no hace falta compilarlo |
| Intel Driver Assistant | No existe | Menú → Administrador de controladores |
| Hypervisor de Windows | KVM | Activar VT-x/AMD-V en la BIOS; el script te agrega al grupo `kvm` |

Gradle 8.7, AGP 8.5.0 y Kotlin 1.9.24 los descarga el wrapper (`./gradlew`) la primera vez. Hace falta internet.

## 2. El agente de Windows en Linux

`windows-agent` apunta a `net10.0-windows` y usa APIs de Windows (`System.Management`, teclas globales, Win+V…). Opciones:

1. **Seguir usando el agente en una PC con Windows** y solo desarrollar la app Android desde Linux.
2. **Portarlo a Linux**: cambiar el target a `net10.0`, y reemplazar lo específico de Windows (inyección de teclado/mouse con `uinput`/`evdev` o `xdotool`, captura de pantalla con X11/PipeWire, listado de adaptadores de red con `System.Net.NetworkInformation`). Si quieres, pásame el código del agente y lo adapto.
3. Windows en una máquina virtual (el script no instala VirtualBox; si lo quieres: `sudo apt install virtualbox`), aunque la red en modo puente puede dar guerra.

## 3. Respaldo antes de formatear (y restaurar después)
El instalador reinstala programas, pero no tus datos personales. Para eso está `respaldo.sh`:

```bash
# ANTES de formatear, con un USB conectado (el destino NO debe ser el disco que vas a formatear)
./respaldo.sh respaldar /media/TU_USUARIO/MI_USB [--con-proyectos]

# DESPUÉS de formatear y de correr el instalador
./respaldo.sh restaurar /media/TU_USUARIO/MI_USB/respaldo-AAAA-MM-DD_HHMM.tar.gz
```

- **Qué guarda:** `.bashrc`, `.profile`, `.gitconfig`, claves SSH y GPG, `~/.android/debug.keystore`, ajustes, atajos y snippets de VS Code, la lista de extensiones, la config de Claude Desktop y `Documentos/MCP`. Con `--con-proyectos` también `proyectos` (sin `node_modules`, `target`, `venv`, `.venv`, `__pycache__` ni `.gradle`).
- **Es seguro:** respaldar solo lee y copia. Al restaurar, si un archivo ya existe y es distinto, el actual queda guardado como `archivo.~1~`; los proyectos que ya tengas no se tocan.
- **Cuidado:** el respaldo incluye tus claves privadas. Guárdalo en un lugar de confianza.
- **No es intercambiable** con el `respaldo.ps1` de Windows: cada uno guarda las rutas de su sistema.

Lo que el respaldo no cubre (hazlo a mano):
- [ ] Hacer push de los repos con cambios sin subir (el instalador vuelve a clonar los de GitHub, pero lo que no subiste se pierde si no usas `--con-proyectos`).
- [ ] `android-app/wifi_device.txt` y `android-app/local.properties` (se pueden recrear).

## 4. Pasos de configuración de la app Android

1. Abrir la carpeta del proyecto en VS Code (`code ~/Escritorio/proyectos/keyboardmovil`).
2. Compilar: dentro de `android-app/` ejecutar
   ```bash
   ./gradlew assembleDebug
   adb install -r app/build/outputs/apk/debug/app-debug.apk
   ```
   (El script ya dejó `gradlew` ejecutable y `local.properties` con `sdk.dir=~/Android/android-sdk`.)
   Los `compilar.bat` / `emulador.bat` / `iniciar-agente.bat` tienen que convertirse a `.sh`; pásamelos y los convierto.
3. Por USB: activar **Depuración USB**. Si `adb devices` dice `no permissions`, cierra sesión y vuelve a entrar (grupo `plugdev`).
4. Por WiFi: activar **Depuración inalámbrica**, emparejar con `adb pair IP:PUERTO_DE_EMPAREJAMIENTO` y poner en `android-app/wifi_device.txt` la IP:puerto de la pantalla principal de Depuración inalámbrica.
5. Emulador: `emulator -avd MeshCraftPhone` (requiere KVM; comprueba con `kvm-ok`).

## 5. Red
- PC y celular en la **misma red WiFi**.
- Mint trae el firewall (`ufw`) desactivado. Si lo activas: `sudo ufw allow from 192.168.0.0/16 to any port 8765 proto tcp`.

## 6. Cosas que cambian al migrar
- La **debug.keystore** nueva tiene otra firma: si la app ya estaba en el celular, **desinstalarla antes** de reinstalar (o restaurar el keystore respaldado).
- La IP:puerto de la depuración inalámbrica es distinta: actualizar `wifi_device.txt`.
- El PIN del agente cambia en cada arranque.
- Las rutas ahora son `/home/TU_USUARIO/...` y distinguen mayúsculas/minúsculas.

## 7. Si algo falla
- *Gradle falla*: `java -version` debe mostrar 17 para compilar la app; `echo $JAVA_HOME` apunta al 21 por defecto. Para forzar 17: `JAVA_HOME=$(ls -d /usr/lib/jvm/java-17-openjdk-*) ./gradlew assembleDebug`.
- *`command not found` tras instalar*: abre una terminal nueva (el PATH se guarda en `~/.bashrc`).
- *El emulador va lentísimo o no abre*: virtualización desactivada en la BIOS o no estás en el grupo `kvm` (cierra sesión).
- *pip dice `externally-managed-environment`*: usa el venv (`source ~/.venvs/dev/bin/activate`).
- *`cargo` falla pidiendo una librería (por ejemplo «no encuentro xkbcommon»)*: marca «Librerías para compilar las apps Rust» en la ventana y vuelve a instalar, o instala con `apt` el paquete `-dev` que nombre el error y agrégalo a la lista del bloque `rustlibs` de `instalar-todo.sh`. Si dice que la versión de Rust es vieja: `rustup update`.
