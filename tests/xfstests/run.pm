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
# Maintainer: Yong Sun <yosun@suse.com>
package run;

use 5.018;
use strict;
use warnings;
use base 'opensusebasetest';
use File::Basename;
use testapi;
use utils;
use power_action_utils 'power_action';

# Heartbeat variables
my $HB_INTVL   = get_var('XFSTESTS_HEARTBEAT_INTERVAL') || 30;
my $HB_TIMEOUT = get_var('XFSTESTS_HEARTBEAT_TIMEOUT')  || 40;
my $HB_PATN    = '<heartbeat>';
my $HB_DONE    = '<done>';
my $HB_DONE_FILE = '/opt/test.done';
my $HB_EXIT_FILE = '/opt/test.exit';
my $HB_SCRIPT    = '/opt/heartbeat.sh';

# xfstests variables
my $TEST_RANGES  = get_required_var('XFSTESTS_RANGES');
my $TEST_WRAPPER = '/usr/share/qa/qa_test_xfstests/wrapper.sh';
my %BLACKLIST    = map { $_ => 1 } split(/,/, get_var('XFSTESTS_BLACKLIST'));
my $STATUS_LOG   = '/opt/status.log';
my $INST_DIR     = '/opt/xfstests';
my $LOG_DIR      = '/opt/log';
my $KDUMP_DIR    = '/opt/kdump';
my $MAX_TIME     = 2400;

# Create heartbeat script, directories(Call it only once)
sub test_prepare {
    my $redir  = " >> /dev/$serialdev";
    my $script = <<END_CMD;
#!/bin/sh
rm -f $HB_DONE_FILE $HB_EXIT_FILE
declare -i c=0
while [[ ! -f $HB_EXIT_FILE ]]; do
    if [[ -f $HB_DONE_FILE ]]; then
        c=0
        echo "$HB_DONE" $redir
        sleep 2
    elif [[ \$c -ge $HB_INTVL ]]; then
        c=0
        echo "$HB_PATN" $redir
    else
        c+=1
    fi
    sleep 1
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
    my $timeout = shift;
    my $begin   = time();
    my ($type, $status) = heartbeat_wait;
    my $delta = time() - $begin;
    while ($type eq $HB_PATN and $delta < $timeout) {
        ($type, $status) = heartbeat_wait;
        $delta = time() - $begin;
    }
    if ($type eq $HB_PATN) {
        return ('', 'FAILED', $delta);
    }
    return ($type, $status, $delta);
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
    my $cmd  = "echo '$name ... ... $status (${time}s)' >> $file && sync $file";
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
        unless (defined($min_max)) {
            next;
        }
        if ($min_max =~ /\d+-\d+/) {
            ($min, $max) = split(/-/, $min_max);
        }
        else {
            $min = $max = $min_max;
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
    my $cmd = "\n$TEST_WRAPPER '$test' | tee $LOG_DIR/$category/$num; ";
    $cmd .= "echo \${PIPESTATUS[0]} > $HB_DONE_FILE\n";
    type_string($cmd);
}

# Save kdump data for further uploading
# test   - corresponding test(e.g. xfs/009)
# dir    - Save kdump data to this dir
# vmcore - include vmcore file
# kernel - include kernel
sub save_kdump {
    my ($test, $dir, %args) = @_;
    $args{vmcore} ||= 0;
    $args{kernel} ||= 0;
    my $name = test_name($test);
    my $ret  = script_run("mv /var/crash/* $dir/$name");
    return 0 if $ret != 0;

    my $removed = "";
    unless ($args{vmcore}) {
        $removed .= " $dir/$name/vmcore";
    }
    unless ($args{kernel}) {
        $removed .= " $dir/$name/*.{gz,bz2,xz}";
    }
    if ($removed) {
        assert_script_run("rm -f $removed");
    }
    return 1;
}

# Kunth shuffle
sub shuffle {
    my @arr = @_;
    srand(time());
    for (my $i = $#arr; $i > 0; $i--) {
        my $j = int(rand($i + 1));
        ($arr[$i], $arr[$j]) = ($arr[$j], $arr[$i]);
    }
    return @arr;
}

# Copy log to ready to save
sub copy_log {
    my ($category, $num, $log_type) = @_;
    my $cmd = "if [ -e /opt/xfstests/results/$category/$num.$log_type ]; then cat /opt/xfstests/results/$category/$num.$log_type | tee $LOG_DIR/$category/$num.$log_type; fi";
    script_run($cmd);
}

sub dump_btrfs_img {
    my ($category, $num) = @_;
    my $cmd = "echo \"no inconsistent error, skip btrfs image dump\"";
    my $ret = script_output("egrep -m 1 \"filesystem on .+ is inconsistent\" $LOG_DIR/$category/$num");
    if ($ret =~ /filesystem on (.+) is inconsistent/) { $cmd = "umount $1;btrfs-image $1 $LOG_DIR/$category/$num.img"; }
    script_run($cmd);
}

sub run {
    my $self = shift;
    select_console('root-console');

    # Get test list
    my @tests = tests_from_ranges($TEST_RANGES, $INST_DIR);
    @tests = shuffle(@tests);

    test_prepare;
    heartbeat_start;
    foreach my $test (@tests) {
        # Skip tests inside blacklist
        if (exists($BLACKLIST{$test})) {
            next;
        }

        # Run test and wait for it to finish
        my ($category, $num) = split(/\//, $test);
        type_string("echo $test > /dev/$serialdev\n");
        test_run($test);
        my ($type, $status, $time) = test_wait($MAX_TIME);
        if ($type eq $HB_DONE) {
            # Test finished without crashing SUT
            log_add($STATUS_LOG, $test, $status, $time);
            if ($status =~ /FAILED/) {
                copy_log($category, $num, 'out.bad');
                copy_log($category, $num, 'full');
                copy_log($category, $num, 'dmesg');
                # Disable dump_btrfs_img to avoid disk exhaust
		#if (check_var 'XFSTESTS', 'btrfs') { dump_btrfs_img($category, $num); }
            }
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
        # Save kdump data to KDUMP_DIR if not set "NO_KDUMP"
        unless (get_var('NO_KDUMP')) {
            unless (save_kdump($test, $KDUMP_DIR)) {
                # If no kdump data found, write warning to log
                my $msg = "Warning: $test crashed SUT but has no kdump data";
                script_run("echo '$msg' >> $LOG_DIR/$category/$num");
            }
        }

        # Add test status to STATUS_LOG file
        log_add($STATUS_LOG, $test, $status, $time);

        # Prepare for the next test
        heartbeat_start;

    }
    heartbeat_stop;
}

1;
