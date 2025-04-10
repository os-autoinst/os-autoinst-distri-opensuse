# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP
# Maintainer: QE-SAP <qe-sap@suse.de>
# Summary: Kill sapinstance ERS without failover

use parent 'sles4sap::sap_deployment_automation_framework::basetest';

use warnings;
use strict;
use testapi;
use serial_terminal qw(select_serial_terminal);
use utils qw(script_retry);
use hacluster;
use sles4sap::sap_host_agent qw(saphostctrl_list_instances);
use sles4sap::sapcontrol qw(sap_show_status_info);
use sles4sap::console_redirection;

=head1 SYNOPSIS

Test module performs ENSA2 B<'Kill sapinstance ERS'> test scenario. SAP process B<er.sap*> is killed using C<kill -9>
command. Expected result is ERS process being restarted on the same node and crm fail count will increase.
Test module is based on usage of console redirection. Check B<tests/sles4sap/redirection_tests/README.md> for details.

=cut

sub run {
    my ($self, $run_args) = @_;
    my $redirection_data = $run_args->{redirection_data};
    my $target_hostname = (keys(%{$redirection_data->{nw_ers}}))[0];
    my %target_data = %{$redirection_data->{'nw_ers'}{$target_hostname}};

    # Connect to (assumed) target VM - ERS resource is there only according to redirection data
    connect_target_to_serial(
        destination_ip => $target_data{ip_address}, ssh_user => $target_data{ssh_user}, switch_root => 1);

    # Get ERS crm resource name
    my @instance_resources = @{crm_resources_by_class(primitive_class => 'ocf:heartbeat:SAPInstance')};
    # Get resource carrying 'ERS' in the name
    my @ers_resources = grep(/ERS/, @instance_resources);
    die("Exactly one resource must exist. Got:\n" . join("\n", @ers_resources)) unless @ers_resources == 1;
    my $ers_resource = $ers_resources[0];

    # If ERS resource is not on the current node, switch to the host it actually resides
    if (crm_resource_locate(crm_resource => $ers_resource) ne $target_hostname) {
        record_info('NODE SWITCH', "ERS resource '$ers_resource' is on different node, reconnecting.");
        disconnect_target_from_serial();
        $target_hostname = (keys(%{$redirection_data->{nw_ascs}}))[0];
        %target_data = %{$redirection_data->{'nw_ascs'}{$target_hostname}};
        connect_target_to_serial(
            destination_ip => $target_data{ip_address}, ssh_user => $target_data{ssh_user}, switch_root => 1);
    }

    my @instances_data = @{saphostctrl_list_instances(as_root => 'yes')};
    # Show status
    sap_show_status_info(cluster => 1, netweaver => 1, instance_id => $instances_data[0]->{instance_id});

    # Check if cluster is being healthy
    my $fail_count;
    record_info('Cluster wait', 'Waiting for resources to start');
    wait_until_resources_started();
    wait_for_idle_cluster();
    record_info('Cluster check', 'Checking state of cluster resources');
    check_cluster_state();

    # Check resource fail count - must be 0
    $fail_count = crm_get_failcount(crm_resource => $ers_resource, assert_result => 'yes');
    record_info("Fail count: $fail_count", "Fail count is $fail_count");

    # Kill ENQ process
    record_info('PROC list', script_output('ps -ef | grep sap'));    # Show SAP processes running
    my $enq_pid = script_output('pgrep er.sap');
    die 'ENQ process ID not found' unless $enq_pid;
    record_info('KILL INST', 'Killing ERS sapinstance process');
    assert_script_run("kill -9 $enq_pid");

    # Check if ENQ process was killed
    record_info('PROC list', script_output('ps -ef | grep sap'));    # Show SAP processes running

    script_retry('pgrep er.sap',
        expect => 1,    # pgrep returns 1 if process was not found
        delay => 1,    # short delay in case process gets up too quickly
        timeout => 30,    # 30 sec is plenty
        fail_message => 'ENQ process still running after being killed.'
    );

    record_info('Cluster wait', 'Waiting for cluster detecting failure');
    # Wait till fail count increases
    $fail_count = crm_wait_failcount(crm_resource => $ers_resource);
    record_info("Fail count: $fail_count", "Fail count is $fail_count");

    record_info('Res cleanup', 'Cleaning up resources using "crm resource cleanup"');
    rsc_cleanup($ers_resource);
    wait_until_resources_started();
    wait_for_idle_cluster();
    record_info('Cluster check', 'Checking state of cluster resources');
    check_cluster_state();
    # ERS resource must not be moved
    die "ERS cluster resource '$ers_resource' is not on the original node." if
      (crm_resource_locate(crm_resource => $ers_resource) ne $target_hostname);

    # Show status of local instances
    sap_show_status_info(cluster => 1, netweaver => 1, instance_id => $instances_data[0]->{instance_id});

    disconnect_target_from_serial();
}

1;
