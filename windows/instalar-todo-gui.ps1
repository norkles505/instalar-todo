# =====================================================================
# instalar-todo-gui.ps1  -  Ventana para elegir que instalar (Windows)
#
# Equivalente de linux\instalar-todo-gui.py. Lo abre INSTALAR-TODO.bat (doble clic).
#  Pantalla 1: lista por categorias (se pliegan), con buscador, tema oscuro y
#              marca de "ya instalado". Solo se instala lo que marques.
#  Pantalla 2: progreso en vivo (barra + registro) y un resumen al terminar.
#
# Para agregar un programa: anadelo a $catalogo y crea su bloque
#   if (Quiero '<id>') { ... }   en instalar-todo.ps1.
# Codigos de salida: lo que devuelva instalar-todo.ps1, o 3 si cierras sin instalar.
# (Solo ASCII a proposito: PowerShell 5.1 lee mal los acentos.)
# =====================================================================
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()

$esAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $esAdmin) {
    [System.Windows.Forms.MessageBox]::Show('Ejecuta esto como Administrador (usa INSTALAR-TODO.bat, que lo pide solo).', 'Instalar todo') | Out-Null
    exit 1
}

function Item([string]$id, [string]$nombre, [string]$desc, [string[]]$req = @()) {
    return @{ Id = $id; Nombre = $nombre; Desc = $desc; Req = $req }
}

# ---------------------------------------------------------------------
# Catalogo: categoria -> programas (id, nombre, para que sirve, dependencias)
# Los ids son los mismos que usa Quiero '<id>' en instalar-todo.ps1
# ---------------------------------------------------------------------
# ---------------------------------------------------------------------
# Repos de GitHub: una casilla por repo (id gh_<repo>), como en la ventana de Linux.
# Si agregas o quitas uno, haz lo mismo en $ghProyectos de instalar-todo.ps1
# (y en GH_PROYECTOS de linux\instalar-todo.sh).
# ---------------------------------------------------------------------
$proyectosGh = @(
    @('paintcraft', ''), @('meshcraft', ''), @('keyboardmovil', ''), @('YTDownloader', ''),
    @('ar-drawing', ''), @('paintcraft-PC', ''),
    @('drawengine', ' Lo usa "Preparar tus proyectos" para crear su entorno virtual.'),
    @('dont-cut-that', ''),
    @('vs-code-mcp', ' Lo usa "Puente vscode-mcp" para compilar e instalar el puente.'),
    @('nodo-capture', ''),
    @('instalar-todo', ' Es este mismo instalador.'),
    @('dontcutthat', ''), @('gitcraft', '')
)
$itemsProyectos = @(foreach ($p in $proyectosGh) {
    Item ('gh_' + $p[0]) ($p[0]) ("Se descarga de github.com/norkles505/$($p[0]) en tu carpeta de proyectos (la eliges arriba; por defecto, proyectos en el Escritorio)." + $p[1]) @('git')
})

# Alternativas open source de ArtCraft (github.com/storytold): solo se clona el codigo en la
# carpeta programas del Escritorio; lo compilas tu con cargo (hace falta Rust y los Build Tools C++).
$artcraftGh = @(
    @('photocraft', 'PhotoCraft', 'Photoshop', 'Editor de imagenes con capas, mascaras, texto y archivos PSD.'),
    @('vectorcraft', 'VectorCraft', 'Illustrator', 'Ilustracion vectorial.'),
    @('filmcraft', 'FilmCraft', 'Premiere Pro', 'Edicion de video, color y sonido.'),
    @('lightcraft', 'LightCraft', 'Lightroom', 'Biblioteca de fotos y revelado de archivos RAW.'),
    @('pdfcraft', 'PdfCraft', 'Acrobat', 'Leer, organizar, combinar, dividir y proteger PDFs.'),
    @('effectcraft', 'EffectCraft', 'After Effects', 'Graficos en movimiento y efectos visuales.'),
    @('designcraft', 'DesignCraft', 'InDesign', 'Maquetacion de paginas y publicaciones.'),
    @('wordcraft', 'WordCraft', 'Word', 'Procesador de textos que abre y guarda .docx.'),
    @('soundcraft', 'SoundCraft', 'Pro Tools', 'Estacion de audio digital: grabar, editar y mezclar.'),
    @('deckcraft', 'DeckCraft', 'PowerPoint', 'Presentaciones y diapositivas.'),
    @('cadcraft', 'CADCraft', 'AutoCAD', 'Diseno y dibujo asistido por computadora (CAD).'),
    @('gridcraft', 'GridCraft', 'Excel', 'Hojas de calculo y analisis de datos.'),
    @('figcraft', 'FigCraft', 'Figma', 'Diseno de interfaces y prototipos.'),
    @('texturecraft', 'TextureCraft', 'Substance Painter', 'Pintura de texturas 3D.'),
    @('materialcraft', 'MaterialCraft', 'Substance Designer', 'Materiales procedurales basados en nodos.'),
    @('craft-anything', 'Craft Anything', '', 'Explora como funciona un software y construye tu propia version.')
)
$itemsArtcraft = @(foreach ($a in $artcraftGh) {
    $nom = $a[1]
    if ($a[2]) { $nom = "$($a[1]) (alternativa a $($a[2]))" }
    Item ('gh_' + $a[0]) $nom ($a[3] + " Se descarga el codigo de github.com/storytold/$($a[0]) en tu carpeta de programas (la eliges arriba; por defecto, programas en el Escritorio). Se compila con el boton Actualizar ArtCraft. Esta en desarrollo o en alfa.") @('git', 'rust', 'buildtools')
})

$catalogo = @(
    @{ Cat = 'Programacion'; Items = @(
        (Item 'git'       'Git' 'Control de versiones: guarda el historial de tus proyectos y permite clonar repositorios de GitHub.')
        (Item 'ghcli'     'GitHub CLI (gh)' 'Herramienta de GitHub para la terminal. GitCraft la usa para iniciar sesion y trabajar con tus repos (solo te falta iniciar sesion en Ajustes de GitCraft).')
        (Item 'vscode'    'Visual Studio Code' 'Editor de codigo. Es lo que Claude usa, con el puente MCP, para ver y editar tus archivos.')
        (Item 'node'      'Node.js (LTS) + npm' 'Para proyectos JavaScript / TypeScript. Hace falta para compilar la extension del puente de VS Code (instala tambien vsce).')
        (Item 'python'    'Python 3.13 + paquetes' 'Para scripts y apps en Python. Instala PySide6, Pillow, PyInstaller, yt-dlp, mcp<2 y mas.')
        (Item 'dotnet'    '.NET SDK 10' 'Para programar en C# y apps .NET. Unity tambien usa C#.')
        (Item 'jdk17'     'Java JDK 17 (Temurin)' 'Para apps Java, Gradle y el SDK de Android (sdkmanager lo necesita). Tus compilar.bat usan esta version.')
        (Item 'jdk21'     'Java JDK 21 (Temurin)' 'Version mas nueva de Java. JAVA_HOME apunta a esta si esta instalada.')
        (Item 'cmake'     'CMake' 'Para configurar y compilar proyectos C/C++ (y el NDK de Android).')
        (Item 'llvm'      'LLVM (Clang)' 'Compilador Clang y herramientas de LLVM para C/C++.')
        (Item 'msys2'     'MSYS2' 'Entorno tipo Linux con gcc y pacman para compilar programas en Windows.')
        (Item 'buildtools' 'Visual Studio Build Tools (C++)' 'Compilador de Microsoft que necesita Rust para compilar en Windows. Es grande y tarda.')
        (Item 'rust'      'Rust (rustup)' 'Para programar en Rust. Deja la toolchain estable.')
        (Item 'php'       'PHP 8.3' 'Para proyectos PHP / Laravel.')
        (Item 'vscodeext' 'Extensiones de VS Code' 'Instala las de Python, Java, Gradle y Maven, y los temas (Monokai Pro, JetBrains icons).' @('vscode'))
    )},
    @{ Cat = 'Android y juegos'; Items = @(
        (Item 'android'    'Android SDK + emulador (sin Android Studio)' 'Para crear y probar apps Android. Incluye adb, emulador, NDK y las plataformas 34 y 36. Descarga varios GB.' @('jdk17'))
        (Item 'avd'        'Emulador MeshCraftPhone' 'Crea el telefono virtual (Pixel 6) que usan tus archivos emulador.bat.' @('android'))
        (Item 'hypervisor' 'Windows Hypervisor Platform' 'Aceleracion que necesita el emulador de Android. La virtualizacion tambien debe estar activa en la BIOS.')
        (Item 'unity'      'Unity Hub' 'Para crear juegos con Unity; desde aqui instalas los editores de Unity.')
        (Item 'blender'    'Blender' 'Programa de modelado 3D, animacion y render.')
        (Item 'virtualbox' 'VirtualBox' 'Para crear maquinas virtuales (por ejemplo, para probar el instalador de Linux).')
    )},
    @{ Cat = 'Servidor web local'; Items = @(
        (Item 'xampp' 'XAMPP' 'Apache + MariaDB + PHP para proyectos con base de datos MySQL. Quedan apagados hasta que los arranques.')
    )},
    @{ Cat = 'Proyectos de GitHub'; Items = $itemsProyectos },
    @{ Cat = 'Alternativas open source (ArtCraft)'; Items = $itemsArtcraft },
    @{ Cat = 'Ajustes de proyectos'; Items = @(
        # (los repos de GitHub tienen cada uno su casilla, arriba)
        (Item 'ajustes' 'Preparar tus proyectos' 'Crea el venv de drawengine y ajusta la ruta del JDK 17 en los compilar.bat. Necesita la carpeta proyectos (con drawengine dentro).' @('python', 'jdk17', 'gh_drawengine'))
    )},
    @{ Cat = 'Claude y puentes MCP'; Items = @(
        (Item 'claude'     'Claude Desktop' 'La app de escritorio de Claude. Al marcarla se marca tambien el puente vscode-mcp (con VS Code y Python). Despues de instalarla tienes que abrirla e iniciar sesion.')
        (Item 'vscodemcp'  'Puente vscode-mcp' 'Deja que Claude vea y edite los archivos de VS Code. Descarga el repo si falta, compila la extension (.vsix) y la instala junto con el servidor MCP.' @('vscode', 'python', 'git', 'node'))
        (Item 'blendermcp' 'Puente blender-mcp (uv)' 'Deja que Claude controle Blender. Instala uv y el servidor blender-mcp (busca su carpeta en Documents\MCP).')
    )},
    @{ Cat = 'Navegadores y comunicacion'; Items = @(
        (Item 'brave'   'Brave' 'Navegador web (basado en Chromium) con bloqueo de anuncios.')
        (Item 'firefox' 'Firefox' 'Navegador web.')
        (Item 'zoom'    'Zoom' 'Videollamadas y reuniones.')
    )},
    @{ Cat = 'Multimedia y creatividad'; Items = @(
        (Item 'vlc'      'VLC' 'Reproductor de video y audio que abre casi cualquier formato.')
        (Item 'obs'      'OBS Studio' 'Para grabar la pantalla y transmitir en vivo.')
        (Item 'audacity' 'Audacity' 'Editor de audio: grabar, cortar y limpiar sonido.')
        (Item 'capcut'   'CapCut' 'Editor de video.')
        (Item 'adobe'    'Adobe Creative Cloud (Photoshop)' 'Instala Creative Cloud; desde ahi instalas Photoshop con tu cuenta de Adobe.')
        (Item 'flstudio' 'FL Studio' 'Para producir musica. Los plugins se instalan despues desde FL Cloud.')
    )},
    @{ Cat = 'Utilidades y drivers'; Items = @(
        (Item 'winrar' 'WinRAR' 'Para abrir y crear .zip y .rar.')
        (Item 'intel'  'Intel Driver and Support Assistant' 'Busca e instala los drivers de Intel (graficos, red, etc.).')
    )},
    @{ Cat = 'Configuracion'; Items = @(
        (Item 'entorno' 'Variables de entorno y PATH' 'Escribe JAVA_HOME, ANDROID_HOME y agrega platform-tools al PATH.')
    )}
)

$extras = @('brave', 'firefox', 'zoom', 'vlc', 'obs', 'audacity', 'winrar', 'capcut', 'adobe', 'flstudio', 'intel')
# Companeros: al marcar la clave, tambien se marcan estos (y lo que ellos necesiten).
$script:companeros = @{ 'claude' = @('vscodemcp') }

# ---------------------------------------------------------------------
# Detectar lo que ya esta instalado (comprobaciones rapidas, sin red)
# ---------------------------------------------------------------------
function Hay-Comando([string]$n) { return [bool](Get-Command $n -ErrorAction SilentlyContinue) }
function Detectar([string]$id) {
    $pf = $env:ProgramFiles
    switch ($id) {
        'git'        { return (Hay-Comando 'git') }
        'ghcli'      { return ((Hay-Comando 'gh') -or (Test-Path "$pf\GitHub CLI\gh.exe")) }
        'vscode'     { return ((Hay-Comando 'code') -or (Test-Path "$env:LOCALAPPDATA\Programs\Microsoft VS Code\Code.exe")) }
        'node'       { return (Hay-Comando 'node') }
        'python'     { return (Hay-Comando 'py') }
        'dotnet'     { return (Hay-Comando 'dotnet') }
        'jdk17'      { return (@(Get-ChildItem "$pf\Eclipse Adoptium" -Directory -Filter 'jdk-17*' -ErrorAction SilentlyContinue).Count -gt 0) }
        'jdk21'      { return (@(Get-ChildItem "$pf\Eclipse Adoptium" -Directory -Filter 'jdk-21*' -ErrorAction SilentlyContinue).Count -gt 0) }
        'cmake'      { return ((Hay-Comando 'cmake') -or (Test-Path "$pf\CMake")) }
        'llvm'       { return (Test-Path "$pf\LLVM") }
        'msys2'      { return (Test-Path 'C:\msys64') }
        'buildtools' { return ((Test-Path "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer") -and (@(Get-ChildItem "${env:ProgramFiles(x86)}\Microsoft Visual Studio" -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -ne 'Installer' }).Count -gt 0)) }
        'rust'       { return ((Hay-Comando 'rustup') -or (Test-Path "$env:USERPROFILE\.cargo\bin\rustup.exe")) }
        'android'    { return (Test-Path 'C:\Android\android-sdk\platform-tools') }
        'avd'        { return (Test-Path "$env:USERPROFILE\.android\avd\MeshCraftPhone.avd") }
        'blender'    { return (Test-Path "$pf\Blender Foundation") }
        'vlc'        { return (Test-Path "$pf\VideoLAN\VLC") }
        'firefox'    { return (Test-Path "$pf\Mozilla Firefox") }
        'brave'      { return (Test-Path "$pf\BraveSoftware") }
        'obs'        { return (Test-Path "$pf\obs-studio") }
        'audacity'   { return (Test-Path "$pf\Audacity") }
        'winrar'     { return (Test-Path "$pf\WinRAR") }
        'virtualbox' { return (Test-Path "$pf\Oracle\VirtualBox") }
        'claude'     { return (Test-Path "$env:LOCALAPPDATA\AnthropicClaude") }
        default      {
            # Apps de ArtCraft: instaladas si estan clonadas en cualquier carpeta (se reconocen por su origen en git)
            if ($id.StartsWith('gh_') -and $script:artcraftRutas.ContainsKey($id.Substring(3))) { return $true }
            # Repos de GitHub (gh_<repo>): instalado si la carpeta ya es un repositorio git
            if ($id.StartsWith('gh_')) {
                # (las apps de ArtCraft ya se resolvieron arriba, asi que aqui solo quedan tus repos)
                if (Test-Path (Join-Path (Join-Path $script:dirProyectos $id.Substring(3)) '.git')) { return $true }
            }
            return $false
        }
    }
}

