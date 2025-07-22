# Copyright 2017 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

# Summary: Test the function of SUSEConnect to deregister a module
# Maintainer: Yi Xu <yxu@suse.com>

use base 'consoletest';
use testapi;
use suseconnect_register;
use registration;

sub run {
    select_console 'root-console';

    my $count = script_output("SUSEConnect --status-text | grep -c \"^\\s*Registered\"", 200);
    if ($count eq 0) {
        die "There is no module registered";
    }

    # check if a certain module is registered, e.g. toolchain
    my $abbrv = "tcm";
    my $module = get_addon_fullname("$abbrv");
    my $version = get_required_var('VERSION') =~ s/([0-9]+).*/$1/r;
    die "$module needs to be part of SCC_ADDONS for this test" unless check_var_array('SCC_ADDONS', $abbrv);
    assert_script_run("SUSEConnect --status-text | grep -A 3 $module | grep \"^\\s*Registered\"", 200);

    # deregister the module and check if it is successful
    add_suseconnect_product($module, $version, get_required_var('ARCH'), "--de-register");

    # check if ONE module is deregistered
    my $count_dereg = script_output("SUSEConnect --status-text | grep -c \"^\\s*Registered\"", 200);
    my $count_expect = $count - 1;
    if ($count_dereg ne $count_expect) {
        die "SUSEConnect deregister didn't work properly!";
    }

    # register the module again, check if it is successful. OR using yast_scc_registration();
    suseconnect_register::command_register($version, $abbrv);
    assert_script_run("SUSEConnect --status-text | grep -A 3 $module | grep \"^\\s*Registered\"", 200);
}

1;
