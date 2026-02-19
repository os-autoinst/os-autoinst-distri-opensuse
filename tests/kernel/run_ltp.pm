# SUSE's openQA tests
#
# Copyright 2016-2017 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: Executes a single LTP test case
# Maintainer: QE Kernel <kernel-qa@suse.de>
# More documentation is at the bottom

use 5.018;
use base 'opensusebasetest';
use testapi qw(is_serial_terminal :DEFAULT);
use serial_terminal 'select_serial_terminal';
use power_action_utils 'power_action';
use utils;
use version_utils 'is_sle';
use Time::HiRes qw(clock_gettime CLOCK_MONOTONIC);
use Utils::Backends qw(is_backend_s390x is_pvm);
use serial_terminal;
use Mojo::File 'path';
use Mojo::JSON;
use LTP::utils 'prepare_ltp_env';
use LTP::WhiteList;
require bmwqemu;

sub do_reboot {
    my $self = shift;

    record_info("reboot");
    power_action('reboot', textmode => 1, keepconsole => is_pvm || is_backend_s390x);
    reconnect_mgmt_console if (is_pvm || is_backend_s390x || get_var('LTP_BAREMETAL'));

    if (is_backend_s390x) {
        $self->wait_boot_past_bootloader(textmode => 1);
    } else {
        $self->wait_boot;
    }
    select_serial_terminal;
    prepare_ltp_env;
}

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
                say $fh "Test process returned unknown non-zero value ($1).";
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
    path($dir, 'result-' . $filename . '.json')->spew(Mojo::JSON::encode_json($result_file));
    path($dir, $filename . '.txt')->spew($details->{test}->{log});

    push @{$self->{details}}, $result_file->{details}->[0];
}

sub thetime {
    return clock_gettime(CLOCK_MONOTONIC);
}

sub save_crashdump {
    my $self = shift;
    my $old_console = current_console();

    select_console('root-console');
    script_run('rm -rf /var/crash/*');
    send_key('alt-sysrq-s');
    send_key('alt-sysrq-c');
    reset_consoles;
    $self->wait_boot;
    select_console($old_console);
    my $dump = script_output('ls /var/crash |tail -n1');
    assert_script_run("tar cJf /root/crashdump.tar.xz /var/crash/$dump");
    upload_logs('/root/crashdump.tar.xz');
}

sub upload_tcpdump {
    my $self = shift;
    my $pid = $self->{tcpdump_pid};
    my $old_console;

    $self->{tcpdump_pid} = undef;

    if ($self->{timed_out}) {
        $old_console = current_console();
        select_console('root-console');

        unless (defined(script_run("timeout 20 sh -c \"kill -s INT $pid && while [ -d /proc/$pid ]; do sleep 1; done\""))) {
            select_console($old_console, await_console => 0);
            return;
        }
    }
    else {
        assert_script_run("kill -s INT $pid && wait $pid");
    }

    assert_script_run("gzip -f9 /var/tmp/tcpdump.pcap", timeout => 1800);
    upload_logs("/var/tmp/tcpdump.pcap.gz");
    upload_logs("/var/tmp/tcpdump.log");
    script_run('rm /var/tmp/tcpdump.pcap* /var/tmp/tcpdump.log');
    select_console($old_console) if defined($old_console);
}

sub upload_oprofile {
    my $self = shift;
    my $pid = $self->{oprofile_pid};
    my $old_console;

    $self->{oprofile_pid} = undef;

    if ($self->{timed_out}) {
        $old_console = current_console();
        select_console('root-console');

        unless (defined(script_run("timeout 20 sh -c \"kill -s INT $pid && while [ -d /proc/$pid ]; do sleep 1; done\""))) {
            select_console($old_console, await_console => 0);
            return;
        }
    }
    else {
        assert_script_run("kill -s INT $pid && wait $pid");
    }

    assert_script_run('cd /tmp');
    assert_script_run("tar cjf /tmp/ltp_oprofile_data.tar.bz2 ltp_oprofile");
    assert_script_run('cd -');
    upload_logs("/tmp/ltp_oprofile_data.tar.bz2");
    upload_logs("/tmp/ltp_oprofile.txt");
    select_console($old_console) if defined($old_console);
}

sub pre_run_hook {
    my ($self) = @_;
    my @pattern_list;

    # Kernel error messages should be treated as soft-fail in boot_ltp,
    # install_ltp and shutdown_ltp so that at least some testing can be done.
    # But change them to hard fail in this test module.
    for my $pattern (@{$self->{serial_failures}}) {
        my %tmp = %$pattern;

        # don't switch to hard fail when test is expected to produce kernel warning
        $tmp{type} = $tmp{post_boot_type} if defined($tmp{post_boot_type}) && !($tmp{soft_on_expect_warn} && get_var('LTP_WARN_EXPECTED'));

        push @pattern_list, \%tmp;
    }

    $self->{serial_failures} = \@pattern_list;
    $self->SUPER::pre_run_hook;
}

