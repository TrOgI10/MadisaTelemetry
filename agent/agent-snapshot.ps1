# ==============================================================================
# MADISA TELEMETRY - AGENTE TPV (PLAN SPARK)
# ==============================================================================
param (
    [string]$ProjectId   = "loho-3ca05",  # Sustituir por el Project ID activo si procede
    [string]$ClientId    = "",     # Código de cliente
    [string]$ClientName  = "Mega Perk",    # Nombre comercial
    [string]$Delegation  = "PALMA",          # Delegación
    [int]$Zone           = 1,
    [string]$OutputDir   = "C:\Projects\MadisaTelemetry\frontend\public"
)

$ErrorActionPreference = "SilentlyContinue"

if (-not (Test-Path $OutputDir)) {
    New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
}

try {
    # 1. Identificador único determinista de este TPV (ej: CLI-SOLLER_WHY_TROGI_PC)
    $computerName = $env:COMPUTERNAME
    $docId = ("{0}{1}" -f $ClientId, $computerName).ToUpper()

    # 2. Diagnóstico del Sistema
    $os = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction Stop
    $cpuLoad = (Get-CimInstance -ClassName Win32_Processor -ErrorAction Stop | Measure-Object -Property LoadPercentage -Average).Average
    if ($null -eq $cpuLoad) { $cpuLoad = 0 }

    $totalRamGb = [math]::Round($os.TotalVisibleMemorySize / 1MB, 2)
    $freeRamGb  = [math]::Round($os.FreePhysicalMemory / 1MB, 2)
    $usedRamGb  = [math]::Round($totalRamGb - $freeRamGb, 2)
    $ramPercent = [math]::Round(($usedRamGb / $totalRamGb) * 100, 2)

    # 3. Disco C: y Uptime
    $driveC          = Get-CimInstance -ClassName Win32_LogicalDisk -Filter "DeviceID='C:'" -ErrorAction Stop
    $diskPercentFree = [math]::Round(($driveC.FreeSpace / $driveC.Size) * 100, 2)
    $uptime          = (Get-Date) - $os.LastBootUpTime
    $uptimeFormatted = "{0}:{1:D2}:{2:D2}:{3:D2}" -f [int]$uptime.Days, $uptime.Hours, $uptime.Minutes, $uptime.Seconds

    # 4. Servicio SQL Server y Cola de Impresión (CIM para evitar conflictos de parámetros)
    $sqlService = Get-Service -Name "MSSQLSERVER" -ErrorAction SilentlyContinue
    $sqlStatus  = if ($sqlService) { $sqlService.Status.ToString() } else { "NotInstalled" }
    $spoolJobs  = (Get-CimInstance -ClassName Win32_PrintJob -ErrorAction SilentlyContinue | Measure-Object).Count

    # 5. Generar y guardar el archivo JSON localmente
    $localData = [ordered]@{
        id          = $docId
        client_id   = $ClientId
        client_name = $ClientName
        delegation  = $Delegation
        zone        = $Zone
        terminal_id = $computerName
        timestamp   = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
        system      = [ordered]@{
            cpu_usage_percent   = [int]$cpuLoad
            ram_used_gb         = $usedRamGb
            ram_total_gb        = $totalRamGb
            disk_c_percent_free = $diskPercentFree
            sql_service_status  = $sqlStatus
            print_spooler_jobs  = $spoolJobs
            uptime_formatted    = $uptimeFormatted
        }
    }
    
    $jsonPath = Join-Path -Path $OutputDir -ChildPath "snapshot.json"
    $localData | ConvertTo-Json -Depth 5 | Set-Content -Path $jsonPath -Encoding UTF8
    Write-Host "[1/2] JSON local guardado en: $jsonPath" -ForegroundColor Cyan

    # 6. Payload formateado para la API REST de Firestore
    $firestorePayload = @{
        fields = @{
            client_id     = @{ stringValue = $ClientId }
            client_name   = @{ stringValue = $ClientName }
            delegation    = @{ stringValue = $Delegation }
            zone          = @{ integerValue = $Zone }
            terminal_id   = @{ stringValue = $computerName }
            timestamp     = @{ stringValue = $localData.timestamp }
            system        = @{
                mapValue = @{
                    fields = @{
                        cpu_usage_percent   = @{ integerValue = [int]$cpuLoad }
                        ram_used_gb         = @{ doubleValue = [double]$usedRamGb }
                        ram_total_gb        = @{ doubleValue = [double]$totalRamGb }
                        disk_c_percent_free = @{ doubleValue = [double]$diskPercentFree }
                        sql_service_status  = @{ stringValue = $sqlStatus }
                        print_spooler_jobs  = @{ integerValue = $spoolJobs }
                        uptime_formatted    = @{ stringValue = $uptimeFormatted }
                    }
                }
            }
        }
    } | ConvertTo-Json -Depth 6

    # 7. Envío PATCH al endpoint del documento exacto para sobrescribir y evitar duplicados
    $apiUrl = "https://firestore.googleapis.com/v1/projects/$ProjectId/databases/(default)/documents/terminals/$docId"

    $webClient = New-Object System.Net.WebClient
    $webClient.Headers.Add("Content-Type", "application/json; charset=utf-8")
    
    $payloadBytes = [System.Text.Encoding]::UTF8.GetBytes($firestorePayload)
    $responseBytes = $webClient.UploadData($apiUrl, "PATCH", $payloadBytes)
    $responseString = [System.Text.Encoding]::UTF8.GetString($responseBytes)

    Write-Host "[2/2] Firestore actualizado correctamente (Doc ID: $docId)" -ForegroundColor Green

} catch {
    Write-Host "[ERROR] $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "En la línea: $($_.InvocationInfo.ScriptLineNumber)" -ForegroundColor Yellow
}