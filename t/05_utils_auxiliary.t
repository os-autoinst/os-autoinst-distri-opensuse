use strict;
use warnings;
use Test::More;
use Test::Warnings;
use Test::MockModule;
use Test::Mock::Time;
use Test::Exception;
use testapi;
use utils;

## Test auxiliary routines.
# Add additional unit tests for auxiliary subroutines (e.g. util.pm) here.


subtest '[script_retry] simulate with local bash: pass' => sub {
    my $mock_utils = Test::MockModule->new('utils');
    # script_run runs the commands on the local machine as bash
    $mock_utils->redefine("script_run", sub { return system("bash -c '$_[0]'"); });
    for my $cmd ('true', 'echo Hello') {
        my $ret = script_retry($cmd, retry => 2, delay => 0, timeout => 1);
        is $ret, 0, "script_retry(true) ret:$ret";
    }
};

subtest '[script_retry] simulate with local bash: fail' => sub {
    my $mock_utils = Test::MockModule->new('utils');
    $mock_utils->redefine("script_run", sub { return system("bash -c '$_[0]'"); });

    dies_ok { script_retry('false', retry => 2, delay => 0, timeout => 1) } 'script_retry(false) is expected to die';

    # die => 0 disable the die
    my $ret = script_retry('false', retry => 2, delay => 0, timeout => 1, die => 0);
    isnt $ret, 0, "script_retry(false, die => 0)";
};

subtest '[script_retry] retry' => sub {
    my $mock_utils = Test::MockModule->new('utils');
    my @calls;
    $mock_utils->redefine("script_run", sub {
            my $cmd_in = $_[0];
            my $ret_val = scalar(@calls) == 0 ? 1 : 0;
            push @calls, {cmd => $cmd_in, ret => $ret_val};
            return $ret_val;
    });

    # called with retry max cap to 5 even if it will only need two retry (due to the way the mock is coded)
    my $ret = script_retry('whatever, none care or run this command', retry => 5, delay => 0, timeout => 1, die => 0);
    for my $call (@calls) {
        note("  C--> Command: '$call->{cmd}' | Returned: '$call->{ret}'");
    }
    is $ret, 0, "script_retry - OK on second try";
    is scalar @calls, 2, "script_retry made exactly 2 attempts";
};

subtest '[script_retry] timeout' => sub {
    # script_run returns undef on timeout (real script_run behavior),
    # script_retry must retry and eventually die.
    # timeout => 1 is arbitrary thanks to Test::Mock::Time
    my $mock_utils = Test::MockModule->new('utils');
    my $called = 0;
    $mock_utils->redefine('script_run', sub { ++$called; return undef });

    dies_ok { script_retry('sleep 10', retry => 3, delay => 0, timeout => 1) }
    'script_retry dies when script_run returns undef (timeout)';
    is $called, 3, 'command called retry times on timeout';
};

subtest '[script_retry] failing command' => sub {
    # script_run returns non-zero (command failure), script_retry must retry
    # and die with the configured fail_message.
    my $mock_utils = Test::MockModule->new('utils');
    my $called = 0;
    $mock_utils->redefine('script_run', sub { ++$called; return 1 });

    throws_ok { script_retry('false', retry => 3, delay => 0, timeout => 1, fail_message => 'will fail') }
    qr/will fail/, 'dies with custom fail_message on failing command';
    is $called, 3, 'command called retry times (retry=3) on failing command';

    # default fail_message when none is given
    $called = 0;
    throws_ok { script_retry('false', retry => 4, delay => 0, timeout => 1) }
    qr/Waiting for Godot/, 'dies with default fail_message when retries are exhausted';
    is $called, 4, 'command called retry times (retry=4) on failing command';
};

subtest '[script_retry] command timeout wrapping' => sub {
    # Collect the command string and the timeout passed to script_run to verify
    # how kill_timeout and retry_grace are wired into the timeout invocation.
    my $mock_utils = Test::MockModule->new('utils');
    my ($cmd, $actual_timeout);
    my $called = 0;
    $mock_utils->redefine('script_run', sub { $cmd = shift; $actual_timeout = shift; ++$called; 0 });

    # default kill_timeout is 5
    is script_retry('true', delay => 0, retry => 2, timeout => 1), 0, 'script_retry(true) is ok mocked to collect call';
    is $cmd, 'timeout -k 5 1 true', 'expected concatenated command (no double spaces), default kill_timeout';
    is $called, 1, 'command called once for successful execution';

    # custom kill_timeout is reflected in the timeout -k argument
    is script_retry('true', delay => 0, retry => 1, timeout => 1, kill_timeout => 9), 0, 'script_retry with kill_timeout=9 succeeds';
    is $cmd, 'timeout -k 9 1 true', 'kill_timeout is reflected in the timeout -k argument';

    # retry_grace is added to the timeout passed to script_run (timeout + retry_grace)
    is script_retry('true', delay => 0, retry => 1, timeout => 2, retry_grace => 20), 0, 'script_retry with retry_grace=20 succeeds';
    is $actual_timeout, 22, 'retry_grace is added to timeout for the script_run call (timeout + retry_grace)';
};

subtest '[script_retry] script_run exception propagates' => sub {
    # An exception thrown by script_run (e.g. an internal timeout) must abort the
    # retry loop immediately and not be masked by further retries.
    my $mock_utils = Test::MockModule->new('utils');
    my $throws_count = 0;
    $mock_utils->redefine('script_run', sub { ++$throws_count; die "script_run timeout\n" });

    throws_ok { script_retry('true', retry => 3, delay => 0, timeout => 1) }
    qr/script_run timeout/, 'script_run exception propagates out of script_retry';
    is $throws_count, 1, 'script_run is called once before the exception aborts the loop';
};

subtest '[script_retry] simulate with local bash: esclamation mark handling' => sub {
    # The tested function has an internal feature
    # moving the esclamation mark at the beginning
    # avoiding problems like:
    #    timeout -k 5 1 ! true ; echo "rc:$?"
    #
    #    timeout: failed to run command ‘!’: No such file or directory
    #    rc:127
    my $mock_utils = Test::MockModule->new('utils');
    my @calls;
    $mock_utils->redefine("script_run", sub {
            push @calls, $_[0];
            return system("bash -c '$_[0]'");
    });

    # Define test cases: [ command, expect_zero_success ]
    my @test_cases = (
        ['! true', 0],
        ['!true', 0],
        ['!false', 1],
        ['! false', 1],
        ['!  false', 1],
    );

    for my $case (@test_cases) {
        my ($cmd, $expect_zero) = @$case;
        my $ret = script_retry($cmd, retry => 2, delay => 0, timeout => 1, die => 0);
        if ($expect_zero) {
            is $ret, 0, "script_retry('$cmd') expected success (0)";
        } else {
            isnt $ret, 0, "script_retry('$cmd') expected failure (not 0)";
        }
        note("\n  C-->  " . join("\n  C-->  ", @calls));
        @calls = ();
    }
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
