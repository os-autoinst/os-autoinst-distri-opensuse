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
#   This module is used to test BCI repository and BCI container images.
#   It installs the required packages and uses the existing BCI-test
#   repository defined by BCI_TESTS_REPO.
# Maintainer: qa-c team <qa-c@suse.de>

use Mojo::Base qw(consoletest);
use XML::LibXML;
use utils qw(zypper_call ensure_ca_certificates_suse_installed);
use version_utils qw(get_os_release);
use containers::common;
use testapi;

sub run {
    my ($self) = @_;
    $self->select_serial_terminal;

    my $engine = get_required_var('CONTAINER_RUNTIME');
    my $bci_tests_repo = get_required_var('BCI_TESTS_REPO');

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
        record_info('pkg', $pkg);
        zypper_call("--quiet in $pkg", timeout => 300);
    }
    assert_script_run('pip3.6 --quiet install --upgrade pip', timeout => 600);
    assert_script_run("pip3.6 --quiet install tox --ignore-installed six", timeout => 600);

    record_info('Clone', "Clone BCI tests repository: $bci_tests_repo");
    assert_script_run("git clone -q --depth 1 $bci_tests_repo");
}

sub test_flags {
    return {fatal => 1, milestone => 1};
}

1;
