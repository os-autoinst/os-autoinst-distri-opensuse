# SUSE's openQA tests
#
# Copyright © 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# G-Summary: QAM Minimal test in openQA
#    it prepares minimal instalation, boot it, install tested incident , try
#    reboot and update system with all released updates.
#
#    with QAM_MINIMAL=full it also installs gnome-basic, base, apparmor and
#    x11 patterns and reboot system to graphical login + start console and
#    x11 tests
# G-Maintainer: Ondřej Súkup <osukup@suse.cz>

use base "consoletest";

use strict;
use warnings;

use qam;
use testapi;

sub run {
    select_console 'root-console';
    # we should get the same IP setup after every reboot, but for now
    # we can't assert this
    script_run("diff -u /tmp/ip_a_before.log /tmp/ip_a_after.log");
    save_screenshot;
    script_run("diff -u /tmp/ip_r_before.log /tmp/ip_r_after.log");
    save_screenshot;
}

1;
