# SUSE's openQA tests
#
# Copyright © 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.


use base "basetest";

use strict;

use utils;
use qam;
use testapi;

sub run {

    script_run("while pgrep packagekitd; do pkcon quit; sleep 1; done");

    my $ret = zypper_call("ref");
    die "zypper failed with code $ret" unless $ret == 0;

    $ret = zypper_call("pt");
    die "zypper failed with code $ret" unless $ret == 0;
    save_screenshot;

    $ret = zypper_call("in -t pattern base x11 gnome-basic apparmor", 2000);
    die "zypper failed with code $ret" unless grep { $_ == $ret } (0, 102);


    assert_script_run("systemctl set-default graphical.target");
    assert_script_run('sed -i -r "s/^DISPLAYMANAGER=\"\"/DISPLAYMANAGER=\"gdm\"/" /etc/sysconfig/displaymanager');
    assert_script_run('sed -i -r "s/^DISPLAYMANAGER_AUTOLOGIN/#DISPLAYMANAGER_AUTOLOGIN/" /etc/sysconfig/displaymanager');

    prepare_system_reboot;
    type_string "reboot\n";
    wait_boot;
}

sub test_flags {
    return {fatal => 1};
}

1;
