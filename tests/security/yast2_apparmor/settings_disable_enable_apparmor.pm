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
# Summary: Test "# yast2 apparmor" can disable/enable apparmor service
# Maintainer: llzhao <llzhao@suse.com>
# Tags: poo#67021, tc#1741266

use base apparmortest;
use strict;
use warnings;
use testapi;
use utils;

sub run {
    my ($self) = shift;

    # Yast2 AppArmor set up
    $self->yast2_apparmor_setup();

    # Check apparmor service is enabled
    $self->yast2_apparmor_is_enabled();

    # Disable apparmor service and check
    send_key "alt-e";
    assert_screen("AppArmor-Settings-Disable-Apparmor");
    wait_screen_change { send_key "alt-q" };
    type_string("systemctl status apparmor | tee \n");
    assert_screen("AppArmor_Inactive");

    # Enable apparmor service and check
    type_string("yast2 apparmor &\n");
    assert_screen("AppArmor-Configuration-Settings");
    send_key "alt-l";
    assert_screen("AppArmor-Settings-Disable-Apparmor");
    send_key "alt-e";
    assert_screen("AppArmor-Settings-Enable-Apparmor");
    wait_screen_change { send_key "alt-q" };
    type_string("systemctl status apparmor | tee \n");
    assert_screen("AppArmor_Active");

    # Yast2 AppArmor clean up
    $self->yast2_apparmor_cleanup();
}

1;
