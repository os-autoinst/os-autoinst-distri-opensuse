# SUSE's openQA tests
#
# Copyright © 2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Initialize testing environment
# Manual modifications to controller node:
#   Installed packages for DHCP, DNS and enable them in firewall
#   Installer kubernetes-client from virtualization repo
#   Firefox:
#     - disabled readerview, password remember, bookmarks bar
#     - startup page, search tips, auto-save to disk
# Maintainer: Martin Kravec <mkravec@suse.com>

use parent 'caasp_controller';

use strict;
use testapi;

sub run {
    select_console 'x11';
    x11_start_program('xterm');

    # Fix permissions
    assert_script_sudo "chown $testapi::username /dev/$testapi::serialdev";
    # Disable screensaver
    script_run "gsettings set org.gnome.desktop.session idle-delay 0";
    # Update kubectl
    assert_script_sudo "zypper -n up kubernetes-client", 300;


    # Leave xterm open for kubernetes tests
    save_screenshot;
    send_key "ctrl-l";
    send_key 'super-up';
    x11_start_program('firefox', valid => 0);
}

1;

# vim: set sw=4 et:
