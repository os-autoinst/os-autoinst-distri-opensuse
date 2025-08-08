# SUSE's openQA tests
#
# Copyright 2023 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: Executes liburing testing suite
# Maintainer: Kernel QE <kernel-qa@suse.de>
# More documentation is at the bottom

use base 'opensusebasetest';
use strict;
use warnings;
use testapi;
use serial_terminal 'select_serial_terminal';
use utils;
use LTP::WhiteList;

sub run {
    my $self = shift;

    select_serial_terminal;

    my $repository = get_var('LIBURING_REPO', 'https://github.com/axboe/liburing.git');
    my $timeout = get_var('LIBURING_TIMEOUT', 1800);
    my $version = get_var('LIBURING_VERSION', '');
    my $exclude = get_var('LIBURING_EXCLUDE', '');
    my $issues = get_var('LIBURING_KNOWN_ISSUES', '');
    my $whitelist = LTP::WhiteList->new($issues);
    my $pkgs = "git-core";
    my @lines;
    my $out;

    record_info('KERNEL', script_output('rpm -qi kernel-default'));
    # check if liburing2 is installed and eventually install it
    $pkgs .= " liburing2" if script_run('rpm -q liburing2');

    # install dependences
    zypper_call("in -t pattern devel_basis");
    zypper_call("in $pkgs");

    # select latest liburing version which is supported by the system
    if ($version eq '') {
        $out = script_output('rpm -q --qf "%{Version}\n" liburing2 | sort -nr | head -1');
        $version = "liburing-$out";
    }

    # download and compile tests
    assert_script_run("git clone --no-single-branch $repository");
    assert_script_run("cd liburing");
    assert_script_run("git checkout $version");
    record_info("test version", script_output("git log -1 --oneline"));
    assert_script_run("./configure");
    assert_script_run("make -C src");
    assert_script_run("make -C test");
    assert_script_run("cd test");

    # create environment information for known issues check
    my $environment = {
        product => get_var('DISTRI') . ':' . get_var('VERSION'),
        revision => get_var('BUILD'),
        flavor => get_var('FLAVOR'),
        arch => get_var('ARCH'),
        backend => get_var('BACKEND'),
        kernel => script_output('uname -r'),
        libc => '',
        gcc => '',
        harness => 'SUSE OpenQA',
        ltp_version => $version
    };

    # run tests executables
    my @skipped = $whitelist->list_skipped_tests($environment, 'liburing');
    my @tests = split(/\n/, script_output("ls -1 *.t"));
    my $tests_num = scalar(@tests);
    my @report_tap;
    my $index = 0;
    my $summary;
    my $ret;

    push(@report_tap, "liburing.tap ..");
    push(@report_tap, "TAP version 13");
    push(@report_tap, "1..$tests_num");

    foreach my $test (@tests) {
        unless ($whitelist->override_known_failures(
                $self,
                $environment,
                'liburing',
                $test
        )) {
            if (grep($test, @skipped)) {
                record_info(
                    "Exclude",
                    "Excluding tests: $test",
                    result => 'softfail'
                );
                next;
            }

            script_run("echo 'io_uring::run: Starting $test' > /dev/kmsg", quiet => 1);

            # liburing tests return code:
            # 0: passed
            # 1: failure
            # 77: skipped
            # 124: timeout
            $ret = script_run(
                "./$test",
                timeout => $timeout,
                proceed_on_failure => 1,
                quiet => 1,
            );

            $index++;

            if ($ret eq 77) {
                script_run("echo 'io_uring::run: Skipped $test' > /dev/kmsg", quiet => 1);
                next;
            }

            if ($ret eq 124) {
                $self->{result} = 'fail';
                $summary = "not ok $index $test (Timed out)";
            } elsif ($ret ne 0) {
                $self->{result} = 'fail';
                $summary = "not ok $index $test";
            } else {
                $summary = "ok $index $test";
            }

            push(@report_tap, $summary);
        }
    }
    script_output("cat <<'EOF' > liburing.tap\n" . join("\n", @report_tap) . "\nEOF");
    parse_extra_log(TAP => 'liburing.tap');
}

sub test_flags {
    return {fatal => 0};
}

1;

=head1 Discussion

Test module to run liburing testing suite.

=head1 Configuration

=head2 LIBURING_REPO

The liburing repository

=head2 LIBURING_VERSION

The liburing version

=head2 LIBURING_TIMEOUT

The liburing testing suite timeout

=head2 LIBURING_EXCLUDE

The liburing tests which we want to exclude. This can be useful for debugging.

=head2 LIBURING_KNOWN_ISSUES

The liburing tests which have known issues if they fail
