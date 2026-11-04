#!/usr/bin/env bash
# Print the lab CA certificate (public part only) from the cluster, for installing on clients.
#   bash export-ca.sh > lab-ca.pem
set -euo pipefail
kubectl -n cert-manager get secret lab-ca -o jsonpath='{.data.tls\.crt}' | base64 -d
