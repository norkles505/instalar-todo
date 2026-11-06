# =====================================================================
# instalar-todo.ps1  -  Reinstala el entorno de desarrollo en Windows
#
# LO MAS FACIL: doble clic en INSTALAR-TODO.bat (abre una ventana donde marcas lo que quieres).
#
# Desde PowerShell COMO ADMINISTRADOR (en la carpeta de este script):
#   powershell -ExecutionPolicy Bypass -File .\instalar-todo.ps1                    -> instala TODO
#   powershell -ExecutionPolicy Bypass -File .\instalar-todo.ps1 -SoloDesarrollo    -> sin los programas extra
#   powershell -ExecutionPolicy Bypass -File .\instalar-todo.ps1 -SinProyectos      -> sin clonar los repos de GitHub
#   powershell -ExecutionPolicy Bypass -File .\instalar-todo.ps1 -Solo vscode,node,python
#                                      -> SOLO esos componentes (los ids estan en instalar-todo-gui.ps1)
#   powershell -ExecutionPolicy Bypass -File .\instalar-todo.ps1 -CarpetaProyectos D:\proyectos -CarpetaProgramas D:\programas
#                                      -> clona los repos en esas carpetas (por defecto: Escritorio\proyectos y Escritorio\programas)
#   (Para guardar y restaurar tus claves y ajustes al formatear: respaldo.ps1)
#
# Si falta winget, intenta instalarlo solo. Al final muestra una lista de lo que fallo.
# Codigos de salida: 0 = todo bien, 2 = termino con avisos, 1 = se detuvo antes de empezar.
# =====================================================================
param([switch]$SoloDesarrollo, [switch]$SinProyectos, [string]$Solo = '', [string]$CarpetaProyectos = '', [string]$CarpetaProgramas = '')

$esAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $esAdmin) {
    Write-Host "Ejecuta este script como Administrador." -ForegroundColor Red
    exit 1
}

# winget es lo que instala todos los programas. Si falta, se intenta instalar solo.
function Probar-Winget {
    if (Get-Command winget -ErrorAction SilentlyContinue) { return $true }
    # A veces winget existe pero su carpeta no esta en el PATH de esta consola
    $wa = Join-Path $env:LOCALAPPDATA 'Microsoft\WindowsApps'
    if (Test-Path (Join-Path $wa 'winget.exe')) {
        $env:Path = $env:Path + ';' + $wa
        if (Get-Command winget -ErrorAction SilentlyContinue) { return $true }
    }
    return $false
}

function Asegurar-Winget {
    if (Probar-Winget) { return $true }

    # winget solo existe en Windows 10 version 1809 (build 17763) o mas nuevo
    if ([Environment]::OSVersion.Version.Build -lt 17763) {
        Write-Host "Tu Windows es demasiado viejo para winget (se necesita Windows 10 1809 o mas nuevo). Actualiza Windows primero." -ForegroundColor Red
        return $false
    }

    Write-Host "No se encontro winget. Intentando instalar 'App Installer' automaticamente..." -ForegroundColor Yellow
    $ProgressPreference = 'SilentlyContinue'     # acelera las descargas
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $arq = if ($env:PROCESSOR_ARCHITECTURE -eq 'ARM64') { 'arm64' } else { 'x64' }
    $tmp = Join-Path $env:TEMP 'winget-instalacion'
    New-Item -ItemType Directory $tmp -Force | Out-Null

    # Intento 1: App Installer ya viene con Windows pero no esta registrado
    try {
        Add-AppxPackage -RegisterByFamilyName -MainPackage 'Microsoft.DesktopAppInstaller_8wekyb3d8bbwe' -ErrorAction Stop
    } catch { }
    if (Probar-Winget) { Write-Host "winget quedo listo." -ForegroundColor Green; return $true }

    # Intento 2: descargar el paquete oficial de Microsoft e instalarlo
    try {
        $bundle = Join-Path $tmp 'AppInstaller.msixbundle'
        Invoke-WebRequest 'https://aka.ms/getwinget' -OutFile $bundle -UseBasicParsing
        try {
            Add-AppxPackage -Path $bundle -ErrorAction Stop
        } catch {
            # Probablemente faltan dependencias (VCLibs / UI.Xaml): se descargan y se reintenta
            Write-Host "Faltan dependencias de winget, descargandolas..." -ForegroundColor DarkYellow
            $deps = @()
            $vc = Join-Path $tmp "VCLibs.$arq.appx"
            Invoke-WebRequest "https://aka.ms/Microsoft.VCLibs.$arq.14.00.Desktop.appx" -OutFile $vc -UseBasicParsing
            $deps += $vc
            try {
                $xaml = Join-Path $tmp "UIXaml.$arq.appx"
                Invoke-WebRequest "https://github.com/microsoft/microsoft-ui-xaml/releases/download/v2.8.6/Microsoft.UI.Xaml.2.8.$arq.appx" -OutFile $xaml -UseBasicParsing
                $deps += $xaml
            } catch { }
            Add-AppxPackage -Path $bundle -DependencyPath $deps -ErrorAction Stop
        }
    } catch {
        Write-Host "No se pudo instalar winget automaticamente: $($_.Exception.Message)" -ForegroundColor DarkYellow
    }
    if (Probar-Winget) { Write-Host "winget quedo listo." -ForegroundColor Green; return $true }
    return $false
}

$wingetListo = Asegurar-Winget | Select-Object -Last 1
if ($wingetListo -ne $true) {
    Write-Host ""
    Write-Host "NO SE INSTALO NINGUN PROGRAMA: no se pudo conseguir winget." -ForegroundColor Red
    Write-Host "Hazlo a mano y vuelve a ejecutar este script:" -ForegroundColor Red
    Write-Host "  1. Abre la Microsoft Store, busca 'Instalador de aplicacion' (App Installer) e instalalo o actualizalo."
    Write-Host "  2. Si no tienes Microsoft Store, descarga el archivo .msixbundle de https://github.com/microsoft/winget-cli/releases"
    Write-Host "     e instalalo con doble clic."
    Write-Host "  3. Cierra esta ventana, abre otra y comprueba con:  winget --version"
    exit 1
}

$fallos = New-Object System.Collections.Generic.List[string]
$script:instalados = 0

# ---------------------------------------------------------------------
# Que componentes se instalan
#   -Solo id1,id2  -> solo esos.   Sin -Solo -> todo (menos extras con -SoloDesarrollo, menos GitHub con -SinProyectos)
# ---------------------------------------------------------------------
$usarLista = $PSBoundParameters.ContainsKey('Solo')
$listaSolo = @()
if ($usarLista) { $listaSolo = @($Solo -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ }) }
$extras = @('brave', 'firefox', 'zoom', 'vlc', 'obs', 'audacity', 'winrar', 'capcut', 'adobe', 'flstudio', 'intel')

function Quiero([string]$id) {
    if ($usarLista) {
        if ($listaSolo -contains $id) { return $true }
        # compatibilidad: 'github' (el id viejo) marca todos los repos
        if ($id.StartsWith('gh_') -and ($listaSolo -contains 'github')) { return $true }
        # compatibilidad: 'java' y 'build' (ids viejos) marcan todos sus programas
        if (($id -eq 'jdk17' -or $id -eq 'jdk21') -and ($listaSolo -contains 'java')) { return $true }
        if (@('cmake', 'llvm', 'msys2', 'buildtools') -contains $id -and ($listaSolo -contains 'build')) { return $true }
        return $false
    }
    if ($SoloDesarrollo -and ($extras -contains $id)) { return $false }
    if ($SinProyectos -and ($id -eq 'github' -or $id.StartsWith('gh_'))) { return $false }
    return $true
}

# Prueba cada ID en orden hasta que uno instale (o ya este instalado).
function Instalar([string]$nombre, [string[]]$ids, [string]$override = '') {
    foreach ($id in $ids) {
        Write-Host ">> $nombre  ($id)" -ForegroundColor Cyan
        $wargs = @('install', '--id', $id, '-e', '--silent', '--accept-package-agreements', '--accept-source-agreements')
        if ($override) { $wargs += @('--override', $override) }
        & winget @wargs
        # 0 = ok, -1978335189 = ya instalado / sin actualizacion aplicable
        if ($LASTEXITCODE -eq 0 -or $LASTEXITCODE -eq -1978335189) { $script:instalados++; return }
    }
    $fallos.Add($nombre)
}

