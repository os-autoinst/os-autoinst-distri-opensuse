# Copyright 2020 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Summary: FORTIFY_SOURCE is very stable in userland, so this can be enabled with little impact in the kernel.
#          From SLES15SP3, we added this kernel parameter check on all platforms.
# Maintainer: QE Security <none@suse.de>
# Tags: poo#73498, tc#1768633

use base 'opensusebasetest';
use strict;
use warnings;
use testapi;
use serial_terminal 'select_serial_terminal';
use utils;

sub run {
    my $self = shift;
    select_serial_terminal;

    # Check the kernel configuration file to make sure the parameter is enabled by default
    assert_script_run "grep CONFIG_FORTIFY_SOURCE=y /boot/config-`uname -r`";
    assert_script_run "zgrep CONFIG_FORTIFY_SOURCE=y /proc/config.gz";

    # Check the syslog and 'dmesg' output to make sure no error or warning messages
    if (script_run("dmesg | grep -i FORTIFY") == 0) {
        die("Error: please check dmesg log for FORTIFY failure");
    }
    if (script_run("grep -i FORTIFY /var/log/messages") == 0) {
        die("Error: please check syslog for FORTIFY failure");
    }
}

1;
