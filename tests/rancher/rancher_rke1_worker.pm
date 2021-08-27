# SUSE's openQA tests
#
# Copyright © 2021 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.
#
# Summary: Two workers deployed by rke1 Kubernetes cluster.
#   All workers wait for master to test the cluster.
# Maintainer: Pavel Dostal <pdostal@suse.com>

use base 'x11test';
use strict;
use warnings;
use testapi;
use lockapi;
use utils;
use version_utils;
use rancher::utils;
use containers::common;

sub run {
    my ($self) = @_;
    $self->select_serial_terminal;

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

