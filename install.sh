#!/bin/bash
# Full installation: qnap-ec driver + fancontrol + qnap-monitor
# Run as: sudo bash install.sh  (from repo root)

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# ── Helpers ────────────────────────────────────────────────────────────────────

find_hwmon() {
    local target="$1"
    for h in /sys/class/hwmon/hwmon*/; do
        [[ "$(cat "$h/name" 2>/dev/null)" == "$target" ]] && printf '%s' "${h%/}" && return 0
    done
    return 1
}

check_root() {
    [ "$EUID" -eq 0 ] || { echo "ERROR: run as root (sudo bash install.sh)"; exit 1; }
}

# ── Start ──────────────────────────────────────────────────────────────────────

check_root

echo "=== 1. Build dependencies ==="
apt-get install -y build-essential fancontrol dkms

# Detect kernel headers package (PVE vs standard)
KVER=$(uname -r)
if apt-cache show "pve-headers-${KVER}" &>/dev/null; then
    apt-get install -y "pve-headers-${KVER}"
else
    apt-get install -y "linux-headers-${KVER}"
fi

echo ""
echo "=== 2. Build and install helper binary + library ==="
cd "$SCRIPT_DIR"
make helper
install --strip --owner=root --group=root --mode=755 qnap-ec /usr/local/sbin/qnap-ec
install --owner=root --group=root --mode=644 libuLinux_hal.so /usr/local/lib/libuLinux_hal.so
ldconfig
echo "  Installed: /usr/local/sbin/qnap-ec"
echo "  Installed: /usr/local/lib/libuLinux_hal.so"

echo ""
echo "=== 3. Set up DKMS (auto-rebuild on kernel updates) ==="
DKMS_SRC="/usr/src/qnap-ec-1.1.2"
mkdir -p "$DKMS_SRC"
cp "$SCRIPT_DIR"/{qnap-ec.c,qnap-ec-ioctl.h,Makefile,dkms.conf} "$DKMS_SRC/"
dkms remove qnap-ec/1.1.2 --all 2>/dev/null || true
dkms add qnap-ec/1.1.2
dkms build qnap-ec/1.1.2
dkms install qnap-ec/1.1.2
echo "  DKMS: qnap-ec 1.1.2 registered and installed"

echo ""
echo "=== 4. Autostart — adding qnap-ec to /etc/modules ==="
if grep -qx "qnap-ec" /etc/modules; then
    echo "  Already present in /etc/modules"
else
    echo "qnap-ec" >> /etc/modules
    echo "  Added qnap-ec to /etc/modules"
fi

echo ""
echo "=== 5. Module config (sim_pwm_enable) ==="
cp "$SCRIPT_DIR/qnap-ec.conf" /etc/modprobe.d/qnap-ec.conf
echo "  Saved: /etc/modprobe.d/qnap-ec.conf"

echo ""
echo "=== 6. Load module with sim_pwm_enable=yes ==="
modprobe -r qnap-ec 2>/dev/null || true
modprobe qnap-ec sim_pwm_enable=yes
sleep 1

echo ""
echo "=== 7. Detect hwmon device ==="
HW=$(find_hwmon "qnap_ec") || { echo "ERROR: qnap_ec hwmon not found — module failed to load?"; exit 1; }
echo "  Found: $HW  ($(cat "$HW/name"))"

echo ""
echo "=== 8. Verify PWM enable ==="
for pwm in pwm1_enable pwm7_enable; do
    val=$(cat "$HW/$pwm" 2>/dev/null || echo "MISSING")
    echo "  $pwm = $val"
done

echo ""
echo "=== 9. Install fancontrol config ==="
HW_NUM=${HW##*hwmon}
sed "s/hwmon19/hwmon${HW_NUM}/g" "$SCRIPT_DIR/fancontrol" > /etc/fancontrol
echo "  Saved: /etc/fancontrol (hwmon${HW_NUM})"

echo ""
echo "=== 10. Configure fancontrol restart policy ==="
mkdir -p /etc/systemd/system/fancontrol.service.d
cat > /etc/systemd/system/fancontrol.service.d/restart.conf <<'EOF'
[Service]
Restart=on-failure
RestartSec=10
EOF
systemctl daemon-reload
echo "  Configured: Restart=on-failure (RestartSec=10)"

echo ""
echo "=== 11. Enable and start fancontrol service ==="
systemctl enable fancontrol
systemctl restart fancontrol
sleep 2
systemctl status fancontrol --no-pager

echo ""
echo "=== 12. Install qnap-monitor ==="
install -o root -g root -m 755 "$SCRIPT_DIR/qnap-monitor" /usr/local/bin/qnap-monitor
echo "  Installed: /usr/local/bin/qnap-monitor"

echo ""
echo "=== 13. Verify fan readings ==="
for fan in fan1_input fan2_input fan3_input fan4_input fan7_input fan8_input; do
    f="$HW/$fan"
    [ -f "$f" ] || continue
    rpm=$(cat "$f")
    echo "  $fan: $rpm RPM"
done

echo ""
echo "=== Done ==="
echo "  Run 'qnap-monitor' to see live thermal dashboard."
echo "  After a kernel update: DKMS rebuilds the module automatically (no action needed)."
