# Copyright (C) 2015-2017 SUSE LLC
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

# Summary: Verify network and repos are available
# Maintainer: Pavel Sladek <psladek@suse.cz>

use strict;
use warnings;
use base 'console_yasttest';
use testapi;
use utils;

sub run {
    # sles12_minimal.xml profile does not install "ip"
    assert_script_run 'ip a || ifstatus all';
    pkcon_quit;
    zypper_call 'ref';
    # make sure that save_y2logs from yast2 package, tar and bzip2 are installed
    # even on minimal system
    zypper_call 'in yast2 tar bzip2';
    assert_script_run 'save_y2logs /tmp/y2logs.tar.bz2';
    upload_logs '/tmp/y2logs.tar.bz2';
}

1;

