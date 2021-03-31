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
use scheduler 'get_test_suite_data';

sub run {
    my $test_data    = get_test_suite_data()->{guided_partitioning};
    my $guided_setup = $testapi::distri->get_guided_partitioner();

    $guided_setup->setup_partitioning_scheme($test_data->{partitioning_scheme});
    $guided_setup->setup_filesystem_options($test_data->{filesystem_options});
}

1;
