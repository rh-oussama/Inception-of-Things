#!/bin/bash

set -euo pipefail

if [ "$EUID" -ne 0 ]; then
  echo "Error: Please run this script as root (using sudo)."
  exit 1
fi

# ──────────────── NAMESPACES ────────────────

echo "[1/7] Creating namespaces..."
kubectl create namespace argocd
kubectl create namespace dev


# ──────────────── INSTALL ARGO CD ────────────────
echo "[2/7] Applying Argo CD manifest..."
kubectl apply -n argocd --server-side --force-conflicts -f https://raw.githubtestcontent.com/argoproj/argo-cd/stable/manifests/install.yaml

echo -n "[3/7] Waiting for Argo CD deployment "
while ! kubectl wait --for=condition=Available deployment/argocd-server \
        -n argocd --timeout=3s > /dev/null 2>&1; do
    echo -n "."
done
echo ""

# ──────────────── DISABLE TLS ────────────────
echo "[4/7] Disabling TLS for Argo CD..."

kubectl apply -n argocd -f - <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-cmd-params-cm
  namespace: argocd
data:
  server.insecure: "true"
EOF
kubectl rollout restart deployment argocd-server -n argocd
kubectl wait --for=condition=Available deployment/argocd-server -n argocd --timeout=2m

# ──────────────── CHANGE ARGO CD ADMIN PASSWORD ────────────────
# bcrypt(admin) = $2a$12$2mdC1Q5cNCED9N1m78lWKe.QolMUgDyGWX0s60ti8.dJzXCOOX44m
kubectl -n argocd patch secret argocd-secret \
  -p '{"stringData": {
    "admin.password": "$2a$12$2mdC1Q5cNCED9N1m78lWKe.QolMUgDyGWX0s60ti8.dJzXCOOX44m",
    "admin.passwordMtime": "'$(date +%FT%T%Z)'"
  }}'

# ──────────────── DEPLOY APP ────────────────
echo "[5/7] Deploying argocd manifests..."
kubectl apply -f ../confs/argocd/

# ──────────────── SETUP HOSTS ────────────────
echo "[6/7] Setting up hosts..."
echo "127.0.0.1 argocd.local" >> /etc/hosts
echo "127.0.0.1 app.local" >> /etc/hosts

# ──────────────── WAIT FOR ARGO CD WEB INTERFACE ────────────────
echo -n "[7/7] Waiting for Argo CD web interface "
until curl -s -o /dev/null -w "%{http_code}" http://argocd.local/healthz | grep -q "200"; do
  echo -n "."
  sleep 5
done
echo ""
