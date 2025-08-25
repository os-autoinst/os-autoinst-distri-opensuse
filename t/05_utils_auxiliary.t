use strict;
use warnings;
use Test::More;
use Test::Warnings;
use Test::MockModule;
use Test::Exception;
use testapi;
use utils;

## Test auxiliary routines.
# Add additional unit tests for auxiliary subroutines (e.g. util.pm) here.


subtest 'script_retry' => sub {
    # Override script_run
    my $testapi = Test::MockModule->new('utils');
    # script_run runs the commands on the local machine as bash
    $testapi->redefine("script_run", sub { return system("bash -c '$_[0]'"); });

    is script_retry('true', retry => 2, delay => 0, timeout => 1), 0, "script_retry(true)";
    is script_retry('echo Hello', retry => 2, delay => 0, timeout => 1), 0, "script_retry(echo)";
    isnt script_retry('false', retry => 2, delay => 0, timeout => 1, die => 0), 0, "script_retry(false)";
    dies_ok { script_retry('false', retry => 2, delay => 0, timeout => 1) } 'script_retry(false) is expected to die';
    isnt script_retry('! true', retry => 2, delay => 0, timeout => 1, die => 0), 0, "script_retry('! true')";
    isnt script_retry('!true', retry => 2, delay => 0, timeout => 1, die => 0), 0, "script_retry('!true')";
    is script_retry('!false', retry => 2, delay => 0, timeout => 1, die => 0), 0, "script_retry('!false')";
    is script_retry('! false', retry => 2, delay => 0, timeout => 1, die => 0), 0, "script_retry('! false')";
    is script_retry('!  false', retry => 2, delay => 0, timeout => 1, die => 0), 0, "script_retry('!  false')";
    # This fails on first run but succeeds on second run. Test if we are actually retrying
    is script_retry('rm -f test', retry => 1, delay => 0, timeout => 1), 0, 'removing test file';
    is script_retry('bash -c "if [[ -f test ]]; then exit 0; else touch test; exit 1; fi"', retry => 2, delay => 0, timeout => 1, die => 0), 0, "script_retry - OK on second try";
    # Note: This is the only test that waits for one second. Disable if time is crucial.
    dies_ok { script_retry('sleep 10', retry => 1, delay => 0, timeout => 1) } 'script_retry(sleep) is expected to die';
    my $cmd;
    $testapi->redefine('script_run', sub { $cmd = shift; 0 });
    is script_retry('true', delay => 0, retry => 2, timeout => 1), 0, 'script_retry(true) is ok mocked to collect call';
    is $cmd, 'timeout -k 5 1 true', 'expected concatenated command (no double spaces)';
};


subtest 'validate_script_output_retry' => sub {
    my $module = Test::MockModule->new('testapi');

    my $basetest = Test::MockModule->new('basetest');
    $basetest->noop('record_resultfile');
    $autotest::current_test = new basetest;

    $module->mock('script_output', sub { 'foo' });
    lives_ok { validate_script_output_retry('echo foo', qr/foo/, retry => 2) } 'Do not throw exception';
    throws_ok { validate_script_output_retry('echo foo', qr/bar/, retry => 2, delay => 0) } qr/validate output/, 'Exception thrown';

    my @results;
    $module->mock('script_output', sub { shift @results });

    @results = qw(1 2 3 foo);
    lives_ok { validate_script_output_retry('echo foo', qr/foo/, retry => 4, delay => 0) } 'Success on 4th retry';
    @results = qw(1 2 3 foo);
    throws_ok { validate_script_output_retry('echo foo', qr/foo/, retry => 3, delay => 0) } qr/validate output/, 'Not enough retries';
};

done_testing;
