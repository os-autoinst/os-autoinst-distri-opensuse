# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP
# Summary: Test module for scheduling multiple instances of tests which target secondary HANA database.
# Maintainer: QE-SAP <qe-sap@suse.de>

=head1 NAME

sles4sap/publiccloud/hana_sr_schedule_replica_tests.pm - Schedules tests targeting the secondary (replica) HANA database.

=head1 DESCRIPTION

This module schedules multiple instances of the 'sles4sap/publiccloud/hana_sr_test_secondary'
test. It is designed to test the resilience and behavior of the secondary (replica)
HANA database in a System Replication setup. The module iterates through a list of
actions (e.g., 'stop', 'kill', 'crash') and applies them to the secondary HANA
database.

=head1 SETTINGS

=over

=item B<HANASR_SECONDARY_ACTIONS>

An optional, comma-separated list of actions to be performed on the secondary HANA
database. This overrides the default list of actions, which is 'stop,kill,crash'.

=back

=head1 MAINTAINER

QE-SAP <qe-sap@suse.de>

=cut

package hana_sr_schedule_replica_tests;

use base 'sles4sap::publiccloud_basetest';
use testapi;
use main_common 'loadtest';

sub test_flags {
    return {fatal => 1, publiccloud_multi_module => 1};
}

sub run {
    my ($self, $run_args) = @_;

    # Needed to have peering and ansible state propagated in post_fail_hook
    $self->import_context($run_args);

    record_info("Schedule", "Executing tests on secondary site (replica)");
    # 'HANASR_SECONDARY_ACTIONS' - define to override test flow
    my @database_actions = split(",", get_var("HANASR_SECONDARY_ACTIONS", 'stop,kill,crash'));

    for my $action (@database_actions) {
        my $test_name = ucfirst($action) . "_replica";
        $run_args->{hana_test_definitions}{$test_name} = $action;
        loadtest('sles4sap/publiccloud/hana_sr_test_secondary', name => $test_name, run_args => $run_args, @_);
    }
}

1;
