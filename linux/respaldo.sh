#!/usr/bin/env bash
# =====================================================================
# respaldo.sh  -  Guarda y restaura tus configuraciones personales
# (para usarlo ANTES de formatear y DESPUES de correr instalar-todo.sh)
#
#   ./respaldo.sh respaldar DESTINO [--con-proyectos]
#       Crea DESTINO/respaldo-AAAA-MM-DD_HHMM.tar.gz. DESTINO debe ser un disco/USB
#       externo o una carpeta que luego copies fuera de este disco: si lo dejas en el
#       disco que vas a formatear, el respaldo se pierde con el.
#       Solo LEE y copia: no modifica ni borra nada de tu sistema.
#
#   ./respaldo.sh restaurar ARCHIVO.tar.gz
#       Devuelve todo a su sitio. Si un archivo ya existe y es distinto, el actual NO se
#       pierde: queda guardado como archivo.~1~ junto al restaurado.
#
# Que guarda: .bashrc, .profile, .gitconfig, claves SSH (~/.ssh), claves GPG (~/.gnupg),
# ~/.android/debug.keystore, ajustes/atajos/snippets de VS Code, la lista de extensiones de
# VS Code, la config de Claude Desktop (claude_desktop_config.json) y Documentos/MCP.
# Con --con-proyectos tambien guarda <Escritorio>/proyectos (sin node_modules, target, venv,
# .venv, __pycache__ ni .gradle: esas carpetas se regeneran).
#
# OJO: el respaldo contiene tus claves privadas SSH/GPG. Guardalo en un lugar de confianza.
# =====================================================================
set -u

DESKTOP="$(xdg-user-dir DESKTOP 2>/dev/null || echo "$HOME/Desktop")"
DOCS="$(xdg-user-dir DOCUMENTS 2>/dev/null || echo "$HOME/Documents")"

# Rutas relativas a $HOME
ITEMS=(
    .bashrc .profile .gitconfig .ssh .gnupg .android/debug.keystore
    .config/Code/User/settings.json .config/Code/User/keybindings.json .config/Code/User/snippets
    .config/Claude/claude_desktop_config.json
)

uso() {
    sed -n '3,12p' "$0" | sed 's/^# \{0,1\}//'
}

respaldar() {
    local destino="" con_proy=0 a
    for a in "$@"; do
        case "$a" in
            --con-proyectos) con_proy=1 ;;
            -*) echo "Opcion desconocida: $a"; uso; return 1 ;;
            *)  destino="$a" ;;
        esac
    done
    if [ -z "$destino" ]; then
        echo "Falta el DESTINO (por ejemplo la carpeta de tu USB)."
        uso; return 1
    fi
    mkdir -p "$destino" || { echo "No pude crear $destino"; return 1; }

    if [ "$(df --output=source "$destino" 2>/dev/null | tail -n1)" = "$(df --output=source "$HOME" 2>/dev/null | tail -n1)" ]; then
        echo "AVISO: ese destino esta en el mismo disco que tu carpeta personal."
        echo "       Si formateas ese disco, el respaldo se pierde. Copialo a un USB o a la nube despues."
    fi

    local tmp rel n=0
    tmp="$(mktemp -d)" || return 1
    trap 'rm -rf "$tmp"' RETURN
    mkdir -p "$tmp/home" "$tmp/meta"

    echo "Copiando configuraciones..."
    for rel in "${ITEMS[@]}"; do
        if [ -e "$HOME/$rel" ]; then
            mkdir -p "$tmp/home/$(dirname "$rel")"
            if cp -a "$HOME/$rel" "$tmp/home/$rel" 2>/dev/null; then
                echo "  + $rel"; n=$((n + 1))
            else
                echo "  ! No pude copiar $rel (se omite)"
            fi
        fi
    done
    # Sockets (p. ej. de gpg-agent) no se pueden guardar ni hace falta
    find "$tmp/home" -type s -delete 2>/dev/null

    if command -v code >/dev/null 2>&1; then
        code --list-extensions > "$tmp/meta/extensiones-vscode.txt" 2>/dev/null \
            && echo "  + lista de extensiones de VS Code"
    fi
    date > "$tmp/meta/fecha.txt"

    local archivo
    archivo="$destino/respaldo-$(date +%Y-%m-%d_%H%M).tar.gz"
    local args=(--exclude=node_modules --exclude=target --exclude=venv --exclude=.venv
                --exclude=__pycache__ --exclude=.gradle
                --transform='s,^MCP,documentos/MCP,')
    local rutas=(-C "$tmp" home meta)
    if [ -d "$DOCS/MCP" ]; then rutas+=(-C "$DOCS" MCP); echo "  + Documentos/MCP"; fi
    if [ "$con_proy" -eq 1 ] && [ -d "$DESKTOP/proyectos" ]; then
        rutas+=(-C "$DESKTOP" proyectos); echo "  + proyectos (puede tardar)"
    fi

    if tar -czf "$archivo" "${args[@]}" "${rutas[@]}"; then
        chmod 600 "$archivo"
        echo
        echo "Listo: $archivo ($(du -h "$archivo" | cut -f1))"
        echo "Contiene tus claves privadas: guardalo en un lugar de confianza."
    else
        echo "Fallo al crear el respaldo."
        rm -f "$archivo"
        return 1
    fi
}