function Refrescar-Path {
    $env:Path = [Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' + [Environment]::GetEnvironmentVariable('Path', 'User')
}

function Titulo([string]$t) { Write-Host "`n=== $t ===" -ForegroundColor Yellow }

function Get-CodePath {
    $c = Get-Command code -ErrorAction SilentlyContinue
    if ($c) { return $c.Source }
    return "$env:LOCALAPPDATA\Programs\Microsoft VS Code\bin\code.cmd"
}

$escritorio = [Environment]::GetFolderPath('Desktop')
# Donde se crean las carpetas "proyectos" (tus repos) y "programas" (apps de ArtCraft).
# Por defecto en el Escritorio; la ventana (o -CarpetaProyectos / -CarpetaProgramas) puede cambiarlas.
$proyDir = Join-Path $escritorio 'proyectos'
$progDir = Join-Path $escritorio 'programas'
if ($CarpetaProyectos.Trim() -ne '') { $proyDir = $CarpetaProyectos.Trim() }
if ($CarpetaProgramas.Trim() -ne '') { $progDir = $CarpetaProgramas.Trim() }
Write-Host "Carpeta de proyectos: $proyDir"
Write-Host "Carpeta de programas: $progDir"
$mcpRoot = Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'MCP'

# ---------------------------------------------------------------------
# Programas de desarrollo
# ---------------------------------------------------------------------
if (Quiero 'git')      { Titulo 'Git';                          Instalar 'Git' @('Git.Git') }
if (Quiero 'ghcli')    { Titulo 'GitHub CLI (gh)';              Instalar 'GitHub CLI' @('GitHub.cli') }
if (Quiero 'dotnet')   { Titulo '.NET SDK 10';                  Instalar '.NET SDK 10' @('Microsoft.DotNet.SDK.10') }
if (Quiero 'jdk17')    { Titulo 'JDK 17 (Temurin)';             Instalar 'JDK 17 (Temurin)' @('EclipseAdoptium.Temurin.17.JDK') }
if (Quiero 'jdk21')    { Titulo 'JDK 21 (Temurin)';             Instalar 'JDK 21 (Temurin)' @('EclipseAdoptium.Temurin.21.JDK') }
if (Quiero 'vscode')   { Titulo 'Visual Studio Code';           Instalar 'VS Code' @('Microsoft.VisualStudioCode') }
if (Quiero 'claude')   { Titulo 'Claude Desktop';               Instalar 'Claude Desktop' @('Anthropic.Claude') }
if (Quiero 'node')     { Titulo 'Node.js (LTS)';                Instalar 'Node.js (LTS)' @('OpenJS.NodeJS.LTS') }
if (Quiero 'python')   { Titulo 'Python 3.13';                  Instalar 'Python 3.13' @('Python.Python.3.13') }
if (Quiero 'cmake')    { Titulo 'CMake';                        Instalar 'CMake' @('Kitware.CMake') }
if (Quiero 'llvm')     { Titulo 'LLVM (Clang)';                 Instalar 'LLVM'  @('LLVM.LLVM') }
if (Quiero 'msys2')    { Titulo 'MSYS2';                        Instalar 'MSYS2' @('MSYS2.MSYS2') }
if (Quiero 'buildtools') {
    Titulo 'Visual Studio Build Tools (C++)'
    Instalar 'Visual Studio Build Tools (C++)' @('Microsoft.VisualStudio.BuildTools', 'Microsoft.VisualStudio.2022.BuildTools') '--passive --wait --add Microsoft.VisualStudio.Workload.VCTools --includeRecommended'
}
if (Quiero 'rust')     { Titulo 'Rust (rustup)';                Instalar 'Rustup' @('Rustlang.Rustup') }
if (Quiero 'php')      { Titulo 'PHP 8.3';                      Instalar 'PHP 8.3' @('PHP.PHP.8.3') }
if (Quiero 'xampp')    { Titulo 'XAMPP';                        Instalar 'XAMPP' @('ApacheFriends.Xampp.8.2', 'ApacheFriends.Xampp.8.0') }
if (Quiero 'blender')  { Titulo 'Blender';                      Instalar 'Blender' @('BlenderFoundation.Blender') }
if (Quiero 'unity')    { Titulo 'Unity Hub';                    Instalar 'Unity Hub' @('Unity.UnityHub') }
if (Quiero 'virtualbox') { Titulo 'VirtualBox';                 Instalar 'VirtualBox' @('Oracle.VirtualBox') }

# ---------------------------------------------------------------------
# Programas de uso diario / creativos (cada uno se elige por separado;
# con -SoloDesarrollo se saltan todos)
# ---------------------------------------------------------------------
if (Quiero 'brave')    { Titulo 'Brave';                        Instalar 'Brave' @('Brave.Brave') }
if (Quiero 'firefox')  { Titulo 'Firefox';                      Instalar 'Firefox' @('Mozilla.Firefox') }
if (Quiero 'zoom')     { Titulo 'Zoom';                         Instalar 'Zoom' @('Zoom.Zoom') }
if (Quiero 'vlc')      { Titulo 'VLC';                          Instalar 'VLC' @('VideoLAN.VLC') }
if (Quiero 'obs')      { Titulo 'OBS Studio';                   Instalar 'OBS Studio' @('OBSProject.OBSStudio') }
if (Quiero 'audacity') { Titulo 'Audacity';                     Instalar 'Audacity' @('Audacity.Audacity') }
if (Quiero 'winrar')   { Titulo 'WinRAR';                       Instalar 'WinRAR' @('RARLab.WinRAR') }
if (Quiero 'capcut')   { Titulo 'CapCut';                       Instalar 'CapCut' @('ByteDance.CapCut') }
if (Quiero 'adobe')    { Titulo 'Adobe Creative Cloud';         Instalar 'Adobe Creative Cloud (para Photoshop)' @('Adobe.CreativeCloud') }
if (Quiero 'flstudio') { Titulo 'FL Studio';                    Instalar 'FL Studio' @('ImageLine.FLStudio') }
if (Quiero 'intel')    { Titulo 'Intel Driver and Support Assistant'; Instalar 'Intel Driver and Support Assistant' @('Intel.IntelDriverAndSupportAssistant') }

Refrescar-Path

$jdk17 = Get-ChildItem 'C:\Program Files\Eclipse Adoptium' -Directory -Filter 'jdk-17*' -ErrorAction SilentlyContinue | Select-Object -First 1
$jdk21 = Get-ChildItem 'C:\Program Files\Eclipse Adoptium' -Directory -Filter 'jdk-21*' -ErrorAction SilentlyContinue | Select-Object -First 1

# ---------------------------------------------------------------------
# Variables de entorno y PATH
# ---------------------------------------------------------------------
if (Quiero 'entorno') {
    Titulo 'Variables de entorno'
    if ($jdk21) { [Environment]::SetEnvironmentVariable('JAVA_HOME', $jdk21.FullName, 'User'); Write-Host "JAVA_HOME = $($jdk21.FullName)" }
    [Environment]::SetEnvironmentVariable('ANDROID_HOME', 'C:\Android\android-sdk', 'User')
    Write-Host "ANDROID_HOME = C:\Android\android-sdk"

    $ptools = 'C:\Android\android-sdk\platform-tools'
    $pathUsuario = [Environment]::GetEnvironmentVariable('Path', 'User')
    if ($pathUsuario -notlike "*$ptools*") {
        [Environment]::SetEnvironmentVariable('Path', ($pathUsuario.TrimEnd(';') + ';' + $ptools), 'User')
        Write-Host "platform-tools agregado al PATH"
    }
    Refrescar-Path
}

# ---------------------------------------------------------------------
# Android SDK (C:\Android\android-sdk)  - sin Android Studio, solo SDK
# ---------------------------------------------------------------------
if (Quiero 'android') {
    Titulo 'Android SDK + emulador'
    $sdk = 'C:\Android\android-sdk'
    $cmdLatest = "$sdk\cmdline-tools\latest"
    $sdkmanager = "$cmdLatest\bin\sdkmanager.bat"
    try {
        if (-not (Test-Path $sdkmanager)) {
            # Si este enlace deja de funcionar, baja "Command line tools only" desde
            # https://developer.android.com/studio#command-line-tools-only y
            # descomprimelo para que quede: C:\Android\android-sdk\cmdline-tools\latest\bin
            $zip = "$env:TEMP\cmdline-tools.zip"
            $tmp = "$env:TEMP\cmdline-tools-tmp"
            Invoke-WebRequest 'https://dl.google.com/android/repository/commandlinetools-win-11076708_latest.zip' -OutFile $zip
            if (Test-Path $tmp) { Remove-Item $tmp -Recurse -Force }
            Expand-Archive $zip $tmp -Force
            New-Item -ItemType Directory "$sdk\cmdline-tools" -Force | Out-Null
            Move-Item "$tmp\cmdline-tools" $cmdLatest -Force
        }
        # sdkmanager necesita Java
        if ($jdk17) { $env:JAVA_HOME = $jdk17.FullName } elseif ($jdk21) { $env:JAVA_HOME = $jdk21.FullName }

        $paquetes = @(
            'platform-tools',
            'platforms;android-34', 'platforms;android-36',
            'build-tools;34.0.0', 'build-tools;35.0.0',
            'emulator',
            'ndk;27.0.12077973', 'ndk;29.0.14206865',
            'cmake;3.22.1', 'cmake;4.0.2',
            'system-images;android-34;google_apis;x86_64'
        )
        1..40 | ForEach-Object { 'y' } | & $sdkmanager "--sdk_root=$sdk" --licenses | Out-Null
        & $sdkmanager "--sdk_root=$sdk" @paquetes
        if ($LASTEXITCODE -ne 0) { $fallos.Add('Android SDK (algun paquete de sdkmanager fallo)') }
    } catch {
        Write-Host "Error con el Android SDK: $($_.Exception.Message)" -ForegroundColor Red
        $fallos.Add('Android SDK')
    }
}

# ---------------------------------------------------------------------
# Python (paquetes), npm y extensiones de VS Code
# ---------------------------------------------------------------------
if (Quiero 'python') {
    Titulo 'Python: paquetes'
    try {
        py -3.13 -m pip install --upgrade pip
        # mcp<2: con mcp 2.x el servidor vscode-mcp no arranca (ya no existe mcp.server.fastmcp)
        py -3.13 -m pip install PySide6 pillow pyinstaller 'mcp<2' yt-dlp requests pywin32 static-ffmpeg imageio-ffmpeg twine python-dotenv uvicorn
        if ($LASTEXITCODE -ne 0) { $fallos.Add('Paquetes de Python (fallo pip install)') }
    } catch { $fallos.Add('Paquetes de Python') }
}

if (Quiero 'node') {
    Titulo 'Node.js: herramientas npm globales'
    try {
        npm install -g '@vscode/vsce' 'rea-agents@6.4.0'
        if ($LASTEXITCODE -ne 0) { $fallos.Add('npm global (vsce / rea-agents)') }
    } catch { $fallos.Add('npm global') }
}

if (Quiero 'vscodeext') {
    Titulo 'Extensiones de VS Code'
    $code = Get-CodePath
    if (Test-Path $code) {
        $ext = @(
            'chadalen.vscode-jetbrains-icon-theme',
            'monokai.theme-monokai-pro-vscode',
            'ms-python.debugpy', 'ms-python.python', 'ms-python.vscode-pylance', 'ms-python.vscode-python-envs',
            'redhat.java',
            'vscjava.vscode-gradle', 'vscjava.vscode-java-debug', 'vscjava.vscode-java-dependency',
            'vscjava.vscode-java-pack', 'vscjava.vscode-java-test', 'vscjava.vscode-maven'
        )
        foreach ($e in $ext) { & $code --install-extension $e --force | Out-Null; Write-Host "extension: $e" }
    } else {
        $fallos.Add('Extensiones de VS Code (no se encontro el comando code)')
    }
}

# ---------------------------------------------------------------------
# Rust estable
# ---------------------------------------------------------------------
if (Quiero 'rust') {
    if (Get-Command rustup -ErrorAction SilentlyContinue) {
        Titulo 'Rust: toolchain estable'
        try {
            rustup default stable
            if ($LASTEXITCODE -ne 0) { $fallos.Add('Rust: rustup default stable (hazlo a mano si cargo no funciona)') }
        } catch { $fallos.Add('Rust: rustup default stable') }
    }
}

# ---------------------------------------------------------------------
# Proyectos de GitHub (tus repos en <Escritorio>\proyectos; las de ArtCraft en <Escritorio>\programas)
# Va antes de los ajustes y de los puentes MCP, que buscan drawengine y vs-code-mcp ahi.
# Si cambias esta lista, cambia tambien GH_PROYECTOS en linux\instalar-todo.sh.
# Los de storytold son las alternativas open source de ArtCraft: solo se clona el codigo,
# se compilan a mano con cargo (Rustup + Visual Studio Build Tools C++ se instalan arriba).
# ---------------------------------------------------------------------
# Devuelve $true si hay al menos un repo de GitHub elegido (ids gh_<repo>, o 'github' = todos)
function Quiero-Repos {
    if ($usarLista) { return (@($listaSolo | Where-Object { $_ -like 'gh_*' -or $_ -eq 'github' }).Count -gt 0) }
    return (-not $SinProyectos)
}
if (Quiero-Repos) {
    # (cada repo muestra su propio titulo, para que la ventana cuente un paso por repo)
    $ghProyectos = @(
        'norkles505/paintcraft', 'norkles505/meshcraft', 'norkles505/keyboardmovil', 'norkles505/YTDownloader',
        'norkles505/ar-drawing', 'norkles505/paintcraft-PC', 'norkles505/drawengine', 'norkles505/dont-cut-that',
        'norkles505/vs-code-mcp', 'norkles505/nodo-capture', 'norkles505/instalar-todo', 'norkles505/dontcutthat', 'norkles505/gitcraft', 'norkles505/texturecraft',
        'storytold/photocraft', 'storytold/vectorcraft', 'storytold/filmcraft', 'storytold/lightcraft',
        'storytold/pdfcraft', 'storytold/effectcraft', 'storytold/designcraft', 'storytold/wordcraft',
        'storytold/soundcraft', 'storytold/deckcraft', 'storytold/cadcraft', 'storytold/gridcraft',
        'storytold/figcraft', 'storytold/texturecraft', 'storytold/materialcraft', 'storytold/craft-anything'
    )
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
        $fallos.Add('Proyectos de GitHub (git no esta instalado)')
    } else {
        New-Item -ItemType Directory $proyDir -Force | Out-Null
        # Si un repo es privado o no existe, que falle en vez de quedarse pidiendo usuario
        $env:GIT_TERMINAL_PROMPT = '0'
        foreach ($p in $ghProyectos) {
            $repo = $p.Split('/')[1]
            # tu texturecraft (norkles505) se llama igual que la de ArtCraft (storytold): lleva un id aparte
            $idRepo = 'gh_' + $repo
            if ($p -eq 'norkles505/texturecraft') { $idRepo = 'gh_norkles505-texturecraft' }
            if (-not (Quiero $idRepo)) { continue }
            Titulo "Clonar $repo"
            # Las alternativas de ArtCraft (storytold) van a "programas"; tus repos, a "proyectos"
            $base = if ($p.StartsWith('storytold/')) { $progDir } else { $proyDir }
            New-Item -ItemType Directory $base -Force | Out-Null
            $destino = Join-Path $base $repo
            if (Test-Path (Join-Path $destino '.git')) {
                Write-Host "Ya esta descargado, no se toca: $destino"
                continue
            }
            if (Test-Path $destino) {
                Write-Host "Ya existe $destino pero no es un repositorio git. No se toca." -ForegroundColor DarkYellow
                $fallos.Add("Clonar $p (la carpeta ya existe y no es un repositorio)")
                continue
            }
            Write-Host ">> Clonar $p" -ForegroundColor Cyan
            git clone "https://github.com/$p.git" $destino
            if ($LASTEXITCODE -ne 0) { $fallos.Add("Clonar $p") }
        }
    }
}

