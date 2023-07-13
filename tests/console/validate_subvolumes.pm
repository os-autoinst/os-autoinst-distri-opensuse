# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

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
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

use base 'consoletest';
use strict;
use warnings;
use testapi;
use scheduler 'get_test_suite_data';

sub validate_subvolume {
    my $args = shift;
    record_info("Check $args->{subvolume}",
        "Check if $args->{subvolume} subvolume exists in $args->{mount_point} partition");
    assert_script_run("btrfs subvolume list $args->{mount_point} | grep $args->{subvolume}",
        fail_message => "Subvolume $args->{subvolume} does not exist in $args->{mount_point} partition");
}

sub run {
    my $test_data = get_test_suite_data;
    select_console 'root-console';

    foreach my $subvolume (@{$test_data->{validate_subvolumes}}) {
        validate_subvolume({
                subvolume => $subvolume->{subvolume},
                mount_point => $subvolume->{mount_point}
        });
    }
}

1;
