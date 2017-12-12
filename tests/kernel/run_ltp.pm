# SUSE's openQA tests
#
# Copyright © 2016-2017 SUSE LLC
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
use JSON;
use serial_terminal;
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
    my $cmd_file_text = script_output('cat $LTPROOT/runtest/' . $cmd_file);

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
        pass          => 0,
        conf          => 0,
        fail          => 0,
        brok          => 0,
        warn          => 0,
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
        pass          => 0,
        conf          => 0,
        fail          => 0,
        brok          => 0,
        warn          => 0,
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
            result   => '',
            duration => $duration,
            log      => $test_log
        }};

    unless (defined $test_log) {
        print $fh "This test took too long to complete! It was running for $duration seconds.";
        $details->{result} = 'fail';
        close $fh;
        push @{$self->{details}}, $details;

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
        $details->{result}                = 'fail';
        $self->{result}                   = 'fail';
        $export_details->{test}->{result} = 'BROK';
    }
    elsif ($results->{fail} || $results->{warn}) {
        $details->{result}                = 'fail';
        $self->{result}                   = 'fail';
        $export_details->{test}->{result} = 'FAIL';
    }
    elsif ($results->{pass}) {
        $export_details->{status} = 'pass';
        $export_details->{test}->{result} = 'PASS';
    }
    elsif ($results->{conf}) {
        $details->{result} = 'unk';
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
    return (0, $export_details);
}

sub thetime {
    return clock_gettime(CLOCK_MONOTONIC);
}

sub export_to_json {
    my ($test_result_export) = @_;
    my $export_file = 'ulogs/result_array.json';

    if (!-d 'ulogs') {
        mkdir('ulogs');
    }
    bmwqemu::save_json_file($test_result_export, $export_file);
}

