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
    script_run("systemctl reboot", 0);
    if (get_var("DESKTOP") =~ /textmode|minimalx/) {
        wait_boot textmode => 1;
    }
    else {
        wait_boot;
    }
}

sub test_flags {
    return {important => 1};
}

1;
# vim: set sw=4 et:
