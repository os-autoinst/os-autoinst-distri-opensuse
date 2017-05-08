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

use base "x11test";
use strict;
use testapi;
use virtmanager;

sub run {
    launch_virtmanager();
    # method: cdrom, net, pxe, image
    # only CDROM supported now
    my $guest;
    $guest->{name}      = "SLE12Guest";
    $guest->{method}    = "cdrom";
    $guest->{automatic} = "true";
    $guest->{memory}    = "512";
    $guest->{cpu}       = "1";
    $guest->{custom}    = "true";
    $guest->{advanced}  = "true";
    $guest->{netmac}    = "52:54:00:66:0b:fd";

    create_guest($guest);

    if (get_var("DESKTOP") !~ /icewm/) {
        assert_screen "virtman-sle12-gnome_guest_install_in_progress", 50;
    }
    else {
        assert_screen "virtman_guest_install_in_progress", 50;
    }
}

1;

# vim: set sw=4 et:
