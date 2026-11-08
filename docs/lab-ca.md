# Lab CA

All `*.lab` HTTPS certificates are issued by cert-manager's `ClusterIssuer` `lab-ca`. It signs
from the out-of-band Secret `cert-manager/lab-ca`. The CA private key is kept only in that Secret
and in the operator's `~/lab-tls` directory on the k3s server. It is never in git.

| CA | Valid | Status |
|---|---|---|
| `CN=lab root CA 2026-11` | 2026-11-07 → 2036-11 | current |
| `CN=lab CA` | 2026-11-03 → 2036-11 | **retired 2026-11-07**: it had no keyUsage extension, so Python 3.13+ (`VERIFY_X509_STRICT`) and Android rejected it |

The current CA carries the extensions that strict verifiers require:
- `basicConstraints = critical, CA:TRUE`
- `keyUsage = critical, keyCertSign, cRLSign`
- `subjectKeyIdentifier`

## Reissue of 2026-11-07: clients must re-import

Every certificate that cert-manager manages was reissued from the new CA. A client that trusted
the old CA now fails TLS to `*.lab` until it imports the new one:

- **Windows:** `.\bootstrap\lab-tls\install-ca-windows.ps1 -SshHost <user>@<k3s-server>`. It
  installs the new CA and removes the retired one from the current user's Root store.
- **Android:** `bash bootstrap/lab-tls/install-ca-android.sh <user>@<k3s-server>`. Then finish
  the install in Settings and delete the old "lab CA" under Trusted credentials → User.
- **Pods:** the ConfigMap `lab/lab-ca` (key `lab-ca.pem`) holds the new CA. Pods that mount it
  as a directory pick it up on their own; restart them so long-lived TLS sessions reload it.
- **Anything else that pins the CA file** (for example `SSL_CERT_FILE` or `NODE_EXTRA_CA_CERTS`):
  copy it again with `bash bootstrap/lab-tls/export-ca.sh > lab-ca.pem`.

## Rotating again

1. Run `make-lab-tls.sh` in a fresh directory. It creates a new CA with the extensions above.
2. Load it: `bash bootstrap/lab-tls/import-ca.sh <dir>`. Then update the ConfigMap:
   `kubectl -n lab create configmap lab-ca --from-file=lab-ca.pem=<dir>/lab-ca.pem --dry-run=client -o yaml | kubectl apply -f -`
3. Reissue: delete each cert-manager TLS Secret (`kubectl get certificate -A` lists them).
   cert-manager recreates each one from the new CA within seconds.
4. Check each host: `openssl s_client -connect <ingress>:443 -servername <host>.lab -CAfile lab-ca.pem`.
5. Re-import the CA on every client (see above).
