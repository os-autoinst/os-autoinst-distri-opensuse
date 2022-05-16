# Copyright 2022 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Summary: Luks1 decrypt with ssh
#
# Maintainer: rfan1 <richard.fan@suse.com> Starry Wang <starry.wang@suse.com>
# Tags: poo#81780, tc#1768639, poo#110953

use strict;
use warnings;
use base 'consoletest';
use base 'opensusebasetest';
use testapi;
use lockapi;
use utils;

sub run {
    select_console('root-console');

    mutex_wait('SERVER_UP');

    # Copy the ssh public key to server
    exec_and_insert_password('ssh-copy-id -o StrictHostKeyChecking=no root@10.0.2.101');

    # Clear console to make sure we have clean terminal console
    clear_console;

    mutex_create('CLIENT_READY');
    mutex_wait('SERVER_READY');

    # Make sure the server can be accessed
    assert_script_run('ping -c 5 10.0.2.101');

    # ssh to the server and unlock the boot partiton
    enter_cmd('ssh -i /root/.ssh/id_rsa root@10.0.2.101');
    wait_still_screen(1);
    save_screenshot;

    # We need wait a few seconds here to make sure each command can get return
    wait_still_screen(5);
    send_key 'up';
    save_screenshot;
    wait_still_screen(5);
    send_key 'ret';
    wait_still_screen(5);
    save_screenshot;
    enter_cmd("$testapi::password");
    wait_still_screen(5);
    save_screenshot;
    # exit from ssh session if it is not closed by remote host
    enter_cmd('exit') unless check_screen('ssh_connection_closed_by_remote_host');
    wait_still_screen(5);
    save_screenshot;
    reset_consoles;
}

1;
