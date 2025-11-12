# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP
# Maintainer: QE-SAP <qe-sap@suse.de>
# Summary: Verify connection between each SUT host and IBSm server IP.

use parent 'sles4sap::sap_deployment_automation_framework::basetest';

use testapi;
use serial_terminal qw(select_serial_terminal);
use sles4sap::sap_deployment_automation_framework::naming_conventions;
use sles4sap::console_redirection;
use sles4sap::sap_deployment_automation_framework::deployment;
use sles4sap::console_redirection::redirection_data_tools;
use sles4sap::azure_cli qw(az_nic_list);

use sles4sap::sap_deployment_automation_framework::basetest;

=head1 NAME

sles4sap/sap_deployment_automation_framework/ibsm_verify.pm - Verify connection between each SUT host and IBSm server IP.

=head1 MAINTAINER

QE-SAP <qe-sap@suse.de>

=head1 DESCRIPTION

Module is used to performs connection checks from each SUT host to IBSm server.
NOTE: Test module expects the worker VM to have keyless access to each host prepared.
- check `sles4sap/sap_deployment_automation_framework/prepare_ssh_config`

B<The key tasks performed by this module include:>

=over

=item * Collects connection data to all SUT virtual machines required for console redirection

=item * Connects to all SUT hosts and checks if ping to IBSm host is possible

=item * Reports results

=item * Terminates test if IBSm connection does not work for any of hosts

=back

=head1 OPENQA SETTINGS

=over

=item * B<IS_MAINTENANCE> : Define if test scenario includes applying maintenance updates

=item * B<REPO_MIRROR_HOST> : IBSm repository hostname

=back
=cut

sub test_flags {
    return {fatal => 1};
}

sub run {
    my ($self, $run_args) = @_;
    unless (get_var('IS_MAINTENANCE')) {
        # Just a safeguard for case the module is in schedule without 'IS_MAINTENANCE' OpenQA setting being set
        record_info('MAINTENANCE OFF', 'OpenQA setting "IS_MAINTENANCE" is disabled, skipping IBSm setup');
        return;
    }
    select_serial_terminal();
    my $redirection_data = sles4sap::console_redirection::redirection_data_tools->new($run_args->{redirection_data});
    my $ibsm_fqdn = get_required_var('REPO_MIRROR_HOST');

    my %sut_hosts = %{$redirection_data->get_sap_hosts};
    my $fail_count;

    for my $host (keys(%sut_hosts)) {
        # Everything is now executed on SUT, not worker VM
        my $ip_addr = $sut_hosts{$host}{ip_address};
        my $user = $sut_hosts{$host}{ssh_user};
        die "Redirection data missing. Got:\nIP: $ip_addr\nUSER: $user\n" unless $ip_addr and $user;

        connect_target_to_serial(destination_ip => $ip_addr, ssh_user => $user, switch_root => 'yes');
        if (script_run("ping -c 3 $ibsm_fqdn")) {
            $fail_count++;
            record_info('Ping test', "Ping test to IBSm IP '$ibsm_fqdn' FAILED", result => 'fail');
        }
        else {
            record_info('Ping test', "Ping test to IBSm IP '$ibsm_fqdn' PASSED");
        }
        disconnect_target_from_serial();
    }
    die "There are $fail_count failed verification checks." if $fail_count;
}

1;
