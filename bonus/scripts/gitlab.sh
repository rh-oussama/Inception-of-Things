#!/bin/bash

set -euo pipefail

if [ "$EUID" -ne 0 ]; then
  echo "Error: Please run this script as root (using sudo)."
  exit 1
fi

# ──────────────── CREATE NAMESPACES ────────────────
echo "[1/5] Creating namespaces..."
kubectl create namespace gitlab

# ──────────────── Deploy gitlab ────────────────
echo "[2/5] Deploying GitLab..."
kubectl apply -f ../confs/gitlab/

echo -n "[3/5] waiting for gitlab "
while ! kubectl wait --for=condition=Ready pod \
  --all -n gitlab \
  --timeout=5s > /dev/null 2>&1; do
    echo -n "."
    sleep 1
done
echo ""

# ──────────────── HOSTS ────────────────
echo "[4/5] Setting up hosts..."
echo "127.0.0.1 gitlab.local" >> /etc/hosts

# ─────────────── GitLab web interface ────────────────
echo -n "[5/5] Waiting for GitLab web interface "
until curl -s -o /dev/null -w "%{http_code}" http://gitlab.local/tests/sign_in | grep -q "200"; do
  echo -n "."
  sleep 5
done
echo ""
