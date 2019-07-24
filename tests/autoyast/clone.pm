# Copyright (C) 2015-2019 SUSE Linux GmbH
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

# Summary: Clone the existing installation for use in validation
# - remove existing autoinst.xml
# - call yast2 clone_system
# - upload autoinst.xml
# - upload original installedSystem.xml
# - run save_y2logs and upload the generated tar.bz2
# Maintainer: Oliver Kurz <okurz@suse.de>

use strict;
use warnings;
use parent 'y2_module_consoletest';
use testapi;

sub run {
    my $self = shift;
    assert_script_run 'rm -f /root/autoinst.xml';
    my $module_name = y2_module_consoletest::yast2_console_exec(yast2_module => 'clone_system', yast2_opts => '--ncurses');
    if (check_screen 'autoyast2-install-accept', 10) {
        send_key 'alt-i';    # confirm package installation
    }
    wait_serial("$module_name-0", 400) || die "'yast2 clone_system' exited with non-zero code";
    upload_logs '/root/autoinst.xml';

    # original autoyast on kernel cmdline
    upload_logs '/var/adm/autoinstall/cache/installedSystem.xml';
    assert_script_run 'save_y2logs /tmp/y2logs_clone.tar.bz2';
    upload_logs '/tmp/y2logs_clone.tar.bz2';
    save_screenshot;
}

1;

