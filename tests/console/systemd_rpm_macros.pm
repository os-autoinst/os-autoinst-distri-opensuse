# SUSE's openQA tests
#
# Copyright 2020-2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: systemd-rpm-macros test
#          - call a list of macros to make sure they are available (list taken from manual testing report)
#          - SLE >= 15, also download sources and install multipath-tools to run some macros
#
# Maintainer: QE Core <qe-core@suse.de>

use base 'consoletest';
use testapi;
use serial_terminal 'select_serial_terminal';
use utils;
use version_utils;

sub build_mt {
    zypper_call("in rpm-build");
    zypper_call("si multipath-tools");
    assert_script_run("rpmbuild -bb /usr/src/packages/SPECS/multipath-tools.spec", 180);
}


sub run {
    #Preparation
    select_serial_terminal;

    # Call macros to make sure they are available
    zypper_call("in systemd-rpm-macros");
    assert_script_run 'wget --quiet ' . data_url('console/test_systemd_rpm_macros.sh');
    assert_script_run 'wget --quiet ' . data_url('console/systemd_rpm_macros_list');
    assert_script_run 'chmod +x test_systemd_rpm_macros.sh';
    assert_script_run "./test_systemd_rpm_macros.sh", 900;

    # Test build of multipath-tools on tw, or SLE >= 15
    if (is_sle '>=15') {
        my $repo_name_pattern = "Basesystem.*Source";
        if (is_sle '>=16.0') {
            $repo_name_pattern = "SLE-Product.*Source";
        }
        my $source_repo = script_output(qq(zypper lr|awk '/$repo_name_pattern/ {print \$5}'));
        # enable & disable source repo for multipat-tools source
        if ($source_repo) {
            assert_script_run(qq(zypper mr -e --refresh $source_repo));
        }
        zypper_call("--gpg-auto-import-keys ref", 300) if (get_var('FIPS') || get_var('FIPS_ENABLED'));
        build_mt();
        if ($source_repo) {
            assert_script_run(qq(zypper mr -d $source_repo));
        }
    }
}
1;
