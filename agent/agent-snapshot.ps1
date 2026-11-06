# ==============================================================================
# MADISA TELEMETRY - AGENTE TPV GENÉRICO
# ==============================================================================
param (
    [string]$OutputDir = "C:\Madisa\Telemetry"
)

$ErrorActionPreference = "SilentlyContinue"

# Garantizar existencia de directorio
if (-not (Test-Path $OutputDir)) {
    New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
}

$logFile    = Join-Path -Path $OutputDir -ChildPath "agent.log"
$configFile = Join-Path -Path $OutputDir -ChildPath "config.json"

function Write-AgentLog ([string]$msg) {
    $timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    "[$timestamp] $msg" | Out-File -FilePath $logFile -Append -Encoding UTF8
}

# ------------------------------------------------------------------------------
# 1. Cargar Configuración del Cliente desde config.json
# ------------------------------------------------------------------------------
$ProjectId   = "loho-3ca05"
$ClientId    = "#" # NOMBRE CLIENTE
$ClientName  = "#" # DISPOSITIVO
$Delegation  = "PALMA" # DELEGACIÓN
$Zone        = 1

if (Test-Path $configFile) {
    try {
        $cfg = Get-Content -Path $configFile -Raw -Encoding UTF8 | ConvertFrom-Json
        if ($cfg.project_id)     { $ProjectId  = [string]$cfg.project_id }
        if ($cfg.client_id)      { $ClientId   = [string]$cfg.client_id }
        if ($cfg.client_name)    { $ClientName = [string]$cfg.client_name }
        if ($cfg.delegation)     { $Delegation = [string]$cfg.delegation }
        if ($null -ne $cfg.zone) { $Zone       = [int]$cfg.zone }
    } catch {
        Write-AgentLog "AVISO: Error leyendo config.json, usando parametros por defecto."
    }
} else {
    # Si no existe, crear la plantilla inicial automáticamente
    $template = [ordered]@{
        project_id  = $ProjectId
        client_id   = $ClientId
        client_name = $ClientName
        delegation  = $Delegation
        zone        = $Zone
    }
    $template | ConvertTo-Json -Depth 2 | Set-Content -Path $configFile -Encoding UTF8
    Write-AgentLog "CONFIG: config.json no existía. Se ha generado la plantilla inicial."
}

# ------------------------------------------------------------------------------
# 2. Rutina de Auto-Actualización Segura (Descarga a archivo, sin irm | iex)
# ------------------------------------------------------------------------------
$CurrentVersion  = "1.2.3"
$UpdateScriptUrl = "https://raw.githubusercontent.com/TrOgI10/MadisaTelemetry/refs/heads/main/agent/agent-snapshot.ps1"

try {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $wc = New-Object System.Net.WebClient
    $wc.Headers.Add("User-Agent", "MadisaTelemetryAgent")

    $tempScriptPath = Join-Path -Path $OutputDir -ChildPath "agent-snapshot.tmp"
    $wc.DownloadFile($UpdateScriptUrl, $tempScriptPath)

    if (Test-Path $tempScriptPath) {
        # Inspeccionar cabecera del script descargado en disco
        $remoteVersionLine = Get-Content -Path $tempScriptPath | Select-String -Pattern '\$CurrentVersion\s*=\s*"([^"]+)"'
        if ($remoteVersionLine) {
            $remoteVersion = $remoteVersionLine.Matches.Groups[1].Value

            if ($remoteVersion -and $remoteVersion -ne $CurrentVersion) {
                Write-AgentLog "UPDATE: Detectada version $remoteVersion (actual: $CurrentVersion). Reemplazando script..."

                $thisScript = $MyInvocation.MyCommand.Path
                if (-not $thisScript) { $thisScript = Join-Path -Path $OutputDir -ChildPath "agent-snapshot.ps1" }

                # Reemplazo atómico de archivo
                Copy-Item -Path $tempScriptPath -Destination $thisScript -Force
                Remove-Item -Path $tempScriptPath -Force -ErrorAction SilentlyContinue
                Write-AgentLog "OK: Script actualizado a version $remoteVersion."
            } else {
                Remove-Item -Path $tempScriptPath -Force -ErrorAction SilentlyContinue
            }
        }
    }
} catch {
    # Falla silenciosamente si el TPV no tiene salida a GitHub en ese momento
}

