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

# Summary: Test nano editor
# Maintainer: Oliver Kurz <okurz@suse.de>

use base 'consoletest';
use strict;
use warnings;
use testapi;
use utils 'zypper_call';

sub run {
    my ($self) = @_;
    select_console('root-console');
    zypper_call('in nano');
    script_run("nano; echo nano-status-\$? > /dev/$serialdev", 0);
    $self->enter_test_text('nano');
    assert_screen('nano');
    wait_screen_change { send_key 'ctrl-x' };
    send_key 'n';
    wait_serial("nano-status-0") || die "'nano' could not finish successfully";
}

1;

