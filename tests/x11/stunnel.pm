# SUSE's openQA tests
#
# Copyright 2017 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: stunnel tigervnc
# Summary: client part of VNC wrapped with stunnel
# Maintainer: Grace Wang <grace.wang@suse.com>
# Tags: TC1595152

use base "x11test";
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
    enter_cmd "exit";
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
