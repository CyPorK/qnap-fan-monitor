# qnap-ec-fan-monitor — QNAP IT8528 hwmon driver, fan control & monitoring (Proxmox VE / Linux)

## What this fork adds — Proxmox VE + fancontrol + live dashboard

This fork extends the original [QNAP-EC driver by Stonyx](https://github.com/Stonyx/QNAP-EC)
with a working setup for **QNAP NAS running Proxmox VE** (or any Linux) instead of QuTS Hero.

Without this, fans spin up to full speed whenever CPU load exceeds ~20%, making the machine
extremely loud. This repo provides everything needed to fix that.

### What's included

| Component | Description |
|---|---|
| `qnap-ec.conf` | Module config — enables `sim_pwm_enable=yes` (required for fancontrol) |
| `fancontrol` | Ready-to-use fancontrol config with temp→PWM curves for drives and CPU |
| `install.sh` | One-shot install script — full setup from scratch (driver + fancontrol + qnap-monitor) |
| `qnap-monitor` | Live terminal dashboard — temperatures, fan RPMs, CPU load |

### qnap-monitor

A `top`-like dashboard that refreshes every 2 seconds:

```
  -- CPU ------------------------------------------------------------------
  Package:   61°C  [████████████░░░░░░░░]  61%   Total load: [███░░░░░░░░░░░░]  19%
             temp              load cpu N (HT)       load cpu N+6 (HT)
  Core 0:   56°C  [███████████░░░░░░░░░]  56%  cpu0 [██░░░░░░░░]  19%  cpu6 [██░░░░░░░░]  21%
  ...

  -- EC Chip (IT8528) ---------------------------------------------------
  CPU zone (EC):    54°C  [███████████░░░░░░░░░░░]  54%
  Drive zone 1:     29°C  [██████████░░░░░░░░░░░░]  48%
  Ambient (intake): 20°C  [█████████░░░░░░░░░░░░░]  44%

  -- Fans ---------------------------------------------------------------
  Chassis (PWM  30%)
    fan1:           1488 RPM  [██████████░░░░░░░░░░░░]  49%
  ...

  [OK] fancontrol active
```

Install globally:
```bash
sudo install -m 755 qnap-monitor /usr/local/bin/qnap-monitor
qnap-monitor        # refresh every 2s
qnap-monitor 5      # refresh every 5s  |  q = quit
```

### Quick install (full setup from scratch)

```bash
git clone https://github.com/CyPorK/qnap-ec-fan-monitor
cd qnap-ec-fan-monitor
sudo bash install.sh
```

This will:
1. Install kernel headers and build tools
2. Compile and install the `qnap-ec` kernel module
3. Configure autostart via `/etc/modules`
4. Set up `fancontrol` with temp→PWM curves
5. Install `qnap-monitor` to `/usr/local/bin/`

> **After a kernel update:** `cd qnap-ec-fan-monitor && sudo make install && sudo systemctl restart fancontrol`

### Tested on

- **Hardware**: QNAP TVS-h1288X, Intel Xeon W-1250 (6C/12T), ITE IT8528 EC chip
- **OS**: Proxmox VE 8, Debian 12, kernel `6.8.12-9-pve`

See [PROJECT.md](PROJECT.md) for full installation details and sensor mapping.

### Security & Safety

This repo installs a **kernel module** (ring 0 — full system access). Before running `install.sh` on any machine:

- Review the driver source: `qnap-ec.c`, `qnap-ec-helper.c`
- Note that `libuLinux_hal.so` is a closed-source binary from QNAP (extracted from TS-873A firmware)
- Only install on systems you own and control
- The module is loaded automatically on boot via `/etc/modules` — removing it requires `sudo make uninstall`

---

## Upstream documentation (original QNAP-EC by Stonyx)

> The section below is preserved from the [original QNAP-EC repository](https://github.com/Stonyx/QNAP-EC) by Stonyx.
> **For Proxmox VE / Debian installations use `install.sh` instead** — the manual steps below target vanilla Ubuntu 20.04 and are outdated for this fork.

---

A Linux hwmon driver kernel module for the QNAP IT8528 Embedded Controller chip (and possibly others).  This driver supports reading the fan speeds and temperatures as well as reading and writing the fan P.W.M. values from the ITE Tech Inc. IT8528 embedded controller chip that is used in many QNAP NAS models.  Because the IT8528 chip can run custom firmware this driver is most likely specific to the firmware that QNAP uses on these chips.  It is based on the reverse engineering knowledge originally gathered by [guedou](https://github.com/guedou) with lots of operational and testing help provided by [r-pufky](https://github.com/r-pufky).

In order to provide the greatest compatibility, this driver uses a library that is supplied by QNAP in it's NAS operating system.  The libuLinux_hal library that is part of this repository was taken from a QNAP-TS873A model running QTS 4.5.4.1800.  In order to ensure proper functionality, you should replace the libuLinux_hal.so library file with one from the operating system image for the exact QNAP NAS model you will be running this driver on.  Because this driver uses the QNAP library it is conceivable that it will work with other chips used by QNAP that are supported by the libuLinux_hal library.

Using a vanilla Ubuntu 20.04.2.0 Live DVD system as an example, you can build this driver by running the following commands:
```
sudo apt install build-essential git
git clone https://github.com/Stonyx/QNAP-EC
cd QNAP-EC
sudo make install
```
This will compile, link, and install the needed files along with inserting the module into the kernel (it uses modprobe to insert the module into the kernel which will NOT persist after a reboot).

If you would like the kernel module to skip checking for the presence of the IT8528 chip (for example to run it on a QNAP NAS unit with a different chip to see if this driver will work) run the following command when inserting the module into the kernel:
```
sudo modprobe qnap-ec check-for-chip=no
```

For development purposes there is a simulated libuLinux_hal library included that can be used when developing on a machine that doesn’t have a compatible embedded controller chip.  To build the simulated library run the following command:
```
make sim-lib
```
This will replace the libuLinux_hal library with the simulated library so that running `sudo make install` will install the simulated library (don't forget to include the `check-for-chip=no` module parameter when inserting the module into the kernel to skip the check for the presence of the IT8528 chip).

To uninstall the driver completely run the following command:
```
sudo make uninstall
```

This driver has three components, the kernel module file called `qnap-ec.ko` which would be installed in the `/lib/modules/5.8.0-43-generic/extra` directory on a vanilla Ubuntu 20.04.2.0 Live DVD system, the helper program file called `qnap-ec` which would be installed in the `/usr/local/sbin` directory (on a vanilla Ubuntu 20.04.2.0 Live DVD system) and the QNAP library file called `libuLinux_hal.so` which would be installed in the `/usr/local/lib` directory (on a vanilla Ubuntu 20.04.2.0 Live DVD).

If this driver is being installed on a Linux distribution with a different folder structure (for example Unraid) the files will need to be manually installed.  The `qnap-ec.ko` kernel module file location will depend on where the system usually expects kernel modules to be located.  The `qnap-ec` helper program file will need to reside in one of the following locations in order for the kernel module to be able to call it correctly (the first two locations are only valid if this driver is not being packaged):
```
/usr/local/sbin
/usr/local/bin
/usr/sbin
/usr/bin
/sbin
/bin
```
And the `libuLinux_hal.so` QNAP library file will need to be in a location where the dynamic linker will be able to find it.

If you would like to create a package containing this driver run the following command which uses the `package` make target in combination with `DESTDIR` to create the necessary files and folders in the package staging location:
```
sudo make package DESTDIR=full_path_to_package_staging_location
```
You can also add `DEBIAN=yes` or `SLACKWARE=yes` to the package command to copy the package describing `control` or `slack-desc` files to the staging location.
