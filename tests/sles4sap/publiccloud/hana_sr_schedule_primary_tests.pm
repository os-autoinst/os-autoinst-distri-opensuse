# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP
# Maintainer: QE-SAP <qe-sap@suse.de>
# Summary: Test module for scheduling multiple instances of tests which target "Master" HANA database.
#
# Parameters:
#  HANASR_PRIMARY_ACTIONS - optional, override list of fencing actions

package hana_sr_schedule_primary_tests;

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
    record_info("Schedule", "Executing tests on master Hana DB");
    # 'HANASR_PRIMARY_ACTIONS' - define to override test flow
    my @database_actions = split(",", get_var("HANASR_PRIMARY_ACTIONS", 'stop,kill,crash'));
    for my $action (@database_actions) {
        for my $site ("site_a", "site_b") {
            my $test_name = join(" ", ucfirst($action), $site, "-", "primary");
            $run_args->{hana_test_definitions}{$test_name}{action} = $action;
            $run_args->{hana_test_definitions}{$test_name}{site_name} = $site;
            loadtest('sles4sap/publiccloud/hana_sr_takeover', name => $test_name, run_args => $run_args, @_);
        }
    }
}

1;
