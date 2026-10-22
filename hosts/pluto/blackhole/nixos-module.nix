# blackhole — host tooling, lab etc., libvirt network (pluto only).
{ config, pkgs, lib, inputs, ... }:
let
  inherit (pkgs.stdenv.hostPlatform) system;
  pwndbgPkg = inputs.pwndbg.packages.${system}.pwndbg;
  blackholeLab = ./.;
  llvm = pkgs.llvmPackages;

  phpDebugCli = pkgs.callPackage ./nix/php-debug-cli.nix { };

  blackholePackages = with pkgs; [
    virt-manager
    virt-viewer
    qemu_kvm
    OVMF
    libguestfs
    cloud-utils
    podman-compose
    podman
    skopeo
    buildah
    binutils
    gdb
    strace
    ltrace
    lsof
    elfutils
    bpftrace
    procps
    psmisc
    gawk
    jq
    rsync
    git
    curl
    wget
    python3
    pkg-config
    autoconf
    automake
    libtool
    re2c
    bison
    flex
    gnumake
    gcc
    clang
    llvm.libllvm
    llvm.llvm
    valgrind
    rizin
    python3Packages.frida-python
    pwndbgPkg
    ghidra
    phpDebugCli
    (writeShellScriptBin "blackhole-compose" ''
      LAB="''${BLACKHOLE_LAB:-/etc/blackhole/lab}"
      FILES=(-f "$LAB/compose.yaml")
      if [[ "''${BLACKHOLE_DEBUG:-0}" == 1 ]]; then
        FILES+=(-f "$LAB/compose.debug.yaml")
      fi
      if [[ -n "''${BLACKHOLE_ASAN:-}" ]]; then
        FILES+=(-f "$LAB/compose.asan.yaml")
      fi
      exec ${podman-compose}/bin/podman-compose "''${FILES[@]}" "$@"
    '')
    (writeShellScriptBin "blackhole-gdb" ''
      exec ${pwndbgPkg}/bin/pwndbg "$@"
    '')
    (writeShellScriptBin "blackhole-symbolize" ''
      exec ${llvm.llvm}/bin/llvm-symbolizer "$@"
    '')
    (writeShellScriptBin "blackhole-extract-libphp" ''
      set -euo pipefail
      IMAGE="''${1:?usage: blackhole-extract-libphp IMAGE [OUTDIR]}"
      OUT="''${2:-./artifacts/libphp}"
      mkdir -p "$OUT"
      CID=$(${pkgs.podman}/bin/podman create "$IMAGE")
      trap "${pkgs.podman}/bin/podman rm -f $CID" EXIT
      ${pkgs.podman}/bin/podman cp "$CID:/usr/local/lib/libphp.so" "$OUT/libphp.so" 2>/dev/null \
        || ${pkgs.podman}/bin/podman cp "$CID:/usr/lib/apache2/modules/libphp.so" "$OUT/libphp.so"
      ${pkgs.podman}/bin/podman cp "$CID:/usr/local/bin/php" "$OUT/php.bin" 2>/dev/null || true
      echo "extracted to $OUT"
    '')
    (writeShellScriptBin "blackhole-ghidra-import" ''
      set -euo pipefail
      LIB="''${1:?usage: blackhole-ghidra-import /path/to/libphp.so [project-name]}"
      PROJ="''${2:-blackhole-libphp}"
      GH="${pkgs.ghidra}/lib/ghidra/support/analyzeHeadless"
      ROOT="''${BLACKHOLE_GHIDRA:-$HOME/blackhole-ghidra}"
      mkdir -p "$ROOT"
      "$GH" "$ROOT" "$PROJ" -import "$LIB" -overwrite -deleteProject
      echo "Ghidra project $PROJ at $ROOT"
    '')
    (writeShellScriptBin "blackhole-sync-guest" ''
      set -euo pipefail
      GUEST="''${1:-voyager@192.168.100.188}"
      LAB="''${BLACKHOLE_LAB:-/etc/blackhole/lab}"
      RSYNC="${pkgs.rsync}/bin/rsync"
      ssh "$GUEST" "mkdir -p ~/blackhole-lab ~/blackhole-scripts"
      if ssh "$GUEST" command -v rsync >/dev/null 2>&1; then
        "$RSYNC" -av --delete "$LAB/" "$GUEST:~/blackhole-lab/"
        "$RSYNC" -av "$LAB/scripts/" "$GUEST:~/blackhole-scripts/"
      else
        ${pkgs.gnutar}/bin/tar -C "$LAB" -cf - . | ssh "$GUEST" "tar -xf - -C ~/blackhole-lab --overwrite && chmod -R u+w ~/blackhole-lab"
        ${pkgs.gnutar}/bin/tar -C "$LAB/scripts" -cf - . | ssh "$GUEST" "tar -xf - -C ~/blackhole-scripts --overwrite && chmod -R u+w ~/blackhole-scripts"
      fi
      echo "synced lab + scripts to $GUEST"
    '')
    (writeShellScriptBin "blackhole-build-asan-image" ''
      set -euo pipefail
      VER="''${1:-8.4.26}"
      LAB="''${BLACKHOLE_LAB:-/etc/blackhole/lab}"
      TAG="localhost/blackhole-php:''${VER}-asan"
      ${pkgs.podman}/bin/podman build \
        -f "$LAB/docker/Dockerfile.php-asan" \
        --build-arg "PHP_VERSION=$VER" \
        -t "$TAG" \
        "$LAB/docker"
      echo "built $TAG — use: BLACKHOLE_ASAN=1 PHP_VERSION=$VER blackhole-compose up -d --force-recreate"
    '')
    (writeShellScriptBin "blackhole-php-src" ''
      set -euo pipefail
      ROOT="''${BLACKHOLE_PHP_SRC:-$HOME/Projects/telescope/php-src}"
      if [[ ! -d "$ROOT/.git" ]]; then
        echo "clone php-src to $ROOT first (see /etc/blackhole/lab/TOOLING.md)"
        exit 1
      fi
      cd "$ROOT"
      exec "$@"
    '')
  ];
