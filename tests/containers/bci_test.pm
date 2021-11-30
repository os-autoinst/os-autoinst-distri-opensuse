# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: bci-tests runner
#   SUSE Linux Enterprise Base Container Images (SLE BCI)
#   provides truly open, flexible and secure container images and application
#   development tools for immediate use by developers and integrators without
#   the lock-in imposed by alternative offerings.
#
#   This module is used to test BCI repository and BCI container images.
#   It makes the call to tox to run a specific test environment.
# Maintainer: qa-c team <qa-c@suse.de>

use Mojo::Base qw(consoletest);
use Time::HiRes qw(clock_gettime CLOCK_MONOTONIC);
use testapi;
use utils qw(script_output_retry);

sub get_time {
    return clock_gettime(CLOCK_MONOTONIC);
}

sub run {
    my ($self, $run_args) = @_;
    die 'Need case_name to know which test to run.' unless $run_args->{test_env};
    $self->{test_env} = $run_args->{test_env};

    my $engine = get_required_var('CONTAINER_RUNTIME');
    my $bci_devel_repo = get_var('BCI_DEVEL_REPO');

    if ($bci_devel_repo && (script_output_retry("curl $bci_devel_repo", retry => 3, delay => 10) =~ /Error 404/)) {
        # If given, make sure the BCI repository url has content.
        $self->{fatal_failure} = 1;
        die("The repository $bci_devel_repo does not exist. Try re-running the tests with a valid URL.");
    }
    $self->{fatal_failure} = 0;

    assert_script_run('cd /root/bci-tests');
    assert_script_run("export TOX_PARALLEL_NO_SPINNER=1");
    assert_script_run("export CONTAINER_RUNTIME=$engine");
    assert_script_run("export BCI_DEVEL_REPO=$bci_devel_repo") if $bci_devel_repo;

    my $start_time = get_time();

    my $cmd = 'tox -e ' . $self->{test_env} . ' -- -n auto --reruns 3 --reruns-delay 10';
    record_info('cmd', $cmd);
    assert_script_run($cmd, timeout => get_var('BCI_TIMEOUT', 1200));

    my $duration = get_time() - $start_time;
    my $min = int($duration / 60);
    my $sec = $duration % 60;
    record_info('Duration', "${min}m ${sec}s\n");
}

sub post_fail_hook {
    my ($self) = @_;
    if ($self->{test_env} eq 'build') {
        record_info('MEEEH', 'Build failed. No need to run the remaining tests.');
        $self->{fatal_failure} = 1;
    }
}

1;
