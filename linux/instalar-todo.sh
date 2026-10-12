#!/usr/bin/env bash
# =====================================================================
# instalar-todo.sh  -  Reinstala el entorno de desarrollo en Linux Mint
# (equivalente de instalar-todo.ps1 + instalar-todo.bat de Windows)
#
# COMO USARLO (con internet):
#   1. Abre una terminal COMO USUARIO NORMAL (no root; el script pide sudo solo).
#   2. cd ~/Escritorio/proyectos/...   (donde hayas copiado este archivo)
#   3. chmod +x instalar-todo.sh && ./instalar-todo.sh
#      Solo programas de desarrollo (sin Brave, GIMP, OBS, etc.):
#      ./instalar-todo.sh --solo-desarrollo
#
# Pensado para Linux Mint 22 (base Ubuntu 24.04). Al final muestra una
# lista de lo que fallo, para instalarlo a mano.
# =====================================================================

SOLO_DEV=0
[ "${1:-}" = "--solo-desarrollo" ] && SOLO_DEV=1

if [ "$EUID" -eq 0 ]; then
    echo "No ejecutes este script como root. Usa tu usuario normal (pide sudo cuando haga falta)."
    exit 1
fi
if ! command -v apt-get >/dev/null 2>&1; then
    echo "Este script es para Linux Mint / Ubuntu / Debian (necesita apt)."
    exit 1
fi

FALLOS=()
titulo() { echo -e "\n\033[1;33m=== $* ===\033[0m"; }
info()   { echo -e "\033[1;36m>> $*\033[0m"; }
fallo()  { FALLOS+=("$1"); echo -e "\033[1;31m!! Fallo: $1\033[0m"; }

# Pide la contrasena de sudo una vez y la mantiene viva mientras corre el script
sudo -v || exit 1
( while true; do sudo -n true; sleep 50; kill -0 "$$" 2>/dev/null || exit; done ) 2>/dev/null &
KEEPALIVE_PID=$!
trap 'kill $KEEPALIVE_PID 2>/dev/null' EXIT

# Carpetas del usuario (en Mint en espanol son Escritorio / Documentos)
DESKTOP="$(xdg-user-dir DESKTOP 2>/dev/null || echo "$HOME/Desktop")"
DOCS="$(xdg-user-dir DOCUMENTS 2>/dev/null || echo "$HOME/Documents")"
MCP_DIR="$DOCS/MCP"
SDK="$HOME/Android/android-sdk"

export ANDROID_HOME="$SDK"
export PATH="$SDK/platform-tools:$SDK/emulator:$SDK/cmdline-tools/latest/bin:$HOME/.local/bin:$HOME/.cargo/bin:$HOME/.npm-global/bin:$HOME/.dotnet:$PATH"

apt_instalar() {          # apt_instalar "Nombre" paquete1 paquete2 ...
    local nombre="$1"; shift
    info "$nombre ($*)"
    sudo DEBIAN_FRONTEND=noninteractive apt-get install -y "$@" || fallo "$nombre"
}
flatpak_instalar() {      # flatpak_instalar "Nombre" id.flatpak
    info "$1 (flatpak: $2)"
    sudo flatpak install -y --noninteractive flathub "$2" || fallo "$1"
}
paso() {                  # paso "Nombre" funcion  -> corre la funcion y registra si falla
    local n="$1"; shift
    info "$n"
    ( set -e; "$@" ) || fallo "$n"
}

# ---------------------------------------------------------------------
# 0. Base del sistema
# ---------------------------------------------------------------------
titulo "0/6 Base del sistema"
sudo apt-get update
apt_instalar "Herramientas base" curl wget git ca-certificates gnupg apt-transport-https \
    software-properties-common unzip zip build-essential pkg-config flatpak
sudo flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo

# ---------------------------------------------------------------------
# 1. Programas de desarrollo
# ---------------------------------------------------------------------
titulo "1/6 Programas de desarrollo"

instalar_dotnet() {
    # 1) repos de Ubuntu  2) PPA de backports  3) script oficial de Microsoft
    sudo apt-get install -y dotnet-sdk-10.0 && return 0
    sudo add-apt-repository -y ppa:dotnet/backports && sudo apt-get update \
        && sudo apt-get install -y dotnet-sdk-10.0 && return 0
    curl -fsSL https://dot.net/v1/dotnet-install.sh -o /tmp/dotnet-install.sh \
        && bash /tmp/dotnet-install.sh --channel 10.0 --install-dir "$HOME/.dotnet"
}
paso ".NET SDK 10" instalar_dotnet

apt_instalar "JDK 17 y JDK 21 (OpenJDK)" openjdk-17-jdk openjdk-21-jdk
apt_instalar "CMake, Ninja, Clang/LLVM, gdb" cmake ninja-build clang lld lldb llvm gdb
# MSYS2 no hace falta en Linux: gcc/make ya vienen con build-essential.

instalar_vscode() {
    wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > /tmp/microsoft.gpg
    sudo install -D -o root -g root -m 644 /tmp/microsoft.gpg /usr/share/keyrings/microsoft.gpg
    sudo tee /etc/apt/sources.list.d/vscode.sources >/dev/null <<'EOF'
Types: deb
URIs: https://packages.microsoft.com/repos/code
Suites: stable
Components: main
Architectures: amd64,arm64,armhf
Signed-By: /usr/share/keyrings/microsoft.gpg
EOF
    sudo apt-get update
    sudo apt-get install -y code
}
paso "VS Code" instalar_vscode

instalar_node() {
    curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
    sudo apt-get install -y nodejs
}
paso "Node.js (LTS)" instalar_node

apt_instalar "Python 3 + venv + pipx + libs de Qt" python3 python3-venv python3-pip python3-dev pipx \
    libxcb-cursor0 libegl1 libxkbcommon-x11-0 ffmpeg

instalar_rust() {
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
}
paso "Rustup" instalar_rust

# Equivalente de XAMPP: Apache + PHP + MariaDB (se dejan sin arrancar solos, como XAMPP)
apt_instalar "PHP + Apache + MariaDB (equivale a XAMPP)" php php-cli php-mysql php-curl php-mbstring php-xml php-zip apache2 mariadb-server
sudo systemctl disable --now apache2 mariadb >/dev/null 2>&1 || true

flatpak_instalar "Blender" org.blender.Blender

instalar_unityhub() {
    wget -qO- https://hub.unity3d.com/linux/keys/public | gpg --dearmor | sudo tee /usr/share/keyrings/Unity_Technologies_ApS.gpg >/dev/null
    echo "deb [signed-by=/usr/share/keyrings/Unity_Technologies_ApS.gpg] https://hub.unity3d.com/linux/repos/deb stable main" \
        | sudo tee /etc/apt/sources.list.d/unityhub.list >/dev/null
    sudo apt-get update
    sudo apt-get install -y unityhub
}
paso "Unity Hub" instalar_unityhub

apt_instalar "VirtualBox" virtualbox
sudo usermod -aG vboxusers "$USER" 2>/dev/null || true

