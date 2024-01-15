# SUSE's openQA tests
#
# Copyright 2021-2023 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: bci-tests runner
#   SUSE Linux Enterprise Base Container Images (SLE BCI)
#   provides truly open, flexible and secure container images and application
#   development tools for immediate use by developers and integrators without
#   the lock-in imposed by alternative offerings.
#
#   This module is used to test BCI repository and BCI container images.
#   It makes the call to tox to run the different test environments defined
#   in the variable BCI_TEST_ENVS.
# Maintainer: QE-C team <qa-c@suse.de>

use Mojo::Base qw(consoletest);
use XML::LibXML;
use testapi;
use serial_terminal 'select_serial_terminal';
use containers::utils qw(reset_container_network_if_needed);
use File::Basename;
use utils qw(systemctl);
use version_utils qw(get_os_release);

my $error_count;

sub run_tox_cmd {
    my ($self, $env) = @_;
    my $bci_marker = get_var('BCI_IMAGE_MARKER');
    my $bci_timeout = get_var('BCI_TIMEOUT', 1200);
    my $bci_reruns = get_var('BCI_RERUNS', 3);
    my $bci_reruns_delay = get_var('BCI_RERUNS_DELAY', 10);
    my $tox_out = "tox_output.txt";
    my $cmd = "tox -e $env -- -rxX -n auto";
    $cmd .= " -k \"$bci_marker\"" if $bci_marker;
    $cmd .= " --reruns $bci_reruns --reruns-delay $bci_reruns_delay";
    $cmd .= "| tee $tox_out";
    my $env_info = (split(/[ _:-]/, $env))[0];    # first word on many separators,to shorten long $env
    record_info("tox " . $env_info, "Running command: $cmd");
    script_run("set -o pipefail");    # required because we don't want to rely on consoletest_setup for BCI tests.
    my $ret = script_run("timeout $bci_timeout $cmd", timeout => ($bci_timeout + 3));
    if ($ret == 124) {
        # man timeout: If  the command times out, and --preserve-status is not set, then exit with status 124.
        record_info('TIMEOUT', "The command <tox -e $env> timed out.", result => 'fail');
        $error_count += 1;
    } elsif ($ret != 0) {
        record_info('FAILED', "The command <tox -e $env> failed.", result => 'fail');
        $error_count += 1;
    } else {
        record_info('PASSED');
    }
    # Cut the tox log from the header onward and filter the text
    my $cmd_xf = "awk '/short test summary info/{f=1}f' $tox_out | grep XFAIL";
    my $ret_xf = script_run("$cmd_xf", timeout => ($bci_timeout + 3));
    record_info('Softfail', "The command <tox -e $env> has softfailures(XFAIL)", result => 'softfail') if ($ret_xf == 0);
    # Rename resulting junit file because it will be overwritten if we run
    # the same tox command later with another container engine. This way,
    # we will be able to parse the results for both container engines tox runs.
    # e.g. junit_python.xml -> junit_python_podman.xml
    # We use script_run because the file might not exist if tox timed out or other
    # unexpected error.
    script_run('mv junit_' . $env . '.xml junit_' . $env . '_${CONTAINER_RUNTIMES}.xml');
}

sub run {
    my ($self, $args) = @_;
    select_serial_terminal;

    if (get_var('BCI_SKIP')) {
        record_info('BCI skipped', 'BCI test skipped due to BCI_SKIP=1 setting');
        return;
    }

    # Skip the postgresql test runs on RHEL7 due to poo#129301
    my ($os_version, $sp, $host_distri) = get_os_release;
    my $is_rhel7 = ($host_distri eq 'rhel' && $os_version == 7);
    if (get_var('BCI_TEST_ENVS') eq 'postgres' && $is_rhel7) {
        record_soft_failure("poo#129301 unsupported authentication for postgresql on RHEL7");
        return;
    }

    $error_count = 0;

    my $engine = $args->{runtime};
    my $bci_devel_repo = get_var('BCI_DEVEL_REPO');
    my $bci_tests_repo = get_required_var('BCI_TESTS_REPO');
    if (my $bci_repo = get_var('REPO_BCI')) {
        $bci_devel_repo = "http://openqa.suse.de/assets/repo/$bci_repo";
    }
    my $bci_target = get_var('BCI_TARGET', 'ibs-cr');
    my $version = get_required_var('VERSION');
    my $test_envs = get_required_var('BCI_TEST_ENVS');
    return if ($test_envs eq '-');

    reset_container_network_if_needed($engine);

    record_info('Run', "Starting the tests for the following environments:\n$test_envs");
    assert_script_run("cd /root/BCI-tests");
    assert_script_run("export TOX_PARALLEL_NO_SPINNER=1");
    assert_script_run("export CONTAINER_RUNTIME=$engine");
    $version =~ s/-SP/./g;
    $version = lc($version);
    assert_script_run("export OS_VERSION=$version");
    assert_script_run("export TARGET=$bci_target");
    assert_script_run("export BCI_DEVEL_REPO=$bci_devel_repo") if $bci_devel_repo;

    # Run common tests from test_all.py
    $self->run_tox_cmd('all');

    # Run metadata tests when needed
    $self->run_tox_cmd('metadata') if get_var('BCI_TEST_METADATA');

    # Run environment specific tests
    for my $env (split(/,/, $test_envs)) {
        $self->run_tox_cmd($env);
    }


    # Mark the job as failed if any of the tests failed
    die("$error_count tests failed.") if ($error_count > 0);
}

sub test_flags {
    return {fatal => 0, no_rollback => 1};
}

1;
