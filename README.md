# lab-gitops

This is the source of truth for what runs on the home-lab k3s cluster. **Commit = deploy.**
Flux runs in the cluster and watches this repo. When a change lands on `main`, Flux applies it within about a minute; when something is removed from the repo, Flux removes it from the cluster.

## Layout
| Path | What |
|---|---|
| `bootstrap/` | One-time machine setup that happens *before* Flux exists: OS install, k3s server/agent join, DNS wildcard |
| `clusters/lab/` | Flux entry point (Kustomizations) for the cluster |
| `infrastructure/` | Cluster plumbing: Traefik config, the registry, storage |
| `apps/<name>/` | One folder per app: Deployment/DaemonSet, Service, Ingress, PVC |

## Rules
- **No secrets, IPs or hostnames in committed files.** Secrets are created out of band (`kubectl create secret …`) or sealed. Node-specific values come from labels (`role=primary-worker`) or ConfigMaps created at bootstrap.
- Every workload has readiness probes.
- Workloads that need the big node's disk use `nodeSelector` and a PersistentVolume under its data mount.
- Apps are published through Traefik Ingress as `<name>.lab`. `infrastructure/lab-dns` (CoreDNS on the node(s) labelled `lab-dns=true`) resolves `*.lab` to the ingress node and forwards everything else to the router. The router hands those nodes out as DNS via DHCP.

## Day-to-day
```bash
git add apps/myapp && git commit -m "feat: deploy myapp" && git push   # that's the deploy
flux get kustomizations                                                 # watch it reconcile
```
