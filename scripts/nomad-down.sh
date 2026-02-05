#!/usr/bin/env bash
set -uo pipefail

# Use the local project logs directory
LOG_DIR="$PWD/logs"

echo "=== Stopping Nomad Jobs ==="
# Attempt to stop jobs gracefully first
sudo nomad job stop -purge care-backend >/dev/null 2>&1 || true
sudo nomad job stop -purge care-redis >/dev/null 2>&1 || true
sudo nomad job stop -purge care-postgres >/dev/null 2>&1 || true

echo "=== Killing Agents (Nomad & Consul) ==="
sudo pkill -9 nomad || true
sudo pkill -9 consul || true

echo "=== Cleaning Up Local State ==="
# Remove PID and log files from the project folder
rm -f "$LOG_DIR"/*.pid
# Optional: remove logs as well, or keep them for history
# rm -f "$LOG_DIR"/*.log

echo "=== Resetting Network Interfaces ==="
# Cleanup the bridge interface if it's lingering
sudo ip link delete nomad >/dev/null 2>&1 || true

echo "✅ infrastructure is down."