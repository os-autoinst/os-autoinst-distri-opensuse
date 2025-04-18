# SUSE's openQA tests
#
# Copyright 2025 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: The test module is to validate whether the installation is in headless mode.
# systemctl status graphical.target and systemctl status x11-autologin.service are
# different between a normal installation and a headless one. And validate the X11/Wayland
# is not used and firefox is not lauched.
#
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

use base 'consoletest';
use strict;
use warnings;
use testapi;

sub run {
    select_console 'root-console';

     my $multi_user_target_status = script_run('systemctl is-active multi-user.target');
     die "multi-user.target is not active, but it is expected to be" if $multi_user_target_status != 0;

    my $graphical_target_status = script_run('systemctl is-active graphical.target');
    die "graphical.target is active, but it should not be" if $graphical_target_status == 0;

    my $is_x11_wayland_running = script_run('pgrep -x X || pgrep -x wayland');
    die "X11 or Wayland is running, but it should not be" if $is_x11_wayland_running == 0;

    my $is_firefox_running = script_run('pgrep -x firefox');
    die "Firefox is running, but it should not be" if $is_firefox_running == 0;
}

1;
