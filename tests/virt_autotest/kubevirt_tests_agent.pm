# SUSE's openQA tests
#
# Copyright 2022 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: This kubevirt test relies on the upstream test code, which is downstreamed as virt-tests.
#          This is the part running on agent node.
# Maintainer: Nan Zhang <nan.zhang@suse.com>

use base multi_machine_job_base;
use strict;
use warnings;
use testapi;
use lockapi;
use utils;
use Utils::Backends 'use_ssh_serial_console';

sub run {
    my ($self) = shift;

    if (get_required_var('WITH_SLE_INSTALL')) {
        my $sut_ip = get_required_var('SUT_IP');

        set_var('AGENT_IP', $sut_ip);
        bmwqemu::save_vars();

        # Synchronize the server & agent node before setup
        barrier_wait('kubevirt_test_setup');

        my $server_ip = $self->get_var_from_parent("SERVER_IP");
        record_info('Server IP', $server_ip);

        $self->rke2_agent_setup($server_ip);
    } else {
        select_console 'sol', await_console => 0;
        use_ssh_serial_console;
    }

    barrier_wait('kubevirt_test_done');
}

sub rke2_agent_setup {
    my ($self, $server_ip) = @_;

    record_info('Start RKE2 agent setup', '');
    systemctl('stop apparmor.service');
    systemctl('stop firewalld.service');
    $self->setup_passwordless_ssh_login($server_ip);

    # Ensure SUSE certificates are installed on the node
    ensure_ca_certificates_suse_installed();

    # Install downstream kubevirt packages
    zypper_call('in -n kubernetes1.18-client') if (script_run('rpmquery kubernetes1.18-client'));

    # RKE2 deployment on agent node
    # Default is to setup service with the latest RKE2 version, the parameter INSTALL_RKE2_VERSION allows to setup with a specified version.
    my $rke2_ver = get_var('INSTALL_RKE2_VERSION');
    if ($rke2_ver) {
        record_info('RKE2 version', $rke2_ver);
        assert_script_run("curl -sfL https://get.rke2.io | INSTALL_RKE2_VERSION=$rke2_ver INSTALL_RKE2_TYPE=agent sh -", timeout => 180);
    } else {
        assert_script_run('curl -sfL https://get.rke2.io | INSTALL_RKE2_TYPE=agent sh -', timeout => 180);
    }

    # Wait for rke2-server service to be ready
    barrier_wait('rke2_server_start_ready');

    # Configure rke2-agent service
    my $server_node_token = script_output("ssh root\@$server_ip cat /var/lib/rancher/rke2/server/node-token");
    assert_script_run('mkdir -p /etc/rancher/rke2/');
    assert_script_run("echo 'server: https://$server_ip:9345' > /etc/rancher/rke2/config.yaml");
    assert_script_run("echo 'token: $server_node_token' >> /etc/rancher/rke2/config.yaml");

    # Enable rke2-agent service
    systemctl('enable rke2-agent.service');
    systemctl('start rke2-agent.service', timeout => 180);
    $self->check_service_status();

    # Start rke2-agent service ready
    mutex_create('RKE2_AGENT_START_READY');

    assert_script_run("mkdir -p ~/.kube; scp root\@$server_ip:/etc/rancher/rke2/rke2.yaml ~/.kube/config");
    assert_script_run("sed -i 's/127.0.0.1/$server_ip/' ~/.kube/config");
    assert_script_run('kubectl get nodes');
    $self->set_cpu_manager_policy();

    # Wait for restarting rke2-server service complete
    barrier_wait('rke2_server_restart_complete');

    # Restart RKE2 service and check the service is active well after restart
    systemctl('restart rke2-agent.service', timeout => 180);
    $self->check_service_status();
    assert_script_run("grep static /var/lib/kubelet/cpu_manager_state");

    # Restart rke2-agent service ready
    mutex_create('RKE2_AGENT_RESTART_COMPLETE');

    script_retry('! kubectl get nodes | grep NotReady', retry => 8, delay => 20, timeout => 180);
    assert_script_run('kubectl get nodes');
}

sub check_service_status {
    my $self = shift;
    # Check RKE2 services status and error message
    record_info('Check RKE2 service status and error message', '');
    assert_script_run("systemctl status rke2-agent.service | grep 'active (running)'");
    assert_script_run("journalctl -u rke2-agent | grep 'Started Rancher Kubernetes Engine v2 (agent)'");
    assert_script_run("! journalctl -u rke2-agent | grep \'\"level\":\"error\"\'");
}

sub set_cpu_manager_policy {
    my $self = shift;
    # Set static policy for CPU Manager
    assert_script_run("sed -i '/ExecStart=/s/agent\$/agent --kubelet-arg cpu-manager-policy=static --kubelet-arg kube-reserved=cpu=500m --kubelet-arg system-reserved=cpu=500m/' /etc/systemd/system/rke2-agent.service");
    assert_script_run("rm /var/lib/kubelet/cpu_manager_state");
    systemctl("daemon-reload");
}

sub post_fail_hook {
    my $self = shift;

    select_console 'log-console';
    $self->save_and_upload_log('dmesg', '/tmp/dmesg.log', {screenshot => 0});
    $self->save_and_upload_log('systemctl list-units -l', '/tmp/systemd_units.log', {screenshot => 0});
    $self->save_and_upload_systemd_unit_log('rke2-agent.service');
}

1;
