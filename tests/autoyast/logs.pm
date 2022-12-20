# Copyright 2015-2016 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

# Summary: autoyast specific log file gathering
#    - split repos.pm into separator tests
#    - changed order of tests, run the specific tests in autoyast_verify
#      earlier
# Maintainer: Vladimir Nadvornik <nadvornik@suse.cz>

use strict;
use warnings;
use base 'basetest';
use testapi;

sub run {
    my $self = shift;
    $self->result('ok');    # default result

    # save all logs that might be useful

    enter_cmd "systemctl status > /var/log/systemctl_status";
    type_string
"tar cjf /tmp/logs.tar.bz2 --exclude=/etc/{brltty,udev/hwdb.bin} --exclude=/var/log/{YaST2,zypp,{pbl,zypper}.log} /var/{log,adm/autoinstall} /run/systemd/system/ /usr/lib/systemd/system/ /boot/grub2/{device.map,grub{.cfg,env}} /etc/\n";
    upload_logs "/tmp/logs.tar.bz2";
    enter_cmd "echo UPLOADFINISH >/dev/$serialdev";
    wait_serial("UPLOADFINISH", 200);
    save_screenshot;
}

1;

