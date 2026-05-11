#!/bin/bash

# OCI fires cloud-init before internet routing is established — wait for
# actual IPv4 connectivity before attempting any network operations
echo "NOTE: Waiting for network..."
until curl -4 -sf --max-time 5 http://us.archive.ubuntu.com/ubuntu/ > /dev/null 2>&1; do
  sleep 5
done

# OCI Ubuntu images block all ports via iptables by default —
# the Security List alone is not sufficient for inbound traffic
iptables -I INPUT -p tcp --dport 80 -j ACCEPT

# Enable SSH password authentication for the packer user created at image build
sed -i 's/^PasswordAuthentication no/PasswordAuthentication yes/' \
  /etc/ssh/sshd_config.d/60-cloudimg-settings.conf
systemctl restart sshd

echo "The image name is ${ami_name}."
