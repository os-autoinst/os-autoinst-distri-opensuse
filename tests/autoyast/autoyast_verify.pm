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
use lockapi;

sub run {
    my $self = shift;
    $self->result('fail'); # default result

    #wait for supportserver if not yet ready
    my $roles_r = get_var_array('SUPPORT_SERVER_ROLES');
    foreach my $role (@$roles_r) {
        #printf("rolemutex=$role\n");#debug
        mutex_lock($role);
        mutex_unlock($role);
    }   
      
    #todo: get the ip addresses by some function (or ENV)
    my $verify_url = autoinst_url();
    my $server_ip = '10.0.2.1';
    type_string "curl '" . $verify_url . "/data/" . get_var("AUTOYAST_VERIFY") . "' | sed -e 's|#SERVER_URL#|" . $server_ip . "|g' > verify.sh\n";
    wait_idle(90);
    type_string "chmod 755 verify.sh\n";
    type_string "./verify.sh | tee /dev/$serialdev\n";
    my $success = 0;
    $success = 1 if wait_serial("AUTOYAST OK", 100);
    wait_idle(10);
    type_string "tar cjf /tmp/logs.tar.bz2 --exclude=/etc/{brltty,udev/hwdb.bin} --exclude=/var/log/{YaST2,zypp,{pbl,zypper}.log} /var/{log,adm/autoinstall} /run/systemd/system/ /usr/lib/systemd/system/ /boot/grub2/{device.map,grub{.cfg,env}} /etc/\n";
    upload_logs "/tmp/logs.tar.bz2";
    wait_idle(30);
    save_screenshot;
    die unless $success;
    $self->result('ok');
}

sub test_flags {
    # without anything - rollback to 'lastgood' snapshot if failed
    # 'fatal' - whole test suite is in danger if this fails
    # 'milestone' - after this test succeeds, update 'lastgood'
    # 'important' - if this fails, set the overall state to 'fail'
    return { fatal => 1 };
}

1;

# vim: set sw=4 et:
