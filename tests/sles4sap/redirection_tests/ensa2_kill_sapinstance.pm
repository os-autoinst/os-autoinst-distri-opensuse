# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP
# Maintainer: QE-SAP <qe-sap@suse.de>
# Summary: Test module performs ENSA2 B<'Kill sapinstance'> test scenario.

use parent 'sles4sap::sap_deployment_automation_framework::basetest';

use warnings;
use strict;
use testapi;
use serial_terminal qw(select_serial_terminal);
use utils qw(script_retry);
use hacluster;
use sles4sap::sap_host_agent qw(saphostctrl_list_instances);
use sles4sap::sapcontrol;
use sles4sap::console_redirection;

=head1 SYNOPSIS

Test module performs ENSA2 B<'Kill sapinstance'> test scenario. SAP instance process (ERS or ASCS) B<*.sap*> is killed
using C<kill -9> command.
This test module is not supposed to be run directly via B<SCHEDULE> but through C<loadtest()> api call from parent module.
Test module is based on usage of console redirection. Check B<tests/sles4sap/redirection_tests/README.md> for details.

B<USAGE:>
Test module requires following structure containing information:
%scenarios = {
    'TestModule_A' => { # This is a name this test module was scheduled under using C<loadtest(name=>'TestModule_A')> .
                        # It is the name visible on the openQA web UI.. It is the name visible on the openQA web UI.
        description => 'First test scheduled using "loadtest()".',
        forced_takeover => true/false
            # B<true> sets cluster parameter B<migration_threshold>  to `1` so the takeover happens without
            # prior attempt to restart the resource first.
        crm_resource_name => 'rsc_sap_QES_ASCS01' # CRM resource name used for ASCS/ERS instance
    }
    'TestModule_B' => { # This is a name this test module was scheduled under using C<loadtest(name=>'TestModule_A')>
        description => 'Second test scheduled using "loadtest()".',
        forced_takeover => true,
        crm_resource_name => 'rsc_sap_QES_ERS02' # CRM resource name used for ASCS/ERS instance
    }
};

B<Schedule test from parent module:>
$run_args->{scenarios} = \%scenarios;
loadtest('sles4sap/redirection_tests/ensa2_kill_sapinstance', name => 'TestModule_A', run_args => $run_args, @_);
loadtest('sles4sap/redirection_tests/ensa2_kill_sapinstance', name => 'TestModule_B', run_args => $run_args, @_);

=cut

