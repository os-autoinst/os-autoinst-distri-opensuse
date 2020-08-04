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
# Summary: This test prepares environment
# Maintainer: Pavel Dostál <pdostal@suse.cz>

use base "consoletest";
use xen;
use strict;
use warnings;
use testapi;
use utils;
use version_utils;

sub run {
    my ($self) = @_;
    $self->select_serial_terminal;

    assert_script_run "rm /etc/zypp/repos.d/SUSE_Maintenance* || true";
    assert_script_run "rm /etc/zypp/repos.d/TEST* || true";
    zypper_call '-t in nmap iputils bind-utils', exitcode => [0, 102, 103, 106];

    # Fill the current pairs of hostname & address into /etc/hosts file
    assert_script_run "echo \"\$(dig +short $xen::guests{$_}->{ip}) $_ # virtualization\" >> /etc/hosts" foreach (keys %xen::guests);
    assert_script_run "cat /etc/hosts";
}

sub test_flags {
    return {fatal => 1, milestone => 1};
}

1;

