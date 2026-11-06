# =====================================================================
# actualizar-artcraft.ps1 - Actualiza (git pull) y recompila las alternativas de ArtCraft que ya
# tienes clonadas, esten en la carpeta que esten. Equivalente de linux\actualizar-artcraft.sh.
# Compilar y crear el acceso directo del Escritorio lo hace compilar-artcraft.ps1 (al lado de este).
#
# USO:  powershell -File actualizar-artcraft.ps1 [-Asociar] [app=ruta ...]
#   Sin argumentos: busca en programas, proyectos, el Escritorio, Documentos y tu carpeta personal
#   todos los repositorios cuyo origen sea github.com/storytold/<app> y los actualiza.
#   Con "app=ruta" (como hace la ventana): actualiza justo esas rutas.
#   Con solo "app": la busca por su origen en git.
#   -Asociar: ademas registra cada app en "Abrir con" para sus tipos de archivo.
# La ventana (instalar-todo-gui.ps1) lo llama con el boton "Actualizar ArtCraft".
# (Solo ASCII a proposito: PowerShell 5.1 lee mal los acentos.)
# =====================================================================
param(
    [switch]$Asociar,
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$Items = @()
)

$ErrorActionPreference = 'Continue'
$env:GIT_TERMINAL_PROMPT = '0'
$env:CARGO_TERM_COLOR = 'never'
$env:CARGO_TERM_PROGRESS_WHEN = 'never'

# PATH fresco (por si git o rust se acaban de instalar) mas la carpeta de cargo
$cargoBin = Join-Path $env:USERPROFILE '.cargo\bin'
$env:Path = [Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' + [Environment]::GetEnvironmentVariable('Path', 'User') + ';' + $cargoBin

$esc = [Environment]::GetFolderPath('Desktop')
$docs = [Environment]::GetFolderPath('MyDocuments')
$buscar = @(
    (Join-Path $esc 'programas'), (Join-Path $esc 'proyectos'), $esc,
    (Join-Path $docs 'programas'), $docs, $env:USERPROFILE
)

# Ejecuta un programa nativo mostrando stdout y stderr como texto normal (cargo y git escriben
# su progreso por stderr y la ventana lo pintaria de rojo). Devuelve el codigo de salida.
function Ejecutar([string]$exe, [string[]]$argumentos) {
    & $exe @argumentos 2>&1 | ForEach-Object { Write-Host ("$_") }
    return $LASTEXITCODE
}

# Compilar-App: compila la app y crea su acceso directo con compilar-artcraft.ps1.
# Con $soloAcceso no compila: solo renueva el acceso directo (la app ya estaba al dia).
function Compilar-App([string]$repo, [string]$ruta, [bool]$soloAcceso) {
    $c = Join-Path $PSScriptRoot 'compilar-artcraft.ps1'
    if (Test-Path $c) {
        $a = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $c, '-Ruta', $ruta, '-Repo', $repo)
        if ($Asociar) { $a += '-Asociar' }
        if ($soloAcceso) { $a += '-SoloAcceso' }
        return (Ejecutar 'powershell.exe' $a)
    }
    # Sin compilar-artcraft.ps1 al lado: solo cargo, sin acceso directo
    if ($soloAcceso) { return 0 }
    Write-Host '>> cargo build --release (puede tardar varios minutos)'
    return (Ejecutar 'cargo' @('build', '--release'))
}

# Origen-Artcraft <carpeta>: devuelve el nombre de la app si su origen es storytold/<app>
function Origen-Artcraft([string]$dir) {
    $url = & git -C $dir remote get-url origin 2>$null
    if ($LASTEXITCODE -ne 0 -or -not $url) { return $null }
    if ("$url" -match 'storytold/([^/]+?)(\.git)?/?$') { return $Matches[1] }
    return $null
}

# Localizar <app>: ruta donde esta clonada la app, reconocida por su origen en git
# (el nombre de la carpeta no basta)
function Localizar([string]$repo) {
    foreach ($base in $buscar) {
        if (-not (Test-Path $base)) { continue }
        foreach ($d in @(Get-ChildItem $base -Directory -ErrorAction SilentlyContinue)) {
            if (-not (Test-Path (Join-Path $d.FullName '.git'))) { continue }
            if ((Origen-Artcraft $d.FullName) -eq $repo) { return $d.FullName }
        }
    }
    return $null
}

