# SUSE's openQA tests
#
# Copyright © 2020 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: systemd-rpm-macros test
#          - call a list of macros to make sure they are available (list taken from manual testing report)
#          - if Tumbleweed or SLE >= 15, also download sources and install multipath-tools to run some macros
#
# Maintainer: Michael Grifalconi <mgrifalconi@suse.com>

use base 'consoletest';
use strict;
use warnings;
use testapi;
use utils;
use version_utils;
use registration qw(add_suseconnect_product);

sub build_mt {
    zypper_call("in rpmbuild");
    zypper_call("si multipath-tools");
    assert_script_run 'rpmbuild -bb /usr/src/packages/SPECS/multipath-tools.spec';
}


sub run {
    #Preparation
    my $self = shift;
    $self->select_serial_terminal;

    # Call macros to make sure they are available
    zypper_call("in systemd-rpm-macros");
    assert_script_run 'wget --quiet ' . data_url('console/test_systemd_rpm_macros.sh');
    assert_script_run 'wget --quiet ' . data_url('console/systemd_rpm_macros_list');
    assert_script_run 'chmod +x test_systemd_rpm_macros.sh';
    assert_script_run "./test_systemd_rpm_macros.sh", 900;

    # Test build of multipath-tools on tw, or SLE >= 15
    if (is_sle '>=15') {
        add_suseconnect_product('PackageHub', undef, undef, undef, 300, 1);
        build_mt();
    } elsif (is_tumbleweed) {
        zypper_call("ar -f http://download.opensuse.org/source/tumbleweed/repo/oss/ my-source-repo");
        build_mt();
        zypper_call("rr my-source-repo");
    }
}
1;
