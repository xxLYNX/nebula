# Gaming graphics configuration for Intel Iris Xe iGPU.
# Provides: hardware video decode, OpenGL, Vulkan support.
# Imported by modules/gaming/flake.nix nixosModules.default.

{ config, pkgs, lib, ... }:
let
  cfg = config.services.gaming or {};
in
lib.mkIf cfg.enable {
  # Intel media driver for hardware acceleration on Iris Xe.
  # Includes OpenGL, video decode (VA-API), and graphics rendering.
  hardware.graphics = {
    enable = true;
    enable32Bit = cfg.enable32bit;
    extraPackages = with pkgs; [
      intel-media-driver
      intel-vaapi-driver
    ];
    extraPackages32 = lib.optionals cfg.enable32bit (with pkgs.pkgsi686Linux; [
      intel-media-driver
      intel-vaapi-driver
    ]);
  };

  # Vulkan support (required for modern games).
  environment.systemPackages = with pkgs; [
    vulkan-loader
    vulkan-validation-layers
    vulkan-tools
  ];
}
