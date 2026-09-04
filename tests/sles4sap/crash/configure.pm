# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP
# Summary: Public Cloud - VM Configuration and Registration
# Maintainer: QE-SAP <qe-sap@suse.de>

=head1 NAME

sles4sap/crash/configure.pm - VM Configuration and Registration

=head1 DESCRIPTION

C<configure.pm> performs initial setup on the SUT cloud VM for subsequent crash testing.

Its primary tasks are:

=over

=item * Connect to the VM via SSH and verify its availability.

=item * Scan and trust the host key.

=item * Register the system using C<SCC_REGCODE_SLES4SAP> and optional C<SCC_ADDONS>.

=item * Prepare the system by patching and rebooting using C<crash_system_ready>.

=back

=head1 SETTINGS

=over

=item B<PUBLIC_CLOUD_PROVIDER>

Type of the public cloud provider (e.g., AWS, AZURE, GCE). Required.

=item B<PUBLIC_CLOUD_REGION>

Region of the public cloud provider.

=item B<PUBLIC_CLOUD_AVAILABILITY_ZONE>

Availability zone for the public cloud provider (Required for GCE).

=item B<SCC_REGCODE_SLES4SAP>

Registration code for SLES for SAP.

=item B<PUBLIC_CLOUD_SCC_ENDPOINT>

Custom SCC endpoint URL. Optional. Defaults to 'registercloudguest' inside C<crash_system_ready>.

=item B<SCC_ADDONS>

Comma-separated list of addons to register. Optional.

=back

=head1 MAINTAINER

QE-SAP <qe-sap@suse.de>

=cut

use Mojo::Base 'publiccloud::basetest';
use serial_terminal 'select_serial_terminal';
use testapi;
use sles4sap::crash;
use publiccloud::utils qw(register_addon);

sub run {
    my ($self) = @_;

    my $provider = get_required_var('PUBLIC_CLOUD_PROVIDER');
    my %crash_pubip_args = (provider => $provider, region => get_var('PUBLIC_CLOUD_REGION'));
    $crash_pubip_args{availability_zone} = get_required_var('PUBLIC_CLOUD_AVAILABILITY_ZONE') if $provider eq 'GCE';
    my $vm_ip = crash_pubip(%crash_pubip_args);

    my $username = crash_get_username(provider => $provider);
    my $remote_host = "$username\@$vm_ip";
    $remote_host = "-o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no $remote_host" unless $provider eq 'AZURE';
    my $ssh_cmd = "ssh $remote_host";

    my $start_time = time();
    while ((time() - $start_time) < 300) {
        my $ret = script_run("nc -vz -w 1 $vm_ip 22", quiet => 1);
        last if defined($ret) and $ret == 0;
        sleep 10;
    }

    assert_script_run("ssh-keyscan $vm_ip | tee -a ~/.ssh/known_hosts");
    crash_system_ready(
        reg_code => get_var('SCC_REGCODE_SLES4SAP'),
        ssh_command => $ssh_cmd,
        scc_endpoint => get_var('PUBLIC_CLOUD_SCC_ENDPOINT', undef));

    if (my $addons = get_var('SCC_ADDONS')) {
        register_addon($remote_host, $_) foreach (split(',', $addons));
    }
}

sub test_flags {
    return {fatal => 1};
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
