# Gaming Module

Minimal gaming support for NixOS workstations. Provides Steam, Proton, Intel graphics drivers (optimized for Iris Xe iGPU), and 32-bit multilib libraries.

## What It Provides

- **Steam** – the client and games platform
- **Proton** – compatibility layer for running non-native (Windows) games via Wine
- **Intel Media Driver** – hardware video acceleration for Intel integrated graphics (Iris Xe, etc.)
- **Vulkan** – modern graphics API support
- **32-bit Multilib Libraries** – required by most Steam games (configurable)
- **Controller Support** – udev rules for input devices (Xbox, PlayStation, etc.)

## Usage

### Add to Your Machine

In `inventory/machines.json`, add `gaming` to the modules list:

```json
"os": {
  "role": "pluto",
  "modules": ["desktop", "web-utils", "maintenance", "gaming"]
}
```

### Enable in Host Configuration

In `hosts/<hostname>/configuration.nix`:

```nix
services.gaming.enable = true;
services.gaming.enable32bit = true;  # Optional (default: true)
```

## Options

### System-Level

- `services.gaming.enable` (bool, default: `false`)
  - Master switch for gaming support. Enables Steam, Proton, graphics drivers, and 32-bit support.
  
- `services.gaming.enable32bit` (bool, default: `true`)
  - Enable 32-bit library support. Required for most Steam games. Can be disabled to save disk space if only running native 64-bit games.

## Hardware Support

This module is optimized for **Intel integrated graphics** (iGPU), including:
- TigerLake-LP GT2 (Iris Xe)
- Other modern Intel integrated graphics (10th gen and newer)

For **discrete NVIDIA** or **AMD** GPUs, the standard NixOS hardware drivers apply; Steam will use those automatically.

## How It Works

### System-Level Configuration (`system/`)

- **graphics.nix** – Configures Intel media driver, Vulkan, 32-bit multilib
- **steam.nix** – Installs Steam, Proton, and controller udev rules

### Home-Manager Configuration (`home/`)

- **steam.nix** – Placeholder for future user-level Steam tweaks (e.g., Proton environment variables, game-specific settings)

## Performance Notes

- **Hardware acceleration** is enabled by default (VA-API, Intel media driver)
- **Vulkan validation layers** are installed for debugging; disable if not needed
- **32-bit libraries** add ~2GB to the store; disable if disk space is tight

## Extending

To add game-specific tweaks (e.g., custom Proton versions, per-game environment variables):

1. Edit `home/steam.nix` to add user-level config
2. Or edit `system/steam.nix` to modify system packages or environment variables

## Troubleshooting

**Steam won't launch:**
- Ensure `services.gaming.enable = true` is set
- Run `sudo nixos-rebuild switch` to rebuild the system
- Check `journalctl -xe` for permission or library errors

**Games crash on startup:**
- Verify 32-bit support is enabled: `services.gaming.enable32bit = true`
- Try forcing a specific Proton version via `PROTON_VERSION=<version>` environment variable
- Check Steam's Proton log at `~/.steam/root/logs/`

**Controller not detected:**
- Ensure the module is enabled (udev rules are installed automatically)
- Try unplugging and re-plugging the controller
- Check `lsusb` to confirm the device is detected by the kernel

## See Also

- [NixOS Gaming Wiki](https://nixos.wiki/wiki/Gaming)
- [Proton Documentation](https://github.com/ValveSoftware/Proton)
- [Steam on NixOS](https://nixos.wiki/wiki/Steam)