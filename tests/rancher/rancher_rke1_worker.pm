# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: Two workers deployed by rke1 Kubernetes cluster.
#   All workers wait for master to test the cluster.
# Maintainer: Pavel Dostal <pdostal@suse.com>

use base 'x11test';
use strict;
use warnings;
use testapi;
use serial_terminal 'select_serial_terminal';
use lockapi;
use utils;
use version_utils;
use rancher::utils;
use containers::common;

sub run {
    my ($self) = @_;
    select_serial_terminal;

    mutex_wait('support_server_ready');
    prepare_mm_network();
    barrier_wait('networking_prepared');

    my ($running_version, $sp, $host_distri) = get_os_release;
    install_docker_when_needed($host_distri);

    barrier_wait('cluster_prepared');

    barrier_wait('cluster_deployed');

    assert_script_run("docker ps");

    barrier_wait('cluster_test_done');

    systemctl('stop docker.service');
}

1;

