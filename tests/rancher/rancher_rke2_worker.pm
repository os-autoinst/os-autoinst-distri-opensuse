# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: Two workers deployed by rke1 Kubernetes cluster.
#   All workers wait for master to test the cluster.
# Maintainer: Pavel Dostal <pdostal@suse.com>

use Mojo::Base 'containers::basetest';
use testapi;
use lockapi qw(mutex_wait barrier_wait);
use mmapi 'get_current_job_id';
use utils qw(exec_and_insert_password set_hostname);
use Utils::Systemd qw(systemctl disable_and_stop_service);
use mm_network 'setup_static_mm_network';

sub run {
    my ($self) = @_;
    mutex_wait 'barrier_setup_done';
    $self->select_serial_terminal;

    # Two last digits from job ID
    my $id = substr(get_current_job_id(), -2);
    my $ip = "10.0.2.1$id/24";
    setup_static_mm_network($ip);
    disable_and_stop_service('firewalld');
    set_hostname("worker$id");
    barrier_wait('networking_prepared');

    # Install the rke2 agent
    assert_script_run("curl -sfL https://get.rke2.io | INSTALL_RKE2_TYPE='agent' sh -");
    assert_script_run('export PATH=$PATH:/var/lib/rancher/rke2/bin/:/opt/rke2/bin');

    assert_script_run("mkdir -p /etc/rancher/rke2/");
    assert_script_run('echo -en "server: https://10.0.2.99:9345\ntoken: " | tee /etc/rancher/rke2/config.yaml');

    barrier_wait('cluster_prepared');
    exec_and_insert_password("scp -o StrictHostKeyChecking=no  10.0.2.99:/var/lib/rancher/rke2/server/node-token ~/");
    assert_script_run("cat ~/node-token >> /etc/rancher/rke2/config.yaml");
    assert_script_run("cat /etc/rancher/rke2/config.yaml");
    systemctl('enable --now rke2-agent.service', timeout => 900);

    barrier_wait('cluster_deployed');
    assert_script_run("ps aux");

    barrier_wait('cluster_test_done');
    assert_script_run("rke2-killall.sh");
    assert_script_run("rke2-uninstall.sh");
}

sub post_fail_hook {
    my ($self) = @_;

    assert_script_run("journalctl --no-pager -u rke2-agent.service");
    $self->SUPER::post_fail_hook;
}

1;

