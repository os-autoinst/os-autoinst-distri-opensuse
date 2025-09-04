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
    my $called = 0;
    $testapi->redefine('script_run', sub { ++$called; $testapi->original('script_run') });
    dies_ok { script_retry('sleep 10', retry => 3, delay => 0, timeout => .0001) } 'script_retry(sleep) is expected to die';
    my $cmd;
    is $called, 3, 'command called multiple times on timeout';
    $testapi->redefine('script_run', sub { $cmd = shift; ++$called; 0 });
    $called = 0;
    is script_retry('true', delay => 0, retry => 2, timeout => 1), 0, 'script_retry(true) is ok mocked to collect call';
    is $cmd, 'timeout -k 5 1 true', 'expected concatenated command (no double spaces)';
    is $called, 1, 'command called once for successful execution';
    $called = 0;
    $testapi->redefine('script_run', sub { ++$called; 1 });
    throws_ok { script_retry('false', retry => 3, delay => 0, timeout => .0001, fail_message => 'will fail') } qr/will fail/, 'expected to die on false';
    is $called, 3, 'command called multiple times on failing command';
};

use List::Util qw(any none);

subtest 'script_retry timeout' => sub {
    my $testapi = Test::MockModule->new('utils');
    my @calls;
    my $timeout;
    $testapi->redefine("script_run", sub {
            my $cmd = shift;
            $timeout = shift;
            push @calls, $cmd;
            return 0; });

    script_retry('pippo', retry => 2, delay => 0, timeout => 42);

    note("\n  -->  " . join("\n  -->  ", @calls));
    ok((any { /timeout 42.*pippo/ } @calls), 'script_run command correctly composed');
    ok(($timeout > 42), "script_run timeout:$timeout is larger than script_retry timeout 42");
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
