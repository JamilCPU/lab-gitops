#!/usr/bin/env bash
# Put the lab CA on an Android phone over adb and open the install screen.
# Android does not allow silent CA installs: on the phone, finish in
#   Settings > Security & privacy > More security settings > Encryption & credentials >
#   Install a certificate > CA certificate > Downloads/lab-ca.crt
# Chrome and apps that opt in to user CAs then trust *.lab; apps that do not opt in
# (network_security_config) keep using cert pinning or system CAs only.
#
#   bash install-ca-android.sh lab-ca.pem       # USB debugging on, `adb devices` shows the phone
set -euo pipefail
pem="${1:?path to lab-ca.pem (from export-ca.sh)}"
openssl x509 -in "$pem" -noout -subject -fingerprint -sha256
openssl x509 -in "$pem" -outform der -out /tmp/lab-ca.crt
adb push /tmp/lab-ca.crt /sdcard/Download/lab-ca.crt
rm -f /tmp/lab-ca.crt
adb shell am start -a android.settings.SECURITY_SETTINGS >/dev/null || true
echo "on the phone: install Downloads/lab-ca.crt as a CA certificate (check the SHA-256 above)"
