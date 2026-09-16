# Windows Server Health Report

![Read Windows CIM data, evaluate checks, and generate HTML and JSON reports](../../assets/diagrams/server-health-flow.svg)

A PowerShell project by Amr Assi for collecting a small, readable snapshot of Windows server health.

**Validated on Windows Server 2025 with Windows PowerShell 5.1 and PowerShell 7:** parser checks, behavioral tests, and real local CIM collection passed. [See the results and limits](docs/validation.md). Remote lab validation is pending.

## Scope
- Physical-memory use from the Windows operating system.
- Free space on fixed logical disks.
- The state of services selected by the operator.
- HTML for human review and JSON for further processing.

The script reads CIM data and writes reports locally. It does not restart services, resize disks, install software, or change Windows remote-management settings.

## Requirements
Windows with Windows PowerShell 5.1 or PowerShell 7 and the CimCmdlets module. The account running the script must have permission to read the requested data. Remote queries require existing, authorized CIM/WinRM access. Local collection does not use a remote connection.

## Usage
Local computer:
```powershell
.\Get-ServerHealthReport.ps1
```

Two lab servers (replace the example names with your own):
```powershell
.\Get-ServerHealthReport.ps1 -ComputerName DC01,FS01 -ServiceName EventLog,Winmgmt
```

Different thresholds:
```powershell
.\Get-ServerHealthReport.ps1 -DiskFreeWarningPercent 20 -MemoryUsedWarningPercent 85
```

Each run writes timestamped HTML and JSON files into the reports directory next to the script. Use -OutputDirectory to choose another directory. Reports can contain machine names and error details; generated reports are excluded from Git by default.

## Interpreting the results
| Status | Meaning |
| --- | --- |
| OK | This particular check passed. |
| Warning | A memory or disk threshold was reached. |
| Critical | A required service was absent or was not running. |
| Unknown | Data could not be collected or was invalid. |

A failed query is recorded as Unknown, not as a healthy result or proof that a service is missing. Memory and disk comparisons use unrounded values. Service names must match actual Windows service names, not their display names. The default services are EventLog and Winmgmt; select services appropriate to each target server.

The script emits a report object. Health findings are represented in the report, not by dedicated process exit codes. It is a snapshot, not continuous monitoring, and does not replace Zabbix or backup verification.

## Validation

Automated checks run in both supported PowerShell editions on a Windows runner. They cover errors and threshold boundaries as well as a real local collection run. The [validation record](docs/validation.md) links to the observed results.

Before using this with lab servers, verify remote CIM access and compare the report with Windows management tools. No customer or home-lab server was contacted by the automated tests.

## References
- [Microsoft: Get-CimInstance](https://learn.microsoft.com/en-us/powershell/module/cimcmdlets/get-ciminstance)
- [Microsoft: Win32_OperatingSystem](https://learn.microsoft.com/en-us/windows/win32/cimwin32prov/win32-operatingsystem)
- [Microsoft: Win32_LogicalDisk](https://learn.microsoft.com/en-us/windows/win32/cimwin32prov/win32-logicaldisk)

## Run the checks
```powershell
.\tests\Test-ServerHealthReport.ps1
.\tests\Test-LocalCollection.ps1
```
The first test script uses synthetic CIM responses. The second queries the local Windows machine. Neither test contacts customer servers.
