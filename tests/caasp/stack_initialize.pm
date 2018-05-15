# SUSE's openQA tests
#
# Copyright © 2017-2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Initialize testing environment
# Manual modifications to controller node:
#   Installed packages for DHCP, DNS and enable them in firewall
#   Installed kubernetes-client from virtualization repo
#   Installed mozilla-nss-tools to import certificate
#   Firefox:
#     - disabled readerview, password remember, bookmarks bar
#     - blank startup page, search tips, auto-save to disk
# Maintainer: Martin Kravec <mkravec@suse.com>

use parent 'caasp_controller';
use caasp_controller;

use strict;
use testapi;
use caasp 'pause_until';
use utils qw(ensure_serialdev_permissions turn_off_gnome_screensaver);

sub firefox_import_ca {
    # Setup ssh
    script_run 'ssh-copy-id -f admin.openqa.test', 0;
    assert_screen 'ssh-password-prompt';
    type_password;
    send_key 'ret';

    # Install certificate
    assert_script_run 'scp admin.openqa.test:/etc/pki/ca.crt .';
    assert_script_run 'certutil -A -n CaaSP -d .mozilla/firefox/*.default -i ca.crt -t "C,,"';
}

sub run {
    select_console 'x11';
    x11_start_program('xterm');
    become_root;
    ensure_serialdev_permissions;
    type_string "exit\n";
    turn_off_gnome_screensaver;
    # Update kubectl
    assert_script_sudo "zypper -n up kubernetes-client", 300;

    # Leave xterm open for kubernetes tests
    save_screenshot;
    send_key "ctrl-l";
    send_key 'super-up';

    pause_until 'VELUM_STARTED';
    firefox_import_ca;
}

1;

