# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: One master node whene k3s server runs and cluster is tested..
# Maintainer: Pavel Dostal <pdostal@suse.com>

use base 'x11test';
use strict;
use warnings;
use testapi;
use serial_terminal 'select_serial_terminal';
use lockapi;
use utils;
use rancher::utils;

sub run {
    select_serial_terminal;

    mutex_wait('support_server_ready');
    prepare_mm_network();
    barrier_wait('networking_prepared');

    assert_script_run("curl -L https://get.k3s.io -o ~/get_k3s", 360);
    assert_script_run("chmod +rx ~/get_k3s");

    assert_script_run("./get_k3s", 600);
    script_retry("kubectl get node | grep ' Ready '", delay => 3, retry => 10);
    script_run("cat /var/lib/rancher/k3s/server/node-token");

    barrier_wait('cluster_prepared');

    systemctl('status k3s');

    # Wait until all workers are visible and Ready. Currently we've 1 master and 2 workers
    script_retry("[ `kubectl get node | grep ' Ready ' | wc -l` -eq 3 ]", delay => 15, retry => 40);

    barrier_wait('cluster_deployed');

    assert_script_run("kubectl get node");
    kubectl_basic_test();

    barrier_wait('cluster_test_done');

    systemctl('stop k3s');
}

1;

