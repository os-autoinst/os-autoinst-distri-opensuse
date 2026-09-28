# Copyright 2015-2020 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

# Package: wicked systemd iproute2 hwinfo
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
# Maintainer: QE Installation and Migration (QE Iam) <none@suse.de>

use Mojo::Base 'consoletest';
use testapi;

sub run {
    # https://en.opensuse.org/openSUSE:Bugreport_wicked
    enter_cmd "systemctl --no-pager status wickedd.service";
    enter_cmd "echo `wicked show all |cut -d ' ' -f 1` END | tee /dev/$serialdev";
    my $iflist = wait_serial("END", 10);
    # For poo#70453, to filter network link from mixed info of the output of wicked cmd
    # we need substr output string from serial. Ex: 'lo0 eth0 END' -> 'eth0'
    ($iflist) =~ s/(.*lo\s)(.*)(\sEND.*)/$2/s;
    $iflist =~ s/^\s*//g;
    $iflist =~ s/\s*$//g;

    my $up = 1;
    for my $if (split(/\s+/, $iflist)) {
        enter_cmd "wicked show '$if' |head -n1|awk '{print\$2}'| tee /dev/$serialdev";
        $up = 0 if !wait_serial("up", 10);
    }
    if (!$up) {
        assert_script_run "mkdir /tmp/wicked";
        # enable debugging
        assert_script_run "perl -i -lpe 's{^(WICKED_DEBUG)=.*}{\$1=\"all\"};s{^(WICKED_LOG_LEVEL)=.*}{\$1=\"debug\"}' /etc/sysconfig/network/config";
        script_run "grep -E \"WICKED_DEBUG|WICKED_LOG_LEVEL\" /etc/sysconfig/network/config ||:";
        # restart the daemons
        script_run "systemctl restart wickedd ||:";
        save_screenshot;
        # reapply the config
        script_run "wicked --debug all ifup all ||:";
        save_screenshot;
        # collect the configuration
        script_run "wicked show-config > /tmp/wicked/config-dump.log ||:";
        # collect the status
        script_run "wicked ifstatus --verbose all > /tmp/wicked/status.log ||:";
        script_run "journalctl -b -o short-precise > /tmp/wicked/wicked.log ||:";
        script_run "ip addr show > /tmp/wicked/ip_addr.log ||:";
        script_run "ip route show table all > /tmp/wicked/routes.log ||:";
        # collect network information
        script_run "hwinfo --netcard > /tmp/wicked/hwinfo-netcard.log ||:";
        script_run "tar -czf /tmp/wicked_logs.tgz /etc/sysconfig/network /tmp/wicked ||:", timeout => 300;
        upload_logs "/tmp/wicked_logs.tgz";
        save_screenshot;
    }
}

1;

