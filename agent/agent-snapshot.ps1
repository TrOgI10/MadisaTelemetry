# ========================================================
# Snapshot de Telemetría del Sistema con Log de Errores
# ========================================================

# 1. Configuración de rutas y archivos de log (hacia frontend/public)
$baseProjectDir = Split-Path -Path $PSScriptRoot -Parent
$telemetryDir   = Join-Path -Path $baseProjectDir -ChildPath "frontend\public"

# Fallback si se ejecuta fuera del árbol de directorios del proyecto
if (-not (Test-Path -Path $telemetryDir)) {
    $telemetryDir = "C:\Projects\MadisaTelemetry\frontend\public"
    if (-not (Test-Path -Path $telemetryDir)) {
        New-Item -ItemType Directory -Path $telemetryDir -Force | Out-Null
    }
}

$outputPath = Join-Path -Path $telemetryDir -ChildPath "snapshot.json"
$logPath    = Join-Path -Path $telemetryDir -ChildPath "error.log"

# Función interna de logging
function Write-TelemetryLog {
    param (
        [string]$Message,
        [string]$Level = "ERROR"
    )
    $timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    $logEntry = "[$timestamp] [$Level] $Message"
    Add-Content -Path $logPath -Value $logEntry -Encoding UTF8
}

try {
    # 2. Datos del Sistema Operativo
    $os = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction Stop

    # 3. CPU
    $cpuLoad = (Get-CimInstance -ClassName Win32_Processor -ErrorAction Stop | Measure-Object -Property LoadPercentage -Average).Average
    if ($null -eq $cpuLoad) { $cpuLoad = 0 }

    # 4. Memoria RAM
    $totalRamGb = [math]::Round($os.TotalVisibleMemorySize / 1MB, 2)
    $freeRamGb  = [math]::Round($os.FreePhysicalMemory / 1MB, 2)
    $usedRamGb  = [math]::Round($totalRamGb - $freeRamGb, 2)
    $ramPercent = [math]::Round(($usedRamGb / $totalRamGb) * 100, 2)

    # 5. Uptime (Tiempo activo)
    $bootTime        = $os.LastBootUpTime
    $uptime          = (Get-Date) - $bootTime
    $uptimeHours     = [math]::Round($uptime.TotalHours, 2)
    $uptimeDays      = [math]::Round($uptime.TotalDays, 2)
    $uptimeFormatted = "{0}:{1:D2}:{2:D2}:{3:D2}" -f [int]$uptime.Days, $uptime.Hours, $uptime.Minutes, $uptime.Seconds

    # 6. Espacio en disco C:
    $driveC = Get-CimInstance -ClassName Win32_LogicalDisk -Filter "DeviceID='C:'" -ErrorAction Stop
    if ($null -eq $driveC -or $driveC.Size -eq 0) {
        throw "No se pudo obtener información de la unidad C:"
    }
    $diskTotalGb     = [math]::Round($driveC.Size / 1GB, 2)
    $diskFreeGb      = [math]::Round($driveC.FreeSpace / 1GB, 2)
    $diskUsedGb      = [math]::Round(($driveC.Size - $driveC.FreeSpace) / 1GB, 2)
    $diskPercentFree = [math]::Round(($driveC.FreeSpace / $driveC.Size) * 100, 2)

    # 7. Servicio SQL Server
    $sqlService = Get-Service -Name "MSSQLSERVER" -ErrorAction SilentlyContinue
    $sqlStatus  = if ($sqlService) { $sqlService.Status.ToString() } else { "NotInstalled" }

    # 8. Estructuración del JSON
    $snapshot = [ordered]@{
        timestamp   = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
        terminal_id = $env:COMPUTERNAME
        system      = [ordered]@{
            cpu_usage_percent   = [int]$cpuLoad
            ram_used_gb         = $usedRamGb
            ram_total_gb        = $totalRamGb
            ram_usage_percent   = $ramPercent
            disk_c_total_gb     = $diskTotalGb
            disk_c_free_gb      = $diskFreeGb
            disk_c_used_gb      = $diskUsedGb
            disk_c_percent_free = $diskPercentFree
            uptime_hours        = $uptimeHours
            uptime_days         = $uptimeDays
            uptime_formatted    = $uptimeFormatted
            last_boot_datetime  = $bootTime.ToString("yyyy-MM-dd HH:mm:ss")
            sql_service_status  = $sqlStatus
        }
    }

    # 9. Escritura atómica en disco
    $tempFile    = Join-Path -Path $telemetryDir -ChildPath "snapshot.tmp"
    $jsonContent = $snapshot | ConvertTo-Json -Depth 4

    Set-Content -Path $tempFile -Value $jsonContent -Encoding UTF8 -ErrorAction Stop
    Move-Item -Path $tempFile -Destination $outputPath -Force -ErrorAction Stop

    Write-Host "[OK] Snapshot generado correctamente en: $outputPath" -ForegroundColor Green

} catch {
    # Captura detallada de la excepción
    $errorMsg = "Línea $($_.InvocationInfo.ScriptLineNumber): $($_.Exception.Message)"
    Write-TelemetryLog -Message $errorMsg -Level "ERROR"
    Write-TelemetryLog -Message "Detalles: $($_.ScriptStackTrace)" -Level "DEBUG"

    Write-Host "[ERROR] Ocurrió un error. Consulta el log en: $logPath" -ForegroundColor Red
    Write-Host "Mensaje: $errorMsg" -ForegroundColor Yellow
}