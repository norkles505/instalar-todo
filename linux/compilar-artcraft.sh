#!/usr/bin/env bash
# compilar-artcraft.sh - Compila una app de ArtCraft (cargo build --release) y deja listo:
#   - un enlace en ~/.local/bin (para abrirla desde la terminal)
#   - una entrada en el menu de aplicaciones (~/.local/share/applications)
#   - un acceso directo en el Escritorio
# Opcional: la registra para abrir sus tipos de archivo.
# Lo llama actualizar-artcraft.sh (boton «Actualizar ArtCraft» de la ventana), pero tambien
# se puede usar solo.
#
# USO:  ./compilar-artcraft.sh --ruta <carpeta> [--repo <app>] [--asociar] [--solo-acceso]
#   --ruta         carpeta donde esta clonada la app (la que tiene Cargo.toml)
#   --repo         nombre del repo (wordcraft, photocraft...). Si falta, se usa el nombre de la carpeta
#   --asociar      ademas registra la app como opcion de «Abrir con» para sus tipos de archivo
#                  (tabla MIMES de abajo). No la pone como predeterminada: eso lo eliges tu una vez
#                  (clic derecho en un archivo > Abrir con > Elegir otra aplicacion > Recordar).
#   --solo-acceso  no compila: solo crea o renueva el enlace y los accesos directos
#
# El binario se descubre con «cargo metadata», asi que no importa como se llame.
# Necesita Rust (rustup) y python3 (para leer cargo metadata).

set -u

[ -f "$HOME/.cargo/env" ] && . "$HOME/.cargo/env"
export CARGO_TERM_COLOR=never CARGO_TERM_PROGRESS_WHEN=never

RUTA=""; REPO=""; ASOCIAR=0; SOLO_ACCESO=0
while [ $# -gt 0 ]; do
  case "$1" in
    --ruta)        RUTA="${2:-}"; shift; [ $# -gt 0 ] && shift ;;
    --repo)        REPO="${2:-}"; shift; [ $# -gt 0 ] && shift ;;
    --asociar)     ASOCIAR=1; shift ;;
    --solo-acceso) SOLO_ACCESO=1; shift ;;
    *) echo "!! Opcion desconocida: $1"; exit 2 ;;
  esac
done

if [ -z "$RUTA" ] || [ ! -d "$RUTA" ]; then
  echo "!! Falta --ruta o la carpeta no existe."
  exit 2
fi
RUTA=$(cd "$RUTA" && pwd)
[ -n "$REPO" ] || REPO=$(basename "$RUTA")
CLAVE="${REPO,,}"

# Nombre que lleva el acceso directo y tipos de archivo (MIME) que abre cada app.
# Las extensiones son una suposicion segun lo que hace cada app (las mismas que en Windows):
# ajusta la tabla si hace falta. Sin entrada en MIMES = esa app no se registra para ningun tipo.
declare -A NOMBRE=(
  [photocraft]="PhotoCraft"   [vectorcraft]="VectorCraft"   [filmcraft]="FilmCraft"
  [lightcraft]="LightCraft"   [pdfcraft]="PdfCraft"         [effectcraft]="EffectCraft"
  [designcraft]="DesignCraft" [wordcraft]="WordCraft"       [soundcraft]="SoundCraft"
  [deckcraft]="DeckCraft"     [cadcraft]="CADCraft"         [gridcraft]="GridCraft"
  [figcraft]="FigCraft"       [texturecraft]="TextureCraft" [materialcraft]="MaterialCraft"
  [craft-anything]="Craft Anything"
)
declare -A MIMES=(
  [photocraft]="image/vnd.adobe.photoshop"                                    # .psd
  [vectorcraft]="image/svg+xml"                                               # .svg
  [lightcraft]="image/x-canon-cr2;image/x-nikon-nef;image/x-sony-arw;image/x-adobe-dng"
  [pdfcraft]="application/pdf"                                                # .pdf
  [wordcraft]="application/vnd.openxmlformats-officedocument.wordprocessingml.document"      # .docx
  [deckcraft]="application/vnd.openxmlformats-officedocument.presentationml.presentation"    # .pptx
  [gridcraft]="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"            # .xlsx
  [cadcraft]="image/vnd.dxf;image/vnd.dwg"                                    # .dxf .dwg
)
NOMBRE_APP="${NOMBRE[$CLAVE]:-$REPO}"

if [ ! -f "$RUTA/Cargo.toml" ]; then
  echo ">> $REPO no tiene Cargo.toml: no hay nada que compilar."
  exit 0
fi
if ! command -v cargo >/dev/null 2>&1; then
  echo '!! No encuentro cargo. Instala «Rust (rustup)» desde la lista y vuelve a intentar.'
  exit 1
fi

# ---- compilar
if [ "$SOLO_ACCESO" -eq 0 ]; then
  echo ">> cargo build --release (puede tardar varios minutos)"
  if ! (cd "$RUTA" && cargo build --release); then
    echo "!! La compilacion fallo en $REPO"
    exit 1
  fi
fi

# ---- buscar el binario que genero la app
if ! command -v python3 >/dev/null 2>&1; then
  echo "!! No encuentro python3 para leer cargo metadata: $REPO no tiene acceso directo."
  exit 0