# ------------------------------------------------------------------------------
# 3. Recolección de Métricas de Telemetría
# ------------------------------------------------------------------------------
try {
    $computerName = if ($env:COMPUTERNAME) { $env:COMPUTERNAME } else { "UNKNOWN-PC" }
    $docId = ("{0}_{1}" -f $ClientId, $computerName).ToUpper()

    # CPU y Memoria RAM
    $os = Get-CimInstance -ClassName Win32_OperatingSystem -OperationTimeoutSec 10
    $cpuLoad = (Get-CimInstance -ClassName Win32_Processor -OperationTimeoutSec 10 | Measure-Object -Property LoadPercentage -Average).Average
    if ($null -eq $cpuLoad) { $cpuLoad = 0 }

    $totalRamGb = [math]::Round($os.TotalVisibleMemorySize / 1MB, 2)
    $freeRamGb  = [math]::Round($os.FreePhysicalMemory / 1MB, 2)
    $usedRamGb  = [math]::Round($totalRamGb - $freeRamGb, 2)
    $ramPercent = [math]::Round(($usedRamGb / $totalRamGb) * 100, 2)

    # Almacenamiento Disco C: y Uptime
    $driveC          = Get-CimInstance -ClassName Win32_LogicalDisk -Filter "DeviceID='C:'" -OperationTimeoutSec 10
    $diskTotalGb     = [math]::Round($driveC.Size / 1GB, 2)
    $diskFreeGb      = [math]::Round($driveC.FreeSpace / 1GB, 2)
    $diskUsedGb      = [math]::Round(($driveC.Size - $driveC.FreeSpace) / 1GB, 2)
    $diskPercentFree = [math]::Round(($driveC.FreeSpace / $driveC.Size) * 100, 2)

    $uptime      = (Get-Date) - $os.LastBootUpTime
    $uptimeHours = [math]::Round($uptime.TotalHours, 1)

    if ($uptime.Days -gt 0) {
        $uptimeHuman = "{0} d {1} h" -f $uptime.Days, $uptime.Hours
    } elseif ($uptime.Hours -gt 0) {
        $uptimeHuman = "{0} h {1} min" -f $uptime.Hours, $uptime.Minutes
    } else {
        $uptimeHuman = "{0} min" -f $uptime.Minutes
    }

    $uptimeFormatted = "{0}:{1:D2}:{2:D2}:{3:D2}" -f [int]$uptime.Days, $uptime.Hours, $uptime.Minutes, $uptime.Seconds

    # Estado de SQL Server y Cola de Impresión
    $sqlService = Get-Service -Name "MSSQLSERVER" -ErrorAction SilentlyContinue
    $sqlStatus  = if ($sqlService) { $sqlService.Status.ToString() } else { "NotInstalled" }
    $spoolJobs  = (Get-CimInstance -ClassName Win32_PrintJob -OperationTimeoutSec 10 -ErrorAction SilentlyContinue | Measure-Object).Count

    # 5. IP Privada Local Real (filtrando adaptadores virtuales y buscando la ruta al router)
    $localIp = (Get-NetRoute -DestinationPrefix "0.0.0.0/0" -ErrorAction SilentlyContinue |
        Sort-Object -Property RouteMetric |
        Select-Object -First 1 |
        ForEach-Object {
            (Get-NetIPAddress -InterfaceIndex $_.InterfaceIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue).IPAddress
        })

    # Si por algún motivo no hay ruta por defecto (offline en ese momento), filtrar interfaces conocidas
    if ([string]::IsNullOrWhiteSpace($localIp)) {
        $localIp = (Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue |
            Where-Object { 
                $_.IPAddress -notlike "127.*" -and 
                $_.IPAddress -notlike "169.254.*" -and
                $_.IPAddress -notlike "192.168.56.*" -and
                $_.InterfaceAlias -notmatch "VirtualBox|VMware|vEthernet|Loopback|WSL|Docker"
            } |
            Select-Object -First 1).IPAddress
    }

    if ([string]::IsNullOrWhiteSpace($localIp)) { $localIp = "No disponible" }

    # Procesos Principales (Top 3 por RAM y Top 3 por CPU)
    $allProcesses = Get-Process -ErrorAction SilentlyContinue

    $rawTopRam = $allProcesses | Where-Object { $_.WorkingSet64 -gt 0 } | Sort-Object -Property WorkingSet64 -Descending | Select-Object -First 3
    $topRamLocal = @()
    $topRamJsonItems = @()

    foreach ($p in $rawTopRam) {
        $ramMb = [math]::Round($p.WorkingSet64 / 1MB, 1)
        $pName = [string]$p.ProcessName

        $topRamLocal += [ordered]@{
            name   = $pName
            ram_mb = $ramMb
        }

        $topRamJsonItems += '{"mapValue":{"fields":{"name":{"stringValue":"' + $pName.Replace('\','\\').Replace('"','\"') + '"},"ram_mb":{"doubleValue":' + $ramMb.ToString([System.Globalization.CultureInfo]::InvariantCulture) + '}}}}'
    }

    $rawTopCpu = $allProcesses | Where-Object { $null -ne $_.CPU -and $_.CPU -gt 0 } | Sort-Object -Property CPU -Descending | Select-Object -First 3
    $topCpuLocal = @()
    $topCpuJsonItems = @()

    foreach ($p in $rawTopCpu) {
        $cpuSec = [math]::Round([double]$p.CPU, 1)
        $pName = [string]$p.ProcessName

        $topCpuLocal += [ordered]@{
            name        = $pName
            cpu_seconds = $cpuSec
        }

        $topCpuJsonItems += '{"mapValue":{"fields":{"name":{"stringValue":"' + $pName.Replace('\','\\').Replace('"','\"') + '"},"cpu_seconds":{"doubleValue":' + $cpuSec.ToString([System.Globalization.CultureInfo]::InvariantCulture) + '}}}}'
    }

    # Guardar snapshot local de diagnóstico
    $localData = [ordered]@{
        id          = $docId
        client_id   = $ClientId
        client_name = $ClientName
        delegation  = $Delegation
        zone        = $Zone
        terminal_id = $computerName
        timestamp   = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
        system      = [ordered]@{
            ip_private          = $localIp
            cpu_usage_percent   = [int]$cpuLoad
            ram_used_gb         = $usedRamGb
            ram_total_gb        = $totalRamGb
            ram_usage_percent   = $ramPercent
            disk_c_total_gb     = $diskTotalGb
            disk_c_free_gb      = $diskFreeGb
            disk_c_used_gb      = $diskUsedGb
            disk_c_percent_free = $diskPercentFree
            sql_service_status  = $sqlStatus
            print_spooler_jobs  = $spoolJobs
            uptime_hours        = $uptimeHours
            uptime_human        = $uptimeHuman
            uptime_formatted    = $uptimeFormatted
            top_ram_processes   = $topRamLocal
            top_cpu_processes   = $topCpuLocal
        }
    }

    Write-AgentLog "PRUEBA: Ejecutando version actualizada 1.2.3 con exito."
    
    $jsonPath = Join-Path -Path $OutputDir -ChildPath "snapshot.json"
    $localData | ConvertTo-Json -Depth 6 | Set-Content -Path $jsonPath -Encoding UTF8

    # --------------------------------------------------------------------------
    # 4. Enviar Telemetría a Firestore REST API
    # --------------------------------------------------------------------------
    $ci = [System.Globalization.CultureInfo]::InvariantCulture
    $topRamArrayJson = if ($topRamJsonItems.Count -gt 0) { ($topRamJsonItems -join ",") } else { "" }
    $topCpuArrayJson = if ($topCpuJsonItems.Count -gt 0) { ($topCpuJsonItems -join ",") } else { "" }

    $firestorePayload = @"
{
  "fields": {
    "client_id": { "stringValue": "$ClientId" },
    "client_name": { "stringValue": "$ClientName" },
    "delegation": { "stringValue": "$Delegation" },
    "zone": { "integerValue": $Zone },
    "terminal_id": { "stringValue": "$computerName" },
    "timestamp": { "stringValue": "$($localData.timestamp)" },
    "system": {
      "mapValue": {
        "fields": {
          "ip_private": { "stringValue": "$localIp" },
          "cpu_usage_percent": { "integerValue": $([int]$cpuLoad) },
          "ram_used_gb": { "doubleValue": $($usedRamGb.ToString($ci)) },
          "ram_total_gb": { "doubleValue": $($totalRamGb.ToString($ci)) },
          "ram_usage_percent": { "doubleValue": $($ramPercent.ToString($ci)) },
          "disk_c_total_gb": { "doubleValue": $($diskTotalGb.ToString($ci)) },
          "disk_c_free_gb": { "doubleValue": $($diskFreeGb.ToString($ci)) },
          "disk_c_used_gb": { "doubleValue": $($diskUsedGb.ToString($ci)) },
          "disk_c_percent_free": { "doubleValue": $($diskPercentFree.ToString($ci)) },
          "sql_service_status": { "stringValue": "$sqlStatus" },
          "print_spooler_jobs": { "integerValue": $spoolJobs },
          "uptime_hours": { "doubleValue": $($uptimeHours.ToString($ci)) },
          "uptime_human": { "stringValue": "$uptimeHuman" },
          "uptime_formatted": { "stringValue": "$uptimeFormatted" },
          "top_ram_processes": {
            "arrayValue": {
              "values": [ $topRamArrayJson ]
            }
          },
          "top_cpu_processes": {
            "arrayValue": {
              "values": [ $topCpuArrayJson ]
            }
          }
        }
      }
    }
  }
}
"@

    $apiUrl = "https://firestore.googleapis.com/v1/projects/$ProjectId/databases/(default)/documents/terminals/$docId"
    
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $response = Invoke-RestMethod -Uri $apiUrl -Method Patch -Body ([System.Text.Encoding]::UTF8.GetBytes($firestorePayload)) -ContentType "application/json; charset=utf-8" -TimeoutSec 15

    Write-AgentLog "OK: Snapshot enviado correctamente a Firestore (Doc: $docId)"

} catch {
    $errDetail = $_.Exception.Message
    if ($_.Exception.Response) {
        try {
            $stream = $_.Exception.Response.GetResponseStream()
            $reader = New-Object System.IO.StreamReader($stream)
            $errDetail = $reader.ReadToEnd()
        } catch {}
    }
    Write-AgentLog "ERROR: $errDetail (Linea $($_.InvocationInfo.ScriptLineNumber))"
}