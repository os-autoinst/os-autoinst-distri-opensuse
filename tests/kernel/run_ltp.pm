# SUSE's openQA tests
#
# Copyright 2016-2017 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: Executes a single LTP test case
# Maintainer: Richard Palethorpe <rpalethorpe@suse.com>
# More documentation is at the bottom

use 5.018;
use warnings;
use base 'opensusebasetest';
use testapi qw(is_serial_terminal :DEFAULT);
use utils;
use Time::HiRes qw(clock_gettime CLOCK_MONOTONIC);
use serial_terminal;
use Mojo::File 'path';
use Mojo::JSON;
use LTP::utils;
use LTP::WhiteList;
require bmwqemu;

sub start_result {
    my ($self, $file_name, $title) = @_;
    my $result = {
        title => $title,
        text => $self->next_resultname('txt', $file_name),
        result => 'ok'
    };
    open my $rfh, '>', bmwqemu::result_dir() . "/$result->{text}";
    return ($result, $rfh);
}

sub commit_result {
    my ($self, $result, $rfh) = @_;

    push @{$self->{details}}, $result;
    close $rfh;
}

sub parse_result_line {
    my ($fh, $line, $res, $results) = @_;

    if ($res =~ qr'T?FAIL') {
        $results->{fail}++;
        say $fh $line;
    }
    elsif ($res =~ qr'T?PASS') {
        $results->{pass}++;
        say $fh $line;
    }
    elsif ($res =~ qr'T?BROK') {
        $results->{brok}++;
        say $fh $line;
    }
    elsif ($res =~ qr'T?CONF') {
        $results->{conf}++;
        say $fh $line;
    }
    elsif ($res =~ qr'T?WARN') {
        $results->{warn}++;
        say $fh $line;
    }
}

sub parse_ltp_log {
    my ($self, $test_log, $fin_msg, $fh) = @_;
    my $results = {
        pass => 0,
        conf => 0,
        fail => 0,
        brok => 0,
        warn => 0,
        ignored_lines => 0
    };

    for (split(/\n/, $test_log)) {
        if ($_ =~ qr'^\s+$') {
            next;
        }

        # Newlib result format
        if ($_ =~ qr'^[\w.:/]+\s+(\w+):\s+.*$') {
            parse_result_line($fh, $_, $1, $results);
        }
        # Oldlib result format
        elsif ($_ =~ qr'^\w+\s+\d+\s+(\w+)\s+:\s+.*$') {
            parse_result_line($fh, $_, $1, $results);
        }
        elsif ($_ =~ qr/$fin_msg(\d+)/) {
            if ($1 == 0 && $results->{fail} + $results->{conf} + $results->{brok}) {
                say $fh 'TEST EXIT CODE IS ZERO, YET FAIL, CONF OR BROK WAS SEEN!';
            }
            elsif ($1 == 0) {
                say $fh "Passed.";
                $results->{pass}++;
            }
            elsif ($1 == 32 && $results->{fail} + $results->{brok}) {
                say $fh 'TEST EXIT CODE IS 32 (CONF), YET FAIL OR BROK WAS SEEN!';
            }
            elsif ($1 == 32) {
                say $fh 'Test process returned CONF (32).';
                $results->{conf}++;
            }
            elsif ($1 == 4 && $results->{fail} + $results->{brok}) {
                say $fh 'TEST EXIT CODE IS 4 (WARN), YET FAIL OR BROK WAS SEEN!';
            }
            elsif ($1 == 4) {
                say $fh 'Passed with warnings.';
                $results->{warn}++;
            }
            elsif ($1 == 1) {
                say $fh 'Failed.';
                $results->{fail}++;
            }
            else {
                say $fh "Test process returned unkown none zero value ($1).";
                $results->{brok}++;
            }
        }
        else {
            $results->{ignored_lines}++;
        }
    }

    return $results;
}

sub parse_openposix_log {
    my ($self, $test_log, $fin_msg, $fh) = @_;
    my $results = {
        pass => 0,
        conf => 0,
        fail => 0,
        brok => 0,
        warn => 0,
        ignored_lines => 0
    };

    $test_log =~ m/$fin_msg(\d+)/;
    print $fh 'Test process returned ';
    if ($1 eq '0') {
        print $fh 'PASSED';
        $results->{pass}++;
    }
    elsif ($1 eq '1') {
        print $fh 'FAILED';
        $results->{fail}++;
    }
    elsif ($1 eq '2') {
        print $fh 'UNRESOLVED';
        $results->{fail}++;
    }
    elsif ($1 eq '4') {
        print $fh 'UNSUPPORTED';
        $results->{conf}++;
    }
    elsif ($1 eq '5') {
        print $fh 'UNTESTED';
        $results->{conf}++;
    }
    else {
        print $fh 'unknown';
        $results->{brok}++;
    }
    say $fh " ($1) exit code.";
    return $results;
}

