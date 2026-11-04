# Restoring the game servers on the primary worker (Linux)

The Minecraft and Terraria servers were **not** restored when the primary node moved from Windows to Linux, by choice.
This page is how to bring them back. Both backups live off-box on the workstation, in the `minecraft/` and `terraria/` folders of the clean pre-migration backup. Its `MANIFEST.md` lists the file counts and the worlds' SHA256 hashes.

Run both as **systemd services on the node**, not as k3s pods. They are heavy and long-lived: systemd is the simplest option, it survives reboots, and it keeps the big Minecraft heap out of Kubernetes scheduling.

## Minecraft (ATM10, NeoForge 21.1.228, port 25565)
1. Install Java 21, which it used on Windows: `sudo apt install openjdk-21-jre-headless`.
2. Copy `minecraft/server/` (about 3.9 GB) to `/data/games/minecraft/server` and `chown -R <admin-user>:` it.
   Check `world/level.dat` against the SHA256 in the manifest.
3. `user_jvm_args.txt` sets the heap. Keep `-Xms12G -Xmx12G` (the primary node has 32 GB) or lower it.
4. On Linux, start it with `./run.sh nogui`. That reads `libraries/net/neoforged/neoforge/21.1.228/unix_args.txt`, the Linux counterpart of the `win_args.txt` used by `start-server-headless.bat`.
5. Write a systemd unit at `/etc/systemd/system/minecraft.service`:
   - `User=<admin-user>`
   - `WorkingDirectory=…/server`
   - `ExecStart=…/run.sh nogui`
   - `Restart=on-failure`

   Stop the server with the RCON `stop` command, not SIGKILL. The RCON settings (`enable-rcon`, `rcon.port`, `rcon.password`) are in `server.properties`; never commit the password.
6. The old helpers in `minecraft/` are PowerShell: `backup.ps1`, and `tracker/` (the ATM10 dashboard and player tracker). Port the backup to a cron job or systemd timer that runs RCON `save-off`, then `save-all flush`, tars the world, then runs `save-on`.

## Terraria (tModLoader v2026.08.3.0, Calamity, 33 mods, port 25564)
1. Copy `terraria/` to `/data/games/terraria`.
   - Mods, configs and worlds are under `data/`. The world is `data/Worlds/Calamity.wld` plus `.twld`, and its last real save was 2026-10-16 20:06.
   - Check both files against the SHA256 in the manifest.
2. Delete the bundled `dotnet/` folder: it is the **Windows** .NET runtime. On first run, `start-tModLoaderServer.sh` downloads the Linux .NET 8 runtime into `dotnet/`; this needs internet.
3. Start it headless, using the Steam-free flag from the tModLoader docs (the one the Windows launcher used):
   `./start-tModLoaderServer.sh <steam-free flag> -config serverconfig.txt -tmlsavedirectory "$PWD/data"`.
   `serverconfig.txt` holds the world, port 25564, the 8-player limit and the password, so keep it out of git.
4. Wrap it in a systemd unit the same way as Minecraft.
   - On Windows it needed a stdin supervisor, and it had a "server is full" socket leak; the Terraria memory note has the details.
   - Under systemd, stop it by sending `exit` on stdin through a FIFO or `tmux`.
   - If the leak comes back, restart it nightly.

## Network
- Players outside the house reach the node through **two** layers of NAT, which is why Windows needed two port forwards. Check that both routers forward TCP 25565 and 25564 to the node's LAN address.
- If `ufw` is ever turned on for the node, allow 25565/tcp and 25564/tcp.
