# SUSE's openQA tests
#
# Copyright 2022 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: Apply livepatch to a process with multiple (thousand) threads
# Maintainer: Martin Doucha <mdoucha@suse.cz>

use base 'opensusebasetest';
use testapi;
use package_utils;
use version_utils;
use utils;

sub run {
    my ($self, $tinfo) = @_;

    die 'ulp_threads must be scheduled by ulp_openposix' unless defined($tinfo);

    my $libver = $tinfo->{glibc_versions}[$tinfo->{run_id}];
    my $packname = $tinfo->{packname};
    my $threadcount = get_var('ULP_THREAD_COUNT', 1000);
    my $threadsleep = get_var('ULP_THREAD_SLEEP', 100);

    uninstall_package($packname) if scalar @{zypper_search("-i $packname")};
    install_package("--oldpackage glibc-$libver", trup_continue => 1,
        trup_reboot => 1);

    # Do not use background_script_run() here. The actual test runs inside
    # a subprocess and we need to read the target PID from test output.
    # Using background_script_run() would create a race condition and cause
    # random failures.
    enter_cmd("ulp_threads01 -t $threadcount -s $threadsleep &");

    # Read test PID for sending SIGUSR1
    my $status = wait_serial(qr/PID \d+ ready/);
    die 'Failed to parse test PID' unless $status =~ m/PID (\d+) ready/;
    my $pid = $1;

    # Read test PID for `wait`
    enter_cmd('echo PID:$!.');
    my $parent = wait_serial(qr/PID:\d+\./);
    die 'Failed to parse test PID' unless $parent =~ m/PID:(\d+)\./;
    $parent = $1;

    install_package($packname);
    assert_script_run("kill -s USR1 $pid");
    assert_script_run("wait $parent");
}

1;

=head1 Configuration

This test module is activated by LIBC_LIVEPATCH=1

=head2 ULP_THREAD_COUNT

The number of threads that will run during process livepatching. The test
program can adjust system thread count limits if necessary. Default: 1000

=head2 ULP_THREAD_SLEEP

Sleep length after each thread loop iteration (in milliseconds). High
thread-to-CPU ratio requires longer sleep length, otherwise the test process
may time out during clean up after receiving signal to terminate.
Default: 100ms

=cut
