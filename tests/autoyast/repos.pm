# Copyright (C) 2015-2021 SUSE LLC
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

# Package: iproute2 systemd PackageKit zypper yast2 tar bzip2
# Summary: Verify network and repos are available
# - Check status of all network interfaces
# - Stop packagekit service
# - Enable install DVD
# - Install yast2 tar bzip2
# - Save yast2 logs
# Maintainer: Pavel Sladek <psladek@suse.cz>

use strict;
use warnings;
use base 'y2_module_consoletest';
use testapi;
use utils;
use zypper;

sub run {
    # sles12_minimal.xml profile does not install "ip"
    assert_script_run 'ip a || ifstatus all';
    if (!check_var('DESKTOP', 'textmode')) {
        quit_packagekit;
        # poo#87850 wait the zypper processes in background to finish and release the lock.
        wait_quit_zypper;
    }
    zypper_enable_install_dvd;
    # make sure that save_y2logs from yast2 package, tar and bzip2 are installed
    # even on minimal system
    zypper_call 'in yast2 tar bzip2';
    assert_script_run 'save_y2logs /tmp/y2logs.tar.bz2';
    upload_logs '/tmp/y2logs.tar.bz2';
}

1;

