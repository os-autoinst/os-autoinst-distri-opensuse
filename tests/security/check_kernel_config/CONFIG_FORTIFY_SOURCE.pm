# Copyright (C) 2020 SUSE LLC
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with this program; if not, see <http://www.gnu.org/licenses/>.
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

sub run {
    my $self = shift;
    $self->select_serial_terminal;

    # Check the kernel configuration file to make sure the parameter is enabled by default
    assert_script_run "cat /boot/config-`uname -r` | grep 'CONFIG_FORTIFY_SOURCE=y'";
    assert_script_run "zcat /proc/config.gz | grep CONFIG_FORTIFY_SOURCE=y";

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
