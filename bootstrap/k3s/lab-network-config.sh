#!/usr/bin/env bash
# Out-of-band, node-specific network values for lab-dns (kept out of git).
# Usage (anywhere with kubectl): LAB_INGRESS_IP=<ingress node LAN ip> UPSTREAM_DNS=<router ip> \
#        DNS_NODES="<node> [<node>...]" bash lab-network-config.sh
set -euo pipefail
: "${LAB_INGRESS_IP:?LAN address that *.lab should resolve to (the Traefik node)}"
: "${UPSTREAM_DNS:?resolver for everything that is not .lab (normally the router)}"
: "${DNS_NODES:?space-separated node names that should serve DNS on :53}"
kubectl create namespace lab-dns --dry-run=client -o yaml | kubectl apply -f -
kubectl -n lab-dns create configmap lab-network \
  --from-literal=LAB_INGRESS_IP="$LAB_INGRESS_IP" \
  --from-literal=UPSTREAM_DNS="$UPSTREAM_DNS" \
  --dry-run=client -o yaml | kubectl apply -f -
for n in $DNS_NODES; do kubectl label node "$n" lab-dns=true --overwrite; done
kubectl -n lab-dns rollout restart daemonset/lab-dns 2>/dev/null || true
