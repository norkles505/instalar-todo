# =====================================================================
# asegurar-winget.ps1  -  Consigue winget (si falta) y despues sigue con el instalador
#
# Lo llama instalar-todo-gui.ps1 antes de instalar. Tambien se puede ejecutar solo:
#   powershell -ExecutionPolicy Bypass -File .\asegurar-winget.ps1
#
# Por que existe: las versiones nuevas de winget (1.29 o mas) necesitan, ademas de VCLibs y
# UI.Xaml, el marco "Microsoft.WindowsAppRuntime.1.8". Microsoft publica todas las
# dependencias juntas en DesktopAppInstaller_Dependencies.zip (repositorio winget-cli).
#
# Parametros (los usa la ventana):  -Siguiente <ruta de instalar-todo.ps1>  -Solo id1,id2
# Codigos de salida: 1 = no se pudo conseguir winget; si no, el del script siguiente.
# (Solo ASCII a proposito: PowerShell 5.1 lee mal los acentos.)
# =====================================================================
param([string]$Siguiente = '', [string]$Solo = '', [string]$CarpetaProyectos = '', [string]$CarpetaProgramas = '')

function Probar-Winget {
    if (Get-Command winget -ErrorAction SilentlyContinue) { return $true }
    $wa = Join-Path $env:LOCALAPPDATA 'Microsoft\WindowsApps'
    if (Test-Path (Join-Path $wa 'winget.exe')) {
        $env:Path = $env:Path + ';' + $wa
        if (Get-Command winget -ErrorAction SilentlyContinue) { return $true }
    }
    return $false
}

function Conseguir-Winget {
    if (Probar-Winget) { return $true }

    if ([Environment]::OSVersion.Version.Build -lt 17763) {
        Write-Host "Tu Windows es demasiado viejo para winget (se necesita Windows 10 1809 o mas nuevo). Actualiza Windows primero." -ForegroundColor Red
        return $false
    }

    Write-Host "No se encontro winget. Intentando instalar 'App Installer' automaticamente..." -ForegroundColor Yellow
    $ProgressPreference = 'SilentlyContinue'
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $arq = if ($env:PROCESSOR_ARCHITECTURE -eq 'ARM64') { 'arm64' } else { 'x64' }
    $tmp = Join-Path $env:TEMP 'winget-instalacion'
    if (Test-Path $tmp) { Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue }
    New-Item -ItemType Directory $tmp -Force | Out-Null

    # Intento 1: App Installer ya viene con Windows pero no esta registrado
    try {
        Add-AppxPackage -RegisterByFamilyName -MainPackage 'Microsoft.DesktopAppInstaller_8wekyb3d8bbwe' -ErrorAction Stop
    } catch { }
    if (Probar-Winget) { Write-Host "winget quedo listo." -ForegroundColor Green; return $true }

    # Intento 2: paquete oficial + TODAS sus dependencias (VCLibs, UI.Xaml y WindowsAppRuntime 1.8)
    try {
        Write-Host "Descargando winget (puede tardar unos minutos)..."
        $bundle = Join-Path $tmp 'AppInstaller.msixbundle'
        Invoke-WebRequest 'https://aka.ms/getwinget' -OutFile $bundle -UseBasicParsing

        Write-Host "Descargando las dependencias oficiales de winget..."
        $zip = Join-Path $tmp 'dependencias.zip'
        Invoke-WebRequest 'https://github.com/microsoft/winget-cli/releases/latest/download/DesktopAppInstaller_Dependencies.zip' -OutFile $zip -UseBasicParsing
        $carpeta = Join-Path $tmp 'dependencias'
        Expand-Archive -Path $zip -DestinationPath $carpeta -Force

        $todos = @(Get-ChildItem $carpeta -Recurse -Include *.appx, *.msix -ErrorAction SilentlyContinue)
        $deps = @($todos | Where-Object { $_.FullName -match "[\\/]$arq[\\/]" } | ForEach-Object { $_.FullName })
        if ($deps.Count -eq 0) { $deps = @($todos | ForEach-Object { $_.FullName }) }
        Write-Host "Instalando winget con $($deps.Count) dependencias..."

        try {
            Add-AppxPackage -Path $bundle -DependencyPath $deps -ErrorAction Stop
        } catch {
            Write-Host "Primer intento fallo, instalando las dependencias una por una..." -ForegroundColor DarkYellow
            foreach ($d in ($deps | Sort-Object)) {
                try { Add-AppxPackage -Path $d -ErrorAction Stop } catch { }
            }
            Add-AppxPackage -Path $bundle -ErrorAction Stop
        }
    } catch {
        Write-Host "No se pudo instalar winget automaticamente: $($_.Exception.Message)" -ForegroundColor Red
    }
    if (Probar-Winget) { Write-Host "winget quedo listo." -ForegroundColor Green; return $true }
    return $false
}

$listo = Conseguir-Winget | Select-Object -Last 1
if ($listo -ne $true) {
    Write-Host ""
    Write-Host "NO SE INSTALO NINGUN PROGRAMA: no se pudo conseguir winget." -ForegroundColor Red
    Write-Host "Hazlo a mano y vuelve a ejecutar:" -ForegroundColor Red
    Write-Host "  1. Abre la Microsoft Store, busca 'Instalador de aplicacion' (App Installer) e instalalo o actualizalo."
    Write-Host "  2. Si no tienes Microsoft Store, descarga el .msixbundle de https://github.com/microsoft/winget-cli/releases"
    Write-Host "     junto con DesktopAppInstaller_Dependencies.zip, instala los .appx de la carpeta x64 y luego el .msixbundle."
    Write-Host "  3. Cierra esta ventana, abre otra y comprueba con:  winget --version"
    exit 1
}

if ($Siguiente -ne '' -and (Test-Path $Siguiente)) {
    $pasar = @{}
    if ($Solo -ne '') { $pasar['Solo'] = $Solo }
    if ($CarpetaProyectos -ne '') { $pasar['CarpetaProyectos'] = $CarpetaProyectos }
    if ($CarpetaProgramas -ne '') { $pasar['CarpetaProgramas'] = $CarpetaProgramas }
    & $Siguiente @pasar
    exit $LASTEXITCODE
}
exit 0