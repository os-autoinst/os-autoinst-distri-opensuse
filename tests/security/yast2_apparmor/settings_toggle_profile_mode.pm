# Copyright (C) 2020 SUSE LLC
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with this program; if not, see <http://www.gnu.org/licenses/>.
#
# Summary: Test "# yast2 apparmor" can toggle profile modes
# Maintainer: llzhao <llzhao@suse.com>
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
    send_key "alt-c";
    assert_screen("AppArmor-Settings-Profile-toggled");
    send_key "alt-c";
    assert_screen("AppArmor-Settings-Profile-List-Show-Active-only");

    # List all profiles
    send_key "alt-s";
    assert_screen("AppArmor-Settings-Profile-List-Show-All");

    # Yast2 AppArmor clean up
    $self->yast2_apparmor_cleanup();
}

1;
