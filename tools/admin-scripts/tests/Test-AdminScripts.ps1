#requires -Version 5.1
[CmdletBinding()]
param()
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
function Assert-True([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw "FAIL: $Message" }
}
foreach ($file in Get-ChildItem -LiteralPath $root -Filter '*.ps1' -File) {
    $tokens = $null; $errors = $null
    $null = [Management.Automation.Language.Parser]::ParseFile($file.FullName, [ref]$tokens, [ref]$errors)
    Assert-True ($errors.Count -eq 0) ("Parse " + $file.Name)
}
Write-Host 'PASS: PowerShell parser for all three scripts'

# All remoting and directory commands below are in-process stubs.
function Invoke-Command {
    [CmdletBinding()]
    param([string]$ComputerName,[object[]]$ArgumentList,[scriptblock]$ScriptBlock)
    if ($ComputerName -eq 'unavailable.example.test') { throw 'Simulated query failure' }
    if ($ComputerName -eq 'empty.example.test') { return }
    [pscustomobject]@{Number=2; FriendlyName='lab.user01'; Location='lab-profile.vhdx'; OperationalStatus='Online'}
}
$found = @(& (Join-Path $root 'Find-RdsProfileDisk.ps1') -ComputerName @('match.example.test','empty.example.test','unavailable.example.test','match.example.test') -UserIdentifier 'lab.user01')
Assert-True ($found.Count -eq 3) 'Deduplicate hosts'
Assert-True (@($found | Where-Object Status -eq 'Candidate').Count -eq 1) 'Candidate'
Assert-True (@($found | Where-Object Status -eq 'NoNameMatch').Count -eq 1) 'NoNameMatch'
Assert-True (@($found | Where-Object Status -eq 'QueryFailed').Count -eq 1) 'Failure must not become NoNameMatch'
Write-Host 'PASS: profile disk discovery results and failure isolation'

function Import-Module {
    [CmdletBinding()]
    param([string]$Name)
    if ($Name -ne 'ActiveDirectory') { throw 'Unexpected module request in test' }
}
function Get-ADUser {
    [CmdletBinding()]
    param([string]$Identity,[string]$LDAPFilter,[string]$Server,[string[]]$Properties)
    if ($Identity) {
        return [pscustomobject]@{ Department='Lab'; Company='Example'; MemberOf=@('CN=LabReaders,OU=Groups,DC=lab,DC=example') }
    }
    if ($global:AdminScriptTestMode -eq 'Existing') { return [pscustomobject]@{SamAccountName='lab.user01'} }
    if ($global:AdminScriptTestMode -eq 'ReadFailure') { throw 'Simulated directory read error' }
}
function Get-ADOrganizationalUnit {
    [CmdletBinding()]
    param([string]$Identity,[string]$Server)
    [pscustomobject]@{DistinguishedName=$Identity}
}
function Get-ADGroup {
    [CmdletBinding()]
    param([string]$Identity,[string]$Server)
    [pscustomobject]@{DistinguishedName=("CN=$Identity,OU=Groups,DC=lab,DC=example")}
}
function New-ADUser {
    [CmdletBinding()]
    param($Name,$DisplayName,$GivenName,$Surname,$SamAccountName,$UserPrincipalName,$Path,$Server,$AccountPassword,
          $Enabled,$ChangePasswordAtLogon,$PasswordNeverExpires,$CannotChangePassword,$Department,$Company,[switch]$PassThru)
    $global:AdminScriptCreates.Add([pscustomobject]@{
        Enabled=$Enabled; ChangeAtLogon=$ChangePasswordAtLogon; NeverExpires=$PasswordNeverExpires; Department=$Department
    })
    [pscustomobject]@{DistinguishedName="CN=$SamAccountName,$Path"}
}
function Add-ADGroupMember {
    [CmdletBinding()]
    param($Identity,$Members,$Server)
    if ($global:AdminScriptTestMode -eq 'GroupFailure') { throw 'Simulated group failure' }
    $global:AdminScriptGroupAdds++
}
function Start-Process {
    [CmdletBinding()]
    param($FilePath,$ArgumentList,$WindowStyle)
    throw 'An interactive client must never start in these tests.'
}
$global:AdminScriptCreates = New-Object 'System.Collections.Generic.List[object]'
$global:AdminScriptGroupAdds = 0
$global:AdminScriptTestMode = 'Normal'
$password = New-Object Security.SecureString
foreach ($c in [Guid]::NewGuid().ToString('N').ToCharArray()) { $password.AppendChar($c) }
$params = @{
    CsvPath=(Join-Path $root 'examples/users.example.csv')
    TemplateUser='lab.template'; TargetOU='OU=Lab,DC=lab,DC=example'
    UpnSuffix='lab.example'; Server='dc.example.test'; InitialPassword=$password
}
$subject = Join-Path $root 'New-ADUsersFromTemplate.ps1'
try {
    $r = @(& $subject @params -WhatIf)
    Assert-True ($global:AdminScriptCreates.Count -eq 0 -and $global:AdminScriptGroupAdds -eq 0) 'WhatIf performs no writes'
    Assert-True (@($r | Where-Object Status -eq 'NotApplied').Count -eq 2) 'WhatIf reports unapplied users'
    Write-Host 'PASS: AD WhatIf prevents account and group writes'

    $r = @(& $subject @params -Confirm:$false)
    Assert-True ($global:AdminScriptCreates.Count -eq 2 -and $global:AdminScriptGroupAdds -eq 0) 'No groups copied by default'
    Assert-True (-not $global:AdminScriptCreates[0].Enabled -and $global:AdminScriptCreates[0].ChangeAtLogon -and -not $global:AdminScriptCreates[0].NeverExpires) 'Account defaults'
    Assert-True ($global:AdminScriptCreates[0].Department -eq 'Lab') 'Template attribute copied'
    Write-Host 'PASS: disabled accounts, password defaults, and selected attributes'

    $global:AdminScriptTestMode = 'Existing'
    $countBefore = $global:AdminScriptCreates.Count
    $r = @(& $subject @params -Confirm:$false)
    Assert-True ($global:AdminScriptCreates.Count -eq $countBefore -and @($r | Where-Object Status -eq 'SkippedExisting').Count -eq 2) 'Existing users untouched'
    $global:AdminScriptTestMode = 'ReadFailure'
    $r = @(& $subject @params -Confirm:$false)
    Assert-True ($global:AdminScriptCreates.Count -eq $countBefore -and @($r | Where-Object Status -eq 'Failed').Count -eq 2) 'Read errors do not allow creation'
    Write-Host 'PASS: existing accounts and directory read failures'

    $global:AdminScriptTestMode = 'GroupFailure'
    $r = @(& $subject @params -GroupIdentity 'LabReaders' -Confirm:$false)
    Assert-True (@($r | Where-Object Status -eq 'CreatedWithGroupErrors').Count -eq 2) 'Partial failure is explicit'
    $rejected = $false
    try { $null = & $subject @params -GroupIdentity 'UnreviewedGroup' -WhatIf } catch { $rejected = $true }
    Assert-True $rejected 'Group must belong to template'
    Write-Host 'PASS: explicit group selection and partial failure reporting'

    $null = & (Join-Path $root 'Start-RdsShadowSession.ps1') -ComputerName 'rds.example.test' -SessionId 3 -Control -WhatIf
    Write-Host 'PASS: RDS WhatIf does not launch the client'
    Write-Host ('ALL TESTS PASSED on PowerShell ' + $PSVersionTable.PSVersion)
} finally {
    $password.Dispose()
    Remove-Variable AdminScriptCreates,AdminScriptGroupAdds,AdminScriptTestMode -Scope Global -ErrorAction SilentlyContinue
}
