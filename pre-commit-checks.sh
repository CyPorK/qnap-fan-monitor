#!/bin/bash
# Project-specific pre-commit checks for qnap-ec-fan-monitor.
# Called automatically by the global pre-commit hook if this file exists.

ERRORS=0

# ── Version consistency ────────────────────────────────────────────────────────
# Source of truth: dkms.conf — install.sh and uninstall.sh must match.

VER=$(grep 'PACKAGE_VERSION=' dkms.conf | cut -d'"' -f2)

if [ -z "$VER" ]; then
    echo "  [pre-commit-checks] ERROR: could not read PACKAGE_VERSION from dkms.conf"
    ERRORS=1
else
    if ! grep -q "qnap-ec/${VER}" install.sh; then
        echo "  [pre-commit-checks] Version mismatch: install.sh does not reference qnap-ec/${VER}"
        echo "    Update install.sh to match PACKAGE_VERSION in dkms.conf"
        ERRORS=1
    fi
    if ! grep -q "qnap-ec/${VER}" uninstall.sh; then
        echo "  [pre-commit-checks] Version mismatch: uninstall.sh does not reference qnap-ec/${VER}"
        echo "    Update uninstall.sh to match PACKAGE_VERSION in dkms.conf"
        ERRORS=1
    fi
fi

# ── Result ─────────────────────────────────────────────────────────────────────
exit "$ERRORS"
