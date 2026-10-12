# =====================================================================
# respaldo.ps1  -  Guarda y restaura tus configuraciones personales
# (para usarlo ANTES de formatear y DESPUES de correr instalar-todo.ps1)
#
#   powershell -ExecutionPolicy Bypass -File .\respaldo.ps1 respaldar E:\ [-ConProyectos]
#       Crea E:\respaldo-AAAA-MM-DD_HHMM.tar.gz. El destino debe ser un USB/disco externo
#       (o una carpeta que luego copies fuera de este disco): si lo dejas en el disco que vas
#       a formatear, el respaldo se pierde con el.
#       Solo LEE y copia: no modifica ni borra nada de tu sistema.
#
#   powershell -ExecutionPolicy Bypass -File .\respaldo.ps1 restaurar E:\respaldo-....tar.gz
#       Devuelve todo a su sitio. Si un archivo ya existe y es distinto, el actual NO se
#       pierde: queda guardado como archivo.bak1 junto al restaurado.
#
# Que guarda: claves SSH (.ssh), claves GPG, .gitconfig, .android\debug.keystore,
# ajustes/atajos/snippets de VS Code, la lista de extensiones de VS Code, la config de
# Claude Desktop (claude_desktop_config.json) y Documents\MCP.
# Con -ConProyectos tambien guarda <Escritorio>\proyectos (sin node_modules, target, venv,
# .venv, __pycache__ ni .gradle: esas carpetas se regeneran).
#
# OJO: el respaldo contiene tus claves privadas. Guardalo en un lugar de confianza.
# No hace falta ser Administrador.
# =====================================================================
param(
    [Parameter(Position = 0)][ValidateSet('respaldar', 'restaurar')][string]$Modo,
    [Parameter(Position = 1)][string]$Ruta,
    [switch]$ConProyectos
)

$perfil     = $env:USERPROFILE
$escritorio = [Environment]::GetFolderPath('Desktop')
$documentos = [Environment]::GetFolderPath('MyDocuments')

# Rutas relativas a %USERPROFILE%
$items = @(
    '.ssh', '.gitconfig', '.android\debug.keystore', 'AppData\Roaming\gnupg',
    'AppData\Roaming\Code\User\settings.json', 'AppData\Roaming\Code\User\keybindings.json',
    'AppData\Roaming\Code\User\snippets',
    'AppData\Roaming\Claude\claude_desktop_config.json'
)
$excluir = @('node_modules', 'target', 'venv', '.venv', '__pycache__', '.gradle')

function Uso {
    Write-Host @"
Uso:
  .\respaldo.ps1 respaldar DESTINO [-ConProyectos]     (DESTINO: por ejemplo la unidad del USB, E:\)
  .\respaldo.ps1 restaurar ARCHIVO.tar.gz
(Si PowerShell bloquea el script: powershell -ExecutionPolicy Bypass -File .\respaldo.ps1 ...)
"@
}

function Buscar-Tar {
    # Se usa el tar de Windows (bsdtar); el de Git/MSYS2 interpreta mal las rutas con "C:"
    $t = Join-Path $env:SystemRoot 'System32\tar.exe'
    if (Test-Path $t) { return $t }
    $c = Get-Command tar -ErrorAction SilentlyContinue
    if ($c) { return $c.Source }
    return $null
}

function Buscar-Code {
    $c = Get-Command code -ErrorAction SilentlyContinue
    if ($c) { return $c.Source }
    $ruta = "$env:LOCALAPPDATA\Programs\Microsoft VS Code\bin\code.cmd"
    if (Test-Path $ruta) { return $ruta }
    return $null
}

