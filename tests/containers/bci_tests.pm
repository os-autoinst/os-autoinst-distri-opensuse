# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: bci-tests runner
#   SUSE Linux Enterprise Base Container Images (SLE BCI)
#   provides truly open, flexible and secure container images and application
#   development tools for immediate use by developers and integrators without
#   the lock-in imposed by alternative offerings.
#
#   This module is used to test BCI repository within a container.
#
#   It installs the required python packages and uses the existing BCI-test
#   repository defined by BCI_TESTS_REPO. Then, it will run the different
#   tests environments defined by BCI_TEST_ENVS.
#   - install needed python environment
#   - clone bci-tests repo
#   - build project
#   - run test for each given environment
# Maintainer: qa-c team <qa-c@suse.de>

use Mojo::Base qw(consoletest);
use XML::LibXML;
use utils qw(systemctl zypper_call ensure_ca_certificates_suse_installed);
use version_utils qw(get_os_release);
use containers::common;
use testapi;

our $test_envs = get_var('BCI_TEST_ENVS', 'base,init,dotnet,python,node,go,multistage');

sub parse_logs {
    my $self = @_;

    upload_logs('junit_build.xml', failok => 1);

    # bci-tests produce separate XUnit results files for each environment.
    # We need tp merge all together into a single xml file that will
    # be used by OpenQA to represent the results in "External results"
    my $dom = XML::LibXML::Document->new('1.0', 'utf-8');
    my $root = $dom->createElement('testsuites');
    $dom->setDocumentElement($root);

    # Dump xml contents to a location where we can access later using data_url
    for my $env (split(/,/, $test_envs)) {
        my $log_file = upload_logs('junit_' . $env . '.xml', failok => 1);
        if ($log_file) {
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
    assert_script_run('curl ' . autoinst_url('/files/result.xml') . ' -o /tmp/result.txt');
    parse_extra_log('XUnit', '/tmp/result.txt');
}


sub run {
    my ($self) = @_;
    $self->select_serial_terminal;

    my $engine = get_required_var('CONTAINER_RUNTIME');
    my $bci_tests_repo = get_required_var('BCI_TESTS_REPO');
    my $bci_devel_repo = get_var('BCI_DEVEL_REPO');
    my $bci_timeout = get_var('BCI_TIMEOUT', 5400);

    ensure_ca_certificates_suse_installed;

    my ($running_version, $sp, $host_distri) = get_os_release;
    if ($engine eq 'podman') {
        install_podman_when_needed($host_distri);
        install_buildah_when_needed($host_distri);
    }
    elsif ($engine eq 'docker') {
        install_docker_when_needed($host_distri);
    }
    else {
        die("Runtime $engine not given or not supported");
    }

    # Show some info about the SLE host
    record_info('SCCcredentials', script_output('cat /etc/zypp/credentials.d/SCCcredentials', proceed_on_failure => 1));
    record_info('SUSEConnect -l', script_output('SUSEConnect -l', proceed_on_failure => 1));
    record_info('SUSEConnect -l', script_output('SUSEConnect --status-text', proceed_on_failure => 1));

    record_info('Install', 'Install needed packages');
    my @packages = ('git-core', 'python3', 'python3-devel', 'gcc');
    if (check_var('HOST_VERSION', '12-SP5')) {
        # pip is not installed in 12-SP5 by default in our hdds
        push @packages, 'python36-pip';
    } else {
        # skopeo is not available in <=12-SP5
        push @packages, 'skopeo';
    }
    foreach my $pkg (@packages) {
        zypper_call("--quiet in $pkg", timeout => 300);
    }
    assert_script_run('pip3.6 --quiet install --upgrade pip', timeout => 600);
    assert_script_run("pip3.6 --quiet install tox --ignore-installed six", timeout => 600);

    record_info('Clone', 'Clone BCI tests repository');
    assert_script_run("git clone -q --depth 1 $bci_tests_repo");

    record_info('Build', 'Build bci-tests project');
    assert_script_run('cd bci-tests');
    assert_script_run("export TOX_PARALLEL_NO_SPINNER=1");
    assert_script_run("export CONTAINER_RUNTIME=$engine");
    assert_script_run("export BCI_DEVEL_REPO=$bci_devel_repo") if $bci_devel_repo;
    my $build_options = check_var('HOST_VERSION', '12-SP5') ? '' : '-- -n auto';
    assert_script_run("tox -e build $build_options", timeout => 900);

    # Run the tests in parallel
    record_info('Tests', 'Build bci-tests project');
    my $ret = script_run("tox -e $test_envs --parallel", timeout => $bci_timeout);
    record_info('Result', "The test run command returned: $ret");

    # script_run returns undef if it hits timeout
    die('There was a timeout running some tests') if (!defined($ret));

    $self->parse_logs();

    die("Some tests failed.") if ($ret != 0);
}

sub test_flags {
    return {fatal => 1, milestone => 1};
}

1;
