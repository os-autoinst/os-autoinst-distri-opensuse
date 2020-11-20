# Copyright (C) 2017-2020 SUSE LLC
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
# Summary: test for 'zypper lifecycle' for toolchain module
# Maintainer: Rodion Iafarov <riafarov@suse.com>
# Tags: fate#322050

use base "consoletest";
use strict;
use warnings;
use testapi;
use utils 'zypper_call';

sub run {
    my %expiration = (
        gcc6  => 'Now',
        gcc7  => 'Now',
        gcc8  => 'Now',
        gcc9  => '2021-05',
        gcc10 => '2024-10',
    );

    select_console 'root-console';
    zypper_call("in sle-module-toolchain-release " . join(' ', keys %expiration), timeout => 1500);
    for my $package (sort keys %expiration) {
        # Get lifecycle information for installed toolchain packages
        my $output = script_output "zypper lifecycle $package", 300;
        diag($output);
        my $expected_date = $expiration{$package};
        if ($output !~ m/.*\Q$package\E\s*$expected_date.*/) {
            die("For toolchain module $package expected $expected_date as expiration date, lifecycle output:\n $output");
        }
    }
}

1;
