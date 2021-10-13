# Copyright 2018-2020 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later
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
use version_utils "is_sle";

sub run {
    select_console "root-console";

    # make sure SELinux is "enabled" and in "permissive" mode
    validate_script_output("sestatus", sub { m/SELinux\ status: .*enabled.* Current\ mode: .*permissive/sx });

    # refresh & update
    zypper_call("ref", timeout => 1200);
    zypper_call("up", timeout => 1200);

    # install & remove pkgs, e.g., apache2
    zypper_call("in apache2");
    zypper_call("rm apache2");

    # for sle, register available extensions and modules, e.g., free addons
    if (is_sle) {
        register_product();
        my $version = get_required_var('VERSION') =~ s/([0-9]+).*/$1/r;
        if ($version == '15') {
            $version = get_required_var('VERSION') =~ s/([0-9]+)-SP([0-9]+)/$1.$2/r;
        }
        my $arch = get_required_var('ARCH');
        my $params = " ";
        my $timeout = 180;
        add_suseconnect_product("sle-module-web-scripting", "$version", "$arch", "$params", "$timeout");
    }

    # install & remove patterns, e.g., mail_server
    zypper_call("in -t pattern mail_server");
    zypper_call("rm -t pattern mail_server");
}

1;
