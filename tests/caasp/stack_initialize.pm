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

use strict;
use testapi;
use utils 'ensure_serialdev_permissions';

sub run {
    select_console 'x11';
    x11_start_program('xterm');
    become_root;
    ensure_serialdev_permissions;
    type_string "exit\n";

    # Disable screensaver
    script_run "gsettings set org.gnome.desktop.session idle-delay 0";
    # Update kubectl
    assert_script_sudo "zypper -n up kubernetes-client", 300;

    # Workaround for Microfocus infobloxx GEO-IP DNS Cluster
    if (get_var('EDGECAST')) {
        record_info 'Netfix', 'Go through Europe Microfocus info-bloxx';
        my $edgecast_europe = get_var('EDGECAST');
        assert_script_sudo("echo $edgecast_europe updates.suse.com >> /etc/hosts");
        assert_script_run("grep 'updates.suse.com' /etc/hosts");
        script_run("ping -c 1 updates.suse.com | grep $edgecast_europe");
    }

    # Leave xterm open for kubernetes tests
    save_screenshot;
    send_key "ctrl-l";
    send_key 'super-up';
    x11_start_program('firefox', valid => 0);
}

1;

# vim: set sw=4 et:
