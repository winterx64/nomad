#!/usr/bin/env bash
set -euo pipefail

# Configuration
LOG_DIR="${LOG_DIR:-$PWD/logs}"
NOMAD_ADDR="${NOMAD_ADDR:-127.0.0.1:4646}"
CONSUL_ADDR="${CONSUL_ADDR:-127.0.0.1:8500}"
GRACE_PERIOD=30
FORCE_TIMEOUT=10

# Job definitions
JOBS=("care-postgres" "care-redis" "care-backend")

# Logging function
log() {
  local level=$1
  shift
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $@"
}

# Cleanup function
cleanup() {
  local exit_code=$?
  if [ $exit_code -ne 0 ]; then
    log "WARN" "Shutdown completed with warnings (exit code: $exit_code)"
  fi
  exit $exit_code
}
trap cleanup EXIT

log "INFO" "=== Starting Graceful Shutdown ==="

log "INFO" "=== Stopping Nomad Jobs (grace period: ${GRACE_PERIOD}s) ==="
for job in "${JOBS[@]}"; do
  if sudo nomad job status "$job" >/dev/null 2>&1; then
    log "INFO" "Stopping job: $job"
    sudo nomad job stop -purge "$job" > "$LOG_DIR/${job}-stop.log" 2>&1 || log "WARN" "Failed to stop job: $job"
  else
    log "INFO" "Job not found: $job (skipping)"
  fi
done

log "INFO" "Waiting for jobs to stop (${GRACE_PERIOD}s)..."
sleep $GRACE_PERIOD

log "INFO" "=== Stopping Agents ==="

# Stop Nomad gracefully first
if sudo pgrep -f 'nomad agent' >/dev/null 2>&1; then
  log "INFO" "Sending SIGTERM to Nomad..."
  sudo pkill -SIGTERM nomad || true
  
  log "INFO" "Waiting for Nomad to gracefully shutdown (${FORCE_TIMEOUT}s)..."
  for i in $(seq 1 $FORCE_TIMEOUT); do
    if ! sudo pgrep -f 'nomad agent' >/dev/null 2>&1; then
      log "INFO" "✅ Nomad stopped gracefully"
      break
    fi
    if [ $i -eq $FORCE_TIMEOUT ]; then
      log "WARN" "Nomad did not stop gracefully, forcing shutdown"
      sudo pkill -9 nomad || true
    else
      echo -n "."
      sleep 1
    fi
  done
  echo ""
else
  log "INFO" "Nomad is not running"
fi

# Stop Consul gracefully
if sudo pgrep -f 'consul agent' >/dev/null 2>&1; then
  log "INFO" "Sending SIGTERM to Consul..."
  sudo pkill -SIGTERM consul || true
  
  log "INFO" "Waiting for Consul to gracefully shutdown (${FORCE_TIMEOUT}s)..."
  for i in $(seq 1 $FORCE_TIMEOUT); do
    if ! sudo pgrep -f 'consul agent' >/dev/null 2>&1; then
      log "INFO" "✅ Consul stopped gracefully"
      break
    fi
    if [ $i -eq $FORCE_TIMEOUT ]; then
      log "WARN" "Consul did not stop gracefully, forcing shutdown"
      sudo pkill -9 consul || true
    else
      echo -n "."
      sleep 1
    fi
  done
  echo ""
else
  log "INFO" "Consul is not running"
fi

log "INFO" "=== Cleaning Up Local State ==="
if [ -d "$LOG_DIR" ]; then
  # Archive logs with timestamp
  TIMESTAMP=$(date +%Y%m%d_%H%M%S)
  ARCHIVE_DIR="$LOG_DIR/archive_$TIMESTAMP"
  
  if [ -f "$LOG_DIR/consul.pid" ] || [ -f "$LOG_DIR/nomad.pid" ]; then
    log "INFO" "Archiving old logs to $ARCHIVE_DIR"
    mkdir -p "$ARCHIVE_DIR"
    mv "$LOG_DIR"/*.pid "$ARCHIVE_DIR/" 2>/dev/null || true
    mv "$LOG_DIR"/*.log "$ARCHIVE_DIR/" 2>/dev/null || true
    mv "$LOG_DIR"/*-stop.log "$ARCHIVE_DIR/" 2>/dev/null || true
    mv "$LOG_DIR"/*-deploy.log "$ARCHIVE_DIR/" 2>/dev/null || true
  fi
else
  log "WARN" "Log directory not found: $LOG_DIR"
fi

log "INFO" "=== Cleaning Up Docker Containers ==="
# Stop and remove Nomad-managed containers only (identified by Nomad allocation ID pattern)
# Nomad containers have UUIDs (allocation IDs) in their names: <task>-<allocation_uuid>
# We only remove containers from the 3 care services managed by Nomad
log "INFO" "Stopping Nomad-managed application containers (care-backend, care-postgres, care-redis)..."
sudo docker ps -a --format "{{.Names}}" | grep -E '^(api|redis|postgres)-[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' | while read container; do
  log "INFO" "Stopping and removing: $container"
  sudo docker stop "$container" 2>/dev/null || true
  sudo docker rm -f "$container" 2>/dev/null || true
done

# Stop and remove Nomad infrastructure containers (pause containers used for network namespaces)
log "INFO" "Removing Nomad infrastructure containers..."
PAUSE_CONTAINERS=$(sudo docker ps -a --filter "ancestor=registry.k8s.io/pause-amd64:3.3" --format "{{.Names}}" 2>/dev/null | grep -E '^nomad_init' || echo "")
if [ -n "$PAUSE_CONTAINERS" ]; then
  echo "$PAUSE_CONTAINERS" | xargs -r sudo docker rm -f 2>/dev/null || log "WARN" "Some Nomad infrastructure containers failed to remove"
fi

log "INFO" "=== Cleaning Up Network Interfaces ==="
# Cleanup lingering bridge interfaces
if sudo ip link show nomad >/dev/null 2>&1; then
  log "INFO" "Removing nomad bridge interface"
  sudo ip link delete nomad || log "WARN" "Failed to delete nomad bridge"
fi

# Clean up any lingering container networks
sudo docker network prune -f --filter 'until=24h' >/dev/null 2>&1 || log "WARN" "Docker network cleanup failed"

log "INFO" "=== ✅ Graceful Shutdown Complete ==="
log "INFO" "State files archived in: $LOG_DIR"