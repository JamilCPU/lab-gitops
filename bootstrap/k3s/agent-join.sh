#!/usr/bin/env bash
# Join this machine to the cluster as a k3s AGENT.
# Usage (on the agent): sudo K3S_URL=https://<server-ip>:6443 K3S_TOKEN_FILE=<file> NODE_IP=<lan-ip> \
#        NODE_LABELS="hardware/bluetooth-usb=true" bash agent-join.sh
# NODE_LABELS is optional and space-separated; hardware labels pin hardware-bound apps (see README).
# Only touches k3s: other services on the machine are left alone.
set -euo pipefail
K3S_VERSION="${K3S_VERSION:-v1.34.6+k3s1}"   # must not be newer than the server
: "${K3S_URL:?https://<server>:6443}"
: "${K3S_TOKEN_FILE:?file holding the server node-token (never pass the token on the command line)}"
: "${NODE_IP:?LAN address of this node}"
mkdir -p /etc/rancher/k3s
{
  echo "node-ip: ${NODE_IP}"
  if [ "${NODE_LABELS:-}" != "" ]; then
    echo "node-label:"
    for l in $NODE_LABELS; do echo "  - ${l}"; done
  fi
} > /etc/rancher/k3s/config.yaml
curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION="$K3S_VERSION" K3S_URL="$K3S_URL" \
  K3S_TOKEN_FILE="$K3S_TOKEN_FILE" sh -s - agent
systemctl is-active k3s-agent
