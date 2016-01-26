# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

use base "console_yasttest";
use testapi;
use utils;

# test yast2 bootloader functionality
# https://bugzilla.novell.com/show_bug.cgi?id=610454

sub run() {
    become_root;

    assert_script_run "zypper -n in yast2-bootloader";    # make sure yast2 bootloader module installed

    script_run("/sbin/yast2 bootloader; echo YBL-$? > /dev/$serialdev", 0);
    assert_screen "test-yast2_bootloader-1", 300;
    send_key "alt-o";                                     # OK => Close
    die "yastootloader failed" unless wait_serial "YBL-0";

    type_string "exit\n";
}

1;
# vim: set sw=4 et:
