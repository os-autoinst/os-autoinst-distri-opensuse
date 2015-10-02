# Copyright (C) 2014 SUSE Linux GmbH
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
# with this program; if not, write to the Free Software Foundation, Inc.,
# 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.

use base "basetest";
use strict;
use testapi;

sub run {
    if (get_var("BETA") =~ /beta/) {
	assert_screen "SLE12_beta", 120;
	send_key "alt-o", 1;
    }

    # accept Licence
    assert_screen "SLE12_acceptlicence", 120;
    send_key "alt-a", 1;
    send_key "alt-n", 1;

    # Skip registration
    send_key "alt-s", 1;
    send_key "alt-y", 1;

    # No external repository
    send_key "alt-n", 3;
    save_screenshot;

    # don't use btrfs, switch to ext4
    assert_screen "SLE12_partition_ext4", 20;
    send_key "alt-d", 1;
    send_key "alt-f", 1;
    send_key "down", 1;
    send_key "alt-o", 1;
    send_key "alt-n", 1;

    # timezone default (NY)
    send_key "alt-n", 1;
    save_screenshot;
    
    # user
    type_string $username, 2;
#    send_key "alt-u", 1;
#    type_string "linux", 2;
    send_key "alt-p", 1;
    type_string $password;
    send_key "alt-o", 1;
    type_string $password;
    send_key "alt-s", 2;
    send_key "alt-a", 2;
    send_key "alt-n", 2;
    send_key "alt-y", 2;

    # install setting go to software selection
    assert_screen "SLE12_software_selection", 20;
    send_key "tab", 3;
    send_key "tab", 3;
    send_key "ret", 3;
    
    # remove doc and apparmor, add kvm
    assert_screen "SLE12_pre_selection", 20;
    send_key "tab", 3;
    # remove doc
    send_key "down", 3;
    send_key "spc", 2;
    # remove apparmor
    for (1 .. 3) { send_key "down", 3; }
    send_key "spc", 2;
    # select KVM
    for (1 .. 3) {send_key "down", 3; }
    send_key "spc", 2;
    if (get_var("DESKTOP") =~ /icewm/) {
	# remove Gnome desktop
	for (1 .. 3) {send_key "down", 3; }
	send_key "spc", 2;
    }
    save_screenshot;
    send_key "alt-o", 1;
    
    # Launch the intallation
    assert_screen "SLE12_goforinstall", 20;
    send_key "alt-i", 1;
    send_key "alt-i", 1;
    assert_screen "SLE12_install_in_progress", 10;
    # reboot !
    wait_idle 530;
}

sub test_flags {
    # without anything - rollback to 'lastgood' snapshot if failed
    # 'fatal' - whole test suite is in danger if this fails
    # 'milestone' - after this test succeeds, update 'lastgood'
    # 'important' - if this fails, set the overall state to 'fail'
    return { fatal => 1, milestone => 1 };
}

1;

# vim: set sw=4 et:
