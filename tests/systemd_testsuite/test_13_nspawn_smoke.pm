# SUSE's openQA tests
#
# Copyright © 2019-2020 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Run test executed by TEST-13-NSPAWN-SMOKE from upstream after openSUSE/SUSE patches.
# Maintainer: Sergio Lindo Mansilla <slindomansilla@suse.com>, Thomas Blume <tblume@suse.com>

use base 'systemd_testsuite_test';
use warnings;
use strict;
use testapi;

sub pre_run_hook {
    my ($self) = @_;
    #prepare test
    $self->testsuiteprepare('TEST-13-NSPAWN-SMOKE');
}

sub run {
    #run test
    assert_script_run 'cd /var/opt/systemd-tests';
    assert_script_run './run-tests.sh TEST-13-NSPAWN-SMOKE --run 2>&1 | tee /tmp/testsuite.log', 120;
    assert_script_run 'grep "PASS: ...TEST-13-NSPAWN-SMOKE" /tmp/testsuite.log';
}

sub test_flags {
    return {always_rollback => 1};
}


1;
