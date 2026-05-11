#!/bin/bash
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive

# OCI fires cloud-init before internet routing is established — wait for
# actual IPv4 HTTP connectivity rather than relying on DNS resolution alone
echo "NOTE: Waiting for network connectivity..."
until curl -4 -sf --max-time 5 http://us.archive.ubuntu.com/ubuntu/ > /dev/null 2>&1; do
  echo "NOTE: Network not ready, retrying in 5 seconds..."
  sleep 5
done
echo "NOTE: Network ready."

# OCI images ship with a region mirror that resolves IPv6-only; rewrite to
# us.archive.ubuntu.com to force IPv4 and avoid DDoS-affected mirrors
echo "NOTE: Replacing apt sources with us.archive.ubuntu.com..."
sudo tee /etc/apt/sources.list.d/ubuntu.sources > /dev/null << 'EOF'
Types: deb
URIs: http://us.archive.ubuntu.com/ubuntu
Suites: noble noble-updates noble-backports
Components: main restricted universe multiverse
Signed-By: /usr/share/keyrings/ubuntu-archive-keyring.gpg

Types: deb
URIs: http://us.archive.ubuntu.com/ubuntu
Suites: noble-security
Components: main restricted universe multiverse
Signed-By: /usr/share/keyrings/ubuntu-archive-keyring.gpg
EOF

echo "NOTE: Running apt-get update..."
sudo apt-get -o Acquire::ForceIPv4=true update -y

echo "NOTE: Installing apache2..."
sudo DEBIAN_FRONTEND=noninteractive apt-get -o Acquire::ForceIPv4=true install -y apache2

echo "NOTE: Enabling and starting apache2..."
sudo systemctl enable apache2
sudo systemctl start apache2

# Copy prebuilt game assets staged by the file provisioner
sudo cp /tmp/html/* /var/www/html/

# OCI Ubuntu images block all ports via iptables by default —
# the Security List alone is not sufficient for inbound traffic
echo "NOTE: Opening port 80 in host firewall..."
sudo iptables -I INPUT -p tcp --dport 80 -j ACCEPT

echo "NOTE: Done."
