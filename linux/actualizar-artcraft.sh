#!/usr/bin/env bash
# actualizar-artcraft.sh - Actualiza (git pull) y recompila las alternativas de ArtCraft que ya
# tienes clonadas, esten en la carpeta que esten.
#
# Si la carpeta de la app tiene al lado actualizar.sh y compilar.sh (como Documentos/programas),
# usa esos scripts: asi se compila con «cargo build -p <app>», se anota .estado y se renuevan el
# enlace de ~/.local/bin, el acceso directo, los iconos y los tipos de archivo. Para el resto de
# apps hace git pull + cargo build --release.
#
# Para el resto de apps, compila con compilar-artcraft.sh (al lado de este): cargo build --release
# y deja el enlace en ~/.local/bin, la entrada del menu y el acceso directo del Escritorio.
#
# USO:  ./actualizar-artcraft.sh [--asociar] [app=ruta ...]
#   Sin argumentos: busca en programas, proyectos, el Escritorio, Documentos y tu carpeta personal
#   todos los repositorios cuyo origen sea github.com/storytold/<app> y los actualiza.
#   Con «app=ruta» (como hace la ventana): actualiza justo esas rutas.
#   Con solo «app»: la busca por su origen en git.
#   --asociar: ademas registra cada app en «Abrir con» para sus tipos de archivo.
# La ventana (instalar-todo-gui.py) lo llama con el boton «Actualizar ArtCraft».

set -u

[ -f "$HOME/.cargo/env" ] && . "$HOME/.cargo/env"
export CARGO_TERM_COLOR=never CARGO_TERM_PROGRESS_WHEN=never GIT_TERMINAL_PROMPT=0

escritorio() {
  local d
  d=$(xdg-user-dir DESKTOP 2>/dev/null)
  [ -n "$d" ] && echo "$d" || echo "$HOME/Desktop"
}

ESC=$(escritorio)
DOCS=$(xdg-user-dir DOCUMENTS 2>/dev/null); [ -n "$DOCS" ] || DOCS="$HOME/Documents"
BUSCAR=("$ESC/programas" "$ESC/proyectos" "$ESC" "$DOCS/programas" "$DOCS" "$HOME")
# Carpetas elegidas en la ventana (INSTALAR_TODO_PROG / INSTALAR_TODO_PROY), si las hay: se buscan primero
[ -n "${INSTALAR_TODO_PROY:-}" ] && BUSCAR=("$INSTALAR_TODO_PROY" "${BUSCAR[@]}")
[ -n "${INSTALAR_TODO_PROG:-}" ] && BUSCAR=("$INSTALAR_TODO_PROG" "${BUSCAR[@]}")

# origen_artcraft <carpeta>: imprime el nombre de la app si su origen es storytold/<app>
origen_artcraft() {
  local url
  url=$(git -C "$1" remote get-url origin 2>/dev/null) || return 1
  if [[ "$url" =~ storytold/([^/]+)/?$ ]]; then
    local r="${BASH_REMATCH[1]}"
    echo "${r%.git}"
    return 0
  fi
  return 1
}

# localizar <app>: imprime la ruta donde esta clonada la app, reconocida por su origen en git
localizar() {
  local repo="$1" base d
  # Solo cuenta el origen en git (storytold/<app>); el nombre de la carpeta no basta
  for base in "${BUSCAR[@]}"; do
    for d in "$base"/*/; do
      [ -d "${d}.git" ] || continue
      [ "$(origen_artcraft "$d")" = "$repo" ] && { echo "${d%/}"; return 0; }
    done
  done
  return 1
}

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

# Opciones: --asociar (el resto de argumentos son apps)
ASOCIAR=0
ITEMS=()
for arg in "$@"; do
  if [ "$arg" = "--asociar" ]; then ASOCIAR=1; else ITEMS+=("$arg"); fi
done

# compilar_app <app> <ruta> <solo_acceso 0|1>: compila con compilar-artcraft.sh (deja enlace, menu
# y acceso directo). Con solo_acceso=1 no compila: solo renueva el acceso directo.
compilar_app() {
  local c="$SCRIPT_DIR/compilar-artcraft.sh"
  local a=(--ruta "$2" --repo "$1")
  [ "$ASOCIAR" -eq 1 ] && a+=(--asociar)
  if [ -f "$c" ]; then
    [ "$3" -eq 1 ] && a+=(--solo-acceso)
    bash "$c" "${a[@]}"
    return $?
  fi
  # Sin compilar-artcraft.sh al lado: solo cargo, sin acceso directo
  [ "$3" -eq 1 ] && return 0
  echo ">> cargo build --release (puede tardar varios minutos)"
  (cd "$2" && cargo build --release)
}

# Sin argumentos: descubre todas las apps de storytold que haya clonadas
if [ ${#ITEMS[@]} -eq 0 ]; then
  declare -A VISTO=()
  for base in "${BUSCAR[@]}"; do
    for d in "$base"/*/; do
      [ -d "${d}.git" ] || continue
      r=$(origen_artcraft "$d") || continue
      [ -n "${VISTO[$r]:-}" ] && continue
      VISTO[$r]=1
      ITEMS+=("$r=${d%/}")
    done
  done
fi

if [ ${#ITEMS[@]} -eq 0 ]; then
  echo "!! No encontré ninguna app de ArtCraft clonada (busqué en programas, proyectos, Escritorio, Documentos/programas y tu carpeta personal)."
  exit 1
fi

if ! command -v cargo >/dev/null 2>&1; then
  echo "!! No encuentro cargo. Instala «Rust (rustup)» desde la lista y vuelve a intentar."
  exit 1
fi

ACTUALIZADAS=(); SIN_CAMBIOS=(); FALLOS=()

for item in "${ITEMS[@]}"; do
  if [[ "$item" == *=* ]]; then
    repo="${item%%=*}"; ruta="${item#*=}"
  else
    repo="$item"; ruta=$(localizar "$repo") || ruta=""
  fi

  echo "@@COMPONENTE gh_$repo"
  echo "=== $repo ==="
  if [ -z "$ruta" ] || [ ! -d "$ruta/.git" ]; then
    echo "!! No encuentro $repo clonado en ninguna carpeta"
    FALLOS+=("$repo: no está clonado")
    continue
  fi
  # Seguridad: nunca tocar una carpeta cuyo origen no sea storytold/<repo>
  if [ "$(origen_artcraft "$ruta")" != "$repo" ]; then
    echo "!! $ruta no viene de github.com/storytold/$repo: no la toco"
    FALLOS+=("$repo: la carpeta no es de ArtCraft (origen distinto)")
    continue
  fi
  echo ">> Carpeta: $ruta"

  # --- Caso 1: la carpeta tiene sus propios actualizar.sh y compilar.sh (p. ej. Documentos/programas)
  padre=$(dirname "$ruta")
  if [ "$(basename "$ruta")" = "$repo" ] && [ -f "$padre/actualizar.sh" ] && [ -f "$padre/compilar.sh" ] \
     && [ -f "$ruta/Cargo.toml" ] && [ -f "$ruta/packaging/linux/ai.storyteller.$repo.desktop" ]; then
    echo ">> Uso actualizar.sh y compilar.sh de $padre"
    antes=$(git -C "$ruta" rev-parse HEAD 2>/dev/null)
    echo ">> actualizar.sh $repo"
    if ! bash "$padre/actualizar.sh" "$repo"; then
      echo "!! actualizar.sh falló en $repo (¿cambios locales o sin internet?)"
      FALLOS+=("$repo: git pull falló")
      continue
    fi
    despues=$(git -C "$ruta" rev-parse HEAD 2>/dev/null)
    # --sin-asociar: no cambia tus programas predeterminados en cada actualización
    # (si se pidió --asociar en este script, compilar.sh sí los registra)
    if [ "$ASOCIAR" -eq 1 ]; then
      echo ">> compilar.sh $repo"
      bash "$padre/compilar.sh" "$repo"
    else
      echo ">> compilar.sh --sin-asociar $repo"
      bash "$padre/compilar.sh" --sin-asociar "$repo"
    fi
    if [ $? -ne 0 ]; then
      echo "!! compilar.sh falló en $repo"
      FALLOS+=("$repo: la compilación falló (mira el error de arriba; puede faltar una librería)")
      continue
    fi
    if [ "$antes" = "$despues" ]; then SIN_CAMBIOS+=("$repo"); else ACTUALIZADAS+=("$repo"); fi
    continue
  fi

  # --- Caso 2: carpeta sin esos scripts: git pull + cargo build --release
  cd "$ruta" || { FALLOS+=("$repo: no se pudo entrar a la carpeta"); continue; }

  antes=$(git rev-parse HEAD 2>/dev/null)
  echo ">> git pull"
  if ! git pull --ff-only; then
    echo "!! git pull falló en $repo (¿cambios locales o sin internet?)"
    FALLOS+=("$repo: git pull falló")
    continue
  fi
  despues=$(git rev-parse HEAD 2>/dev/null)

  if [ ! -f Cargo.toml ]; then
    echo ">> $repo no tiene Cargo.toml: solo se actualizó el código."
    ACTUALIZADAS+=("$repo")
    continue
  fi

  # Si no hubo cambios y ya esta compilado, no se gasta tiempo recompilando
  # (solo se renueva el acceso directo, por si se borro o la app es anterior a esta funcion)
  if [ "$antes" = "$despues" ] && [ -d target/release ]; then
    echo ">> Ya estaba al día."
    compilar_app "$repo" "$ruta" 1
    SIN_CAMBIOS+=("$repo")
    continue
  fi

  if compilar_app "$repo" "$ruta" 0; then
    ACTUALIZADAS+=("$repo")
  else
    echo "!! La compilación falló en $repo"
    FALLOS+=("$repo: cargo build falló (mira el error de arriba; puede faltar una librería)")
  fi
done

echo
echo "=== Resumen ==="
echo "Actualizadas y compiladas: ${ACTUALIZADAS[*]:-ninguna}"
echo "Sin cambios nuevos:        ${SIN_CAMBIOS[*]:-ninguna}"

if [ ${#FALLOS[@]} -gt 0 ]; then
  echo
  echo "Esto fallo o hay que hacerlo a mano:"
  for f in "${FALLOS[@]}"; do echo "  - $f"; done
  exit 1
fi
echo "Todo se actualizo sin errores"
