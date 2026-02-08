#!/usr/bin/env bash
set -euo pipefail

# Configuration
LOG_DIR="${LOG_DIR:-$PWD/logs}"
NOMAD_CONFIG_DIR="${NOMAD_CONFIG_DIR:-/etc/nomad.d}"
CONSUL_CONFIG_DIR="${CONSUL_CONFIG_DIR:-/etc/consul.d}"
CONSUL_ADDR="${CONSUL_ADDR:-127.0.0.1:8500}"
NOMAD_ADDR="${NOMAD_ADDR:-127.0.0.1:4646}"
TIMEOUT_CONSUL=60
TIMEOUT_NOMAD=60
TIMEOUT_JOBS=120

# Job definitions
JOBS=("nomad/postgres.nomad" "nomad/redis.nomad" "nomad/backend.nomad")

mkdir -p "$LOG_DIR"

# Cleanup function
cleanup() {
  local exit_code=$?
  if [ $exit_code -ne 0 ]; then
    echo "❌ Deployment failed with exit code $exit_code"
    echo "Check logs in: $LOG_DIR"
  fi
  exit $exit_code
}
trap cleanup EXIT

# Logging function
log() {
  local level=$1
  shift
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $@"
}

log "INFO" "=== Ensuring Kernel Modules ==="
sudo modprobe bridge || log "WARN" "Failed to load bridge module"
sudo modprobe br_netfilter || log "WARN" "Failed to load br_netfilter module"

log "INFO" "=== Stopping existing Nomad / Consul services ==="
if sudo pgrep -f 'nomad agent' >/dev/null 2>&1; then
  log "INFO" "Stopping Nomad gracefully..."
  sudo pkill -SIGTERM nomad || true
  sleep 3
  sudo pkill -9 nomad || true
fi

if sudo pgrep -f 'consul agent' >/dev/null 2>&1; then
  log "INFO" "Stopping Consul gracefully..."
  sudo pkill -SIGTERM consul || true
  sleep 3
  sudo pkill -9 consul || true
fi

sleep 2

log "INFO" "=== Starting Consul ==="
if [ ! -d "$CONSUL_CONFIG_DIR" ]; then
  log "ERROR" "Consul config directory not found: $CONSUL_CONFIG_DIR"
  exit 1
fi

sudo consul agent -config-dir="$CONSUL_CONFIG_DIR" > "$LOG_DIR/consul.log" 2>&1 &
echo $! > "$LOG_DIR/consul.pid"
log "INFO" "Consul started (PID: $(cat $LOG_DIR/consul.pid))"

log "INFO" "Waiting for Consul leader (timeout: ${TIMEOUT_CONSUL}s)..."
for i in $(seq 1 $TIMEOUT_CONSUL); do
  if curl -sf "http://$CONSUL_ADDR/v1/status/leader" 2>/dev/null | grep -qE '^"[^"]+"$'; then
    log "INFO" "✅ Consul is ready"
    break
  fi
  if [ $i -eq $TIMEOUT_CONSUL ]; then
    log "ERROR" "Consul failed to start within timeout"
    exit 1
  fi
  echo -n "."
  sleep 1
done
echo ""

log "INFO" "=== Starting Nomad ==="
if [ ! -d "$NOMAD_CONFIG_DIR" ]; then
  log "ERROR" "Nomad config directory not found: $NOMAD_CONFIG_DIR"
  exit 1
fi

sudo nomad agent -config="$NOMAD_CONFIG_DIR" > "$LOG_DIR/nomad.log" 2>&1 &
echo $! > "$LOG_DIR/nomad.pid"
log "INFO" "Nomad started (PID: $(cat $LOG_DIR/nomad.pid))"

log "INFO" "Waiting for Nomad to be ready (timeout: ${TIMEOUT_NOMAD}s)..."
for i in $(seq 1 $TIMEOUT_NOMAD); do
  if sudo nomad node status -self >/dev/null 2>&1; then
    log "INFO" "✅ Nomad is ready"
    break
  fi
  if [ $i -eq $TIMEOUT_NOMAD ]; then
    log "ERROR" "Nomad failed to start within timeout"
    exit 1
  fi
  echo -n "."
  sleep 1
done
echo ""

log "INFO" "Waiting for Docker driver to be available..."
sleep 5

log "INFO" "=== Deploying Jobs ==="
for job_file in "${JOBS[@]}"; do
  if [ ! -f "$job_file" ]; then
    log "ERROR" "Job file not found: $job_file"
    exit 1
  fi
  job_name=$(grep -m1 '^job "' "$job_file" | sed 's/job "\([^"]*\)".*/\1/')
  log "INFO" "Deploying job: $job_name from $job_file"
  if ! sudo nomad job run "$job_file" > "$LOG_DIR/${job_name}-deploy.log" 2>&1; then
    log "ERROR" "Failed to deploy $job_name"
    exit 1
  fi
done

log "INFO" "Waiting for jobs to stabilize (timeout: ${TIMEOUT_JOBS}s)..."
for i in $(seq 1 $TIMEOUT_JOBS); do
  all_ready=true
  for job_file in "${JOBS[@]}"; do
    job_name=$(grep -m1 '^job "' "$job_file" | sed 's/job "\([^"]*\)".*/\1/')
    status=$(sudo nomad job status "$job_name" 2>/dev/null | grep -E '^Status' | awk '{print $NF}' || echo "unknown")
    if [ "$status" != "running" ]; then
      all_ready=false
      break
    fi
  done
  
  if $all_ready; then
    log "INFO" "✅ All jobs are running"
    break
  fi
  
  if [ $i -eq $TIMEOUT_JOBS ]; then
    log "WARN" "Jobs did not stabilize within timeout"
    break
  fi
  echo -n "."
  sleep 1
done
echo ""

log "INFO" "=== Deployment Status ==="
for job_file in "${JOBS[@]}"; do
  job_name=$(grep -m1 '^job "' "$job_file" | sed 's/job "\([^"]*\)".*/\1/')
  sudo nomad job status "$job_name" || true
  echo ""
done

log "INFO" "=== ✅ Deployment Complete ==="
log "INFO" "Consul UI: http://$CONSUL_ADDR/ui"
log "INFO" "Nomad UI: http://$NOMAD_ADDR/ui"
log "INFO" "Logs directory: $LOG_DIR"