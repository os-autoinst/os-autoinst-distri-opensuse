# SUSE's openQA tests
#
# Copyright © 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

use base "opensusebasetest";
use strict;
use testapi;

# Check that realtime kernel is running
sub run() {
    assert_script_run "uname -v | grep -qo 'PREEMPT RT'";
    assert_script_run "grep -q 1 /sys/kernel/realtime";
}

sub test_flags() {
    return {important => 1};
}

1;
