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
# with this program; if not, see <http://www.gnu.org/licenses/>.

# Summary: - add the virtualization test suite- add a load_virtualization_tests call
# Maintainer: aginies <aginies@suse.com>

use base "basetest";
use strict;
use testapi;

sub run {
    if (get_var("BETA") =~ /beta/) {
        assert_screen "SLE12_beta", 120;
        send_key "alt-o";
    }

    # accept Licence
    assert_screen "SLE12_acceptlicence", 120;
    send_key "alt-a";
    send_key "alt-n";

    # Skip registration
    send_key "alt-s";
    send_key "alt-y";

    # No external repository
    send_key "alt-n";
    save_screenshot;

    # don't use btrfs, switch to ext4
    assert_screen "SLE12_partition_ext4", 20;
    send_key "alt-d";
    send_key "alt-f";
    send_key "down";
    send_key "alt-o";
    send_key "alt-n";

    # timezone default (NY)
    send_key "alt-n";
    save_screenshot;

    # user
    type_string $username, 2;
    #    send_key "alt-u";
    #    type_string "linux", 2;
    send_key "alt-p";
    type_string $password;
    send_key "alt-o";
    type_string $password;
    send_key "alt-s";
    send_key "alt-a";
    send_key "alt-n";
    send_key "alt-y";

    # install setting go to software selection
    assert_screen "SLE12_software_selection", 20;
    send_key "tab";
    send_key "tab";
    send_key "ret";

    # remove doc and apparmor, add kvm
    assert_screen "SLE12_pre_selection", 20;
    send_key "tab";
    # remove doc
    send_key "down";
    send_key "spc";
    # remove apparmor
    for (1 .. 3) { send_key "down"; }
    send_key "spc";
    # select KVM
    for (1 .. 3) { send_key "down"; }
    send_key "spc";
    if (get_var("DESKTOP") =~ /icewm/) {
        # remove Gnome desktop
        for (1 .. 3) { send_key "down"; }
        send_key "spc";
    }
    save_screenshot;
    send_key "alt-o";

    # Launch the intallation
    assert_screen "SLE12_goforinstall", 20;
    send_key "alt-i";
    send_key "alt-i";
    assert_screen "SLE12_install_in_progress", 10;
    # reboot !
}

sub test_flags {
    # without anything - rollback to 'lastgood' snapshot if failed
    # 'fatal' - whole test suite is in danger if this fails
    # 'milestone' - after this test succeeds, update 'lastgood'
    # 'important' - if this fails, set the overall state to 'fail'
    return {fatal => 1, milestone => 1};
}

1;

# vim: set sw=4 et:
