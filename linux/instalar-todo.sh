#!/usr/bin/env bash
# =====================================================================
# instalar-todo.sh  -  Reinstala el entorno de desarrollo en Linux Mint
# (equivalente de instalar-todo.ps1 + instalar-todo.bat de Windows)
#
# COMO USARLO (con internet):
#   Lo mas facil: ./instalar-todo-gui.sh  (ventana donde marcas lo que quieres instalar)
#
#   Desde terminal, COMO USUARIO NORMAL (no root; el script pide sudo solo):
#     chmod +x instalar-todo.sh
#     ./instalar-todo.sh                          -> instala TODO
#     ./instalar-todo.sh --solo-desarrollo        -> sin los programas extra (Brave, GIMP, OBS...)
#     ./instalar-todo.sh --solo=vscode,node,python
#                                                 -> SOLO esos componentes (mas la base del sistema).
#   Los nombres (ids) de los componentes estan en instalar-todo-gui.py (lista CATALOGO).
#
# Pensado para Linux Mint 22 (base Ubuntu 24.04). Al final muestra una
# lista de lo que fallo, para instalarlo a mano.
# =====================================================================

SOLO_DEV=0
SELECCION=""          # vacio = todo; si no, lista ",id1,id2," con lo elegido
for arg in "$@"; do
    case "$arg" in
        --solo-desarrollo) SOLO_DEV=1 ;;
        --solo=*)          SELECCION=",${arg#--solo=}," ;;
    esac
done

# quiero ID -> verdadero si ese componente esta elegido
quiero() {
    if [ -n "$SELECCION" ]; then
        case "$SELECCION" in *",$1,"*) return 0 ;; *) return 1 ;; esac
    fi
    case "$1" in
        brave|firefox|zoom|vlc|obs|audacity|kdenlive|gimp|lmms|archivos) [ "$SOLO_DEV" -eq 0 ] ;;
        *) return 0 ;;
    esac
}

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

# componente ID "Nombre" -> abre una seccion en el registro. Si lo lanza la interfaz grafica,
# tambien manda una marca (@@COMPONENTE) que usa para la barra de progreso.
componente() {
    if [ "${INSTALAR_TODO_GUI:-0}" = "1" ]; then echo "@@COMPONENTE $1"; fi
    titulo "$2"
}

# Modo interfaz grafica (instalar-todo-gui.py): si viene SUDO_ASKPASS, sudo pide la
# contrasena a ese programa en vez de la terminal. Se exporta la funcion para que tambien
# la usen los scripts que este llama (por ejemplo install.sh de vs-code-mcp).
if [ -n "${SUDO_ASKPASS:-}" ]; then
    sudo() { command sudo -A "$@"; }
    export -f sudo
fi

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
# Base del sistema (siempre se instala: lo demas la necesita)
# ---------------------------------------------------------------------
componente base "Base del sistema"
sudo apt-get update
apt_instalar "Herramientas base" curl wget ca-certificates gnupg apt-transport-https \
    software-properties-common unzip zip build-essential pkg-config flatpak
sudo flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo

# ---------------------------------------------------------------------
# Programas de desarrollo
# ---------------------------------------------------------------------
if quiero git; then
    componente git "Git"
    apt_instalar "Git" git
fi
if quiero dotnet; then
    componente dotnet ".NET SDK 10"
    instalar_dotnet() {
        # 1) repos de Ubuntu  2) PPA de backports  3) script oficial de Microsoft
        sudo apt-get install -y dotnet-sdk-10.0 && return 0
        sudo add-apt-repository -y ppa:dotnet/backports && sudo apt-get update \
            && sudo apt-get install -y dotnet-sdk-10.0 && return 0
        curl -fsSL https://dot.net/v1/dotnet-install.sh -o /tmp/dotnet-install.sh \
            && bash /tmp/dotnet-install.sh --channel 10.0 --install-dir "$HOME/.dotnet"
    }
    paso ".NET SDK 10" instalar_dotnet
fi

