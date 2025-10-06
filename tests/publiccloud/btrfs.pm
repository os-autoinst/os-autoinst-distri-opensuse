# SUSE's openQA tests
#
# Copyright SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Test BTRFS filesystem on SLE 16+
#
# Maintainer: QE-C team <qa-c@suse.de>

use Mojo::Base 'publiccloud::basetest';
use testapi;
use utils;
use serial_terminal qw(select_serial_terminal);

sub run {
    my ($self, $args) = @_;

    my $btrfs_binary = '/sbin/btrfs';

    select_serial_terminal();

    record_info("BTRFS", "Testing btrfs scrub");

    assert_script_run(qq{$btrfs_binary scrub start -B -R /});
    script_retry(qq{$btrfs_binary scrub status / | grep -E "Status:\\s+finished"}, retry => 30, delay => 20, timeout => 600);
    assert_script_run(qq{$btrfs_binary scrub status / | grep -E "Error summary:\\s+no errors found"});
}

sub test_flags {
    return {fatal => 1, publiccloud_multi_module => 1};
}

1;