in
{
  nix.settings.substituters = lib.mkAfter [ "https://pwndbg.cachix.org" ];
  nix.settings.trusted-public-keys = lib.mkAfter [
    "pwndbg.cachix.org-1:HhtIpP7j73SnuzLgobqqa8LVTng5Qi36sQtNt79cD3k="
  ];

  virtualisation.libvirtd.enable = lib.mkDefault true;
  virtualisation.libvirtd.qemu.package = lib.mkDefault pkgs.qemu_kvm;

  virtualisation.podman = {
    enable = lib.mkDefault true;
    dockerCompat = lib.mkDefault false;
    defaultNetwork.settings.dns_enabled = lib.mkDefault true;
  };

  users.users.voyager.extraGroups = lib.mkAfter [
    "libvirtd"
    "kvm"
    "podman"
  ];

  environment.systemPackages = blackholePackages;

  environment.etc."blackhole/libvirt-network.xml".source = "${blackholeLab}/libvirt-blackhole.xml";
  environment.etc."blackhole/lab".source = blackholeLab;

  systemd.services.blackhole-libvirt-network = {
    description = "blackhole isolated libvirt network";
    after = [ "libvirtd.service" ];
    requires = [ "libvirtd.service" ];
    wantedBy = [ "multi-user.target" ];
    path = [ pkgs.libvirt ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      if ! virsh net-info blackhole >/dev/null 2>&1; then
        virsh net-define /etc/blackhole/libvirt-network.xml
        virsh net-autostart blackhole
      fi
      virsh net-start blackhole 2>/dev/null || true
    '';
  };

  environment.interactiveShellInit = lib.mkAfter ''
    export BLACKHOLE_LAB=/etc/blackhole/lab
    export PATH="$BLACKHOLE_LAB/scripts:$PATH"
    alias blackhole-gdb='${pwndbgPkg}/bin/pwndbg'
  '';
}
