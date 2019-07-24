# SUSE's openQA tests
#
# Copyright (c) 2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: snapper without DBus service running tests / POO#15944 FATE#321049
# Maintainer: Michal Nowak <mnowak@suse.com>

use strict;
use warnings;
use base 'btrfs_test';
use testapi;
use utils;

# In many cases script output returns not only script execution results
# but other data which was written to serial device. We have to ensure
# that we got what we expect. See poo#25716
sub get_last_snap_number {
    # get snapshot id column, parse output in perl to avoid SIGPIPE
    my $snap_head = (split(/\n/, script_output("snapper list")))[0];
    # strip kernel messages - for some reason we always get something like this at this very position:
    # [ 1248.663412] BTRFS info (device vda2): qgroup scan completed (inconsistency flag cleared)
    my @lines = split(/\n/, $snap_head);
    @lines = grep(/\|/, @lines);
    die "Unable to receive snapshot list column header line" unless (@lines);
    $snap_head = $lines[0];

    my $snap_col_found    = 0;
    my $snap_id_col_index = 1;
    for my $field (split(/\|/, $snap_head)) {
        $field =~ s/^\s+|\s+$//g;    # trim spaces
        if ($field eq '#') {
            # get snapshot id field
            $snap_col_found = 1;
            last;
        }
        $snap_id_col_index++;
    }
    die "Unable to determine snapshot id column index" unless ($snap_col_found);

    my $output = script_output("snapper list | tail -n1 | awk -F '|' '{ print \$$snap_id_col_index }' | tr -d '[:space:]*' | awk '{ print \">>>\" \$1 \"<<<\" }'");
    if ($output =~ />>>(?<snap_number>\d+)<<</) {
        return $+{snap_number};
    }
    die "Could not get last snapshot number, got following output:\n$output";
}

sub run {
    select_console 'root-console';

    my @snapper_cmd = "snapper create";
    my @snap_numbers;
    my $first_snap_to_delete;
    foreach my $type ('single', 'command', 'pre', 'post') {
        my $type_arg = "--type $type";
        $type_arg = "--command \"snapper list | tail -n1\"" if ($type eq 'command');
        push @snapper_cmd, $type_arg;
        foreach my $cleanup_algorithm ('number', 'timeline', 'empty-pre-post') {
            push @snapper_cmd, '--pre-number ' . pop @snap_numbers if ($type eq 'post');
            push @snapper_cmd, "--cleanup-algorithm $cleanup_algorithm";
            my $description = "type=$type,cleanup_algorithm=$cleanup_algorithm";
            push @snapper_cmd, "--print-number --description \"$description\"";
            push @snapper_cmd, "--userdata \"$description\"";
            assert_script_run(join ' ', @snapper_cmd);
            $first_snap_to_delete = get_last_snap_number() unless ($first_snap_to_delete);
            assert_script_run("snapper list | tail -n1");
            for (1 .. 3) { pop @snapper_cmd; }
            if ($type eq 'pre') {
                # Add last snapshot id for pre type
                push @snap_numbers, get_last_snap_number();
            }
        }
        pop @snapper_cmd if ($type eq 'post');
        pop @snapper_cmd;
    }
    assert_script_run("snapper list");
    # Delete all those snapshots we just created so other tests are not confused
    assert_script_run("snapper delete --sync $first_snap_to_delete-" . get_last_snap_number());
    assert_script_run("snapper list");
}

1;

