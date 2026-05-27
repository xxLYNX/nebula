# Gaming performance optimizations for NixOS.
# Provides: CPU frequency scaling, gamemode, microcode updates, kernel tuning.
# Imported by modules/gaming/flake.nix nixosModules.default.

{
  config,
  pkgs,
  lib,
  primaryUser ? null,
  ...
}:

let
  cfg = config.services.gaming or { };
in
lib.mkIf cfg.enable {
  # CPU frequency governor: base governor for system-wide use.
  #
  # Intel P-State active mode (default on modern Intel CPUs):
  # In active mode with HWP (Hardware P-States), only "performance" and "powersave"
  # governors are available. The "powersave" governor in active mode is hardware-managed
  # and provides intelligent scaling similar to "schedutil" in passive mode.
  #
  # Recommended setup for automatic gaming performance + battery savings:
  # - Set cpuGovernor = "powersave" (smart scaling via HWP in active mode)
  # - Enable GameMode
  # - Add "gamemoderun %command%" to Steam launch options
  # - Result: smart scaling normally, performance governor while gaming
  #
  # Governor options in intel_pstate active mode:
  # "powersave"   = hardware-managed intelligent scaling (recommended for laptops)
  # "performance" = always max turbo frequency (for desktops)
  #
  # Note: When governor switches to "performance" in active mode, EPP automatically
  # becomes "performance" and allows full turbo boost (e.g., 4.7GHz on i7-1165G7).
  powerManagement.cpuFreqGovernor = lib.mkDefault cfg.cpuGovernor;

  # CPU microcode updates for Intel/AMD.
  # Improves performance, stability, and security.
  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
  hardware.cpu.amd.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;

  # Power Profiles Daemon: required for proper GPU power management on Intel iGPUs.
  # Without this, GPU may not reach full performance clocks during gaming.
  # Works alongside GameMode to optimize power delivery to CPU and GPU.
  services.power-profiles-daemon.enable = true;

  # GameMode: automatically boosts performance when games launch,
  # then reverts when they close.
  #
  # Steam usage:
  #   gamemoderun %command%
  programs.gamemode = lib.mkIf cfg.enableGameMode {
    enable = true;

    # NixOS defaults this to true, but keeping it explicit documents that
    # renice support is expected.
    enableRenice = true;

    settings = {

      general = {
        renice = 10;

        desiredgov = "performance";
        defaultgov = cfg.cpuGovernor;

        desiredprof = "performance";

        # Integrated-GPU-aware behavior:
        # if iGPU load is high relative to CPU load, GameMode may use powersave
        # for the CPU governor to avoid starving the iGPU package budget.
        igpu_desiredgov = "powersave";
        igpu_power_threshold = 0.3;

        inhibit_screensaver = 1;
      };

      gpu = {
        # Enables GameMode GPU performance hooks where supported.
        # Upstream intentionally requires this exact "accept-responsibility"
        # value for GPU optimizations.
        apply_gpu_optimisations = "accept-responsibility";
        gpu_device = 0;
      };

      cpu = {
        # [cpu] is for GameMode's parking/pinning features, not governor switching.
        #
        # Leave these off by default unless you have a hybrid CPU or AMD X3D CPU
        # and specifically want to test GameMode's core placement behavior.
        park_cores = "no";
        pin_cores = "no";
      };

      custom = {
        # Custom scripts can be added here if needed.
        # start = "${pkgs.libnotify}/bin/notify-send 'GameMode started'";
        # end = "${pkgs.libnotify}/bin/notify-send 'GameMode ended'";
      };
    };
  };

  # NixOS's GameMode module creates the "gamemode" group.
  # Add the primary admin user to it when Nebula provides primaryUser.
  users.users = lib.mkIf (cfg.enableGameMode && primaryUser != null) {
    ${primaryUser}.extraGroups = [ "gamemode" ];
  };

  # Performance kernel parameters for gaming.
  # These improve latency and responsiveness during gameplay.
  boot.kernelParams = lib.optionals cfg.enablePerformanceKernelParams [
    # Reduce scheduling latency for better frame timing.
    "preempt=full"

    # Uncomment below for maximum performance at cost of security:
    # Disables CPU vulnerability mitigations (Spectre, Meltdown, etc.)
    # "mitigations=off"
  ];

  # Additional performance monitoring tools.
  environment.systemPackages = with pkgs; [
    gamemode
    libnotify

    # Uncomment if you want these available globally:
    # mangohud
    # cpupower
  ];
}
