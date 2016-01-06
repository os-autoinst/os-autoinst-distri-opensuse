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
                            # verify that all repos are available
                            # this checks also network connectivity
    type_string "ip addr\n";
    type_string "zypper ref | tee /dev/$serialdev";
    send_key "ret";
    if (!wait_serial("All repositories have been refreshed", 100)) {
        send_key "ctrl-c";
        send_key "ret";
        sleep 1;
        send_key "ctrl-c";
        send_key "ret";
        sleep 1;
        send_key "ctrl-c";
        send_key "ret";
        sleep 1;
        send_key "ctrl-c";
        send_key "ret";
        sleep 1;
        type_string "save_y2logs /tmp/y2logs.tar.bz2\n";
        # use fixed IP addr
        my $n = get_var("NICMAC");
        $n =~ s/.*://;
        $n = 120 + $n;
        type_string "ip link set eth0 up ; ip addr add 10.0.2.$n/24 dev eth0 \n";
        type_string "ip addr\n";
        wait_idle(30);
        upload_logs "/tmp/y2logs.tar.bz2";
        $self->result('fail');
    }
    else {
        # make sure that save_y2logs from yast2 package and tar is installed
        # even on minimal system
        type_string "zypper -n --no-gpg-checks in yast2 tar\n";

        type_string "save_y2logs /tmp/y2logs.tar.bz2\n";
        upload_logs "/tmp/y2logs.tar.bz2";
    }
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