# ---------------------------------------------------------------------
# Ajustes de los proyectos
# ---------------------------------------------------------------------
if (Quiero 'ajustes') {
    Titulo 'Ajustes de los proyectos'
    $proy = @($proyDir, (Split-Path -Parent $PSScriptRoot)) | Where-Object { $_ -and (Test-Path "$_\drawengine") } | Select-Object -First 1
    if (-not $proy) {
        Write-Host "No encontre la carpeta proyectos (con drawengine dentro). Restaurala y vuelve a ejecutar este script." -ForegroundColor Red
        $fallos.Add('Carpeta proyectos no encontrada (no se hizo el venv ni el ajuste del JDK)')
    } else {
        # a) Entorno virtual de drawengine
        try {
            $venv = "$proy\drawengine\venv"
            if (Test-Path $venv) { Remove-Item $venv -Recurse -Force }
            py -3.13 -m venv $venv
            & "$venv\Scripts\python.exe" -m pip install --upgrade pip
            & "$venv\Scripts\python.exe" -m pip install -r "$proy\drawengine\requirements.txt"
            if ($LASTEXITCODE -ne 0) { $fallos.Add('venv de drawengine (fallo pip install)') }
        } catch { $fallos.Add('venv de drawengine') }

        # b) Los compilar.bat tienen fija la version del JDK 17: se ajusta a la que quedo instalada
        try {
            $j17 = Get-ChildItem 'C:\Program Files\Eclipse Adoptium' -Directory -Filter 'jdk-17*' -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($j17) {
                Get-ChildItem $proy -Recurse -Filter compilar.bat -ErrorAction SilentlyContinue | Where-Object { $_.FullName -notmatch '\\(build|dist|venv)\\' } | ForEach-Object {
                    $txt = [IO.File]::ReadAllText($_.FullName)
                    $nuevo = $txt -replace 'jdk-17[0-9.]*-hotspot', $j17.Name
                    if ($nuevo -ne $txt) {
                        [IO.File]::WriteAllText($_.FullName, $nuevo, (New-Object Text.UTF8Encoding($false)))
                        Write-Host "JDK 17 ajustado en $($_.FullName)"
                    }
                }
            } else { $fallos.Add('No se encontro el JDK 17 para ajustar los compilar.bat') }
        } catch { $fallos.Add('Ajuste de la ruta del JDK 17 en los compilar.bat') }
    }
}

