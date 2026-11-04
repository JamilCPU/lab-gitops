# lab-gitops

GitOps source of truth for a four-node home-lab Kubernetes cluster. **Commit = deploy.** [Flux](https://fluxcd.io) runs in the cluster and watches this repo:
- When a change lands on `main`, Flux applies it within about a minute.
- When something is deleted from the repo, Flux removes it from the cluster.

## Cluster design

```
                 ┌──────────────────────────── k3s v1.34 ─────────────────────────────┐
  LAN clients    │  control plane: x86 desktop (Ubuntu 24.04, 32 GB, NVMe data disk)    │
  *.lab ──DNS──► │    Traefik ingress · Flux · Gitea + OCI registry · app workloads     │
                 │  agents: 3 × Raspberry Pi (arm64, Debian 13)                         │
                 │    · gateway/audio Pi  (label hardware/bluetooth-usb=true)           │
                 │    · robot Pi          (ROS 2 lidar stack, second DNS server)        │
                 │    · air-gapped Pi     (no internet: offline k3s install)            │
                 └──────────────────────────────────────────────────────────────────────┘
```

- **Mixed architecture.** The control plane is amd64 and the Pis are arm64. Images are built multi-arch (`docker buildx --platform linux/amd64,linux/arm64`), and arm-only workloads use `nodeSelector: kubernetes.io/arch: arm64`.
- **Placement is by label, never by node name.**
  - `role=primary-worker` marks the node with the big data disk, so stateful apps pin there with hostPath volumes under `/data/lab/<app>`.
  - Hardware-bound apps select a hardware label. For example, the audio app needs the USB Bluetooth dongle, so it uses `hardware/bluetooth-usb=true`.
- **LAN DNS (`infrastructure/lab-dns`).**
  - A CoreDNS DaemonSet runs on nodes labelled `lab-dns=true`, using host networking on each node's LAN address port 53.
  - It answers `*.lab` with the ingress node and forwards everything else to the router.
  - The router hands those nodes out as DNS servers via DHCP. Two nodes serve, so `.lab` keeps resolving if one is down.
- **Ingress.** k3s's bundled Traefik routes `<app>.lab` by Host header. Apps that terminate their own TLS (with pinned certificates) use an `IngressRouteTCP` with TLS passthrough instead.
- **Registry.** Gitea's built-in OCI registry, published as `registry.lab`.
  - Nodes pull over plain HTTP through a containerd mirror (`registries.yaml`).
  - Pushes go to a plain-HTTP port (`registry.lab:5000`). Docker and BuildKit switch to HTTPS whenever :443 answers, and Gitea would then advertise an HTTPS token realm the client can't verify.
- **Health.** Every workload has readiness and liveness probes. Where a service binds only to loopback, the probe runs inside the container (`exec`).

## Layout
| Path | What |
|---|---|
| `clusters/lab/` | Flux entry point: `flux-system` plus the `infrastructure` → `apps` Kustomizations (apps depend on infrastructure) |
| `infrastructure/` | cluster plumbing: `lab-dns` |
| `apps/` | one folder per app: Deployment/DaemonSet, Service, Ingress |
| `bootstrap/` | one-time machine setup before Flux exists: [unattended Windows → Ubuntu reinstall over SSH](bootstrap/ubuntu-autoinstall/README.md) and [k3s server/agent install](bootstrap/k3s/README.md) |
| `docs/` | runbooks, e.g. restoring the game servers |

## What runs here
| App | Name | Notes |
|---|---|---|
| Gitea + registry | `gitea.lab`, `registry.lab` | git hosting and image registry |
| AI Art Factory | `art.lab` | FastAPI dashboard for composing, generating and reviewing images |
| Personal Automations | `automations.lab`, `mcp.automations.lab` | control-plane API and MCP server for the lab, used by an Android app and AI agents |
| AI News | `news.lab` | daily AI-news digest reader |
| Mission Control | `mission.lab` | dashboard for the agent gateway on each Pi |
| OpenClaw gateway | (host network) | agent gateway DaemonSet on the Pis |

## Rules
- **No secrets, addresses or hostnames in git.** Node-specific values come from labels or from out-of-band ConfigMaps and Secrets. Each one has a `*.example` next to the script that creates it. Moving the Secrets to SOPS is planned.
- Every workload has probes. Stateful apps use `strategy: Recreate`, since sqlite on a hostPath must never have two writers.
- Image tags are built and pushed from each app's own repo (root `Dockerfile`).

## Day-to-day
```bash
git add apps/myapp && git commit -m "feat(apps): deploy myapp" && git push   # that's the deploy
flux get kustomizations                                                      # watch it reconcile
flux reconcile kustomization apps --with-source                              # don't wait for the interval
```
