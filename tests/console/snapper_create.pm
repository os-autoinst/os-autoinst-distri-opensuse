# SUSE's openQA tests
#
# Copyright 2017 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: snapper
# Summary: snapper without DBus service running tests / POO#15944 FATE#321049
# - Run snapper create for the following options:
#   - Types 'single', 'command', 'pre' and 'post'
#   - Cleanup algorithms 'number', 'timeline', and 'empty-pre-post'
#   - Use options --pre-number, --cleanup-algorithm, --print-number,
#     --description, --userdata
#   - List all created snapshots
#   - Cleanup by deleting created snapshots
# Maintainer: Michal Nowak <mnowak@suse.com>

use strict;
use warnings;
use base 'btrfs_test';
use testapi;
use serial_terminal 'select_serial_terminal';
use utils;
use version_utils qw(is_sle);

# In many cases script output returns not only script execution results
# but other data which was written to serial device. We have to ensure
# that we got what we expect. See poo#25716
sub get_last_snap_number {
    # get snapshot id column, parse output in perl to avoid SIGPIPE
    my $snap_head = script_output("snapper list");
    # strip kernel messages - for some reason we always get something like this at this very position:
    # [ 1248.663412] BTRFS info (device vda2): qgroup scan completed (inconsistency flag cleared)
    my @lines = split(/\n/, $snap_head);
    @lines = grep(/\|/, @lines);
    die "Unable to receive snapshot list column header line - got this output: $snap_head" unless (@lines);
    $snap_head = $lines[0];

    my $snap_col_found = 0;
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
    my $self = shift;
    select_serial_terminal;
    $self->cron_mock_lastrun() if is_sle('<15');

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
    assert_script_run("snapper delete --sync $first_snap_to_delete-" . get_last_snap_number(), timeout => 240);
    assert_script_run("snapper list");
}

1;

