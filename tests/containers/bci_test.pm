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
#   It makes the call to tox to run the different test environments defined
#   in the variable BCI_TEST_ENVS.
# Maintainer: qa-c team <qa-c@suse.de>

use Mojo::Base qw(consoletest);
use XML::LibXML;
use testapi;
use serial_terminal 'select_serial_terminal';
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
    record_info("tox", "Running command: $cmd");
    my $ret = script_run("timeout $bci_timeout $cmd", timeout => ($bci_timeout + 3));
    if ($ret == 124) {
        # man timeout: If  the command times out, and --preserve-status is not set, then exit with status 124.
        record_info('Softfail', "The command <tox -e $env> timed out.", result => 'softfail');
        $error_count += 1;
    } elsif ($ret != 0) {
        record_info('Softfail', "The command <tox -e $env> failed.", result => 'softfail');
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
    script_run('mv junit_' . $env . '.xml junit_' . $env . '_${CONTAINER_RUNTIME}.xml');
}

sub reset_engines {
    my ($self, $current_engine) = @_;
    my ($version, $sp, $host_distri) = get_os_release;
    my $sp_version = "$version.$sp";
    if ($sp_version =~ /15.3|15.4/) {
        # This workaround is only needed in SLE 15-SP3 and 15-SP4 (and Leap 15.3 and 15.4)
        # where we need to restart docker and firewalld before running podman, otherwise
        # the podman containers won't have access to the outside world.
        my $engines = get_required_var('CONTAINER_RUNTIME');
        if ($engines =~ /docker/ && $host_distri =~ /sles|opensuse/ && $host_distri =~ /sles|opensuse/) {
            ($current_engine eq 'podman') ? systemctl("stop docker") : systemctl("start docker");
            script_run('systemctl --no-pager restart firewalld');
        }
    }
}

sub run {
    my ($self, $args) = @_;
    select_serial_terminal;

    $error_count = 0;

    my $engine = $args->{runtime};
    my $bci_devel_repo = get_var('BCI_DEVEL_REPO');
    my $bci_tests_repo = get_required_var('BCI_TESTS_REPO');
    my $version = get_required_var('VERSION');
    my $test_envs = get_required_var('BCI_TEST_ENVS');

    $self->reset_engines($engine);

    record_info('Run', "Starting the tests for the following environments:\n$test_envs");
    assert_script_run("cd /root/BCI-tests");
    assert_script_run("export TOX_PARALLEL_NO_SPINNER=1");
    assert_script_run("export CONTAINER_RUNTIME=$engine");
    $version =~ s/-SP/./g;
    assert_script_run("export OS_VERSION=$version");
    assert_script_run("export TARGET=ibs-cr");
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
