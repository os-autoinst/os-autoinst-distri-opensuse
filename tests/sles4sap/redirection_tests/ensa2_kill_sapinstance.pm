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
        connect_ip => '192.168.1.1',
        connect_user => 'cloudadmin',
        crm_resource_name => 'rsc_sap_QES_ASCS01' # CRM resource name used for ASCS/ERS instance
    }
    'TestModule_B' => { # This is a name this test module was scheduled under using C<loadtest(name=>'TestModule_A')>
        description => 'Second test scheduled using "loadtest()".',
        connect_ip => '192.168.1.2',
        connect_user => 'cloudadmin',
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
    my %scenario = %{$run_args->{scenarios}{$self->{name}}};
    my $resource_name = $scenario{crm_resource_name};

    record_info('TEST INFO', $scenario{description});

    connect_target_to_serial(
        destination_ip => $scenario{connect_ip}, ssh_user => $scenario{connect_user}, switch_root => 1);

    my @instances_data = @{saphostctrl_list_instances(as_root => 'yes', running => 'yes')};
    my $instance_id = $instances_data[0]->{instance_id};
    my $instance_type = get_instance_type(local_instance_id => $instance_id);

    # Show status
    sap_show_status_info(cluster => 1, netweaver => 1, instance_id => $instance_id);

    # Check if cluster is being healthy
    my $fail_count;
    record_info('Cluster wait', 'Waiting for resources to start');
    wait_until_resources_started();
    wait_for_idle_cluster();

    # Remove meta-argument 'migration-threshold' for cluster to try restarting sapinstance process first.
    crm_resource_meta_set(resource => $resource_name, meta_argument => 'migration-threshold');

    record_info('Cluster check', 'Checking state of cluster resources');
    check_cluster_state();

    # Check resource fail count - must be 0
    $fail_count = crm_get_failcount(crm_resource => $resource_name, assert_result => 'yes');
    record_info("Fail count: $fail_count", "Fail count is $fail_count");

    # record initial resource location
    my $initial_res_location = crm_resource_locate(crm_resource => $resource_name);

    # Kill sapinstance process
    my $process_name;
    $process_name = 'en.sap' if $instance_type eq 'ASCS';
    $process_name = 'er.sap' if $instance_type eq 'ERS';
    die "Unknown instance type: '$instance_type'" unless $process_name;

    record_info('PROC list', script_output("ps -ef | grep $process_name"));    # Show SAP processes running
    my $pid = script_output("pgrep $process_name");
    die "Sapinstance $instance_type process ID not found" unless $pid;
    record_info('KILL INST', "Killing $instance_type sapinstance process");
    assert_script_run("kill -9 $pid");

    # Check if sapinstance process was killed
    record_info('PROC list', script_output("ps -ef | grep $process_name"));
    script_retry("pgrep $process_name",
        expect => 1,    # pgrep returns 1 if process was not found
        delay => 1,    # short delay in case process gets up too quickly
        timeout => 30,    # 30 sec is plenty
        fail_message => "$instance_type process still running after being killed."
    );

    record_info('Cluster wait', 'Waiting for cluster detecting failure');
    # Wait till fail count increases
    $fail_count = crm_wait_failcount(crm_resource => $resource_name);
    record_info("Fail count: $fail_count", "Fail count is $fail_count");

    record_info('Res cleanup', 'Cleaning up resources using "crm resource cleanup"');
    rsc_cleanup($resource_name);
    wait_until_resources_started();
    wait_for_idle_cluster();
    record_info('Cluster check', 'Checking state of cluster resources');
    check_cluster_state();

    # Resource must not be moved - compare current location with initial one.
    die "Cluster resource '$resource_name' is not on the original node." if
      (crm_resource_locate(crm_resource => $resource_name) ne $initial_res_location);

    # Show status of local instances
    sap_show_status_info(cluster => 1, netweaver => 1, instance_id => $instances_data[0]->{instance_id});

    disconnect_target_from_serial();
}
1;