if quiero java; then
    componente java "Java (JDK 17 y 21)"
    apt_instalar "JDK 17 y JDK 21 (OpenJDK)" openjdk-17-jdk openjdk-21-jdk
fi

if quiero build; then
    componente build "Compiladores C/C++ (CMake, Ninja, Clang, gdb)"
    apt_instalar "CMake, Ninja, Clang/LLVM, gdb" cmake ninja-build clang lld lldb llvm gdb
    # MSYS2 no hace falta en Linux: gcc/make ya vienen con build-essential.
fi

if quiero vscode; then
    componente vscode "Visual Studio Code"
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
fi

# Claude Desktop (beta oficial para Linux, repositorio apt de Anthropic).
# Va ANTES del puente vscode-mcp, que lo registra en ~/.config/Claude.
if quiero claude; then
    componente claude "Claude Desktop (beta oficial)"
    instalar_claude_desktop() {
        if command -v claude-desktop >/dev/null 2>&1; then
            echo "Claude Desktop ya esta instalado"
        else
            sudo apt-get install -y curl gnupg
            sudo curl -fsSLo /usr/share/keyrings/claude-desktop-archive-keyring.asc \
                https://downloads.claude.ai/claude-desktop/key.asc
            # Comprueba que la clave descargada sea la de Anthropic (id ...BAA929FF1A7ECACE)
            if ! gpg --show-keys --with-colons /usr/share/keyrings/claude-desktop-archive-keyring.asc 2>/dev/null \
                    | grep -q 'BAA929FF1A7ECACE'; then
                echo "La clave descargada no coincide con la de Anthropic. Se cancela la instalacion."
                return 1
            fi
            echo "deb [arch=amd64,arm64 signed-by=/usr/share/keyrings/claude-desktop-archive-keyring.asc] https://downloads.claude.ai/claude-desktop/apt/stable stable main" \
                | sudo tee /etc/apt/sources.list.d/claude-desktop.list >/dev/null
            sudo apt-get update
            sudo apt-get install -y claude-desktop
        fi
        # Crea la carpeta de configuracion para que install.sh (vscode-mcp) pueda registrar el servidor
        # aunque Claude Desktop todavia no se haya abierto ni una vez.
        mkdir -p "$HOME/.config/Claude"
    }
    paso "Claude Desktop (beta oficial)" instalar_claude_desktop
fi

if quiero node; then
    componente node "Node.js (LTS) + npm"
    instalar_node() {
        curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
        sudo apt-get install -y nodejs
    }
    paso "Node.js (LTS)" instalar_node
fi

if quiero python; then
    componente python "Python 3 + entorno virtual"
    apt_instalar "Python 3 + venv + pipx + libs de Qt" python3 python3-venv python3-pip python3-dev pipx \
        libxcb-cursor0 libegl1 libxkbcommon-x11-0 ffmpeg
fi

if quiero rust; then
    componente rust "Rust (rustup)"
    instalar_rust() {
        curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
    }
    paso "Rustup" instalar_rust
fi

# Paquetes -dev (cabeceras) que cargo necesita para compilar apps con ventana, graficos y audio
# (las alternativas de ArtCraft: photocraft, wordcraft, etc.). Si una app pide otra libreria,
# el error de cargo dice cual es: agregala aqui.
if quiero rustlibs; then
    componente rustlibs "Librerias para compilar las apps Rust"
    apt_instalar "Librerias -dev para compilar apps Rust (ventanas, graficos, audio)" \
        libxkbcommon-dev libwayland-dev libx11-dev libxrandr-dev libxi-dev libxcursor-dev \
        libgl1-mesa-dev libgtk-3-dev libfontconfig1-dev libfreetype-dev libasound2-dev \
        libssl-dev libudev-dev
fi

# Equivalente de XAMPP: Apache + PHP + MariaDB (se dejan sin arrancar solos, como XAMPP)
if quiero xampp; then
    componente xampp "PHP + Apache + MariaDB (servidor web local)"
    apt_instalar "PHP + Apache + MariaDB (equivale a XAMPP)" php php-cli php-mysql php-curl php-mbstring php-xml php-zip apache2 mariadb-server
    sudo systemctl disable --now apache2 mariadb >/dev/null 2>&1 || true
fi

if quiero blender; then
    componente blender "Blender"
    flatpak_instalar "Blender" org.blender.Blender
fi

if quiero unity; then
    componente unity "Unity Hub"
    instalar_unityhub() {
        wget -qO- https://hub.unity3d.com/linux/keys/public | gpg --dearmor | sudo tee /usr/share/keyrings/Unity_Technologies_ApS.gpg >/dev/null
        # Si el paquete ya dejo su propio unityhub.sources, no se crea el .list (evita avisos de duplicado)
        if [ ! -f /etc/apt/sources.list.d/unityhub.sources ]; then
            echo "deb [signed-by=/usr/share/keyrings/Unity_Technologies_ApS.gpg] https://hub.unity3d.com/linux/repos/deb stable main" \
                | sudo tee /etc/apt/sources.list.d/unityhub.list >/dev/null
        fi
        sudo apt-get update
        sudo apt-get install -y unityhub
        if [ -f /etc/apt/sources.list.d/unityhub.sources ]; then
            sudo rm -f /etc/apt/sources.list.d/unityhub.list
        fi
    }
    paso "Unity Hub" instalar_unityhub
fi

# ---------------------------------------------------------------------
# Programas de uso diario / creativos (cada uno se elige por separado;
# con --solo-desarrollo se saltan todos)
# ---------------------------------------------------------------------
if quiero brave; then
    componente brave "Brave"
    instalar_brave() {
        if command -v brave-browser >/dev/null 2>&1; then echo "Brave ya esta instalado"; return 0; fi
        curl -fsS https://dsl.brave.com/install.sh | sh && return 0
        # Si la descarga falla (sin internet / DNS), se usa Flatpak
        sudo flatpak install -y --noninteractive flathub com.brave.Browser
    }
    paso "Brave" instalar_brave
fi
if quiero firefox; then
    componente firefox "Firefox"
    apt_instalar "Firefox" firefox
fi
if quiero zoom; then
    componente zoom "Zoom"
    flatpak_instalar "Zoom" us.zoom.Zoom
fi
if quiero vlc; then
    componente vlc "VLC"
    apt_instalar "VLC" vlc
fi
if quiero obs; then
    componente obs "OBS Studio"
    apt_instalar "OBS Studio" obs-studio
fi
if quiero audacity; then
    componente audacity "Audacity"
    apt_instalar "Audacity" audacity
fi
if quiero archivos; then
    componente archivos "Compresores (7zip / rar / unrar)"
    apt_instalar "Reemplazo de WinRAR (7zip / rar / unrar)" p7zip-full p7zip-rar unrar file-roller
fi
# Sin version nativa para Linux -> alternativas:
if quiero kdenlive; then
    componente kdenlive "Kdenlive (reemplazo de CapCut)"
    apt_instalar "Kdenlive (reemplazo de CapCut)" kdenlive
fi
if quiero gimp; then
    componente gimp "GIMP + Krita (reemplazo de Photoshop)"
    apt_instalar "GIMP + Krita (reemplazo de Photoshop)" gimp krita
fi
if quiero lmms; then
    componente lmms "LMMS (reemplazo de FL Studio)"
    apt_instalar "LMMS (reemplazo de FL Studio)" lmms
fi
# Intel Driver Assistant no existe en Linux: usa el "Administrador de controladores" de Mint.

# ---------------------------------------------------------------------
# Variables de entorno y PATH (se escriben en ~/.bashrc, sin duplicar)
# ---------------------------------------------------------------------
if quiero entorno; then
    componente entorno "Variables de entorno y PATH"
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
fi

# ---------------------------------------------------------------------
# Android SDK (~/Android/android-sdk) - sin Android Studio, solo SDK
# ---------------------------------------------------------------------
if quiero android; then
    componente android "Android SDK + emulador"
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
fi

