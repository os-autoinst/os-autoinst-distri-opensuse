# SUSE's openQA tests
#
# Copyright © 2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: client part of VNC wrapped with stunnel
# Maintainer: Wei Jiang <wjiang@suse.com>
# Tags: TC1595152

use base "x11test";
use strict;
use warnings;
use testapi;
use lockapi;
use utils;
use mm_tests;

sub run {
    x11_start_program('xterm');
    become_root;
    script_run 'cd';
    configure_static_network('10.0.2.11/24');
    zypper_call("in stunnel tigervnc");

    mutex_lock('stunnel');
    mutex_unlock('stunnel');

    wait_still_screen 2;
    configure_stunnel;

    # Connect vnc server as normal user
    type_string "exit\n";
    script_run('vncviewer 127.0.0.1:15905', 0);
    assert_screen 'stunnel-vnc-auth';
    type_string $password;
    wait_still_screen 2;
    send_key 'ret';
    assert_screen 'stunnel-server-desktop';
    send_key 'alt-f4';
    wait_still_screen 2;
    send_key 'alt-f4';
}

1;
