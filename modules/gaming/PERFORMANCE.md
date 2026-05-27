# Gaming Performance Quick Reference

## TL;DR - Fix Low FPS Now

Your CPU is probably stuck at base clock. Check it:
```bash
cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor
```

If it says `powersave`, you need this in your config:
```nix
services.gaming.cpuGovernor = "performance";
```

Then rebuild:
```bash
sudo nixos-rebuild switch
```

## Performance Checklist

### ✅ Essential (Do These First)

- [ ] **CPU Governor = Performance**
  ```nix
  services.gaming.cpuGovernor = "performance";
  ```
  - Prevents CPU from sitting at base clock (800MHz → 4000MHz+)
  - Single biggest performance impact
  - Check: `cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor`

- [ ] **32-bit Libraries Enabled** (if playing Windows games)
  ```nix
  services.gaming.enable32bit = true;  # default: true
  ```
  - Required for most Steam/Proton games
  - Check: `steam` launches without library errors

- [ ] **GameMode Enabled**
  ```nix
  services.gaming.enableGameMode = true;  # default: true
  ```
  - Auto-boosts performance when games launch
  - Add to Steam launch options: `gamemoderun %command%`
  - Check while gaming: `gamemoded -s`

### 🔧 Recommended

- [ ] **CPU Microcode Updated**
  ```nix
  hardware.enableRedistributableFirmware = true;
  ```
  - Automatically enabled by this module
  - Fixes CPU bugs, improves stability

- [ ] **Verify Graphics Drivers Loaded**
  ```bash
  lspci -k | grep -A 2 VGA
  ```
  - Should show `i915` driver in use for Intel
  - Or `nvidia`/`amdgpu` for discrete GPUs

### ⚡ Optional (Advanced)

- [ ] **Performance Kernel Parameters**
  ```nix
  services.gaming.enablePerformanceKernelParams = true;  # default: false
  ```
  - Adds `preempt=full` for lower latency
  - May cause instability on some systems

- [ ] **Disable Security Mitigations** (⚠️ security risk)
  - Edit `modules/gaming/system/performance.nix`
  - Uncomment: `"mitigations=off"`
  - 5-15% FPS boost but exposes CPU vulnerabilities

## CPU Governor Comparison

| Governor | When to Use | Performance | Power | Notes |
|----------|-------------|-------------|-------|-------|
| `performance` | Gaming PC, desktop | ⭐⭐⭐⭐⭐ | High | Always max speed |
| `schedutil` | Laptop, mixed use | ⭐⭐⭐⭐ | Medium | Smart scaling |
| `powersave` | Battery only | ⭐ | Low | **Never for gaming** |

## Diagnostic Commands

### Check CPU Performance
```bash
# Current governor (should be "performance")
cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor

# Current CPU frequencies (should be near max turbo)
watch -n 1 'grep "cpu MHz" /proc/cpuinfo'

# Available governors
cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_available_governors
```

### Check GameMode
```bash
# Check if GameMode daemon is running
systemctl status gamemode

# Check GameMode status (while game is running)
gamemoded -s

# Watch GameMode logs
journalctl -u gamemode -f
```

### Check Graphics
```bash
# Verify driver loaded
lspci -k | grep -A 2 VGA

# Check Vulkan support
vulkaninfo | head -20

# Test OpenGL
glxinfo | grep "OpenGL version"
```

### Check Steam
```bash
# Verify Steam installed
which steam

# Check 32-bit library support
file $(which steam)

# Steam logs (if game crashes)
tail -f ~/.steam/root/logs/content_log.txt
```

## Common Performance Issues

### Issue: Low FPS, CPU at 800MHz-1.5GHz

**Cause**: `powersave` governor active

**Fix**:
1. Set `services.gaming.cpuGovernor = "performance";`
2. `sudo nixos-rebuild switch`
3. Verify: `cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor`

---

### Issue: FPS drops/stuttering during gameplay

**Causes**:
- Thermal throttling (check `sensors`)
- Background processes (check `htop`)
- GameMode not active (add `gamemoderun %command%` to Steam)

**Fix**:
```bash
# Check temperatures
sensors

# Check CPU load
htop

# Enable GameMode for game
# Steam → Game Properties → Launch Options:
gamemoderun %command%
```

---

### Issue: Game crashes on startup

**Causes**:
1. Missing 32-bit libraries
2. Wrong Proton version
3. Performance kernel params incompatible

**Fix**:
```nix
# Ensure 32-bit enabled
services.gaming.enable32bit = true;

# Disable aggressive kernel params
services.gaming.enablePerformanceKernelParams = false;
```

Then in Steam:
- Right-click game → Properties → Compatibility
- Try different Proton versions

---

### Issue: GameMode not boosting performance

**Cause**: Not added to game launch options

**Fix**:
1. Right-click game in Steam library
2. Properties → Launch Options
3. Add: `gamemoderun %command%`
4. Launch game
5. Verify: `gamemoded -s` (should show "active")

---

### Issue: System sluggish when not gaming

**Cause**: `performance` governor always runs at max frequency

**Fix Option 1** (Recommended):
```nix
services.gaming.cpuGovernor = "schedutil";
```
Smart scaling, still good gaming performance.

**Fix Option 2**:
```nix
services.gaming.cpuGovernor = "schedutil";  # or "powersave"
services.gaming.enableGameMode = true;      # GameMode will boost when gaming
```
Then add `gamemoderun %command%` to Steam games.

## Performance Monitoring

### Real-time FPS/Stats Overlay

Install MangoHud (edit `system/performance.nix`):
```nix
environment.systemPackages = with pkgs; [
  mangohud
];
```

Use in Steam launch options:
```
mangohud gamemoderun %command%
```

Shows: FPS, frame time, CPU/GPU usage, temperature

### Benchmark Your System

```bash
# CPU stress test
stress-ng --cpu $(nproc) --timeout 60s --metrics

# GPU test (run while monitoring `watch sensors`)
vkcube  # Vulkan test

# Check if CPU hits turbo frequencies during load
watch -n 1 'grep "cpu MHz" /proc/cpuinfo'
```

## Expected Performance Gains

With proper configuration:

| Fix | Expected FPS Gain | Impact |
|-----|------------------|--------|
| `performance` governor | +50-200% | ⭐⭐⭐⭐⭐ Critical |
| 32-bit libraries | Game works vs. crashes | ⭐⭐⭐⭐⭐ Critical |
| GameMode | +5-15% | ⭐⭐⭐⭐ High |
| CPU microcode | +2-5% stability | ⭐⭐⭐ Medium |
| `preempt=full` | Smoother framing | ⭐⭐ Low |
| `mitigations=off` | +5-15% | ⭐⭐ Low (security risk) |

## Quick Config Examples

### Maximum Performance (Desktop Gaming PC)
```nix
services.gaming = {
  enable = true;
  enable32bit = true;
  cpuGovernor = "performance";
  enableGameMode = true;
  enablePerformanceKernelParams = true;
};
```

### Balanced (Laptop/General Use)
```nix
services.gaming = {
  enable = true;
  enable32bit = true;
  cpuGovernor = "schedutil";
  enableGameMode = true;
  enablePerformanceKernelParams = false;
};
```

### GameMode Only (Power Conscious)
```nix
services.gaming = {
  enable = true;
  enable32bit = true;
  cpuGovernor = "schedutil";  # or "powersave"
  enableGameMode = true;       # Boosts only during gaming
  enablePerformanceKernelParams = false;
};
```

Add to all Steam games: `gamemoderun %command%`

## After Configuration Changes

Always rebuild and verify:
```bash
# 1. Rebuild system
sudo nixos-rebuild switch

# 2. Verify governor
cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor

# 3. Check CPU frequency under load
# Open a game or run: stress-ng --cpu $(nproc) --timeout 10s
grep "cpu MHz" /proc/cpuinfo

# 4. Verify GameMode (if enabled)
systemctl status gamemode

# 5. Test a game
steam
```

## Need Help?

1. Check logs: `journalctl -xe`
2. Steam logs: `~/.steam/root/logs/content_log.txt`
3. GPU driver: `lspci -k | grep -A 2 VGA`
4. See full README: `modules/gaming/README.md`
