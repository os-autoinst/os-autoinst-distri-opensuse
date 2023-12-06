# SUSE's openQA tests
#
# Copyright 2024 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: kubernetes-*-kubeadm kubernetes*-client
# Summary: Test kubeadm to bootstrap single node k8s cluster.
# Maintainer: QE-C team <qa-c@suse.de>

use strict;
use warnings;
use base "consoletest";
use testapi;
use utils qw(systemctl zypper_call);
use serial_terminal 'select_serial_terminal';

sub run {
    select_serial_terminal;
    zypper_call "in patterns-kubernetes-kubeadm conntrackd iptables";
    systemctl "start containerd";

    assert_script_run("kubeadm version");
    assert_script_run("kubeadm config images pull");

    record_info 'Test #1', 'Test: Initialize kubeadm';
    # Need to skip kube-proxy because of https://github.com/kubernetes/kubeadm/issues/2699
    assert_script_run("kubeadm init --v=5 --skip-phases=addon/kube-proxy", 300);

    record_info 'Test #2', 'Test: Configure kubectl';
    assert_script_run('mkdir ~/.kube');
    assert_script_run('cp /etc/kubernetes/admin.conf ~/.kube/config');

    sleep 60;
    record_info 'Test #3', 'Test: Configure CNI';
    assert_script_run('kubectl apply -f /usr/share/k8s-yaml/weave/weave.yaml');

    record_info 'Test #4', 'Test: Record cluster info';
    # Cluster isn't ready immediately
    assert_script_run("kubectl wait --for=condition=Ready --timeout=300s node/\$(hostname)", 300);
    assert_script_run("kubectl cluster-info");
    assert_script_run("kubectl config view --flatten=true");
    assert_script_run("kubectl get pods --all-namespaces");
    assert_script_run("kubectl describe nodes");
    assert_script_run("cat /etc/cni/net.d/*");

    record_info 'Test #5', 'Test: Confirm node is ready';
    assert_script_run('kubectl get nodes | grep "Ready" | grep -v "NotReady"');
}

1;
