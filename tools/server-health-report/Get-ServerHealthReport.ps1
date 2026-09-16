#requires -Version 5.1
<#
.SYNOPSIS
Read-only Windows server checks with local HTML and JSON reports.
.DESCRIPTION
Reads CIM data for memory, fixed disks, and selected services. Does not
change services, machine configuration, authentication, or remote settings.
The only files written are reports in OutputDirectory.
See README.md and docs/validation.md for validation scope and limitations.
#>
[CmdletBinding()]
param(
    [ValidateNotNullOrEmpty()][string[]]$ComputerName = @($env:COMPUTERNAME),
    [ValidateNotNullOrEmpty()][string[]]$ServiceName = @('EventLog', 'Winmgmt'),
    [ValidateRange(1,99)][double]$DiskFreeWarningPercent = 15,
    [ValidateRange(1,99)][double]$MemoryUsedWarningPercent = 90,
    [ValidateRange(5,120)][uint32]$OperationTimeoutSec = 20,
    [ValidateNotNullOrEmpty()][string]$OutputDirectory = (Join-Path $PSScriptRoot 'reports')
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$records = New-Object 'System.Collections.Generic.List[object]'

function Add-Check {
    param([string]$Server, [string]$Check, [string]$Target,
          [string]$Status, [string]$Detail)
    $records.Add([pscustomobject][ordered]@{
        Server = $Server
        Check = $Check
        Target = $Target
        Status = $Status
        Detail = $Detail
        CollectedAtUtc = [DateTime]::UtcNow.ToString('o')
    })
}

$targets = @($ComputerName | ForEach-Object { $_.Trim() } |
    Where-Object { $_ } | Sort-Object -Unique)
$expectedServices = @($ServiceName | ForEach-Object { $_.Trim() } |
    Where-Object { $_ } | Sort-Object -Unique)
if ($targets.Count -eq 0) { throw 'At least one computer name is required.' }
if ($expectedServices.Count -eq 0) { throw 'At least one service name is required.' }

foreach ($server in $targets) {
    # Local checks do not need a WinRM connection.
    $queryParameters = @{
        ErrorAction = 'Stop'
        OperationTimeoutSec = $OperationTimeoutSec
    }
    if ($server -notin @('.', 'localhost', $env:COMPUTERNAME)) {
        $queryParameters.ComputerName = $server
    }

    try {
        $os = Get-CimInstance -ClassName Win32_OperatingSystem @queryParameters
        if ($null -eq $os -or $null -eq $os.TotalVisibleMemorySize -or
            $null -eq $os.FreePhysicalMemory) {
            throw 'Memory counters were not returned.'
        }
        $total = [double]$os.TotalVisibleMemorySize
        $free = [double]$os.FreePhysicalMemory
        if ($total -le 0 -or $free -lt 0 -or $free -gt $total) {
            throw 'Memory counters are invalid.'
        }
        $usedPercent = 100 * ($total - $free) / $total
        $state = if ($usedPercent -ge $MemoryUsedWarningPercent) { 'Warning' } else { 'OK' }
        Add-Check $server 'Memory' 'Physical RAM' $state ('{0:N1}% used' -f $usedPercent)
    } catch {
        Add-Check $server 'Memory' 'Physical RAM' 'Unknown' $_.Exception.Message
    }

    try {
        $disks = @(Get-CimInstance -ClassName Win32_LogicalDisk -Filter 'DriveType=3' @queryParameters)
        if ($disks.Count -eq 0) { throw 'No fixed disks were returned.' }
        foreach ($disk in $disks) {
            if ($null -eq $disk.Size -or $null -eq $disk.FreeSpace -or
                [double]$disk.Size -le 0 -or [double]$disk.FreeSpace -lt 0 -or
                [double]$disk.FreeSpace -gt [double]$disk.Size) {
                Add-Check $server 'Disk' ([string]$disk.DeviceID) 'Unknown' 'Disk counters are invalid.'
                continue
            }
            $freePercent = 100 * [double]$disk.FreeSpace / [double]$disk.Size
            $state = if ($freePercent -le $DiskFreeWarningPercent) { 'Warning' } else { 'OK' }
            $detail = '{0:N1}% free ({1:N1} GiB)' -f $freePercent, ([double]$disk.FreeSpace / 1GB)
            Add-Check $server 'Disk' ([string]$disk.DeviceID) $state $detail
        }
    } catch {
        Add-Check $server 'Disk' 'Fixed disks' 'Unknown' $_.Exception.Message
    }

    try {
        $services = @(Get-CimInstance -ClassName Win32_Service -Property Name,State @queryParameters)
        foreach ($requiredService in $expectedServices) {
            $found = @($services | Where-Object { $_.Name -eq $requiredService })
            if ($found.Count -eq 0) {
                Add-Check $server 'Service' $requiredService 'Critical' 'Required service was not found.'
            } elseif ($found[0].State -ne 'Running') {
                Add-Check $server 'Service' $requiredService 'Critical' ('State: ' + $found[0].State)
            } else {
                Add-Check $server 'Service' $requiredService 'OK' 'Running'
            }
        }
    } catch {
        # A query failure is not proof that a service is stopped or missing.
        Add-Check $server 'Service' 'Selected services' 'Unknown' $_.Exception.Message
    }
}

$checks = @($records.ToArray())
$summary = [pscustomobject][ordered]@{
    ComputersRequested = $targets.Count
    Checks = $checks.Count
    OK = @($checks | Where-Object { $_.Status -eq 'OK' }).Count
    Warning = @($checks | Where-Object { $_.Status -eq 'Warning' }).Count
    Critical = @($checks | Where-Object { $_.Status -eq 'Critical' }).Count
    Unknown = @($checks | Where-Object { $_.Status -eq 'Unknown' }).Count
}
$payload = [pscustomobject][ordered]@{
    SchemaVersion = 1
    GeneratedAtUtc = [DateTime]::UtcNow.ToString('o')
    Thresholds = [pscustomobject]@{
        DiskFreeWarningPercent = $DiskFreeWarningPercent
        MemoryUsedWarningPercent = $MemoryUsedWarningPercent
    }
    Summary = $summary
    Checks = $checks
}

if (-not (Test-Path -LiteralPath $OutputDirectory)) {
    $null = New-Item -ItemType Directory -Path $OutputDirectory
}
$outputItem = Get-Item -LiteralPath $OutputDirectory
if (-not $outputItem.PSIsContainer) { throw 'OutputDirectory must be a directory.' }
$stamp = [DateTime]::UtcNow.ToString('yyyyMMddTHHmmssfffZ')
$jsonPath = Join-Path $outputItem.FullName ('server-health-' + $stamp + '.json')
$htmlPath = Join-Path $outputItem.FullName ('server-health-' + $stamp + '.html')

function Encode-Html([object]$Value) {
    [System.Net.WebUtility]::HtmlEncode([string]$Value)
}
$rows = foreach ($check in $checks) {
    $cells = foreach ($field in @('Server','Check','Target','Status','Detail','CollectedAtUtc')) {
        '<td>' + (Encode-Html $check.$field) + '</td>'
    }
    '<tr class="' + $check.Status.ToLowerInvariant() + '">' + ($cells -join '') + '</tr>'
}
$summaryText = 'OK: {0} | Warning: {1} | Critical: {2} | Unknown: {3}' -f $summary.OK, $summary.Warning, $summary.Critical, $summary.Unknown
$html = @"
<!doctype html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Windows Server Health Report</title>
<style>
body{font-family:Segoe UI,Arial,sans-serif;color:#172033;background:#f5f7fb;margin:0;padding:32px}
main{max-width:1280px;margin:auto;background:white;padding:28px;border:1px solid #dde3ec;border-radius:12px}
h1{font-size:28px;margin:0 0 12px}p{line-height:1.6}
.scroll{overflow-x:auto}table{border-collapse:collapse;width:100%;font-size:14px}
th,td{text-align:left;border-bottom:1px solid #dde3ec;padding:12px;vertical-align:top}
th{background:#eef2f7}.warning td:nth-child(4){color:#805500;font-weight:600}
.critical td:nth-child(4){color:#a81724;font-weight:600}
.unknown td:nth-child(4){color:#6044a0;font-weight:600}
.ok td:nth-child(4){color:#12653b;font-weight:600}td{overflow-wrap:anywhere}
</style></head><body><main>
<h1>Windows Server Health Report</h1>
<p>Generated at $(Encode-Html $payload.GeneratedAtUtc)</p>
<p>$(Encode-Html $summaryText)</p>
<p>Unknown means data could not be collected or validated. OK applies only to the checks shown; it is not a complete assessment of a server.</p>
<div class="scroll"><table><thead><tr><th>Server</th><th>Check</th><th>Target</th><th>Status</th><th>Detail</th><th>Collected at UTC</th></tr></thead>
<tbody>$($rows -join [Environment]::NewLine)</tbody></table></div>
</main></body></html>
"@
$utf8 = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($jsonPath, ($payload | ConvertTo-Json -Depth 6), $utf8)
[System.IO.File]::WriteAllText($htmlPath, $html, $utf8)
[pscustomobject]@{ HtmlReport = $htmlPath; JsonReport = $jsonPath; Summary = $summary }
