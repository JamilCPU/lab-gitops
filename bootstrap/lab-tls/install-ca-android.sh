#!/usr/bin/env bash
# Put the lab CA on an Android phone over adb and open the install screen.
# Android does not allow silent CA installs: on the phone, finish in
#   Settings > Security & privacy > More security settings > Encryption & credentials >
#   Install a certificate > CA certificate > Downloads/lab-ca.crt
# After a CA rotation, also remove the retired one under
#   Encryption & credentials > Trusted credentials > User ("lab CA").
# Chrome and apps that opt in to user CAs then trust *.lab; apps that do not opt in
# (network_security_config) keep using cert pinning or system CAs only.
#
#   bash install-ca-android.sh user@k3s-server   # fetch the CA over ssh with kubectl
#   bash install-ca-android.sh lab-ca.pem        # or a file from export-ca.sh
# USB debugging on, `adb devices` shows the phone.
set -euo pipefail
src="${1:?user@k3s-server or path to lab-ca.pem}"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
if [[ -f "$src" ]]; then
  cp "$src" "$tmp/lab-ca.pem"
else
  ssh "$src" "kubectl -n cert-manager get secret lab-ca -o jsonpath='{.data.tls\.crt}' | base64 -d" > "$tmp/lab-ca.pem"
fi
grep -q 'BEGIN CERTIFICATE' "$tmp/lab-ca.pem" || { echo "no certificate read from $src" >&2; exit 1; }
openssl x509 -in "$tmp/lab-ca.pem" -noout -ext keyUsage | grep -q 'Certificate Sign' \
  || { echo "CA has no keyCertSign usage (retired CA?)" >&2; exit 1; }
openssl x509 -in "$tmp/lab-ca.pem" -noout -subject -fingerprint -sha256
openssl x509 -in "$tmp/lab-ca.pem" -outform der -out "$tmp/lab-ca.crt"
adb push "$tmp/lab-ca.crt" /sdcard/Download/lab-ca.crt
adb shell am start -a android.settings.SECURITY_SETTINGS >/dev/null || true
echo "on the phone: install Downloads/lab-ca.crt as a CA certificate (check the SHA-256 above)"
