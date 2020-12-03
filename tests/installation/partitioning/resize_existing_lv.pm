# SUSE's openQA tests
#
# Copyright © 2020 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved. This file is offered as-is,
# without any warranty.

# Summary: modify and resize existing logical volume on a pre-configured disk.
# Maintainer: QE YaST <qa-sle-yast@suse.com>

use strict;
use warnings;
use parent 'y2_installbase';
use testapi;
use version_utils ':VERSION';
use scheduler 'get_test_suite_data';

sub run {
    my $test_data   = get_test_suite_data();
    my $partitioner = $testapi::distri->get_expert_partitioner();
    $partitioner->run_expert_partitioner('current');
    foreach my $vg (@{$args->{volume_groups}}) {
        foreach my $lv (@{$vg->{logical_volumes}}) {
            $partitioner->resize_logical_volume({
                    volume_group   => $vg->{name},
                    logical_volume => $lv->{name},
                    size           => $lv->{size}
            });
        }
    }
    $partitioner->accept_changes_and_press_next();
}

1;
