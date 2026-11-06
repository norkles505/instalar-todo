@echo off
rem Doble clic: se pide permiso de administrador solo y se abre una ventana con casillas
rem para elegir que instalar (igual que en Linux). winget se consigue solo si falta.
cd /d "%~dp0"

net session >nul 2>&1
if %errorlevel% neq 0 (
    echo Pidiendo permisos de administrador...
    powershell -NoProfile -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    exit /b
)

echo Abriendo la ventana para elegir que instalar...
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0instalar-todo-gui.ps1"
set RESULTADO=%errorlevel%

echo.
if "%RESULTADO%"=="0" (
    echo Terminado sin errores. Ahora REINICIA la PC.
) else if "%RESULTADO%"=="2" (
    echo Terminado, pero con avisos. Revisa el RESUMEN de arriba para ver que fallo y luego REINICIA la PC.
) else if "%RESULTADO%"=="3" (
    echo No se instalo nada: cerraste la ventana sin elegir.
) else (
    echo NO SE INSTALO NADA: el script se detuvo antes de empezar. Lee el mensaje en rojo de arriba.
)
pause
