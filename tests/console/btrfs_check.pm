# SUSE's openQA tests
#
# Copyright 2024 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: btrfs_check
# Summary: Test that btrfs is setup properly
# Maintainer: QE-C team <qa-c@suse.de>

use base 'consoletest';
use strict;
use warnings;
use testapi;
use utils;
use List::Util qw(any);
use serial_terminal 'select_serial_terminal';

sub run {
    select_serial_terminal;

    # Prepare the arrays of subvolumes for comparing
    # TODO: the subvolumes list vary depending on the arch and the version
    my @kiwi_volumes = qw(@ @/.snapshots @/home @/opt @/root @/srv @/usr/local);
    if (check_var('VERSION', '12-SP5')) {
        push(@kiwi_volumes, qw(@/var/cache @/var/log));
    } else {
        push(@kiwi_volumes, '@/var');
    }
    my @test_volumes = split("\n", script_output("btrfs subvolume list / | cut -d ' ' -f 9"));
    record_info('test_volumes', "@test_volumes");
    record_info('kiwi_volumes', "@kiwi_volumes");

    # Compare that the lists of subvolumes match
    foreach my $kiwi (@kiwi_volumes) {
        die "Subvolume $kiwi not present" unless (any { $_ eq $kiwi } @test_volumes);
    }
}

1;
