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
use version_utils qw(get_os_release check_version is_sle);

my $error_count;

sub skip_testrun {
    # Check if the current test run should be skipped.
    # This check is needed here to allow for fine-grained control over BCI test runs, otherwise not possible via the job groups

    # Skip due to test setting
    return 1 unless get_var('BCI_TESTS');

    # Skip Spack on SLES12-SP5 (https://bugzilla.suse.com/show_bug.cgi?id=1224345)
    return 1 if (check_var('BCI_IMAGE_NAME', 'spack') && is_sle && check_version('<15', get_required_var('HOST_VERSION')));

    # Skip Kiwi on RES, CentOS, Ubuntu
    my $bci_image_name = get_var('BCI_IMAGE_NAME');
    return 1 if (
        (get_var('BCI_IMAGE_NAME') =~ m/kiwi/g) &&
        (
            check_var('HOST_VERSION', 'LIBERTY9') ||
            check_var('HOST_VERSION', 'centos') ||
            check_var('HOST_VERSION', 'ubuntu') ||
            check_var('HOST_VERSION', 'res8') ||
            check_var('HOST_VERSION', 'mls8') ||
            check_var('HOST_VERSION', 'mls9')
        )
    );

    return 0;
}

sub run_tox_cmd {
    my ($self, $env) = @_;
    my $bci_marker = get_var('BCI_IMAGE_MARKER');
    my $bci_timeout = get_var('BCI_TIMEOUT', 1200) * get_var('TIMEOUT_SCALE', 1);
    my $bci_reruns = get_var('BCI_RERUNS', 3);
    my $bci_reruns_delay = get_var('BCI_RERUNS_DELAY', 10);
    my $tox_out = "tox_$env.txt";
    assert_script_run("export USE_MACVLAN_DUMMY=1");
    my $cmd = "tox -e $env -- -rxX -n auto";
    $cmd .= " -k \"$bci_marker\"" if $bci_marker;
    $cmd .= " --reruns $bci_reruns --reruns-delay $bci_reruns_delay";
    $cmd .= "| tee $tox_out";
    my $env_info = (split(/[ _:-]/, $env))[0];    # first word on many separators,to shorten long $env
    record_info("tox " . $env_info, "Running command: $cmd");
    assert_script_run("export TESTINFRA_LOGGING=1");
    script_run("set -o pipefail");    # required because we don't want to rely on consoletest_setup for BCI tests.
    my $ret = script_run("timeout $bci_timeout $cmd", timeout => ($bci_timeout + 60));
    upload_logs("$tox_out", failok => 1);
    script_run("tar zcf commands.tgz commands-*.txt");
    upload_logs("commands.tgz", failok => 1);
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
    my $ret_xf = script_run("$cmd_xf", timeout => ($bci_timeout + 60));
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

    if (skip_testrun()) {
        record_info('BCI skipped', 'BCI tests skipped');
        return;
    }

    $error_count = 0;

    # For some containers we need to fake the OS version to distinguish them
    my $os_version = get_var('BCI_OS_VERSION');

    my $engine = $args->{runtime};
    my $bci_devel_repo = get_var('BCI_DEVEL_REPO');
    my $bci_tests_repo = get_var('BCI_TESTS_REPO', 'https://github.com/SUSE/BCI-tests.git');
    my $bci_tests_branch = get_var('BCI_TESTS_BRANCH', '');    # Keep BCI_TESTS_BRANCH for backwards compatibility.
    if ($bci_tests_repo =~ m/(.*)#(.*)/) {
        $bci_tests_repo = $1;
        $bci_tests_branch = $2;
    } elsif ($bci_tests_repo =~ m/(.*)\/tree\/(.*)/) {
        # Also accept directly pasted links, e.g. 'https://github.com/SUSE/BCI-tests/tree/only-jdk11-sucks-on-ppc64'
        $bci_tests_repo = "$1.git";
        $bci_tests_branch = $2;
    }
    if (my $bci_repo = get_var('REPO_BCI')) {
        $bci_devel_repo = "http://openqa.suse.de/assets/repo/$bci_repo";
    }
    my $bci_target = get_var('BCI_TARGET', 'ibs-cr');
    my $version = get_required_var('VERSION');
    my $test_envs = get_required_var('BCI_TEST_ENVS');

    die "no BCI test environment (BCI_TEST_ENVS) set" unless ($test_envs);
    return if ($test_envs eq '-');

    reset_container_network_if_needed($engine);

    assert_script_run('source bci/bin/activate');

    record_info('Run', "Starting the tests for the following environments:\n$test_envs");
    assert_script_run("cd /root/BCI-tests && git fetch && git reset --hard $bci_tests_branch");
    assert_script_run("export TOX_PARALLEL_NO_SPINNER=1");
    assert_script_run("export TOX_SKIP_ENV=" . get_var('BCI_SKIP_ENVS', ''));
    assert_script_run("export CONTAINER_RUNTIME=$engine");
    if ($os_version) {
        script_run("export OS_VERSION=$os_version");
        validate_script_output('echo $OS_VERSION', sub { m/$os_version/ });
    } else {
        $version =~ s/-SP/./g;
        $version = lc($version);
        assert_script_run("export OS_VERSION=$version");
    }
    assert_script_run("export TARGET=$bci_target");
    assert_script_run("export BCI_DEVEL_REPO=$bci_devel_repo") if $bci_devel_repo;

    # Run environment specific tests
    for my $env (split(/,/, $test_envs)) {
        $self->run_tox_cmd($env);
    }

    assert_script_run('deactivate');

    # Mark the job as failed if any of the tests failed
    die("$error_count tests failed.") if ($error_count > 0);
}

sub test_flags {
    return {fatal => 0, no_rollback => 1};
}

1;
