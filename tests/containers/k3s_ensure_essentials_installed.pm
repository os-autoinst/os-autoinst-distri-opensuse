# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: podman docker helm
# Summary: Ensure that helm is installed in the system if HELM_CHART is defined.
# - check if kubectl is installed; if not, install kubectl
# - check if helm is installed; if not, install helm
# Maintainer: qe-c <qe-c@suse.de>

use Mojo::Base 'containers::basetest';
use testapi;
use utils;
use serial_terminal qw(select_serial_terminal);
use containers::k8s qw(install_kubectl install_helm install_k3s);

sub run {
    select_serial_terminal;
    return undef unless get_var('HELM_CHART');
    install_kubectl() unless script_run("which kubectl") == 0;
    install_helm() unless script_run("which helm") == 0;
    install_k3s() unless script_run("which k3s") == 0;
    systemctl 'disable --now firewalld';
}

1;
