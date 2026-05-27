# MangoHud performance overlay configuration for gaming.
#
# Provides:
# - MangoHud package
# - System-level MangoHud config
# - A stable MANGOHUD_CONFIGFILE path for Steam launch options
#
# Usage in Steam launch options:
#   mangohud gamemoderun %command%
#
# If using gamescope:
#   gamescope --mangoapp -W 1280 -H 720 -r 60 -f -- gamemoderun %command%

{
  config,
  pkgs,
  lib,
  ...
}:

let
  cfg = config.services.gaming or { };

  mangoHudConfigPath = "/etc/xdg/MangoHud/MangoHud.conf";
in
lib.mkIf (cfg.enable && cfg.enableMangoHud) {
  environment.systemPackages = with pkgs; [
    mangohud
    gamescope

    # Useful for Intel iGPU debugging outside MangoHud:
    #   sudo intel_gpu_top
    intel-gpu-tools
  ];

  # MangoHud normally reads per-user config from ~/.config/MangoHud/MangoHud.conf.
  # For a system-level NixOS gaming module, expose a stable config file and point
  # MangoHud at it with MANGOHUD_CONFIGFILE.
  environment.etc."xdg/MangoHud/MangoHud.conf".text = ''
    ############################
    # Nebula MangoHud profile  #
    ############################

    # Keep the HUD readable but detailed enough for diagnosis.
    position=top-left
    font_size=18
    background_alpha=0.45
    round_corners=6
    table_columns=2

    ################
    # Frame timing #
    ################

    fps
    frametime
    frame_timing
    dynamic_frame_timing
    present_mode
    show_fps_limit
    resolution
    display_server

    ##################
    # GPU visibility #
    ##################

    gpu_stats
    gpu_temp
    gpu_core_clock
    gpu_mem_clock
    gpu_power
    gpu_power_limit
    gpu_name
    gpu_load_change
    gpu_load_value=60,90
    vulkan_driver
    vram

    ##################
    # CPU visibility #
    ##################

    cpu_stats
    cpu_temp
    cpu_power
    cpu_mhz
    cpu_load_change
    cpu_load_value=60,90

    # Per-core/thread load is important for diagnosing Unreal Engine-style
    # main-thread bottlenecks where total CPU usage looks low.
    core_load
    core_bars

    #####################
    # System visibility #
    #####################

    ram
    swap
    battery
    battery_watt
    wine
    winesync
    gamemode
    arch
    engine_short_names
    exec_name

    ######################
    # Throttle detection #
    ######################

    throttling_status
    throttling_status_graph

    #################
    # Logging hooks #
    #################

    # Toggle HUD: Right Shift + F12
    toggle_hud=Shift_R+F12

    # Toggle logging: Left Shift + F2
    toggle_logging=Shift_L+F2

    # Put benchmark logs somewhere predictable.
    output_folder=/tmp
    log_duration=120
    log_interval=100
    benchmark_percentiles=97,AVG,1,0.1
  '';

  # Make the system-level config discoverable to games launched from the desktop.
  # Restart the graphical session, or at least fully restart Steam, after rebuild.
  environment.sessionVariables = {
    MANGOHUD_CONFIGFILE = mangoHudConfigPath;
  };
}
