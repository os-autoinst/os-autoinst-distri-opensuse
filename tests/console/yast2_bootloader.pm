# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Basic test for yast2 bootloader
# Maintainer: Oliver Kurz <okurz@suse.de>

use base "console_yasttest";
use strict;
use testapi;
use utils;

# test yast2 bootloader functionality
# https://bugzilla.novell.com/show_bug.cgi?id=610454

sub run() {
    select_console 'root-console';

    assert_script_run "zypper -n in yast2-bootloader";    # make sure yast2 bootloader module installed

    script_run("/sbin/yast2 bootloader; echo yast2-bootloader-status-\$? > /dev/$serialdev", 0);
    assert_screen "test-yast2_bootloader-1", 300;
    send_key "alt-o";                                     # OK => Close
    assert_screen([qw(yast2_bootloader-missing_package yast2_console-finished)]);
    if (match_has_tag('yast2_bootloader-missing_package')) {
        wait_screen_change { send_key 'alt-i'; };
    }
    assert_screen 'yast2_console-finished';
    wait_serial("yast2-bootloader-status-0", 150) || die "'yast2 bootloader' didn't finish";
}

1;
# vim: set sw=4 et:
