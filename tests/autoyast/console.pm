# Copyright (C) 2015-2017 SUSE LLC
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

# Summary: Make sure we are logged in
# Maintainer: Oliver Kurz <okurz@suse.de>

use strict;
use base 'y2logsstep';
use testapi;
use utils 'power_action';

sub run {
    my ($self) = @_;
    # trying to change consoles manually because of bsc#1042554
    send_key 'ctrl-alt-f2';
    send_key 'alt-f2';
    if (!check_screen 'text-login') {
        record_soft_failure 'bsc#1042554';
        send_key 'ctrl-alt-delete';
        power_action('reboot', keepconsole => 0, observe => 0);
        $self->wait_boot();
    }
    select_console 'root-console';
}

1;

# vim: set sw=4 et:
