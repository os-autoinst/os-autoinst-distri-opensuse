# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP
# Maintainer: QE-SAP <qe-sap@suse.de>
# Summary: Test module is used for scheduling multiple variants of ENSA2 'kill sapinstance' scenario.

use parent 'sles4sap::sap_deployment_automation_framework::basetest';

use strict;
use warnings FATAL => 'all';
use testapi;
use main_common 'loadtest';
use serial_terminal qw(select_serial_terminal);
use sles4sap::console_redirection;
use hacluster;

=head1 SYNOPSIS

Test module is used for scheduling multiple variants of ENSA2 'kill sapinstance' scenario.
At the moment, the code supports only SDAF based deployment, but the dependencies can be removed completely in the future.
Test module is based on usage of console redirection. Check B<tests/sles4sap/redirection_tests/README.md> for details.

=cut

sub run {
    my ($self, $run_args) = @_;
    # Merge data into one hash. Resource location from redirection data is relative and can change
    my %redirection_data = map { %{$run_args->{redirection_data}{$_}} } ('nw_ascs', 'nw_ers');
    # Connect to any of the ENSA2 cluster nodes to collect current data
    select_serial_terminal();
    connect_target_to_serial(
        destination_ip => $redirection_data{(keys(%redirection_data))[0]}{ip_address},
        ssh_user => $redirection_data{(keys(%redirection_data))[0]}{ssh_user},
        switch_root => 1);

    # Collect current 'SAPInstance' resources location
    my @instance_resources = @{crm_resources_by_class(primitive_class => 'ocf:heartbeat:SAPInstance')};
    my $ascs_resource = (grep(/SCS/, @instance_resources))[0];
    my $ers_resource = (grep(/ERS/, @instance_resources))[0];

    # Disconnect from ASCS
    disconnect_target_from_serial();

    # Define test scenarios
    my %scenarios = (
        'Kill_sapinstance_ASCS' => {
            description => 'Test kills SAP instance ASCS process using "kill -9" command.
            Process must be restarted by cluster on original node without failover.',
            crm_resource_name => $ascs_resource,
            forced_takeover => undef
        },
        'Kill_sapinstance_ERS' => {
            description => 'Test kills SAP instance ERS process using "kill -9" command.
                Process must be restarted by cluster on original node without failover',
            crm_resource_name => $ers_resource,
            forced_takeover => undef
        }
    );

    # Schedule all tests using `loadtest` call
    for my $test_name (
        'Kill_sapinstance_ASCS',
        'Kill_sapinstance_ERS'
      )
    {
        loadtest('sles4sap/redirection_tests/ensa2_kill_sapinstance', name => $test_name, run_args => $run_args, @_);
        record_info('LOAD TEST', "Scheduling test: $test_name\nDescription:\n$scenarios{$test_name}{description}");
    }
    $run_args->{scenarios} = \%scenarios;
}

1;
