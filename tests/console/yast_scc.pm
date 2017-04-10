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

# G-Summary: harmorize zypper_ref between SLE and openSUSE
# G-Maintainer: Max Lin <mlin@suse.com>

use strict;
use base "consoletest";

use testapi;
use registration;

sub run() {
    select_console 'root-console';

    if (my $u = get_var('SCC_URL')) {
        type_string "echo 'url: $u' > /etc/SUSEConnect\n";
    }
    yast_scc_registration;
}

1;
# vim: set sw=4 et:
