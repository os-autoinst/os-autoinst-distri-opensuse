# Copyright (C) 2017 SUSE Linux GmbH
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

# Summary: Add modules with yast2_scc in a registered system
# Maintainer: Sergio Lindo Mansilla <slindomansilla@suse.com>

use base "consoletest";
use strict;
use testapi;
use utils;
use warnings;


sub run {
    select_console 'root-console';

    if (my $u = get_var('SCC_URL')) {
        type_string "echo 'url: $u' > /etc/SUSEConnect\n";
    }
    script_run("yast2 scc; echo yast2-scc-status-\$? > /dev/$serialdev", 0);
    assert_screen('yas2_scc-system_already-registered');
    assert_screen('yas2_scc-select-extensions');
    send_key('ret');
    send_key_until_needle_match('yast2_scc-legacy-module-highlighted', 'down');
    send_key(' ');
    assert_screen('yast2_scc-legacy-module-selected');
    send_key('alt-n');
    assert_screen('yast2_scc-installation_summary');
    send_key('alt-a');
    assert_screen('yast2_scc-installation_dependencies');
    send_key('alt-o');
    assert_screen('yast2_scc-installation_report');
    send_key('alt-f');
}


1;
# vim: set sw=4 et:
