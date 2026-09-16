# Amr Assi · Systems & Infrastructure Portfolio

Practical Windows infrastructure, troubleshooting, and PowerShell work.

[Live portfolio](https://amr-assi-portfolio.pages.dev/) · [GitHub profile](https://github.com/AmrAssi) · [LinkedIn](https://www.linkedin.com/in/amr-assi-b13451232/)

## Start here

| Project | Focus | Evidence |
| --- | --- | --- |
| [Enterprise Home Lab](labs/enterprise-home-lab/) | AD DS, DNS, DHCP, Group Policy, ESXi, pfSense, PKI, IIS, Entra ID, Intune, Veeam | Environment summary, architecture, and links to the existing gallery. |
| [Windows Server Health Report](tools/server-health-report/) | PowerShell, CIM, service checks, thresholds, HTML and JSON reports | Source code, automated tests, and a [validation record](tools/server-health-report/docs/validation.md). |
| [Recovery case study](case-studies/file-recovery-after-endpoint-quarantine.md) | Endpoint security and historical file recovery with Zerto | An anonymized account of a real support incident. |
| [Troubleshooting runbooks](labs/enterprise-home-lab/docs/troubleshooting/) | Group Policy, DNS, and recovery verification | Prepared lab procedures with explicit acceptance criteria. |

## Professional context

I work as an **IT Support Specialist** in a multi-client environment, with hands-on responsibilities across Windows servers, Microsoft 365, identity services, virtualization, backup recovery, and monitoring.

A previous Windows 11 deployment project included preparing **more than 300 computers for 150 branches**: imaging, domain join, business applications, IP/DNS settings, printers, peripherals, and final functional checks.

## Repository guide

```text
index.html                          Existing portfolio website
labs/enterprise-home-lab/            Architecture and troubleshooting runbooks
tools/server-health-report/          PowerShell tool, usage, tests, and validation
case-studies/                       Anonymized professional experience
.github/workflows/                  Automated Windows checks
```

The Home Lab documentation describes the existing environment. Runbooks without recorded outcomes are identified as exercises. Automated script tests are distinct from testing against real lab servers.
