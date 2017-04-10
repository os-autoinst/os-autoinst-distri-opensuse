# Copyright (C) 2015-2016 SUSE LLC
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

# Summary: autoyast specific log file gathering
#    - split repos.pm into separater tests
#    - changed order of tests, run the specific tests in autoyast_verify
#      earlier
# Maintainer: Vladimir Nadvornik <nadvornik@suse.cz>

use strict;
use base 'basetest';
use testapi;

sub run {
    my $self = shift;
    $self->result('ok');    # default result

    # save all logs that might be useful

    type_string "systemctl status > /var/log/systemctl_status\n";
    type_string
"tar cjf /tmp/logs.tar.bz2 --exclude=/etc/{brltty,udev/hwdb.bin} --exclude=/var/log/{YaST2,zypp,{pbl,zypper}.log} /var/{log,adm/autoinstall} /run/systemd/system/ /usr/lib/systemd/system/ /boot/grub2/{device.map,grub{.cfg,env}} /etc/\n";
    upload_logs "/tmp/logs.tar.bz2";

    #on high load, wait_idle is not enough
    type_string "echo UPLOADFINISH >/dev/$serialdev\n";
    wait_serial("UPLOADFINISH", 200);

    wait_idle(30);
    save_screenshot;
}

1;

# vim: set sw=4 et:
