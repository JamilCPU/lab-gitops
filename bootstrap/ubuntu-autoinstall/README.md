# Remote Windows → Ubuntu Server reinstall (no USB, no monitor)

This turns a Windows box you can reach over SSH into Ubuntu Server 24.04 unattended, with one reboot.
The Linux worker/control-plane node was built this way.

## What it does
1. Downloads the Ubuntu live-server ISO onto the box and checks it against `SHA256SUMS`.
2. Shrinks a data partition and creates a ~6 GB **FAT32 partition labelled `CIDATA`**. It holds:
   - `ubuntu.iso`. FAT32's limit is 4 GiB, and the 24.04.5 ISO is 4.08 GB, so it fits.
   - `user-data` and `meta-data`. The installer finds these through cloud-init NoCloud, which looks for the `CIDATA` label.
3. Copies the ISO's signed `bootx64.efi` (shim), `grubx64.efi` and `mmx64.efi` into the EFI System Partition as `\EFI\ubuntu\shimx64.efi` etc., plus `grub.cfg` from this folder.
   - The signed grub's built-in prefix is `/EFI/ubuntu`, so it reads that `grub.cfg`. That config loopback-mounts the ISO from `CIDATA` and boots casper with `iso-scan/filename=… autoinstall`.
   - Secure Boot can stay on.
4. `bcdedit /copy {bootmgr} /d "Ubuntu Installer"`, then `bcdedit /set {new} path \EFI\ubuntu\shimx64.efi`, then `bcdedit /set {fwbootmgr} bootsequence {new}`.
   This is a **one-time** boot: if it fails, the firmware falls back to Windows.
5. If BitLocker is on: save the recovery password first (`manage-bde -protectors -get C:`), then `manage-bde -protectors -disable C: -RebootCount 1`.
   Otherwise a fallback boot into Windows asks for the recovery key.
6. `shutdown /r`. The installer wipes only the disk that matches `DISK_MODEL_GLOB`, applies the static network, installs OpenSSH with your key, and reboots into Ubuntu.

## Rendering the template
Fill in the `${…}` placeholders in `user-data.template` and `meta-data.template`. **Do not commit the rendered files.**
- `PASSWORD_HASH` comes from `openssl passwd -6`.
- `DISK_MODEL_GLOB` must match only the target disk (`lsblk -o NAME,MODEL`, or `Get-PhysicalDisk` on Windows).

```bash
export HOSTNAME=… NODE_CIDR=… GATEWAY=… DNS1=… DNS2=… NIC_MAC=… DISK_MODEL_GLOB=… \
       SSH_PUBKEY="$(cat ~/.ssh/id_ed25519.pub)" PASSWORD_HASH="$(openssl passwd -6)"
envsubst < user-data.template > user-data
envsubst < meta-data.template > meta-data
```

## Gotchas
- `Format-Volume` wants `-Force`, not `-Confirm:$false`, when called through ssh/cmd quoting.
- `early-commands` adds your key for the live `installer` user, so you can `ssh installer@<ip>` while it runs.
  This is best effort: it only works if the live environment brings up the network.
- The ESP may sit on a different disk than `C:`. The installer creates its own ESP on the target disk, and the old one is left in place.
