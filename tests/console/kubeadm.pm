# SUSE's openQA tests
#
# Copyright © 2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Test kubeadm installation and bootstrap single k8s cluster
# Maintainer: Panagiotis Georgiadis <pgeorgiadis@suse.com>

use strict;
use base "consoletest";
use testapi;
use caasp;
use utils "systemctl";

sub run {
    select_console("root-console");

    record_info 'etcd', 'Stop etcd and clean up';
    systemctl 'disable --now etcd';
    script_run 'rm -r /var/lib/etcd/*';

    record_info 'Setup', 'Test: Package Installation';
    my $packages = 'kubernetes-client kubernetes-kubelet kubernetes-kubeadm docker-kubic cri-tools';
    trup_install($packages);

    record_info 'Prepare', 'Test: Enable and start required services';
    systemctl('enable --now kubelet docker');
    systemctl('is-active docker');
    systemctl('is-active kubelet');

    record_info 'Test #1', 'Test: Initialize kubeadm';
    record_soft_failure "bsc#1093132" if script_run('kubeadm init');
    script_run('kubeadm reset');
    assert_script_run('kubeadm init', 180);

}

1;
