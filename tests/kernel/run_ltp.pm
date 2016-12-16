# SUSE's openQA tests
#
# Copyright © 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.
#
# Summary: Extracts test commands from an LTP runfile and executes them on the guest.
# Maintainer: Richard Palethorpe <rpalethorpe@suse.com>
# More documentation is at the bottom

use 5.018;
use warnings;
use base 'opensusebasetest';
use testapi qw(is_serial_terminal :DEFAULT);
use utils;
use Time::HiRes qw(clock_gettime CLOCK_MONOTONIC);
use File::Basename 'basename';
require bmwqemu;

sub start_result {
    my ($self, $file_name, $title) = @_;
    my $result = {
        title  => $title,
        text   => $self->next_resultname('txt', $file_name),
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

sub parse_runfile {
    my ($self, $cmd_file, $cmd_pattern, $cmd_exclude) = @_;
    my @tests         = ();
    my $tests_ignored = 0;
    my $cmd_file_text = script_output("cat /opt/ltp/runtest/$cmd_file");

    my ($result, $rfh) = $self->start_result('runfile', 'parse runfile');
    say $rfh "## Parsing `$cmd_file` for tests which match `$cmd_pattern`";

    for my $line (split(qr/[\n\r\f]+/, $cmd_file_text)) {
        if ($line =~ /(^#)|(^$)/) {
            next;
        }

        #Command format is "<name> <command> [<args>...] [#<comment>]"
        if ($line =~ /^\s* ([\w-]+) \s+ (\S.+) #?/gx) {
            my $test = {name => $1, command => $2};
            if ($test->{name} =~ m/$cmd_pattern/ && !($test->{name} =~ m/$cmd_exclude/)) {
                push @tests, $test;
            }
            else {
                $tests_ignored++;
            }
            next;
        }

        if ($result->{result} ne 'fail') {
            say $rfh "## Some lines could not be parsed: ";
            $result->{result} = 'fail';
            $self->{result}   = 'fail';
        }
        print $rfh $line;

    }

    say $rfh "\nUsing " . @tests . " test commands.";
    print $rfh "Ignoring $tests_ignored test commands." if $tests_ignored > 0;
    if (@tests < 1) {
        $result->{result} = 'fail';
        $self->{result}   = 'fail';
    }

    $self->commit_result($result, $rfh);

    return @tests;
}

sub parse_openposix_runfile {
    my ($self, $cmd_pattern, $cmd_exclude) = @_;
    my $cmd_file_text = script_output('cat ~/openposix_test_list.txt');

    my ($result, $rfh) = $self->start_result('runfile', 'parse openposix runfile');
    say $rfh 'Parsing Openposix runfile for tests which match ' . $cmd_pattern;

    my @tests = ();
    my @lines = split qr/[\n\r\f]+/, $cmd_file_text;
    for my $line (@lines) {
        if ($line =~ m/$cmd_pattern/ && !($line =~ m/$cmd_exclude/)) {
            push @tests,
              {
                name    => basename($line, '.run-test'),
                command => $line
              };
        }
    }

    print $rfh 'Using ' . @tests . ' of ' . @lines . ' Openposix test cases';
    if (@tests < 1) {
        $result->{result} = 'fail';
        $self->{result}   = 'fail';
    }

    $self->commit_result($result, $rfh);

    return @tests;
}

sub parse_ltp_log {
    my ($self, $test_log, $fin_msg, $fh) = @_;
    my $ignored_lines = 0;
    my ($tconf, $tfail) = (0, 0);

    for (split(qr/\n/, $test_log)) {
        if (m/^\s+$/) {
            next;
        }

        if (m/^(\w+)\s+(\d+)\s+(\w+)\s+:\s+(.*)$/) {
            if ($3 eq 'TFAIL' || $3 eq 'TBROK') {
                $tfail = 1;
                print $fh $_;
            }
            elsif ($3 eq 'TCONF') {
                $tconf = 1;
                print $fh $_;
            }
        }
        elsif (m/$fin_msg(\d+)/) {
            if ($1 == 0 && ($tfail || $tconf)) {
                say $fh 'TEST EXIT CODE IS ZERO, YET TFAIL, TCONF OR TBROK WAS SEEN!';
                $tfail = 1;
            }
            elsif ($1 == 32 && $tfail) {
                say $fh 'TEST EXIT CODE IS 32 (TCONF), YET TFAIL OR TBROK WAS SEEN!';
            }
            elsif ($1 == 32) {
                say $fh 'Test process returned TCONF (32).';
                $tconf = 1;
            }
            elsif ($1 != 0) {
                say $fh "Test process returned none zero value ($1).";
                $tfail = 1;
            }
            else {
                say $fh "Passed.";
            }
        }
        else {
            $ignored_lines++;
        }
    }

    return ($ignored_lines, $tconf, $tfail);
}

sub parse_openposix_log {
    my ($self, $test_log, $fin_msg, $fh) = @_;
    my ($tconf, $tfail) = (0, 0);

    $test_log =~ m/$fin_msg(\d+)/;
    print $fh 'Test process returned ';
    if ($1 eq '0') {
        print $fh 'PASSED';
    }
    elsif ($1 eq '1') {
        print $fh 'FAILED';
        $tfail = 1;
    }
    elsif ($1 eq '2') {
        print $fh 'UNRESOLVED';
        $tfail = 1;
    }
    elsif ($1 eq '4') {
        print $fh 'UNSUPPORTED';
        $tconf = 1;
    }
    elsif ($1 eq '5') {
        print $fh 'UNTESTED';
        $tconf = 1;
    }
    else {
        print $fh 'unknown';
        $tfail = 1;
    }
    say $fh " ($1) exit code.";
    return (0, $tconf, $tfail);
}

sub record_ltp_result {
    my ($self, $name, $test_log, $fin_msg, $duration, $is_posix) = @_;
    my ($details, $fh) = $self->start_result($name, $name);
    my $ignored_lines = 0;
    my ($tconf, $tfail) = (0, 0);

    unless (defined $test_log) {
        print $fh "This test took too long to complete! It was running for $duration seconds.";
        $details->{result} = 'fail';
        close $fh;
        push @{$self->{details}}, $details;
        die "Can't continue; timed out waiting for LTP test case which may still be running or the OS may have crashed!";
    }

    if ($is_posix) {
        ($ignored_lines, $tconf, $tfail) = $self->parse_openposix_log($test_log, $fin_msg, $fh);
    }
    else {
        ($ignored_lines, $tconf, $tfail) = $self->parse_ltp_log($test_log, $fin_msg, $fh);
    }

    if ($tfail) {
        $details->{result} = 'fail';
        $self->{result}    = 'fail';
    }
    elsif ($tconf) {
        $details->{result} = 'unk';
    }

    say $fh "Test took approximately $duration seconds";

    if ($ignored_lines > 0) {
        print $fh "Some test output could not be parsed: $ignored_lines lines were ignored.";
    }

    $self->commit_result($details, $fh);
}

sub thetime {
    return clock_gettime(CLOCK_MONOTONIC);
}

sub run {
    my ($self) = @_;
    my $cmd_file = get_var 'LTP_COMMAND_FILE';
    die 'Need LTP_COMMAND_FILE to know which tests to run' unless $cmd_file;
    my $conf_file   = '/root/env-variables.sh';                 # TODO: remove duplicity with ltp_setup_networking.pm
    my $cmd_pattern = get_var('LTP_COMMAND_PATTERN') || '.*';
    my $cmd_exclude = get_var('LTP_COMMAND_EXCLUDE') || '$^';
    my $timeout     = get_var('LTP_TIMEOUT') || 900;
    my $is_posix    = $cmd_file =~ m/^\s*openposix\s*$/i;

    if ($conf_file) {
        assert_script_run(". '$conf_file'");
    }

    my @tests;
    if ($is_posix) {
        @tests = $self->parse_openposix_runfile($cmd_pattern, $cmd_exclude);
    }
    else {
        @tests = $self->parse_runfile($cmd_file, $cmd_pattern, $cmd_exclude);
    }

    assert_script_run('cd /opt/ltp/testcases/bin');

    for my $test (@tests) {
        my $fin_msg    = "### TEST $test->{name} COMPLETE >>> ";
        my $cmd_text   = qq($test->{command}; echo "$fin_msg\$?");
        my $start_time = thetime();
        if (is_serial_terminal) {
            type_string("$cmd_text\n");
            wait_serial($cmd_text, undef, 0, no_regex => 1);
        }
        else {
            type_string("($cmd_text) | tee /dev/$serialdev\n");
        }
        my $test_log = wait_serial(qr/$fin_msg\d+/, $timeout, 0, record_output => 1);
        $self->record_ltp_result($test->{name}, $test_log, $fin_msg, thetime() - $start_time, $is_posix);
    }
}

1;

=head1 Discussion

This module extracts an LTP runtest file from the VM, parses it and then
executes the LTP test cases defined on each line of the runtest file. Logs are
uploaded and interpreted after each LTP test case completes.

LTP test cases are usually a binary executable or a shell script. Each line of
the runtest file contains the name of the test case and a string which is
executed by the shell.

The output of each test case is parsed for lines containing TCONF and TFAIL.
If these terms are found in the output then a neutral or fail result will be
reported, otherwise a pass.

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
is created by install_ltp.pm.

=head2 LTP_COMMAND_PATTERN

A regex which filters the commands from LTP_COMMAND_FILE. If a command name
matches this pattern then the corresponding test command will be included in the
set of commands to be run.

=head2 LTP_COMMAND_EXCLUDE

The inverse of LTP_COMMAND_PATTERN; if a command name matches this pattern then
the corresponding test command will be removed from the set of commands to be run.
This overrides LTP_COMMAND_PATTERN.

=head2 LTP_TIMEOUT

The time in seconds which each test command has to run.

=cut

# vim: set sw=4 et:
