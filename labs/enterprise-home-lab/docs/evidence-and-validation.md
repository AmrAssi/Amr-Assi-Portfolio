# Evidence and validation

The existing portfolio contains screenshots of Active Directory, Group Policy, VLAN configuration, DHCP, certificate services, Intune, and Veeam. A configuration screenshot documents a configuration; it does not by itself prove end-to-end recovery or current service health.

Evidence source: https://amr-assi-portfolio.pages.dev/#gallery

For each new test, record:
- Date and lab machine role.
- Relevant software versions.
- Expected result.
- Commands or GUI actions used.
- Observed result.
- A focused screenshot or sanitized output.
- Interpretation and remaining limitations.

## Test record
No new execution results have been recorded in this repository yet.

| Test | Status |
| --- | --- |
| GPO scope and application | Awaiting a recorded lab run |
| DNS resolution and expected answer | Awaiting a recorded lab run |
| File recovery and SHA-256 comparison | Awaiting a recorded lab run |

Use lab data and screenshots when adding evidence. Published diagrams should describe the lab, not customer networks.

The separate [server-health report](../../../tools/server-health-report/) has its own [validation record](../../../tools/server-health-report/docs/validation.md). Automated checks of that tool do not validate this lab's configuration.
