# SUSE's openQA tests
#
# Copyright 2022-2023 SUSE LLC
# SPDX-License-Identifier: FSFAP
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
# Maintainer: QE-C team <qa-c@suse.de>

use Mojo::Base qw(consoletest);
use XML::LibXML;
use utils qw(zypper_call script_retry);
use version_utils qw(get_os_release is_sle is_opensuse);
use db_utils qw(push_image_data_to_db);
use containers::common;
use testapi;
use serial_terminal 'select_serial_terminal';


sub packages_to_install {
    my ($version, $sp, $host_distri) = @_;
    my $arch = get_required_var('ARCH');
    my $scc_timeout = 1200;    # SCC can take really long timetimes

    # Avoid PackageKit to conflict about lock with zypper
    script_run("pkcon quit", die_on_timeout => 0) if (is_sle || is_opensuse);

    # common packages
    my @packages = ('git-core', 'python3', 'gcc', 'jq');
    if ($host_distri eq 'ubuntu') {
        push @packages, ('python3-dev', 'python3-pip', 'golang', 'postgresql-server-dev-all');
    } elsif ($host_distri eq 'rhel' && $version > 7) {
        push @packages, ('platform-python-devel', 'python3-pip', 'golang', 'postgresql-devel');
    } elsif ($host_distri =~ /centos|rhel/) {
        push @packages, ('python3-devel', 'python3-pip', 'golang', 'postgresql-devel');
    } elsif ($host_distri eq 'sles') {
        # SDK is needed for postgresql
        my $version = "$version.$sp";
        push @packages, ('postgresql-server-devel');
        if ($version eq "12.5") {
            script_retry("SUSEConnect -p sle-sdk/$version/$arch", delay => 60, retry => 3, timeout => $scc_timeout);
            # PackageHub is needed for jq
            script_retry("SUSEConnect -p PackageHub/12.5/$arch", delay => 60, retry => 3, timeout => $scc_timeout);
            push @packages, ('python36-devel', 'python36-pip');
        } elsif ($version eq '15.0') {
            # Desktop module is needed for SDK module, which is required for go and postgresql-devel
            script_retry("SUSEConnect -p sle-module-desktop-applications/$version/$arch", delay => 60, retry => 3, timeout => $scc_timeout);
            script_retry("SUSEConnect -p sle-module-development-tools/$version/$arch", delay => 60, retry => 3, timeout => $scc_timeout);
            # On SLES15 go needs to be installed from packagehub. On later SLES it comes from the SDK module
            script_retry("SUSEConnect -p PackageHub/15/$arch", delay => 60, retry => 3, timeout => $scc_timeout);
            push @packages, ('python3-devel', 'go1.10', 'skopeo');
        } else {
            # Desktop module is needed for SDK module, which is required for go and postgresql-devel
            script_retry("SUSEConnect -p sle-module-desktop-applications/$version/$arch", delay => 60, retry => 3, timeout => $scc_timeout);
            script_retry("SUSEConnect -p sle-module-development-tools/$version/$arch", delay => 60, retry => 3, timeout => $scc_timeout);
            push @packages, ('python3-devel', 'go', 'skopeo');
        }
    } elsif ($host_distri =~ /opensuse/) {
        push @packages, qw(python3-devel go skopeo postgresql-server-devel);
    } else {
        die("Host is not supported for running BCI tests.");
    }
    return @packages;
}

sub run {
    select_serial_terminal;

    # Wait for any zypper tasks in the background to finish
    assert_script_run('while pgrep -f zypp; do sleep 1; done', timeout => 300);

    my ($version, $sp, $host_distri) = get_os_release;

    # CONTAINER_RUNTIMES can be "docker", "podman" or both "podman,docker"
    my $engines = get_required_var('CONTAINER_RUNTIMES');
    my $bci_tests_repo = get_required_var('BCI_TESTS_REPO');
    my $bci_tests_branch = get_var('BCI_TESTS_BRANCH');

    record_info('Install', 'Install needed packages');
    my @packages = packages_to_install($version, $sp, $host_distri);
    if ($host_distri eq 'ubuntu') {
        foreach my $pkg (@packages) {
            script_retry("apt-get -y install $pkg", timeout => 300);
        }
        assert_script_run('pip3 --quiet install --upgrade pip', timeout => 600);
        assert_script_run("pip3 --quiet install tox", timeout => 600);
    } elsif ($host_distri =~ /centos|rhel/) {
        foreach my $pkg (@packages) {
            script_retry("yum install -y $pkg", timeout => 300);
        }
        assert_script_run('pip3 --quiet install --upgrade pip', timeout => 600);
        assert_script_run("pip3 --quiet install tox", timeout => 600);
    } elsif ($host_distri =~ /sles|opensuse/) {
        foreach my $pkg (@packages) {
            zypper_call("--quiet in $pkg", timeout => 300);
        }
        assert_script_run('pip --quiet install --upgrade pip', timeout => 600);
        assert_script_run("pip --quiet install tox --ignore-installed six", timeout => 600);
    } else {
        die "Unexpected distribution ($host_distri) has been used";
    }

    return if (get_var('HELM_CONFIG') && !($host_distri == "sles" && $version == 15 && $sp >= 3));

    # For BCI tests using podman, buildah package is also needed
    install_buildah_when_needed($host_distri) if ($engines =~ /podman/);

    record_info('Clone', "Clone BCI tests repository: $bci_tests_repo");
    my $branch = $bci_tests_branch ? "-b $bci_tests_branch" : '';
    script_run('rm -rf /root/BCI-tests');
    assert_script_run("git clone $branch -q --depth 1 $bci_tests_repo /root/BCI-tests");
}

sub test_flags {
    return {fatal => 1, milestone => 1};
}

1;
