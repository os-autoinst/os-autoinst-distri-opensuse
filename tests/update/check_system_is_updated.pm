# SUSE's openQA tests
#
# Copyright © 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Check no more updates are available
# Maintainer: mkravec <mkravec@suse.com>

use base "consoletest";
use strict;
use testapi;

sub run {
    select_console 'root-console';
    assert_script_run "chown $testapi::username /dev/$testapi::serialdev";
    assert_script_run "pkcon refresh";
    assert_script_run "pkcon get-updates | tee /dev/$serialdev | grep 'There are no updates'";
}

sub test_flags {
    return {fatal => 1};
}

1;
# vim: set sw=4 et:
