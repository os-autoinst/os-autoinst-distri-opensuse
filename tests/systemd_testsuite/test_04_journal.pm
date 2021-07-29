# SUSE's openQA tests
#
# Copyright 2019-2020 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Run test executed by TEST-04-JOURNAL from upstream after openSUSE/SUSE patches.
# Maintainer: Sergio Lindo Mansilla <slindomansilla@suse.com>, Thomas Blume <tblume@suse.com>

use base 'systemd_testsuite_test';
use warnings;
use strict;
use testapi;

sub pre_run_hook {
    my ($self) = @_;
    #prepare test
    $self->testsuiteprepare('TEST-04-JOURNAL');
}

sub run {
    #run test
    my $timeout = get_var('SYSTEMD_TEST_DEFAULT_TIMEOUT') || 180;
    assert_script_run 'cd /usr/lib/systemd/tests';
    assert_script_run './run-tests.sh TEST-04-JOURNAL --run 2>&1 | tee /tmp/testsuite.log', $timeout;
    assert_script_run 'grep "PASS: ...TEST-04-JOURNAL" /tmp/testsuite.log';
}

sub test_flags {
    return {always_rollback => 1};
}


1;
