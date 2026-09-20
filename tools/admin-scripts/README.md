# Windows Administration Scripts

Three public adaptations of Amr Assi's existing operational PowerShell scripts, focused on **RDS, Active Directory onboarding, and profile-disk investigation**.

[הסבר בעברית](README.he.md) · [Infrastructure portfolio](../../README.md)

| Script | Purpose | Changes it can make |
| --- | --- | --- |
| [Find-RdsProfileDisk.ps1](Find-RdsProfileDisk.ps1) | Search disk metadata across RDS hosts for an identifier. | None; discovery only. |
| [New-ADUsersFromTemplate.ps1](New-ADUsersFromTemplate.ps1) | Create users from CSV and selected template attributes; optionally add reviewed groups. | Creates AD accounts and group memberships when actually applied. |
| [Start-RdsShadowSession.ps1](Start-RdsShadowSession.ps1) | List RDS sessions and launch an explicitly selected shadow session. | Opens a viewing session, or control with `-Control`. |

## Origin and publication changes

Four local source files contained three unique scripts; two files were byte-for-byte duplicates. The public versions remove customer names, server inventories, user identities, and the embedded password. The local originals were not changed.

The adaptations also address behavior that was unsuitable for a reusable public example:

- Disk metadata matches are **candidates**, not proof that a container is locked. Remoting errors are reported separately from an empty result.
- The automatic profile-disk detach section was omitted: its command and success handling were not validated. No disk is detached by this tool.
- AD input is parameterized and loaded from a fictional CSV. The destination OU and domain controller are explicit. Accounts start disabled; enabling requires `-EnableAccounts`.
- Group membership is opt-in through `-GroupIdentity`, and each requested group must be a direct group of the template. Review the selected groups before applying.
- The shadowing wrapper does not request `/noConsentPrompt` or alter RDS consent policies.
- AD creation and shadow launching support `-WhatIf`.

These are revised public versions, not byte-for-byte copies of customer-specific scripts.

## 1. Find candidate profile disks

Requires PowerShell remoting access and the Storage module on the target hosts.

```powershell
.\Find-RdsProfileDisk.ps1 -ComputerName rds01.lab.example,rds02.lab.example -UserIdentifier lab.user01
```

Results: `Candidate`, `NoNameMatch`, or `QueryFailed`. Many profile problems cannot be identified from a username in disk metadata. Check the actual user session, container path, file handles, and FSLogix logs separately.

## 2. Create users from a template

Requires the RSAT ActiveDirectory module and delegated rights in the selected domain. The sample CSV contains fictional identities.

```powershell
$password = Read-Host 'Initial password' -AsSecureString
$params = @{
    CsvPath = '.\examples\users.example.csv'
    TemplateUser = 'lab.template'
    TargetOU = 'OU=LabUsers,DC=lab,DC=example'
    UpnSuffix = 'lab.example'
    Server = 'dc01.lab.example'
    InitialPassword = $password
}
.\New-ADUsersFromTemplate.ps1 @params -WhatIf
```

Review the output, then run without `-WhatIf` to apply. Add `-GroupIdentity LabReaders` only for groups you have reviewed; add `-EnableAccounts` only when the accounts should be enabled. The initial password must be changed at first logon.

The same supplied initial password is used for this batch; apply your organization's password and handover policy. The script does not print it.

Existing accounts are skipped. Group failures are reported as `CreatedWithGroupErrors`; there is no automatic rollback. Inspect AD after any failure, because directory operations can leave partial changes. `-WhatIf` still performs read-only directory queries.

## 3. Shadow an RDS session

List sessions first:

```powershell
.\Start-RdsShadowSession.ps1 -ComputerName rds01.lab.example
```

Preview opening a selected session, then remove `-WhatIf` to launch:

```powershell
.\Start-RdsShadowSession.ps1 -ComputerName rds01.lab.example -SessionId 3 -WhatIf
```

Viewing is the default. `-Control` requests control. Confirm the correct session and user first. Windows permissions, host policy, and consent requirements still apply.

## Validation

Verified in [GitHub Actions on 16 September 2026](https://github.com/AmrAssi/Amr-Assi-Portfolio/actions/runs/35148954756): all checks passed on Windows PowerShell **5.1.26100.33296** and PowerShell **7.6.5**, at commit `04f8911a4240afd984d73fc64d089fc4f43cee6c`.

`tests/Test-AdminScripts.ps1` checks syntax and behavior with **stubbed directory, remoting, and process calls**. It does not contact an AD domain, RDS host, or customer server. A successful stubbed test is not a production-validation claim.

```powershell
.\tests\Test-AdminScripts.ps1
```

## References

- [Microsoft: New-ADUser](https://learn.microsoft.com/en-us/powershell/module/activedirectory/new-aduser?view=windowsserver2025-ps)
- [Microsoft: mstsc parameters](https://learn.microsoft.com/en-us/windows-server/administration/windows-commands/mstsc)
- [Microsoft: FSLogix frx utility](https://learn.microsoft.com/en-us/fslogix/utilities/frx/frx)
