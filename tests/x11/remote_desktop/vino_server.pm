# Copyright 2017 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Package: yast2-firewall gnome-control-center vino
# Summary: Remote Login: vino server for VNC connections
#          server: vino_server.pm
#          client: vino_client.pm
# Maintainer: Grace Wang <grace.wang@suse.com>
# Tags: tc#1586210

use base 'x11test';
use testapi;
use lockapi;
use mmapi;

sub run {
    my $self = shift;

    # Setup static NETWORK
    $self->configure_static_ip_nm('10.0.2.15/15');

    # Add the firewall port for VNC
    x11_start_program('xterm');
    become_root;
    assert_script_run 'yast2 firewall services add zone=EXT service=service:vnc-server';
    enter_cmd "exit";
    wait_screen_change { send_key 'alt-f4' };

    # Activate vino server
    x11_start_program('gnome-control-center sharing', target_match => 'gcc-sharing');
    assert_and_click 'gcc-sharing-on';
    send_key 'alt-s';
    assert_screen 'gcc-screen-sharing';
    assert_and_click 'gcc-screen-sharing-on';
    send_key 'alt-r';
    wait_still_screen 3;
    send_key 'alt-p';
    type_password;
    wait_still_screen 3;
    send_key 'alt-f4';
    assert_screen 'gcc-sharing-activate';

    # The following section opens a terminal to print vino-server log
    # to help debug poo#49811
    x11_start_program('xterm');
    assert_script_run('killall vino-server');
    enter_cmd("/usr/lib/vino/vino-server | tee /tmp/vino-server.log");
    send_key 'alt-tab';

    # Notice vino server is ready for remote access
    mutex_create 'vino_server_ready';

    # Wait until vino client finishes remote access
    wait_for_children;

    save_screenshot;
    wait_screen_change { send_key 'alt-f4' };
    wait_screen_change { send_key 'alt-f4' };
}

1;
