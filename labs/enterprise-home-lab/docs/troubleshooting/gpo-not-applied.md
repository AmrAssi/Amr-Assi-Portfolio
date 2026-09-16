# Troubleshooting: a Group Policy setting is not applied

**Lab exercise — execution evidence pending.**

## Symptom and expected behavior

A lab workstation or user does not receive a setting from an existing GPO. Before changing anything, identify the exact setting, whether it belongs to Computer Configuration or User Configuration, and the expected value.

## Investigation

1. Identify the affected AD object and OU. Check the GPO link, enabled configuration section, link state, inheritance, security filtering, and any WMI filter.
2. Capture the current result in the affected user's session. Computer-scope results may require an elevated shell.

```powershell
gpresult /r
gpresult /h "$env:TEMP\gpo-result.html"
Get-WinEvent -LogName 'Microsoft-Windows-GroupPolicy/Operational' -MaxEvents 30 |
    Select-Object TimeCreated, Id, LevelDisplayName, Message
```

3. In the report, distinguish an absent GPO from a denied GPO and an applied GPO with an unexpected setting. Check precedence if more than one policy sets the same value.
4. If the logs point to domain connectivity, check the client's DNS configuration and domain-controller access before changing GPO permissions.
5. Correct only the cause supported by the evidence. In the disposable lab, refresh policy after the correction:

```powershell
gpupdate /force
```

Some settings require sign-out or restart. Read the command result before doing either.

## Acceptance criteria

The policy appears in the appropriate scope, the intended setting has the expected effective value, and a new result report supports the outcome.

Record the original symptom, root cause, exact change, before/after evidence, and any sign-out or restart required. Command success alone is not proof that the setting changed.

[Back to lab overview](../../README.md)
