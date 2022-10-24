# SUSE's openQA tests
#
# Copyright 2018-2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: snapper btrfsprogs
# Summary: Display of used space per snapshot
# Tags: poo#17848
# - Check if quota is enabled
# - Display the exclusive space used by each snapshot
# - Query the exclusive space when data is included in a single snapshot
# - Query the exclusive space when data is included in several snapshots (pre- and post-)
# Maintainer: QE YaST <qa-sle-yast@suse.de>

use base 'btrfs_test';
use strict;
use warnings;
use testapi;
use serial_terminal 'select_serial_terminal';

use constant COLUMN_FILTER => "awk -F '|' '{print \$1  \$6}'";    # Filter by columns: # and Used Space
use constant SUBVOLUME_FILTER => "tail -n4 | sed -n 2,3p | cut -d ' ' -f2";    # Subvolume IDs
use constant CREATE_BIG_FILE => "touch /big-data && btrfs prop set /big-data compression 'none' && dd if=/dev/zero of=/big-data bs=1M count=1024";
use constant REMOVE_BIG_FILE => "rm /big-data";

=head2 ensure_size_displayed
Ensure column for size is displayed or not if flag is provided
=cut
sub ensure_size_displayed {
    # Displays the exclusive space used by each snapshot
    assert_script_run "snapper list | awk -F '|' '{print \$6}' | grep -E 'Used Space|iB'";
    # if flag set to disable it will be display Cleanup column instead
    assert_script_run "snapper list --disable-used-space | awk -F '|' '{print \$6}' | grep -E 'Cleanup|number'";
}

=head2 query_space_single_snapshot
Query the exclusive space when data is included in a single snapshot
=cut
sub query_space_single_snapshot {
    record_info("Query single", "Query the exclusive space when data is included in a single snapshot");
    # Create 1GiB file in the root file system.
    assert_script_run CREATE_BIG_FILE;
    # Create snapshot
    assert_script_run 'snapper create --cleanup number --print-number';
    # Check data is not exclusive to that snapshot
    assert_script_run 'snapper list | tail -n1 | ' . COLUMN_FILTER . ' | grep KiB';
    # Remove file
    assert_script_run REMOVE_BIG_FILE;
    # Check data is exclusive to that snapshot and used space grows 1GiB
    assert_script_run 'snapper list | tail -n1 | ' . COLUMN_FILTER . ' | grep \'1.00 GiB\'';
}

=head2 query_space_several_snapshot
Query the exclusive space when data is included in several snapshots (pre- and post-)
=cut
sub query_space_several_snapshot {
    record_info("Query multiple", "Query the exclusive space when data is included in several snapshots");
    my $args = '--cleanup number --print-number';
    foreach my $action (qw(create remove)) {
        my $command = '"' . ($action eq "create" ? CREATE_BIG_FILE : REMOVE_BIG_FILE) . '"';
        my $description = '"' . $action . ' big data"';
        # Create two pair of pre- and post- snapshots
        assert_script_run "snapper create --command $command --description $description $args";
    }
    # Check that correct used space does not show up in any of the snapshots.
    assert_script_run 'snapper list | tail -n4 | ' . COLUMN_FILTER . ' | grep KiB';
    # Filter snapshots containing the data (intermediate ones)
    my @ids = split(/\n/, script_output('btrfs subvolume list / | ' . SUBVOLUME_FILTER));
    # Create a new higher level qgroup
    assert_script_run 'btrfs qgroup create 1/1 /';
    # Add snapshots to the group
    assert_script_run "btrfs qgroup assign --no-rescan 0/$_ 1/1 /" foreach (@ids);
    # run quota
    assert_script_run 'btrfs quota rescan -w /';
    # query the exclusive space
    assert_script_run "btrfs qgroup show -p / | grep -E '1/1.*1.00GiB'";
}

sub run {
    select_serial_terminal;
    die 'Quota must be enabled on btrfs for this test' if (script_run('snapper get-config | grep QGROUP') != 0);
    ensure_size_displayed;
    query_space_single_snapshot;
    query_space_several_snapshot;
}

1;
