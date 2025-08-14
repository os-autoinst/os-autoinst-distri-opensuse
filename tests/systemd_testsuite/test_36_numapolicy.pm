# SUSE's openQA tests
#
# Copyright 2020 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Run test executed by TEST-36-NUMAPOLICY from upstream after openSUSE/SUSE patches.
# Maintainer: Sergio Lindo Mansilla <slindomansilla@suse.com>, Thomas Blume <tblume@suse.com>

use base 'systemd_testsuite_test';
use testapi;

sub pre_run_hook {
    my ($self) = @_;
    #prepare test
    $self->testsuiteprepare('TEST-36-NUMAPOLICY');
}

sub run {
    #run test
    my $timeout = 1200;
    assert_script_run 'cd /usr/lib/systemd/tests';
    assert_script_run './run-tests.sh TEST-36-NUMAPOLICY --run 2>&1 | tee /tmp/testsuite.log', $timeout;
    assert_script_run 'grep "PASS: ...TEST-36-NUMAPOLICY" /tmp/testsuite.log';
    script_run './run-tests.sh TEST-36-NUMAPOLICY --clean';
}

sub test_flags {
    return {always_rollback => 1};
}


1;
