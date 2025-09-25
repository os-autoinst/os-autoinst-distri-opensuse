# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: k3s helm
# Summary: Ensure that k3s and helm is installed in the system
# - check if k3s is installed; if not, install k3s
# - check if helm is installed; if not, install helm
# Maintainer: QE-C team <qa-c@suse.de>

use Mojo::Base 'containers::basetest';
use testapi;
use utils;
use serial_terminal qw(select_serial_terminal);
use containers::k8s qw(install_helm install_k3s);

# Expected to work only on x86_64 and aarch64 due to k3s restrictions and only on Suse hosts due to the usage of zypper
sub run {
    select_serial_terminal;

    install_k3s();
    systemctl 'disable --now firewalld';
    install_helm() if get_var("INSTALL_HELM");
}

1;
