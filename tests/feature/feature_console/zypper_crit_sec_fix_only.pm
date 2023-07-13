# SUSE's feature tests
#
# Copyright 2016 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Test zypper can update critical security fixes only
# Tags: fate#318760, tc#1480288
# Maintainer: QE Security <none@suse.de>

use base "consoletest";
use strict;
use warnings;
use testapi;
use registration;
use utils;

sub run {
    select_console 'root-console';

    my $not_registered = qr/"status":"Not Registered"/;
    my $registered = qr/"status":"Registered"/;

    if (check_var 'DISTRI', 'sle') {
        script_run "SUSEConnect --status | tee /dev/$serialdev", 0;
        my $out = wait_serial [$not_registered, $registered];
        if ($out =~ $not_registered) {
            set_var 'SCC_REGISTER', 'console';
            yast_scc_registration;
        }
    }

    zypper_call "ref";

    my $zypper_patches = "zypper -n patches 2>/dev/null";
    # List all critical security fixes available, exclude "Not Needed" ones
    script_run "$zypper_patches | grep \"security .* critical\" | grep -v \"Not Needed\" | tee available_sec_crit_fixes", 60;

    # Install critical security fixes only
    zypper_call 'patch --category security --severity critical';

    # Make sure all critical security fixes are installed
    script_run "$zypper_patches | grep \"security .* critical\" | grep Installed | tee installed_sec_crit_fixes", 60;
    assert_script_run
      'test $(wc -l installed_sec_crit_fixes | cut -d" " -f1) -eq $(wc -l available_sec_crit_fixes | cut -d" " -f1)',
      60, "Not all critical security fixes are installed";

    # Clearn up
    script_run "rm -f *sec_crit_fixes";

    save_screenshot;
}

1;
