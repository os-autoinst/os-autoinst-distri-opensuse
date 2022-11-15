# SUSE's openQA tests
#
# Copyright 2020-2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: systemd-rpm-macros test
#          - call a list of macros to make sure they are available (list taken from manual testing report)
#          - if Tumbleweed or SLE >= 15, also download sources and install multipath-tools to run some macros
#
# Maintainer: QE Core <qe-core@suse.de>

use base 'consoletest';
use strict;
use warnings;
use testapi;
use serial_terminal 'select_serial_terminal';
use utils;
use version_utils;
use registration qw(add_suseconnect_product);

sub build_mt {
    zypper_call("in rpmbuild");
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
        # enable & disable source repo for multipat-tools source
        assert_script_run(q(zypper mr -e --refresh $(zypper lr|awk '/Basesystem.*Source/ {print$5}')));
        add_suseconnect_product('PackageHub', undef, undef, undef, 300, 1);
        build_mt();
        assert_script_run(q(zypper mr -d $(zypper lr|awk '/Basesystem.*Source/ {print$5}')));
    } elsif (is_tumbleweed) {
        zypper_call("ar -f http://download.opensuse.org/source/tumbleweed/repo/oss/ my-source-repo");
        build_mt();
        zypper_call("rr my-source-repo");
    }
}
1;
