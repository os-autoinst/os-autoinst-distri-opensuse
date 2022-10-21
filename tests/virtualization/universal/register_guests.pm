# Copyright 2019-2020 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Package: openssl SUSEConnect ca-certificates-suse
# Summary: Register all guests against local SMT server
# Maintainer: Pavel Dostál <pdostal@suse.cz>

use base "virt_feature_test_base";
use virt_autotest::common;
use strict;
use warnings;
use testapi;
use serial_terminal 'select_serial_terminal';
use utils;
use version_utils;

sub run_test {
    # Use serial terminal, unless defined otherwise. The unless will go away once we are certain this is stable
    # select_serial_terminal unless get_var('_VIRT_SERIAL_TERMINAL', 1) == 0;
    select_console 'root-console';
    my %ltss_products = @{get_var_array("LTSS_REGCODES_SECRET")};

    foreach my $guest (keys %virt_autotest::common::guests) {
        record_info "$guest", "Registrating $guest against SMT";
        my ($sles_running_version, $sles_running_sp) = get_os_release("ssh root\@$guest");
        my $version_id = $sles_running_sp != 0 ? "$sles_running_version.$sles_running_sp" : $sles_running_version;
        if ($sles_running_version >= 12) {
            assert_script_run("ssh root\@$guest SUSEConnect -r " . get_var('SCC_REGCODE') . " -e " . get_var("SCC_EMAIL"));
            #it's safe to wait a few seconds to perform next register.
            sleep 10;
            assert_script_run("ssh root\@$guest SUSEConnect -p SLES-LTSS/$version_id/x86_64 -r " . $ltss_products{"$version_id"}) if ($ltss_products{"$version_id"});
            sleep 10;
        }
        assert_script_run("ssh root\@$guest zypper -n ref");
        # Perhaps check the return values?
        script_run("ssh root\@$guest 'zypper ar --refresh http://download.suse.de/ibs/SUSE:/CA/" . $virt_autotest::common::guests{$guest}->{distro} . "/SUSE:CA.repo'", 90);
        assert_script_run("ssh root\@$guest 'zypper -n in ca-certificates-suse'", 90);
    }
}

1;

