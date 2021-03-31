# SUSE's openQA tests
#
# Copyright © 2021 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved. This file is offered as-is,
# without any warranty.

# Summary: The test module performs guided partitioning
# Maintainer: QE YaST <qa-sle-yast@suse.de>

use parent 'y2_installbase';
use strict;
use warnings FATAL => 'all';
use testapi;
use scheduler;

sub run {
    my $partitioner = $testapi::distri->get_partitioner();
    my $test_data   = get_test_suite_data();
    $partitioner->guided_setup(%{$test_data->{guided_partitioning}});
}

1;
