# Copyright (C) 2018-2020 SUSE LLC
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
use registration qw(add_suseconnect_product register_product);
use version_utils qw(is_sle is_microos is_sle_micro);

sub run {
    select_console "root-console";

    if (!is_microos || !is_sle_micro) {
        # make sure SELinux is "enabled" and in "permissive" mode
        validate_script_output("sestatus", sub { m/SELinux\ status: .*enabled.* Current\ mode: .*permissive/sx });
    }
    if (is_microos || is_sle_micro) {
        # make sure SELinux is "enabled" and in "enforcing" mode
        validate_script_output("sestatus", sub { m/SELinux\ status: .*enabled.* Current\ mode: .*enforcing/sx });
    }

    if (!is_microos || !is_sle_micro) {
        # refresh & update
        zypper_call("ref", timeout => 1200);
        zypper_call("up",  timeout => 1200);
        # install & remove pkgs, e.g., apache2
        zypper_call("in apache2");
        zypper_call("rm apache2");
    }
    if (is_microos || is_sle_micro) {
        # refresh & update
        zypper_call("ref", timeout => 1200);
        assert_script_run('transactional-update up',  timeout => 1200);
        # install & remove pkgs, e.g., checkpolicy-debuginfo
        assert_script_run("transactional-update -n pkg install checkpolicy-debuginfo");
        # reboot the vm and reconnect the console
        power_action("reboot", textmode => 1);
        reconnect_mgmt_console if is_pvm;
        $self->wait_boot(textmode => 1, ready_time => 600, bootloader_time => 300);
        select_console "root-console";
        assert_script_run("transactional-update -n pkg remove checkpolicy-debuginfo");
    }

    # for sle, register available extensions and modules, e.g., free addons
    if (is_sle || is_sle_micro) {
        register_product();
        my $version = get_required_var('VERSION') =~ s/([0-9]+).*/$1/r;
        if ($version == '15') {
            $version = get_required_var('VERSION') =~ s/([0-9]+)-SP([0-9]+)/$1.$2/r;
        }
        my $arch    = get_required_var('ARCH');
        my $params  = " ";
        my $timeout = 180;
        add_suseconnect_product("sle-module-web-scripting", "$version", "$arch", "$params", "$timeout");
    }

    # install & remove patterns, e.g., mail_server
    if (!is_microos || !is_sle_micro) {
        zypper_call("in -t pattern mail_server");
        zypper_call("rm -t pattern mail_server");
    }
}

1;
