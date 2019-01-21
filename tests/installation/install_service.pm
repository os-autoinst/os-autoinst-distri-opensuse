
# Copyright (C) 2019 SUSE LLC
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

# Summary: Installs and checks a service for migration scenarios
# Maintainer: Joachim Rauch <jrauch@suse.com>

use strict;
use base 'installbasetest';
use testapi;
use utils 'systemctl', 'zypper_call';

sub run {

    select_console 'root-console';
    zypper_call 'in vsftpd';
    systemctl 'start vsftpd';
    systemctl 'status vsftpd';
    save_screenshot;
    assert_script_run 'systemctl status vsftpd --no-pager | grep active';
}

1;
