# SUSE's openQA tests
#
# Copyright © 2021 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved. This file is offered as-is,
# without any warranty.

# Summary: Validate that the subvolumes, specified in the test data,
# exist in the given partition (described by mount point).
# example of expected test data syntax:
# test_data:
#   validate_subvolumes:
#     - subvolume: subvolume1
#       mount_point: /
#     - subvolume: subvolume2
#       mount_point: /home
#
# Maintainer: QA SLE YaST team <qa-sle-yast@suse.de>

use base 'consoletest';
use strict;
use warnings;
use testapi;
use scheduler 'get_test_suite_data';
use partitions_validator_utils 'validate_subvolume';

sub run {
    my $test_data = get_test_suite_data;
    select_console 'root-console';

    foreach my $subvolume (@{$test_data->{validate_subvolumes}}) {
        validate_subvolume({
                subvolume   => $subvolume->{subvolume},
                mount_point => $subvolume->{mount_point}
        });
    }
}

1;
