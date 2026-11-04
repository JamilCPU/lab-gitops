# Node bootstrap

Run these once per machine, before Flux takes over. They are idempotent.

| Step | Where | What |
|---|---|---|
| `server-install.sh` | control-plane node | k3s server with `role=primary-worker`, local-path storage on the data disk |
| `agent-join.sh` | each Raspberry Pi | k3s agent. `NODE_LABELS` sets hardware labels such as `hardware/bluetooth-usb=true`. The join token is read from a file and never passed as an argument. |
| `lab-network-config.sh` | anywhere with kubectl | creates the out-of-band `lab-network` ConfigMap (from `lab-network.env.example`) and labels the DNS nodes |

## Per-node prep (not in git)
- `/etc/rancher/k3s/registries.yaml`: copy it from `registries.yaml.example` and add real credentials.
- `/etc/hosts` gets `<ingress-ip> gitea.lab registry.lab`, so containerd can reach the registry even before the LAN DNS points at the cluster.
- On the Pis, `/srv/lab-home` is a symlink to the service user's home directory. The OpenClaw DaemonSets mount that neutral path, so no username appears in the manifests.
- An air-gapped node gets the k3s binary plus `rancher/mirrored-pause` and `rancher/klipper-lb` image tarballs in `/var/lib/rancher/k3s/agent/images/`, and is installed with `INSTALL_K3S_SKIP_DOWNLOAD=true`.

## Out-of-band Secrets
These are created with `kubectl create secret …` from local files and never committed:
- `lab/mission-control` (`OC_TOKEN`)
- `lab/pa-mcp` (`PA_HUB_TOKEN`, `PA_MCP_HTTP_TOKEN`)

Moving them to SOPS-encrypted manifests decrypted by Flux is the planned next step.