sub record_ltp_result {
    my ($self, $suite, $test, $test_log, $fin_msg, $duration, $is_posix) = @_;
    my ($details, $fh) = $self->start_result($test->{name}, $test->{name});
    my $results;

    # Top level fields are required for all test suites, unless otherwise
    # stated. Lower level fields can vary between test suites and even
    # idividual tests.
    my $export_details = {
        # Fully qualified name of the test suite and individual test case
        test_fqn => "LTP:$suite:$test->{name}",
        # The environment in which the test was executed. Ideally, when
        # comparing results, only one of these should change
        environment => {},
        # Simplified indicator of the test result. It is only true if the test
        # passed successfully
        status => 'fail',
        # Test suite specific data
        test => {
            result => '',
            duration => $duration,
            log => $test_log
        }};

    unless (defined $test_log) {
        print $fh "This test took too long to complete! It was running for $duration seconds.";
        $details->{result} = 'fail';
        close $fh;
        push @{$self->{details}}, $details;

        $self->{result} = 'fail';
        $export_details->{test}->{result} = 'timeout';
        return (1, $export_details);
    }

    if ($is_posix) {
        $results = $self->parse_openposix_log($test_log, $fin_msg, $fh);
    }
    else {
        $results = $self->parse_ltp_log($test_log, $fin_msg, $fh);
    }

    if ($results->{brok}) {
        $details->{result} = 'fail';
        $self->{result} = 'fail';
        $export_details->{test}->{result} = 'BROK';
    }
    elsif ($results->{fail} || $results->{warn}) {
        $details->{result} = 'fail';
        $self->{result} = 'fail';
        $export_details->{test}->{result} = 'FAIL';
    }
    elsif ($results->{pass}) {
        $export_details->{status} = 'pass';
        $export_details->{test}->{result} = 'PASS';
    }
    elsif ($results->{conf}) {
        $details->{result} = 'skip';
        $self->{result} = 'skip';
        $export_details->{test}->{result} = 'CONF';
    }
    else {
        die 'No LTP test result was parsed from the log';
    }

    say $fh "Test took approximately $duration seconds";

    if ($results->{ignored_lines} > 0) {
        print $fh "Some test output could not be parsed: $results->{ignored_lines} lines were ignored.";
    }

    $self->commit_result($details, $fh);
    $self->write_extra_test_result($export_details);
    return (0, $export_details);
}

sub write_extra_test_result {
    my ($self, $details) = @_;
    my $dir = bmwqemu::result_dir();
    my $filename = $details->{test_fqn} =~ s/:/_/gr;
    my $result = 'failed';
    $result = 'passed' if ($details->{test}->{result} eq 'PASS');
    $result = 'skipped' if ($details->{test}->{result} eq 'CONF');

    my $result_file = {
        dents => 0,
        details => [{
                _source => 'parser',
                result => $result,
                text => $filename . '.txt',
                title => $filename,
        }],
        result => $result,
    };
    path($dir, 'result-' . $filename . '.json')->spurt(Mojo::JSON::encode_json($result_file));
    path($dir, $filename . '.txt')->spurt($details->{test}->{log});

    push @{$self->{details}}, $result_file->{details}->[0];
}

sub thetime {
    return clock_gettime(CLOCK_MONOTONIC);
}

sub pre_run_hook {
    my ($self) = @_;
    my @pattern_list;

    # Kernel error messages should be treated as soft-fail in boot_ltp,
    # install_ltp and shutdown_ltp so that at least some testing can be done.
    # But change them to hard fail in this test module.
    for my $pattern (@{$self->{serial_failures}}) {
        my %tmp = %$pattern;
        $tmp{type} = 'hard' if $tmp{message} =~ m/kernel/i;
        push @pattern_list, \%tmp;
    }

    $self->{serial_failures} = \@pattern_list;
    $self->SUPER::pre_run_hook;
}

sub run {
    my ($self, $tinfo) = @_;
    die 'Need LTP_COMMAND_FILE to know which tests to run' unless $tinfo && $tinfo->runfile;
    my $runfile = $tinfo->runfile;
    my $test = $tinfo->test;

    # default timeout
    my $timeout = (get_var('LTP_TIMEOUT') || 900);
    # test specific timeout, e.g. LTP_TIMEOUT_zram01
    $timeout = (get_var('LTP_TIMEOUT_' . $test->{name})) || $timeout;
    $timeout *= get_ltp_mul();

    my $is_posix = $runfile =~ m/^\s*openposix\s*$/i;
    my $test_result_export = $tinfo->test_result_export;
    my %env = %{$test_result_export->{environment}};

    $env{retval} = 'undefined';
    $self->{ltp_env} = \%env;
    $self->{ltp_tinfo} = $tinfo;

    my $fin_msg = "### TEST $test->{name} COMPLETE >>> ";
    my $cmd_text = qq($test->{command}; echo "$fin_msg\$?.");
    my $klog_stamp = "echo 'OpenQA::run_ltp.pm: Starting $test->{name}' > /dev/$serialdev";
    my $start_time = thetime();

    if (is_serial_terminal) {
        script_run($klog_stamp);
        wait_serial(serial_term_prompt(), undef, 0, no_regex => 1);
        type_string($cmd_text);
        wait_serial($cmd_text, undef, 0, no_regex => 1);
        send_key 'ret';
    }
    else {
        enter_cmd("($cmd_text) 2>\&1 | tee /dev/$serialdev");
    }
    my $test_log = wait_serial(qr/$fin_msg\d+\./, $timeout, 0, record_output => 1);
    my ($timed_out, $result_export) = $self->record_ltp_result($runfile, $test, $test_log, $fin_msg, thetime() - $start_time, $is_posix);

    if ($test_log =~ qr/$fin_msg(\d+)\.$/) {
        $env{retval} = $1;
    }

    push(@{$test_result_export->{results}}, $result_export);
    if ($timed_out) {
        if (get_var('LTP_DUMP_MEMORY_ON_TIMEOUT')) {
            save_memory_dump(filename => $test->{name});
        }
        die "Timed out waiting for LTP test case which may still be running or the OS may have crashed!";
    }

    script_run('vmstat -w');
}

# Only propogate death don't create it from failure [2]
sub run_post_fail {
    my ($self, $msg) = @_;

    $self->fail_if_running();

    if ($self->{ltp_tinfo} and $self->{result} eq 'fail') {
        my $whitelist = LTP::WhiteList->new();

        $whitelist->override_known_failures($self, $self->{ltp_env}, $self->{ltp_tinfo}->runfile, $self->{ltp_tinfo}->test->{name});
    }

    if ($msg =~ qr/died/) {
        die $msg . "\n";
    }
}

1;

=head1 Discussion

This module executes a single LTP test case specified by LTP::TestInfo which
is passed to run. This module is dynamically scheduled by boot_ltp at runtime.

LTP test cases are usually a binary executable or a shell script. Each line of
the runtest file contains the name of the test case and a string which is
executed by the shell.

The output of each test case is parsed for lines containing CONF and FAIL.
If these terms are found in the output then a neutral or fail result will be
reported, otherwise a pass.

[2] This overrides the default basetest class behaviour because the LTP tests
    are able to continue after most failures (without reverting to a
    milestone). We call 'die' inside run() and then propogate it if the
    failure is more severe and requires either reverting the SUT or aborting
    the tests.

=head1 Configuration

Example configuration for SLE:

BOOT_HDD_IMAGE=1
DESKTOP=textmode
HDD_1=SLES-%VERSION%-%ARCH%-minimal_with_ltp_installed.qcow2
LTP_COMMAND_FILE=controllers
LTP_COMMAND_PATTERN=memcg
LTP_TIMEOUT=1200
START_AFTER_TEST=install_ltp

=head2 LTP_COMMAND_FILE

Either specifies the name of an LTP runfile from the runtest directory or
'openposix'. When set to openposix it will load openposix_test_list.txt which
is created by install_ltp.pm. Multiple runfiles separated by comma are also
supported.

=head2 LTP_COMMAND_PATTERN

A regex which filters the commands from LTP_COMMAND_FILE. If a command name
matches this pattern then the corresponding test command will be included in the
set of commands to be run.

=head2 LTP_COMMAND_EXCLUDE

The inverse of LTP_COMMAND_PATTERN; if a command name matches this pattern then
the corresponding test command will be removed from the set of commands to be run.
This overrides LTP_COMMAND_PATTERN.

=head2 LTP_TIMEOUT

The time in seconds which each test command has to run. The default is 900.

=head2 LTP_TIMEOUT_test (e.g.  LTP_TIMEOUT_zram01)

Test specific timeout in sec (overrides LTP_TIMEOUT).

=head2 LTP_TIMEOUT_MUL

Multiplies the timeout. Also exported as environment variable for LTP
(originally LTP variable).

=head2 LTP_TIMEOUT_MUL_arch (e.g. LTP_TIMEOUT_MUL_aarch64)

Multiplicator for specific arch (overrides LTP_TIMEOUT_MUL, also exported as
LTP_TIMEOUT_MUL for LTP).

=head2 LTP_DUMP_MEMORY_ON_TIMEOUT

If set will request that the SUT's memory is dumped if the timer in this test
module runs out. This is does not include timeouts which are built into the
LTP test itself.

=head2 LTP_ENV

Comma separated list of environment variables to be set for tests.
E.g.: key=value,key2="value with spaces",key3='another value with spaces'

=cut

