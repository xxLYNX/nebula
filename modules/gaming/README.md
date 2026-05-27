# Gaming Module

Gaming support for NixOS workstations with performance optimizations. Provides Steam, Proton, Intel graphics drivers (optimized for Iris Xe iGPU), 32-bit multilib libraries, CPU frequency scaling, and GameMode.

## What It Provides

- **Steam** – the client and games platform
- **Proton** – compatibility layer for running non-native (Windows) games via Wine
- **Intel Media Driver** – hardware video acceleration for Intel integrated graphics (Iris Xe, etc.)
- **Vulkan** – modern graphics API support
- **32-bit Multilib Libraries** – required by most Steam games (configurable)
- **Controller Support** – udev rules for input devices (Xbox, PlayStation, etc.)
- **CPU Frequency Scaling** – prevents CPU from sitting at base clock during gaming (configurable governor)
- **GameMode** – automatic performance optimizations when games launch (Feral Interactive)
- **CPU Microcode Updates** – improves performance, stability, and security
- **Performance Kernel Parameters** – optional low-latency tuning for better frame timing

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
services.gaming = {
  enable = true;
  enable32bit = true;  # Optional (default: true) - required for most games
  cpuGovernor = "schedutil";  # Optional (default: "schedutil") - smart scaling + GameMode auto-boost
  enableGameMode = true;  # Optional (default: true) - auto-optimize when games launch
  enablePerformanceKernelParams = false;  # Optional (default: false) - low-latency kernel tuning
};
```

**Important**: Add `gamemoderun %command%` to Steam game launch options for automatic performance boost!

## Performance Modes

This module supports two performance modes:

### 🔋 Automatic Mode (Default - Recommended)

Best for laptops and general-purpose systems. Provides **automatic performance boost during gaming** with **battery savings** during normal use.

```nix
services.gaming = {
  enable = true;
  cpuGovernor = "schedutil";  # Smart scaling (default)
  enableGameMode = true;       # Auto-boost when gaming (default)
};
```

**How it works:**
- **Normal use** (browsing, coding): CPU scales intelligently (800MHz-2.5GHz) → saves battery ⚡
- **Game launches**: GameMode automatically boosts to max turbo (4.0GHz+) → maximum FPS 🎮
- **Game closes**: Reverts to smart scaling → saves battery again ⚡
- **Setup**: Add `gamemoderun %command%` to Steam game launch options (one-time setup per game)

**Result**: Best of both worlds - battery life AND gaming performance!

### ⚡ Always-On Performance Mode

Best for dedicated gaming desktops. CPU runs at **max turbo 24/7**.

```nix
services.gaming = {
  enable = true;
  cpuGovernor = "performance";  # Always max frequency
  enableGameMode = true;         # Still helpful for GPU/process optimizations
};
```

**Behavior:**
- CPU always runs at maximum turbo frequency (higher power consumption)
- No battery savings during normal use
- No need to add `gamemoderun` to Steam (already at max performance)
- GameMode still provides GPU optimizations and process priority

## Configuration Options

### `services.gaming.enable`
- **Type**: boolean
- **Default**: `false`
- **Description**: Master switch for gaming support. Enables Steam, Proton, graphics drivers, 32-bit support, and performance optimizations.

### `services.gaming.enable32bit`
- **Type**: boolean
- **Default**: `true`
- **Description**: Enable 32-bit library support. Required for most Steam games (majority of Windows games are 32-bit). Can be disabled to save ~2GB disk space if you only play native 64-bit games.

### `services.gaming.cpuGovernor`
- **Type**: string
- **Default**: `"schedutil"`
- **Description**: CPU frequency governor for system-wide use. When GameMode is enabled, it automatically boosts to "performance" during gaming.
  - `"schedutil"` (default) – Intelligent scaling based on CPU load. **Recommended** for automatic mode with battery savings.
  - `"performance"` – Always runs at max turbo frequency. Best for dedicated gaming desktops, higher power consumption.
  - `"powersave"` – Always low frequency. **Not recommended for gaming** – will severely throttle performance even with GameMode.

### `services.gaming.enableGameMode`
- **Type**: boolean
- **Default**: `true`
- **Description**: Enable Feral GameMode for automatic performance optimizations when games launch. Temporarily boosts CPU governor to "performance" and applies GPU optimizations during gameplay, then reverts when game closes. **Highly recommended** for automatic performance mode.

### `services.gaming.enablePerformanceKernelParams`
- **Type**: boolean
- **Default**: `false`
- **Description**: Enable performance-oriented kernel parameters (e.g., `preempt=full` for lower scheduling latency). May slightly reduce security for better gaming performance. Leave disabled unless you need maximum performance.

## Performance Optimizations

### CPU Frequency Scaling (CRITICAL!)

**The Problem**: Many Linux systems default to the `powersave` CPU governor, which keeps your CPU at base clock speeds even during heavy gaming loads. This causes:
- Severe FPS drops and stuttering
- CPU-bound games running at 50% of expected performance
- CPU sitting at 800MHz-1.5GHz instead of 4.0GHz+ turbo speeds

**The Solution**: This module uses **automatic performance boosting** by default:
- Sets `cpuGovernor = "schedutil"` for smart scaling during normal use (saves battery)
- Enables GameMode to **automatically boost to max turbo when games launch**
- Reverts to smart scaling when games close
- **Setup required**: Add `gamemoderun %command%` to Steam game launch options

**How to verify it's working**:
```bash
# Check current governor (should show "schedutil" normally, "performance" during gaming)
cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor

# Check current CPU frequency (should be near max turbo during gaming)
watch -n 1 'grep "cpu MHz" /proc/cpuinfo'

# Check GameMode status while game is running
gamemoded -s
```

**Governor Comparison**:
| Governor | Normal Use | During Gaming (with GameMode) | Power Usage | Recommended For |
|----------|------------|------------------------------|-------------|-----------------|
| `schedutil` (default) | Scales intelligently | Auto-boosts to max | Medium | ⭐ Laptops, general use |
| `performance` | Always max | Always max | High | Desktop gaming PCs |
| `powersave` | Always low | Still low (poor) | Low | **Not for gaming** |

### GameMode Integration (Automatic Performance Boost)

GameMode (by Feral Interactive) **automatically boosts performance when games launch, then reverts when they close**:

**What it does:**
- ✅ Temporarily switches CPU governor to `performance` (max turbo)
- ✅ Applies GPU performance profiles (Mesa drivers)
- ✅ Renices game process for better scheduling priority
- ✅ **Automatically reverts all changes when game closes** (saves battery)

**How to enable with Steam**: 
1. Right-click game in Steam library
2. Select **Properties** → **Launch Options**
3. Add: `gamemoderun %command%`
4. Done! Game will auto-boost to max performance when launched

**Result**: You get the best of both worlds:
- 🔋 Battery savings during browsing, coding, normal use
- 🎮 Maximum performance during gaming
- 🤖 Completely automatic switching

**Verify GameMode is active**:
```bash
# Check GameMode status (run while game is active)
gamemoded -s

# View GameMode logs
journalctl -u gamemode -f
```

### CPU Microcode Updates

The module automatically enables CPU microcode updates for both Intel and AMD processors (when `hardware.enableRedistributableFirmware = true`). This provides:
- Performance improvements (especially for newer CPUs)
- Stability fixes for CPU bugs
- Security patches for vulnerabilities (Spectre, Meltdown, etc.)

### Other Performance Features

- **Hardware video acceleration** (VA-API) enabled for Intel integrated graphics
- **Vulkan** support for modern games and APIs
- **32-bit graphics drivers** included when `enable32bit = true`
- **Performance kernel parameters** available via `enablePerformanceKernelParams` option (adds `preempt=full` for lower scheduling latency)

## Hardware Support

### Intel Integrated Graphics (Primary Support)

This module is optimized for **Intel integrated graphics** (iGPU), including:
- **Iris Xe Graphics** (11th gen Tiger Lake and newer)
- **UHD Graphics** (10th gen Ice Lake and newer)
- Older Intel HD Graphics (may work but not explicitly tested)

The following are automatically configured:
- `intel-media-driver` for hardware acceleration
- `intel-vaapi-driver` for video decode/encode
- Vulkan support via Mesa drivers
- 32-bit graphics libraries (when enabled)

### NVIDIA / AMD Discrete GPUs

For discrete NVIDIA or AMD GPUs, the standard NixOS hardware drivers apply. Steam and Proton will automatically detect and use discrete GPUs. You may need to add additional NixOS hardware configuration:

```nix
# For NVIDIA (add to configuration.nix)
services.xserver.videoDrivers = [ "nvidia" ];
hardware.nvidia.modesetting.enable = true;

# For AMD (usually works out of the box)
services.xserver.videoDrivers = [ "amdgpu" ];
```

## Module Structure

```
modules/gaming/
├── flake.nix              # Module definition and options
├── README.md              # This file
├── PERFORMANCE.md         # Quick reference for performance tuning
└── system/                # System-level NixOS configuration
    ├── graphics.nix       # Intel media driver, Vulkan, 32-bit multilib
    ├── steam.nix          # Steam client, Proton, controller support
    └── performance.nix    # CPU frequency, gamemode, microcode, kernel params
```

## Troubleshooting

### Low FPS / CPU Running at Base Clock

**Symptoms**: Games running at 50% expected FPS, CPU frequency stuck at 800MHz-1.5GHz

**Solution**:
```bash
# 1. Check current CPU governor
cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor
# Should show "schedutil" or "performance", not "powersave"

# 2. If wrong, verify your configuration includes:
services.gaming.cpuGovernor = "schedutil";  # or "performance"

# 3. Rebuild and check again
sudo nixos-rebuild switch
cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor

# 4. If using automatic mode, ensure GameMode is working:
# Add "gamemoderun %command%" to Steam game launch options
# Then check while game is running:
gamemoded -s
```

### GameMode Not Activating

**Symptoms**: CPU not boosting to max frequency during gaming, or `gamemoded -s` shows inactive

**Solution**:
```bash
# 1. Verify GameMode is enabled in config
services.gaming.enableGameMode = true;

# 2. Add to Steam game launch options
# Right-click game → Properties → Launch Options → Add:
gamemoderun %command%

# 3. Check daemon status while game is running
systemctl status gamemode
gamemoded -s

# 4. View logs for errors
journalctl -u gamemode -f
```

### Steam Won't Launch

**Solution**:
```bash
# 1. Ensure module is enabled
services.gaming.enable = true;

# 2. Rebuild system
sudo nixos-rebuild switch

# 3. Check for errors
journalctl -xe

# 4. Try launching Steam from terminal to see error messages
steam
```

### Games Crash on Startup

**Common causes**:

1. **Missing 32-bit libraries** (most common)
   ```nix
   services.gaming.enable32bit = true;  # Ensure this is set
   ```

2. **Incompatible Proton version**
   - In Steam: Right-click game → Properties → Compatibility
   - Try different Proton versions (Proton Experimental, Proton 8.0, etc.)

3. **Performance kernel params causing issues**
   ```nix
   services.gaming.enablePerformanceKernelParams = false;  # Disable if crashes occur
   ```

4. **Check Proton logs**:
   ```bash
   tail -f ~/.steam/root/logs/content_log.txt
   ```

### Controller Not Detected

**Solution**:
```bash
# 1. Unplug and replug controller

# 2. Check if kernel sees it
lsusb | grep -i "xbox\|playstation\|controller"

# 3. Check for udev rules (should be automatic with this module)
ls /etc/udev/rules.d/ | grep steam

# 4. Reload udev rules
sudo udevadm control --reload
sudo udevadm trigger
```

### System Feels Sluggish Outside Gaming

**Problem**: If using `cpuGovernor = "performance"`, CPU runs at max frequency 24/7

**Solution**: Switch to automatic mode (recommended):
```nix
services.gaming = {
  enable = true;
  cpuGovernor = "schedutil";  # Smart scaling
  enableGameMode = true;       # Auto-boost during gaming only
};
```

Then add `gamemoderun %command%` to Steam game launch options. This gives you battery savings during normal use and maximum performance during gaming.

## Advanced Configuration

### Optional Performance Monitoring Tools

Uncomment these in `system/performance.nix` for additional tools:

```nix
environment.systemPackages = with pkgs; [
  mangohud  # FPS/performance overlay for Vulkan/OpenGL games
  cpupower  # CPU frequency monitoring and control tools
];
```

**Using MangoHud**: Add to Steam launch options:
```
mangohud gamemoderun %command%
```

### Disabling CPU Security Mitigations (Advanced)

For maximum performance at the cost of security, you can disable CPU vulnerability mitigations. **Only do this if you understand the security implications**.

In `system/performance.nix`, uncomment:
```nix
boot.kernelParams = [
  "mitigations=off"  # ⚠️ Disables Spectre, Meltdown, etc. protections
];
```

This can provide 5-15% FPS boost in CPU-bound games but leaves your system vulnerable to CPU-level exploits.

## Quick Config Examples

### Automatic Mode (Recommended for most users)
```nix
services.gaming = {
  enable = true;
  enable32bit = true;
  cpuGovernor = "schedutil";  # Smart scaling (default)
  enableGameMode = true;       # Auto-boost when gaming (default)
  enablePerformanceKernelParams = false;
};
```
Add `gamemoderun %command%` to Steam games for automatic performance boost.

### Always-On Performance (Desktop gaming PC)
```nix
services.gaming = {
  enable = true;
  enable32bit = true;
  cpuGovernor = "performance";  # Always max frequency
  enableGameMode = true;         # Still helpful for GPU optimizations
  enablePerformanceKernelParams = true;
};
```
No need to add `gamemoderun` - already at max performance.

### Minimal (Native Linux games only, no auto-boost)
```nix
services.gaming = {
  enable = true;
  enable32bit = false;  # Saves ~2GB disk space
  cpuGovernor = "schedutil";
  enableGameMode = false;
  enablePerformanceKernelParams = false;
};
```

## See Also

- [NixOS Gaming Wiki](https://nixos.wiki/wiki/Gaming)
- [Proton on GitHub](https://github.com/ValveSoftware/Proton)
- [Steam on NixOS](https://nixos.wiki/wiki/Steam)
- [GameMode on GitHub](https://github.com/FeralInteractive/gamemode)
- [Intel Graphics on Arch Wiki](https://wiki.archlinux.org/title/Intel_graphics)
- [PERFORMANCE.md](PERFORMANCE.md) - Quick reference guide for performance tuning