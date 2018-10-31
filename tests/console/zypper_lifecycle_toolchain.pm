# Copyright (C) 2017 SUSE LLC
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
use testapi;
use utils 'zypper_call';

sub run {
    my %expiration = (
        gcc5      => 'Now',
        libada5   => 'Now',
        gcc6      => 'Now',
        gcc7      => '2024-10-30',
        libada7   => '2024-10-30',
        toolchain => '2024-10-30',
    );

    select_console 'root-console';
    # Get gcc packages, ignore conflicting gcc6-ada and libada6 and cross-nvptx-newlib7 packages
    my $gcc_packages
      = script_output "zypper -q se -ur SLE-Module-Toolchain12-Updates -t package | awk -F '|' '{print \$2}' | tail -n +3 | grep -vE '(gcc6-ada|libada6|cross-nvptx-newlib7)'", 300;
    # Create list by removing blank symbols and new lines
    $gcc_packages =~ s/(\R|\s)+/ /g;
    # Install gcc packages
    zypper_call("in $gcc_packages");
    # Get lifecycle information for installed toolchain packages
    my $output = script_output "zypper lifecycle $gcc_packages", 300;
    diag($output);
    # Verify that for gcc5 "now" is shown as expiration date, for gcc6 C<$expected_date>
    for my $package (split(/ /, $gcc_packages)) {
        while (my ($package_regexp, $expected_date) = each %expiration) {
            if ($package =~ m/.*$package_regexp.*/ && $output !~ m/.*\Q$package\E\s*$expected_date.*/) {
                die("For toolchain module $package expected $expected_date as expiration date, lifecycle output:\n $output");
            }
        }
    }

}

1;
