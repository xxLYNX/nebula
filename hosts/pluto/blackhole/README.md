# blackhole — PHP 2026 runtime research lab

Host-side tooling lives on pluto; **run the web stack only inside a VM** on libvirt network `blackhole`.

## Target layout (disclosure-aligned surfaces)

| Surface | Lab artifact |
| -------- | ------------- |
| mod_php + Apache | Official `php:*-apache` image |
| Multipart / RFC1867 | Ticket form + on-disk uploads under `/var/www/uploads` |
| Session upload progress | `session.upload_progress.*` in `conf/php-lab.ini` + hidden form field |
| Early ini diagnostics | `/status.php` (optional `?phpinfo=1`) |
| OOM / memory pressure | `/memory_lab.php?mb=N` + tunable `memory_limit` |
| Impact proof | Flag at **`/var/blackhole/flag.txt`** (not under webroot; not served by app) |

## On pluto (after Colmena / nixos-rebuild)

- **virt-manager**: VM on network `blackhole` (`192.168.100.0/24`, no upstream route).
- Tools: `pwndbg`, `blackhole-gdb`, `ghidra`, `valgrind`, lab tree at **`/etc/blackhole/lab`**.

### Guest (Debian) setup

```bash
sudo apt install podman podman-compose git curl gdb binutils
podman pull docker.io/library/php:8.4.26-apache
podman pull docker.io/library/php:8.4.27-apache
```

Copy `/etc/blackhole/lab` from pluto or use this repo path inside the VM.

### Run (inside VM)

```bash
cd /path/to/lab
blackhole-compose up -d   # or: podman-compose -f compose.yaml up -d
podman-compose exec web php -v
curl -s http://127.0.0.1:8080/status.php | head
curl -s http://127.0.0.1:8080/upload_progress.php

PHP_VERSION=8.4.27 blackhole-compose up -d --force-recreate
```

Record image digest + `php -v` for each run. For historical **source** analysis (issues predating container tags), use php-src tags/branches — not necessarily runnable PHP 5 binaries.

### Flag

Successful runtime compromise should read **`/var/blackhole/flag.txt`** inside the container/VM. The PHP app does not reference this path.

## php-src (on pluto)

```bash
git clone --filter=blob:none https://github.com/php/php-src.git
cd php-src && git fetch --tags
git diff php-8.4.26 php-8.4.27 -- Zend/zend_alloc.c main/main.c main/rfc1867.c ext/session sapi/apache2handler
blackhole-gdb
```
