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
use main_common 'loadtest';
use testapi;

sub test_flags {
    return {fatal => 1, publiccloud_multi_module => 1};
}

sub run {
    my ($self, $run_args) = @_;
    $self->{network_peering_present} = 1 if ($run_args->{network_peering_present});

    record_info("Schedule", "Schedule cleanup job");
    loadtest('sles4sap/publiccloud/qesap_cleanup', name => "Cleanup resources", run_args => $run_args, @_);
}

1;
