# SUSE's openQA tests
#
# Copyright © 2020 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Verify that essential snapshots cannot be deleted, see https://jira.suse.com/browse/SLE-3804
# Maintainer: QA SLE Functional YaST <qa-sle-yast@suse.de>

use strict;
use warnings;
use base "opensusebasetest";
use testapi;
use transactional qw(rpmver get_utt_packages trup_call);
use Test::Assert 'assert_equals';

# Verify that essential snapshots cannot be deleted, see https://jira.suse.com/browse/SLE-3804
sub run {
    select_console 'root-console';

    my @snapshots_before = split /\n/, script_output('snapper list --disable-used-space');
    my $current_snapshot_before;
    foreach (@snapshots_before) {
        if ($_ =~ /(?<current_snapshot_before>^\d+)\*/) {
            $current_snapshot_before = $+{current_snapshot_before};
            last;
        }
    }

    # Create some snapshots with a transactional update snapshot in the middle.
    record_info "Check undel", "Snapshot #1 - Check that essential snapshots cannot be deleted, 
                                creates snapshots and installs a package";
    assert_script_run("snapper create -d \"Disposable snapshot #1\"");
    get_utt_packages;
    trup_call "ptf install" . rpmver('security');
    my $last_snapshot_number = script_output("snapper create -p -d \"Disposable snapshot #2\"");

    my @snapshots_after_update = split /\n/, script_output('snapper list --disable-used-space');
    my $next_snap_after_update;
    my $current_snap_after_update;
    foreach (@snapshots_after_update) {
        $current_snap_after_update = $+{current_snap} if ($_ =~ /(?<current_snap>^\d+)\-/);
        $next_snap_after_update    = $+{next_snap}    if ($_ =~ /(?<next_snap>^\d+)\+/);
    }
    die('Current snapshot was not marked with -') unless $current_snap_after_update;
    die('New snapshot not marked with +')         unless $next_snap_after_update;
    assert_equals($current_snapshot_before, $current_snap_after_update, "Current snapshot number should not change after update");

    my $delete_response = script_output("snapper delete 0-$last_snapshot_number 2>&1");
    unless ($delete_response =~ /^.*0.*current system\..*$current_snap_after_update.*currently mounted.*\..*$next_snap_after_update.*next to be mounted.*\./s) {
        die("Unexpected response from snapper delete:\n$delete_response\n");
    }

    my @snapshots_after = split /\n/, script_output('snapper list --disable-used-space');
    # number of lines for 3 snapshots +header
    my $output_lines = 5;
    die("Incorrect number of snapshots after deletion") if (@snapshots_after != $output_lines);
}

1;
