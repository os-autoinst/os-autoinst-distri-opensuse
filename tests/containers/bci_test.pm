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
#   It makes the call to tox to run the different test environments and
#   parses the resulting JUnit logs at the end.
# Maintainer: qa-c team <qa-c@suse.de>

use Mojo::Base qw(consoletest);
use XML::LibXML;
use testapi;
use File::Basename;
use Utils::Architectures qw(is_ppc64le);

our $test_envs = get_var('BCI_TEST_ENVS', 'base,init,dotnet,python,node,go,multistage');
our $error_count = 0;

sub parse_logs {
    my $self = @_;

    # bci-tests produce separate XUnit results files for each environment.
    # We need tp merge all together into a single xml file that will
    # be used by OpenQA to represent the results in "External results"
    my $dom = XML::LibXML::Document->new('1.0', 'utf-8');
    my $root = $dom->createElement('testsuites');
    $dom->setDocumentElement($root);

    record_info('Files', script_output('ls -lh'));
    # Dump xml contents to a location where we can access later using data_url
    $test_envs = "all,$test_envs";
    for my $env (split(/,/, $test_envs)) {
        my $log_file;
        eval {
            $log_file = upload_logs('junit_' . $env . '.xml');
        };
        if ($@) {
            record_info('Skip', "Skipping results for $env. $@");
        } else {
            record_info('Parse', $log_file);
            my $dom = XML::LibXML->load_xml(location => "ulogs/$log_file");
            for my $node ($dom->findnodes('//testsuite')) {
                # Replace default attribute name "pytest" by its env name
                $node->{name} =~ s/pytest/$env/;
                # Append test results to the resulting xml file
                $root->appendChild($node);
            }
        }
    }
    $dom->toFile(hashed_string('result.xml'), 1);
    # Download file from host pool to the instance
    assert_script_run('curl -s ' . autoinst_url('/files/result.xml') . ' -o /tmp/result.txt');
    parse_extra_log('XUnit', '/tmp/result.txt');
}

sub run_tox_cmd {
    my ($self, $env) = @_;
    my $bci_marker = get_var('BCI_IMAGE_MARKER');
    my $bci_timeout = get_var('BCI_TIMEOUT', 1200);
    my $bci_reruns = get_var('BCI_RERUNS', 3);
    my $bci_reruns_delay = get_var('BCI_RERUNS_DELAY', 10);
    my $cmd = "tox -e $env -- -n auto";
    $cmd .= " -k \"$bci_marker\"" if $bci_marker;
    $cmd .= " --reruns $bci_reruns --reruns-delay $bci_reruns_delay";
    record_info("tox", "Running command: $cmd");
    my $ret = script_run("timeout $bci_timeout $cmd", timeout => ($bci_timeout + 3));
    if ($ret == 124) {
        # man timeout: If  the command times out, and --preserve-status is not set, then exit with status 124.
        record_soft_failure("The command <tox -e $env> timed out.");
        $error_count += 1;
    } elsif ($ret != 0) {
        record_soft_failure("The command <tox -e $env> failed.");
        $error_count += 1;
    } else {
        record_info('PASSED');
    }
}


sub run {
    my ($self) = @_;
    $self->select_serial_terminal;

    my $engine = get_required_var('CONTAINER_RUNTIME');
    my $bci_devel_repo = get_var('BCI_DEVEL_REPO');
    my $bci_tests_repo = get_required_var('BCI_TESTS_REPO');
    my $version = get_required_var('VERSION');

    record_info('Run', "Starting the tests for the following environments:\n$test_envs");
    my $bci_dir = fileparse($bci_tests_repo, qr/\.[^.]*/);
    # Sometimes ppc64le are still running type_string 'cd' command from select_serial_terminal and fail to run cd BCI-tests
    sleep 60 if is_ppc64le;
    assert_script_run("cd $bci_dir");
    assert_script_run("export TOX_PARALLEL_NO_SPINNER=1");
    assert_script_run("export CONTAINER_RUNTIME=$engine");
    $version =~ s/-SP/./g;
    assert_script_run("export OS_VERSION=$version");
    assert_script_run("export TARGET=ibs-cr");
    assert_script_run("export BCI_DEVEL_REPO=$bci_devel_repo") if $bci_devel_repo;

    # Run common tests from test_all.py
    $self->run_tox_cmd('all');

    # Run environment specific tests
    for my $env (split(/,/, $test_envs)) {
        $self->run_tox_cmd($env);
    }

    $self->parse_logs();

    # Mark the job as failed if any of the tests failed
    die("$error_count tests failed.") if ($error_count > 0);
}

sub test_flags {
    return {fatal => 1, milestone => 1};
}

1;
