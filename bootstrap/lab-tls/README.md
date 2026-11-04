# Lab TLS

One lab-internal CA signs every `*.lab` certificate. cert-manager holds its key pair in the
out-of-band Secret `cert-manager/lab-ca`; the `ClusterIssuer` named `lab-ca`
(`infrastructure-config/lab-ca`) issues from it. Nothing private is committed.

## Getting a certificate for an app

Annotate the Ingress and name a Secret; cert-manager creates and renews it:

```yaml
metadata:
  annotations:
    cert-manager.io/cluster-issuer: lab-ca
    traefik.ingress.kubernetes.io/router.entrypoints: websecure
spec:
  tls:
    - hosts: [myapp.lab]
      secretName: myapp-lab-tls
```

Or create a `Certificate` with `issuerRef: {kind: ClusterIssuer, name: lab-ca}`.

## Scripts

| Script | Use |
|---|---|
| `make-lab-tls.sh` | Create the CA once (and, without cert-manager, a single host cert). Keep `lab-ca.key` off git. |
| `import-ca.sh` | Load the CA key pair into `cert-manager/lab-ca`. |
| `export-ca.sh` | Print the public CA certificate for clients. |
| `install-ca-windows.ps1` | Trust it on Windows (current user) and set `NODE_EXTRA_CA_CERTS`. |
| `install-ca-android.sh` | Push it to an Android phone over adb; finish the install in Settings. |
