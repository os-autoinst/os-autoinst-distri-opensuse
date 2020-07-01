# SUSE's openQA tests
#
# Copyright © 2020 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Run test executed by TEST-39-EXECRELOAD from upstream after openSUSE/SUSE patches.
# Maintainer: Sergio Lindo Mansilla <slindomansilla@suse.com>, Thomas Blume <tblume@suse.com>

use base 'systemd_testsuite_test';
use warnings;
use strict;
use testapi;

sub pre_run_hook {
    my ($self) = @_;
    #prepare test
    $self->testsuiteprepare('TEST-39-EXECRELOAD');
}

sub run {
    #run test
    assert_script_run 'cd /var/opt/systemd-tests';
    assert_script_run './run-tests.sh TEST-39-EXECRELOAD --run 2>&1 | tee /tmp/testsuite.log', 60;
    assert_script_run 'grep "PASS: ...TEST-39-EXECRELOAD" /tmp/testsuite.log';
    script_run './run-tests.sh TEST-39-EXECRELOAD --clean';
}

sub test_flags {
    return {always_rollback => 1};
}


1;
