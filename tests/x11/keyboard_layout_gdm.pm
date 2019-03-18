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
use warnings;
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
    my $self             = shift;
    my $kbdlayout_script = "changekbd.sh";

    # login
    select_console('root-console');

    # disable autologin
    assert_script_run "sed -i.bak '/^DISPLAYMANAGER_AUTOLOGIN=/s/=.*/=\"\"/' /etc/sysconfig/displaymanager";

    # set german keyboard layout (y and z are switched on this layout)
    type_string "echo \"test \\\$1 == qwerty && loadkeys us && echo done > /dev/$serialdev\" > $kbdlayout_script\n";
    assert_script_run "cat $kbdlayout_script";
    assert_script_run "yast keyboard set layout=german";

    $self->reboot(setnologin => 1);

    # check gdm keyboard layout
    assert_and_click('user_not_listed');
    type_string "qwertz";
    assert_screen 'gdm-user-querty', 60;

    # check console keyboard layout and restore autologin
    select_console('root-console', skip_set_standard_prompt => 1, skip_setterm => 1);
    type_string "bash $kbdlayout_script qwertz\n";
    wait_serial 'done';
    assert_script_run '$(exit $?)';
    assert_script_run "mv /etc/sysconfig/displaymanager.bak /etc/sysconfig/displaymanager";

    # restore keyboard settings
    assert_script_run "yast keyboard set layout=english-us";

    $self->reboot;

    # after restart of X11 give the desktop a bit more time to show up to
    # prevent the post_run_hook to fail being too impatient
    assert_screen 'generic-desktop', 600;
}

1;
