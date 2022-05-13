# SUSE's openQA tests
#
# Copyright 2019 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: Run tests
# Maintainer: An Long <lan@suse.com>
use strict;
use warnings;
use base 'opensusebasetest';
use File::Basename;
use testapi;
use utils;
use power_action_utils 'power_action';

# btrfs-progs variables
my @blacklist = split(/,/, get_var('TESTS_BLACKLIST'));
my @category = split(/,/, get_required_var('CATEGORY'));

use constant STATUS_LOG => '/opt/status.log';
use constant LOG_DIR => '/opt/logs/';

# Return a test list of a specific btrfs-progs category
# blacklist (e.g. cli/001,cli/003-005,fuzz/003)
sub get_test_list {
    my $category = shift;
    my $cmd = "find $category-tests -maxdepth 1 -type d -regex .*/[0-9]+.+";
    my $output = script_output($cmd, 30);
    my @tests = split(/\n/, $output);
    foreach my $test (@tests) {
        $test = basename($test);
        $test = substr("$test", 0, 3);
    }

    # Genarate blacklist
    my @blacklist_cat = map(substr($_, length("$category/")), grep(/$category\//, @blacklist));
    my @blacklist_copy;
    for my $list (@blacklist_cat) {
        $list =~ s/\s+//g;
        if ($list =~ /^(\d{3})-(\d{3})$/) {
            push(@blacklist_copy, ($1 .. $2));
        }
        elsif ($list =~ /^\d{3}$/) {
            push(@blacklist_copy, $list);
        }
        else {
            die "Invalid test blacklist: $list";
        }
    }

    # Remove blacklist tests
    my %hash_blacklist = map { $_ => 1 } @blacklist_copy;
    @tests = grep { !$hash_blacklist{$_} } @tests;

    return @tests;
}

# Run a single test, return test result and copy log to file
# category - category of test set(e.g. cli)
# num - test to run(e.g. 001)
sub test_run {
    my ($category, $num) = @_;
    my $status = 'PASSED';
    my $logfile = "$category-tests-results.txt";

    script_run("./clean-tests.sh");
    my $ret = script_output("TEST=$num\\* ./$category-tests.sh | tee output.log", 1800, proceed_on_failure => 1);

    if ($ret =~ /test\s+failed\s+for\s+case/i) {
        $status = 'FAILED';
    }
    elsif ($ret =~ /NOTRUN|[Ff]ailed\s+prerequisiti?es/) {
        $status = 'SKIPPED';
        $logfile = 'output.log';
    }
    script_run("cp $logfile " . LOG_DIR . "$category/$num.txt");
    return $status;
}

# Add one test result to log file
# file   - log file
# test   - specific test(e.g. xfs/008)
# status - test status
# time   - time consumed
sub log_add {
    my ($file, $name, $status, $time) = @_;
    my $cmd = "echo '$name ... ... $status (${time}s)' >> $file && sync $file";
    send_key 'ret';
    assert_script_run($cmd);
}

sub run {
    my $self = shift;
    select_console('root-console');

    assert_script_run('cd ' . get_var('WORK_DIR'));
    assert_script_run('btrfs version | tee ' . STATUS_LOG);
    for my $category (@category) {
        assert_script_run('mkdir -p ' . LOG_DIR . $category);

        # Get test list
        my @tests = get_test_list($category);

        my $status;
        for my $test (@tests) {
            # Run test and wait for it to finish
            my $begin = time();
            $status = test_run($category, $test);
            my $delta = time() - $begin;

            # Add test status to STATUS_LOG file
            log_add(STATUS_LOG, "$category-$test", $status, $delta);
        }
        set_var('SOFT_FAILURE', 1) if (@tests == 1) && ($status eq 'SKIPPED');
    }
}

1;