# Localizar-Artcraft: {app = ruta} de las apps de ArtCraft ya clonadas, esten en la carpeta que esten.
# Se reconocen solo por su origen en git (github.com/storytold/<app>); el nombre de la carpeta no basta.
function Localizar-Artcraft {
    $repos = @($artcraftGh | ForEach-Object { $_[0] })
    $esc = [Environment]::GetFolderPath('Desktop')
    $docs = [Environment]::GetFolderPath('MyDocuments')
    $encontrados = @{}
    foreach ($base in @($script:dirProgramas, $script:dirProyectos, (Join-Path $esc 'programas'), (Join-Path $esc 'proyectos'), $esc, (Join-Path $docs 'programas'), $docs, $env:USERPROFILE)) {
        if (-not $base) { continue }
        if (-not (Test-Path $base)) { continue }
        foreach ($d in @(Get-ChildItem $base -Directory -ErrorAction SilentlyContinue)) {
            $cfg = Join-Path $d.FullName '.git\config'
            if (-not (Test-Path $cfg)) { continue }
            $txt = Get-Content $cfg -Raw -ErrorAction SilentlyContinue
            if ($txt -match '(?im)\[remote "origin"\][^\[]*?url\s*=\s*\S*github\.com[:/]storytold/([\w.\-]+?)(\.git)?/?\s*$') {
                $r = $Matches[1]
                if (($repos -contains $r) -and -not $encontrados.ContainsKey($r)) { $encontrados[$r] = $d.FullName }
            }
        }
    }
    return $encontrados
}

function Norm([string]$t) {
    # minusculas y sin acentos, para que el buscador no distinga 'edicion' de 'edicion'
    $d = $t.ToLower().Normalize([Text.NormalizationForm]::FormD)
    return ($d -replace '\p{Mn}', '')
}

# ---------------------------------------------------------------------
# Colores y fuentes (tema oscuro)
# ---------------------------------------------------------------------
function Col([int]$r, [int]$g, [int]$b) { return [System.Drawing.Color]::FromArgb($r, $g, $b) }
$cBg = Col 27 28 31;      $cPanel = Col 37 39 43;   $cPanel2 = Col 48 51 56;  $cBorde = Col 58 61 67
$cFg = Col 232 232 234;   $cMuted = Col 157 163 171; $cAcento = Col 79 140 255; $cHover = Col 59 63 70
$cOk = Col 127 209 139;   $cRojo = Col 224 108 117;  $cAmar = Col 229 192 123;  $cCian = Col 86 182 194
$cLog = Col 18 19 22

$fNormal = New-Object System.Drawing.Font('Segoe UI', 9)
$fNegrita = New-Object System.Drawing.Font('Segoe UI', 9, [System.Drawing.FontStyle]::Bold)
$fTitulo = New-Object System.Drawing.Font('Segoe UI', 17, [System.Drawing.FontStyle]::Bold)
$fLog = New-Object System.Drawing.Font('Consolas', 9.5)
$flechaAbierta = [string][char]0x25BE      # flecha hacia abajo
$flechaCerrada = [string][char]0x25B8      # flecha hacia la derecha
$marca = [string][char]0x2714              # palomita

function Estilo-Boton($b, [bool]$acento = $false) {
    $b.FlatStyle = 'Flat'
    $b.FlatAppearance.BorderSize = 1
    $b.Cursor = 'Hand'
    if ($acento) {
        $b.BackColor = $cAcento; $b.ForeColor = [System.Drawing.Color]::White
        $b.FlatAppearance.BorderColor = $cAcento
        $b.FlatAppearance.MouseOverBackColor = (Col 106 160 255)
        $b.Font = $fNegrita
    } else {
        $b.BackColor = $cPanel2; $b.ForeColor = $cFg
        $b.FlatAppearance.BorderColor = $cBorde
        $b.FlatAppearance.MouseOverBackColor = $cHover
    }
}
function Nueva-Etiqueta([string]$texto, $color, $fuente = $null) {
    $l = New-Object System.Windows.Forms.Label
    $l.Text = $texto; $l.ForeColor = $color; $l.AutoSize = $true
    if ($fuente) { $l.Font = $fuente }
    return $l
}

# ---------------------------------------------------------------------
# Estado
# ---------------------------------------------------------------------
$script:cbs = @{}
$script:reqs = @{}
$script:orden = New-Object System.Collections.Generic.List[string]
$script:cats = New-Object System.Collections.Generic.List[object]
$script:instalados = @{}
$script:ajustando = $false
$script:codigo = 3
$script:proc = $null
$script:cancelado = $false
$script:fallos = @()
$script:captura = $false
$script:titulos = 0
$script:total = 1
$script:modo = 'instalar'          # 'instalar' o 'actualizar' (boton Actualizar ArtCraft)
$script:artcraftRutas = @{}        # app de ArtCraft -> carpeta donde esta clonada
# Donde se crean las carpetas de proyectos y de programas (se pueden cambiar en la ventana)
$script:dirProyectos = Join-Path ([Environment]::GetFolderPath('Desktop')) 'proyectos'
$script:dirProgramas = Join-Path ([Environment]::GetFolderPath('Desktop')) 'programas'
$script:pos = @{ out = 0; err = 0 }
$script:resto = @{ out = ''; err = '' }
$script:logOut = Join-Path $env:TEMP 'instalar-todo-salida.log'
$script:logErr = Join-Path $env:TEMP 'instalar-todo-errores.log'

# ---------------------------------------------------------------------
# Ventana principal
# ---------------------------------------------------------------------
$form = New-Object System.Windows.Forms.Form
$form.Text = 'Instalar todo - Windows'
$form.Size = New-Object System.Drawing.Size(980, 760)
$form.MinimumSize = New-Object System.Drawing.Size(780, 520)
$form.StartPosition = 'CenterScreen'
$form.Font = $fNormal
$form.BackColor = $cBg
$form.ForeColor = $cFg

$pSel = New-Object System.Windows.Forms.Panel
$pSel.Dock = 'Fill'
$pProg = New-Object System.Windows.Forms.Panel
$pProg.Dock = 'Fill'
$pProg.Visible = $false
$form.Controls.Add($pSel)
$form.Controls.Add($pProg)

# ============================ PANTALLA 1: SELECCION ============================
$lista = New-Object System.Windows.Forms.FlowLayoutPanel
$lista.Dock = 'Fill'
$lista.FlowDirection = 'TopDown'
$lista.WrapContents = $false
$lista.AutoScroll = $true
$lista.BackColor = $cBg
$lista.Padding = New-Object System.Windows.Forms.Padding(16, 4, 4, 8)
$lista.Add_MouseEnter({ $lista.Focus() | Out-Null })

# -- cabecera
$cab = New-Object System.Windows.Forms.FlowLayoutPanel
$cab.Dock = 'Top'
$cab.AutoSize = $true
$cab.AutoSizeMode = 'GrowAndShrink'
$cab.FlowDirection = 'TopDown'
$cab.WrapContents = $false
$cab.Padding = New-Object System.Windows.Forms.Padding(16, 12, 16, 4)

$lblTitulo = Nueva-Etiqueta 'Instalar todo' $cFg $fTitulo
$lblAyuda = Nueva-Etiqueta 'Marca lo que quieres instalar. Lo que no marques no se toca. Si marcas algo que necesita otro programa, se marca tambien. winget se instala solo si falta.' $cMuted
$lblAyuda.MaximumSize = New-Object System.Drawing.Size(900, 0)
$lblAyuda.Margin = New-Object System.Windows.Forms.Padding(2, 2, 0, 0)

$fila1 = New-Object System.Windows.Forms.FlowLayoutPanel
$fila1.AutoSize = $true; $fila1.WrapContents = $false; $fila1.FlowDirection = 'LeftToRight'
$fila1.Margin = New-Object System.Windows.Forms.Padding(0, 10, 0, 0)
$lb = Nueva-Etiqueta 'Buscar:' $cFg
$lb.Margin = New-Object System.Windows.Forms.Padding(0, 6, 6, 0)
$txtBuscar = New-Object System.Windows.Forms.TextBox
$txtBuscar.Width = 300
$txtBuscar.BackColor = $cPanel2; $txtBuscar.ForeColor = $cFg; $txtBuscar.BorderStyle = 'FixedSingle'
$txtBuscar.Margin = New-Object System.Windows.Forms.Padding(0, 3, 6, 0)
$btnLimpiar = New-Object System.Windows.Forms.Button
$btnLimpiar.Text = 'X'; $btnLimpiar.Size = New-Object System.Drawing.Size(30, 26)
Estilo-Boton $btnLimpiar
$chkOcultar = New-Object System.Windows.Forms.CheckBox
$chkOcultar.Text = 'Ocultar los ya instalados'; $chkOcultar.AutoSize = $true; $chkOcultar.ForeColor = $cFg
$chkOcultar.Margin = New-Object System.Windows.Forms.Padding(24, 5, 0, 0)
$btnPlegar = New-Object System.Windows.Forms.Button
$btnPlegar.Text = 'Plegar todo'; $btnPlegar.Size = New-Object System.Drawing.Size(100, 26)
$btnPlegar.Margin = New-Object System.Windows.Forms.Padding(24, 0, 0, 0)
Estilo-Boton $btnPlegar
$btnDesplegar = New-Object System.Windows.Forms.Button
$btnDesplegar.Text = 'Desplegar todo'; $btnDesplegar.Size = New-Object System.Drawing.Size(110, 26)
Estilo-Boton $btnDesplegar
$fila1.Controls.AddRange(@($lb, $txtBuscar, $btnLimpiar, $chkOcultar, $btnPlegar, $btnDesplegar))

$fila2 = New-Object System.Windows.Forms.FlowLayoutPanel
$fila2.AutoSize = $true; $fila2.WrapContents = $false; $fila2.FlowDirection = 'LeftToRight'
$fila2.Margin = New-Object System.Windows.Forms.Padding(0, 6, 0, 6)
$lr = Nueva-Etiqueta 'Seleccion rapida:' $cFg
$lr.Margin = New-Object System.Windows.Forms.Padding(0, 6, 6, 0)
$fila2.Controls.Add($lr)

