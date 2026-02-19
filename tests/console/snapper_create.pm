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

use Mojo::Base qw(btrfs_test);
use testapi;
use serial_terminal 'select_serial_terminal';
use utils;
use version_utils qw(is_sle);

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
            $first_snap_to_delete = $self->get_last_snap_number() unless ($first_snap_to_delete);
            assert_script_run("snapper list | tail -n1");
            for (1 .. 3) { pop @snapper_cmd; }
            if ($type eq 'pre') {
                # Add last snapshot id for pre type
                push @snap_numbers, $self->get_last_snap_number();
            }
        }
        pop @snapper_cmd if ($type eq 'post');
        pop @snapper_cmd;
    }
    assert_script_run("snapper list");
    # Delete all those snapshots we just created so other tests are not confused
    assert_script_run("snapper delete --sync $first_snap_to_delete-" . $self->get_last_snap_number(), timeout => 240);
    assert_script_run("snapper list");
    # check whether average system load is below treshold
    # wait until the load gets below 0.2
    select_console 'root-console';
    # 6s per iteration -> 10min by default
    my $iterations = 100 * get_var('TIMEOUT_SCALE', 1);
    my $cmd = qq(for i in {1..${iterations}}; do read -d' ' load </proc/loadavg; uptime > /dev/$serialdev; if [ "\${load/./}" -le 10 ]; then echo 'LOAD_OK' > /dev/$serialdev; break; fi; sleep 6; done);
    enter_cmd("( $cmd )\&");
    wait_serial('LOAD_OK', timeout => 600, no_regex => 1) or die 'System average load was not settled after taking snapshots';
}

1;

