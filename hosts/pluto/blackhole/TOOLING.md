# blackhole tooling (pluto host + guest VM)

Goal: lab POC for **CVE-2026-109618 / CVE-2026-109619** (PHP RFC1867 / upload-progress OOM bailout → state corruption), ending in controlled read of **`/var/blackhole/flag.txt`**.

## After Colmena on pluto

| Command | Purpose |
|---------|---------|
| `blackhole-compose` | Podman stack (`/etc/blackhole/lab/compose.yaml`) |
| `BLACKHOLE_DEBUG=1 blackhole-compose up -d` | Adds `SYS_PTRACE`, `php-oom-probe.ini` |
| `blackhole-build-asan-image 8.4.26` | Build `localhost/blackhole-php:8.4.26-asan` (needs network) |
| `BLACKHOLE_ASAN=1 blackhole-compose up -d` | ASan mod_php stack |
| `blackhole-gdb` / `pwndbg` | Interactive debug (host or guest with symbols) |
| `blackhole-extract-libphp IMAGE [dir]` | Pull `libphp.so` from container image |
| `blackhole-ghidra-import libphp.so [proj]` | Headless Ghidra import |
| `blackhole-symbolize` | `llvm-symbolizer` for ASan stacks |
| `blackhole-sync-guest [user@ip]` | Rsync lab + scripts to VM |
| `blackhole-php-debug` | Nix debug PHP **CLI** on pluto (vendor phpt, not mod_php) |
| `blackhole-php-src git …` | Wrapper around `~/Projects/telescope/php-src` |

Scripts (also on guest at `~/blackhole-scripts/` after sync):

- `run-wedge-investigation.sh` — health probe + pin + FD capture (+ `RUN_GDB=1`)
- `capture-wedged-fds.sh`, `gdb-nsenter-wedged.sh`, `pin-wedged-worker.sh`
- `oom_rfc1867_http_probe.py`, `post-oom-health-probe.sh`

## Guest VM workflow

```bash
blackhole-sync-guest voyager@192.168.100.188
ssh voyager@192.168.100.188
cd ~/blackhole-lab
BLACKHOLE_DEBUG=1 PHP_VERSION=8.4.26 blackhole-compose up -d --force-recreate
bash ~/blackhole-scripts/run-wedge-investigation.sh
# gdb backtraces (host namespace):
sudo GDB=blackhole-gdb RUN_GDB=1 bash ~/blackhole-scripts/run-wedge-investigation.sh
```

After NAT bootstrap only if needed: `apt install gdb` on guest — pluto ships gdb via sync is optional; prefer `sudo gdb-nsenter-wedged.sh` on guest.

## Ghidra (pluto)

```bash
blackhole-extract-libphp docker.io/library/php:8.4.26-apache ./artifacts/php826
blackhole-extract-libphp docker.io/library/php:8.4.27-apache ./artifacts/php827
blackhole-ghidra-import ./artifacts/php826/libphp.so php826
blackhole-ghidra-import ./artifacts/php827/libphp.so php827
# GUI: ghidra → diff Decompiler on functions from commit 506e87fa7d
```

## Git repos (not all packaged in nixpkgs)

| Repo | Use |
|------|-----|
| https://github.com/php/php-src | Tags `php-8.4.26` / `php-8.4.27`, `oom_rfc1867_*` tests |
| https://github.com/pwndbg/pwndbg | Flake input → `blackhole-gdb` |
| https://github.com/NationalSecurityAgency/ghidra | Via nixpkgs `ghidra` + headless scripts |
| https://github.com/rizinorg/rizin | CLI RE (`rizin` on pluto) |
| https://github.com/frida/frida | `frida-tools` for optional dynamic hooks |

Clone php-src once:

```bash
mkdir -p ~/Projects/telescope
git clone --filter=blob:none https://github.com/php/php-src.git ~/Projects/telescope/php-src
cd ~/Projects/telescope/php-src && git fetch --tags
```

## Valgrind

Use `blackhole-php-debug` + `valgrind --tool=memcheck` against CLI reproduction of multipart logic, or Valgrind on a custom Apache build (heavy). ASan image is the primary mod_php path.

## Compose files

| File | When |
|------|------|
| `compose.yaml` | Default official `php:*-apache` |
| `compose.debug.yaml` | `BLACKHOLE_DEBUG=1` — ptrace + OOM probe ini |
| `compose.asan.yaml` | `BLACKHOLE_ASAN=1` — local ASan image |
