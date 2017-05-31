# SUSE's openQA tests
#
# Copyright (c) 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: yast2_xinetd checks start and stop of verious server components and add or delete server components
# Maintainer: Zaoliang Luo <zluo@suse.de>

use strict;
use base "console_yasttest";
use testapi;



sub run() {
    select_console 'root-console';

    # check network at first
    assert_script_run("if ! systemctl -q is-active network; then systemctl -q start network; fi");
    # install xinetd at first
    assert_script_run("/usr/bin/zypper -n -q in xinetd");

    script_run("yast2 xinetd; echo yast2-xinetd-status-\$? > /dev/$serialdev", 0);

    # check xinetd network configuration got started
    assert_screen 'yast2_xinetd_startup', 90;

    # enable xinetd
    send_key 'alt-l';
    wait_still_screen 1;

    # toggle status on at first and then off
    send_key 'alt-s';
    wait_still_screen 1;
    send_key 'alt-d';
    wait_still_screen 1;

    # deactivate all services
    assert_screen 'yast2_xinetd_all_deactivated';
    send_key 'alt-s';
    wait_still_screen 1;

    # activate all services
    send_key 'alt-a';
    wait_still_screen 1;

    # try to delete an item which is not installed at all
    send_key 'alt-d';
    assert_screen 'yast2_xinetd_cannot_delete';
    send_key 'alt-o';
    wait_still_screen 1;

    # delete ftp configuration from the list
    send_key_until_needlematch 'yast2_xinetd_ftp_deleted', 'down';
    send_key 'alt-d';
    wait_still_screen 1;
    assert_screen 'yast2_xinetd_cannot_delete_again';
    send_key 'alt-o';

    # add a service
    send_key 'alt-a';
    wait_still_screen 1;
    type_string 'super_ping';
    wait_still_screen 1;
    send_key 'alt-e';
    wait_still_screen 1;
    type_string 'localhost';
    wait_still_screen 1;
    send_key 'alt-m';
    wait_still_screen 1;
    type_string 'fake, useless, nobody should use it, use ping instead of it ;)';
    wait_still_screen 1;
    send_key 'alt-a';
    wait_still_screen 1;

    # close xinetd with finish
    send_key 'alt-f';

    # wait till xinetd got closed
    wait_serial('yast2-xinetd-status-0', 60) || die "'yast2 xinetd' didn't finish";

    # check xinetd configuration
    assert_script_run("systemctl show -p ActiveState xinetd.service | grep ActiveState=active");

}
1;

# vim: set sw=4 et:
