# blackhole — PHP 2026 runtime research lab

Host-side tooling lives on **pluto**; **run the web stack only inside a VM** on libvirt network `blackhole`.

See **`TOOLING.md`** for commands, Ghidra, ASan builds, and git repos.

## Target layout (disclosure-aligned surfaces)

| Surface | Lab artifact |
| -------- | ------------- |
| mod_php + Apache | Official `php:*-apache` or `localhost/blackhole-php:*-asan` |
| Multipart / RFC1867 | Ticket form + on-disk uploads under `/var/www/uploads` |
| Session upload progress | `session.upload_progress.*` in `conf/php-lab.ini` + hidden form field |
| Early ini diagnostics | `/status.php` (optional `?phpinfo=1`) |
| OOM / memory pressure | `/memory_lab.php?mb=N`, `/oom_target.php`, `conf/php-oom-probe.ini` |
| Worker forensics | `/pid.php`, scripts in `scripts/` |
| Impact proof | Flag at **`/var/blackhole/flag.txt`** (not under webroot) |

## On pluto (after Colmena)

- Lab tree: **`/etc/blackhole/lab`** (this directory).
- **virt-manager** + network **`blackhole`** (`192.168.100.0/24`, isolated).
- **pwndbg**, **Ghidra**, **Valgrind**, **rizin**, **frida-tools**, **bpftrace**, **ASan image builder**.

```bash
blackhole-sync-guest voyager@192.168.100.188
blackhole-build-asan-image 8.4.26   # on pluto with network; podman save → guest
```

## Guest (Debian) setup

```bash
sudo apt install podman podman-compose git curl
# gdb/strace/lsof optional — sync scripts from pluto
podman load -i php-8.4.26-apache.tar   # if air-gapped
```

### Run (inside VM)

```bash
cd ~/blackhole-lab
BLACKHOLE_DEBUG=1 PHP_VERSION=8.4.26 blackhole-compose up -d
curl -s http://127.0.0.1:8080/status.php | head
bash ~/blackhole-scripts/post-oom-health-probe.sh 127.0.0.1 8080
```

## php-src (pluto or telescope)

```bash
git diff php-8.4.26 php-8.4.27 -- main/rfc1867.c ext/session Zend/
blackhole-php-debug tests/basic/oom_rfc1867_upload_progress.phpt  # after run-tests setup
```

## Flag

Successful runtime compromise should read **`/var/blackhole/flag.txt`** inside the container/VM.
