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
# Summary: This test install the virt-manager libvirt GUI
# Maintainer: Pavel Dostál <pdostal@suse.cz>

use base "consoletest";
use strict;
use testapi;
use utils;
use mm_network qw(configure_static_dns get_host_resolv_conf);

sub run {
    my ($self) = @_;
    select_console 'root-console';
    opensusebasetest::select_serial_terminal();

    configure_static_dns(get_host_resolv_conf());

    zypper_call 'in virt-manager nmap';
    systemctl 'stop ' . $self->firewall;
    systemctl 'disable ' . $self->firewall;
}

sub test_flags {
    return {fatal => 1, milestone => 0};
}

1;

