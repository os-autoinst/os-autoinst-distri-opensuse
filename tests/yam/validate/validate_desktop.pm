# SUSE's openQA tests
#
# Copyright 2025 SUSE LLC
# SPDX-License-Identifier: FSFAP


# Summary: Validate agama GNOME Desktop Environment (Wayland)
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

use base "x11test";
use Utils::Architectures qw(is_s390x is_ppc64le);
use strict;
use warnings;
use testapi;

sub run {
    return if (is_s390x() || is_ppc64le());

    x11_start_program "kgx";
    wait_still_screen 2, 2;
    assert_and_click "kgx";
    become_root;
    wait_still_screen 2;
    assert_script_run "loginctl show-session \$(loginctl | grep \$USER | awk '{print \$1}') -p Type | grep Type=wayland";
    enter_cmd 'exit';
    wait_still_screen 5;
    enter_cmd 'exit';
    wait_still_screen 5;
    assert_screen "generic-desktop", timeout => 90;
}

1;
