# Fragment: firmware updates for physical machines.
# Enables hardware.enableRedistributableFirmware (CPU microcode + driver blobs)
# and services.fwupd (LVFS-based UEFI/device firmware flashing).
# Defaults to enabled on machines tagged "physical"; no-ops on VMs/containers.

{ config, lib, machine, ... }:
let
  cfg       = config.services.maintenance.firmware;
  isPhysical = builtins.elem "physical" (machine.tags or []);
in {
  options.services.maintenance.firmware = {
    enable = lib.mkOption {
      type        = lib.types.bool;
      default     = isPhysical;
      description = ''
        Enable firmware update support. Defaults to true on machines tagged
        "physical", false otherwise.
        - hardware.enableRedistributableFirmware: packs CPU microcode (Intel/AMD)
          and driver firmware blobs into the initrd/closure.
        - services.fwupd: LVFS daemon for flashing UEFI, NIC, SSD, and other
          device firmware. Vendor-signed updates only; actual flash happens on
          next reboot under UEFI control.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    hardware.enableRedistributableFirmware = true;
    services.fwupd.enable                  = true;
  };
}
