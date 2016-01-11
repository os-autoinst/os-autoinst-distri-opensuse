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

# test yast2 bootloader functionality
# https://bugzilla.novell.com/show_bug.cgi?id=610454

sub run() {
    my $self = shift;

    assert_script_sudo "zypper -n in yast2-bootloader";    # make sure yast2 bootloader module installed

    script_sudo("/sbin/yast2 bootloader");
    my $ret = assert_screen "test-yast2_bootloader-1", 300;
    send_key "alt-o";                                      # OK => Close
    assert_screen 'exited-bootloader', 150;
    send_key "ctrl-l";
    script_run("echo \"EXIT-\$?\" > /dev/$serialdev");
    die unless wait_serial "EXIT-0", 2;
    script_run('rpm -q hwinfo');
    save_screenshot;
}

1;
# vim: set sw=4 et:
