@echo off
setlocal EnableDelayedExpansion

:: 1. Comprobar privilegios de Administrador
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo [ERROR] Este script requiere privilegios de Administrador.
    echo Por favor, haz clic derecho y selecciona "Ejecutar como administrador".
    pause
    exit /b 1
)

:: 2. Variables de rutas dinamicas
set "SCRIPT_DIR=%~dp0"
:: Quitar la barra invertida final si existe
if "%SCRIPT_DIR:~-1%"=="\" set "SCRIPT_DIR=%SCRIPT_DIR:~0,-1%"

set "XML_FILE=%SCRIPT_DIR%\MadisaTelemetryAgent.xml"
set "PS_SCRIPT=%SCRIPT_DIR%\agent-snapshot.ps1"
set "TASK_NAME=MadisaTelemetryAgent"

echo ======================================================
echo    INSTALADOR MADISA TELEMETRY AGENT
echo ======================================================
echo Directorio: %SCRIPT_DIR%

:: 3. Verificar que los archivos existen
if not exist "%XML_FILE%" (
    echo [ERROR] No se encuentra %XML_FILE%
    pause
    exit /b 1
)

if not exist "%PS_SCRIPT%" (
    echo [ERROR] No se encuentra %PS_SCRIPT%
    pause
    exit /b 1
)

:: 4. Eliminar tarea previa si ya existiera
echo [*] Limpiando tareas anteriores...
schtasks /delete /tn "%TASK_NAME%" /f >nul 2>&1

:: 5. Crear la tarea programada desde el XML
echo [*] Registrando tarea programada con privilegios SYSTEM...
schtasks /create /tn "%TASK_NAME%" /xml "%XML_FILE%" /ru "NT AUTHORITY\SYSTEM" /f

if %errorLevel% neq 0 (
    echo [ERROR] Fallo al crear la tarea programada.
    pause
    exit /b 1
)

:: 6. Disparar primera ejecucion inmediata
echo [*] Iniciando ciclo de telemetria inicial...
schtasks /run /tn "%TASK_NAME%"

echo.
echo ======================================================
echo [OK] Agente instalado y configurado correctamente.
echo La telemetria se enviara cada 5 minutos de forma continua.
echo ======================================================
timeout /t 5 >nul
exit /b 0
