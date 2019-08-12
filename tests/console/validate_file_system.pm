# SUSE's openQA tests
#
# Copyright © 2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved. This file is offered as-is,
# without any warranty.

# Summary: Validation module to check File system on partition(s).
# Requires 'test_data->{file_system}' to be specified in yaml scheduling file,
# so that it allows to check the File system on any amount of partitions
# by iterating over the hash.
# Maintainer: Oleksandr Orlov <oorlov@suse.de>

use strict;
use warnings;
use base "opensusebasetest";
use testapi;
use scheduler 'get_test_data';
use Test::Assert ':all';

sub run {
    my $test_data  = get_test_data();
    my %partitions = %{$test_data->{file_system}};

    foreach (keys %partitions) {
        record_info("Check fs $_", "Verify the '$_' partition filesystem is '$partitions{$_}'");
        my $fstype = script_output("df -PT $_ | grep -v \"Filesystem\" | awk '{print \$2}'");
        assert_equals($partitions{$_}, $fstype,
            "File system on '$_' partition does not correspond to the expected one");
    }

}

1;
