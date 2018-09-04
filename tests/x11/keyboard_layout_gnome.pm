# SUSE's openQA tests
#
# Copyright © 2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.


# Summary: Test if gnome login manager honors keyboard layout changes
# Maintainer: Dominik Heidler <dheidler@suse.de>

use base "x11test";
use strict;
use testapi;
use utils;
use power_action_utils 'power_action';

sub reboot {
    my ($self, %args) = @_;
    $args{setnologin} //= 0;
    power_action('reboot', textmode => 1);
    $self->wait_boot(nologin => $args{setnologin}, forcenologin => $args{setnologin});
}

sub run {
    my $self = shift;
    my $kbdlayout_script = "changekbd.sh";

    # login
    select_console('root-console');

    # disable autologin
    assert_script_run "sed -i.bak '/^DISPLAYMANAGER_AUTOLOGIN=/s/=.*/=\"\"/' /etc/sysconfig/displaymanager";

    # set german keyboard layout (y and z are switched on this layout)
    type_string "echo \"loadkeys us-intl && echo done > /dev/$serialdev\" > $kbdlayout_script\n";
    type_string "cat $kbdlayout_script\n";
    assert_script_run "yast keyboard set layout=german";

    $self->reboot(setnologin => 1);

    # check gdm keyboard layout
    assert_and_click('user_not_listed');
    type_string "qwertz";
    assert_screen 'gdm-user-querty', 60;

    # check console keyboard layout and restore autologin
    select_console('root-console', skip_set_standard_prompt => 1, skip_setterm => 1);
    type_string "bash $kbdlayout_script\n";
    wait_serial 'done';
    assert_script_run '$(exit $?)';
    assert_script_run "mv /etc/sysconfig/displaymanager.bak /etc/sysconfig/displaymanager";

    $self->reboot;

    select_console('root-console', skip_set_standard_prompt => 1, skip_setterm => 1);
    type_string "bash $kbdlayout_script\n";
    wait_serial 'done';
    assert_script_run '$(exit $?)';
    ensure_serialdev_permissions;

    # check gnome keyboard layout
    select_console('x11');
    x11_start_program('xterm');
    wait_still_screen;
    # this should actually type "zcat --version" into xterm
    if (script_run("ycat --version") == 127) {
        record_soft_failure("bsc#1105797: Keyboard Layout change via YaST doesn't affect GNOME");
    }

    # restore keyboard settings
    select_console('root-console');
    assert_script_run "yast keyboard set layout=us-int";

    $self->reboot;

    # after restart of X11 give the desktop a bit more time to show up to
    # prevent the post_run_hook to fail being too impatient
    assert_screen 'generic-desktop', 600;
}

1;
