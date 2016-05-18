# SLE12 online migration tests
#
# Copyright © 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

use base "consoletest";
use strict;
use testapi;
use utils;

sub check_rollback_system() {
    # first to check rollback-helper service is enabled and worked properly
    my $output = script_output "systemctl status rollback.service";
    if ($output !~ /enabled.*?code=exited,\sstatus=0\/SUCCESS/s) {
        die "rollback service was failed";
    }

    # second to check if repos were rolled back to original
    script_run("zypper lr -u | tee /dev/$serialdev");
}

sub run() {
    my $self = shift;

    # login to snapshot and perform snapper rollback
    assert_screen 'linux-login', 200;
    select_console 'root-console';
    wait_still_screen;
    script_run "snapper rollback";

    # reboot into the system before online migration
    script_run("systemctl reboot", 0);
    if (get_var("DESKTOP") =~ /textmode|minimalx/) {
        wait_boot textmode => 1;
    }
    else {
        wait_boot;
    }
    select_console 'root-console';

    check_rollback_system;
}

sub test_flags {
    return {important => 1};
}

1;
# vim: set sw=4 et:
