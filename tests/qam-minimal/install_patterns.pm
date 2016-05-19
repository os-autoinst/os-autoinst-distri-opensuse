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
    select_console 'root-console';

    script_run("while pgrep packagekitd; do pkcon quit; sleep 1; done");

    zypper_call("ref");

    zypper_call("pt");
    save_screenshot;

    zypper_call("in -t pattern base x11 gnome-basic apparmor", [0, 102], 2000);

    assert_script_run("systemctl set-default graphical.target");
    assert_script_run('sed -i -r "s/^DISPLAYMANAGER=\"\"/DISPLAYMANAGER=\"gdm\"/" /etc/sysconfig/displaymanager');
    assert_script_run('sed -i -r "s/^DISPLAYMANAGER_AUTOLOGIN/#DISPLAYMANAGER_AUTOLOGIN/" /etc/sysconfig/displaymanager');

    # now we have gnome installed - restore DESKTOP variable
    set_var('DESKTOP', get_var('FULL_DESKTOP'));

    prepare_system_reboot;
    type_string "reboot\n";
    wait_boot;
}

sub test_flags {
    return {fatal => 1};
}

sub post_fail_hook {
    assert_script_run "save_y2logs /tmp/y2logs-fail.tar.bz2";
    upload_logs "/tmp/y2logs-fail.tar.bz2";
}

1;
