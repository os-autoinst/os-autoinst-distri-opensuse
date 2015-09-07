# Copyright (C) 2014,2015 SUSE Linux GmbH
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

use strict;
use base "consoletest";

use testapi;
use registration;

sub run() {
    become_root;

    type_string "PS1=\"# \"\n";
    if (my $u = get_var('SCC_URL')) {
        type_string "echo 'url: $u' > /etc/SUSEConnect\n";
    }
    type_string "yast scc; echo yast-scc-done-\$? > /dev/$serialdev\n";
    assert_screen( "scc-registration", 30 );

    fill_in_registration_data;

    wait_serial("yast-scc-done-0") || die "yast scc failed";
    type_string "zypper lr\n";
    assert_screen "scc-repos-listed";

    type_string "exit\n";
}

sub test_flags() {
    return { 'important' => 1, };
}

1;
# vim: set sw=4 et:
