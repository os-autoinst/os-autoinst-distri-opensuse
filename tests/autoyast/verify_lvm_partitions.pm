# SUSE's openQA tests
#
# Copyright 2020 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Package: lvm2
# Summary: Verify lvm partitions after autoyast installation
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

use strict;
use warnings;
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
