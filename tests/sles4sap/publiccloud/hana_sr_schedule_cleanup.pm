# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP
# Maintainer: QE-SAP <qe-sap@suse.de>
# Summary: Test module schedules cleanup at the end of the test queue.

package hana_sr_schedule_cleanup;

use strict;
use warnings FATAL => 'all';
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
    loadtest('sles4sap/publiccloud/qesap_cleanup', name => "Cleanup resources", run_args => $run_args, @_);
}

1;
