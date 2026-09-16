#requires -Version 5.1
[CmdletBinding()]
param()
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$subject = Join-Path (Split-Path $PSScriptRoot -Parent) 'Get-ServerHealthReport.ps1'
$tokens = $null
$parseErrors = $null
$null = [System.Management.Automation.Language.Parser]::ParseFile($subject, [ref]$tokens, [ref]$parseErrors)
if ($parseErrors.Count -gt 0) { throw ($parseErrors | Out-String) }
Write-Host 'PASS: PowerShell parser'
$testRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('health-report-tests-' + [Guid]::NewGuid().ToString('N'))
$null = New-Item -ItemType Directory -Path $testRoot
$global:HealthReportTestFixture = 'Healthy'
$global:HealthReportTestCalls = New-Object 'System.Collections.Generic.List[object]'

# Script scope shadows the CIM cmdlet only inside this test process.
function Get-CimInstance {
    [CmdletBinding()]
    param([string]$ClassName, [string]$Filter, [string[]]$Property,
          [string]$ComputerName, [uint32]$OperationTimeoutSec)
    $global:HealthReportTestCalls.Add([pscustomobject]@{
        Class = $ClassName; Remote = $PSBoundParameters.ContainsKey('ComputerName')
    })
    if ($global:HealthReportTestFixture -eq 'QueryFailure' -or $ComputerName -eq 'offline.example.test') {
        throw 'Simulated access or connection failure'
    }
    switch ($ClassName) {
        'Win32_OperatingSystem' {
            if ($global:HealthReportTestFixture -eq 'EscapeHtml') { throw '<script>alert("test")</script> & denied' }
            $total = 10000; $free = 5000
            if ($global:HealthReportTestFixture -eq 'NearThreshold') { $free = 1004 }
            if ($global:HealthReportTestFixture -eq 'AtThreshold') { $free = 1000 }
            if ($global:HealthReportTestFixture -eq 'InvalidCounters') { $total = 0; $free = 0 }
            [pscustomobject]@{ TotalVisibleMemorySize = $total; FreePhysicalMemory = $free }
        }
        'Win32_LogicalDisk' {
            if ($Filter -ne 'DriveType=3') { throw 'Fixed-disk filter missing' }
            if ($global:HealthReportTestFixture -eq 'EmptyDisks') { return }
            $size = 10000; $free = 5000
            if ($global:HealthReportTestFixture -eq 'NearThreshold') { $free = 1504 }
            if ($global:HealthReportTestFixture -eq 'AtThreshold') { $free = 1500 }
            if ($global:HealthReportTestFixture -eq 'InvalidCounters') { $size = 0; $free = 0 }
            [pscustomobject]@{ DeviceID = 'C:'; Size = $size; FreeSpace = $free }
        }
        'Win32_Service' {
            if ($global:HealthReportTestFixture -eq 'ServiceProblems') {
                [pscustomobject]@{ Name = 'EventLog'; State = 'Stopped' }
            } else {
                [pscustomobject]@{ Name = 'EventLog'; State = 'Running' }
                [pscustomobject]@{ Name = 'Winmgmt'; State = 'Running' }
            }
        }
        default { throw "Unexpected CIM class: $ClassName" }
    }
}
function Assert-True([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw "FAIL: $Message" }
}
function Invoke-Fixture([string]$Name, [string[]]$Computers = @('.'), [string[]]$Services = @('EventLog','Winmgmt')) {
    $global:HealthReportTestFixture = $Name
    $result = & $subject -ComputerName $Computers -ServiceName $Services -OutputDirectory (Join-Path $testRoot ([Guid]::NewGuid().ToString('N')))
    $json = Get-Content -LiteralPath $result.JsonReport -Raw | ConvertFrom-Json
    $html = Get-Content -LiteralPath $result.HtmlReport -Raw
    Assert-True ($json.SchemaVersion -eq 1) 'JSON schema'
    Assert-True ($json.Summary.Checks -eq @($json.Checks).Count) 'Summary count matches rows'
    Assert-True (($json.Summary.OK + $json.Summary.Warning + $json.Summary.Critical + $json.Summary.Unknown) -eq $json.Summary.Checks) 'Every check has a recognized status'
    Assert-True ($html.Contains('<table>') -and $html.Contains('</html>')) 'Complete HTML document'
    $null = [DateTimeOffset]::Parse($json.GeneratedAtUtc)
    foreach ($check in $json.Checks) { $null = [DateTimeOffset]::Parse($check.CollectedAtUtc) }
    [pscustomobject]@{ Data = $json; Html = $html }
}
try {
    $r = Invoke-Fixture 'Healthy'
    Assert-True ($r.Data.Summary.OK -eq 4 -and $r.Data.Summary.Unknown -eq 0) 'Healthy inputs'
    Assert-True (@($global:HealthReportTestCalls | Where-Object Remote).Count -eq 0) 'Local collection does not request WinRM'
    Write-Host 'PASS: healthy input, local collection, output structure and timestamps'

    $r = Invoke-Fixture 'NearThreshold'
    Assert-True ($r.Data.Summary.Warning -eq 0) 'Threshold comparisons must precede display rounding'
    Write-Host 'PASS: unrounded threshold comparisons'

    $r = Invoke-Fixture 'AtThreshold'
    Assert-True ($r.Data.Summary.Warning -eq 2) 'Exact threshold is a warning'
    Write-Host 'PASS: inclusive thresholds'

    $r = Invoke-Fixture 'ServiceProblems'
    Assert-True ($r.Data.Summary.Critical -eq 2) 'Stopped and missing services are critical'
    Write-Host 'PASS: stopped and missing services'

    $r = Invoke-Fixture 'QueryFailure'
    Assert-True ($r.Data.Summary.Unknown -eq 3 -and $r.Data.Summary.OK -eq 0 -and $r.Data.Summary.Critical -eq 0) 'Unavailable data cannot be healthy or proof of a missing service'
    Write-Host 'PASS: query failures remain unknown'

    $r = Invoke-Fixture 'InvalidCounters'
    Assert-True ($r.Data.Summary.Unknown -eq 2) 'Invalid memory and disk counters'
    Write-Host 'PASS: invalid counters'

    $r = Invoke-Fixture 'EmptyDisks'
    Assert-True ($r.Data.Summary.Unknown -eq 1) 'An empty disk query is not a healthy disk'
    Write-Host 'PASS: absent disk data'

    $r = Invoke-Fixture 'EscapeHtml' -Computers @('<img src=x onerror=alert(1)>')
    Assert-True (-not $r.Html.Contains('<script>') -and -not $r.Html.Contains('<img ')) 'Dynamic HTML must be escaped'
    Assert-True ($r.Html.Contains('&lt;script&gt;') -and $r.Html.Contains('&lt;img')) 'Escaped values remain readable'
    Assert-True ($r.Data.Checks[0].Server -eq '<img src=x onerror=alert(1)>') 'JSON preserves original text'
    Write-Host 'PASS: HTML escaping and JSON fidelity'

    $r = Invoke-Fixture 'Healthy' -Computers @('healthy.example.test','offline.example.test')
    Assert-True ($r.Data.Summary.ComputersRequested -eq 2 -and $r.Data.Summary.OK -eq 4 -and $r.Data.Summary.Unknown -eq 3) 'One failed server must not hide another server'
    Write-Host 'PASS: partial collection across multiple servers'

    $r = Invoke-Fixture 'Healthy' -Computers @(' . ','.') -Services @('EventLog',' EventLog ','Winmgmt')
    Assert-True ($r.Data.Summary.ComputersRequested -eq 1 -and $r.Data.Summary.Checks -eq 4) 'Normalize and deduplicate input'
    Write-Host 'PASS: input normalization'

    $rejected = $false
    try { $null = & $subject -ComputerName ' ' -OutputDirectory $testRoot } catch { $rejected = $true }
    Assert-True $rejected 'Reject whitespace-only computer input'
    $rejected = $false
    try { $null = & $subject -ServiceName ' ' -OutputDirectory $testRoot } catch { $rejected = $true }
    Assert-True $rejected 'Reject whitespace-only service input'
    $rejected = $false
    try { $null = & $subject -DiskFreeWarningPercent 0 -OutputDirectory $testRoot } catch { $rejected = $true }
    Assert-True $rejected 'Reject an out-of-range threshold'
    Write-Host 'PASS: invalid parameters'

    $fileTarget = Join-Path $testRoot 'not-a-directory.txt'
    Set-Content -LiteralPath $fileTarget -Value 'preserve this file'
    $rejected = $false
    try { $null = & $subject -ComputerName . -OutputDirectory $fileTarget } catch { $rejected = $true }
    Assert-True $rejected 'Reject a file as the output directory'
    Assert-True ((Get-Content -LiteralPath $fileTarget -Raw).Trim() -eq 'preserve this file') 'Do not overwrite an existing file'
    Write-Host 'PASS: output directory validation'
    Write-Host ('ALL TESTS PASSED on PowerShell ' + $PSVersionTable.PSVersion.ToString())
} finally {
    Remove-Variable HealthReportTestFixture,HealthReportTestCalls -Scope Global -ErrorAction SilentlyContinue
    # Generated reports stay in the disposable runner temp directory.
}
