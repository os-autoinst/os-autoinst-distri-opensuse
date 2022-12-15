# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP
# Maintainer: QE-SAP <qe-sap@suse.de>
# Summary: Test module schedules cleanup at the end of the test queue.

package hana_sr_schedule_cleanup;
use base 'sles4sap_publiccloud_basetest';
use main_common 'loadtest';
use strict;
use warnings FATAL => 'all';
use testapi;

sub test_flags {
    return {fatal => 1, publiccloud_multi_module => 1};
}

sub run {
    my ($self, $run_args) = @_;
    record_info("Schedule", "Schedule cleanup job");
    loadtest('sles4sap/publiccloud/qesap_cleanup', name => "Cleanup resources", run_args => $run_args, @_);
}

1;
