#!/usr/bin/env python3
"""
instalar-todo-gui.py - Interfaz grafica para instalar-todo.sh (Linux Mint / Ubuntu)

Pantalla 1: lista de programas por categorias (que se pliegan y despliegan), cada uno con una
casilla y una descripcion. Tiene buscador, tema oscuro y marca lo que ya esta instalado.
Solo se instala lo que marques.
Pantalla 2: progreso en vivo (barra + registro) y un resumen al terminar.

USO:  ./instalar-todo-gui.sh      (o:  python3 instalar-todo-gui.py)
Necesita python3-tk; instalar-todo-gui.sh lo instala si falta.

Para agregar un programa nuevo: anadelo a CATALOGO (id, nombre, descripcion,
dependencias), crea un bloque `if quiero <id>; then ... fi` en instalar-todo.sh y,
si quieres que se marque como "ya instalado", agrega su comprobacion en detectar_instalados().
"""

import glob
import os
import queue
import re
import shutil
import signal
import subprocess
import tempfile
import threading
import tkinter as tk
import tkinter.font as tkfont
import unicodedata
from tkinter import messagebox, simpledialog, ttk

AQUI = os.path.dirname(os.path.abspath(__file__))
SCRIPT = os.path.join(AQUI, "instalar-todo.sh")
ANSI = re.compile(r"\x1b\[[0-9;?]*[A-Za-z]")
MAX_LINEAS = 6000
HOME = os.path.expanduser("~")
SDK = os.path.join(HOME, "Android", "android-sdk")

BASE_TXT = ("Siempre se instala la base del sistema (curl, wget, unzip, compiladores básicos y "
            "flatpak): todo lo demás la necesita.")

# Paleta del tema oscuro
C = {
    "bg": "#1b1c1f", "panel": "#25272b", "panel2": "#303338", "borde": "#3a3d43",
    "fg": "#e8e8ea", "muted": "#9da3ab", "accent": "#4f8cff", "accent_h": "#6aa0ff",
    "hover": "#3b3f46", "ok": "#7fd18b", "log_bg": "#121316",
}

# Proyectos que se clonan de GitHub en la carpeta "proyectos" del Escritorio.
# Si agregas o quitas uno, haz lo mismo en la lista GH_PROYECTOS de instalar-todo.sh.
GH_USER = "norkles505"
PROYECTOS_GH = [
    ("gh_" + repo, repo,
     f"Se descarga de github.com/{GH_USER}/{repo} en la carpeta proyectos del Escritorio." + extra,
     ["git"])
    for repo, extra in [
        ("paintcraft", ""),
        ("meshcraft", ""),
        ("keyboardmovil", ""),
        ("YTDownloader", ""),
        ("ar-drawing", ""),
        ("paintcraft-PC", ""),
        ("drawengine", " Lo usa «Preparar tus proyectos» para crear su entorno virtual."),
        ("dont-cut-that", ""),
        ("vs-code-mcp", " Lo usa «Puente vscode-mcp» para compilar e instalar el puente."),
        ("nodo-capture", ""),
        ("instalar-todo", " Es este mismo instalador."),
        ("dontcutthat", ""),
    ]
]

# Alternativas de código abierto del proyecto ArtCraft (github.com/storytold). Solo se clona el
# código fuente en la carpeta proyectos; lo compilas tú con cargo (mira el README de cada una).
# Si agregas o quitas una, haz lo mismo en la lista GH_PROYECTOS de instalar-todo.sh.
GH_ARTCRAFT = "storytold"
ARTCRAFT_GH = [
    ("gh_" + repo, f"{nombre} (alternativa a {alt})",
     f"{desc} Se descarga el código de github.com/{GH_ARTCRAFT}/{repo}; lo compilas tú con cargo. "
     "Está en desarrollo o en alfa.",
     ["git", "rust", "rustlibs"])
    for repo, nombre, alt, desc in [
        ("photocraft", "PhotoCraft", "Photoshop",
         "Editor de imágenes con capas, máscaras, texto y archivos PSD."),
        ("vectorcraft", "VectorCraft", "Illustrator", "Ilustración vectorial."),
        ("filmcraft", "FilmCraft", "Premiere Pro", "Edición de video, color y sonido."),
        ("lightcraft", "LightCraft", "Lightroom", "Biblioteca de fotos y revelado de archivos RAW."),
        ("pdfcraft", "PdfCraft", "Acrobat", "Leer, organizar, combinar, dividir y proteger PDFs."),
        ("effectcraft", "EffectCraft", "After Effects", "Gráficos en movimiento y efectos visuales."),
        ("designcraft", "DesignCraft", "InDesign", "Maquetación de páginas y publicaciones."),
        ("wordcraft", "WordCraft", "Word", "Procesador de textos que abre y guarda .docx."),
        ("soundcraft", "SoundCraft", "Pro Tools", "Estación de audio digital: grabar, editar y mezclar."),
        ("deckcraft", "DeckCraft", "PowerPoint", "Presentaciones y diapositivas."),
        ("cadcraft", "CADCraft", "AutoCAD", "Diseño y dibujo asistido por computadora (CAD)."),
        ("gridcraft", "GridCraft", "Excel", "Hojas de cálculo y análisis de datos."),
    ]
]

# (id, nombre, para que sirve, [ids de los que depende])
CATALOGO = [
    ("Programación", [
        ("git", "Git",
         "Control de versiones: guarda el historial de tus proyectos y te permite clonar repositorios "
         "de GitHub. VS Code lo usa para su panel de control de código fuente.", []),
        ("vscode", "Visual Studio Code",
         "Editor de código donde programas casi todo. Es lo que Claude usa, con el puente MCP, "
         "para ver y editar tus archivos.", []),
        ("node", "Node.js (LTS) + npm",
         "Para proyectos JavaScript / TypeScript y herramientas de npm. Hace falta para compilar la "
         "extensión del puente de VS Code (incluye vsce).", []),
        ("python", "Python 3 + entorno virtual",
         "Para scripts y apps en Python. Crea el entorno ~/.venvs/dev con PySide6, Pillow, PyInstaller, "
         "yt-dlp, mcp y más, y instala ffmpeg y las librerías de Qt.", []),
        ("dotnet", ".NET SDK 10",
         "Para programar en C# y apps .NET. Unity también usa C#.", []),
        ("java", "Java (JDK 17 y 21)",
         "Para apps Java, Gradle y Android. El SDK de Android necesita Java.", []),
        ("build", "Compiladores C/C++ (CMake, Ninja, Clang, gdb)",
         "Para compilar proyectos en C/C++ y depurarlos. Útil con el NDK de Android.", []),
        ("rust", "Rust (rustup)",
         "Para programar en Rust.", []),
        ("rustlibs", "Librerías para compilar las apps Rust",
         "Paquetes -dev (xkbcommon, wayland, X11, OpenGL, GTK, fuentes, audio, OpenSSL y udev) que "
         "cargo necesita para compilar apps con ventana, como las alternativas de ArtCraft. "
         "Sin ellos, cargo se detiene con un error tipo «no encuentro xkbcommon».", ["rust"]),
        ("vscodeext", "Extensiones de VS Code",
         "Instala las de Python, Java, Gradle y Maven, y los temas (Monokai Pro, JetBrains icons).",
         ["vscode"]),
    ]),
    ("Android y juegos", [
        ("android", "Android SDK + emulador (sin Android Studio)",
         "Para crear y probar apps Android. Incluye adb, el emulador con aceleración KVM, el NDK y las "
         "plataformas 34 y 36.", ["java"]),
        ("avd", "Emulador MeshCraftPhone",
         "Crea el teléfono virtual (Pixel 6) que usaban tus archivos emulador.bat.", ["android"]),
        ("unity", "Unity Hub",
         "Para crear juegos con Unity; desde aquí instalas los editores de Unity.", []),
        ("blender", "Blender",
         "Programa de modelado 3D, animación y render.", []),
    ]),
    ("Servidor web local", [
        ("xampp", "PHP + Apache + MariaDB",
         "Equivale a XAMPP: para proyectos PHP / Laravel con base de datos MySQL. Quedan apagados hasta "
         "que los arranques.", []),
    ]),
    ("Proyectos de GitHub", PROYECTOS_GH),
    ("Alternativas open source (ArtCraft)", ARTCRAFT_GH),
    ("Claude y puentes MCP", [
        ("claude", "Claude Desktop (beta oficial)",
         "La app de escritorio de Claude para Linux. Después de instalarla tienes que abrirla e iniciar "
         "sesión.", []),
        ("vscodemcp", "Puente vscode-mcp",
         "Deja que Claude vea y edite los archivos de VS Code. Compila e instala la extensión y el "
         "servidor MCP, y los registra en Claude Desktop.", ["vscode", "node", "python"]),
        ("blendermcp", "Puente blender-mcp (uv)",
         "Deja que Claude controle Blender. Instala uv y el servidor blender-mcp; busca su carpeta en "
         "Documentos/MCP o en proyectos.", []),
    ]),
    ("Navegadores y comunicación", [
        ("brave", "Brave", "Navegador web (basado en Chromium) con bloqueo de anuncios.", []),
        ("firefox", "Firefox", "Navegador web.", []),
        ("zoom", "Zoom", "Videollamadas y reuniones.", []),
    ]),
    ("Multimedia y creatividad", [
        ("vlc", "VLC", "Reproductor de video y audio que abre casi cualquier formato.", []),
        ("obs", "OBS Studio", "Para grabar la pantalla y transmitir en vivo.", []),
        ("audacity", "Audacity", "Editor de audio: grabar, cortar y limpiar sonido.", []),
        ("kdenlive", "Kdenlive", "Editor de video (reemplazo de CapCut).", []),
        ("concat", "Concat",
         "Editor de video gratis y de código abierto, otra alternativa a CapCut: subtítulos "
         "automáticos, quitar fondo, efectos y exportación hasta 4K, sin marca de agua y sin "
         "internet. Instala el .deb de su última versión de GitHub. Está en beta.", []),
        ("gimp", "GIMP + Krita",
         "Edición de imágenes (GIMP) y pintura digital (Krita). Reemplazo de Photoshop.", []),
        ("lmms", "LMMS", "Para producir música (reemplazo de FL Studio).", []),
    ]),
    ("Utilidades", [
        ("archivos", "Compresores (7zip, rar, unrar)",
         "Para abrir y crear .zip, .7z y .rar. Reemplazo de WinRAR.", []),
    ]),
    ("Configuración", [
        ("entorno", "Variables de entorno y PATH",
         "Escribe JAVA_HOME, ANDROID_HOME y el PATH en ~/.bashrc para que las herramientas se encuentren "
         "desde cualquier terminal.", []),
        ("ajustes", "Preparar tus proyectos copiados de Windows",
         "Borra node_modules y venv de Windows, crea el venv de drawengine y deja gradlew y "
         "local.properties listos para Linux. Necesita la carpeta proyectos (con drawengine dentro).",
         ["python"]),
    ]),
]

