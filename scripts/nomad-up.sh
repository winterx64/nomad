#!/usr/bin/env bash
set -euo pipefail

# Create a logs directory inside your project folder
LOG_DIR="$PWD/logs"
mkdir -p "$LOG_DIR"

NOMAD_CONFIG_DIR="/etc/nomad.d"
CONSUL_CONFIG_DIR="/etc/consul.d"

echo "=== Ensuring Kernel Modules ==="
sudo modprobe bridge
sudo modprobe br_netfilter

echo "=== Hard stopping existing Nomad / Consul ==="
sudo pkill -9 nomad || true
sudo pkill -9 consul || true
sleep 2

echo "=== Starting Consul ==="
# We use sudo here so it has permission to write logs in your project folder
sudo consul agent -config-dir="$CONSUL_CONFIG_DIR" > "$LOG_DIR/consul.log" 2>&1 &
echo $! > "$LOG_DIR/consul.pid"

echo "Waiting for Consul leader..."
for i in {1..30}; do
  if curl -s http://127.0.0.1:8500/v1/status/leader | grep -qE '^"[^"]+"$'; then
    echo "✅ Consul is ready"
    break
  fi
  echo "Waiting... ($i/30)"
  sleep 2
done

echo "=== Starting Nomad (root) ==="
sudo nomad agent -config="$NOMAD_CONFIG_DIR" > "$LOG_DIR/nomad.log" 2>&1 &
echo $! > "$LOG_DIR/nomad.pid"

echo "Waiting for Nomad to be ready..."
for i in {1..30}; do
  if sudo nomad node status -self >/dev/null 2>&1; then
    echo "✅ Nomad is ready"
    break
  fi
  echo "Waiting for Nomad... ($i/30)"
  sleep 2
done

echo "Waiting for Docker driver..."
sleep 5

echo "=== Deploying Jobs ==="
sudo nomad job run nomad/postgres.nomad
sudo nomad job run nomad/redis.nomad
sudo nomad job run nomad/backend.nomad

echo "=== Deployment complete ==="