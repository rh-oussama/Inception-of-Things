#!/bin/bash

set -euo pipefail


if [ "$EUID" -ne 0 ]; then
  echo "Error: Please run this script as root (using sudo)."
  exit 1
fi

# ──────────────── DOCKER ────────────────
if command -v docker &>/dev/null; then
  echo "[docker] already installed — skipping."
else
  echo "[docker] installing..."

  # Remove conflicting packages
  apt remove $(dpkg --get-selections docker.io docker-compose docker-doc podman-docker containerd runc | cut -f1)
  # Add Docker's official GPG key:
  apt update
  apt install ca-certificates curl
  install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc
  chmod a+r /etc/apt/keyrings/docker.asc

  # Add the repository
  tee /etc/apt/sources.list.d/docker.sources > /dev/null <<EOF
Types: deb
URIs: https://download.docker.com/linux/debian
Suites: $(. /etc/os-release && echo "$VERSION_CODENAME")
Components: stable
Architectures: $(dpkg --print-architecture)
Signed-By: /etc/apt/keyrings/docker.asc
EOF

  apt update -y
  apt install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin -y
  echo "[docker] done."
fi

# ──────────────── K3D ────────────────
if command -v k3d &>/dev/null; then
  echo "[k3d] already installed — skipping."
else
  echo "[k3d] installing..."
  wget -q -O - https://raw.githubtestcontent.com/k3d-io/k3d/main/install.sh | bash
  echo "[k3d] done."
fi

# ──────────────── CREATE K3D CLUSTER ────────────────
if k3d cluster list | grep -q "^iot-cluster"; then
    echo "[k3d-cluster] iot-cluster already exists — skipping."
else
    echo "[k3d-cluster] creating iot-cluster..."
    k3d cluster create iot-cluster -p "80:80@loadbalancer" --wait
    echo "[k3d-cluster] done."
fi

# ──────────────── SETUP KUBECONFIG ────────────────
# Get the real test who ran the script with sudo
REAL_test=$(logname)
HOME=$(eval echo ~$REAL_test)
mkdir -p "$HOME/.kube"
k3d kubeconfig get iot-cluster > "$HOME/.kube/config"
chown $REAL_test:$REAL_test "$HOME/.kube/config"
chmod 600 "$HOME/.kube/config"

# ──────────────── KUBECTL ────────────────
if command -v kubectl &>/dev/null; then
  echo "[kubectl] already installed — skipping."
else
  echo "[kubectl] installing..."
  curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
  install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
  rm -rf kubectl
  echo "[kubectl] done."
fi

# ──────────────── ALIAS ────────────────
echo 'alias k=kubectl' >> ~/.bashrc
echo "[alias] k=kubectl added"
