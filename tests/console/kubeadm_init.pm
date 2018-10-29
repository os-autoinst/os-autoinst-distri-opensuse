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

    record_info 'Test #1', 'Test: Initialize kubeadm';
    # record_soft_failure "bsc#1093132" if script_run('kubeadm init');
    # script_run('kubeadm reset');
    assert_script_run('kubeadm init --pod-network-cidr=10.244.0.0/16 --cri-socket /var/run/crio/crio.sock', 180);

}

1;