NOMBRES = {i[0]: i[1] for _, its in CATALOGO for i in its}
REQS = {i[0]: i[3] for _, its in CATALOGO for i in its}
ORDEN = [i[0] for _, its in CATALOGO for i in its]
EXTRAS = {"brave", "firefox", "zoom", "vlc", "obs", "audacity", "kdenlive", "concat", "gimp", "lmms", "archivos"}
NOMBRES["base"] = "Base del sistema"


# ====================================================== detectar lo ya instalado
def _norm(texto):
    """Minusculas y sin acentos, para que el buscador no distinga 'edicion' de 'edición'."""
    return "".join(c for c in unicodedata.normalize("NFD", texto.lower())
                   if unicodedata.category(c) != "Mn")


def _cmd(*nombres):
    return any(shutil.which(n) for n in nombres)


def _existe(*rutas):
    return any(os.path.exists(os.path.expanduser(r)) for r in rutas)


def _glob(patron):
    return bool(glob.glob(os.path.expanduser(patron)))


def _flatpak(app_id):
    return any(os.path.isdir(os.path.join(base, "app", app_id))
               for base in ("/var/lib/flatpak", os.path.join(HOME, ".local", "share", "flatpak")))


def _en_bashrc(marca):
    try:
        with open(os.path.join(HOME, ".bashrc"), encoding="utf-8", errors="replace") as f:
            return marca in f.read()
    except OSError:
        return False


def _escritorio():
    """Carpeta Escritorio del usuario (igual que hace instalar-todo.sh)."""
    try:
        r = subprocess.run(["xdg-user-dir", "DESKTOP"], capture_output=True, text=True, timeout=3)
        d = r.stdout.strip()
        if r.returncode == 0 and d:
            return d
    except Exception:  # noqa: BLE001
        pass
    return os.path.join(HOME, "Desktop")


def detectar_instalados(proyectos_dir):
    """Devuelve el conjunto de ids que ya estan instalados (comprobaciones rapidas, sin red)."""
    pruebas = {
        "git": lambda: _cmd("git"),
        "vscode": lambda: _cmd("code"),
        "node": lambda: _cmd("node"),
        "python": lambda: os.path.isdir(os.path.join(HOME, ".venvs", "dev")),
        "dotnet": lambda: _cmd("dotnet") or _existe("~/.dotnet/dotnet"),
        "java": lambda: _glob("/usr/lib/jvm/java-17-openjdk-*") and _glob("/usr/lib/jvm/java-21-openjdk-*"),
        "build": lambda: _cmd("cmake") and _cmd("ninja"),
        "rust": lambda: _cmd("rustc") or _existe("~/.cargo/bin/rustc"),
        "rustlibs": lambda: _existe("/usr/include/xkbcommon/xkbcommon.h") and _existe("/usr/include/alsa/asoundlib.h"),
        "vscodeext": lambda: _glob("~/.vscode/extensions/ms-python.python-*"),
        "android": lambda: os.path.isdir(os.path.join(SDK, "platform-tools")),
        "avd": lambda: os.path.isdir(os.path.join(HOME, ".android", "avd", "MeshCraftPhone.avd")),
        "unity": lambda: _cmd("unityhub") or os.path.isdir("/opt/unityhub"),
        "blender": lambda: _cmd("blender") or _flatpak("org.blender.Blender"),
        "xampp": lambda: _cmd("php") and os.path.exists("/usr/sbin/apache2"),
        "claude": lambda: _cmd("claude-desktop"),
        "vscodemcp": lambda: _glob("~/.vscode/extensions/*mcp-bridge*"),
        "blendermcp": lambda: _cmd("blender-mcp") or _existe("~/.local/bin/blender-mcp"),
        "brave": lambda: _cmd("brave-browser") or _flatpak("com.brave.Browser"),
        "firefox": lambda: _cmd("firefox"),
        "zoom": lambda: _cmd("zoom") or _flatpak("us.zoom.Zoom"),
        "vlc": lambda: _cmd("vlc"),
        "obs": lambda: _cmd("obs"),
        "audacity": lambda: _cmd("audacity"),
        "kdenlive": lambda: _cmd("kdenlive"),
        "concat": lambda: _cmd("concat", "Concat") or _glob("/usr/share/applications/*[Cc]oncat*.desktop"),
        "gimp": lambda: _cmd("gimp"),
        "lmms": lambda: _cmd("lmms"),
        "archivos": lambda: _cmd("7z"),
        "entorno": lambda: _en_bashrc("# >>> entorno-dev >>>"),
    }
    # Un proyecto de GitHub cuenta como instalado si su carpeta ya es un repositorio git
    for id_ in ORDEN:
        if id_.startswith("gh_"):
            repo = id_[3:]
            pruebas[id_] = lambda r=repo: os.path.isdir(os.path.join(proyectos_dir, r, ".git"))

    instalados = set()
    for id_, prueba in pruebas.items():
        try:
            if prueba():
                instalados.add(id_)
        except Exception:  # noqa: BLE001
            pass
    return instalados


