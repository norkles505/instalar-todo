# =====================================================================
# compilar-artcraft.ps1 - Compila una app de ArtCraft (cargo build --release) y le crea un
# acceso directo en el Escritorio. Opcional: la registra para abrir sus tipos de archivo.
# Lo llama actualizar-artcraft.ps1 (boton "Actualizar ArtCraft" de la ventana), pero tambien
# se puede usar solo.
#
# USO:  powershell -File compilar-artcraft.ps1 -Ruta <carpeta> [-Repo <app>] [-Asociar] [-SoloAcceso]
#   -Ruta        carpeta donde esta clonada la app (la que tiene Cargo.toml)
#   -Repo        nombre del repo (wordcraft, photocraft...). Si falta, se usa el nombre de la carpeta
#   -Asociar     ademas registra la app en "Abrir con" para sus tipos de archivo (tabla $apps).
#                Windows no deja que un programa se ponga solo como predeterminado: despues, en el
#                Explorador, clic derecho > Abrir con > Elegir otra aplicacion > Siempre.
#   -SoloAcceso  no compila: solo crea o renueva el acceso directo (la app ya debe estar compilada)
#
# El .exe se descubre con "cargo metadata", asi que no importa como se llame el binario.
# Necesita Rust (rustup) y los Visual Studio Build Tools C++.
# (Solo ASCII a proposito: PowerShell 5.1 lee mal los acentos.)
# =====================================================================
param(
    [Parameter(Mandatory = $true)][string]$Ruta,
    [string]$Repo = '',
    [switch]$Asociar,
    [switch]$SoloAcceso
)

$ErrorActionPreference = 'Continue'
$env:CARGO_TERM_COLOR = 'never'
$env:CARGO_TERM_PROGRESS_WHEN = 'never'

# PATH fresco (por si Rust se acaba de instalar) mas la carpeta de cargo
$cargoBin = Join-Path $env:USERPROFILE '.cargo\bin'
$env:Path = [Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' + [Environment]::GetEnvironmentVariable('Path', 'User') + ';' + $cargoBin

# Nombre que lleva el acceso directo y tipos de archivo que abre cada app.
# Las extensiones son una suposicion segun lo que hace cada app: ajusta la lista si hace falta.
# Una lista vacia = esa app no se registra para ningun tipo de archivo.
$apps = @{
    'photocraft'     = @{ Nombre = 'PhotoCraft';     Ext = @('.psd') }
    'vectorcraft'    = @{ Nombre = 'VectorCraft';    Ext = @('.svg') }
    'filmcraft'      = @{ Nombre = 'FilmCraft';      Ext = @() }
    'lightcraft'     = @{ Nombre = 'LightCraft';     Ext = @('.cr2', '.nef', '.arw', '.dng') }
    'pdfcraft'       = @{ Nombre = 'PdfCraft';       Ext = @('.pdf') }
    'effectcraft'    = @{ Nombre = 'EffectCraft';    Ext = @() }
    'designcraft'    = @{ Nombre = 'DesignCraft';    Ext = @() }
    'wordcraft'      = @{ Nombre = 'WordCraft';      Ext = @('.docx') }
    'soundcraft'     = @{ Nombre = 'SoundCraft';     Ext = @() }
    'deckcraft'      = @{ Nombre = 'DeckCraft';      Ext = @('.pptx') }
    'cadcraft'       = @{ Nombre = 'CADCraft';       Ext = @('.dxf', '.dwg') }
    'gridcraft'      = @{ Nombre = 'GridCraft';      Ext = @('.xlsx') }
    'figcraft'       = @{ Nombre = 'FigCraft';       Ext = @() }
    'texturecraft'   = @{ Nombre = 'TextureCraft';   Ext = @() }
    'materialcraft'  = @{ Nombre = 'MaterialCraft';  Ext = @() }
    'craft-anything' = @{ Nombre = 'Craft Anything'; Ext = @() }
}

if (-not $Repo) { $Repo = Split-Path -Leaf $Ruta }
$clave = $Repo.ToLower()
if ($apps.ContainsKey($clave)) { $nombre = $apps[$clave].Nombre; $exts = @($apps[$clave].Ext) }
else { $nombre = $Repo; $exts = @() }

# Ejecuta un programa nativo mostrando stdout y stderr como texto normal (cargo escribe su
# progreso por stderr y la ventana lo pintaria de rojo). Devuelve el codigo de salida.
function Ejecutar([string]$exe, [string[]]$argumentos) {
    & $exe @argumentos 2>&1 | ForEach-Object { Write-Host ("$_") }
    return $LASTEXITCODE
}
function Norm([string]$t) { return (($t -replace '[-_ ]', '').ToLower()) }

if (-not (Test-Path (Join-Path $Ruta 'Cargo.toml'))) {
    Write-Host ">> $Repo no tiene Cargo.toml: no hay nada que compilar."
    exit 0
}
if (-not (Get-Command cargo -ErrorAction SilentlyContinue)) {
    Write-Host '!! No encuentro cargo. Instala "Rust (rustup)" desde la lista y vuelve a intentar.'
    exit 1
}

Push-Location $Ruta
try {
    if (-not $SoloAcceso) {
        Write-Host '>> cargo build --release (puede tardar varios minutos)'
        $rc = Ejecutar 'cargo' @('build', '--release')
        if ($rc -ne 0) {
            Write-Host "!! La compilacion fallo en $Repo"
            exit 1
        }
    }

    # ---- buscar el .exe que genero la app
    $meta = $null
    try { $meta = (& cargo metadata --no-deps --format-version 1 2>$null | Out-String) | ConvertFrom-Json } catch { }
    if (-not $meta) {
        Write-Host "!! No pude leer los datos del proyecto con cargo metadata: $Repo no tiene acceso directo."
        exit 0
    }
    $manifiestoRaiz = [IO.Path]::GetFullPath((Join-Path $Ruta 'Cargo.toml'))
    $bins = @()
    foreach ($p in $meta.packages) {
        foreach ($t in $p.targets) {
            if ($t.kind -contains 'bin') {
                $bins += [pscustomobject]@{
                    Nombre = $t.name
                    Raiz   = ([IO.Path]::GetFullPath($p.manifest_path) -ieq $manifiestoRaiz)
                }
            }
        }
    }
    if ($bins.Count -eq 0) {
        Write-Host ">> $Repo no genera ningun programa (es una libreria): sin acceso directo."
        exit 0
    }
    # Prioridad: el binario que se llama como la app; si solo hay uno, ese; el del paquete raiz; el primero
    $elegido = $bins | Where-Object { (Norm $_.Nombre) -eq (Norm $Repo) } | Select-Object -First 1
    if (-not $elegido -and $bins.Count -eq 1) { $elegido = $bins[0] }
    if (-not $elegido) { $elegido = $bins | Where-Object { $_.Raiz } | Select-Object -First 1 }
    if (-not $elegido) {
        $elegido = $bins[0]
        Write-Host ('>> Hay varios programas (' + (($bins | ForEach-Object { $_.Nombre }) -join ', ') + '): uso ' + $elegido.Nombre)
    }
    $exe = [IO.Path]::GetFullPath((Join-Path (Join-Path $meta.target_directory 'release') ($elegido.Nombre + '.exe')))
    if (-not (Test-Path $exe)) {
        Write-Host "!! No encuentro $exe : compila la app primero (sin -SoloAcceso)."
        exit 1
    }

    # ---- acceso directo en el Escritorio
    try {
        $escritorio = [Environment]::GetFolderPath('Desktop')
        $lnk = Join-Path $escritorio ($nombre + '.lnk')
        $ws = New-Object -ComObject WScript.Shell
        $sc = $ws.CreateShortcut($lnk)
        $sc.TargetPath = $exe
        $sc.WorkingDirectory = $Ruta
        $sc.IconLocation = "$exe,0"
        $sc.Description = $nombre
        $sc.Save()
        Write-Host ">> Acceso directo: $lnk"
    } catch {
        Write-Host "!! No pude crear el acceso directo de ${nombre}: $($_.Exception.Message)"
    }

    # ---- registrar los tipos de archivo en "Abrir con" (solo si se pidio)
    if ($Asociar) {
        if ($exts.Count -eq 0) {
            Write-Host ">> $nombre no tiene tipos de archivo definidos en la tabla: no se registra nada."
        } else {
            try {
                $exeNombre = Split-Path -Leaf $exe
                $base = "HKCU:\Software\Classes\Applications\$exeNombre"
                New-Item "$base\shell\open\command" -Force | Out-Null
                Set-ItemProperty "$base\shell\open\command" -Name '(default)' -Value ('"' + $exe + '" "%1"')
                Set-ItemProperty $base -Name 'FriendlyAppName' -Value $nombre
                New-Item "$base\SupportedTypes" -Force | Out-Null
                foreach ($e in $exts) {
                    New-ItemProperty "$base\SupportedTypes" -Name $e -Value '' -PropertyType String -Force | Out-Null
                    New-Item "HKCU:\Software\Classes\$e\OpenWithList\$exeNombre" -Force | Out-Null
                }
                Write-Host ">> $nombre aparece en 'Abrir con' para: $($exts -join ' ')"
                Write-Host '>> Para que sea el predeterminado: clic derecho en un archivo > Abrir con > Elegir otra aplicacion > Siempre.'
            } catch {
                Write-Host "!! No pude registrar los tipos de archivo de ${nombre}: $($_.Exception.Message)"
            }
        }
    }
} finally {
    Pop-Location
}
exit 0
