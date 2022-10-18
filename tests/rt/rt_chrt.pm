# SUSE's openQA tests
#
# Copyright 2019 SUSE LLC
# SPDX-License-Identifier: FSFAP
# Summary: Manage processes with chrt command
#           1) Retrieve scheduler's extreme values (min/max) for priorities
#           2) Verify that RT processes have already exist
#           3) Execute a new process as rt_tester
#           4) Add rt atributtes to the process started by rt_tester
#           5) Increase and Reduce its priority
#           6) Try to assign unsupported priority values to the running proces
#           7) Use rtkit to reset all rt processes
#           8) Clean up after yourself!
#           To avoid throttling add more CPUs
# Maintainer: mloviska <mloviska@suse.com>

use base "opensusebasetest";
use strict;
use warnings;
use testapi;
use serial_terminal 'select_serial_terminal';
use Utils::Systemd 'systemctl';
use version_utils qw(is_sle);

#****************************** SLERT default setup ******************************#
# The default values for sched_rt_period_us (1000000 or 1s) and
# sched_rt_runtime_us (950000 or 0.95s).  This gives 0.05s to be used by
# SCHED_OTHER (non-RT tasks). These defaults were chosen so that a run-away
# realtime tasks will not lock up the machine but leave a little time to recover it
#************************************* EoM ***************************************#
# Filter out all runnig RT processes,
# expected to see FF - SCHED_FIFO or RR - SCHED_RR processes ( rt-process scheduler policies )
# TS - SCHED_OTHER is the standard Linux time-sharing scheduler for all threads that do not require real-time mechanisms
sub snapshot_running_rt_processes {
    my @rt_ps_list = grep { s/^\s+//;
        s/\s+/ /g;
        !/^TS\s/;
    } (split('\n', script_output 'ps -e -o cls,pid,pri,command'));

    die "There are no RT processes!\n" unless (@rt_ps_list);
    # remove the header from ps output
    shift @rt_ps_list;
    return \@rt_ps_list;
}

sub remap_args {
    my $type = shift;
    my %arg_map = (SCHED_FIFO => '--fifo', SCHED_RR => '--rr');
    die 'Scheduler type does not exist!' unless exists $arg_map{$type};

    return $arg_map{$type};
}

sub run {
    my $self = shift;

    select_serial_terminal;

    # Are there any running RT processes ?
    print "List of all running RT processes:\n";
    print $_, "\n" foreach (@{snapshot_running_rt_processes()});

    # Print and store min/max priority settings
    # SCHED_RR and SCHED_FIFO should have valid min and max values set by default
    # RT sched_priority values in the range 1 (low) to 99 (high)
    # real-time threads always have higher priority than normal threads
    # PR = 20 + NI (-20 to +19)
    # PR = -1 - real_time_priority
    record_info('Scheduler policies', 'Print current policy settings');
    my $sched_settings = {};
    foreach (grep { /SCHED_FIFO|SCHED_RR|SCHED_OTHER/ } (split('\n', script_output 'chrt -m'))) {
        my $sched_type = (split(/\s/, $_))[0];
        my ($p_mix, $p_max) = split(/\//, (split(/\s/, $_))[-1]);
        $sched_settings->{$sched_type} = {min => $p_mix, max => $p_max};
        record_info(
            "$sched_type",
            "min prio -> $sched_settings->{$sched_type}->{min}\nmax prio -> $sched_settings->{$sched_type}->{max}"
        );
    }
    my $sched_features = is_sle("15-sp4+") ? '/sys/kernel/debug/sched/features' : '/sys/kernel/debug/sched_features';
    record_info('sched_features', script_output "cat ${sched_features}");

    # RealtimeKit is a D-Bus system service that changes the scheduling policy of user processes/threads to SCHED_RR on request
    # It is intended to be used as a secure mechanism to allow real-time scheduling to be used by normal user processes.
    record_info('Service', 'Is rtkit-daemon.service active?');
    systemctl 'is-active rtkit-daemon.service';

    # Retrieve PID of bash on bg
    # Save PID in bash env
    assert_script_run 'useradd -m rt_tester';
    assert_script_run "sudo -bu rt_tester 'bash'";
    assert_script_run q{BG_BASH_PID=`ps -U rt_tester | awk 'END{print $1}'`};

    # User *rt_tester* has created a proces with SCHED_OTHER and Priority 0
    assert_script_run q{chrt -p $BG_BASH_PID};

    foreach (qw(SCHED_RR SCHED_FIFO)) {
        my $scheduler_policy = remap_args($_);
        my $scheduler = $_;
        # Try to modify *rt_tester's* bash proces with a sequence of valid and invalid priorities
        foreach ($sched_settings->{$scheduler}->{min}, 42, 100, -1, $sched_settings->{$scheduler}->{max}) {
            record_info('Change', "Change policy to $scheduler, set priority to $_");
            if ((script_run qq{chrt $scheduler_policy -p $_ \$BG_BASH_PID})
                && ($_ > 99 && $_ < 0)) {
                die 'Unsupported priority value for the policy';
            }
            assert_script_run q{awk '{print "PR="$18 "\nNI=" $19}' /proc/$BG_BASH_PID/stat};
            assert_script_run q{chrt -p $BG_BASH_PID};
        }
    }

    record_info('Cleanup', 'This is the end!');
    assert_script_run q{rtkitctl --reset-all};
    assert_script_run q{awk '{print "PR="$18 "\nNI=" $19}' /proc/$BG_BASH_PID/stat};
    assert_script_run q{chrt -p $BG_BASH_PID};
    assert_script_run('killall -u rt_tester -s 9');
    assert_script_run('userdel -rf rt_tester');
}


sub post_fail_hook {
    my $self = shift;

    select_console 'log-console';
    $self->export_logs_basic;
    $self->upload_coredumps;
}

1;
