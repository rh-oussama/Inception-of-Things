#!/bin/bash

echo "Starting K3s Server (Controller) installation..."

# Authorize the host's public SSH key for passwordless login
if [ -f /vagrant/host_key.pub ]; then
  mkdir -p /home/vagrant/.ssh
  cat /vagrant/host_key.pub >> /home/vagrant/.ssh/authorized_keys
  chown -R vagrant:vagrant /home/vagrant/.ssh
  chmod 700 /home/vagrant/.ssh
  chmod 600 /home/vagrant/.ssh/authorized_keys
fi


# Install K3s as a server, binding it to the specific IP from the project requirements


sudo fallocate -l 3G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile


sudo apt update
sudo apt install curl -y

export INSTALL_K3S_EXEC="server --bind-address=192.168.56.110 --node-ip=192.168.56.110 --disable traefik --disable servicelb --disable metrics-server --kubelet-arg=fail-swap-on=false --write-kubeconfig-mode 644"
curl -sfL https://get.k3s.io | sh -


# K3s takes a few seconds to start up and generate the node token.
echo "Waiting for K3s to initialize..."
sleep 15

# Copy the secret node token to the shared Vagrant folder so the Worker can find it
sudo cp /var/lib/rancher/k3s/server/node-token /vagrant/node-token

# Make kubectl accessible for the default vagrant test without needing 'sudo'
sudo chmod 644 /etc/rancher/k3s/k3s.yaml
echo 'export KUBECONFIG=/etc/rancher/k3s/k3s.yaml' >> /home/vagrant/.bashrc
echo 'alias k=kubectl' >> /home/vagrant/.bashrc

echo "K3s Server installation complete! Token shared."
