# SUSE's openQA tests
#
# Copyright © 2021 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.
#
# Summary: One master node whene rke1 runs and deploys the cluster and cluster is tested..
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

    assert_script_run("curl -L https://github.com/rancher/rke/releases/download/v1.1.15/rke_linux-amd64 -o ~/rke", 360);
    assert_script_run("chmod +rx ~/rke");

    my ($running_version, $sp, $host_distri) = get_os_release;
    install_docker_when_needed($host_distri);
    zypper_call('in kubernetes-client');

    barrier_wait('cluster_prepared');

    assert_script_run('ssh-keyscan master >> ~/.ssh/known_hosts');
    exec_and_insert_password('ssh-copy-id root@master');
    assert_script_run('ssh-keyscan worker1 >> ~/.ssh/known_hosts');
    exec_and_insert_password('ssh-copy-id root@worker1');
    assert_script_run('ssh-keyscan worker2 >> ~/.ssh/known_hosts');
    exec_and_insert_password('ssh-copy-id root@worker2');

    assert_script_run("curl -o cluster.yml " . data_url("rancher/rke1.yaml"));
    script_run('cat cluster.yml');
    assert_script_run("./rke up", 600);

    assert_script_run("mkdir ~/.kube");
    assert_script_run("cp kube_config_cluster.yml ~/.kube/config");
    assert_script_run("chmod 600 ~/.kube/config");

    # Wait untill all workers are visible and Ready. Currently we've 1 master and 2 workers
    script_retry("[ `kubectl get node | grep ' Ready ' | wc -l` -eq 3 ]", delay => 15, retry => 40);

    barrier_wait('cluster_deployed');

    assert_script_run("kubectl get nodes");
    kubectl_basic_test();

    assert_script_run 'yes | ./rke remove';

    barrier_wait('cluster_test_done');

    systemctl('stop docker.service');
}

1;

