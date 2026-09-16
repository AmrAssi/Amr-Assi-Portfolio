#requires -Version 5.1
<#
.SYNOPSIS
Create AD users from a CSV, selected template attributes, and explicit groups.
.DESCRIPTION
Public adaptation of a template-based onboarding script. Supports -WhatIf.
Accounts are disabled unless -EnableAccounts is supplied. Passwords are
SecureString inputs and are never placed in the example CSV or source.
#>
[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
param(
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$CsvPath,
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$TemplateUser,
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$TargetOU,
    [Parameter(Mandatory)][ValidatePattern('^[A-Za-z0-9.-]+$')][string]$UpnSuffix,
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$Server,
    [Parameter(Mandatory)][ValidateNotNull()][Security.SecureString]$InitialPassword,
    [string[]]$GroupIdentity = @(),
    [switch]$EnableAccounts
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Import-Module ActiveDirectory -ErrorAction Stop

$attributes = @('Description','Department','Company','Title','Office','OfficePhone',
    'StreetAddress','City','State','PostalCode','Country','Manager')
$template = Get-ADUser -Identity $TemplateUser -Server $Server -Properties ($attributes + 'MemberOf') -ErrorAction Stop
$null = Get-ADOrganizationalUnit -Identity $TargetOU -Server $Server -ErrorAction Stop
$rows = @(Import-Csv -LiteralPath $CsvPath)
if ($rows.Count -eq 0) { throw 'The CSV contains no users.' }

$seen = @{}
foreach ($row in $rows) {
    foreach ($column in @('SamAccountName','GivenName','Surname','DisplayName')) {
        if ($null -eq $row.PSObject.Properties[$column] -or
            [string]::IsNullOrWhiteSpace([string]$row.$column)) {
            throw "Missing or empty CSV column: $column"
        }
    }
    $sam = $row.SamAccountName.Trim()
    if ($sam -notmatch '^[A-Za-z0-9._-]{1,20}$') { throw "Invalid SamAccountName: $sam" }
    if ($seen.ContainsKey($sam)) { throw "Duplicate SamAccountName in CSV: $sam" }
    $seen[$sam] = $true
}
$groups = @()
foreach ($identity in @($GroupIdentity | Sort-Object -Unique)) {
    $group = Get-ADGroup -Identity $identity -Server $Server -ErrorAction Stop
    if (@($template.MemberOf) -notcontains $group.DistinguishedName) {
        throw "The selected group is not a direct group of the template: $identity"
    }
    $groups += $group.DistinguishedName
}

foreach ($row in $rows) {
    $sam = $row.SamAccountName.Trim()
    try {
        $existing = @(Get-ADUser -LDAPFilter "(sAMAccountName=$sam)" -Server $Server -ErrorAction Stop)
        if ($existing.Count -gt 0) {
            [pscustomobject]@{ User = $sam; Status = 'SkippedExisting'; GroupsAdded = 0; Detail = 'Existing account unchanged.' }
            continue
        }
        $parameters = @{
            Name = $row.DisplayName.Trim(); DisplayName = $row.DisplayName.Trim()
            GivenName = $row.GivenName.Trim(); Surname = $row.Surname.Trim()
            SamAccountName = $sam; UserPrincipalName = "$sam@$UpnSuffix"
            Path = $TargetOU; Server = $Server; AccountPassword = $InitialPassword
            Enabled = [bool]$EnableAccounts; ChangePasswordAtLogon = $true
            PasswordNeverExpires = $false; CannotChangePassword = $false
            PassThru = $true; ErrorAction = 'Stop'
        }
        foreach ($name in $attributes) {
            $property = $template.PSObject.Properties[$name]
            if ($null -ne $property -and $null -ne $property.Value -and [string]$property.Value -ne '') {
                $parameters[$name] = $property.Value
            }
        }
        $action = "Create AD account; Enabled=$([bool]$EnableAccounts); add $($groups.Count) reviewed groups"
        if (-not $PSCmdlet.ShouldProcess("$sam in $TargetOU on $Server", $action)) {
            [pscustomobject]@{ User = $sam; Status = 'NotApplied'; GroupsAdded = 0; Detail = 'WhatIf or operator declined.' }
            continue
        }
        $newUser = New-ADUser @parameters
    } catch {
        [pscustomobject]@{ User = $sam; Status = 'Failed'; GroupsAdded = 0; Detail = $_.Exception.Message }
        continue
    }
    $added = 0
    $failures = New-Object 'System.Collections.Generic.List[string]'
    foreach ($groupDN in $groups) {
        try {
            Add-ADGroupMember -Identity $groupDN -Members $newUser.DistinguishedName -Server $Server -ErrorAction Stop
            $added++
        } catch { $failures.Add($groupDN + ': ' + $_.Exception.Message) }
    }
    [pscustomobject]@{
        User = $sam
        Status = $(if ($failures.Count -eq 0) { 'Created' } else { 'CreatedWithGroupErrors' })
        GroupsAdded = $added
        Detail = $(if ($failures.Count -eq 0) { 'Account created; review before enabling or handover.' } else { $failures -join '; ' })
    }
}
