# Troubleshooting: a lab server name does not resolve

**Lab exercise — execution evidence pending.**

## Symptom and expected behavior

A lab client cannot reach a server by name. Use the lab inventory to identify the expected FQDN and address. The examples below use reserved example values; replace them with the lab's actual values.

```powershell
$name = 'fileserver.lab.example'
$dnsServer = '192.0.2.53'
Get-DnsClientServerAddress -AddressFamily IPv4
Resolve-DnsName -Name $name -Type A -DnsOnly
Resolve-DnsName -Name $name -Type A -Server $dnsServer -DnsOnly
```

## Interpret the evidence

| Observation | Next check |
| --- | --- |
| Default lookup fails, explicit DNS lookup succeeds | Client DNS server configuration and the path to that server. |
| Both lookups return no record | Requested FQDN, zone, record, and authoritative server. |
| An unexpected address is returned | Stale or incorrect records, cache, and the server's actual address. |
| Correct address, application still unavailable | The service, firewall, route, and relevant TCP port. |

Inspect the zone on the authoritative lab DNS server. Avoid clearing caches before recording the initial response, since that can remove useful evidence.

After correcting the established cause, repeat the same lookups and check the intended application. For an SMB file-server exercise:

```powershell
Test-NetConnection -ComputerName $name -Port 445
```

A successful TCP check does not prove share access. Test access with the intended lab user as well.

## Acceptance criteria

The client's normal lookup returns the expected address and the intended service can be used. Record the initial answer, identified cause, exact correction, and final result.

[Back to lab overview](../../README.md)
