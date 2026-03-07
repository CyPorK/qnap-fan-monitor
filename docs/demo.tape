# VHS tape — qnap-monitor demo
# Usage: vhs docs/demo.tape
# Replace <pve-host> with actual host IP/hostname before running

Output docs/demo.gif

Set FontSize 13
Set Width 1200
Set Height 900
Set Theme "Catppuccin Mocha"
Set Framerate 15

# Connect silently (hide SSH command with IP from recording)
Hide
Type "ssh <pve-host> -t 'qnap-monitor 1'"
Enter
Sleep 4s
Show

# Show idle state (normal temps, normal RPM, no override)
Sleep 2s

# Start logging, then stress test
Type "l"
Sleep 0.3s
Type "s"

# Wait for CPU override to appear (~30s) — will be trimmed in post
Sleep 30s

# Stop stress — cooldown begins
Type "s"

# Cooldown: CPU override appears (~8s), then stabilizes (~3s)
Sleep 12s

# Stop logging — report appears automatically
Type "l"
Sleep 5s

# Replay report
Type "r"
Sleep 3s

# Quit
Type "q"
