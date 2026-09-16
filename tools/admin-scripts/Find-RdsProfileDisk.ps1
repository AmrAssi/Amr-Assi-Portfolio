#requires -Version 5.1
<#
.SYNOPSIS
Find RDS disk records whose name or location contains an identifier.
.DESCRIPTION
Read-only adaptation of an operational profile-disk investigation script.
A candidate is not proof of a locked FSLogix container or a user's session.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string[]]$ComputerName,
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$UserIdentifier
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$identifier = $UserIdentifier.Trim()
if (-not $identifier) { throw 'UserIdentifier cannot be whitespace.' }
$servers = @($ComputerName | ForEach-Object { $_.Trim() } | Where-Object { $_ } | Sort-Object -Unique)
if ($servers.Count -eq 0) { throw 'At least one computer is required.' }

foreach ($server in $servers) {
    try {
        $disks = @(Invoke-Command -ComputerName $server -ArgumentList $identifier -ErrorAction Stop -ScriptBlock {
            param($Identifier)
            Get-Disk -ErrorAction Stop | Where-Object {
                ([string]$_.Location).IndexOf($Identifier, [StringComparison]::OrdinalIgnoreCase) -ge 0 -or
                ([string]$_.FriendlyName).IndexOf($Identifier, [StringComparison]::OrdinalIgnoreCase) -ge 0
            } | Select-Object Number, FriendlyName, Location, OperationalStatus
        })
        if ($disks.Count -eq 0) {
            [pscustomobject]@{
                ComputerName = $server; Status = 'NoNameMatch'; DiskNumber = $null
                FriendlyName = $null; Location = $null
                Detail = 'No matching disk metadata; this does not rule out a profile-container problem.'
            }
        } else {
            foreach ($disk in $disks) {
                [pscustomobject]@{
                    ComputerName = $server; Status = 'Candidate'; DiskNumber = $disk.Number
                    FriendlyName = $disk.FriendlyName; Location = $disk.Location
                    Detail = 'Matching metadata only. Verify the session, container path, and FSLogix logs.'
                }
            }
        }
    } catch {
        [pscustomobject]@{
            ComputerName = $server; Status = 'QueryFailed'; DiskNumber = $null
            FriendlyName = $null; Location = $null; Detail = $_.Exception.Message
        }
    }
}
