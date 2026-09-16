# Validation record

## Verified run — 16 September 2026

[GitHub Actions run 35145162114](https://github.com/AmrAssi/Amr-Assi-Portfolio/actions/runs/35145162114) completed successfully for [commit 0dfb7e1](https://github.com/AmrAssi/Amr-Assi-Portfolio/commit/0dfb7e17805e78cb8764657a88b07bd4d712de24).

Environment: GitHub-hosted Windows Server 2025 Datacenter, build 10.0.26100; runner image windows-2025-vs2026, version 20260907.229.1.

| Runtime | Parser and behavioral tests | Real local CIM collection |
| --- | --- | --- |
| Windows PowerShell 5.1.26100.33296 | Passed | Passed: 5 checks OK, 0 Warning, 0 Critical, 0 Unknown |
| PowerShell 7.6.5 | Passed | Passed: 5 checks OK, 0 Warning, 0 Critical, 0 Unknown |

Commands, run separately in each shell:

```powershell
./tools/server-health-report/tests/Test-ServerHealthReport.ps1
./tools/server-health-report/tests/Test-LocalCollection.ps1
```

## Behavioral coverage

Synthetic inputs exercise healthy data, threshold boundaries before rounding, stopped and absent services, failed queries, invalid counters, absent disk data, HTML escaping, JSON fidelity, partial failures across hosts, duplicate/whitespace inputs, invalid parameters, and an output path that is a file.

The local smoke test uses actual Windows CIM data. It verifies memory, fixed disks, the two default services, and report creation. It does not use mocked responses.

## Limits and next lab validation

- No remote connection to Amr's lab or a customer server was made.
- Remote CIM/WinRM authentication, authorization, and firewall behavior still require a lab run.
- Windows Server versions other than the runner's version have not been verified.
- HTML content and escaping were tested programmatically; a visual browser review is still pending.
- This report does not validate backups, application availability, or whole-server health.

For a remote lab run, record OS and PowerShell versions, exact command, service names, thresholds, expected result, observed result, and sanitized supporting output. Compare returned memory, disk, and service data with Windows management tools.

Generated machine reports remain outside version control.