class App(tk.Tk):
    def __init__(self):
        super().__init__()
        self.title("Instalar todo - Linux Mint")
        self.geometry("960x720")
        self.minsize(780, 500)

        self.proc = None
        self.cola = queue.Queue()
        self.askpass = None
        self.fallos = []
        self.captura = False
        self.cancelado = False
        self.total = 1
        self.vistos = 0
        self.vars = {}
        self.descs = []
        self.cats = []
        self.badges = {}
        self.instalados = set()
        self.proyectos_dir = os.path.join(_escritorio(), "proyectos")
        self._ajustando = False

        self._fuentes()
        self._tema()
        self._pantalla_seleccion()
        self._pantalla_progreso()
        self.sel.pack(fill="both", expand=True)
        self._refrescar_instalados()

        self.after(100, self._vaciar_cola)
        self.protocol("WM_DELETE_WINDOW", self._cerrar)

    # ============================================================ aspecto
    def _fuentes(self):
        base = tkfont.nametofont("TkDefaultFont")
        self.f_bold = base.copy()
        self.f_bold.configure(weight="bold")
        self.f_title = base.copy()
        self.f_title.configure(size=18, weight="bold")

    def _tema(self):
        self.configure(bg=C["bg"])
        e = ttk.Style(self)
        try:
            e.theme_use("clam")
        except tk.TclError:
            pass
        e.configure(".", background=C["bg"], foreground=C["fg"], fieldbackground=C["panel2"],
                    bordercolor=C["borde"], lightcolor=C["borde"], darkcolor=C["borde"],
                    troughcolor=C["panel"], focuscolor=C["panel"], insertcolor=C["fg"])

        # Botones
        e.configure("TButton", background=C["panel2"], foreground=C["fg"], padding=(12, 5),
                    relief="flat", borderwidth=1)
        e.map("TButton",
              background=[("disabled", C["panel"]), ("pressed", C["accent"]), ("active", C["hover"])],
              foreground=[("disabled", C["muted"])])
        e.configure("Small.TButton", padding=(8, 2))
        e.configure("Accent.TButton", background=C["accent"], foreground="#ffffff", font=self.f_bold,
                    padding=(18, 7), bordercolor=C["accent"], lightcolor=C["accent"], darkcolor=C["accent"])
        e.map("Accent.TButton",
              background=[("disabled", C["panel2"]), ("active", C["accent_h"])],
              foreground=[("disabled", C["muted"])])

        # Marcos y etiquetas
        e.configure("Panel.TFrame", background=C["panel"])
        e.configure("Titulo.TLabel", font=self.f_title)
        e.configure("Sub.TLabel", foreground=C["muted"])
        e.configure("Panel.TLabel", background=C["panel"])
        e.configure("PanelB.TLabel", background=C["panel"], font=self.f_bold)
        e.configure("Muted.TLabel", background=C["panel"], foreground=C["muted"])
        e.configure("Ok.TLabel", background=C["panel"], foreground=C["ok"], font=self.f_bold)

        # Casillas
        e.configure("TCheckbutton", background=C["bg"], foreground=C["fg"],
                    indicatorbackground=C["panel2"], indicatorcolor=C["panel2"],
                    indicatorforeground="#ffffff", upperbordercolor=C["borde"], lowerbordercolor=C["borde"])
        e.map("TCheckbutton",
              background=[("active", C["bg"])],
              indicatorbackground=[("selected", C["accent"]), ("pressed", C["accent"])],
              indicatorcolor=[("selected", C["accent"]), ("pressed", C["accent"])])
        e.configure("Nombre.TCheckbutton", background=C["panel"], font=self.f_bold)
        e.map("Nombre.TCheckbutton", background=[("active", C["panel"])])

        # Campo de busqueda, barra de desplazamiento y barra de progreso
        e.configure("TEntry", fieldbackground=C["panel2"], foreground=C["fg"], insertcolor=C["fg"],
                    padding=5)
        e.map("TEntry", bordercolor=[("focus", C["accent"])], lightcolor=[("focus", C["accent"])],
              darkcolor=[("focus", C["accent"])])
        e.configure("Vertical.TScrollbar", background=C["panel2"], troughcolor=C["bg"],
                    bordercolor=C["bg"], arrowcolor=C["fg"], lightcolor=C["panel2"], darkcolor=C["panel2"])
        e.map("Vertical.TScrollbar", background=[("active", C["hover"])])
        e.configure("Horizontal.TProgressbar", background=C["accent"], troughcolor=C["panel"],
                    bordercolor=C["borde"], lightcolor=C["accent"], darkcolor=C["accent"])

    # ================================================== pantalla 1: seleccion
    def _pantalla_seleccion(self):
        self.sel = ttk.Frame(self)

        cab = ttk.Frame(self.sel, padding=(20, 16, 20, 4))
        cab.pack(fill="x")
        ttk.Label(cab, text="Instalar todo", style="Titulo.TLabel").pack(anchor="w")
        ttk.Label(cab, wraplength=880, style="Sub.TLabel",
                  text="Marca lo que quieres instalar. Lo que no marques no se toca. "
                       "Si marcas algo que necesita otro programa, se marca también."
                  ).pack(anchor="w", pady=(2, 0))
        ttk.Label(cab, wraplength=880, style="Sub.TLabel", text=BASE_TXT).pack(anchor="w")

        # Barra inferior (se empaqueta antes del area con scroll para que no quede tapada)
        inf = ttk.Frame(self.sel, padding=(20, 10))
        inf.pack(fill="x", side="bottom")
        self.cuenta = tk.StringVar()
        ttk.Label(inf, textvariable=self.cuenta).pack(side="left")
        self.btn_instalar = ttk.Button(inf, text="Instalar lo marcado", style="Accent.TButton",
                                       command=self._empezar)
        self.btn_instalar.pack(side="right")
        ttk.Button(inf, text="Cerrar", command=self._cerrar).pack(side="right", padx=8)

        # Barra de herramientas: buscador, plegar/desplegar y selecciones rapidas
        barra = ttk.Frame(self.sel, padding=(20, 8, 20, 0))
        barra.pack(fill="x")
        fila1 = ttk.Frame(barra)
        fila1.pack(fill="x")
        ttk.Label(fila1, text="Buscar:").pack(side="left")
        self.busqueda = tk.StringVar()
        self.entrada = ttk.Entry(fila1, textvariable=self.busqueda, width=34)
        self.entrada.pack(side="left", padx=8)
        ttk.Button(fila1, text="✕", width=3, style="Small.TButton",
                   command=lambda: self.busqueda.set("")).pack(side="left")
        ttk.Button(fila1, text="Desplegar todo", style="Small.TButton",
                   command=lambda: self._plegar_todo(False)).pack(side="right")
        ttk.Button(fila1, text="Plegar todo", style="Small.TButton",
                   command=lambda: self._plegar_todo(True)).pack(side="right", padx=6)

        fila2 = ttk.Frame(barra)
        fila2.pack(fill="x", pady=(8, 0))
        ttk.Label(fila2, text="Selección rápida:").pack(side="left")
        rapidas = (
            ("Todo", lambda: self._preset(set(ORDEN))),
            ("Solo desarrollo", lambda: self._preset(set(ORDEN) - EXTRAS)),
            ("Solo lo que falta", lambda: self._preset(set(ORDEN) - self.instalados)),
            ("Nada", lambda: self._preset(set())),
        )
        for texto, fn in rapidas:
            ttk.Button(fila2, text=texto, style="Small.TButton", command=fn).pack(side="left", padx=(8, 0))
        self.ocultar_inst = tk.BooleanVar(value=False)
        ttk.Checkbutton(fila2, text="Ocultar los ya instalados", variable=self.ocultar_inst,
                        command=lambda: self._filtrar(True)).pack(side="right")

        marco = ttk.Frame(self.sel)
        marco.pack(fill="both", expand=True, padx=(20, 0), pady=(10, 0))
        self.canvas = tk.Canvas(marco, highlightthickness=0, bg=C["bg"])
        sb = ttk.Scrollbar(marco, orient="vertical", command=self.canvas.yview)
        self.canvas.configure(yscrollcommand=sb.set)
        sb.pack(side="right", fill="y")
        self.canvas.pack(side="left", fill="both", expand=True)
        self.inner = ttk.Frame(self.canvas)
        self.ventana = self.canvas.create_window((0, 0), window=self.inner, anchor="nw")
        self.inner.bind("<Configure>", lambda e: self.canvas.configure(scrollregion=self.canvas.bbox("all")))
        self.canvas.bind("<Configure>", self._ajustar_ancho)
        self.bind_all("<Button-4>", lambda e: self._rueda(-1))
        self.bind_all("<Button-5>", lambda e: self._rueda(1))
        self.bind_all("<MouseWheel>", lambda e: self._rueda(-1 if e.delta > 0 else 1))

        for categoria, items in CATALOGO:
            caja = tk.Frame(self.inner, bg=C["panel"], highlightthickness=1,
                            highlightbackground=C["borde"])
            cab_cat = ttk.Frame(caja, style="Panel.TFrame", padding=(12, 8))
            cab_cat.pack(fill="x")
            cuerpo = ttk.Frame(caja, style="Panel.TFrame", padding=(14, 0, 12, 10))

            ids = [i[0] for i in items]
            cat = {"caja": caja, "cuerpo": cuerpo, "ids": ids, "filas": [], "plegada": False,
                   "cuenta": tk.StringVar()}

            flecha = ttk.Label(cab_cat, text="▾", style="PanelB.TLabel", width=2)
            flecha.pack(side="left")
            titulo = ttk.Label(cab_cat, text=categoria, style="PanelB.TLabel")
            titulo.pack(side="left")
            cuenta_lbl = ttk.Label(cab_cat, textvariable=cat["cuenta"], style="Muted.TLabel")
            cuenta_lbl.pack(side="left", padx=(12, 0))
            cat["flecha"] = flecha
            for w in (cab_cat, flecha, titulo, cuenta_lbl):
                w.bind("<Button-1>", lambda e, c=cat: self._alternar(c))
                w.configure(cursor="hand2")

            ttk.Button(cab_cat, text="Ninguno", width=8, style="Small.TButton",
                       command=lambda ids=ids: self._poner(ids, False)).pack(side="right")
            ttk.Button(cab_cat, text="Todos", width=8, style="Small.TButton",
                       command=lambda ids=ids: self._poner(ids, True)).pack(side="right", padx=4)

            for id_, nombre, desc, req in items:
                var = tk.BooleanVar(value=True)
                self.vars[id_] = var
                fila = ttk.Frame(cuerpo, style="Panel.TFrame")
                arriba = ttk.Frame(fila, style="Panel.TFrame")
                arriba.pack(fill="x")
                ttk.Checkbutton(arriba, text=nombre, variable=var, style="Nombre.TCheckbutton",
                                command=lambda i=id_: self._cambio(i)).pack(side="left")
                self.badges[id_] = ttk.Label(arriba, text="✔ Ya instalado", style="Ok.TLabel")
                texto = desc
                if req:
                    texto += "  (Necesita: " + ", ".join(NOMBRES[r] for r in req) + ")"
                lbl = ttk.Label(fila, text=texto, wraplength=700, style="Muted.TLabel")
                lbl.pack(anchor="w", padx=(24, 0))
                self.descs.append(lbl)
                cat["filas"].append((id_, fila, _norm(f"{nombre} {desc} {id_}")))
            self.cats.append(cat)

        self.vacio = ttk.Label(self.inner, text="Nada coincide con tu búsqueda.", style="Sub.TLabel")

        self.busqueda.trace_add("write", lambda *a: self._filtrar(True))
        self.entrada.bind("<Escape>", lambda e: self.busqueda.set(""))
        self.bind("<Control-f>", lambda e: (self.entrada.focus_set(), self.entrada.select_range(0, "end")))

    def _ajustar_ancho(self, evento):
        self.canvas.itemconfigure(self.ventana, width=evento.width)
        for lbl in self.descs:
            lbl.configure(wraplength=max(300, evento.width - 100))

    def _rueda(self, paso):
        if self.sel.winfo_ismapped():
            self.canvas.yview_scroll(paso * 3, "units")

    # ---- plegar / buscar / ocultar instalados
    def _alternar(self, cat):
        if self.busqueda.get().strip():
            return          # mientras se busca, las categorias con resultados se muestran abiertas
        cat["plegada"] = not cat["plegada"]
        self._filtrar()

    def _plegar_todo(self, plegar):
        for cat in self.cats:
            cat["plegada"] = plegar
        self._filtrar()

    def _filtrar(self, reiniciar_scroll=False):
        q = _norm(self.busqueda.get().strip())
        ocultar = self.ocultar_inst.get()

        for cat in self.cats:
            cat["caja"].pack_forget()
        hay = False
        for cat in self.cats:
            for _, fila, _ in cat["filas"]:
                fila.pack_forget()
            visibles = 0
            for id_, fila, texto in cat["filas"]:
                if q and q not in texto:
                    continue
                if ocultar and id_ in self.instalados:
                    continue
                fila.pack(fill="x", pady=(5, 0))
                visibles += 1
            if not visibles:
                continue
            hay = True
            cat["caja"].pack(fill="x", padx=(0, 12), pady=6)
            abierta = bool(q) or not cat["plegada"]
            cat["flecha"].configure(text="▾" if abierta else "▸")
            if abierta:
                cat["cuerpo"].pack(fill="x")
            else:
                cat["cuerpo"].pack_forget()

        if hay:
            self.vacio.pack_forget()
        else:
            self.vacio.pack(pady=30)
        if reiniciar_scroll:
            self.canvas.yview_moveto(0)

    def _refrescar_instalados(self):
        self.instalados = detectar_instalados(self.proyectos_dir)
        for id_, badge in self.badges.items():
            if id_ in self.instalados:
                badge.pack(side="left", padx=(12, 0))
            else:
                badge.pack_forget()
        self._filtrar()
        self._actualizar_cuenta()

    # ---- logica de casillas y dependencias
    def _cambio(self, id_):
        if self._ajustando:
            return
        self._ajustando = True
        try:
            if self.vars[id_].get():
                self._marcar_reqs(id_)
            else:
                self._desmarcar_dependientes(id_)
        finally:
            self._ajustando = False
        self._actualizar_cuenta()

    def _marcar_reqs(self, id_):
        for r in REQS[id_]:
            if not self.vars[r].get():
                self.vars[r].set(True)
            self._marcar_reqs(r)

    def _desmarcar_dependientes(self, id_):
        for otro, reqs in REQS.items():
            if id_ in reqs and self.vars[otro].get():
                self.vars[otro].set(False)
                self._desmarcar_dependientes(otro)

    def _poner(self, ids, valor):
        self._ajustando = True
        try:
            for i in ids:
                self.vars[i].set(valor)
                if valor:
                    self._marcar_reqs(i)
                else:
                    self._desmarcar_dependientes(i)
        finally:
            self._ajustando = False
        self._actualizar_cuenta()

    def _preset(self, elegidos):
        self._ajustando = True
        try:
            for i in ORDEN:
                self.vars[i].set(i in elegidos)
            for i in ORDEN:
                if self.vars[i].get():
                    self._marcar_reqs(i)
        finally:
            self._ajustando = False
        self._actualizar_cuenta()

    def _elegidos(self):
        return [i for i in ORDEN if self.vars[i].get()]

    def _actualizar_cuenta(self):
        n = len(self._elegidos())
        extra = f"   ·   {len(self.instalados)} ya instalados" if self.instalados else ""
        self.cuenta.set(f"{n} de {len(ORDEN)} marcados{extra}")
        for cat in self.cats:
            m = sum(1 for i in cat["ids"] if self.vars[i].get())
            cat["cuenta"].set(f"{m} de {len(cat['ids'])} marcados")

    # ================================================== pantalla 2: progreso
    def _pantalla_progreso(self):
        self.prog = ttk.Frame(self)

        cab = ttk.Frame(self.prog, padding=(20, 16, 20, 4))
        cab.pack(fill="x")
        ttk.Label(cab, text="Instalando...", style="Titulo.TLabel").pack(anchor="w")
        self.estado = tk.StringVar(value="")
        ttk.Label(cab, textvariable=self.estado).pack(anchor="w", pady=(4, 0))
        self.barra = ttk.Progressbar(cab, mode="determinate", maximum=1)
        self.barra.pack(fill="x", pady=(8, 0))

        fila = ttk.Frame(self.prog, padding=(20, 10))
        fila.pack(fill="x", side="bottom")
        self.btn_cancelar = ttk.Button(fila, text="Cancelar", command=self._cancelar)
        self.btn_cancelar.pack(side="left")
        self.btn_volver = ttk.Button(fila, text="Volver a la lista", command=self._volver, state="disabled")
        self.btn_volver.pack(side="left", padx=8)
        ttk.Button(fila, text="Cerrar", command=self._cerrar).pack(side="right")

        cuerpo = ttk.Frame(self.prog, padding=(20, 8, 20, 0))
        cuerpo.pack(fill="both", expand=True)
        self.log = tk.Text(
            cuerpo, wrap="word", state="disabled", bg=C["log_bg"], fg="#d4d4d4",
            insertbackground="#d4d4d4", font=("DejaVu Sans Mono", 10), relief="flat",
            highlightthickness=1, highlightbackground=C["borde"], padx=10, pady=8)
        sb = ttk.Scrollbar(cuerpo, command=self.log.yview)
        self.log.configure(yscrollcommand=sb.set)
        sb.pack(side="right", fill="y")
        self.log.pack(side="left", fill="both", expand=True)
        self.log.tag_configure("titulo", foreground="#e5c07b", font=("DejaVu Sans Mono", 10, "bold"))
        self.log.tag_configure("info", foreground="#56b6c2")
        self.log.tag_configure("error", foreground="#e06c75")
        self.log.tag_configure("ok", foreground="#98c379")

    def _mostrar(self, pantalla):
        for p in (self.sel, self.prog):
            p.pack_forget()
        pantalla.pack(fill="both", expand=True)

    def _volver(self):
        self._mostrar(self.sel)

    # ===================================================== iniciar / detener
    def _empezar(self):
        elegidos = self._elegidos()
        if not elegidos:
            messagebox.showinfo("Nada marcado", "Marca al menos un programa para instalar.")
            return
        if not os.path.isfile(SCRIPT):
            messagebox.showerror("Falta el script", f"No encuentro instalar-todo.sh en:\n{AQUI}")
            return
        if not messagebox.askyesno(
                "Confirmar",
                f"Se instalarán {len(elegidos)} componentes (más la base del sistema).\n\n¿Continuar?"):
            return

        pw = simpledialog.askstring(
            "Contraseña de administrador",
            "Escribe tu contraseña para poder instalar programas (sudo):",
            show="*", parent=self)
        if not pw:
            return
        r = subprocess.run(["sudo", "-S", "-v"], input=pw + "\n", text=True, capture_output=True)
        if r.returncode != 0:
            messagebox.showerror("Contraseña incorrecta", "sudo no aceptó esa contraseña. Intenta de nuevo.")
            return

        # Programa auxiliar para que sudo reciba la contrasena sin terminal
        fd, ruta = tempfile.mkstemp(prefix="askpass-", suffix=".sh")
        with os.fdopen(fd, "w") as f:
            f.write('#!/bin/sh\nprintf "%s\\n" "$INSTALAR_TODO_PW"\n')
        os.chmod(ruta, 0o700)
        self.askpass = ruta

        env = dict(os.environ, SUDO_ASKPASS=ruta, INSTALAR_TODO_PW=pw,
                   INSTALAR_TODO_GUI="1", PYTHONUNBUFFERED="1", TERM="dumb")
        cmd = ["bash", SCRIPT, "--solo=" + ",".join(elegidos)]

        self._limpiar_log()
        self.fallos = []
        self.captura = False
        self.cancelado = False
        self.total = len(elegidos) + 1      # +1 por la base del sistema
        self.vistos = 0
        self.barra.configure(maximum=self.total, value=0)
        self.estado.set("Iniciando...")
        self.btn_cancelar.configure(state="normal")
        self.btn_volver.configure(state="disabled")
        self._mostrar(self.prog)

        try:
            self.proc = subprocess.Popen(
                cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, stdin=subprocess.DEVNULL,
                text=True, errors="replace", bufsize=1, env=env, cwd=AQUI, start_new_session=True)
        except Exception as e:  # noqa: BLE001
            self._borrar_askpass()
            self._mostrar(self.sel)
            messagebox.showerror("No se pudo iniciar", str(e))
            return
        threading.Thread(target=self._leer, daemon=True).start()

    def _leer(self):
        try:
            for linea in self.proc.stdout:
                self.cola.put(("linea", linea))
        finally:
            rc = self.proc.wait()
            self.cola.put(("fin", rc))

    def _matar(self):
        try:
            os.killpg(self.proc.pid, signal.SIGTERM)
        except Exception:  # noqa: BLE001
            self.proc.terminate()

    def _cancelar(self):
        if self.proc and self.proc.poll() is None:
            if messagebox.askyesno("Cancelar", "¿Detener la instalación? Lo que ya se instaló se queda."):
                self.cancelado = True
                self._matar()

    def _cerrar(self):
        if self.proc and self.proc.poll() is None:
            if not messagebox.askyesno("Instalación en curso", "Todavía se está instalando. ¿Detenerla y salir?"):
                return
            self._matar()
        self._borrar_askpass()
        self.destroy()

    # ================================================================ salida
    def _vaciar_cola(self):
        try:
            for _ in range(300):
                tipo, dato = self.cola.get_nowait()
                if tipo == "linea":
                    self._linea(dato)
                else:
                    self._fin(dato)
        except queue.Empty:
            pass
        self.after(100, self._vaciar_cola)

    def _linea(self, dato):
        texto = ANSI.sub("", dato.rstrip("\n")).replace("\r", "")

        # Marca interna del script: avanza la barra de progreso (no se muestra)
        if texto.startswith("@@COMPONENTE "):
            id_ = texto.split(" ", 1)[1].strip()
            self.vistos += 1
            self.barra.configure(value=self.vistos - 1)
            self.estado.set(f"Paso {self.vistos} de {self.total}: {NOMBRES.get(id_, id_)}")
            return

        tag = None
        if texto.startswith("==="):
            tag = "titulo"
        elif texto.startswith(">>"):
            tag = "info"
        elif texto.startswith("!!"):
            tag = "error"
        elif "Todo se instalo sin errores" in texto:
            tag = "ok"

        if "Esto fallo o hay que hacerlo a mano" in texto:
            self.captura = True
        elif self.captura:
            if texto.startswith("  - "):
                self.fallos.append(texto[4:])
            else:
                self.captura = False

        self._escribir(texto + "\n", tag)

    def _escribir(self, texto, tag=None):
        al_final = self.log.yview()[1] > 0.98
        self.log.configure(state="normal")
        self.log.insert("end", texto, tag)
        exceso = int(self.log.index("end-1c").split(".")[0]) - MAX_LINEAS
        if exceso > 0:
            self.log.delete("1.0", f"{exceso + 1}.0")
        self.log.configure(state="disabled")
        if al_final:
            self.log.see("end")

    def _limpiar_log(self):
        self.log.configure(state="normal")
        self.log.delete("1.0", "end")
        self.log.configure(state="disabled")

    def _fin(self, rc):
        self._borrar_askpass()
        self.btn_cancelar.configure(state="disabled")
        self.btn_volver.configure(state="normal")
        self._refrescar_instalados()      # para que la lista muestre lo que acaba de quedar instalado
        if self.cancelado:
            self.estado.set("Instalación cancelada.")
            self._escribir("\n-- Instalación cancelada --\n", "error")
            return
        self.barra.configure(value=self.total)
        if rc == 0 and not self.fallos:
            self.estado.set("Terminó sin errores. Cierra sesión y vuelve a entrar.")
            messagebox.showinfo(
                "Instalación terminada",
                "Todo se instaló sin errores.\n\nÚltimo paso: cierra sesión y vuelve a entrar "
                "(para que se activen el PATH y los grupos). Los pasos pendientes están al final del registro.")
        else:
            self.estado.set("Terminó con avisos. Revisa el resumen.")
            detalle = "\n".join(f"  • {f}" for f in self.fallos) if self.fallos else f"Código de salida: {rc}"
            messagebox.showwarning(
                "Instalación terminada con avisos",
                f"Esto falló o hay que hacerlo a mano:\n\n{detalle}\n\n"
                "El registro tiene el detalle. Si algo falla, copia el mensaje de error.")

    def _borrar_askpass(self):
        if self.askpass:
            try:
                os.remove(self.askpass)
            except OSError:
                pass
            self.askpass = None


if __name__ == "__main__":
    App().mainloop()
