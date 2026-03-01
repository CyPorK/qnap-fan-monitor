#!/bin/bash
# Full uninstall: qnap-ec driver + fancontrol + qnap-monitor
# Run as: sudo bash uninstall.sh  (from repo root)

set -e

check_root() {
    [ "$EUID" -eq 0 ] || { echo "ERROR: run as root (sudo bash uninstall.sh)"; exit 1; }
}

check_root

echo "=== 1. Stop and disable fancontrol ==="
if systemctl is-active --quiet fancontrol; then
    systemctl stop fancontrol
    echo "  Stopped fancontrol"
else
    echo "  fancontrol already stopped"
fi
if systemctl is-enabled --quiet fancontrol 2>/dev/null; then
    systemctl disable fancontrol
    echo "  Disabled fancontrol autostart"
else
    echo "  fancontrol autostart already disabled"
fi

echo ""
echo "=== 2. Unload kernel module ==="
if lsmod | grep -q "^qnap_ec"; then
    modprobe -r qnap-ec
    echo "  Module unloaded"
else
    echo "  Module not loaded"
fi

echo ""
echo "=== 3. Remove DKMS module ==="
if dkms status qnap-ec/1.1.2 2>/dev/null | grep -q "qnap-ec"; then
    dkms remove qnap-ec/1.1.2 --all
    echo "  DKMS: qnap-ec 1.1.2 removed from all kernels"
else
    echo "  DKMS: qnap-ec not registered"
fi

echo ""
echo "=== 4. Remove DKMS source ==="
if [ -d /usr/src/qnap-ec-1.1.2 ]; then
    rm -rf /usr/src/qnap-ec-1.1.2
    echo "  Removed: /usr/src/qnap-ec-1.1.2"
else
    echo "  Already absent: /usr/src/qnap-ec-1.1.2"
fi

echo ""
echo "=== 5. Remove helper binary and library ==="
remove_file() {
    if [ -f "$1" ]; then rm -f "$1" && echo "  Removed: $1"; else echo "  Already absent: $1"; fi
}
remove_file /usr/local/sbin/qnap-ec
remove_file /usr/local/lib/libuLinux_hal.so
ldconfig

echo ""
echo "=== 6. Remove module from /etc/modules ==="
if grep -qx "qnap-ec" /etc/modules; then
    sed -i '/^qnap-ec$/d' /etc/modules
    echo "  Removed qnap-ec from /etc/modules"
else
    echo "  Already absent from /etc/modules"
fi

echo ""
echo "=== 7. Remove fancontrol systemd override ==="
remove_file /etc/systemd/system/fancontrol.service.d/restart.conf
rmdir --ignore-fail-on-non-empty /etc/systemd/system/fancontrol.service.d 2>/dev/null || true
systemctl daemon-reload

echo ""
echo "=== 8. Remove config files ==="
remove_file /etc/fancontrol
remove_file /etc/modprobe.d/qnap-ec.conf

echo ""
echo "=== 9. Remove qnap-monitor ==="
remove_file /usr/local/bin/qnap-monitor

echo ""
echo "=== Done ==="
echo "  All qnap-ec-fan-monitor components have been removed."
