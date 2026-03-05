# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP
# Maintainer: QE-SAP <qe-sap@suse.de>
# Summary: executes a crash scenario on cloud provider.

use Mojo::Base 'publiccloud::basetest';
use serial_terminal 'select_serial_terminal';
use testapi;
use publiccloud::instance;
use publiccloud::ssh_interactive;
use sles4sap::crash;

sub run {
    my ($self) = @_;

    my $provider = get_required_var('PUBLIC_CLOUD_PROVIDER');
    my %crash_get_instance_args = (provider => $provider, region => get_var('PUBLIC_CLOUD_REGION'));
    $crash_get_instance_args{availability_zone} = get_required_var('PUBLIC_CLOUD_AVAILABILITY_ZONE') if $provider eq 'GCE';
    my $instance = crash_get_instance(%crash_get_instance_args);
    my $username = crash_get_username(provider => $provider);

    select_host_console();
    $instance->ssh_script_run(
        cmd => 'sudo su -c "echo b > /proc/sysrq-trigger &"',
        timeout => 10,
        ssh_opts => '-E /var/tmp/ssh_sut.log -fn -o ServerAliveInterval=2',
        username => $username);

    # wait for reboot
    sleep 5;
    record_info('Wait until', 'Wait until SUT is back again');
    crash_wait_back(vm_ip => $instance->{public_ip}, username => $username);
}

sub test_flags {
    return {fatal => 1, publiccloud_multi_module => 1};
}

sub post_fail_hook {
    my ($self) = shift;
    my $provider = get_required_var('PUBLIC_CLOUD_PROVIDER');
    my %clean_args = (provider => $provider, region => get_required_var('PUBLIC_CLOUD_REGION'));
    $clean_args{availability_zone} = get_required_var('PUBLIC_CLOUD_AVAILABILITY_ZONE') if $provider eq 'GCE';
    crash_cleanup(%clean_args);
    $self->SUPER::post_fail_hook;
}

1;
