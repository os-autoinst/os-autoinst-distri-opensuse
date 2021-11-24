# Copyright 2020 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Summary: FORTIFY_SOURCE is very stable in userland, so this can be enabled with little impact in the kernel.
#          From SLES15SP3, we added this kernel parameter check on all platforms.
# Maintainer: rfan1 <richard.fan@suse.com>
# Tags: poo#73498, tc#1768633

use base 'opensusebasetest';
use strict;
use warnings;
use testapi;
use utils;
use version_utils 'is_sle';

sub run {
    my $self = shift;
    $self->select_serial_terminal;

    # Check the kernel configuration file to make sure the parameter is enabled by default
    if (is_sle) {
        assert_script_run "cat /boot/config-`uname -r` | grep 'CONFIG_FORTIFY_SOURCE=y'";
        assert_script_run "zcat /proc/config.gz | grep CONFIG_FORTIFY_SOURCE=y";
    } else {
        validate_script_output "zcat /proc/config.gz | grep CONFIG_FORTIFY", qr/CONFIG_FORTIFY_SOURCE is not set/;
    }

    # Check the syslog and 'dmesg' output to make sure no error or warning messages
    my $results = script_run("dmesg | grep -i FORTIFY");
    if (!$results) {
        die("Error: please check dmesg log for FORTIFY failure");
    }
    my $results_1 = script_run("cat /var/log/messages | grep -i FORTIFY");
    if (!$results_1) {
        die("Error: please check syslog for FORTIFY failure");
    }
}

1;
