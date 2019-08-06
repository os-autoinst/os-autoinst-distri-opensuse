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

# Summary: wicked script for more logs if eth0 is not up
# - Check wickedd status
# - Send network interface list to serial output
# - Check each network interface status
# - If any interface fails
#   - Enable wicked debug
#   - Restart wickedd
#   - Bring all interfaces up in debug mode
#   - Save a screenshot
#   - Collect interface config and save
#   - Collect interface status and save
#   - Collect system log and save
#   - Collect route and ip address
#   - Collect network card info
#   - Compress everything and upload the logs
#   - Save a screenshot
# Maintainer: Oliver Kurz <okurz@suse.de>

use strict;
use warnings;
use base 'consoletest';
use testapi;

sub run {
    # https://en.opensuse.org/openSUSE:Bugreport_wicked
    type_string "systemctl status wickedd.service\n";
    type_string "echo `wicked show all |cut -d ' ' -f 1` END | tee /dev/$serialdev\n";
    my $iflist = wait_serial("END", 10);
    $iflist =~ s/\bEND\b//g;
    $iflist =~ s/\blo\b//g;
    $iflist =~ s/^\s*//g;
    $iflist =~ s/\s*$//g;

    my $up = 1;
    for my $if (split(/\s+/, $iflist)) {
        type_string "wicked show '$if' |head -n1|awk '{print\$2}'| tee /dev/$serialdev\n";
        $up = 0 if !wait_serial("up", 10);
    }
    if (!$up) {
        type_string "mkdir /tmp/wicked\n";
        # enable debugging
        type_string "perl -i -lpe 's{^(WICKED_DEBUG)=.*}{\$1=\"all\"};s{^(WICKED_LOG_LEVEL)=.*}{\$1=\"debug\"}' /etc/sysconfig/network/config\n";
        type_string "egrep \"WICKED_DEBUG|WICKED_LOG_LEVEL\" /etc/sysconfig/network/config\n";
        # restart the daemons
        type_string "systemctl restart wickedd\n";
        save_screenshot;
        # reapply the config
        type_string "wicked --debug all ifup all\n";
        save_screenshot;
        # collect the configuration
        type_string "wicked show-config > /tmp/wicked/config-dump.log\n";
        # collect the status
        type_string "wicked ifstatus --verbose all > /tmp/wicked/status.log\n";
        type_string "journalctl -b -o short-precise > /tmp/wicked/wicked.log\n";
        type_string "ip addr show > /tmp/wicked/ip_addr.log\n";
        type_string "ip route show table all > /tmp/wicked/routes.log\n";
        # collect network information
        type_string "hwinfo --netcard > /tmp/wicked/hwinfo-netcard.log\n";
        type_string "tar -czf /tmp/wicked_logs.tgz /etc/sysconfig/network /tmp/wicked\n";
        upload_logs "/tmp/wicked_logs.tgz";
        save_screenshot;
    }
}

1;

