#!/usr/bin/env bash
# instalar-todo-gui.sh - Abre la interfaz grafica de instalar-todo.sh
#
# USO (desde una terminal, en esta carpeta):
#   chmod +x instalar-todo-gui.sh instalar-todo.sh
#   ./instalar-todo-gui.sh
# No lo ejecutes con sudo.

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ "$EUID" -eq 0 ]; then
    echo "No ejecutes esto como root (sin sudo). Pedira la contrasena cuando haga falta."
    exit 1
fi
command -v python3 >/dev/null 2>&1 || { echo "No hay python3. Instala: sudo apt install python3 python3-tk"; exit 1; }
[ -f "$DIR/instalar-todo-gui.py" ] || { echo "No encuentro instalar-todo-gui.py en $DIR"; exit 1; }
[ -f "$DIR/instalar-todo.sh" ]     || { echo "No encuentro instalar-todo.sh en $DIR"; exit 1; }

# La ventana usa tkinter (paquete python3-tk). Si falta, se instala con una ventana de contrasena (pkexec).
if ! python3 -c "import tkinter" 2>/dev/null; then
    echo "Falta python3-tk (la libreria de ventanas). Instalando..."
    if command -v pkexec >/dev/null 2>&1 && [ -n "${DISPLAY:-}${WAYLAND_DISPLAY:-}" ]; then
        pkexec sh -c 'apt-get update && apt-get install -y python3-tk' \
            || { echo "No se pudo instalar python3-tk."; exit 1; }
    else
        sudo sh -c 'apt-get update && apt-get install -y python3-tk' \
            || { echo "No se pudo instalar python3-tk."; exit 1; }
    fi
    python3 -c "import tkinter" 2>/dev/null || { echo "python3-tk sigue sin funcionar. Instala a mano: sudo apt install python3-tk"; exit 1; }
fi

chmod +x "$DIR/instalar-todo.sh" 2>/dev/null
exec python3 "$DIR/instalar-todo-gui.py"
