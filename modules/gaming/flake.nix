{
  description = "Gaming module: Steam + Intel graphics + Proton + 32-bit support + performance optimizations";

  inputs = {
    nixpkgs.follows = "nixpkgs";
  };

  outputs =
    { self, nixpkgs, ... }:
    let
      lib = nixpkgs.lib;

      importDir =
        dir:
        builtins.map (name: dir + "/${name}") (
          builtins.filter (name: builtins.match ".*\.nix$" name != null) (
            builtins.attrNames (lib.filterAttrs (_: type: type == "regular") (builtins.readDir dir))
          )
        );
    in
    {

      # ── System NixOS module ────────────────────────────────────────────────
      # Configures: graphics drivers, 32-bit support, Steam, Proton, CPU frequency scaling, gamemode.
      # All configuration is system-level; Steam doesn't require home-manager.
      nixosModules.default =
        {
          config,
          pkgs,
          lib,
          ...
        }:
        let
          cfg = config.services.gaming or { };
        in
        {
          imports = importDir ./system;

          options.services.gaming = {
            enable = lib.mkOption {
              type = lib.types.bool;
              default = false;
              description = "Enable gaming support (Steam, Proton, graphics drivers, 32-bit libraries).";
            };
            enable32bit = lib.mkOption {
              type = lib.types.bool;
              default = true;
              description = "Enable 32-bit library support for Steam games.";
            };
            cpuGovernor = lib.mkOption {
              type = lib.types.str;
              default = "powersave";
              description = ''
                CPU frequency governor for system-wide use.
                When GameMode is enabled, it will automatically boost to "performance" during gaming.

                For Intel P-State active mode (default on modern Intel CPUs):
                - "powersave" = intelligent scaling (recommended) - similar to schedutil but hardware-managed
                - "performance" = always max frequency

                For Intel P-State passive mode or other drivers:
                - "schedutil" = intelligent scaling
                - "performance" = always max frequency
                - "powersave" = low frequency bias

                Default "powersave" works best with intel_pstate active mode (HWP).
              '';
            };
            enableGameMode = lib.mkOption {
              type = lib.types.bool;
              default = true;
              description = ''
                Enable Feral GameMode for automatic performance optimizations when games launch.
                Temporarily boosts CPU governor and applies GPU optimizations during gameplay.
              '';
            };
            enablePerformanceKernelParams = lib.mkOption {
              type = lib.types.bool;
              default = false;
              description = ''
                Enable performance-oriented kernel parameters (e.g., preempt=full for lower latency).
                May slightly reduce security for better gaming performance.
              '';
            };
            enableMangoHud = lib.mkOption {
              type = lib.types.bool;
              default = true;
              description = ''
                Enable MangoHud performance overlay for monitoring FPS, CPU/GPU stats, and GameMode status.
                Add "mangohud %command%" to Steam launch options to use.
              '';
            };
          };

          # MangoHud configuration for performance monitoring
          config = lib.mkIf cfg.enableMangoHud {
            programs.mangohud = {
              enable = true;
              settings = {
                # FPS and frame timing
                fps = true;
                frametime = true;
                frame_timing = true;

                # CPU monitoring
                cpu_stats = true;
                cpu_temp = true;
                cpu_power = true;
                cpu_mhz = true;
                core_load = true;

                # GPU monitoring
                gpu_stats = true;
                gpu_temp = true;
                gpu_power = true;
                gpu_core_clock = true;
                gpu_mem_clock = true;
                vram = true;

                # System monitoring
                ram = true;
                wine = true;
                gamemode = true;

                # Throttling detection
                throttling_status = true;

                # Display position (top-left by default)
                position = "top-left";
              };
            };
          };

        };
    };
}
