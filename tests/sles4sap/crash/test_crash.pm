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

    # Crash test
    my $provider = get_required_var('PUBLIC_CLOUD_PROVIDER');
    my $vm_ip = crash_pubip(provider => $provider, region => get_var('PUBLIC_CLOUD_REGION'));

    my %usernames = (
        AZURE => 'cloudadmin',
        EC2 => 'ec2-user'
    );
    my $username = $usernames{$provider} or die "Unsupported cloud provider: $provider";
    my $instance = publiccloud::instance->new(public_ip => $vm_ip, username => $username);
    select_host_console();

    $instance->run_ssh_command(
        cmd => 'sudo su -c "echo b > /proc/sysrq-trigger &"',
        timeout => 10,
        rc_only => 1,
        ssh_opts => '-E /var/tmp/ssh_sut.log -fn -o ServerAliveInterval=2',
        username => $username);

    # wait for reboot
    sleep 5;
    record_info('Wait until', 'Wait until SUT is back again');
    crash_wait_back(vm_ip => $vm_ip, username => $username);
}

sub test_flags {
    return {fatal => 1, publiccloud_multi_module => 1};
}

sub post_fail_hook {
    my ($self) = shift;

    my $provider = get_required_var('PUBLIC_CLOUD_PROVIDER');
    if ($provider eq 'AZURE') {
        crash_destroy_azure();
    }
    elsif ($provider eq 'EC2') {
        crash_destroy_aws(region => get_required_var('PUBLIC_CLOUD_REGION'));
    }
    $self->SUPER::post_fail_hook;
}

1;
