# SUSE's openQA tests
#
# Copyright © 2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.
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

use constant CATEGORY   => get_var('CATEGORY', 'no_var');
use constant STATUS_LOG => '/opt/status.log';
use constant LOG_DIR    => '/opt/logs/';

if (CATEGORY eq 'no_var') { die "Could not retrieve required variable CATEGORY"; }

# Return a test list of a specific btrfs-progs category
# blacklist (e.g. 001-010,100)
sub get_test_list {
    my $cmd    = 'find ' . CATEGORY . '-tests -maxdepth 1 -type d -regex .*/[0-9]+.+';
    my $output = script_output($cmd, 30);
    my @tests  = split(/\n/, $output);
    foreach my $test (@tests) {
        $test = basename($test);
        $test = substr("$test", 0, 3);
    }

    # Genarate blacklist
    my @blacklist_copy;
    foreach my $list (@blacklist) {
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
# test - test to run(e.g. 001)
sub test_run {
    my $num     = shift;
    my $status  = 'PASSED';
    my $logfile = CATEGORY . '-tests-results.txt';

    script_run("./clean-tests.sh");
    my $ret = script_output("TEST=$num\\* ./" . CATEGORY . '-tests.sh | tee output.log;', 600, proceed_on_failure => 1);

    if ($ret =~ /test\s+failed\s+for\s+case/i) {
        $status = 'FAILED';
    }
    elsif ($ret =~ /NOTRUN|[Ff]ailed\s+prerequisiti?es/) {
        $status  = 'SKIPPED';
        $logfile = 'output.log';
    }
    script_run("cp $logfile " . LOG_DIR . CATEGORY . "/$num.txt");
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
    type_string("\n");
    assert_script_run($cmd);
}

sub run {
    my $self = shift;
    select_console('root-console');
    assert_script_run('mkdir -p ' . LOG_DIR . CATEGORY);

    # Get test list
    my @tests = get_test_list;

    foreach my $test (@tests) {
        # Run test and wait for it to finish
        my $status = test_run($test);

        # Add test status to STATUS_LOG file
        log_add(STATUS_LOG, CATEGORY . "-$test", $status, "10");
    }
}

1;
