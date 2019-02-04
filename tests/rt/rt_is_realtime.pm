# SUSE's openQA tests
#
# Copyright © 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Check that realtime kernel is running
# Maintainer: mkravec <mkravec@suse.com>

use base "opensusebasetest";
use strict;
use testapi;

sub run {
    assert_script_run "uname -v | grep 'PREEMPT RT'";
    assert_script_run "grep 1 /sys/kernel/realtime";
}

sub test_flags {
    return {fatal => 1};
}


1;