# Sin argumentos: descubre todas las apps de storytold que haya clonadas
if ($Items.Count -eq 0) {
    $visto = @{}
    $lista = @()
    foreach ($base in $buscar) {
        if (-not (Test-Path $base)) { continue }
        foreach ($d in @(Get-ChildItem $base -Directory -ErrorAction SilentlyContinue)) {
            if (-not (Test-Path (Join-Path $d.FullName '.git'))) { continue }
            $r = Origen-Artcraft $d.FullName
            if (-not $r -or $visto.ContainsKey($r)) { continue }
            $visto[$r] = $true
            $lista += "$r=$($d.FullName)"
        }
    }
    $Items = $lista
}

if ($Items.Count -eq 0) {
    Write-Host '!! No encontre ninguna app de ArtCraft clonada (busque en programas, proyectos, Escritorio, Documentos y tu carpeta personal).'
    exit 1
}

if (-not (Get-Command cargo -ErrorAction SilentlyContinue)) {
    Write-Host '!! No encuentro cargo. Instala "Rust (rustup)" desde la lista y vuelve a intentar.'
    exit 1
}
if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Write-Host '!! No encuentro git. Instala "Git" desde la lista y vuelve a intentar.'
    exit 1
}

$actualizadas = @(); $sinCambios = @(); $fallos = @()

foreach ($item in $Items) {
    if ($item -match '^([^=]+)=(.*)$') { $repo = $Matches[1]; $ruta = $Matches[2] }
    else { $repo = $item; $ruta = Localizar $item }

    Write-Host "=== $repo ==="
    if (-not $ruta -or -not (Test-Path (Join-Path $ruta '.git'))) {
        Write-Host "!! No encuentro $repo clonado en ninguna carpeta"
        $fallos += "${repo}: no esta clonado"
        continue
    }
    # Seguridad: nunca tocar una carpeta cuyo origen no sea storytold/<repo>
    if ((Origen-Artcraft $ruta) -ne $repo) {
        Write-Host "!! $ruta no viene de github.com/storytold/${repo}: no la toco"
        $fallos += "${repo}: la carpeta no es de ArtCraft (origen distinto)"
        continue
    }
    Write-Host ">> Carpeta: $ruta"
    Push-Location $ruta
    try {
        $antes = (& git rev-parse HEAD 2>$null)
        Write-Host '>> git pull'
        $rc = Ejecutar 'git' @('pull', '--ff-only')
        if ($rc -ne 0) {
            Write-Host "!! git pull fallo en $repo (cambios locales o sin internet?)"
            $fallos += "${repo}: git pull fallo"
            continue
        }
        $despues = (& git rev-parse HEAD 2>$null)

        if (-not (Test-Path 'Cargo.toml')) {
            Write-Host ">> $repo no tiene Cargo.toml: solo se actualizo el codigo."
            $actualizadas += $repo
            continue
        }

        # Si no hubo cambios y ya esta compilado, no se gasta tiempo recompilando
        # (solo se renueva el acceso directo, por si se borro o la app es anterior a esta funcion)
        if ($antes -eq $despues -and (Test-Path 'target\release')) {
            Write-Host '>> Ya estaba al dia.'
            $null = Compilar-App $repo $ruta $true
            $sinCambios += $repo
            continue
        }

        $rc = Compilar-App $repo $ruta $false
        if ($rc -eq 0) {
            $actualizadas += $repo
        } else {
            Write-Host "!! La compilacion fallo en $repo"
            $fallos += "${repo}: cargo build fallo (mira el error de arriba; pueden faltar los Build Tools C++)"
        }
    } finally {
        Pop-Location
    }
}

Write-Host ''
Write-Host '=== Resumen ==='
if ($actualizadas.Count -gt 0) { $a = $actualizadas -join ' ' } else { $a = 'ninguna' }
if ($sinCambios.Count -gt 0) { $s = $sinCambios -join ' ' } else { $s = 'ninguna' }
Write-Host "Actualizadas y compiladas: $a"
Write-Host "Sin cambios nuevos:        $s"

if ($fallos.Count -gt 0) {
    Write-Host ''
    Write-Host 'Esto fallo o hay que hacerlo a mano:'
    foreach ($f in $fallos) { Write-Host "  - $f" }
    exit 1
}
Write-Host 'Todo se actualizo sin errores'
exit 0
