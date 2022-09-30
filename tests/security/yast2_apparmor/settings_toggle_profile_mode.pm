# Copyright 2020 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Summary: Test "# yast2 apparmor" can toggle profile modes
# Maintainer: QE Security <none@suse.de>
# Tags: poo#66901, tc#1741266

use base apparmortest;
use strict;
use warnings;
use testapi;
use utils;

sub run {
    my ($self) = shift;
    my $test_file = "/usr/bin/nscd";

    # Set the testing profile to "enforce" mode
    assert_script_run("aa-enforce $test_file");

    # Yast2 AppArmor set up
    $self->yast2_apparmor_setup();

    # Check apparmor service is enabled
    $self->yast2_apparmor_is_enabled();

    # Enter "Configure Profile modes" and list active only profiles
    send_key "alt-c";
    assert_screen("AppArmor-Settings-Profile-List-Show-Active-only");

    # Toggle profile modes and check "nscd" was changed from "enforcing" to "complain"
    # Set to "complain"
    send_key "alt-c";
    assert_screen("AppArmor-Settings-Profile-toggled");
    # Set to "enforce"
    send_key "alt-e";
    assert_screen("AppArmor-Settings-Profile-List-Show-Active-only");

    # List all profiles
    send_key "alt-s";
    assert_screen("AppArmor-Settings-Profile-List-Show-All");

    # Yast2 AppArmor clean up
    $self->yast2_apparmor_cleanup();
}

1;