sub run {
    my ($self, $tinfo) = @_;
    die 'Need LTP_COMMAND_FILE to know which tests to run' unless $tinfo && $tinfo->runfile;
    my $runfile = $tinfo->runfile;
    my $timeout = get_var('LTP_TIMEOUT') || 900;
    my $is_posix = $runfile =~ m/^\s*openposix\s*$/i;
    my $test_result_export = $tinfo->test_result_export;
    my $test = $tinfo->test;
    my %env = %{$test_result_export->{environment}};

    $env{retval} = 'undefined';
    $self->{ltp_env} = \%env;
    $self->{ltp_tinfo} = $tinfo;

    my $fin_msg = "### TEST $test->{name} COMPLETE >>> ";
    my $cmd_text = qq($test->{command}; echo "$fin_msg\$?.");

    my $klog_stamp = "OpenQA::run_ltp.pm: Starting $test->{name}";
    my $start_time = thetime();

    if (check_var_array('LTP_DEBUG', 'tcpdump')) {
        $self->{tcpdump_pid} = background_script_run("tcpdump -i any -w /var/tmp/tcpdump.pcap &>/var/tmp/tcpdump.log");
        # Wait for tcpdump to initialize before running the test
        script_run('while [ ! -e /var/tmp/tcpdump.pcap ]; do sleep 1; done');
    }

    if (check_var_array('LTP_DEBUG', 'oprofile')) {
        script_run('rm -rf /tmp/ltp_oprofile');
        assert_script_run('mkdir -p /tmp/ltp_oprofile');
        $self->{oprofile_pid} = background_script_run('operf -ls -d /tmp/ltp_oprofile &>/tmp/ltp_oprofile.txt');
    }

    if (is_serial_terminal) {
        script_run("echo '$klog_stamp' > /dev/kmsg");
        # SLE11-SP4 doesn't support ignore_loglevel, due that stamp is not printed in console
        script_run("echo '$klog_stamp' > /dev/$serialdev") if is_sle('<12');
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
    $self->{timed_out} = $timed_out;

    if ($test_log =~ qr/$fin_msg(\d+)\.$/) {
        $env{retval} = $1;
        $self->upload_oprofile() if defined($self->{oprofile_pid});
        $self->upload_tcpdump() if defined($self->{tcpdump_pid});
    }

    push(@{$test_result_export->{results}}, $result_export);
    if ($timed_out) {
        if (get_var('LTP_DUMP_MEMORY_ON_TIMEOUT')) {
            save_memory_dump(filename => $test->{name});
        }
        die "Timed out waiting for LTP test case which may still be running or the OS may have crashed!";
    }

    script_run('vmstat -w');

    # reboot unless TCONF or last test
    $self->do_reboot if (get_var('LTP_REBOOT_AFTER_TEST') && !$test->{last} && $env{retval} != 32);
}

# Only propogate death don't create it from failure [2]
sub run_post_fail {
    my ($self, $msg) = @_;

    $self->upload_oprofile() if defined($self->{oprofile_pid});
    $self->upload_tcpdump() if defined($self->{tcpdump_pid});
    dump_tasktrace() if check_var_array('LTP_DEBUG', 'tasktrace');
    $self->save_crashdump()
      if $self->{timed_out} && check_var_array('LTP_DEBUG', 'crashdump');

    $self->get_new_serial_output();
    $self->fail_if_running();
    $self->compute_test_execution_time();

    if ($self->{ltp_tinfo} and $self->{result} eq 'fail') {
        my $whitelist = LTP::WhiteList->new();

        $whitelist->override_known_failures($self, $self->{ltp_env}, $self->{ltp_tinfo}->runfile, $self->{ltp_tinfo}->test->{name});
    }

    if ($msg =~ qr/died/) {
        die $msg . "\n";
    }
}

1;

=head1 Description

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

The time in seconds which each test command has to run.

=head2 LTP_DUMP_MEMORY_ON_TIMEOUT

If set will request that the SUT's memory is dumped if the timer in this test
module runs out. This does not include timeouts which are built into the
LTP test itself.

=head2 LTP_ENV

Comma separated list of environment variables to be set for tests.
E.g.: key=value,key2="value with spaces",key3='another value with spaces'

=head2 LTP_DEBUG

Comma separated list of debug features to enable during test run.
- C<oprofile>: Collect system-wide oprofile during each test. QEMUCPU=host may
  be required.
- C<crashdump>: Save kernel crashdump on test timeout.
- C<tasktrace>: Print backtrace of all processes and show blocked tasks
- C<tcpdump>: Capture all packets sent or received during each test.
- C<supportconfig>: Run supportconfig after boot and before shutdown.

=head2 LTP_REBOOT_AFTER_TEST

Reboot SUT after each test (unless last test or TCONF). It prolongs testing
significantly, but for some tests may be necessary, e.g. ltp_ima_reboot.

=cut
