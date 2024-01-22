# SUSE's openQA tests
#
# Copyright 2019-2022 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Run systemd upstream test cases
#
# This module is an helper to run a single systemd test case under openQA.
# It is invoked from prepare_systemd_and_testsuite.pm with autotest::loadtest() and run_args parameter.
#
# Since the full upstream systemd testsuite it not yet compatible on SLE, when the test fails
# or timeouts, if the test name is contained in the SYSTEMD_SOFTFAIL variable, mark it as softfailed.
#
# Maintainer: qe-core@suse.com, Martin Loviska <mloviska@suse.com>

use Mojo::Base qw(systemd_testsuite_test);
use testapi;
use serial_terminal 'select_serial_terminal';
use Utils::Logging 'save_and_upload_log';
use version_utils 'is_sle';

my $test_hash;
my $logs_path_mask = '/var/tmp/systemd-tests/systemd-test';

sub build_cmd {
    my ($target, $args) = @_;
    my @opts = ();
    my $test = $args->{test};
    my $dir = $args->{dir};

    foreach my $k (keys %{$args->{make_opts}}) {
        if ($args->{make_opts}->{$k}) {
            push @opts, "$k=$args->{make_opts}->{$k}";
        }
    }

    return sprintf('%s make -C %s%s %s', join(" ", @opts), $dir, $test, $target);
}

# give a chance to softfail some specific subtests, known to not work on current SLE systemd
sub decide_result {
    my $name = shift;
    my $ok_to_softfail = get_var('SYSTEMD_SOFTFAIL');
    if (is_sle() && $name =~ m/$ok_to_softfail/) {
        record_soft_failure("poo#151738");
        return 'softfail';
    }
    return 'fail';
}

sub run {
    my ($self, $args) = @_;
    my $timeout = 900;
    my $marker = " systemd test runner: >>> $args->{test} has finished <<<";
    my $logs = qr[$logs_path_mask\.(\w+)\/];

    select_serial_terminal();

    assert_script_run(build_cmd('clean', $args), timeout => 180);
    # redirect stdout as a workaround to run the command and keep both the return code and the output
    my $rc = script_run(build_cmd('setup', $args) . "> /tmp/out.txt", timeout => 240);
    if ($rc != 0) {
        $self->{result} = decide_result($args->{test});
        return;
    }
    my $out = script_output('cat /tmp/out.txt');
    if ($out =~ $logs) {
        $test_hash = $1;
        record_info("$test_hash", sprintf('Test logs: %s.%s', $logs_path_mask, $test_hash));
    } else {
        bmwqemu::diag 'Cannot find the location for logs';
    }

    my $texec = sprintf('(%s;echo "%s [$?]")', build_cmd('run', $args), $marker);
    $rc = script_run $texec . "> /tmp/out.txt", timeout => $timeout;
    if ($rc != 0) {
        $self->{result} = decide_result($args->{test});
        return;
    }
    my $test_log = script_output 'cat /tmp/out.txt';
    if (defined($test_log) && $test_log =~ qr/$marker\s+\[(\d+)\]$/) {
        if ($1 != 0) {
            bmwqemu::diag "$args->{test} has failed with RC => $1!";
            $self->{result} = decide_result($args->{test});
        }
    } else {
        bmwqemu::diag "$args->{test} has timed out!";
        $self->{result} = decide_result($args->{test});
    }
}

sub post_fail_hook {
    my $lfile = sprintf('%s.%s/system.journal', $logs_path_mask, $test_hash);
    select_console('log-console');
    script_run(sprintf('xz -9 %s', $lfile));
    $lfile .= '.xz';
    upload_logs("$lfile", failok => 1);
    save_and_upload_log('journalctl -o short-precise --no-pager', "journalctl-host.txt");
}

1;
