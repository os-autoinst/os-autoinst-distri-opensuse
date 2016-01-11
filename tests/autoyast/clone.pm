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
use base 'basetest';
use testapi;

sub run {
    my $self = shift;
    $self->result('ok');    # default result

    type_string "rm -f /root/autoinst.xml\n";

    type_string "yast2 --ncurses clone_system ; echo CLONED >/dev/$serialdev\n";
    while (!wait_serial("CLONED", 200)) {
        $self->result('fail');
        save_screenshot;
        send_key "ret";
    }

    upload_logs "/root/autoinst.xml";

    # original autoyast on kernel cmdline
    upload_logs "/var/adm/autoinstall/cache/installedSystem.xml";
    wait_idle(30);

    type_string "save_y2logs /tmp/y2logs_clone.tar.bz2\n";
    upload_logs "/tmp/y2logs_clone.tar.bz2";
    wait_idle(30);

    save_screenshot;
}

sub test_flags {
    # without anything - rollback to 'lastgood' snapshot if failed
    # 'fatal' - whole test suite is in danger if this fails
    # 'milestone' - after this test succeeds, update 'lastgood'
    # 'important' - if this fails, set the overall state to 'fail'
    return {important => 1};
}

1;

# vim: set sw=4 et:
