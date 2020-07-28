# SUSE's openQA tests
#
# Copyright © 2020 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved. This file is offered as-is,
# without any warranty.
#
# Summary: Verify lvm partitions after autoyast installation
# Maintainer: QA SLE YaST team <qa-sle-yast@suse.de>

use strict;
use warnings;
use parent 'installbasetest';
use testapi;
use scheduler 'get_test_suite_data';

sub run {
    my $test_data = get_test_suite_data();
    my $vg        = $test_data->{lvm}->{vg};
    assert_script_run("vgdisplay $vg");
    foreach my $lv (@{$test_data->{lvm}->{lvs}}) {
        assert_script_run("lvdisplay /dev/$vg/$lv");
    }
}

1;
