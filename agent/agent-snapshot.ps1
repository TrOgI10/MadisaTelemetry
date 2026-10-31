# ==============================================================================
# MADISA TELEMETRY - AGENTE TPV (PLAN SPARK)
# ==============================================================================
param (
    [string]$ProjectId   = "loho-3ca05",
    [string]$ClientId    = "CLI-MADISA",
    [string]$ClientName  = "Central Madisa",
    [string]$Delegation  = "PALMA",
    [int]$Zone           = 1,
    [string]$OutputDir   = "C:\Madisa\Telemetry"
)

$ErrorActionPreference = "SilentlyContinue"

if (-not (Test-Path $OutputDir)) {
    New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
}

try {
    # 1. Identificador unico de este TPV
    $computerName = $env:COMPUTERNAME
    $docId = ("{0}_{1}" -f $ClientId, $computerName).ToUpper()

    # 2. Diagnostico del Sistema (CPU y RAM)
    $os = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction Stop
    $cpuLoad = (Get-CimInstance -ClassName Win32_Processor -ErrorAction Stop | Measure-Object -Property LoadPercentage -Average).Average
    if ($null -eq $cpuLoad) { $cpuLoad = 0 }

    $totalRamGb = [math]::Round($os.TotalVisibleMemorySize / 1MB, 2)
    $freeRamGb  = [math]::Round($os.FreePhysicalMemory / 1MB, 2)
    $usedRamGb  = [math]::Round($totalRamGb - $freeRamGb, 2)
    $ramPercent = [math]::Round(($usedRamGb / $totalRamGb) * 100, 2)

    # 3. Disco C: y Uptime legible
    $driveC          = Get-CimInstance -ClassName Win32_LogicalDisk -Filter "DeviceID='C:'" -ErrorAction Stop
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

    # 4. Servicio SQL Server y Cola de Impresion
    $sqlService = Get-Service -Name "MSSQLSERVER" -ErrorAction SilentlyContinue
    $sqlStatus  = if ($sqlService) { $sqlService.Status.ToString() } else { "NotInstalled" }
    $spoolJobs  = (Get-CimInstance -ClassName Win32_PrintJob -ErrorAction SilentlyContinue | Measure-Object).Count

    # 5. Generar y guardar JSON local
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
        }
    }
    
    $jsonPath = Join-Path -Path $OutputDir -ChildPath "snapshot.json"
    $localData | ConvertTo-Json -Depth 5 | Set-Content -Path $jsonPath -Encoding UTF8
    Write-Host "[1/2] JSON local guardado en: $jsonPath" -ForegroundColor Cyan

    # 6. Payload para la API REST de Firestore
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
                        ram_usage_percent   = @{ doubleValue = [double]$ramPercent }
                        disk_c_total_gb     = @{ doubleValue = [double]$diskTotalGb }
                        disk_c_free_gb      = @{ doubleValue = [double]$diskFreeGb }
                        disk_c_used_gb      = @{ doubleValue = [double]$diskUsedGb }
                        disk_c_percent_free = @{ doubleValue = [double]$diskPercentFree }
                        sql_service_status  = @{ stringValue = $sqlStatus }
                        print_spooler_jobs  = @{ integerValue = $spoolJobs }
                        uptime_hours        = @{ doubleValue = [double]$uptimeHours }
                        uptime_human        = @{ stringValue = $uptimeHuman }
                        uptime_formatted    = @{ stringValue = $uptimeFormatted }
                    }
                }
            }
        }
    } | ConvertTo-Json -Depth 6

    # 7. Envio PATCH a Firestore
    $apiUrl = "https://firestore.googleapis.com/v1/projects/$ProjectId/databases/(default)/documents/terminals/$docId"

    $webClient = New-Object System.Net.WebClient
    $webClient.Headers.Add("Content-Type", "application/json; charset=utf-8")
    
    $payloadBytes = [System.Text.Encoding]::UTF8.GetBytes($firestorePayload)
    $responseBytes = $webClient.UploadData($apiUrl, "PATCH", $payloadBytes)
    $responseString = [System.Text.Encoding]::UTF8.GetString($responseBytes)

    Write-Host "[2/2] Firestore actualizado correctamente (Doc ID: $docId)" -ForegroundColor Green

} catch {
    Write-Host "[ERROR] $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "En la linea: $($_.InvocationInfo.ScriptLineNumber)" -ForegroundColor Yellow
}