#!/usr/bin/env bash
# Install the k3s SERVER (control plane) on the big amd64 node.
# Usage (on the node): sudo NODE_IP=<lan-ip> bash server-install.sh
# Idempotent: re-running upgrades/reconfigures in place.
set -euo pipefail

K3S_VERSION="${K3S_VERSION:-v1.34.6+k3s1}"   # keep agents at or below this version
DATA_MOUNT="${DATA_MOUNT:-/data}"
: "${NODE_IP:?set NODE_IP to the LAN address of this node}"

mountpoint -q "$DATA_MOUNT" || { echo "$DATA_MOUNT is not mounted" >&2; exit 1; }
mkdir -p "$DATA_MOUNT/k3s-storage"

mkdir -p /etc/rancher/k3s
cat > /etc/rancher/k3s/config.yaml <<EOF
node-ip: ${NODE_IP}
node-label:
  - role=primary-worker
default-local-storage-path: ${DATA_MOUNT}/k3s-storage
write-kubeconfig-mode: "0640"
tls-san:
  - ${NODE_IP}
EOF

curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION="$K3S_VERSION" sh -s - server

# Let the admin user run kubectl without sudo.
if [ -n "${SUDO_USER:-}" ]; then
  groupadd -f k3s
  chgrp k3s /etc/rancher/k3s/k3s.yaml
  usermod -aG k3s "$SUDO_USER"
  install -d -o "$SUDO_USER" -g "$SUDO_USER" "/home/$SUDO_USER/.kube"
  grep -q KUBECONFIG "/home/$SUDO_USER/.bashrc" || \
    echo 'export KUBECONFIG=/etc/rancher/k3s/k3s.yaml' >> "/home/$SUDO_USER/.bashrc"
fi

for _ in $(seq 1 60); do k3s kubectl get node "$(hostname)" >/dev/null 2>&1 && break; sleep 3; done
k3s kubectl wait --for=condition=Ready node --all --timeout=180s
k3s kubectl get nodes -o wide
echo "Agent join token: sudo cat /var/lib/rancher/k3s/server/node-token"
