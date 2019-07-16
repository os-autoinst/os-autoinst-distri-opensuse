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
# Summary: Obtain the dom0 metrics
# Maintainer: Pavel Dostál <pdostal@suse.cz>

use base "consoletest";
use xen;
use strict;
use warnings;
use testapi;
use utils;

sub run {
    my $hypervisor = get_var('HYPERVISOR') // '127.0.0.1';

    assert_script_run 'vhostmd';

    foreach my $guest (keys %xen::guests) {
        record_info "$guest",                                                     "Obtaining dom0 metrics on xl-$guest";
        assert_script_run "xl block-attach xl-$guest /dev/shm/vhostmd0,,xvdc,ro", 90;
        assert_script_run "ssh root\@$guest 'vm-dump-metrics' | grep 'SUSE LLC'";
        assert_script_run "xl block-detach xl-$guest xvdc";
    }
}

sub test_flags {
    return {fatal => 1, milestone => 0};
}

1;

