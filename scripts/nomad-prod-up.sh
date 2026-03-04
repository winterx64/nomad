#!/usr/bin/env bash
set -euo pipefail

echo "Stopping existing agents..."
pkill consul || true
pkill nomad || true
sleep 2

echo "Starting Consul..."

consul agent -config-dir=/etc/consul.d > consul.log 2>&1 &
echo $! > consul.pid

echo "Waiting for Consul..."
for i in {1..30}; do
  curl -s http://127.0.0.1:8500/v1/status/leader | grep -q '"' && break
  sleep 1
done

echo "Consul ready."

echo "Starting Nomad..."

nomad agent -config=/etc/nomad.d > nomad.log 2>&1 &
echo $! > nomad.pid

echo "Waiting for Nomad..."
for i in {1..30}; do
  nomad node status >/dev/null 2>&1 && break
  sleep 1
done

echo "Nomad ready."

echo "Deploying Postgres..."
nomad job run jobs/postgres.nomad.hcl

echo "Deploying Redis..."
nomad job run jobs/redis.nomad.hcl

echo "Deploying Care API..."
nomad job run jobs/backend.nomad.hcl

echo "Deployment complete."
