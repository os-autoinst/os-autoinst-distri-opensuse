# SUSE's openQA tests
#
# Copyright © 2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.
#
# Summary: Run tests
# Maintainer: Nathan Zhao <jtzhao@suse.com>
package run;

use 5.018;
use strict;
use warnings;
use base "opensusebasetest";
use File::Basename;
use testapi;
use utils;
use kdump_utils;

# Heartbeat variables
my $HB_INTVL   = get_var("XFSTESTS_HEARTBEAT_INTERVAL") || 5;
my $HB_TIMEOUT = get_var("XFSTESTS_HEARTBEAT_TIMEOUT")  || 300;
my $HB_PATN    = "<heartbeat>";
my $HB_DONE    = "<done>";
my $HB_LOCKUP  = "NMI watchdog: BUG: soft lockup";
my $HB_RAMFS   = "/mnt/ramfs";
my $HB_DONE_FILE = "$HB_RAMFS/test.done";
my $HB_EXIT_FILE = "$HB_RAMFS/test.exit";

# xfstests variables
my $WRAPPER  = "/usr/share/qa/qa_test_xfstests/wrapper.sh";
my $LOG_FILE = "/tmp/xfstests.log";

# blacklist
my %BLACKLIST = map { $_ => 1 } split(/,/, get_var("XFSTESTS_BLACKLIST"));


sub heartbeat_start {
    # Create ramfs
    assert_script_run("mkdir -p $HB_RAMFS; umount -f $HB_RAMFS; mount -t ramfs none $HB_RAMFS");

    my $redir = " >> /dev/$serialdev";
    my $cmd   = "while [[ ! -f $HB_EXIT_FILE ]]; do ";
    $cmd .= "sleep $HB_INTVL; ";
    $cmd .= "[[ -f $HB_DONE_FILE ]] && ";
    $cmd .= "echo \"$HB_DONE\" $redir || echo \"$HB_PATN\" $redir";
    $cmd .= "; done";
    script_run("rm -f $HB_DONE_FILE $HB_EXIT_FILE");
    type_string("nice -n -20 bash -c '$cmd' &\n");
}

# Stop heartbeat
sub heartbeat_stop {
    type_string("\n");
    assert_script_run("touch $HB_EXIT_FILE");
}

# Wait for heartbeat
sub heartbeat_wait {
    # When under heavy load, the system might be unable to send
    # heartbeat messages to serial console. That's why HB_TIMEOUT
    # is set to 300 by default: waiting for such tests to finish.
    my $ret = wait_serial([$HB_PATN, $HB_DONE, $HB_LOCKUP], $HB_TIMEOUT);
    if ($ret) {
        if ($ret =~ /$HB_PATN/) {
            return ($HB_PATN, "");
        }
        elsif ($ret =~ /$HB_LOCKUP/) {
            return ($HB_LOCKUP, "FAILED");
        }
        else {
            my $status;
            type_string("\n");
            my $ret = script_output("cat $HB_DONE_FILE; rm -f $HB_DONE_FILE");
            $ret =~ s/^\s+|\s+$//g;
            if ($ret == 0) {
                $status = "PASSED";
            }
            elsif ($ret == 22) {
                $status = "SKIPPED";
            }
            else {
                $status = "FAILED";
            }
            return ($HB_DONE, $status);
        }
    }
    return ("", "FAILED");
}

# Wait for test to finish
sub test_wait {
    my $time = 0;
    my ($type, $status) = heartbeat_wait;
    while ($type eq $HB_PATN) {
        ($type, $status) = heartbeat_wait;
        $time += $HB_INTVL;
    }
    return ($type, $status, $time);
}

# Add one test result to log file
sub log_add {
    my ($file, $name, $status, $time) = @_;
    my $cmd = "echo '$name ... ... $status (${time}s)' >> $file";
    type_string("\n");
    assert_script_run($cmd);
}

# Create log dir and set environment variables
sub test_prepare {
    my $category = shift;
    type_string("mkdir -p /tmp/$category; . ~/.xfstests\n");
}

# List all the tests of a specific category
sub test_list {
    my $dir    = shift;
    my $output = script_output("find $dir -regex '.*/[0-9]+'", 200);
    my @tests  = split(/\n/, $output);
    foreach my $test (@tests) {
        $test = basename($test);
    }
    return @tests;
}

# Run a single test and write log to file
# category - category of tests(e.g. xfs, btrfs, generic)
# test  - specific test(e.g. 001, 002)
sub test_run {
    my $category = shift;
    my $test     = shift;
    my $cmd      = "\n$WRAPPER '$category/$test' | ";
    $cmd .= "tee /tmp/$category/$test.log; ";
    $cmd .= "echo \${PIPESTATUS[0]} > $HB_DONE_FILE\n";
    type_string($cmd);
}


sub run {
    my $self = shift;
    select_console('root-console');

    # Get test list
    my ($filesystem, $category) = split(/-/, get_var("XFSTESTS"));
    my @tests = test_list("/opt/xfstests/tests/$category");

    heartbeat_start;
    test_prepare($category);
    my @crashed;
    foreach my $test (@tests) {
        if (exists($BLACKLIST{"$category/$test"})) {
            next;
        }

        my $name = "$category-$test";
        test_run($category, $test);
        my ($type, $status, $time) = test_wait;
        if ($type eq $HB_DONE) {
            # Test finished
            log_add($LOG_FILE, $name, $status, $time);
            next;
        }
        if ($type eq $HB_LOCKUP) {
            # Soft lockup
            power("reset");
        }
        else {
            # Normally kdump should already be started, and
            # system will automatically reboot after it's done,
            # so we just need to observe it.
            power_action('reboot', observe => 1, keepconsole => 1);
        }
        $self->wait_boot;
        sleep(1);
        select_console('root-console');
        log_add($LOG_FILE, $name, $status, $time);
        heartbeat_start;
        test_prepare($category);

        # TODO: upload kdump dmesg
        push(@crashed, "$category/$test");
    }
    heartbeat_stop;
    script_run("echo '@crashed'");
}

1;
