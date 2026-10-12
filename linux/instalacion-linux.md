# Teclado Móvil – Qué instalar y hacer en Linux Mint

Versión para Linux Mint (22, base Ubuntu 24.04) de `instalacion.md`.

El proyecto tiene dos partes:
- `android-app/`: la app del celular (Kotlin). **Se puede compilar en Linux sin problema.**
- `windows-agent/`: el agente de Windows (.NET). **No corre en Linux tal cual** (ver sección 2).

## 1. Instalación automática

```bash
chmod +x instalar-todo.sh
./instalar-todo.sh                     # todo
./instalar-todo.sh --solo-desarrollo   # sin Brave, GIMP, OBS, etc.
```

Después de terminar: **cerrar sesión y volver a entrar** (para el PATH y los grupos `kvm`, `plugdev`, `vboxusers`).

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
| WinRAR | `p7zip-full`, `unrar` | |
| Photoshop / CapCut / FL Studio | No existen en Linux | Alternativas: GIMP + Krita / Kdenlive / LMMS |
| Intel Driver Assistant | No existe | Menú → Administrador de controladores |
| Hypervisor de Windows | KVM | Activar VT-x/AMD-V en la BIOS; el script te agrega al grupo `kvm` |

Gradle 8.7, AGP 8.5.0 y Kotlin 1.9.24 los descarga el wrapper (`./gradlew`) la primera vez. Hace falta internet.

## 2. El agente de Windows en Linux

`windows-agent` apunta a `net10.0-windows` y usa APIs de Windows (`System.Management`, teclas globales, Win+V…). Opciones:

1. **Seguir usando el agente en una PC con Windows** y solo desarrollar la app Android desde Linux.
2. **Portarlo a Linux**: cambiar el target a `net10.0`, y reemplazar lo específico de Windows (inyección de teclado/mouse con `uinput`/`evdev` o `xdotool`, captura de pantalla con X11/PipeWire, listado de adaptadores de red con `System.Net.NetworkInformation`). Si quieres, pásame el código del agente y lo adapto.
3. Windows en una máquina virtual (VirtualBox ya queda instalado), aunque la red en modo puente puede dar guerra.

## 3. Respaldo antes de migrar (si todavía no lo hiciste)
- [ ] Carpeta `proyectos` completa (hacer push de los repos).
- [ ] `~/.android/debug.keystore` (en Windows: `C:\Users\HP\.android\debug.keystore`).
- [ ] Carpeta `Documentos/MCP` (blender-mcp, vscode-mcp, el `.vsix`).
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
