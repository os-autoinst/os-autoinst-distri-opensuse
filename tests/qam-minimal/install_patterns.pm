# SUSE's openQA tests
#
# Copyright © 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

#package install_update;

use base "basetest";

use strict;

use qam;
use testapi;
use utils;

sub run {

    script_run("while pgrep packagekitd; do pkcon quit; sleep 1; done");

    assert_script_run("zypper ref");

    script_run("zypper pt");
    save_screenshot;

    assert_script_run("zypper -n in -t pattern base x11 gnome-basic apparmor", 2000);

    assert_script_run("systemctl set-default graphical.target");
    assert_script_run('sed -i -r "s/^DISPLAYMANAGER=\"\"/DISPLAYMANAGER=\"gdm\"/" /etc/sysconfig/displaymanager');
    assert_script_run('sed -i -r "s/^DISPLAYMANAGER_AUTOLOGIN/#DISPLAYMANAGER_AUTOLOGIN/" /etc/sysconfig/displaymanager');

    type_string "reboot\n";
    wait_boot;
}

sub test_flags {
    return {fatal => 1};
}

1;
