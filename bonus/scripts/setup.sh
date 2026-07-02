#!/bin/bash

set -euo pipefail

if [ "$EUID" -ne 0 ]; then
  echo "Error: Please run this script as root (using sudo)."
  exit 1
fi



install() {
    # ──────────────── DOCKER + K3D + KUBECTL + CLUSTER ────────────────
    if ! kubectl get nodes | grep -q " Ready "; then
      chmod +x ./deps.sh
      ./deps.sh
      echo "Dependencies installed successfully + K3D cluster set up."
    else
      echo "Dependencies already installed — skipping."
    fi

    # ──────────────── deploy Argo CD ────────────────
    if ! kubectl get namespace argocd &> /dev/null || \
          kubectl get pods -n argocd --no-headers 2>/dev/null | grep -q "0/"; then
      chmod +x ./argocd.sh
      ./argocd.sh
      echo "Argo CD deployed successfully."
    else
      echo "Argo CD is already deployed. — skipping."
    fi

    # ──────────────── deploy GitLab ────────────────
    if ! kubectl get namespace gitlab &> /dev/null || \
          kubectl get pods -n gitlab --no-headers 2>/dev/null | grep -q "0/"; then
      chmod +x ./gitlab.sh
      ./gitlab.sh
      echo "GitLab deployed successfully."
    else
      echo "GitLab is already deployed. — skipping."
    fi
   

    # ──────────────── INFO ────────────────
    clear
    print_info

}

uninstall() {
    
    # ──────────────── K3D ────────────────
    echo "[k3d] uninstalling..."
    if command -v k3d &>/dev/null; then
        k3d cluster delete iot-cluster 2>/dev/null || true
        rm -rf ~/.k3d 2>/dev/null || true
        rm -f /usr/local/bin/k3d 2>/dev/null || true
    fi
    echo "[k3d] uninstall done."
    
    # ──────────────── DOCKER ────────────────
    echo "[docker] uninstalling..."
    if command -v docker &>/dev/null; then
        docker volume prune -f
        systemctl stop docker docker.socket containerd 2>/dev/null || true
        apt remove --purge -y docker-ce docker-ce-cli containerd.io \
            docker-buildx-plugin docker-compose-plugin docker-ce-rootless-extras 2>/dev/null || true
        apt autoremove -y 2>/dev/null || true
        rm -rf /var/lib/docker /var/lib/containerd /etc/docker \
            /etc/apt/sources.list.d/docker* /etc/apt/keyrings/docker* 2>/dev/null || true
        groupdel docker 2>/dev/null || true
    fi
    echo "[docker] uninstall done."


    # ──────────────── KUBECTL ────────────────
    echo "[kubectl] uninstalling..."
    if command -v kubectl &>/dev/null; then
        rm -f /usr/local/bin/kubectl 2>/dev/null || true
    fi
    echo "[kubectl] uninstall done."
}


print_info() {
  local C="\033[0;36m" B="\033[0;34m" Y="\033[0;33m"
  local DIM="\033[2m" R="\033[0m"
  echo ""
  echo -e "${C}┌─[ ArgoCD ]────────────────────────────────────${R}"
  printf "  ${DIM}%-12s${R}  →  ${B}%s${R}\n" "url" "http://argocd.local"
  printf "  ${DIM}%-12s${R}  →  ${Y}%s${R}\n" "testname"  "admin"
  printf "  ${DIM}%-12s${R}  →  ${Y}%s${R}\n" "password"  "admin"

  echo ""
  echo -e "${C}├─[ GitLab ]────────────────────────────────────${R}"
  printf "  ${DIM}%-12s${R}  →  ${B}%s${R}\n" "url"       "http://gitlab.local"
  printf "  ${DIM}%-12s${R}  →  ${Y}%s${R}\n" "testname"  "root"
  printf "  ${DIM}%-12s${R}  →  ${Y}%s${R}\n" "password"  '0x%Qx[$71wb_'

  echo ""
  echo -e "${C}├─[ App ]───────────────────────────────────────${R}"
  printf "  ${DIM}%-12s${R}  →  ${B}%s${R}\n" "url"       "http://app.local"
  printf "  ${DIM}%-12s${R}  →  ${R}%s${R}\n" "curl"       "curl http://app.local"
  echo -e ""
  echo -e ""
  
}

case "${1:-}" in
  install|i)
    install
    ;;
  uninstall|u)
    uninstall
    ;;
  *)
    echo "Usage: $0 {install|uninstall|i|u}"
    echo "Example: ./deps.sh install"
    exit 1
    ;;
esac
