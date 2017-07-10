# SUSE's openQA tests
#
# Copyright © 2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: HPC_Module: Add test for conman  package
#
#    https://fate.suse.com/321724
#
#    This tests the conman package from the HPC module
#
# Maintainer: Matthias Griessmeier <mgriessmeier@suse.com>


use base "opensusebasetest";
use strict;
use testapi;
use utils;
use susedistribution;

sub run() {
    select_console 'root-console';

    # install conman
    pkcon_quit();
    zypper_call('in conman');

    # add serial console to conman.conf
    assert_script_run("echo 'CONSOLE name=\"serial1\" dev=\"/dev/$serialdev\" seropts=\"115200\"' >> /etc/conman.conf");
    assert_script_run("cat /etc/conman.conf");

    # enable and start conmand
    assert_script_run('systemctl enable conman.service');
    assert_script_run('systemctl start conman.service');

    # check service status
    assert_script_run('systemctl status conman');

    # run conman client on serialdev
    type_string("conman serial1\n");
    assert_screen("connection-opened");

    # close connection
    type_string '&.';
    assert_screen("connection-closed");

    # test with unix domain socket
    assert_script_run("echo 'CONSOLE name=\"socket1\" dev=\"unix:/tmp/testsocket\"' >> /etc/conman.conf");

    # run netcat on this socket
    type_string("netcat -ClU /tmp/testsocket &\n");

    # restart conmand service
    assert_script_run("systemctl restart conman.service");

    # start conman on this socket
    type_string("conman socket1 &\n");

    # test from netcat side
    type_string("fg 1\n");
    type_string("Hello from nc...\n");
    send_key('ctrl-z');
    type_string("fg 2\n");
    assert_screen('socket-response');

    # test from conman side
    type_string("&E\n");    # enable echoing
    type_string("Hello from conman...\n");
    send_key('ctrl-l');     # send \n
    type_string '&.';
    assert_screen("connection-closed");
    type_string "fg 1\n";
    assert_screen('nc-response');

    send_key 'ctrl-d';
}
1;
# vim: set sw=4 et:
