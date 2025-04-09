# Copyright 2018-2020 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Summary: Test that with with SELinux "enabled" the system still
#          works, can access files, directories, ports and processes, e.g.,
#          no problem with refreshing and updating,
#          packages should be installed and removed without any problems,
#          patterns could be installed.
# Maintainer: QE Security <none@suse.de>
# Tags: poo#40361, tc#1682591

use base 'opensusebasetest';
use strict;
use warnings;
use testapi;
use serial_terminal 'select_serial_terminal';
use utils;
use registration qw(add_suseconnect_product register_product);
use version_utils qw(is_sle);

sub test_zypper {
    # Refresh & update
    zypper_call("ref", timeout => 1200);
    zypper_call("up", timeout => 1200);

    # Install & remove packages
    zypper_call("in apache2");
    zypper_call("rm apache2");

    # Register available extensions and modules for SLE, e.g., free addons, if SLE16 skip
    if (is_sle('<16') && !main_common::is_updates_tests()) {
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

    # Install & remove patterns
    zypper_call("in -t pattern mail_server");
    zypper_call("rm -t pattern mail_server");

    # Add & remove a repository and test priorities
    zypper_call("ar -f https://download.opensuse.org/repositories/utilities/openSUSE_Factory/ utilities");
    zypper_call("mr -p 90 utilities");

    my $priority = script_output("zypper lr -p | awk -F '|' '/utilities/ {print \$7}' | tr -d ' '");
    die "Repository priority not set correctly" if $priority ne "90";

    zypper_call("rr utilities");
}

sub test_sysctl {
    my $sysctl = "vm.swappiness";
    my $original_value = script_output("/sbin/sysctl -n $sysctl");

    assert_script_run("/sbin/sysctl -w $sysctl=50");

    my $new_value = script_output("/sbin/sysctl -n $sysctl");
    die "Value not set correctly" if $new_value ne "50";

    assert_script_run("/sbin/sysctl -w $sysctl=$original_value");
}

sub run {
    select_serial_terminal;

    # Make sure SELinux is "enabled"
    validate_script_output("sestatus", sub { m/SELinux\ status: .*enabled/sx });

    record_info("zypper");
    test_zypper();
    record_info("sysctl");
    test_sysctl();
}

1;
