# SUSE's openQA tests
#
# Copyright 2023-2026 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: Executes liburing testing suite
# Maintainer: Kernel QE <kernel-qa@suse.de>
# More documentation is at the bottom

use Mojo::Base 'opensusebasetest';
use testapi;
use serial_terminal 'select_serial_terminal';
use utils;
use version_utils 'is_transactional';
use LTP::WhiteList;
use repo_tools 'add_qa_head_repo';
use package_utils 'install_package';

sub run {
    my $self = shift;

    select_serial_terminal;

    my $install = get_var('LIBURING_INSTALL', 'from_repo');
    my $timeout = get_var('LIBURING_TIMEOUT', 1800);
    my $exclude = get_var('LIBURING_EXCLUDE', '');
    my $issues = get_var('LIBURING_KNOWN_ISSUES', '');
    my $whitelist = LTP::WhiteList->new($issues);
    my $test_dir;
    my $out;

    record_info('KERNEL', script_output('rpm -qi kernel-default'));

    if ($install =~ /git/i) {
        my $repository = get_var('LIBURING_REPO', 'https://github.com/axboe/liburing.git');
        my $version = get_var('LIBURING_VERSION', '');
        my $pkgs = "git-core";

        $pkgs .= " liburing2" if script_run('rpm -q liburing2');
        install_package('-t pattern devel_basis');
        install_package($pkgs, trup_continue => 1, trup_apply => 1);

        if ($version eq '') {
            $out = script_output('rpm -q --qf "%{Version}\n" liburing2 | sort -nr | head -1');
            $version = "liburing-$out";
        }

        assert_script_run("git clone --depth=1 --branch $version $repository");
        assert_script_run("cd liburing");
        record_info("test version", script_output("git log -1 --oneline"));
        assert_script_run("./configure");
        assert_script_run("make -C src");
        assert_script_run("make -C test");
        $test_dir = 'liburing';
    } else {
        my $default_test_dir = '/usr/lib/liburing-tests';
        add_qa_head_repo(priority => 100);
        install_package('liburing-tests', trup_apply => 1);
        if (is_transactional()) {
            assert_script_run("cp -r $default_test_dir /tmp/liburing-tests");
            $test_dir = '/tmp/liburing-tests';
        } else {
            $test_dir = $default_test_dir;
        }
    }

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
    };

    # run tests executables
    my $test_exclude = '';
    my @skipped = $whitelist->list_skipped_tests($environment, 'liburing');
    if (@skipped) {
        push @skipped, $exclude if $exclude;
        my @sorted = sort @skipped;
        $test_exclude = join(' ', @sorted);
        my $count = scalar @sorted;
        my @details;
        for my $test (@sorted) {
            my $entry = $whitelist->find_whitelist_entry($environment, 'liburing', $test);
            my $message = ($entry && $entry->{message}) ? $entry->{message} : '';
            push @details, $message ? "$test: $message" : $test;
        }
        record_info(
            "Exclude ($count)",
            "Excluding tests ($count):\n" . join("\n", @details),
            result => 'softfail'
        );
    }

    if ($install =~ /git/i) {
        assert_script_run("echo 'TEST_EXCLUDE=\"$test_exclude\"' > test/config.local") if $test_exclude;
        $out = script_output(
            "make -C test runtests",
            timeout => $timeout,
            proceed_on_failure => 1
        );
    } else {
        my $env = $test_exclude ? "TEST_EXCLUDE=\"$test_exclude\" " : '';
        $out = script_output(
            "cd $test_dir && ${env}./runtests.sh *.t",
            timeout => $timeout,
            proceed_on_failure => 1
        );
    }

    my @issues;
    for my $line ($out =~ /Tests timed out \(\d+\):.*/mg) {
        push @issues, map { {name => $_, retval => 'undefined', type => 'timeout'} } $line =~ /<([\w\-\.]+\.t)>/g;
    }
    for my $line ($out =~ /Tests failed \(\d+\):.*/mg) {
        push @issues, map { {name => $_, retval => 1, type => 'failure'} } $line =~ /<([\w\-\.]+\.t)>/g;
    }

    if (@issues) {
        my @names = map { $_->{name} } @issues;
        record_info("Failed/Timed-out tests", join(", ", @names));

        my @unexpected;
        for my $test (@issues) {
            $environment->{retval} = $test->{retval};
            next if $whitelist->override_known_failures($self, $environment, 'liburing', $test->{name});
            push @unexpected, $test;
        }

        if (@unexpected) {
            for my $test (@unexpected) {
                my $msg = "$test->{type}: $test->{name}";
                record_info("Unexpected $test->{type}", $msg, result => 'fail');
            }
            $self->result('fail');
        }
    }
}

sub test_flags {
    return {fatal => 0};
}

1;

=head1 Description

Test module to run liburing testing suite.

=head1 Configuration

=head2 LIBURING_INSTALL

Installation method. Defaults to C<from_repo> which installs the pre-built
liburing-tests RPM from QA:Head. Set to C<from_git> to clone and build from
source instead.

=head2 LIBURING_REPO

The liburing git repository. Used only with C<LIBURING_INSTALL=from_git>.

=head2 LIBURING_VERSION

The liburing version to checkout. Used only with C<LIBURING_INSTALL=from_git>.

=head2 LIBURING_TIMEOUT

The liburing testing suite timeout.

=head2 LIBURING_EXCLUDE

The liburing tests which we want to exclude. This can be useful for debugging.

=head2 LIBURING_KNOWN_ISSUES

The liburing tests which have known issues if they fail.
