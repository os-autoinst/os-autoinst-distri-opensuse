# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: One master node whene rke1 runs and deploys the cluster and cluster is tested..
# Maintainer: Pavel Dostal <pdostal@suse.com>

use Mojo::Base 'containers::basetest';
use testapi;
use lockapi;
use mmapi;
use utils qw(script_retry zypper_call set_hostname permit_root_ssh);
use Utils::Systemd qw(systemctl disable_and_stop_service);
use rancher::utils 'kubectl_basic_test';
use mm_network 'setup_static_mm_network';

sub run {
    my ($self) = @_;
    $self->select_serial_terminal;

    # All nodes are online with SSH enabled
    barrier_create('networking_prepared', 3);
    # Master node is ready to accept workers
    barrier_create('cluster_prepared', 3);
    # Cluster is fully deployed
    barrier_create('cluster_deployed', 3);
    # Testing is done, cluster can be destroyed
    barrier_create('cluster_test_done', 3);
    # Hack for YAML scheduling
    mutex_create 'barrier_setup_done';
    mutex_wait 'barrier_setup_done';

    my $ip = '10.0.2.99/24';
    setup_static_mm_network($ip);
    disable_and_stop_service('firewalld');
    set_hostname('master');
    assert_script_run("echo 'master 10.0.2.99' >> /etc/hosts");
    barrier_wait('networking_prepared');

    # Install rke2
    assert_script_run("curl -sfL https://get.rke2.io | sh -", timeout => 600);
    assert_script_run('export PATH=$PATH:/var/lib/rancher/rke2/bin/:/opt/rke2/bin');

    # Start rke2 as a server (default)
    systemctl("enable --now rke2-server.service", timeout => 400);

    assert_script_run("mkdir -p ~/.kube && cp /etc/rancher/rke2/rke2.yaml .kube/config");
    permit_root_ssh();

    barrier_wait('cluster_prepared');

    # Wait untill all workers are visible and Ready. Currently we've 1 master and 2 workers
    script_retry("[ `kubectl get node | grep ' Ready ' | wc -l` -eq 3 ]", delay => 15, retry => 400);

    barrier_wait('cluster_deployed');

    assert_script_run("kubectl get nodes");
    kubectl_basic_test();

    barrier_wait('cluster_test_done');
    assert_script_run("rke2-killall.sh");
    assert_script_run("rke2-uninstall.sh");
}

sub post_fail_hook {
    my ($self) = @_;

    script_run("kubectl get node");
    script_run("journalctl --no-pager -u rke2-server.service");
    $self->SUPER::post_fail_hook;
}

1;

