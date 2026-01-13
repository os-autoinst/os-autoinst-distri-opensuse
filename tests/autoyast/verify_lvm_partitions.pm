# SUSE's openQA tests
#
# Copyright 2020 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Package: lvm2
# Summary: Verify lvm partitions after autoyast installation
# Maintainer: QE Installation and Migration (QE Iam) <none@suse.de>

use parent 'installbasetest';
use testapi;
use scheduler 'get_test_suite_data';

sub run {
    my $test_data = get_test_suite_data();
    my $vg = $test_data->{lvm}->{vg};
    assert_script_run("vgdisplay $vg");
    foreach my $lv (@{$test_data->{lvm}->{lvs}}) {
        assert_script_run("lvdisplay /dev/$vg/$lv");
    }
}

1;
