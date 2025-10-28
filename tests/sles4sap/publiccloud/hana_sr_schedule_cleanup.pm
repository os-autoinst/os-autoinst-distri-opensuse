# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP
# Maintainer: QE-SAP <qe-sap@suse.de>
# Summary: Test module schedules cleanup at the end of the test queue.

=head1 NAME

hana_sr_schedule_cleanup.pm - Schedules the cleanup test module.

=head1 DESCRIPTION

This module schedules the 'sles4sap/publiccloud/qesap_cleanup' test module to be executed at the end of the test queue.
This is necessary to ensure that resource cleanup is the very last action performed, especially when other test modules
also use 'loadtest' to schedule tests.

=head1 SETTINGS

This module does not have any specific settings. It passes the test run arguments to the scheduled cleanup module.

=head1 MAINTAINER

QE-SAP <qe-sap@suse.de>

=cut

package hana_sr_schedule_cleanup;

use base 'sles4sap_publiccloud_basetest';
use testapi;
use main_common 'loadtest';

sub test_flags {
    return {fatal => 1, publiccloud_multi_module => 1};
}

sub run {
    my ($self, $run_args) = @_;

    # Needed to have peering and ansible state propagated in post_fail_hook
    $self->import_context($run_args);

    record_info("Schedule", "Schedule cleanup job");
    # A test module only to schedule another test module
    # It is needed to be sure that qesap_cleanup is executed as last test step
    # Direct schedule of qesap_cleanup is not possible
    # due to the fact that hana_sr_schedule_cleanup is scheduled
    # with other test modules that are also using loadtest
    loadtest('sles4sap/publiccloud/qesap_cleanup', name => "Cleanup_resources", run_args => $run_args, @_);
}

1;
