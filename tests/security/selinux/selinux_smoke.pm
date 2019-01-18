# Copyright (C) 2018-2019 SUSE LLC
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
# Summary: Test with SELinux is "enabled" and in "permissive" mode system still
#          works, can access files, directories, ports and processes, e.g.,
#          no problem with refreshing and updating,
#          packages should be installed and removed without any problems,
#          patterns could be installed.
# Maintainer: llzhao <llzhao@suse.com>
# Tags: poo#40361, tc#1682591

use base 'opensusebasetest';
use strict;
use warnings;
use testapi;
use utils;
use registration "add_suseconnect_product";
use version_utils "is_sle";

sub run {
    my ($self) = @_;
    $self->select_serial_terminal;

    # make sure SELinux is "enabled" and in "permissive" mode
    validate_script_output("sestatus", sub { m/SELinux\ status: .*enabled.* Current\ mode: .*permissive/sx });

    # refresh & update
    zypper_call("ref", timeout => 1200);
    zypper_call("up",  timeout => 1200);

    # install & remove pkgs, e.g., apache2
    zypper_call("in apache2");
    zypper_call("rm apache2");

    # for sle, register available extensions and modules, e.g., free addons
    if (is_sle) {
        my $SCC_REGCODE = get_required_var("SCC_REGCODE");
        assert_script_run("SUSEConnect -r $SCC_REGCODE");
        add_suseconnect_product("sle-module-web-scripting");
    }

    # install & remove patterns, e.g., mail_server
    zypper_call("in -t pattern mail_server");
    zypper_call("rm -t pattern mail_server");
}

1;
