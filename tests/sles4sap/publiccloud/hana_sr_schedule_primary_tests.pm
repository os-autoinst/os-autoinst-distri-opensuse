# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP
# Summary: Test module for scheduling multiple instances of tests which target "Master" HANA database.
# Maintainer: QE-SAP <qe-sap@suse.de>

=head1 NAME

sles4sap/publiccloud/hana_sr_schedule_primary_tests.pm - Schedules tests targeting the primary HANA database.

=head1 DESCRIPTION

This module schedules multiple instances of the 'sles4sap/publiccloud/hana_sr_takeover'
test. It is designed to test the high-availability and disaster recovery capabilities
of a SAP HANA System Replication setup. The module iterates through a list of actions
(e.g., 'stop', 'kill', 'crash') and applies them to the primary HANA database at each
site, triggering a takeover by the secondary site.

=head1 SETTINGS

=over

=item B<HANASR_PRIMARY_ACTIONS>

An optional, comma-separated list of actions to be performed on the primary HANA
database. This overrides the default list of actions, which is 'stop,kill,crash'.

=back

=head1 MAINTAINER

QE-SAP <qe-sap@suse.de>

=cut

package hana_sr_schedule_primary_tests;

use base 'sles4sap::sles4sap_publiccloud_basetest';
use sles4sap::sles4sap_publiccloud;
use testapi;
use main_common 'loadtest';

sub test_flags {
    return {fatal => 1, publiccloud_multi_module => 1};
}

sub run {
    my ($self, $run_args) = @_;

    # Needed to have peering and ansible state propagated in post_fail_hook
    $self->import_context($run_args);

    record_info("Schedule", "Executing tests on master Hana DB");
    my @hana_sites = get_hana_site_names();
    # 'HANASR_PRIMARY_ACTIONS' - define to override test flow
    my @database_actions = split(",", get_var("HANASR_PRIMARY_ACTIONS", 'stop,kill,crash'));
    for my $action (@database_actions) {
        for my $site (@hana_sites) {
            my $test_name = join('_', ucfirst($action), "$site-primary");
            $run_args->{hana_test_definitions}{$test_name}{action} = $action;
            $run_args->{hana_test_definitions}{$test_name}{site_name} = $site;
            loadtest('sles4sap/publiccloud/hana_sr_takeover', name => $test_name, run_args => $run_args, @_);
        }
    }
}

1;
