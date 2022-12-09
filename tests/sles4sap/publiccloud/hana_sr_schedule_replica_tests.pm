# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP
# Maintainer: QE-SAP <qe-sap@suse.de>
# Summary: Test module for scheduling multiple instances of tests which target secondary HANA database.
#
# Parameters:
#  HANASR_SECONDARY_ACTIONS - optional, override list of fencing actions

package hana_sr_schedule_replica_tests;

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
    record_info("Schedule", "Executing tests on secondary site (replica)");
    # 'HANASR_SECONDARY_ACTIONS' - define to override test flow
    my @database_actions = split(",", get_var("HANASR_SECONDARY_ACTIONS", 'stop,kill,crash'));

    for my $action (@database_actions) {
        my $test_name = ucfirst($action) . " replica";
        $run_args->{hana_test_definitions}{$test_name} = $action;
        loadtest('sles4sap/publiccloud/hana_sr_test_secondary', name => $test_name, run_args => $run_args, @_);
    }
}

1;
