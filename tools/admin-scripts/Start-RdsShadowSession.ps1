#requires -Version 5.1
<#
.SYNOPSIS
List RDS sessions or open a selected session for shadow viewing/control.
.DESCRIPTION
Does not use /noConsentPrompt and does not change host consent policies.
#>
[CmdletBinding(SupportsShouldProcess = $true, DefaultParameterSetName = 'List')]
param(
    [Parameter(Mandatory)][ValidatePattern('^[A-Za-z0-9][A-Za-z0-9.-]{0,252}$')][string]$ComputerName,
    [Parameter(Mandatory, ParameterSetName = 'Shadow')][ValidateRange(1,2147483647)][int]$SessionId,
    [Parameter(ParameterSetName = 'Shadow')][switch]$Control
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
if ($PSCmdlet.ParameterSetName -eq 'List') {
    $query = Join-Path $env:WINDIR 'System32\quser.exe'
    & $query "/server:$ComputerName"
    if ($LASTEXITCODE -ne 0) { throw "Session query failed with exit code $LASTEXITCODE." }
    return
}
$arguments = @("/v:$ComputerName", "/shadow:$SessionId")
if ($Control) { $arguments += '/control' }
$mode = if ($Control) { 'control' } else { 'view' }
if ($PSCmdlet.ShouldProcess("$ComputerName session $SessionId", "Open RDS shadow $mode")) {
    $client = Join-Path $env:WINDIR 'System32\mstsc.exe'
    if (-not (Test-Path -LiteralPath $client)) { throw 'The Remote Desktop client is not installed.' }
    # Visible window is required for the operator's interactive RDS session.
    Start-Process -FilePath $client -ArgumentList $arguments -WindowStyle Normal
}