# ---------------------------------------------------------------------
# 2. Programas de uso diario / creativos (se saltan con --solo-desarrollo)
# ---------------------------------------------------------------------
if [ "$SOLO_DEV" -eq 0 ]; then
    titulo "2/6 Programas extra"
    instalar_brave() { curl -fsS https://dsl.brave.com/install.sh | sh; }
    paso "Brave" instalar_brave
    apt_instalar "Firefox" firefox
    apt_instalar "VLC" vlc
    apt_instalar "OBS Studio" obs-studio
    apt_instalar "Audacity" audacity
    apt_instalar "Reemplazo de WinRAR (7zip / rar / unrar)" p7zip-full p7zip-rar unrar file-roller
    flatpak_instalar "Zoom" us.zoom.Zoom
    # Sin version nativa para Linux -> alternativas:
    apt_instalar "Kdenlive (reemplazo de CapCut)" kdenlive
    apt_instalar "GIMP + Krita (reemplazo de Photoshop)" gimp krita
    apt_instalar "LMMS (reemplazo de FL Studio)" lmms
    # Intel Driver Assistant no existe en Linux: usa el "Administrador de controladores" de Mint.
else
    titulo "2/6 Programas extra: OMITIDO (--solo-desarrollo)"
fi

# ---------------------------------------------------------------------
# 3. Variables de entorno y PATH (se escriben en ~/.bashrc, sin duplicar)
# ---------------------------------------------------------------------
titulo "3/6 Variables de entorno"
configurar_entorno() {
    local rc="$HOME/.bashrc" jdk21
    jdk21="$(ls -d /usr/lib/jvm/java-21-openjdk-* 2>/dev/null | head -n1)"
    sed -i '/# >>> entorno-dev >>>/,/# <<< entorno-dev <<</d' "$rc"
    {
        echo '# >>> entorno-dev >>>'
        [ -n "$jdk21" ] && echo "export JAVA_HOME=\"$jdk21\""
        echo 'export ANDROID_HOME="$HOME/Android/android-sdk"'
        echo 'export ANDROID_SDK_ROOT="$ANDROID_HOME"'
        [ -d "$HOME/.dotnet" ] && echo 'export DOTNET_ROOT="$HOME/.dotnet"' && echo 'export PATH="$HOME/.dotnet:$HOME/.dotnet/tools:$PATH"'
        echo 'export PATH="$ANDROID_HOME/platform-tools:$ANDROID_HOME/emulator:$ANDROID_HOME/cmdline-tools/latest/bin:$HOME/.local/bin:$HOME/.cargo/bin:$HOME/.npm-global/bin:$PATH"'
        echo '# <<< entorno-dev <<<'
    } >> "$rc"
    echo "Variables escritas en $rc (abre una terminal nueva para que apliquen)"
}
paso "Variables de entorno en ~/.bashrc" configurar_entorno

# ---------------------------------------------------------------------
# 4. Android SDK (~/Android/android-sdk) - sin Android Studio, solo SDK
# ---------------------------------------------------------------------
titulo "4/6 Android SDK"
instalar_android_sdk() {
    local cmd="$SDK/cmdline-tools/latest"
    local sdkmanager="$cmd/bin/sdkmanager"
    if [ ! -x "$sdkmanager" ]; then
        # Si el enlace deja de funcionar, baja "Command line tools only" de
        # https://developer.android.com/studio#command-line-tools-only y
        # descomprimelo para que quede: ~/Android/android-sdk/cmdline-tools/latest/bin
        wget -q --show-progress -O /tmp/cmdline-tools.zip \
            https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip
        rm -rf /tmp/cmdline-tools-tmp
        unzip -q /tmp/cmdline-tools.zip -d /tmp/cmdline-tools-tmp
        mkdir -p "$SDK/cmdline-tools"
        rm -rf "$cmd"
        mv /tmp/cmdline-tools-tmp/cmdline-tools "$cmd"
    fi
    # sdkmanager necesita Java
    local j17; j17="$(ls -d /usr/lib/jvm/java-17-openjdk-* 2>/dev/null | head -n1)"
    [ -n "$j17" ] && export JAVA_HOME="$j17"

    yes | "$sdkmanager" --sdk_root="$SDK" --licenses >/dev/null || true
    "$sdkmanager" --sdk_root="$SDK" \
        'platform-tools' \
        'platforms;android-34' 'platforms;android-36' \
        'build-tools;34.0.0' 'build-tools;35.0.0' \
        'emulator' \
        'ndk;27.0.12077973' 'ndk;29.0.14206865' \
        'cmake;3.22.1' 'cmake;4.0.2' \
        'system-images;android-34;google_apis;x86_64'
}
paso "Android SDK (algun paquete de sdkmanager puede haber fallado)" instalar_android_sdk

# USB para adb (reglas udev) y aceleracion KVM para el emulador (equivale al Hypervisor de Windows)
apt_instalar "adb udev + KVM + libs del emulador" android-sdk-platform-tools-common cpu-checker libpulse0 libgl1 libnss3 libxkbfile1
sudo usermod -aG plugdev,kvm "$USER" 2>/dev/null || true
if command -v kvm-ok >/dev/null 2>&1 && ! kvm-ok >/dev/null 2>&1; then
    fallo "KVM no disponible: activa la virtualizacion (VT-x / AMD-V) en la BIOS"
fi

# ---------------------------------------------------------------------
# 5. Python, npm y extensiones de VS Code
# ---------------------------------------------------------------------
titulo "5/6 Python / npm / VS Code"
instalar_python() {
    # En Mint/Ubuntu 24.04 pip global esta bloqueado (PEP 668): se usa un venv en ~/.venvs/dev
    mkdir -p "$HOME/.venvs" "$HOME/.local/bin"
    [ -d "$HOME/.venvs/dev" ] || python3 -m venv "$HOME/.venvs/dev"
    "$HOME/.venvs/dev/bin/pip" install --upgrade pip
    # pywin32 se omite: solo existe en Windows
    "$HOME/.venvs/dev/bin/pip" install PySide6 pillow pyinstaller mcp yt-dlp requests \
        static-ffmpeg imageio-ffmpeg twine python-dotenv uvicorn
    for b in yt-dlp pyinstaller twine; do ln -sf "$HOME/.venvs/dev/bin/$b" "$HOME/.local/bin/$b"; done
    local mcp_server="$MCP_DIR/vscode-mcp/server"
    if [ -d "$mcp_server" ]; then
        "$HOME/.venvs/dev/bin/pip" install -e "$mcp_server"
    else
        echo "No existe $mcp_server : restaura Documents/MCP y ejecuta: ~/.venvs/dev/bin/pip install -e <esa ruta>"
    fi
}
paso "Paquetes de Python (venv ~/.venvs/dev)" instalar_python

instalar_npm_global() {
    npm config set prefix "$HOME/.npm-global"
    npm install -g '@vscode/vsce' 'rea-agents@6.4.0'
}
paso "npm global (vsce / rea-agents)" instalar_npm_global

if command -v code >/dev/null 2>&1; then
    EXT=(
        chadalen.vscode-jetbrains-icon-theme
        monokai.theme-monokai-pro-vscode
        ms-python.debugpy ms-python.python ms-python.vscode-pylance ms-python.vscode-python-envs
        redhat.java
        vscjava.vscode-gradle vscjava.vscode-java-debug vscjava.vscode-java-dependency
        vscjava.vscode-java-pack vscjava.vscode-java-test vscjava.vscode-maven
    )
    for e in "${EXT[@]}"; do
        code --install-extension "$e" --force >/dev/null 2>&1 && echo "extension: $e" || fallo "Extension de VS Code: $e"
    done
    VSIX="$(find "$MCP_DIR" -name '*.vsix' 2>/dev/null | head -n1)"
    if [ -n "$VSIX" ]; then
        code --install-extension "$VSIX" --force && echo "extension propia: $(basename "$VSIX")"
    else
        echo "No se encontro el .vsix de vscode-mcp-bridge. Regeneralo con 'vsce package' en su carpeta."
    fi
else
    fallo "Extensiones de VS Code (no se encontro el comando code)"
fi

# ---------------------------------------------------------------------
# 6. Ajustes de los proyectos + resumen
# ---------------------------------------------------------------------
titulo "Ajustes de los proyectos"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROY=""
for c in "$DESKTOP/proyectos" "$HOME/proyectos" "$HOME/Desktop/proyectos" "$(dirname "$SCRIPT_DIR")" "$SCRIPT_DIR"; do
    if [ -d "$c/drawengine" ]; then PROY="$c"; break; fi
done

if [ -z "$PROY" ]; then
    echo "No encontre la carpeta proyectos (con drawengine dentro). Restaurala y vuelve a ejecutar este script."
    fallo "Carpeta proyectos no encontrada (no se hizo el venv ni los ajustes)"
else
    echo "Proyectos en: $PROY"

    # a) Entorno virtual de drawengine (se filtran paquetes solo-Windows del requirements)
    ajustar_drawengine() {
        local venv="$PROY/drawengine/venv"
        rm -rf "$venv"
        python3 -m venv "$venv"
        "$venv/bin/pip" install --upgrade pip
        grep -viE '^(pywin32|pypiwin32|pywinauto|comtypes|wmi|winshell)' "$PROY/drawengine/requirements.txt" > /tmp/req-linux.txt
        "$venv/bin/pip" install -r /tmp/req-linux.txt
    }
    paso "venv de drawengine (revisa requirements.txt si falla)" ajustar_drawengine

    # b) gradlew ejecutable y con saltos de linea Unix; local.properties apuntando al SDK de Linux
    ajustar_gradle() {
        find "$PROY" -name gradlew -not -path '*/build/*' -print0 | while IFS= read -r -d '' g; do
            sed -i 's/\r$//' "$g"; chmod +x "$g"; echo "gradlew listo: $g"
        done
        find "$PROY" -name local.properties -not -path '*/build/*' -print0 | while IFS= read -r -d '' f; do
            if grep -q '^sdk.dir=' "$f"; then sed -i "s|^sdk.dir=.*|sdk.dir=$SDK|" "$f"; echo "sdk.dir ajustado en $f"; fi
        done
    }
    paso "Ajustes de gradlew / local.properties" ajustar_gradle
fi

# c0) uv + blender-mcp: deja blender-mcp en ~/.local/bin
instalar_blender_mcp() {
    curl -LsSf https://astral.sh/uv/install.sh | sh
    local bm="$MCP_DIR/blender-mcp"
    if [ ! -f "$bm/pyproject.toml" ]; then
        echo "No existe $bm : restaura Documents/MCP y ejecuta: uv tool install --force <esa carpeta>"
    else
        ( cd "$bm" && "$HOME/.local/bin/uv" tool install --force . )
    fi
}
paso "uv / blender-mcp" instalar_blender_mcp

# c) Emulador MeshCraftPhone (lo usaban los emulador.bat)
crear_avd() {
    local avdm="$SDK/cmdline-tools/latest/bin/avdmanager"
    if [ -x "$avdm" ] && [ ! -d "$HOME/.android/avd/MeshCraftPhone.avd" ]; then
        echo no | "$avdm" create avd -n MeshCraftPhone -k 'system-images;android-34;google_apis;x86_64' --device pixel_6 --force
    fi
}
paso "Crear el emulador MeshCraftPhone" crear_avd

titulo "6/6 Resumen"
if [ ${#FALLOS[@]} -eq 0 ]; then
    echo -e "\033[1;32mTodo se instalo sin errores.\033[0m"
else
    echo -e "\033[1;31mEsto fallo o hay que hacerlo a mano:\033[0m"
    for f in "${FALLOS[@]}"; do echo "  - $f"; done
fi

cat <<'EOF'

PENDIENTE A MANO (no se puede automatizar):
  - CERRAR SESION o reiniciar una vez: asi quedan activos el PATH y los grupos (kvm, plugdev, vboxusers).
  - Blender: instalar las extensiones desde Edit > Preferences > Get Extensions:
      Ant Landscape, Edit Mesh Tools, LoopTools, Node Tree Screenshot, Sapling Tree Gen, Draw Hair, Ucupaint
    y el addon del puente MCP de Blender (desde Documentos/MCP).
  - Restaurar tus carpetas: proyectos, Documentos/MCP y ~/.android/debug.keystore
  - Sin version para Linux: Photoshop, FL Studio, CapCut, Riot/Valorant, Enterprise Architect, MuseHub,
    VirtualTablet Server. Se instalaron alternativas (GIMP/Krita, LMMS, Kdenlive). FL Studio y
    Photoshop se pueden intentar con Wine/Bottles, sin garantias.
  - Drivers: Menu > Administrador de controladores (Mint los detecta solo).
  - Firewall (si activas ufw/gufw): sudo ufw allow from 192.168.0.0/16 to any port 8765 proto tcp
  - IMPORTANTE: el agente de Windows (windows-agent, net10.0-windows) NO corre en Linux. Ver instalacion-linux.md
EOF
