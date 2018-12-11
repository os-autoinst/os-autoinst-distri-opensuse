# SUSE's openQA tests
#
# Copyright © 2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Test kubeadm to bootstrap single node k8s cluster. Intended for use in Kubic (only place where k8s is supported)
# Maintainer: Panagiotis Georgiadis <pgeorgiadis@suse.com>, Richard Brown <rbrown@suse.com>

use strict;
use base "consoletest";
use testapi;
use caasp;
use utils "systemctl";

sub run {
    select_console("root-console");

    record_info 'Test #1', 'Test: Initialize kubeadm';
    assert_script_run('kubeadm init --cri-socket=/var/run/crio/crio.sock --pod-network-cidr=10.244.0.0/16 | tee /dev/$serialdev', 180);

    record_info 'Test #2', 'Test: Configure kubectl';
    assert_script_run('mkdir -p ~/.kube');
    assert_script_run('cp -i /etc/kubernetes/admin.conf ~/.kube/config');

    record_info 'Test #3', 'Test: Configure flannel';
    assert_script_run('kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/bc79dd1505b0c8681ece4de4c0d86c5cd2643275/Documentation/kube-flannel.yml');

    record_info 'Test #4', 'Test: Record cluster info';
    # Cluster isn't ready immediately
    sleep 60;
    script_run('kubectl config view --flatten=true | tee /dev/$serialdev');
    script_run('kubectl get pods --all-namespaces | tee /dev/$serialdev');

    record_info 'Test #5', 'Test: Confirm node is ready';
    assert_script_run('kubectl get nodes | grep "Ready" | grep -v "NotReady"');
}

1;