sub run {
    my ($self) = @_;
    my $cmd_file = get_var 'LTP_COMMAND_FILE';
    die 'Need LTP_COMMAND_FILE to know which tests to run' unless $cmd_file;
    my $cmd_pattern = get_var('LTP_COMMAND_PATTERN') || '.*';
    my $cmd_exclude = get_var('LTP_COMMAND_EXCLUDE') || '$^';
    my $timeout     = get_var('LTP_TIMEOUT')         || 900;
    my $ltp_env     = get_var('LTP_ENV');
    my $is_posix    = $cmd_file =~ m/^\s*openposix\s*$/i;
    my $is_network  = $cmd_file =~ m/^\s*(net|net_stress)\./;
    my $tmp;

    if ($ltp_env) {
        $ltp_env =~ s/,/ /g;
        script_run("export $ltp_env");
        script_run('env');
    }

    my $test_result_export = {
        format  => 'result_array:v1',
        results => []};

    my @tests;

    if ($is_posix) {
        @tests = $self->parse_openposix_runfile($cmd_pattern, $cmd_exclude);
    }
    else {
        @tests = $self->parse_runfile($cmd_file, $cmd_pattern, $cmd_exclude);
    }

    assert_script_run('cd $LTPROOT/testcases/bin');

    my $ver_linux_path = '$LTPROOT/ver_linux';
    my $ver_linux_log  = '/tmp/ver_linux_before.txt';
    script_run("$ver_linux_path > $ver_linux_log 2>&1");
    upload_logs($ver_linux_log);
    my $ver_linux_out = script_output("cat $ver_linux_log");
    my $environment   = {
        product     => get_var('DISTRI') . ':' . get_var('VERSION'),
        revision    => get_var('BUILD'),
        arch        => get_var('ARCH'),
        kernel      => '',
        libc        => '',
        gcc         => '',
        harness     => 'SUSE OpenQA',
        ltp_version => ''
    };
    if ($ver_linux_out =~ qr'^Linux\s+(.*?)\s*$'m) {
        $environment->{kernel} = $1;
    }
    if ($ver_linux_out =~ qr'^Linux C Library\s*>?\s*(.*?)\s*$'m) {
        $environment->{libc} = $1;
    }
    if ($ver_linux_out =~ qr'^Gnu C\s*(.*?)\s*$'m) {
        $environment->{gcc} = $1;
    }
    $environment->{ltp_version} = script_output('touch /opt/ltp_version; cat /opt/ltp_version');

    if ($is_network) {
        # poo#18762: Sometimes there is physical NIC which is not configured.
        # One of the reasons can be renaming by udev rule in
        # /etc/udev/rules.d/70-persistent-net.rules. This breaks some tests
        # (even net namespace based ones).
        # Workaround: configure physical NIS (if needed).
        $tmp = << 'EOF';
dir=/sys/class/net
ifaces="`basename -a $dir/* | grep -v -e ^lo -e ^tun -e ^virbr -e ^vnet`"
for iface in $ifaces; do
    config=/etc/sysconfig/network/ifcfg-$iface
    if [ "`cat $dir/$iface/operstate`" = "down" ] && [ ! -e $config ]; then
        echo "WARNING: create config '$config'"
        printf "BOOTPROTO='dhcp'\nSTARTMODE='auto'\nDHCLIENT_SET_DEFAULT_ROUTE='yes'\n" > $config
        systemctl restart network
        sleep 1
    fi
done
EOF
        script_output($tmp);

        # dhclient requires no wicked service not only running but also disabled
        script_run(
            'systemctl --no-pager -p Id show network.service | grep -q Id=wicked.service &&
{ export ENABLE_WICKED=1; systemctl disable wicked; }'
        );

        # emulate $LTPROOT/testscripts/network.sh
        assert_script_run('TST_TOTAL=1 TCID="network_settings"; . test_net.sh; export TCID= TST_LIB_LOADED=');
        script_run('env');

        # Disable IPv4 and IPv6 iptables.
        # Disabling IPv4 is needed for iptables tests (net.tcp_cmds).
        # Disabling IPv6 is needed for ICMPv6 tests (net.ipv6).
        # This must be done after stopping network service and loading
        # test_net.sh script.
        $tmp = << 'EOF';
iptables -P INPUT ACCEPT;
iptables -P OUTPUT ACCEPT;
iptables -P FORWARD ACCEPT;
iptables -t nat -F;
iptables -t mangle -F;
iptables -F;
iptables -X;

ip6tables -P INPUT ACCEPT;
ip6tables -P OUTPUT ACCEPT;
ip6tables -P FORWARD ACCEPT;
ip6tables -t nat -F;
ip6tables -t mangle -F;
ip6tables -F;
ip6tables -X;
EOF
        script_output($tmp);
        # display resulting iptables
        script_run('iptables -L');
        script_run('iptables -S');
        script_run('ip6tables -L');
        script_run('ip6tables -S');

        # display various network configuration
        script_run('ps axf');
        script_run('netstat -nap');

        script_run('cat /etc/resolv.conf');
        script_run('cat /etc/nsswitch.conf');
        script_run('cat /etc/hosts');

        script_run('ip addr');
        script_run('ip netns exec ltp_ns ip addr');
        script_run('ip route');
        script_run('ip -6 route');

        script_run('ping -c 2 $IPV4_NETWORK.$LHOST_IPV4_HOST');
        script_run('ping -c 2 $IPV4_NETWORK.$RHOST_IPV4_HOST');
        script_run('ping6 -c 2 $IPV6_NETWORK:$LHOST_IPV6_HOST');
        script_run('ping6 -c 2 $IPV6_NETWORK:$RHOST_IPV6_HOST');
    }

    for my $test (@tests) {
        my $fin_msg    = "### TEST $test->{name} COMPLETE >>> ";
        my $cmd_text   = qq($test->{command}; echo "$fin_msg\$?");
        my $klog_stamp = "echo 'OpenQA::run_ltp.pm: Starting $test->{command}' > /dev/$serialdev";
        my $start_time = thetime();
        my $set_rhost  = $is_network && $test->{command} =~ m/^finger01|ftp01|rcp01|rdist01|rlogin01|rpc01|rpcinfo01|rsh01|telnet01/;

        if ($set_rhost) {
            assert_script_run(q(export RHOST='127.0.0.1'));
        }

        if (is_serial_terminal) {
            script_run($klog_stamp);
            wait_serial(serial_term_prompt(), undef, 0, no_regex => 1);
            type_string($cmd_text);
            wait_serial($cmd_text, undef, 0, no_regex => 1);
            type_string("\n");
        }
        else {
            type_string("($cmd_text) | tee /dev/$serialdev\n");
        }
        my $test_log = wait_serial(qr/$fin_msg\d+/, $timeout, 0, record_output => 1);
        my ($timed_out, $result_export) = $self->record_ltp_result($cmd_file, $test, $test_log, $fin_msg, thetime() - $start_time, $is_posix);

        $result_export->{environment} = $environment;
        push(@{$test_result_export->{results}}, $result_export);
        if ($timed_out) {
            export_to_json($test_result_export);
            if (get_var('LTP_DUMP_MEMORY_ON_TIMEOUT')) {
                save_memory_dump(filename => $test->{name});
            }
            die "Can't continue; timed out waiting for LTP test case which may still be running or the OS may have crashed!";
        }

        if ($set_rhost) {
            assert_script_run('unset RHOST');
        }
    }

    export_to_json($test_result_export);

    script_run('[ "$ENABLE_WICKED" ] && systemctl enable wicked');
    script_run('journalctl --no-pager -p warning');

    $ver_linux_log = '/tmp/ver_linux_after.txt';
    script_run("$ver_linux_path > $ver_linux_log 2>&1");
    upload_logs($ver_linux_log);
}

1;

=head1 Discussion

This module extracts an LTP runtest file from the VM, parses it and then
executes the LTP test cases defined on each line of the runtest file. Logs are
uploaded and interpreted after each LTP test case completes.

LTP test cases are usually a binary executable or a shell script. Each line of
the runtest file contains the name of the test case and a string which is
executed by the shell.

The output of each test case is parsed for lines containing CONF and FAIL.
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

=head2 LTP_DUMP_MEMORY_ON_TIMEOUT

If set will request that the SUT's memory is dumped if the timer in this test
module runs out. This is does not include timeouts which are built into the
LTP test itself.

=head2 LTP_ENV

Comma separated list of environment variables to be set for tests.
E.g.: key=value,key2="value with spaces",key3='another value with spaces'

=cut

# vim: set sw=4 et:
