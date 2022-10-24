# SUSE's openQA tests
#
# Copyright 2020 SUSE LLC
# SPDX-License-Identifier: FSFAP
# Summary: Basic CPU shielding smoke test with a single memory node
#		The cpuset feature provides “soft partitioning” of the system's CPUs and memory nodes.
#	 	A shielded CPU is dedicated to the activities associated with high-priority real-time tasks.
#		Shield takes care of mounting cpuset filesystems and with naming of cpusets
#		Subcmd *shield* moves all movable tasks to the unshielded cpuset on shield activation
#		A simple shielded configuration typically uses three cpusets:
#				1) root set (always present and contains all CPUs)
#				2) system set (system tasks, unshielded)
#				3) user set (important tasks for user, shielded)
#		Test case should not combine *set* and *proc* subcommands with *shield* to configure sets
# Maintainer: mloviska <mloviska@suse.com>

use base "opensusebasetest";
use strict;
use warnings;
use testapi;
use serial_terminal 'select_serial_terminal';

# Used in post_fail_hook as well
my $cpuset_log = '/var/log/cpuset';

sub run {
    my $cmd_base = 'cset --log ' . $cpuset_log . ' shield ';

    select_serial_terminal;

    # Support for cpuset filesystem has to enabled in kernel during compilation
    ((script_output 'cat /proc/filesystems') =~ m/\bnodev\s+cpuset\b/) or
      die "System does not support cpuset!";

    # List cpusets in default setup
    assert_script_run 'cset set -l';

    # Check if there are any activated shields
    unless (script_run $cmd_base) {
        die 'Shielding has been already defined!';
    }

    # Let's create a shield with CPU1 and CPU3
    # CPU0 should always stay unshielded
    assert_script_run($cmd_base . '--cpu=1,3');
    # Show shields and their processes
    assert_script_run($cmd_base . '--verbose');
    # Show shielded processes only
    assert_script_run($cmd_base . '--verbose --shield');
    # Show unshielded processes only
    assert_script_run($cmd_base . '--verbose --unshield');
    # Shift moveable kernel threads
    assert_script_run($cmd_base . '--kthread=on');
    # Show shielded processes only
    assert_script_run($cmd_base . '--verbose --shield');
    # Show unshielded processes only
    assert_script_run($cmd_base . '--verbose --unshield');
    # Run a new process in the shield
    assert_script_run($cmd_base . '--exec -- ls -l');
    # Shield current shell
    assert_script_run($cmd_base . '-s -p $$');
    # Unshield current shell
    assert_script_run($cmd_base . '-u -p $$');
    # Show shielded processes only
    assert_script_run($cmd_base . '--verbose --shield');
    # Reset to default state
    assert_script_run($cmd_base . '--reset');
}

sub post_fail_hook {
    my $self = shift;

    select_console 'log-console';
    $self->export_logs_basic;
    $self->upload_coredumps;
    upload_logs($cpuset_log) unless (script_run("test -f $cpuset_log"));
}

1;
