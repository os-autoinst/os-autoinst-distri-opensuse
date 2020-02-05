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
use warnings;
use base "consoletest";
use testapi;
use utils "systemctl";

sub run {
    select_console("root-console");

    record_info 'Test #1', 'Test: Initialize kubeadm';
    assert_script_run("kubeadm init --cri-socket=/var/run/crio/crio.sock --pod-network-cidr=10.244.0.0/16 --kubernetes-version=\$(kubelet --version|sed -e 's/Kubernetes v//g') | tee /dev/$serialdev", 300);

    record_info 'Test #2', 'Test: Configure kubectl';
    assert_script_run('mkdir -p ~/.kube');
    assert_script_run('cp -i /etc/kubernetes/admin.conf ~/.kube/config');

    record_info 'Test #3', 'Test: Configure CNI';
    if (check_var('CNI', 'cilium')) {
        assert_script_run('kubectl apply -f /usr/share/k8s-yaml/cilium/*.yaml');
    } elsif (check_var('CNI', 'flannel')) {
        assert_script_run('kubectl apply -f /usr/share/k8s-yaml/flannel/kube-flannel.yaml');
    } elsif (check_var('CNI', 'weave')) {
        assert_script_run('kubectl apply -f /usr/share/k8s-yaml/weave/weave.yaml');
    } else {
        die('CNI variable not set, or set to unknown value');
    }

    record_info 'Test #4', 'Test: Record cluster info';
    # Cluster isn't ready immediately
    sleep 60;
    script_run("kubectl config view --flatten=true | tee /dev/$serialdev");
    script_run("kubectl get pods --all-namespaces | tee /dev/$serialdev");
    script_run("kubectl describe nodes | tee /dev/$serialdev");
    script_run("cat /etc/cni/net.d/* | tee /dev/$serialdev");

    record_info 'Test #5', 'Test: Confirm node is ready';
    assert_script_run('kubectl get nodes | grep "Ready" | grep -v "NotReady"');

    # If SONOBUOY_URL is set, this is a certification run, download upstream certification tool and run the process
    if (get_var 'SONOBUOY_URL') {
        assert_script_run('mkdir ~/sonobuoy && cd ~/sonobuoy');
        assert_script_run('curl -L -O ' . get_var('SONOBUOY_URL'));
        assert_script_run('tar xvf *.tar.gz && rm *.tar.gz');
        assert_script_run('kubectl taint nodes --all node-role.kubernetes.io/master-');
        assert_script_run('./sonobuoy run --mode=certified-conformance');
        # Wait a minute for the process to start
        sleep 60;
        type_string("./sonobuoy status |& grep 'running' | tee /dev/$serialdev\n");
        # Sonobuoy runs really long, wait for upto 2 hours checking every 10 minutes if its finished or not
        my $counter = 0;
        while ((wait_serial('Sonobuoy is still running')) && ($counter < 12)) {
            sleep 600;
            $counter++;
            type_string("./sonobuoy status |& grep 'running' | tee /dev/$serialdev\n");
        }
        assert_script_run('outfile=$(./sonobuoy retrieve)');
        assert_script_run('mkdir ./results; tar xzf $outfile -C ./results');
        upload_logs '$outfile';
        upload_logs './results/plugins/e2e/results/global/e2e.log';
        upload_logs './results/plugins/e2e/results/global/junit_01.xml';
        assert_script_run('tail ~/sonobuoy/results/plugins/e2e/results/global/e2e.log|grep "Test Suite Passed"');
    }
}

1;
