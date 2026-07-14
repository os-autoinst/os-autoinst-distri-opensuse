# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP
# Summary: executes a crash scenario on cloud provider.
# Maintainer: QE-SAP <qe-sap@suse.de>

=head1 NAME

sles4sap/crash/test_crash.pm - Execute System Crash Scenario

=head1 DESCRIPTION

C<test_crash.pm> executes a system crash on a cloud VM instance by triggering a SysRq reboot.

Its primary tasks are:

=over

=item * Retrieve VM instance information based on the cloud provider.

=item * Trigger an immediate reboot (crash) via C<sysrq-trigger> over SSH.

=item * Monitor the VM's network availability to confirm it has gone down.

=item * Wait for the VM to recover and verify that no critical services have failed using C<crash_wait_back>.

=back

=head1 SETTINGS

=over

=item B<PUBLIC_CLOUD_PROVIDER>

The cloud provider used: 'EC2', 'AZURE', or 'GCE'. Required.

=item B<PUBLIC_CLOUD_REGION>

Cloud region where the SUT is deployed. Required.

=item B<PUBLIC_CLOUD_AVAILABILITY_ZONE>

Availability zone for the cloud provider. Required for GCE.

=item B<IBSM_RG>

Azure Resource Group of the IBSm server. Optional (used in cleanup).

=item B<IBSM_IP>

IP address of the IBSm server. Optional (used in cleanup).

=back

=head1 MAINTAINER

QE-SAP <qe-sap@suse.de>

=cut

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
        apply_graceful_timeout => 1,
        ssh_opts => '-E /var/tmp/ssh_sut.log -fn -o ServerAliveInterval=2',
        username => $username);

    # wait for reboot
    record_info('Wait down', 'Wait until SUT is unreachable (rebooting)');
    my $wait_down_timeout = 60;
    while ($wait_down_timeout > 0) {
        if (script_run('nc -vz -w 1 ' . $instance->{public_ip} . ' 22', quiet => 1) != 0) {
            record_info('SUT down', 'SUT is unreachable, continuing with wait_back');
            last;
        }
        sleep 2;
        $wait_down_timeout -= 2;
    }

    record_info('Wait up', 'Wait until SUT is back again');
    crash_wait_back(vm_ip => $instance->{public_ip}, username => $username);
}

sub test_flags {
    return {fatal => 1};
}

sub post_fail_hook {
    my ($self) = shift;
    my $provider = get_required_var('PUBLIC_CLOUD_PROVIDER');
    my %clean_args = (provider => $provider, region => get_required_var('PUBLIC_CLOUD_REGION'), ibsm_rg => get_var('IBSM_RG'), ibsm_ip => get_var('IBSM_IP'));
    $clean_args{availability_zone} = get_required_var('PUBLIC_CLOUD_AVAILABILITY_ZONE') if $provider eq 'GCE';
    crash_cleanup(%clean_args);
    $self->SUPER::post_fail_hook;
}

1;
