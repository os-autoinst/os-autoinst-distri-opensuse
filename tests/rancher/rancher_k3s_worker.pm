# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: Two worker nodes where k3s agent runs.
#   All workers wait for master to test the cluster.
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

    assert_script_run('ssh-keyscan master >> ~/.ssh/known_hosts');
    exec_and_insert_password('ssh-copy-id root@master');

    barrier_wait('cluster_prepared');

    my $token = script_output('ssh root@master cat /var/lib/rancher/k3s/server/node-token', timeout => 90);

    script_run 'curl -sk https://master:6443/';
    assert_script_run("K3S_TOKEN=$token K3S_URL=https://master:6443 ./get_k3s", 600);

    barrier_wait('cluster_deployed');

    barrier_wait('cluster_test_done');

    systemctl('stop k3s-agent');
}

1;

