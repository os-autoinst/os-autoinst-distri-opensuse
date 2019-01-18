# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Full patch system using zypper
# Maintainer: Oliver Kurz <okurz@suse.de>

use base "console_yasttest";
use strict;
use warnings;
use testapi;
use utils;

sub run {
    select_console 'root-console';
    pkcon_quit;
    fully_patch_system;
    assert_script_run("rpm -q libzypp zypper");

    # XXX: does this below make any sense? what if updates got
    # published meanwhile?
    clear_console;    # clear screen to see that second update does not do any more
    zypper_call("-q patch");
}

sub test_flags {
    return {milestone => 1, fatal => 1};
}

1;
