# Recovery exercise: verify the intended file version

**Lab exercise — execution evidence pending.**

## Goal

Demonstrate that a file-level restore recovers the intended historical content. Use a disposable sample file and the existing lab backup workflow.

## Procedure

1. Create a small sample document in a dedicated lab folder. Record its content and hash.
2. Back it up through the configured workflow. Record the successful job and recovery point.
3. Change only the disposable sample file and capture its new hash.
4. Restore the earlier version to a separate recovery folder, preserving the current file.
5. Compare the recovered file with the baseline:

```powershell
# Replace these paths with the dedicated lab sample and recovery locations.
$originalHash = Get-FileHash -LiteralPath 'C:\LabRecovery\sample.txt' -Algorithm SHA256
# Record $originalHash.Hash BEFORE editing and backing up other versions.

# Run after restoring the chosen baseline version:
$restoredHash = Get-FileHash -LiteralPath 'C:\LabRecovery\restored\sample.txt' -Algorithm SHA256
$restoredHash.Hash -eq $originalHash.Hash
```

Keep the original hash in the test record if you close the shell. Select the recovery point that contains that exact baseline.

6. Open the restored file and verify the expected content. Record the outcome.

## Acceptance criteria

The recovered file's hash matches the pre-change baseline, its content is readable, and the selected recovery point and restore destination are documented.

Record product/version, job status, recovery point, both hashes, and observed result. This verifies file recovery; it does not establish full-server disaster recovery or an RTO/RPO.

[Back to lab overview](../../README.md)