# ---------------------------------------------------------------------
# Python (venv), npm y extensiones de VS Code
# ---------------------------------------------------------------------
if quiero python; then
    titulo "Python: paquetes en el venv ~/.venvs/dev"
    instalar_python() {
        # En Mint/Ubuntu 24.04 pip global esta bloqueado (PEP 668): se usa un venv en ~/.venvs/dev
        mkdir -p "$HOME/.venvs" "$HOME/.local/bin"
        [ -d "$HOME/.venvs/dev" ] || python3 -m venv "$HOME/.venvs/dev"
        "$HOME/.venvs/dev/bin/pip" install --upgrade pip
        # pywin32 se omite: solo existe en Windows
        # mcp<2: con mcp 2.x el servidor vscode-mcp no arranca (ya no existe mcp.server.fastmcp)
        "$HOME/.venvs/dev/bin/pip" install PySide6 pillow pyinstaller "mcp<2" yt-dlp requests \
            static-ffmpeg imageio-ffmpeg twine python-dotenv uvicorn
        for b in yt-dlp pyinstaller twine; do ln -sf "$HOME/.venvs/dev/bin/$b" "$HOME/.local/bin/$b"; done
        # El servidor vscode-mcp se instala mas abajo, con el install.sh de vs-code-mcp/linux.
    }
    paso "Paquetes de Python (venv ~/.venvs/dev)" instalar_python
fi

if quiero node; then
    titulo "Node.js: herramientas npm globales"
    instalar_npm_global() {
        npm config set prefix "$HOME/.npm-global"
        npm install -g '@vscode/vsce' 'rea-agents@6.4.0'
    }
    paso "npm global (vsce / rea-agents)" instalar_npm_global
fi

if quiero vscodeext; then
    componente vscodeext "Extensiones de VS Code"
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
        # La extension propia (vscode-mcp-bridge) se compila e instala mas abajo con el install.sh de vs-code-mcp/linux.
    else
        fallo "Extensiones de VS Code (no se encontro el comando code)"
    fi
fi

# ---------------------------------------------------------------------
# Proyectos de GitHub: se clonan en <Escritorio>/proyectos
# (va antes de los ajustes y de los puentes MCP, que buscan drawengine y vs-code-mcp ahi)
# ---------------------------------------------------------------------
# Si cambias esta lista, cambia tambien PROYECTOS_GH en instalar-todo-gui.py (el id es gh_<nombre>).
# Formato usuario/repo (en la ventana, el id de cada uno es gh_<repo>).
# Los de storytold son las alternativas open source del proyecto ArtCraft (solo se clona el codigo;
# se compilan a mano con cargo, ver el README de cada una).
GH_PROYECTOS=(
    norkles505/paintcraft norkles505/meshcraft norkles505/keyboardmovil norkles505/YTDownloader
    norkles505/ar-drawing norkles505/paintcraft-PC norkles505/drawengine norkles505/dont-cut-that
    norkles505/vs-code-mcp norkles505/nodo-capture norkles505/instalar-todo norkles505/dontcutthat
    storytold/photocraft storytold/vectorcraft storytold/filmcraft storytold/lightcraft
    storytold/pdfcraft storytold/effectcraft storytold/designcraft storytold/wordcraft
    storytold/soundcraft storytold/deckcraft storytold/cadcraft storytold/gridcraft
)
PROY_DIR="$DESKTOP/proyectos"

clonar_proyecto() {       # clonar_proyecto usuario/repo
    local repo="${1##*/}" destino="$PROY_DIR/${1##*/}"
    command -v git >/dev/null 2>&1 || { echo "git no esta instalado (marca tambien Git)."; return 1; }
    if [ -d "$destino/.git" ]; then
        echo "Ya esta descargado, no se toca: $destino"
        return 0
    fi
    if [ -e "$destino" ]; then
        echo "Ya existe $destino pero no es un repositorio git. No se toca."
        return 1
    fi
    # GIT_TERMINAL_PROMPT=0: si el repo es privado o no existe, falla en vez de quedarse pidiendo usuario
    GIT_TERMINAL_PROMPT=0 git clone "https://github.com/$1.git" "$destino"
}

hay_proyectos=0
for p in "${GH_PROYECTOS[@]}"; do
    if quiero "gh_${p##*/}"; then hay_proyectos=1; break; fi
done
if [ "$hay_proyectos" -eq 1 ]; then
    info "Creando la carpeta de proyectos: $PROY_DIR"
    mkdir -p "$PROY_DIR" || fallo "No se pudo crear la carpeta $PROY_DIR"
    for p in "${GH_PROYECTOS[@]}"; do
        if quiero "gh_${p##*/}"; then
            componente "gh_${p##*/}" "Proyecto de GitHub: $p"
            paso "Clonar $p" clonar_proyecto "$p"
        fi
    done
fi

# ---------------------------------------------------------------------
# Ajustes de los proyectos copiados de Windows
# ---------------------------------------------------------------------
if quiero ajustes; then
    componente ajustes "Preparar tus proyectos (copiados de Windows)"
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

        # Limpieza de cosas copiadas desde Windows que no sirven en Linux
        limpiar_copias_windows() {
            # node_modules de Windows: en .bin hay archivos normales sin permiso de ejecucion (tsc: Permission denied)
            find "$PROY" -type d -name node_modules -prune -print0 2>/dev/null | while IFS= read -r -d '' nm; do
                if [ -d "$nm/.bin" ] && [ -n "$(find "$nm/.bin" -mindepth 1 -maxdepth 1 -type f ! -perm -u+x 2>/dev/null | head -n1)" ]; then
                    echo "Borrando node_modules copiado de Windows: $nm"
                    rm -rf "$nm"
                fi
            done
            # venv de Windows: tienen Scripts/ en vez de bin/
            find "$PROY" -type f -name pyvenv.cfg -print0 2>/dev/null | while IFS= read -r -d '' cfg; do
                d="$(dirname "$cfg")"
                if [ -d "$d/Scripts" ] && [ ! -x "$d/bin/python" ]; then
                    echo "Borrando venv copiado de Windows: $d"
                    rm -rf "$d"
                fi
            done
        }
        paso "Limpiar node_modules / venv copiados de Windows" limpiar_copias_windows

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
fi

# ---------------------------------------------------------------------
# Puentes MCP
# ---------------------------------------------------------------------
# uv + blender-mcp: deja blender-mcp en ~/.local/bin
if quiero blendermcp; then
    componente blendermcp "Puente blender-mcp (uv)"
    instalar_blender_mcp() {
        curl -LsSf https://astral.sh/uv/install.sh | sh
        local bm
        # Busca blender-mcp en Documentos/MCP o en proyectos (prefiere la subcarpeta linux/ si existe)
        bm="$(find "$MCP_DIR" "$DESKTOP/proyectos" -maxdepth 4 -type d -path '*blender-mcp/linux' 2>/dev/null | head -n1)"
        if [ -z "$bm" ]; then
            bm="$(find "$MCP_DIR" "$DESKTOP/proyectos" -maxdepth 3 -type d -name blender-mcp 2>/dev/null | head -n1)"
        fi
        if [ -z "$bm" ] || [ ! -f "$bm/pyproject.toml" ]; then
            echo "No encontre la carpeta blender-mcp (con pyproject.toml). Copiala y ejecuta: uv tool install --force <esa carpeta>"
        else
            ( cd "$bm" && "$HOME/.local/bin/uv" tool install --force . )
        fi
    }
    paso "uv / blender-mcp" instalar_blender_mcp
fi

