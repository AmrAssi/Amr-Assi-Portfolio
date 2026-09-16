#requires -Version 5.1
[CmdletBinding()]
param()
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$subject = Join-Path (Split-Path $PSScriptRoot -Parent) 'Get-ServerHealthReport.ps1'
$output = Join-Path ([System.IO.Path]::GetTempPath()) ('health-report-smoke-' + [Guid]::NewGuid().ToString('N'))
$result = & $subject -ComputerName . -OutputDirectory $output
$data = Get-Content -LiteralPath $result.JsonReport -Raw | ConvertFrom-Json
if ($data.Summary.Unknown -ne 0) { throw 'Local CIM smoke test returned Unknown checks.' }
if ($data.Summary.Critical -ne 0) { throw 'Required default services were not running.' }
if (@($data.Checks | Where-Object Check -eq 'Memory').Count -ne 1) { throw 'Memory check missing.' }
if (@($data.Checks | Where-Object Check -eq 'Disk').Count -lt 1) { throw 'Disk check missing.' }
if (@($data.Checks | Where-Object Check -eq 'Service').Count -ne 2) { throw 'Service checks missing.' }
if (-not (Test-Path -LiteralPath $result.HtmlReport)) { throw 'HTML report missing.' }
Write-Host ('PASS: real local CIM collection on ' + [Environment]::OSVersion.VersionString + ', PowerShell ' + $PSVersionTable.PSVersion.ToString())
$data.Summary | Format-List