# copiar_arbol ORIGEN DESTINO [sin-pisar]
#   Copia todos los archivos de ORIGEN a DESTINO. Si ya existe uno distinto, el actual se
#   conserva como .~N~ (o, con "sin-pisar", no se toca el existente).
copiar_arbol() {
    local origen="$1" destino="$2" modo="${3:-}" f rel d
    [ -d "$origen" ] || return 0
    while IFS= read -r -d '' f; do
        rel="${f#"$origen"/}"
        d="$destino/$rel"
        mkdir -p "$(dirname "$d")"
        if [ -e "$d" ] || [ -L "$d" ]; then
            if [ "$modo" = "sin-pisar" ] || cmp -s "$f" "$d" 2>/dev/null; then continue; fi
            echo "  ~ $rel (el actual queda como copia .~N~)"
            cp -a --backup=numbered "$f" "$d"
        else
            cp -a "$f" "$d"
        fi
    done < <(find "$origen" \( -type f -o -type l \) -print0)
}

restaurar() {
    local archivo="${1:-}"
    if [ -z "$archivo" ] || [ ! -f "$archivo" ]; then
        echo "Indica el archivo de respaldo (.tar.gz) que quieres restaurar."
        uso; return 1
    fi
    local tmp
    tmp="$(mktemp -d)" || return 1
    trap 'rm -rf "$tmp"' RETURN
    tar -xzf "$archivo" -C "$tmp" || { echo "No pude leer el respaldo."; return 1; }
    [ -d "$tmp/home" ] || { echo "Ese archivo no parece un respaldo de este script."; return 1; }

    echo "Restaurando en $HOME ..."
    copiar_arbol "$tmp/home" "$HOME"
    # Permisos estrictos: ssh y gpg se niegan a usar claves con permisos abiertos
    [ -d "$HOME/.ssh" ]   && chmod 700 "$HOME/.ssh"
    [ -d "$HOME/.gnupg" ] && chmod 700 "$HOME/.gnupg"

    if [ -d "$tmp/documentos/MCP" ]; then
        echo "Restaurando Documentos/MCP en $DOCS/MCP ..."
        copiar_arbol "$tmp/documentos/MCP" "$DOCS/MCP"
    fi
    if [ -d "$tmp/proyectos" ]; then
        echo "Restaurando proyectos en $DESKTOP/proyectos (lo que ya exista no se toca) ..."
        copiar_arbol "$tmp/proyectos" "$DESKTOP/proyectos" sin-pisar
    fi

    if [ -s "$tmp/meta/extensiones-vscode.txt" ]; then
        if command -v code >/dev/null 2>&1; then
            echo "Instalando extensiones de VS Code ..."
            while IFS= read -r e; do
                [ -n "$e" ] && { code --install-extension "$e" --force >/dev/null 2>&1 \
                    && echo "  extension: $e" || echo "  ! fallo: $e"; }
            done < "$tmp/meta/extensiones-vscode.txt"
        else
            echo "VS Code no esta instalado: se omiten las extensiones (corre instalar-todo.sh primero)."
        fi
    fi
    echo
    echo "Listo. Abre una terminal nueva para que apliquen .bashrc y demas."
}

case "${1:-}" in
    respaldar)  shift; respaldar "$@" ;;
    restaurar)  shift; restaurar "$@" ;;
    *)          uso; exit 1 ;;
esac
