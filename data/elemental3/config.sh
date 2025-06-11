#!/bin/bash

set -xe

# Disable Grub timeout
grub2-editenv /boot/grubenv set timeout=-1

# Setting root passwd
echo "%TEST_PASSWORD%" | passwd root --stdin

# Allow root ssh access (for testing purposes only!)
echo "PermitRootLogin yes" > /etc/ssh/sshd_config.d/root_access.conf
systemctl enable sshd

# Add kubectl access/command
ln -s /var/lib/rancher/rke2/bin/kubectl /root/bin/
echo "export KUBECONFIG=/etc/rancher/rke2/rke2.yaml" > /root/.profile