# -- carpetas donde se clonan los repos (proyectos y programas)
function Normalizar-Carpeta([string]$ruta, [string]$subcarpeta) {
    $r = $ruta.Trim().Trim('"')
    if ($r -eq '') { return '' }
    try { $r = [IO.Path]::GetFullPath($r) } catch { return $r }
    $r = $r.TrimEnd('\')
    # raiz de un disco (D:\): se usa una subcarpeta, para no clonar todo suelto en el disco
    if ($r -match '^[A-Za-z]:$') { $r = $r + '\' + $subcarpeta }
    return $r
}
function Aplicar-Carpetas {
    $esc = [Environment]::GetFolderPath('Desktop')
    $p = Normalizar-Carpeta $script:txtProy.Text 'proyectos'
    $g = Normalizar-Carpeta $script:txtProg.Text 'programas'
    if ($p -eq '') { $p = Join-Path $esc 'proyectos' }
    if ($g -eq '') { $g = Join-Path $esc 'programas' }
    $script:txtProy.Text = $p
    $script:txtProg.Text = $g
    if (($p -ne $script:dirProyectos) -or ($g -ne $script:dirProgramas)) {
        $script:dirProyectos = $p
        $script:dirProgramas = $g
        Refrescar-Instalados
    }
}
function Nueva-FilaCarpeta([string]$titulo, [string]$valor) {
    $f = New-Object System.Windows.Forms.FlowLayoutPanel
    $f.AutoSize = $true; $f.WrapContents = $false; $f.FlowDirection = 'LeftToRight'
    $f.Margin = New-Object System.Windows.Forms.Padding(0, 4, 0, 0)
    $l = Nueva-Etiqueta $titulo $cFg
    $l.Margin = New-Object System.Windows.Forms.Padding(0, 6, 6, 0)
    $l.AutoSize = $false; $l.Width = 150; $l.Height = 24
    $t = New-Object System.Windows.Forms.TextBox
    $t.Width = 480; $t.Text = $valor
    $t.BackColor = $cPanel2; $t.ForeColor = $cFg; $t.BorderStyle = 'FixedSingle'
    $t.Margin = New-Object System.Windows.Forms.Padding(0, 3, 6, 0)
    $t.Add_Leave({ Aplicar-Carpetas })
    $b = New-Object System.Windows.Forms.Button
    $b.Text = 'Examinar...'; $b.Size = New-Object System.Drawing.Size(100, 26)
    $b.Tag = $t
    Estilo-Boton $b
    $b.Add_Click({
        $caja = $this.Tag
        $dlg = New-Object System.Windows.Forms.FolderBrowserDialog
        $dlg.Description = 'Elige la carpeta (se crea si no existe)'
        $dlg.ShowNewFolderButton = $true
        if ($caja.Text -and (Test-Path $caja.Text)) { $dlg.SelectedPath = $caja.Text }
        if ($dlg.ShowDialog() -eq 'OK') { $caja.Text = $dlg.SelectedPath; Aplicar-Carpetas }
    })
    $f.Controls.AddRange(@($l, $t, $b))
    return @{ Panel = $f; Caja = $t }
}
$filaProy = Nueva-FilaCarpeta 'Carpeta de proyectos:' $script:dirProyectos
$filaProg = Nueva-FilaCarpeta 'Carpeta de programas:' $script:dirProgramas
$script:txtProy = $filaProy.Caja
$script:txtProg = $filaProg.Caja
$lblCarpetas = Nueva-Etiqueta 'Tus repos (norkles505) van a proyectos; las apps de ArtCraft (storytold), a programas. Se crean si no existen.' $cMuted
$lblCarpetas.Margin = New-Object System.Windows.Forms.Padding(2, 8, 0, 0)

$cab.Controls.AddRange(@($lblTitulo, $lblAyuda, $fila1, $fila2, $lblCarpetas, $filaProy.Panel, $filaProg.Panel))

# -- pie
$pie = New-Object System.Windows.Forms.Panel
$pie.Dock = 'Bottom'
$pie.Height = 58
$pie.BackColor = $cPanel
$lblCuenta = Nueva-Etiqueta '' $cFg
$lblCuenta.Location = New-Object System.Drawing.Point(18, 20)
$btnInstalar = New-Object System.Windows.Forms.Button
$btnInstalar.Text = 'Instalar lo marcado'; $btnInstalar.Size = New-Object System.Drawing.Size(180, 36)
Estilo-Boton $btnInstalar $true
$btnCerrar = New-Object System.Windows.Forms.Button
$btnCerrar.Text = 'Cerrar'; $btnCerrar.Size = New-Object System.Drawing.Size(90, 36)
Estilo-Boton $btnCerrar
$botones = New-Object System.Windows.Forms.FlowLayoutPanel
$botones.Dock = 'Right'; $botones.AutoSize = $true; $botones.FlowDirection = 'RightToLeft'; $botones.WrapContents = $false
$botones.Padding = New-Object System.Windows.Forms.Padding(0, 10, 14, 0)
$btnActualizar = New-Object System.Windows.Forms.Button
$btnActualizar.Text = 'Actualizar ArtCraft'; $btnActualizar.Size = New-Object System.Drawing.Size(150, 36)
Estilo-Boton $btnActualizar
$botones.Controls.AddRange(@($btnInstalar, $btnCerrar, $btnActualizar))
$pie.Controls.AddRange(@($lblCuenta, $botones))

# el control que llena el espacio se agrega primero (asi funcionan los Dock de WinForms)
$pSel.Controls.Add($lista)
$pSel.Controls.Add($cab)
$pSel.Controls.Add($pie)

# ---- logica de casillas y dependencias
function Actualizar-Cuenta {
    $n = 0
    foreach ($id in $script:orden) { if ($script:cbs[$id].Checked) { $n++ } }
    $txt = "$n de $($script:orden.Count) marcados"
    if ($script:instalados.Count -gt 0) { $txt += "   -   $($script:instalados.Count) ya instalados" }
    $lblCuenta.Text = $txt
    foreach ($cat in $script:cats) {
        $m = 0
        foreach ($id in $cat.Ids) { if ($script:cbs[$id].Checked) { $m++ } }
        $cat.Cuenta.Text = "$m de $($cat.Ids.Count) marcados"
    }
}
function Marcar-Reqs([string]$id) {
    foreach ($r in $script:reqs[$id]) {
        if (-not $script:cbs[$r].Checked) { $script:cbs[$r].Checked = $true }
        Marcar-Reqs $r
    }
}
function Marcar-Companeros([string]$id) {
    if (-not $script:companeros.ContainsKey($id)) { return }
    foreach ($c in $script:companeros[$id]) {
        if (-not $script:cbs[$c].Checked) { $script:cbs[$c].Checked = $true }
        Marcar-Reqs $c
    }
}
function Desmarcar-Dependientes([string]$id) {
    foreach ($otro in @($script:reqs.Keys)) {
        if (($script:reqs[$otro] -contains $id) -and $script:cbs[$otro].Checked) {
            $script:cbs[$otro].Checked = $false
            Desmarcar-Dependientes $otro
        }
    }
}
function Poner-Seleccion([string[]]$ids) {
    $script:ajustando = $true
    try {
        foreach ($id in $script:orden) { $script:cbs[$id].Checked = ($ids -contains $id) }
        foreach ($id in $script:orden) { if ($script:cbs[$id].Checked) { Marcar-Reqs $id; Marcar-Companeros $id } }
    } finally { $script:ajustando = $false }
    Actualizar-Cuenta
}
function Poner-Grupo([string[]]$ids, [bool]$valor) {
    $script:ajustando = $true
    try {
        foreach ($id in $ids) {
            $script:cbs[$id].Checked = $valor
            if ($valor) { Marcar-Reqs $id; Marcar-Companeros $id } else { Desmarcar-Dependientes $id }
        }
    } finally { $script:ajustando = $false }
    Actualizar-Cuenta
}

# ---- filtrar (buscador, plegar, ocultar instalados)
function Filtrar {
    $q = Norm ($txtBuscar.Text.Trim())
    $ocultar = $chkOcultar.Checked
    $hay = $false
    $lista.SuspendLayout()
    foreach ($cat in $script:cats) {
        $vis = 0
        foreach ($r in $cat.Rows) {
            $ok = $true
            if ($q -ne '' -and -not $r.Texto.Contains($q)) { $ok = $false }
            if ($ocultar -and $script:instalados.ContainsKey($r.Id)) { $ok = $false }
            $r.Ok = $ok
            if ($ok) { $vis++ }
        }
        $abierta = ($q -ne '') -or (-not $cat.Plegada)
        $cat.Header.Visible = ($vis -gt 0)
        if ($vis -gt 0) { $hay = $true }
        foreach ($r in $cat.Rows) { $r.Panel.Visible = ($r.Ok -and $abierta -and ($vis -gt 0)) }
        if ($abierta) { $cat.Flecha.Text = $flechaAbierta } else { $cat.Flecha.Text = $flechaCerrada }
    }
    $lblVacio.Visible = (-not $hay)
    $lista.ResumeLayout()
}
function Alternar-Cat($cat) {
    if ($txtBuscar.Text.Trim() -ne '') { return }
    $cat.Plegada = -not $cat.Plegada
    Filtrar
}
function Plegar-Todo([bool]$plegar) {
    foreach ($cat in $script:cats) { $cat.Plegada = $plegar }
    Filtrar
}
function Reajustar {
    $w = [Math]::Max(420, $lista.ClientSize.Width - 40)
    $lista.SuspendLayout()
    foreach ($cat in $script:cats) {
        $cat.Header.Width = $w
        foreach ($r in $cat.Rows) {
            $r.Panel.Width = $w
            $mx = New-Object System.Drawing.Size(($w - 40), 0)
            $r.Desc.MaximumSize = $mx
            $h = $r.Desc.GetPreferredSize($mx).Height
            $r.Panel.Height = 28 + $h
        }
    }
    $lista.ResumeLayout()
}
function Refrescar-Instalados {
    $env:Path = [Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' + [Environment]::GetEnvironmentVariable('Path', 'User')
    $script:instalados = @{}
    $script:artcraftRutas = Localizar-Artcraft
    foreach ($cat in $script:cats) {
        foreach ($r in $cat.Rows) {
            if (Detectar $r.Id) { $script:instalados[$r.Id] = $true }
            $r.Badge.Visible = $script:instalados.ContainsKey($r.Id)
        }
    }
    Filtrar
    Actualizar-Cuenta
}

# ---- construir la lista
$lblVacio = Nueva-Etiqueta 'Nada coincide con tu busqueda.' $cMuted
$lblVacio.Margin = New-Object System.Windows.Forms.Padding(8, 30, 0, 0)
$lblVacio.Visible = $false

$anchoInicial = 840
foreach ($grupo in $catalogo) {
    $ids = @($grupo.Items | ForEach-Object { $_.Id })
    $cat = @{ Ids = $ids; Rows = (New-Object System.Collections.Generic.List[object]); Plegada = $false }

    $h = New-Object System.Windows.Forms.Panel
    $h.Size = New-Object System.Drawing.Size($anchoInicial, 36)
    $h.BackColor = $cPanel
    $h.Cursor = 'Hand'
    $h.Margin = New-Object System.Windows.Forms.Padding(0, 10, 0, 2)
    $h.Tag = $cat
    $fl = Nueva-Etiqueta $flechaAbierta $cFg $fNegrita
    $fl.Location = New-Object System.Drawing.Point(8, 9)
    $lt = Nueva-Etiqueta $grupo.Cat $cFg $fNegrita
    $lt.Location = New-Object System.Drawing.Point(30, 9)
    $lc = Nueva-Etiqueta '' $cMuted
    $lc.Location = New-Object System.Drawing.Point((30 + $lt.PreferredWidth + 14), 9)
    foreach ($c in @($fl, $lt, $lc)) { $c.Tag = $cat; $c.Cursor = 'Hand' }

    $bN = New-Object System.Windows.Forms.Button
    $bN.Text = 'Ninguno'; $bN.Size = New-Object System.Drawing.Size(76, 26)
    $bN.Location = New-Object System.Drawing.Point(($anchoInicial - 84), 5)
    $bN.Anchor = 'Top, Right'; $bN.Tag = $ids
    Estilo-Boton $bN
    $bN.Add_Click({ Poner-Grupo $this.Tag $false })
    $bT = New-Object System.Windows.Forms.Button
    $bT.Text = 'Todos'; $bT.Size = New-Object System.Drawing.Size(76, 26)
    $bT.Location = New-Object System.Drawing.Point(($anchoInicial - 166), 5)
    $bT.Anchor = 'Top, Right'; $bT.Tag = $ids
    Estilo-Boton $bT
    $bT.Add_Click({ Poner-Grupo $this.Tag $true })

    $h.Controls.AddRange(@($fl, $lt, $lc, $bT, $bN))
    foreach ($c in @($h, $fl, $lt, $lc)) { $c.Add_Click({ Alternar-Cat $this.Tag }) }
    $cat.Header = $h; $cat.Flecha = $fl; $cat.Cuenta = $lc
    $lista.Controls.Add($h)

    foreach ($it in $grupo.Items) {
        $script:orden.Add($it.Id)
        $script:reqs[$it.Id] = $it.Req

        $fila = New-Object System.Windows.Forms.Panel
        $fila.Margin = New-Object System.Windows.Forms.Padding(0, 2, 0, 2)
        $fila.Width = $anchoInicial

        $cb = New-Object System.Windows.Forms.CheckBox
        $cb.Text = $it.Nombre; $cb.Font = $fNegrita; $cb.ForeColor = $cFg
        $cb.AutoSize = $true; $cb.Checked = $false; $cb.Tag = $it.Id
        $cb.Location = New-Object System.Drawing.Point(18, 3)
        $cb.Add_CheckedChanged({
            if ($script:ajustando) { return }
            $script:ajustando = $true
            try {
                if ($this.Checked) { Marcar-Reqs $this.Tag; Marcar-Companeros $this.Tag } else { Desmarcar-Dependientes $this.Tag }
            } finally { $script:ajustando = $false }
            Actualizar-Cuenta
        })
        $script:cbs[$it.Id] = $cb

        $badge = Nueva-Etiqueta "$marca Ya instalado" $cOk $fNegrita
        $badge.Location = New-Object System.Drawing.Point((18 + $cb.PreferredSize.Width + 14), 5)
        $badge.Visible = $false

        $texto = $it.Desc
        if ($it.Req.Count -gt 0) { $texto += '  (Necesita: ' + ($it.Req -join ', ') + ')' }
        $d = Nueva-Etiqueta $texto $cMuted
        $d.Location = New-Object System.Drawing.Point(40, 26)

        $fila.Controls.AddRange(@($cb, $badge, $d))
        $fila.Height = 52
        $cat.Rows.Add(@{ Id = $it.Id; Panel = $fila; Desc = $d; Badge = $badge; Ok = $true; Texto = (Norm "$($it.Nombre) $($it.Desc) $($it.Id)") })
        $lista.Controls.Add($fila)
    }
    $script:cats.Add($cat)
}
$lista.Controls.Add($lblVacio)

# ---- selecciones rapidas
$rapidas = @(
    @{ T = 'Todo';              A = { Poner-Seleccion $script:orden.ToArray() } },
    @{ T = 'Solo desarrollo';   A = { Poner-Seleccion @($script:orden | Where-Object { $extras -notcontains $_ }) } },
    @{ T = 'Solo lo que falta'; A = { Poner-Seleccion @($script:orden | Where-Object { -not $script:instalados.ContainsKey($_) }) } },
    @{ T = 'Nada';              A = { Poner-Seleccion @() } }
)
foreach ($r in $rapidas) {
    $b = New-Object System.Windows.Forms.Button
    $b.Text = $r.T; $b.Size = New-Object System.Drawing.Size(130, 26); $b.Tag = $r.A
    Estilo-Boton $b
    $b.Add_Click({ & $this.Tag })
    $fila2.Controls.Add($b)
}

$txtBuscar.Add_TextChanged({ Filtrar; $lista.AutoScrollPosition = New-Object System.Drawing.Point(0, 0) })
$txtBuscar.Add_KeyDown({ param($s, $e) if ($e.KeyCode -eq 'Escape') { $txtBuscar.Text = '' } })
$btnLimpiar.Add_Click({ $txtBuscar.Text = ''; $txtBuscar.Focus() | Out-Null })
$chkOcultar.Add_CheckedChanged({ Filtrar })
$btnPlegar.Add_Click({ Plegar-Todo $true })
$btnDesplegar.Add_Click({ Plegar-Todo $false })
$lista.Add_Resize({ Reajustar })

# ============================ PANTALLA 2: PROGRESO ============================
$cuerpoP = New-Object System.Windows.Forms.Panel
$cuerpoP.Dock = 'Fill'
$cuerpoP.Padding = New-Object System.Windows.Forms.Padding(16, 6, 16, 6)
$rtb = New-Object System.Windows.Forms.RichTextBox
$rtb.Dock = 'Fill'; $rtb.ReadOnly = $true; $rtb.BackColor = $cLog; $rtb.ForeColor = $cFg
$rtb.Font = $fLog; $rtb.BorderStyle = 'None'; $rtb.WordWrap = $true
$cuerpoP.Controls.Add($rtb)

$cabP = New-Object System.Windows.Forms.Panel
$cabP.Dock = 'Top'; $cabP.Height = 112
$cabP.Padding = New-Object System.Windows.Forms.Padding(16, 12, 16, 4)
$barra = New-Object System.Windows.Forms.ProgressBar
$barra.Dock = 'Top'; $barra.Height = 22; $barra.Style = 'Continuous'
$lblEstado = New-Object System.Windows.Forms.Label
$lblEstado.Dock = 'Top'; $lblEstado.Height = 28; $lblEstado.ForeColor = $cFg
$lblEstado.TextAlign = 'MiddleLeft'
$lblTituloP = New-Object System.Windows.Forms.Label
$lblTituloP.Dock = 'Top'; $lblTituloP.Height = 40; $lblTituloP.Font = $fTitulo; $lblTituloP.ForeColor = $cFg
$lblTituloP.Text = 'Instalando...'
$cabP.Controls.Add($barra)
$cabP.Controls.Add($lblEstado)
$cabP.Controls.Add($lblTituloP)

$pieP = New-Object System.Windows.Forms.Panel
$pieP.Dock = 'Bottom'; $pieP.Height = 58; $pieP.BackColor = $cPanel
$btnCerrar2 = New-Object System.Windows.Forms.Button
$btnCerrar2.Text = 'Cerrar'; $btnCerrar2.Size = New-Object System.Drawing.Size(90, 36)
Estilo-Boton $btnCerrar2
$btnVolver = New-Object System.Windows.Forms.Button
$btnVolver.Text = 'Volver a la lista'; $btnVolver.Size = New-Object System.Drawing.Size(140, 36); $btnVolver.Enabled = $false
Estilo-Boton $btnVolver
$btnCancelar = New-Object System.Windows.Forms.Button
$btnCancelar.Text = 'Cancelar'; $btnCancelar.Size = New-Object System.Drawing.Size(100, 36)
Estilo-Boton $btnCancelar
$botonesP = New-Object System.Windows.Forms.FlowLayoutPanel
$botonesP.Dock = 'Right'; $botonesP.AutoSize = $true; $botonesP.FlowDirection = 'RightToLeft'; $botonesP.WrapContents = $false
$botonesP.Padding = New-Object System.Windows.Forms.Padding(0, 10, 14, 0)
$botonesP.Controls.AddRange(@($btnCerrar2, $btnVolver, $btnCancelar))
$pieP.Controls.Add($botonesP)

$pProg.Controls.Add($cuerpoP)
$pProg.Controls.Add($cabP)
$pProg.Controls.Add($pieP)

# ---- registro en vivo
function Escribir-Log([string]$texto, $color) {
    $rtb.SelectionStart = $rtb.TextLength
    $rtb.SelectionLength = 0
    $rtb.SelectionColor = $color
    $rtb.AppendText($texto + "`n")
    $rtb.SelectionStart = $rtb.TextLength
    $rtb.ScrollToCaret()
}
function Procesar-Linea([string]$t, [bool]$esErr) {
    $t = $t.TrimEnd()
    if ($t.Trim() -eq '') { return }
    # ruido de las barras de progreso de winget
    if ($t -match '[^\x00-\x7F]{3,}') { return }
    if ($t -match '^\s*[\-\\|/]+\s*$') { return }
    if ($t -match '^\s*\d+\s*%\s*$') { return }
    if ($t -match '^\s*[\d\.,]+\s*(KB|MB|GB)\s*/\s*[\d\.,]+\s*(KB|MB|GB)\s*$') { return }

    $color = $cFg
    if ($esErr) { $color = $cRojo }
    elseif ($t -match '^===') {
        $color = $cAmar
        $script:titulos++
        $nombre = $t.Trim('=', ' ')
        $lblEstado.Text = "Paso $($script:titulos): $nombre"
        $barra.Value = [Math]::Min($script:titulos - 1, $barra.Maximum)
    }
    elseif ($t.StartsWith('>>')) { $color = $cCian }
    elseif ($t -match 'Todo se (instalo|actualizo) sin errores') { $color = $cOk }
    elseif ($t -match 'NO SE INSTALO|Error|No se pudo|^!!') { $color = $cRojo }

    if ($t -match 'Esto fallo o hay que hacerlo a mano') { $script:captura = $true; $color = $cRojo }
    elseif ($script:captura) {
        if ($t.StartsWith('  - ')) { $script:fallos += $t.Substring(4); $color = $cRojo } else { $script:captura = $false }
    }
    Escribir-Log $t $color
}
function Leer-Nuevo([string]$ruta, [string]$clave) {
    if (-not (Test-Path $ruta)) { return '' }
    $fs = $null
    try {
        $fs = New-Object System.IO.FileStream($ruta, 'Open', 'Read', 'ReadWrite')
        if ($fs.Length -le $script:pos[$clave]) { return '' }
        [void]$fs.Seek($script:pos[$clave], 'Begin')
        $buf = New-Object byte[] ($fs.Length - $script:pos[$clave])
        $n = $fs.Read($buf, 0, $buf.Length)
        $script:pos[$clave] += $n
        $enc = [Text.Encoding]::GetEncoding([Globalization.CultureInfo]::CurrentCulture.TextInfo.OEMCodePage)
        return $enc.GetString($buf, 0, $n)
    } catch { return '' } finally { if ($fs) { $fs.Dispose() } }
}
function Procesar-Salida([bool]$final = $false) {
    foreach ($par in @(@('out', $script:logOut, $false), @('err', $script:logErr, $true))) {
        $clave = $par[0]
        $nuevo = Leer-Nuevo $par[1] $clave
        $txt = $script:resto[$clave] + $nuevo
        if ($txt -eq '') { continue }
        $partes = @($txt -split "[\r\n]")
        if ($final) {
            $script:resto[$clave] = ''
            foreach ($p in $partes) { Procesar-Linea $p $par[2] }
        } else {
            $script:resto[$clave] = $partes[$partes.Count - 1]
            for ($i = 0; $i -lt ($partes.Count - 1); $i++) { Procesar-Linea $partes[$i] $par[2] }
        }
    }
}

function Mostrar-Pantalla($cual) {
    if ($cual -eq 'sel') { $pProg.Visible = $false; $pSel.Visible = $true }
    else { $pSel.Visible = $false; $pProg.Visible = $true }
}

function Terminar {
    $rc = $script:proc.ExitCode
    $script:codigo = $rc
    $btnCancelar.Enabled = $false
    $btnVolver.Enabled = $true
    Refrescar-Instalados
    if ($script:cancelado) {
        $lblEstado.Text = 'Instalacion cancelada.'
        Escribir-Log '-- Instalacion cancelada --' $cRojo
        return
    }
    $barra.Value = $barra.Maximum
    if ($script:modo -eq 'actualizar') {
        if ($rc -eq 0 -and $script:fallos.Count -eq 0) {
            $lblTituloP.Text = 'Terminado'
            $lblEstado.Text = 'Termino: todas las apps estan actualizadas.'
            [System.Windows.Forms.MessageBox]::Show('Las apps de ArtCraft se actualizaron y compilaron sin errores.', 'Actualizacion terminada') | Out-Null
        } else {
            $lblTituloP.Text = 'Terminado con avisos'
            $lblEstado.Text = 'Termino con avisos. Revisa el registro.'
            if ($script:fallos.Count -gt 0) { $detalle = ($script:fallos | ForEach-Object { "  - $_" }) -join "`n" }
            else { $detalle = "Codigo de salida: $rc" }
            [System.Windows.Forms.MessageBox]::Show("Esto fallo:`n`n$detalle`n`nEl registro tiene el detalle del error.", 'Actualizacion terminada con avisos') | Out-Null
        }
        return
    }
    if ($rc -eq 0 -and $script:fallos.Count -eq 0) {
        $lblTituloP.Text = 'Terminado'
        $lblEstado.Text = 'Termino sin errores. Reinicia la PC.'
        [System.Windows.Forms.MessageBox]::Show("Todo se instalo sin errores.`n`nUltimo paso: reinicia la PC para que el PATH y las variables queden bien. Los pasos pendientes estan al final del registro.", 'Instalacion terminada') | Out-Null
    } else {
        $lblTituloP.Text = 'Terminado con avisos'
        $lblEstado.Text = 'Termino con avisos. Revisa el registro.'
        if ($script:fallos.Count -gt 0) { $detalle = ($script:fallos | ForEach-Object { "  - $_" }) -join "`n" }
        else { $detalle = "Codigo de salida: $rc (mira el mensaje en rojo del registro)" }
        [System.Windows.Forms.MessageBox]::Show("Esto fallo o hay que hacerlo a mano:`n`n$detalle`n`nEl registro tiene el detalle. Si algo falla, copia el mensaje de error.", 'Instalacion terminada con avisos') | Out-Null
    }
}

$timer = New-Object System.Windows.Forms.Timer
$timer.Interval = 400
$timer.Add_Tick({
    Procesar-Salida
    if ($script:proc -and $script:proc.HasExited) {
        $timer.Stop()
        Procesar-Salida $true
        Terminar
    }
})

function Empezar {
    Aplicar-Carpetas
    $sel = @($script:orden | Where-Object { $script:cbs[$_].Checked })
    if ($sel.Count -eq 0) {
        [System.Windows.Forms.MessageBox]::Show('Marca al menos un programa para instalar.', 'Nada marcado') | Out-Null
        return
    }
    $principal = Join-Path $PSScriptRoot 'instalar-todo.ps1'
    if (-not (Test-Path $principal)) {
        [System.Windows.Forms.MessageBox]::Show("No encuentro instalar-todo.ps1 en:`n$PSScriptRoot`n`nCopia la carpeta windows completa.", 'Falta un archivo') | Out-Null
        return
    }
    $resp = [System.Windows.Forms.MessageBox]::Show("Se instalaran $($sel.Count) componentes.`n`nContinuar?", 'Confirmar', 'YesNo', 'Question')
    if ($resp -ne 'Yes') { return }

    Remove-Item $script:logOut, $script:logErr -ErrorAction SilentlyContinue
    $script:pos = @{ out = 0; err = 0 }
    $script:resto = @{ out = ''; err = '' }
    $script:fallos = @(); $script:captura = $false; $script:cancelado = $false; $script:titulos = 0
    # pasos estimados: uno por componente, mas los que hacen un segundo paso, mas el resumen
    $est = $sel.Count + 1
    foreach ($x in @('python', 'node', 'rust')) { if ($sel -contains $x) { $est++ } }
    $script:total = $est
    $script:modo = 'instalar'
    $barra.Maximum = $est; $barra.Value = 0
    $rtb.Clear()
    $lblTituloP.Text = 'Instalando...'
    $lblEstado.Text = 'Iniciando...'
    $btnCancelar.Enabled = $true; $btnVolver.Enabled = $false

    # Primero asegurar-winget.ps1 (consigue winget si falta) y despues instalar-todo.ps1
    $carpetas = ' -CarpetaProyectos "' + $script:dirProyectos + '" -CarpetaProgramas "' + $script:dirProgramas + '"'
    $helper = Join-Path $PSScriptRoot 'asegurar-winget.ps1'
    if (Test-Path $helper) {
        $arg = '-NoProfile -ExecutionPolicy Bypass -File "' + $helper + '" -Siguiente "' + $principal + '" -Solo "' + ($sel -join ',') + '"' + $carpetas
    } else {
        $arg = '-NoProfile -ExecutionPolicy Bypass -File "' + $principal + '" -Solo "' + ($sel -join ',') + '"' + $carpetas
    }
    try {
        $script:proc = Start-Process -FilePath 'powershell.exe' -ArgumentList $arg -WindowStyle Hidden -PassThru -RedirectStandardOutput $script:logOut -RedirectStandardError $script:logErr
        $null = $script:proc.Handle      # para poder leer el ExitCode despues
    } catch {
        [System.Windows.Forms.MessageBox]::Show("No se pudo iniciar la instalacion:`n$($_.Exception.Message)", 'Error') | Out-Null
        return
    }
    Mostrar-Pantalla 'prog'
    $timer.Start()
}

function Actualizar-Artcraft {
    Aplicar-Carpetas
    Refrescar-Instalados
    # {app = ruta}: busca cada app donde este (programas, proyectos, Escritorio, Documentos, carpeta personal)
    $rutas = $script:artcraftRutas
    $presentes = @($artcraftGh | Where-Object { $rutas.ContainsKey($_[0]) } | ForEach-Object { $_[0] })
    if ($presentes.Count -eq 0) {
        [System.Windows.Forms.MessageBox]::Show("No encontre ninguna app de ArtCraft clonada (busque en programas, proyectos, el Escritorio, Documentos y tu carpeta personal).`n`nInstalalas primero desde la lista.", 'Nada que actualizar') | Out-Null
        return
    }
    $ps1 = Join-Path $PSScriptRoot 'actualizar-artcraft.ps1'
    if (-not (Test-Path $ps1)) {
        [System.Windows.Forms.MessageBox]::Show("No encuentro actualizar-artcraft.ps1 en:`n$PSScriptRoot`n`nCopia la carpeta windows completa.", 'Falta un archivo') | Out-Null
        return
    }
    $resp = [System.Windows.Forms.MessageBox]::Show("Se actualizaran y recompilaran $($presentes.Count) apps de ArtCraft, cada una en la carpeta donde esta clonada.`n`nSolo se recompilan las que tengan cambios nuevos, pero compilar en Rust puede tardar varios minutos.`n`nContinuar?", 'Actualizar ArtCraft', 'YesNo', 'Question')
    if ($resp -ne 'Yes') { return }

    Remove-Item $script:logOut, $script:logErr -ErrorAction SilentlyContinue
    $script:pos = @{ out = 0; err = 0 }
    $script:resto = @{ out = ''; err = '' }
    $script:fallos = @(); $script:captura = $false; $script:cancelado = $false; $script:titulos = 0
    $script:modo = 'actualizar'
    $script:total = $presentes.Count + 1      # una por app, mas el resumen
    $barra.Maximum = $script:total; $barra.Value = 0
    $rtb.Clear()
    $lblTituloP.Text = 'Actualizando ArtCraft...'
    $lblEstado.Text = 'Iniciando...'
    $btnCancelar.Enabled = $true; $btnVolver.Enabled = $false

    $arg = '-NoProfile -ExecutionPolicy Bypass -File "' + $ps1 + '"'
    foreach ($p in $presentes) { $arg += ' "' + $p + '=' + $rutas[$p] + '"' }
    try {
        $script:proc = Start-Process -FilePath 'powershell.exe' -ArgumentList $arg -WindowStyle Hidden -PassThru -RedirectStandardOutput $script:logOut -RedirectStandardError $script:logErr
        $null = $script:proc.Handle
    } catch {
        [System.Windows.Forms.MessageBox]::Show("No se pudo iniciar la actualizacion:`n$($_.Exception.Message)", 'Error') | Out-Null
        return
    }
    Mostrar-Pantalla 'prog'
    $timer.Start()
}

$btnInstalar.Add_Click({ Empezar })
$btnActualizar.Add_Click({ Actualizar-Artcraft })
$btnCerrar.Add_Click({ $form.Close() })
$btnCerrar2.Add_Click({ $form.Close() })
$btnVolver.Add_Click({ Mostrar-Pantalla 'sel' })
$btnCancelar.Add_Click({
    if ($script:proc -and -not $script:proc.HasExited) {
        $r = [System.Windows.Forms.MessageBox]::Show('Detener la instalacion? Lo que ya se instalo se queda.', 'Cancelar', 'YesNo', 'Question')
        if ($r -eq 'Yes') {
            $script:cancelado = $true
            & taskkill.exe /PID $script:proc.Id /T /F | Out-Null
        }
    }
})
$form.Add_FormClosing({
    param($s, $e)
    if ($script:proc -and -not $script:proc.HasExited) {
        $r = [System.Windows.Forms.MessageBox]::Show('Todavia se esta instalando. Detenerla y salir?', 'Instalacion en curso', 'YesNo', 'Question')
        if ($r -ne 'Yes') { $e.Cancel = $true; return }
        & taskkill.exe /PID $script:proc.Id /T /F | Out-Null
    }
})
$form.Add_Shown({ Reajustar; Refrescar-Instalados; $txtBuscar.Focus() | Out-Null })

[void]$form.ShowDialog()
exit $script:codigo