#!/bin/bash

echo "Starting K3s Worker (Agent) installation..."

# Authorize the host's public SSH key for passwordless login
if [ -f /vagrant/host_key.pub ]; then
  mkdir -p /home/vagrant/.ssh
  cat /vagrant/host_key.pub >> /home/vagrant/.ssh/authorized_keys
  chown -R vagrant:vagrant /home/vagrant/.ssh
  chmod 700 /home/vagrant/.ssh
  chmod 600 /home/vagrant/.ssh/authorized_keys
fi


# Wait in a loop until the Server finishes booting and writes the token to the shared folder
echo "Waiting for the Server to provide the node token..."
while [ ! -f /vagrant/node-token ]; do
  sleep 2
done

echo "Token found! Joining the cluster..."

# Read the token and define the Server's URL
export K3S_TOKEN=$(cat /vagrant/node-token)
export K3S_URL=https://192.168.56.110:6443

# Install K3s in agent mode, assigning its specific IP


sudo fallocate -l 2G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile


sudo apt update
sudo apt install curl -y

curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="--node-ip=192.168.56.111 --kubelet-arg=fail-swap-on=false" sh -

echo "K3s Worker installation complete! Joined the cluster."