sub run {
    my ($self, $run_args) = @_;

    # Merge data into one hash. Resource location from redirection data is relative and can change
    my %redirection_data = map { %{$run_args->{redirection_data}{$_}} } ('nw_ascs', 'nw_ers');
    my %scenario = %{$run_args->{scenarios}{$self->{name}}};
    my $resource_name = $scenario{crm_resource_name};
    record_info('TEST INFO', $scenario{description});

    # Connect to any of the ENSA2 cluster nodes and collect current data
    my $connect_ip = $redirection_data{(keys(%redirection_data))[0]}{ip_address};
    connect_target_to_serial(
        destination_ip => $connect_ip,
        ssh_user => $redirection_data{(keys(%redirection_data))[0]}{ssh_user},
        switch_root => 1);

    # Collect current 'SAPInstance' resources location
    my $resource_location = crm_resource_locate(crm_resource => $resource_name);
    # Check if current console is redirected to target host and reconnect if needed.
    if (script_run("hostname | grep $resource_location")) {
        disconnect_target_from_serial();
        connect_target_to_serial(
            destination_ip => $redirection_data{$resource_location}{ip_address},
            ssh_user => $redirection_data{$resource_location}{ssh_user},
            switch_root => 1);
    }

    my @instances_data = @{saphostctrl_list_instances(as_root => 'yes', running => 'yes')};
    my $instance_id = $instances_data[0]->{instance_id};
    my $instance_type = get_instance_type(local_instance_id => $instance_id);
    my $forced_takeover = ($scenario{forced_takeover} && $instance_type eq 'ASCS') ? '1' : undef;

    # Show status
    sap_show_status_info(cluster => 1, netweaver => 1, instance_id => $instance_id);

    # Check if cluster is being healthy
    my $fail_count;
    record_info('Cluster wait', 'Waiting for resources to start');
    wait_until_resources_started();
    wait_for_idle_cluster();

    # Store original 'migration-threshold' to restore it at the end of the test
    my $migration_threshold_original_value =
      crm_resource_meta_show(resource => $resource_name, meta_argument => 'migration-threshold');
    record_info('CRM meta show', "Original CRM meta : $migration_threshold_original_value");

    # Change migration threshold according to scenario settings
    # 1 = killing process will trigger takeover immediately
    my $migration_threshold = $forced_takeover ? '1' : undef;
    crm_resource_meta_set(
        resource => $resource_name,
        meta_argument => 'migration-threshold',
        argument_value => $migration_threshold);

    record_info('Cluster check', 'Checking state of cluster resources');
    check_cluster_state();

    # Check resource fail count - must be 0
    $fail_count = crm_get_failcount(crm_resource => $resource_name, assert_result => 'yes');
    record_info("Fail count: $fail_count", "Fail count is $fail_count");

    # record initial resource location
    my $initial_res_location = crm_resource_locate(crm_resource => $resource_name);

    # Kill sapinstance process
    my $process_name;
    # There is a different naming between S4HANA and regular NW installation.
    # Note: 'pgrep' accepts only limited regexes
    $process_name = '"en.sap|enq.sap"' if $instance_type eq 'ASCS';
    $process_name = '"er.sap|enqr.sap"' if $instance_type eq 'ERS';
    die "Unknown instance type: '$instance_type'" unless $process_name;

    record_info('PROC list', script_output("ps -ef | grep -E $process_name"));    # Show SAP processes running
    my $pid = script_output("pgrep -f $process_name");
    die "Sapinstance $instance_type process ID not found" unless $pid;
    record_info('KILL INST', "Killing $instance_type sapinstance process PID '$pid'");
    assert_script_run("kill -9 $pid");

    # Check if sapinstance process was killed
    record_info('PROC list', script_output("ps -ef | grep -E $process_name"));

    my $retry = 0;
    until (script_run("pgrep -f $process_name")) {
        sleep 1;
        $retry++;
        die if ($retry == 30);
    }

    record_info('Cluster wait', 'Waiting for cluster detecting failure');
    # Wait till fail count increases
    $fail_count = crm_wait_failcount(crm_resource => $resource_name);
    record_info("Fail count: $fail_count", "Fail count is $fail_count");

    record_info('Refresh', 'Refreshing resources using "crm resource refresh"');
    assert_script_run('crm resource refresh');
    wait_until_resources_started();
    wait_for_idle_cluster();
    record_info('Cluster check', 'Checking state of cluster resources');
    check_cluster_state();

    if ($forced_takeover) {
        die "Cluser resource '$resource_name' was not moved to another node" if
          crm_resource_locate(crm_resource => $resource_name) eq $initial_res_location;
    }
    else {
        die "Cluster resource '$resource_name' is not on the original node." if
          (crm_resource_locate(crm_resource => $resource_name) ne $initial_res_location);
    }

    # Restore 'migration-threshold' to original value
    if (crm_resource_meta_show(resource => $resource_name, meta_argument => 'migration-threshold')
        ne $migration_threshold_original_value) {
        crm_resource_meta_set(
            resource => $resource_name,
            meta_argument => 'migration-threshold',
            argument_value => $migration_threshold_original_value);
    }

    # Show status of local instances
    sap_show_status_info(cluster => 1, netweaver => 1, instance_id => $instances_data[0]->{instance_id});
    # Close serial connection to SUT
    disconnect_target_from_serial();
}
1;
