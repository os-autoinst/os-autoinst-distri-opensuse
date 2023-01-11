# SUSE's openQA tests
#
# Copyright 2020-2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: snapper btrfsprogs
# Summary: Test snapper create when branching from a different snapshot.
# `snapper` is used for creating the snapshots used by transactional-update and
# not only can create a snapshot of the currently active one, but also has available
# the option `--from` to branch off a different snapshot.
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

use strict;
use warnings;
use base "opensusebasetest";
use testapi;
use utils;
use Test::Assert ':all';
use scheduler 'get_test_suite_data';

sub run {
    select_console 'root-console';

    my $snapshots = get_test_suite_data()->{snapshots};

    my $last_printed_num;    # keep track of last snapshot created
    my $last_uuid;    # keep track of last snapshot uuid
    my $btrfs_info;

    # process each snapshot according to test data
    foreach my $snapshot (@{$snapshots}) {
        record_info("snap", $snapshot->{description});

        # display list of snapshots
        assert_script_run("snapper ls");

        # make up next 'snapper create'
        my $snapper_args = "--print-number -d '$snapshot->{description}'";
        $snapper_args .= " --read-write" if ($snapshot->{read_write});
        $snapper_args .= " --from $last_printed_num" if ($snapshot->{from});

        # execute snapper create when testing for failure and exit earlier
        if ($snapshot->{from_non_existing_parent}) {
            my $non_existing_snapshot = ($last_printed_num + 1);
            $snapper_args .= " --from $non_existing_snapshot";
            script_run("snapper create $snapper_args 2>&1 " .
                  "| grep 'Snapshot \'$non_existing_snapshot\' not found.'");
            next;
        }

        # execute snapper create
        $last_printed_num = script_output("snapper create $snapper_args");

        # validate created snapshot
        assert_script_run("snapper ls | grep '$snapshot->{description}'");
        $btrfs_info = script_output("btrfs subvolume show /.snapshots/$last_printed_num/snapshot/");
        $btrfs_info =~
          /UUID:\s+(?<UUID>.*?)\n\s+Parent UUID:\s+(?<Parent_UUID>.*?)\n.*Flags:\s+(?<Flags>.*?)\n/s;
        if ($snapshot->{from}) {
            assert_equals($last_uuid, $+{Parent_UUID}, "Child snapshot not set Parent properly in btrfs");
        }
        $last_uuid = $+{UUID};
        assert_equals($snapshot->{flags}, $+{Flags}, "Flags attribute is wrongly set in btrfs");
    }
}

1;
