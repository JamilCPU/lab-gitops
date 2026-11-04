#!/usr/bin/env bash
# Hand the lab CA key pair to cert-manager (once per cluster, or after rotating the CA).
# The ClusterIssuer `lab-ca` signs from this Secret. Reuses the CA from make-lab-tls.sh, so
# clients that already trust it need nothing new.
#
#   bash import-ca.sh [ca-dir]      # default ./lab-tls (holds lab-ca.pem + lab-ca.key)
set -euo pipefail
dir="${1:-./lab-tls}"
[[ -f "$dir/lab-ca.pem" && -f "$dir/lab-ca.key" ]] || { echo "need $dir/lab-ca.pem and $dir/lab-ca.key (run make-lab-tls.sh first)" >&2; exit 1; }
kubectl create namespace cert-manager --dry-run=client -o yaml | kubectl apply -f -
kubectl -n cert-manager create secret tls lab-ca --cert="$dir/lab-ca.pem" --key="$dir/lab-ca.key" \
  --dry-run=client -o yaml | kubectl apply -f -
echo "cert-manager/lab-ca updated"
