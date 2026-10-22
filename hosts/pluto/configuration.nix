{ client, inputs, pkgs, lib, ... }:
let
  inherit (pkgs.stdenv.hostPlatform) system;
  pwndbgPkg = inputs.pwndbg.packages.${system}.pwndbg;
  blackholeLab = ./blackhole;
  # blackholePackages — merged into environment.systemPackages (options marked below).
  blackholePackages = with pkgs; [
    virt-manager
    virt-viewer
    qemu_kvm
    OVMF
    libguestfs
    cloud-utils
    podman-compose
    binutils
    pwndbgPkg
    ghidra
    valgrind
    (writeShellScriptBin "blackhole-compose" ''
      exec ${podman-compose}/bin/podman-compose -f /etc/blackhole/lab/compose.yaml "$@"
    '')
    (writeShellScriptBin "blackhole-gdb" ''
      exec ${pwndbgPkg}/bin/pwndbg "$@"
    '')
  ];
in
{
  imports = [
    ./hardware-configuration.nix
  ];

  environment.systemPackages = with pkgs; [
    tailscale
    asusctl
    fzf
    yazi
    tree
    bitwarden-desktop
    pkgs.qbittorrent
    obsidian
    zed-editor
    mage
    cargo
    rustc
    gcc
    gnumake
    texlive.combined.scheme-full # latex-for-resume-repo
    gh
    tio
    usbutils
    forgejo-cli
    brightnessctl
  ] ++ blackholePackages;

  services.power-profiles-daemon.enable = true;
  services.tailscale = {
    enable = true;
  };

  services.asusd = {
    enable = true;
  };

  # asusd's unit uses PrivateMounts and expects /etc/asusd before namespacing.
  # The NixOS module only creates that path when declarative configs are set.
  systemd.services.asusd.serviceConfig.ConfigurationDirectory = "asusd";

  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };

  services.syncthing = {
    enable = true;

    # Run it as your normal user (recommended for a desktop/dev machine)
    user = "voyager";
    group = "users";

    # Where to store config + data (change if you want)
    configDir = "/home/voyager/.config/syncthing";
    dataDir = "/home/voyager/Sync"; # or wherever you want your synced folders

    # Allow you to change devices/folders from the web GUI
    overrideDevices = true;
    overrideFolders = true;

    # (Optional but nice) open the GUI only on localhost
    guiAddress = "127.0.0.1:8384";
  };

  # Use latest stable kernel for security updates and performance improvements
  boot.kernelPackages = pkgs.linuxPackages_latest;

  # Gaming support: Steam + Intel Iris Xe graphics + Proton + 32-bit multilib
  # Intel P-State active mode (default): uses HWP for efficient power management
  # In active mode, "powersave" governor ≈ schedutil (smart scaling)
  # GameMode will automatically boost to "performance" when games launch
  # services.gaming.enable comes from inventory os.modules (flake.nix)
  services.gaming = {
    enable32bit = true;
    cpuGovernor = "powersave"; # In intel_pstate active mode, powersave = smart scaling
  };

  # --- blackhole: PHP 2026 runtime research lab (host tooling + isolated libvirt net) ---

  nix.settings.substituters = lib.mkAfter [ "https://pwndbg.cachix.org" ];
  nix.settings.trusted-public-keys = lib.mkAfter [
    "pwndbg.cachix.org-1:HhtIpP7j73SnuzLgobqqa8LVTng5Qi36sQtNt79cD3k="
  ];

  virtualisation.libvirtd.enable = true;
  virtualisation.libvirtd.qemu.package = pkgs.qemu_kvm;

  virtualisation.podman = {
    enable = true;
    dockerCompat = false;
    defaultNetwork.settings = {
      dns_enabled = true;
    };
  };

  programs.dconf.enable = true;

  users.users.voyager.extraGroups = lib.mkAfter [
    "libvirtd"
    "kvm"
    "podman"
  ];

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
    # blackhole lab helpers (plain GDB remains ${pkgs.gdb}/bin/gdb).
    export BLACKHOLE_LAB=/etc/blackhole/lab
    alias blackhole-gdb='${pwndbgPkg}/bin/pwndbg'
  '';

  # --- end blackhole ---

}
