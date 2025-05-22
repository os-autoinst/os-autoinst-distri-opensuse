#!/bin/bash

set -xe

# Setting root passwd
echo "%TEST_PASSWORD%" | passwd root --stdin

# Enabling services
systemctl enable NetworkManager.service
systemctl enable systemd-sysext.service

# !! FOR QA ONLY !!

# Allow root ssh access (for testing purposes only!)
echo "PermitRootLogin yes" > /etc/ssh/sshd_config.d/root_access.conf
systemctl enable sshd

# Add kubectl access/command
ln -s /var/lib/rancher/rke2/bin/kubectl /root/bin/
echo "export KUBECONFIG=/etc/rancher/rke2/rke2.yaml" > /root/.profile

# !! CA CERTS WORKAROUND !!
# This should be done because "--installroot" option is used in zypper!
/sbin/update-ca-certificates
# !! CA CERTS WORKAROUND !!
