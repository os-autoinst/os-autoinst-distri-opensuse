# SUSE's openQA tests
#
# Copyright 2019-2022 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Run systemd upstream test cases
# Maintainer: Martin Loviska <mloviska@suse.com>

use Mojo::Base qw(systemd_testsuite_test);
use testapi;
use serial_terminal 'select_serial_terminal';
use Utils::Logging 'save_and_upload_log';

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

sub run {
    my ($self, $args) = @_;
    my $timeout = 900;
    my $marker = " systemd test runner: >>> $args->{test} has finished <<<";
    my $logs = qr[$logs_path_mask\.(\w+)\/];

    select_serial_terminal();

    assert_script_run(build_cmd('clean', $args), timeout => 180);
    my $out = script_output(build_cmd('setup', $args), 240);

    if ($out =~ $logs) {
        $test_hash = $1;
        record_info("$test_hash", sprintf('Test logs: %s.%s', $logs_path_mask, $test_hash));
    } else {
        bmwqemu::diag 'Cannot find the location for logs';
    }

    my $texec = sprintf('(%s;echo "%s [$?]")', build_cmd('run', $args), $marker);
    my $test_log = script_output("$texec", $timeout);

    if (defined($test_log) && $test_log =~ qr/$marker\s+\[(\d+)\]$/) {
        if ($1 != 0) {
            bmwqemu::diag "$args->{test} has failed with RC => $1!";
            $self->{result} = 'fail';
        }
    } else {
        bmwqemu::diag "$args->{test} has timed out!";
        $self->{result} = 'fail';
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
