# qnap-ec-fan-monitor — TVS-h1288X + Proxmox VE

## What was done

### The problem
QNAP TVS-h1288X running Proxmox VE had no access to the IT8528 embedded controller sensors —
no fan speed readings and no PWM control. As a result, fans would spin up to full speed
whenever CPU load exceeded ~20%, making the machine extremely loud.

### Solution
Installed the [QNAP-EC](https://github.com/Stonyx/QNAP-EC) driver (by Stonyx)
— an open-source kernel module for the ITE IT8528 embedded controller.

### Environment
- **Hardware**: QNAP TVS-h1288X, Intel Xeon W-1250, EC chip: ITE IT8528
- **OS**: Proxmox VE, Debian 12.10, kernel `6.8.12-9-pve`
- **PVE host**: `<pve-host>`

### Quick install

Run this on the **PVE host** (not inside a VM):

```bash
git clone https://github.com/CyPorK/qnap-ec-fan-monitor
cd qnap-ec-fan-monitor
sudo bash install.sh
```

This installs everything: kernel module, fancontrol, and qnap-monitor.

> **After a kernel update:** `cd qnap-ec-fan-monitor && sudo make install && sudo systemctl restart fancontrol`

### Manual installation steps

1. **Source code review** — security audit of the driver
2. **Architecture decision** — the driver must run on the PVE host, not inside a VM
3. **Install dependencies** on the PVE host:
   ```
   sudo apt install pve-headers-$(uname -r) gcc make
   ```
4. **Build and install**:
   ```
   sudo make install
   ```
5. **Verification** — module loaded successfully, IT8528 chip detected automatically
6. **Autostart** — added `qnap-ec` to `/etc/modules`

### Key finding
The `libuLinux_hal.so` library bundled in the repo (taken from a QNAP TS-873A)
**works correctly** on TVS-h1288X without any modifications.
Likely because both platforms use the same IT8528 chip and the QTS-specific
file dependencies (`/etc/model.conf`) are stubbed out in the helper via the `-export-dynamic` flag.

---

## Active sensors

Device `qnap_ec` (`/sys/class/hwmon/hwmon19/`) — the `hwmon19` number may change after a reboot.
Detect dynamically: `grep -rl qnap_ec /sys/class/hwmon/*/name | head -1 | xargs dirname`

### Temperatures
| Sensor | EC channel | Typical value | Description |
|---|---|---|---|
| temp1_input | EC #1 | ~67°C | CPU zone (EC thermistor near CPU) |
| temp6_input | EC #6 | ~35°C | Drive bay zone 1 |
| temp7_input | EC #7 | ~35°C | Drive bay zone 2 |
| temp8_input | EC #8 | ~20°C | Ambient / air intake |

### Fans
| Sensor | EC channel | Typical value | Description |
|---|---|---|---|
| fan1_input | EC fan1 | ~1900 RPM | Chassis fan 1 |
| fan2_input | EC fan2 | ~1900 RPM | Chassis fan 2 |
| fan3_input | EC fan3 | ~1875 RPM | Chassis fan 3 |
| fan4_input | EC fan4 | ~1880 RPM | Chassis fan 4 |
| fan7_input | EC fan7 | ~750 RPM | CPU fan 1 |
| fan8_input | EC fan8 | ~720 RPM | CPU fan 2 |

### PWM (control)
| Sensor | Value (0-255) | Duty cycle | Controls |
|---|---|---|---|
| pwm1 | 102 | ~40% | fan1-4 (chassis) |
| pwm7 | 73 | ~29% | fan7-8 (CPU) |

---

## Installed files

| File | Location | Description |
|---|---|---|
| `qnap-ec.ko` | `/lib/modules/6.8.12-9-pve/updates/` | Kernel module |
| `qnap-ec` | `/usr/local/sbin/` | Helper binary (user-space bridge) |
| `libuLinux_hal.so` | `/usr/local/lib/` | QNAP library (from TS-873A) |
| `qnap-ec.conf` | `/etc/modprobe.d/` | Module parameters (`sim_pwm_enable=yes`) |
| `fancontrol` | `/etc/fancontrol` | Fan control configuration |
| `qnap-monitor` | `/usr/local/bin/` | Live thermal dashboard (bash) |

Autostart: `qnap-ec` entry in `/etc/modules`; `fancontrol` as a systemd service.

---

## Components

### 1. Fancontrol — automatic fan speed control ✅ DONE

Installed and running since 2026-02-28.

#### Configuration files
- `/etc/modprobe.d/qnap-ec.conf` — enables `sim_pwm_enable=yes` (required by fancontrol)
- `/etc/fancontrol` — temp→PWM curves
- `install.sh` — install script (reusable after reinstallation)

#### Channel mapping
| PWM | Controlling sensor | Min temp | Max temp | Min PWM | Max PWM |
|---|---|---|---|---|---|
| pwm1 (fan1-4, chassis) | temp6_input (drives) | 30°C | 50°C | 80/255 | 255/255 |
| pwm7 (fan7-8, CPU) | temp1_input (CPU zone) | 45°C | 85°C | 60/255 | 255/255 |

#### Example values in operation
- Drives at 32°C → chassis fans ~1800 RPM (37% PWM)
- CPU zone at 79°C → CPU fans ~2330 RPM (80% PWM)

#### Rebuilding after a kernel update
After every PVE kernel update, rebuild and reinstall the module:
```bash
cd ~/qnap-ec-fan-monitor && sudo make install
sudo systemctl restart fancontrol
```

### 2. Live dashboard — qnap-monitor ✅ DONE

File: `qnap-monitor` (bash, installed at `/usr/local/bin/qnap-monitor`)

Dashboard refreshed every N seconds (default: 2s), displays:
- CPU temperatures (Package + per-core) with `█░` bars
- load per HT thread (cpu0+cpu6, cpu1+cpu7, …)
- EC chip temperatures (CPU zone, drives, ambient)
- fan speeds + current PWM%
- top 5 hottest drives
- fancontrol service status

```bash
qnap-monitor        # refresh every 2s
qnap-monitor 5      # refresh every 5s
q                   # quit
```

Hwmon paths are detected dynamically by name (`qnap_ec`, `coretemp`) —
resilient to numbering changes after kernel updates.

### 3. Long-term monitoring — Grafana + node_exporter

Goal: temperature, RPM and PWM charts over time.

```bash
# On the PVE host — node_exporter exposes /sys/class/hwmon/*
sudo apt install prometheus-node-exporter
# Metrics: http://<pve-host>:9100/metrics  (node_hwmon_*)
```

Grafana dashboard: import ID `1860` (Node Exporter Full).

### 4. Identifying inactive EC channels

EC channels that returned no data (temp2-5, fan5-6):
- May correspond to absent sensors (e.g. expansion bays)
- Worth investigating with the `val_pwm_channels=n` parameter:
  ```bash
  sudo modprobe -r qnap-ec
  sudo modprobe qnap-ec val_pwm_channels=n
  ```

### 5. Updating libuLinux_hal.so (optional)

If sensor readings become unreliable — try extracting the native library
from the TVS-h1288X firmware:

```bash
sudo apt install binwalk squashfs-tools
# Download TVS-h1288X firmware from support.qnap.com
binwalk TVS-h1288X_*.img
# Extract squashfs and locate /usr/lib/libuLinux_hal.so
```
