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

    is script_retry('true',       retry => 2, delay => 0, timeout => 1), 0, "script_retry(true)";
    is script_retry('echo Hello', retry => 2, delay => 0, timeout => 1), 0, "script_retry(echo)";
    isnt script_retry('false', retry => 2, delay => 0, timeout => 1, die => 0), 0, "script_retry(false)";
    dies_ok { script_retry('false', retry => 2, delay => 0, timeout => 1) } 'script_retry(false) is expected to die';
    isnt script_retry('! true', retry => 2, delay => 0, timeout => 1, die => 0), 0, "script_retry('! true')";
    isnt script_retry('!true', retry => 2, delay => 0, timeout => 1, die => 0),  0, "script_retry('!true')";
    is script_retry('!false', retry => 2, delay => 0, timeout => 1, die => 0),   0, "script_retry('!false')";
    is script_retry('! false', retry => 2, delay => 0, timeout => 1, die => 0),  0, "script_retry('! false')";
    is script_retry('!  false', retry => 2, delay => 0, timeout => 1, die => 0), 0, "script_retry('!  false')";
    # This fails on first run but succeeds on second run. Test if we are actually retrying
    is script_retry('rm -f test', retry => 1, delay => 0, timeout => 1), 0, 'removing test file';
    is script_retry('bash -c "if [[ -f test ]]; then exit 0; else touch test; exit 1; fi"', retry => 2, delay => 0, timeout => 1, die => 0), 0, "script_retry - OK on second try";
    # Note: This is the only test that waits for one second. Disable if time is crucial.
    dies_ok { script_retry('sleep 10', retry => 1, delay => 0, timeout => 1) } 'script_retry(sleep) is expected to die';
};

done_testing;
