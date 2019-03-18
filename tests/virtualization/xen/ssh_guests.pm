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
# Summary: This tries to ping and SSH to every guest we created.
# Maintainer: Pavel Dostál <pdostal@suse.cz>

use base "consoletest";
use xen;
use strict;
use warnings;
use testapi;
use utils;

sub run {
    my ($self) = @_;
    my $hypervisor = get_required_var('HYPERVISOR');

    foreach my $guest (keys %xen::guests) {
        record_info "$guest", "Establishing SSH connection to $guest";
        assert_script_run "ping -c3 -W1 $guest";
        assert_script_run "ssh root\@$guest 'hostname -f; uptime'";
    }
}

1;

