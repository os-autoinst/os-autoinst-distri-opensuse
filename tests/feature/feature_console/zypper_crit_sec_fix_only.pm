# SUSE's feature tests
#
# Copyright © 2016 SUSE LLC
#
# Copying and distbution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Test zypper can update critical security fixes only
# Tags: fate#318760, tc#1480288
# Maintainer: Qingming Su <qingming.su@suse.com>

use base "consoletest";
use strict;
use warnings;
use testapi;
use registration;

sub run {
    select_console 'root-console';

    my $not_registered = qr/"status":"Not Registered"/;
    my $registered     = qr/"status":"Registered"/;

    if (check_var 'DISTRI', 'sle') {
        script_run "SUSEConnect --status | tee /dev/$serialdev", 0;
        my $out = wait_serial [$not_registered, $registered];
        if ($out =~ $not_registered) {
            die "The test can only be run on registered system\n";
        }
    }

    assert_script_run "zypper ref", 120;

    my $zypper_patches = "zypper -n patches 2>/dev/null";
    # List all critical security fixes available, exclude "Not Needed" ones
    script_run "$zypper_patches | grep \"security .* critical\" | grep -v \"Not Needed\" | tee available_sec_crit_fixes", 60;

    # Install critical security fixes only
    assert_script_run 'zypper -n patch --category security --severity critical', 600;

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
# vim: set sw=4 et:
