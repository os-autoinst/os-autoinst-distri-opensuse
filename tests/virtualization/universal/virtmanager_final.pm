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
# Summary: This test turns just check all VMs
# Maintainer: Pavel Dostál <pdostal@suse.cz>

use base "virt_feature_test_base";
use virt_autotest::common;
use strict;
use warnings;
use testapi;
use utils;
use virtmanager;

sub run_test {
    select_console 'root-console';
    zypper_call '-t in virt-manager', exitcode => [0, 4, 102, 103, 106];

    #x11_start_program 'virt-manager';
    enter_cmd "virt-manager";

    establish_connection();

    foreach my $guest (keys %virt_autotest::common::guests) {
        record_info "$guest", "VM $guest will be turned off and then on again";

        select_guest($guest);

        detect_login_screen();

        close_guest();
    }

    wait_screen_change { send_key 'ctrl-q'; };
}

1;