# Puente vscode-mcp: extension de VS Code + servidor MCP + registro en Claude Desktop
if quiero vscodemcp; then
    componente vscodemcp "Puente vscode-mcp (extension + servidor)"
    instalar_vscode_mcp() {
        local d="" c
        local SD; SD="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
        for c in "$DESKTOP/proyectos/vs-code-mcp/linux" "$HOME/proyectos/vs-code-mcp/linux" \
                 "$(dirname "$(dirname "$SD")")/vs-code-mcp/linux" "$MCP_DIR/vscode-mcp/linux" "$MCP_DIR/vscode-mcp"; do
            if [ -f "$c/install.sh" ] && [ -d "$c/extension" ] && [ -d "$c/server" ]; then d="$c"; break; fi
        done
        if [ -z "$d" ]; then
            local f
            f="$(find "$DESKTOP/proyectos" -maxdepth 4 -path '*vs-code-mcp/linux/install.sh' 2>/dev/null | head -n1)"
            if [ -n "$f" ]; then d="$(dirname "$f")"; fi
        fi
        if [ -z "$d" ]; then
            echo "No encontre vs-code-mcp/linux (con install.sh). Copia esa carpeta y ejecuta ./install.sh dentro de ella."
            return 0
        fi
        echo "Instalando vscode-mcp desde: $d"
        bash "$d/install.sh"
    }
    paso "Puente vscode-mcp (extension + servidor + config de Claude Desktop)" instalar_vscode_mcp
fi

# Emulador MeshCraftPhone (lo usaban los emulador.bat)
if quiero avd; then
    componente avd "Emulador MeshCraftPhone"
    crear_avd() {
        local avdm="$SDK/cmdline-tools/latest/bin/avdmanager"
        if [ -x "$avdm" ] && [ ! -d "$HOME/.android/avd/MeshCraftPhone.avd" ]; then
            echo no | "$avdm" create avd -n MeshCraftPhone -k 'system-images;android-34;google_apis;x86_64' --device pixel_6 --force
        fi
    }
    paso "Crear el emulador MeshCraftPhone" crear_avd
fi

# ---------------------------------------------------------------------
# Resumen
# ---------------------------------------------------------------------
titulo "Resumen"
if [ ${#FALLOS[@]} -eq 0 ]; then
    echo -e "\033[1;32mTodo se instalo sin errores.\033[0m"
else
    echo -e "\033[1;31mEsto fallo o hay que hacerlo a mano:\033[0m"
    for f in "${FALLOS[@]}"; do echo "  - $f"; done
fi

echo
echo "PENDIENTE A MANO (no se puede automatizar):"
echo "  - CERRAR SESION o reiniciar una vez: asi quedan activos el PATH y los grupos (kvm, plugdev)."
if quiero claude; then
    echo "  - Claude Desktop: abrelo (menu o comando 'claude-desktop') e inicia sesion con tu cuenta."
    echo "    Se actualiza con: sudo apt update && sudo apt upgrade (no se actualiza solo en Linux)."
fi
if quiero vscodemcp; then
    echo "  - Puente vscode-mcp: cierra y abre VS Code (debe aparecer MCP:9877 abajo) y cierra por completo"
    echo "    Claude Desktop y abrelo de nuevo para que cargue el puente."
fi
if quiero blender; then
    cat <<'FIN'
  - Blender: instalar las extensiones desde Edit > Preferences > Get Extensions:
      Ant Landscape, Edit Mesh Tools, LoopTools, Node Tree Screenshot, Sapling Tree Gen, Draw Hair, Ucupaint
    y el addon del puente MCP de Blender (desde Documentos/MCP).
FIN
fi
cat <<'FIN'
  - Restaurar tus carpetas: proyectos, Documentos/MCP y ~/.android/debug.keystore
  - Sin version para Linux: Photoshop, FL Studio, CapCut, Riot/Valorant, Enterprise Architect, MuseHub,
    VirtualTablet Server. Hay alternativas (GIMP/Krita, LMMS, Kdenlive). FL Studio y
    Photoshop se pueden intentar con Wine/Bottles, sin garantias.
  - Drivers: Menu > Administrador de controladores (Mint los detecta solo).
  - Firewall (si activas ufw/gufw): sudo ufw allow from 192.168.0.0/16 to any port 8765 proto tcp
  - IMPORTANTE: el agente de Windows (windows-agent, net10.0-windows) NO corre en Linux. Ver instalacion-linux.md
FIN