# ---------------------------------------------------------------------
# Puentes MCP
# ---------------------------------------------------------------------
# Puente vscode-mcp: servidor (pip) + extension de VS Code (.vsix)
if (Quiero 'vscodemcp') {
    Titulo 'Puente vscode-mcp (servidor + extension)'
    try {
        # Si el repo no esta (por ejemplo no marcaste "Clonar tus repos"), se descarga solo
        $repoMcp = Join-Path $proyDir 'vs-code-mcp'
        if (-not (Test-Path $repoMcp) -and -not (Test-Path (Join-Path $mcpRoot 'vscode-mcp\server'))) {
            if (Get-Command git -ErrorAction SilentlyContinue) {
                New-Item -ItemType Directory $proyDir -Force | Out-Null
                $env:GIT_TERMINAL_PROMPT = '0'
                Write-Host ">> Clonar norkles505/vs-code-mcp" -ForegroundColor Cyan
                git clone 'https://github.com/norkles505/vs-code-mcp.git' $repoMcp
            } else {
                Write-Host "git no esta disponible: no se puede descargar vs-code-mcp." -ForegroundColor DarkYellow
            }
        }
        $serv = @((Join-Path $proyDir 'vs-code-mcp\windows\server'), (Join-Path $mcpRoot 'vscode-mcp\server')) | Where-Object { Test-Path $_ } | Select-Object -First 1
        if ($serv) {
            py -3.13 -m pip install -e $serv
            # El servidor necesita mcp 1.x: se fuerza por si su pyproject trajo mcp 2.x
            py -3.13 -m pip install 'mcp<2'
            Write-Host "Servidor vscode-mcp instalado desde $serv"
        } else {
            $fallos.Add('Puente vscode-mcp: no encontre la carpeta (descargala: git clone https://github.com/norkles505/vs-code-mcp)')
        }

        $code = Get-CodePath
        if (Test-Path $code) {
            $vsix = $null
            foreach ($b in @((Join-Path $proyDir 'vs-code-mcp\windows'), $mcpRoot)) {
                if (Test-Path $b) {
                    $vsix = Get-ChildItem $b -Recurse -Filter '*.vsix' -ErrorAction SilentlyContinue | Select-Object -First 1
                    if ($vsix) { break }
                }
            }
            if ($vsix) { & $code --install-extension $vsix.FullName --force; Write-Host "extension propia: $($vsix.Name)" }
            else {
                # No hay .vsix (no se sube a git): se compila aqui mismo, igual que hace vs-code-mcp\windows\install.ps1
                $extDir = $null
                if ($serv) { $extDir = Join-Path (Split-Path -Parent $serv) 'extension' }
                if ($extDir -and (Test-Path (Join-Path $extDir 'package.json'))) {
                    Write-Host "No hay .vsix: compilando la extension en $extDir ..." -ForegroundColor Cyan
                    Push-Location $extDir
                    try {
                        npm install
                        if ($LASTEXITCODE -ne 0) { throw 'npm install' }
                        npm run compile
                        if ($LASTEXITCODE -ne 0) { throw 'npm run compile' }
                        "y`ny`n" | npx --yes '@vscode/vsce' package --allow-missing-repository
                        if ($LASTEXITCODE -ne 0) { throw 'vsce package' }
                        $vsix = Get-ChildItem $extDir -Filter '*.vsix' | Sort-Object LastWriteTime -Descending | Select-Object -First 1
                        if ($vsix) { & $code --install-extension $vsix.FullName --force; Write-Host "extension propia: $($vsix.Name)" }
                        else { $fallos.Add('Puente vscode-mcp: no se genero el .vsix') }
                    } catch {
                        $fallos.Add("Puente vscode-mcp: fallo al compilar la extension ($($_.Exception.Message))")
                    } finally { Pop-Location }
                } else {
                    $fallos.Add('Puente vscode-mcp: no encontre la carpeta de la extension para compilar el .vsix')
                }
            }
        } else {
            $fallos.Add('Puente vscode-mcp: no se encontro VS Code (comando code)')
        }
    } catch { $fallos.Add('Puente vscode-mcp') }
}

# uv + blender-mcp: deja blender-mcp.exe en <usuario>\.local\bin (la ruta que usa tu config de Claude Desktop)
if (Quiero 'blendermcp') {
    Titulo 'Puente blender-mcp (uv)'
    try {
        Instalar 'uv' @('astral-sh.uv')
        Refrescar-Path
        $bm = Join-Path $mcpRoot 'blender-mcp'
        if (-not (Test-Path "$bm\pyproject.toml")) {
            Write-Host "No existe $bm : restaura Documents\MCP y vuelve a ejecutar: uv tool install --force <esa carpeta>" -ForegroundColor DarkYellow
            $fallos.Add('Puente blender-mcp: no encontre su carpeta (Documents\MCP\blender-mcp)')
        } elseif (Get-Command uv -ErrorAction SilentlyContinue) {
            Push-Location $bm
            uv tool install --force .
            if ($LASTEXITCODE -ne 0) { $fallos.Add('Instalar blender-mcp con uv') }
            Pop-Location
        } else { $fallos.Add('uv no quedo disponible (cierra y abre la consola, luego: uv tool install --force .  dentro de blender-mcp)') }
    } catch { $fallos.Add('uv / blender-mcp') }
}

# Emulador MeshCraftPhone (lo usan los emulador.bat)
if (Quiero 'avd') {
    Titulo 'Emulador MeshCraftPhone'
    try {
        $avdm = 'C:\Android\android-sdk\cmdline-tools\latest\bin\avdmanager.bat'
        if ((Test-Path $avdm) -and -not (Test-Path "$env:USERPROFILE\.android\avd\MeshCraftPhone.avd")) {
            'no' | & $avdm create avd -n MeshCraftPhone -k 'system-images;android-34;google_apis;x86_64' --device pixel_6 --force
            if ($LASTEXITCODE -ne 0) { $fallos.Add('Crear el emulador MeshCraftPhone') }
        }
    } catch { $fallos.Add('Crear el emulador MeshCraftPhone') }
}

# Hypervisor de Windows (el emulador lo necesita; ademas la virtualizacion debe estar activa en la BIOS)
if (Quiero 'hypervisor') {
    Titulo 'Windows Hypervisor Platform'
    try {
        Enable-WindowsOptionalFeature -Online -FeatureName HypervisorPlatform -All -NoRestart -ErrorAction Stop | Out-Null
    } catch { $fallos.Add('Activar Windows Hypervisor Platform (hazlo en Activar o desactivar caracteristicas de Windows)') }
}

# ---------------------------------------------------------------------
# Resumen
# ---------------------------------------------------------------------
Titulo 'Resumen'
Write-Host "Programas instalados por winget (o que ya estaban): $($script:instalados)"
if ($fallos.Count -eq 0) {
    Write-Host "Todo se instalo sin errores." -ForegroundColor Green
} else {
    Write-Host "Esto fallo o hay que hacerlo a mano ($($fallos.Count)):" -ForegroundColor Red
    $fallos | ForEach-Object { Write-Host "  - $_" }
}

Write-Host ""
Write-Host "PENDIENTE A MANO (no se puede automatizar):"
Write-Host "  - Reiniciar la PC una vez para que el PATH y las variables queden bien."
if (Quiero 'claude') {
    Write-Host "  - Claude Desktop: abrelo e inicia sesion con tu cuenta."
}
if (Quiero 'vscodemcp') {
    Write-Host "  - Puente vscode-mcp: si Claude Desktop no ve VS Code, ejecuta install.bat dentro de vs-code-mcp\windows"
    Write-Host "    (registra el servidor en la config de Claude Desktop). Luego cierra y abre VS Code y Claude Desktop."
}
if (Quiero 'blender') {
    Write-Host @"
  - Blender: instalar las extensiones desde Edit > Preferences > Get Extensions:
      Ant Landscape, Edit Mesh Tools, LoopTools, Node Tree Screenshot, Sapling Tree Gen, Draw Hair, Ucupaint
    y el addon del puente MCP de Blender (desde Documents\MCP).
"@
}
Write-Host @"
  - Restaurar tus carpetas: proyectos, Documents\MCP y .android\debug.keystore (en tu carpeta de usuario)
    (si hiciste un respaldo antes de formatear: .\respaldo.ps1 restaurar ARCHIVO.tar.gz)
  - Photoshop (desde Creative Cloud), FL Studio y sus plugins (FL Cloud), Riot/Valorant,
    VirtualTablet Server, Enterprise Architect (trial) y MuseHub: instalar desde sus paginas.
  - Drivers: Windows Update + Intel Graphics + Realtek Audio.
  - Firewall: permitir el agente de Windows en redes PRIVADAS la primera vez que corra.
"@

# Codigo de salida para INSTALAR-TODO.bat: 0 = todo bien, 2 = termino con avisos (1 = se detuvo antes de empezar)
if ($fallos.Count -gt 0) { exit 2 } else { exit 0 }
