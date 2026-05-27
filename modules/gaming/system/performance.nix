# Gaming performance optimizations for NixOS.
# Provides: CPU frequency scaling, gamemode, microcode updates, kernel tuning.
# Imported by modules/gaming/flake.nix nixosModules.default.

{ config, pkgs, lib, ... }:
let
  cfg = config.services.gaming or {};
in
lib.mkIf cfg.enable {
  # CPU frequency governor: base governor for system-wide use.
  # When GameMode is enabled and a game launches, it will AUTOMATICALLY boost to "performance".
  #
  # Recommended setup for automatic gaming performance + battery savings:
  #   - Set cpuGovernor = "schedutil" (default)
  #   - Enable GameMode (default: true)
  #   - Add "gamemoderun %command%" to Steam game launch options
  #   - Result: Smart scaling normally, automatic max performance during gaming
  #
  # Governor options:
  #   "schedutil" (default) = intelligent scaling, great battery life, auto-boost via GameMode
  #   "performance" = always max frequency (24/7), best for dedicated gaming PC
  #   "powersave" = always low frequency, not recommended even with GameMode
  powerManagement.cpuFreqGovernor = lib.mkDefault cfg.cpuGovernor;

  # CPU microcode updates for Intel/AMD.
  # Improves performance, stability, and security.
  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
  hardware.cpu.amd.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;

  # GameMode: AUTOMATICALLY boosts performance when games launch, then reverts when they close.
  # Actions: Temporarily switches to "performance" governor, applies GPU optimizations, renices process.
  # Usage: Add "gamemoderun %command%" to Steam game launch options.
  # Result: Automatic performance boost during gaming, battery savings during normal use.
  programs.gamemode = lib.mkIf cfg.enableGameMode {
    enable = true;
    settings = {
      general = {
        # Renice game process for better scheduling priority
        renice = 10;
      };
      gpu = {
        # Apply GPU performance mode (works with Mesa drivers)
        apply_gpu_optimisations = "accept-responsibility";
        gpu_device = 0;
      };
      custom = {
        # Custom scripts can be added here if needed
        # start = "${pkgs.libnotify}/bin/notify-send 'GameMode started'";
        # end = "${pkgs.libnotify}/bin/notify-send 'GameMode ended'";
      };
    };
  };

  # Performance kernel parameters for gaming.
  # These improve latency and responsiveness during gameplay.
  boot.kernelParams = lib.optionals cfg.enablePerformanceKernelParams [
    # Reduce scheduling latency for better frame timing
    "preempt=full"

    # Uncomment below for maximum performance at cost of security:
    # Disables CPU vulnerability mitigations (Spectre, Meltdown, etc.)
    # "mitigations=off"
  ];

  # Additional performance monitoring tools (optional, commented out by default)
  environment.systemPackages = with pkgs; [
    # mangohud  # FPS/performance overlay for Vulkan/OpenGL games
    # cpupower  # CPU frequency monitoring and control tools
  ];
}
