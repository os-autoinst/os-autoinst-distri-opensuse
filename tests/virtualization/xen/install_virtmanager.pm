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

use base "x11test";
use strict;
use testapi;
use utils;

sub run {
    my ($self) = @_;
    select_console 'x11';

    x11_start_program('xterm');
    send_key 'super-up';
    become_root;
    zypper_call 'in virt-manager';
    systemctl 'stop ' . $self->firewall;
    systemctl 'disable ' . $self->firewall;
    wait_screen_change { send_key 'alt-f4'; };

}

sub test_flags {
    return {fatal => 1, milestone => 0};
}

1;

