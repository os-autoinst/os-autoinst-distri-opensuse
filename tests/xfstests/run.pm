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
use base 'opensusebasetest';
use File::Basename;
use testapi;
use utils;

# Heartbeat variables
my $HB_INTVL   = get_var('XFSTESTS_HEARTBEAT_INTERVAL') || 5;
my $HB_TIMEOUT = get_var('XFSTESTS_HEARTBEAT_TIMEOUT')  || 200;
my $HB_PATN    = '<heartbeat>';
my $HB_DONE    = '<done>';
my $HB_DONE_FILE = '/tmp/test.done';
my $HB_EXIT_FILE = '/tmp/test.exit';
my $HB_SCRIPT    = '/tmp/heartbeat.sh';

# xfstests variables
my $TEST_RANGES  = get_required_var('XFSTESTS_RANGES');
my $TEST_WRAPPER = '/usr/share/qa/qa_test_xfstests/wrapper.sh';
my %BLACKLIST    = map { $_ => 1 } split(/,/, get_var('XFSTESTS_BLACKLIST'));
my $STATUS_LOG   = '/tmp/status.log';
my $INST_DIR     = '/opt/xfstests';
my $LOG_DIR      = '/tmp/log';
my $KDUMP_DIR    = '/tmp/kdump';

# Create heartbeat script, directories(Call it only once)
sub test_prepare {
    my $redir  = " >> /dev/$serialdev";
    my $script = <<END_CMD;
#!/bin/sh
rm -f $HB_DONE_FILE $HB_EXIT_FILE
while [[ ! -f $HB_EXIT_FILE ]]; do
    sleep $HB_INTVL
    [[ -f $HB_DONE_FILE ]] && echo '$HB_DONE' $redir || echo '$HB_PATN' $redir
done
END_CMD
    assert_script_run("cat > $HB_SCRIPT <<'END'\n$script\nEND\n( exit \$?)");
    assert_script_run("mkdir -p $KDUMP_DIR $LOG_DIR");
}

# Start heartbeat, setup environment variables(Call it everytime SUT reboots)
sub heartbeat_start {
    type_string(". ~/.xfstests; nohup sh $HB_SCRIPT &\n");
}

# Stop heartbeat
sub heartbeat_stop {
    type_string("\n");
    assert_script_run("touch $HB_EXIT_FILE");
}

# Wait for heartbeat
sub heartbeat_wait {
    # When under heavy load, the SUT might be unable to send
    # heartbeat messages to serial console. That's why HB_TIMEOUT
    # is set to 200 by default: waiting for such tests to finish.
    my $ret = wait_serial([$HB_PATN, $HB_DONE], $HB_TIMEOUT);
    if ($ret) {
        if ($ret =~ /$HB_PATN/) {
            return ($HB_PATN, '');
        }
        else {
            my $status;
            type_string("\n");
            my $ret = script_output("cat $HB_DONE_FILE; rm -f $HB_DONE_FILE");
            $ret =~ s/^\s+|\s+$//g;
            if ($ret == 0) {
                $status = 'PASSED';
            }
            elsif ($ret == 22) {
                $status = 'SKIPPED';
            }
            else {
                $status = 'FAILED';
            }
            return ($HB_DONE, $status);
        }
    }
    return ('', 'FAILED');
}

# Wait for test to finish
sub test_wait {
    my $time = $HB_INTVL;
    my ($type, $status) = heartbeat_wait;
    while ($type eq $HB_PATN) {
        ($type, $status) = heartbeat_wait;
        $time += $HB_INTVL;
    }
    return ($type, $status, $time);
}

# Return the name of a test(e.g. xfs-005)
# test - specific test(e.g. xfs/005)
sub test_name {
    my $test = shift;
    return $test =~ s/\//-/gr;
}

# Add one test result to log file
# file   - log file
# test   - specific test(e.g. xfs/008)
# status - test status
# time   - time consumed
sub log_add {
    my ($file, $test, $status, $time) = @_;
    my $name = test_name($test);
    my $cmd  = "echo '$name ... ... $status (${time}s)' >> $file && sync";
    type_string("\n");
    assert_script_run($cmd);
}

# Return all the tests of a specific xfstests category
# category - xfstests category(e.g. generic)
# dir      - xfstests installation dir(e.g. /opt/xfstests)
sub tests_from_category {
    my ($category, $dir) = @_;
    my $cmd    = "find '$dir/tests/$category' -regex '.*/[0-9]+'";
    my $output = script_output($cmd, 60);
    my @tests  = split(/\n/, $output);
    foreach my $test (@tests) {
        $test = basename($test);
    }
    return @tests;
}

# Return a list of tests to run from given test ranges
# ranges - test ranges(e.g. xfs/001-100,btrfs/100-159)
# dir    - xfstests installation dir(e.g. /opt/xfstests)
sub tests_from_ranges {
    my ($ranges, $dir) = @_;
    if ($ranges !~ /\w+(\/\d+-\d+)?(,\w+(\/\d+-\d+)?)*/) {
        die "Invalid test ranges: $ranges";
    }

    my %cache;
    my @tests;
    foreach my $range (split(/,/, $ranges)) {
        my ($min, $max) = (0, 99999);
        my ($category, $min_max) = split(/\//, $range);
        if (defined($min_max)) {
            ($min, $max) = split(/-/, $min_max);
        }
        unless (exists($cache{$category})) {
            $cache{$category} = [tests_from_category($category, $dir)];
            assert_script_run("mkdir -p $LOG_DIR/$category");
        }
        foreach my $num (@{$cache{$category}}) {
            if ($num >= $min and $num <= $max) {
                push(@tests, "$category/$num");
            }
        }
    }
    return @tests;
}

# Run a single test and write log to file
# test - test to run(e.g. xfs/001)
sub test_run {
    my $test = shift;
    my ($category, $num) = split(/\//, $test);
    my $cmd = "\n$TEST_WRAPPER '$test' | ";
    $cmd .= "tee $LOG_DIR/$category/$num; ";
    $cmd .= "echo \${PIPESTATUS[0]} > $HB_DONE_FILE\n";
    type_string($cmd);
}

sub run {
    my $self = shift;
    select_console('root-console');

    # Get test list
    my @tests = tests_from_ranges($TEST_RANGES, $INST_DIR);

    test_prepare;
    heartbeat_start;
    foreach my $test (@tests) {
        # Skip tests inside blacklist
        if (exists($BLACKLIST{$test})) {
            next;
        }

        # Run test and wait for it to finish
        my ($category, $num) = split(/\//, $test);

        # TODO: Remove this after kdump data uploading is implemented
        assert_script_run("echo '$test:' | tee /dev/$serialdev");

        test_run($test);
        my ($type, $status, $time) = test_wait;
        if ($type eq $HB_DONE) {
            # Test finished without crashing SUT
            log_add($STATUS_LOG, $test, $status, $time);
            next;
        }

        # SUT crashed. Wait for kdump to finish.
        # After that, SUT will reboot automatically
        eval {
            power_action('reboot', observe => 1, keepconsole => 1);
            $self->wait_boot(in_grub => 1, bootloader_time => 60);
        };
        # If SUT didn't reboot for some reason, force reset
        if ($@) {
            power('reset');
            $self->wait_boot(in_grub => 1);
        }

        sleep(1);
        select_console('root-console');

        # TODO: upload kdump data

        log_add($STATUS_LOG, $test, $status, $time);

        # Prepare for the next test
        heartbeat_start;

    }
    heartbeat_stop;
}

1;
