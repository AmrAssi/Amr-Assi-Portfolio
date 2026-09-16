# Case study: recovering a business application file

## Context

An endpoint security product removed a file required by a business application on a customer's server. The endpoint product's rollback did not recover the required file.

This is an anonymized account of an incident Amr handled at work. It is separate from the lab exercises.

## Actions taken

1. Received approval for a file exception scoped to the affected server.
2. Attempted the endpoint product's recovery function.
3. Used Zerto to locate the file in a historical recovery point from approximately one month earlier.
4. Recovered the required file and transferred it through a file server to the target server.

## What this demonstrates

- Moving to another recovery source when the first recovery method is insufficient.
- Selecting a historical recovery point for a specific file.
- Keeping a security exception within the approved scope.
- Coordinating recovery and file transfer across systems.

## Evidence limits

The file recovery and transfer are based on Amr's account. Customer logs, screenshots, server names, and file contents are not published. No measured recovery time, hash comparison, or full application acceptance test is claimed.

For a reproducible demonstration of recovery validation, see the [lab file-recovery exercise](../labs/enterprise-home-lab/docs/troubleshooting/file-recovery.md).
