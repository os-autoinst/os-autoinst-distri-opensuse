# Copyright (C) 2018 SUSE LLC
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
#
# Summary: Enforce a disabled profile with aa-enforce
# Maintainer: Wes <whdu@suse.com>
# Tags: poo#36877, tc#1621145

use strict;
use base "consoletest";
use testapi;
use utils;

sub run {
    select_console 'root-console';

    systemctl('restart apparmor');

    validate_script_output "aa-disable usr.sbin.nscd", sub {
        m/Disabling.*nscd/;
    };

    # Check if /usr/sbin/ntpd is really disabled
    die "/usr/sbin/nscd should be disabled"
      if (script_run("aa-status |grep /usr/sbin/nscd") == 0);

    validate_script_output "aa-enforce usr.sbin.nscd", sub {
        m/Setting.*nscd to enforce mode/;
    };

    validate_script_output "aa-status", sub {
        m/\/usr\/sbin\/nscd/;
    };

}

1;
