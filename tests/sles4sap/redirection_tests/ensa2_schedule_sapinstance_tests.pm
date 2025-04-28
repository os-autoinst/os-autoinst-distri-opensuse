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
    my $connect_ip = $redirection_data{(keys(%redirection_data))[0]}{ip_address};
    my $connect_user = $redirection_data{(keys(%redirection_data))[0]}{ssh_user};

    select_serial_terminal();
    connect_target_to_serial(destination_ip => $connect_ip, ssh_user => $connect_user, switch_root => 1);

    # Collect current 'SAPInstance' resources location
    my @instance_resources = @{crm_resources_by_class(primitive_class => 'ocf:heartbeat:SAPInstance')};
    my $ascs_resource = (grep(/SCS/, @instance_resources))[0];
    my $ascs_location = crm_resource_locate(crm_resource => $ascs_resource);
    my $ers_resource = (grep(/ERS/, @instance_resources))[0];
    my $ers_location = crm_resource_locate(crm_resource => $ers_resource);

    # Disconnect from ASCS
    disconnect_target_from_serial();

    # Define test scenarios
    my %scenarios = (
        'Kill_sapinstance_ASCS' => {
            description => 'Test kills SAP instance ASCS process using "kill -9" command. Process must be restarted by cluster on original node without failover',
            connect_ip => $redirection_data{$ascs_location}{ip_address},
            connect_user => $redirection_data{$ascs_location}{ssh_user},
            crm_resource_name => $ascs_resource
        },
        'Kill_sapinstance_ERS' => {
            description => 'Test kills SAP instance ERS process using "kill -9" command. Process must be restarted by cluster on original node without failover',
            connect_ip => $redirection_data{$ers_location}{ip_address},
            connect_user => $redirection_data{$ers_location}{ssh_user},
            crm_resource_name => $ers_resource
        }
    );

    loadtest('sles4sap/redirection_tests/ensa2_kill_sapinstance',
        name => 'Kill_sapinstance_ASCS',
        run_args => $run_args, @_);

    loadtest('sles4sap/redirection_tests/ensa2_kill_sapinstance',
        name => 'Kill_sapinstance_ERS',
        run_args => $run_args, @_);

    $run_args->{scenarios} = \%scenarios;
}

1;
