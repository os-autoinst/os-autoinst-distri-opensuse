# SUSE's openQA tests
#
# Copyright © 2020 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Run test executed by TEST-36-NUMAPOLICY from upstream after openSUSE/SUSE patches.
# Maintainer: Sergio Lindo Mansilla <slindomansilla@suse.com>, Thomas Blume <tblume@suse.com>

use base 'systemd_testsuite_test';
use warnings;
use strict;
use testapi;

sub run {
    my ($self) = @_;
    my $test = 'TEST-36-NUMAPOLICY';


    #run test
    my $timeout = 1200;
    assert_script_run "NO_BUILD=1 make -C test/$test clean setup run 2> /tmp/testerr.log", $timeout;
}

sub test_flags {
    return {always_rollback => 1};
}


1;