fi
INFO=$(cd "$RUTA" && cargo metadata --no-deps --format-version 1 2>/dev/null | python3 -c '
import json, os, re, sys
repo, ruta = sys.argv[1], sys.argv[2]
raiz = os.path.realpath(os.path.join(ruta, "Cargo.toml"))
try:
    m = json.load(sys.stdin)
except Exception:
    sys.exit(1)
norm = lambda s: re.sub(r"[-_ ]", "", s).lower()
bins = []
for p in m["packages"]:
    for t in p["targets"]:
        if "bin" in t["kind"]:
            bins.append((t["name"], os.path.realpath(p["manifest_path"]) == raiz))
if not bins:
    print("LIB")
    sys.exit(0)
# Prioridad: el binario que se llama como la app; si solo hay uno, ese; el del paquete raiz; el primero
pick = [b for b in bins if norm(b[0]) == norm(repo)]
if not pick and len(bins) == 1:
    pick = bins
if not pick:
    pick = [b for b in bins if b[1]]
if not pick:
    pick = bins[:1]
print(pick[0][0] + "|" + m["target_directory"])
' "$REPO" "$RUTA")

if [ -z "$INFO" ]; then
  echo "!! No pude leer los datos del proyecto con cargo metadata: $REPO no tiene acceso directo."
  exit 0
fi
if [ "$INFO" = "LIB" ]; then
  echo ">> $REPO no genera ningun programa (es una libreria): sin acceso directo."
  exit 0
fi
BIN_NOMBRE="${INFO%%|*}"
TARGET_DIR="${INFO#*|}"
EXE="$TARGET_DIR/release/$BIN_NOMBRE"
if [ ! -x "$EXE" ]; then
  echo "!! No encuentro $EXE : compila la app primero (sin --solo-acceso)."
  exit 1
fi

# ---- enlace en ~/.local/bin
mkdir -p "$HOME/.local/bin"
DESTINO="$HOME/.local/bin/$BIN_NOMBRE"
if [ -e "$DESTINO" ] && [ ! -L "$DESTINO" ]; then
  echo "!! Ya existe $DESTINO y no es un enlace: no lo toco."
else
  ln -sfn "$EXE" "$DESTINO"
  echo ">> Enlace: $DESTINO"
fi

# ---- icono: el primero que se encuentre en el repo; si no, uno generico del sistema
ICONO=""
for c in "$RUTA"/packaging/linux/*.png "$RUTA"/packaging/linux/*.svg \
         "$RUTA"/assets/icon.png "$RUTA"/assets/icons/*.png "$RUTA"/icon.png; do
  [ -f "$c" ] && { ICONO="$c"; break; }
done
[ -n "$ICONO" ] || ICONO="application-x-executable"

# ---- entrada del menu de aplicaciones
APPS_DIR="$HOME/.local/share/applications"
mkdir -p "$APPS_DIR"
ENTRADA="$APPS_DIR/artcraft-$CLAVE.desktop"

# Tipos de archivo: solo con --asociar. Si antes se asociaron y ahora no se pide, se conservan
# (renovar el acceso directo no debe deshacer la asociacion).
LINEA_MIME=""
EXEC_LINEA="Exec=\"$EXE\""
if [ "$ASOCIAR" -eq 1 ]; then
  if [ -n "${MIMES[$CLAVE]:-}" ]; then
    LINEA_MIME="MimeType=${MIMES[$CLAVE]};"
  else
    echo ">> $NOMBRE_APP no tiene tipos de archivo definidos en la tabla: no se registra nada."
  fi
elif [ -f "$ENTRADA" ]; then
  LINEA_MIME=$(grep '^MimeType=' "$ENTRADA" 2>/dev/null | head -n1)
fi
[ -n "$LINEA_MIME" ] && EXEC_LINEA="Exec=\"$EXE\" %F"

{
  echo "[Desktop Entry]"
  echo "Type=Application"
  echo "Name=$NOMBRE_APP"
  echo "Comment=$NOMBRE_APP (ArtCraft)"
  echo "$EXEC_LINEA"
  echo "Path=$RUTA"
  echo "Icon=$ICONO"
  echo "Terminal=false"
  echo "Categories=Graphics;Office;"
  echo "StartupNotify=true"
  [ -n "$LINEA_MIME" ] && echo "$LINEA_MIME"
} > "$ENTRADA"
echo ">> Menu de aplicaciones: $ENTRADA"

if [ "$ASOCIAR" -eq 1 ] && [ -n "$LINEA_MIME" ]; then
  command -v update-desktop-database >/dev/null 2>&1 && update-desktop-database "$APPS_DIR" 2>/dev/null
  echo ">> $NOMBRE_APP aparece en «Abrir con» para sus tipos de archivo."
  echo ">> Para que sea la predeterminada: clic derecho en un archivo > Abrir con > Elegir otra aplicacion > Recordar."
fi

# ---- acceso directo en el Escritorio
ESC=$(xdg-user-dir DESKTOP 2>/dev/null); [ -n "$ESC" ] || ESC="$HOME/Desktop"
if [ -d "$ESC" ]; then
  ACCESO="$ESC/$NOMBRE_APP.desktop"
  if cp -f "$ENTRADA" "$ACCESO" 2>/dev/null; then
    chmod +x "$ACCESO"
    # En GNOME hay que marcarlo como de confianza para que se pueda abrir con doble clic
    command -v gio >/dev/null 2>&1 && gio set "$ACCESO" metadata::trusted true 2>/dev/null
    echo ">> Acceso directo: $ACCESO"
  else
    echo "!! No pude crear el acceso directo en $ESC"
  fi
else
  echo ">> No encuentro la carpeta del Escritorio ($ESC): solo se creo la entrada del menu."
fi
exit 0
