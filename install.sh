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
apt-get install -y build-essential fancontrol

# Detect kernel headers package (PVE vs standard)
KVER=$(uname -r)
if apt-cache show "pve-headers-${KVER}" &>/dev/null; then
    apt-get install -y "pve-headers-${KVER}"
else
    apt-get install -y "linux-headers-${KVER}"
fi

echo ""
echo "=== 2. Build and install qnap-ec kernel module ==="
cd "$SCRIPT_DIR"
make install
echo "Installed: qnap-ec.ko"

echo ""
echo "=== 3. Autostart — adding qnap-ec to /etc/modules ==="
if grep -qx "qnap-ec" /etc/modules; then
    echo "  Already present in /etc/modules"
else
    echo "qnap-ec" >> /etc/modules
    echo "  Added qnap-ec to /etc/modules"
fi

echo ""
echo "=== 4. Module config (sim_pwm_enable) ==="
cp "$SCRIPT_DIR/qnap-ec.conf" /etc/modprobe.d/qnap-ec.conf
echo "  Saved: /etc/modprobe.d/qnap-ec.conf"

echo ""
echo "=== 5. Load module with sim_pwm_enable=yes ==="
modprobe -r qnap-ec 2>/dev/null || true
modprobe qnap-ec sim_pwm_enable=yes
sleep 1

echo ""
echo "=== 6. Detect hwmon device ==="
HW=$(find_hwmon "qnap_ec") || { echo "ERROR: qnap_ec hwmon not found — module failed to load?"; exit 1; }
echo "  Found: $HW  ($(cat "$HW/name"))"

echo ""
echo "=== 7. Verify PWM enable ==="
for pwm in pwm1_enable pwm7_enable; do
    val=$(cat "$HW/$pwm" 2>/dev/null || echo "MISSING")
    echo "  $pwm = $val"
done

echo ""
echo "=== 8. Install fancontrol config ==="
cp "$SCRIPT_DIR/fancontrol" /etc/fancontrol
echo "  Saved: /etc/fancontrol"

echo ""
echo "=== 9. Enable and start fancontrol service ==="
systemctl enable fancontrol
systemctl restart fancontrol
sleep 2
systemctl status fancontrol --no-pager

echo ""
echo "=== 10. Install qnap-monitor ==="
install -o root -g root -m 755 "$SCRIPT_DIR/qnap-monitor" /usr/local/bin/qnap-monitor
echo "  Installed: /usr/local/bin/qnap-monitor"

echo ""
echo "=== 11. Verify fan readings ==="
for fan in fan1_input fan2_input fan3_input fan4_input fan7_input fan8_input; do
    f="$HW/$fan"
    [ -f "$f" ] || continue
    rpm=$(cat "$f")
    echo "  $fan: $rpm RPM"
done

echo ""
echo "=== Done ==="
echo "  Run 'qnap-monitor' to see live thermal dashboard."
echo "  After a kernel update: cd $SCRIPT_DIR && sudo make install && sudo systemctl restart fancontrol"
