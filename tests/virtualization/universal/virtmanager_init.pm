# Copyright (C) 2019 SUSE LLC
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
# Package: virt-manager
# Summary: This test connects to hypervisor and check our VMs
# Maintainer: Pavel Dostal <pdostal@suse.cz>, Felix Niederwanger <felix.niederwanger@suse.de>

use base "virt_feature_test_base";
use virt_autotest::common;
use virt_autotest::utils;
use strict;
use warnings;
use testapi;
use utils;
use virtmanager;

sub run_test {
    my ($self) = @_;
    select_console 'root-console';

    zypper_call '-t in virt-manager', exitcode => [0, 4, 102, 103, 106];

    # Ensure additional devices are removed (if present).
    # This is necessary for restarting the virtmanager tests, as we assume the state is clear.
    foreach my $guest (keys %virt_autotest::common::guests) {
        next if ($guest == "");
        remove_additional_nic($guest, "00:16:3e:32");
        remove_additional_disks($guest);
    }

    #x11_start_program 'virt-manager';
    enter_cmd "virt-manager";

    establish_connection();

    wait_screen_change { send_key 'ctrl-q'; };
}

sub test_flags {
    return {fatal => 1, milestone => 1};
}

1;