# Copia todos los archivos de ORIGEN a DESTINO. Si ya existe uno distinto, el actual se conserva
# como .bakN (o, con -SinPisar, no se toca el existente).
function Copiar-Arbol([string]$origen, [string]$destino, [switch]$SinPisar) {
    if (-not (Test-Path -LiteralPath $origen)) { return }
    $base = (Resolve-Path -LiteralPath $origen).Path.TrimEnd('\')
    Get-ChildItem -LiteralPath $origen -Recurse -File -Force | ForEach-Object {
        $rel = $_.FullName.Substring($base.Length).TrimStart('\')
        $d = Join-Path $destino $rel
        New-Item -ItemType Directory (Split-Path $d -Parent) -Force | Out-Null
        if (Test-Path -LiteralPath $d) {
            if ($SinPisar) { return }
            if ((Get-FileHash -LiteralPath $_.FullName).Hash -eq (Get-FileHash -LiteralPath $d).Hash) { return }
            $n = 1
            while (Test-Path -LiteralPath "$d.bak$n") { $n++ }
            Move-Item -LiteralPath $d -Destination "$d.bak$n"
            Write-Host "  ~ $rel (el actual queda como $(Split-Path "$d.bak$n" -Leaf))"
        }
        Copy-Item -LiteralPath $_.FullName -Destination $d
    }
}

function Respaldar {
    if (-not $Ruta) {
        Write-Host "Falta el DESTINO (por ejemplo la unidad de tu USB: E:\)." -ForegroundColor Red
        Uso; return
    }
    $tar = Buscar-Tar
    if (-not $tar) {
        Write-Host "No encontre tar.exe (viene con Windows 10/11). Actualiza Windows o instala bsdtar." -ForegroundColor Red
        return
    }
    New-Item -ItemType Directory $Ruta -Force | Out-Null
    $destino = (Resolve-Path $Ruta).Path
    if ([IO.Path]::GetPathRoot($destino) -eq [IO.Path]::GetPathRoot($perfil)) {
        Write-Host "AVISO: ese destino esta en el mismo disco que tu carpeta personal." -ForegroundColor DarkYellow
        Write-Host "       Si formateas ese disco, el respaldo se pierde. Copialo a un USB o a la nube despues." -ForegroundColor DarkYellow
    }

    $tmp = Join-Path ([IO.Path]::GetTempPath()) ('respaldo-' + [Guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory "$tmp\home", "$tmp\meta" -Force | Out-Null
    try {
        Write-Host "Copiando configuraciones..."
        foreach ($rel in $items) {
            $src = Join-Path $perfil $rel
            if (-not (Test-Path -LiteralPath $src)) { continue }
            $dst = Join-Path "$tmp\home" $rel
            New-Item -ItemType Directory (Split-Path $dst -Parent) -Force | Out-Null
            try {
                Copy-Item -LiteralPath $src -Destination $dst -Recurse -Force -ErrorAction Stop
                Write-Host "  + $rel"
            } catch {
                Write-Host "  ! No pude copiar $rel (se omite): $($_.Exception.Message)" -ForegroundColor DarkYellow
            }
        }
        # Archivos temporales de gpg-agent (S.*): no sirven en otra instalacion
        $gpg = "$tmp\home\AppData\Roaming\gnupg"
        if (Test-Path $gpg) { Get-ChildItem $gpg -Filter 'S.*' -Force -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue }

        $code = Buscar-Code
        if ($code) {
            $lista = & $code --list-extensions 2>$null
            if ($lista) {
                [IO.File]::WriteAllLines("$tmp\meta\extensiones-vscode.txt", [string[]]$lista, (New-Object Text.UTF8Encoding($false)))
                Write-Host "  + lista de extensiones de VS Code"
            }
        }
        (Get-Date).ToString() | Set-Content "$tmp\meta\fecha.txt"

        # robocopy: codigos de salida 0-7 = bien, 8 o mas = error
        if (Test-Path "$documentos\MCP") {
            robocopy "$documentos\MCP" "$tmp\documentos\MCP" /E /XD $excluir /NFL /NDL /NJH /NJS /NP | Out-Null
            if ($LASTEXITCODE -lt 8) { Write-Host "  + Documents\MCP" } else { Write-Host "  ! No pude copiar Documents\MCP" -ForegroundColor DarkYellow }
        }
        if ($ConProyectos -and (Test-Path "$escritorio\proyectos")) {
            Write-Host "  + proyectos (puede tardar)"
            robocopy "$escritorio\proyectos" "$tmp\proyectos" /E /XD $excluir /NFL /NDL /NJH /NJS /NP | Out-Null
            if ($LASTEXITCODE -ge 8) { Write-Host "  ! Hubo errores copiando proyectos" -ForegroundColor DarkYellow }
        }

        $archivo = Join-Path $destino ('respaldo-' + (Get-Date -Format 'yyyy-MM-dd_HHmm') + '.tar.gz')
        & $tar -czf $archivo -C $tmp .
        if ($LASTEXITCODE -eq 0 -and (Test-Path $archivo)) {
            $mb = [math]::Round((Get-Item $archivo).Length / 1MB, 1)
            Write-Host ""
            Write-Host "Listo: $archivo ($mb MB)" -ForegroundColor Green
            Write-Host "Contiene tus claves privadas: guardalo en un lugar de confianza."
        } else {
            Write-Host "Fallo al crear el respaldo." -ForegroundColor Red
            if (Test-Path $archivo) { Remove-Item $archivo -Force }
        }
    } finally {
        Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue
    }
}

function Restaurar {
    if (-not $Ruta -or -not (Test-Path -LiteralPath $Ruta -PathType Leaf)) {
        Write-Host "Indica el archivo de respaldo (.tar.gz) que quieres restaurar." -ForegroundColor Red
        Uso; return
    }
    $tar = Buscar-Tar
    if (-not $tar) {
        Write-Host "No encontre tar.exe (viene con Windows 10/11)." -ForegroundColor Red
        return
    }
    $archivo = (Resolve-Path -LiteralPath $Ruta).Path
    $tmp = Join-Path ([IO.Path]::GetTempPath()) ('respaldo-' + [Guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory $tmp -Force | Out-Null
    try {
        & $tar -xzf $archivo -C $tmp
        if ($LASTEXITCODE -ne 0) { Write-Host "No pude leer el respaldo." -ForegroundColor Red; return }
        if (-not (Test-Path "$tmp\home")) {
            Write-Host "Ese archivo no parece un respaldo de este script." -ForegroundColor Red
            return
        }

        Write-Host "Restaurando en $perfil ..."
        Copiar-Arbol "$tmp\home" $perfil

        if (Test-Path "$tmp\documentos\MCP") {
            Write-Host "Restaurando Documents\MCP en $documentos\MCP ..."
            Copiar-Arbol "$tmp\documentos\MCP" (Join-Path $documentos 'MCP')
        }
        if (Test-Path "$tmp\proyectos") {
            Write-Host "Restaurando proyectos en $escritorio\proyectos (lo que ya exista no se toca) ..."
            Copiar-Arbol "$tmp\proyectos" (Join-Path $escritorio 'proyectos') -SinPisar
        }

        $extFile = "$tmp\meta\extensiones-vscode.txt"
        if (Test-Path $extFile) {
            $code = Buscar-Code
            if ($code) {
                Write-Host "Instalando extensiones de VS Code ..."
                foreach ($e in (Get-Content $extFile)) {
                    $e = $e.Trim()
                    if (-not $e) { continue }
                    & $code --install-extension $e --force *> $null
                    if ($LASTEXITCODE -eq 0) { Write-Host "  extension: $e" } else { Write-Host "  ! fallo: $e" -ForegroundColor DarkYellow }
                }
            } else {
                Write-Host "VS Code no esta instalado: se omiten las extensiones (corre instalar-todo.ps1 primero)." -ForegroundColor DarkYellow
            }
        }
        Write-Host ""
        Write-Host "Listo. Cierra y abre las terminales y VS Code para que apliquen los cambios." -ForegroundColor Green
    } finally {
        Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue
    }
}

switch ($Modo) {
    'respaldar' { Respaldar }
    'restaurar' { Restaurar }
    default     { Uso }
}
