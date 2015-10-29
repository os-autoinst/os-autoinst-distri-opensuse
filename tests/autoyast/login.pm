# Copyright (C) 2015 SUSE Linux GmbH
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

use strict;
use base 'y2logsstep';
use testapi;

sub run {
    my $self = shift;
    assert_screen("autoyast-system-login-console", 20);
    $self->result('fail');    # default result
    type_string "root\n";
    sleep 10;
    type_password;
    send_key "ret";
    sleep 10;

    type_string "echo SERIAL OK | tee /dev/$serialdev";
    send_key "ret";
    die unless wait_serial("SERIAL OK", 100);
    wait_idle(10);
    type_string "cat /proc/cmdline\n";
    wait_idle(10);
    save_screenshot;
    $self->result('ok');
}

sub test_flags {
    # without anything - rollback to 'lastgood' snapshot if failed
    # 'fatal' - whole test suite is in danger if this fails
    # 'milestone' - after this test succeeds, update 'lastgood'
    # 'important' - if this fails, set the overall state to 'fail'
    return {fatal => 1};
}

1;

# vim: set sw=4 et:
