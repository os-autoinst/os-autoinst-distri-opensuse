# SUSE's openQA tests
#
# Copyright (c) 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

use strict;
use base "consoletest";
use testapi;



sub run() {
    select_console 'root-console';

    # check network at first
    assert_script_run("if ! systemctl -q is-active network; then systemctl -q start network; fi");

    # install xorg-x11 at first
    assert_script_run("/usr/bin/zypper -n -q in xorg-x11 ");

    # start Remote Administration configuration
    script_run("/sbin/yast2 remote; echo yast2-remote-status-\$? > /dev/$serialdev", 0);

    # check Remote Administration VNC got started
    assert_screen 'yast2_vnc_remote_administration';

    # enable remote administration
    send_key 'alt-a';

    # open port in firewall if it is eanbaled and check network interfaces, check long text by send key right.
    if (check_screen 'yast2_vnc_open_port_firewall') {
        send_key 'alt-p';
        send_key 'alt-d';
        assert_screen 'yast2_vnc_firewall_port_details';
        send_key 'alt-e';
        for (1 .. 5) { send_key 'right'; }
        send_key 'alt-a';
        send_key 'alt-o';
    }

    # finish configuration with OK
    send_key 'alt-o';

    # confirm with OK for Warning dialogue
    assert_screen 'yast2_vnc_warning_text';
    send_key 'alt-o';

    wait_serial('yast2-remote-status-0', 60) || die "'yast2 remote' didn't finish";

    # check vnc port is listening
    assert_script_run("/bin/netstat -tl | grep 5901 | grep LISTEN");

}
1;

# vim: set sw=4 et:
