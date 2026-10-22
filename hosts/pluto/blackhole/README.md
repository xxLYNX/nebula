# blackhole — PHP 2026 runtime research lab

Host-side tooling and lab assets for pluto. **Do not** run the vulnerable web stack on pluto; use a VM on the isolated libvirt network `blackhole`.

## On pluto (after `nixos-rebuild switch`)

- **virt-manager**: create a VM attached to network `blackhole` (isolated, `192.168.100.0/24`).
- **Snapshot** the guest after installing Podman and pulling images, then disable WAN for experiments.
- **Analysis tools**: `pwndbg`, `blackhole-gdb` (same as pwndbg), `ghidra`, `valgrind`, plus `blackhole-compose` for the reference app tree under `/etc/blackhole/lab`.

### Suggested guest (Debian) packages

```bash
sudo apt install podman podman-compose git curl gdb binutils
podman pull docker.io/library/php:8.4.26-apache
podman pull docker.io/library/php:8.4.27-apache
```

Copy or bind-mount `/etc/blackhole/lab` from pluto (e.g. `scp -r`) or clone this repo inside the VM.

### Run the lab (inside the VM)

```bash
cd /path/to/lab
podman compose up -d
podman compose exec web php -v
curl -i http://127.0.0.1:8080/

# Patched runtime comparison
podman compose down
PHP_VERSION=8.4.27 podman compose up -d --force-recreate
```

### Pre-pull on pluto (optional, air-gap helper)

```bash
cd /etc/blackhole/lab
podman pull docker.io/library/php:8.4.26-apache
podman pull docker.io/library/php:8.4.27-apache
podman save -o blackhole-php-images.tar docker.io/library/php:8.4.26-apache docker.io/library/php:8.4.27-apache
# Transfer blackhole-php-images.tar to the VM, then: podman load -i blackhole-php-images.tar
```

## php-src investigation (host)

```bash
git clone --filter=blob:none https://github.com/php/php-src.git
cd php-src && git fetch --tags
git diff php-8.4.26 php-8.4.27 -- Zend/zend_alloc.c main/main.c
pwndbg  # use instead of gdb when debugging instrumented builds in the VM
```
