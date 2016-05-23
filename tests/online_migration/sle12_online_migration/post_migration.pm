# SLE12 online migration tests
#
# Copyright © 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

use base "installbasetest";
use strict;
use testapi;
use utils;

sub run() {
    my $self = shift;
    select_console 'root-console';

    # print repos to screen and serial console after online migration
    wait_still_screen;
    script_run("zypper lr -u | tee /dev/$serialdev");
    save_screenshot;

    # reboot into upgraded system after online migration
    if (check_var("FLAVOR", "Desktop-DVD")) {
        record_soft_failure 'bsc#989696: [online migration] systemctl reboot hangs after migration from sled12 to sled12sp2';
        script_run("reboot", 0);
    }
    else {
        script_run("systemctl reboot", 0);
    }
    save_screenshot;

    wait_boot textmode => !is_desktop_installed;
}

sub test_flags {
    return {important => 1};
}

1;
# vim: set sw=4 et:
