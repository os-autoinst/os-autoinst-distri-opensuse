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

    my $bci_virtualenv = get_var('BCI_VIRTUALENV', 0);

    # Avoid PackageKit to conflict about lock with zypper
    script_run("pkcon quit", die_on_timeout => 0) if (is_sle || is_opensuse);

    # common packages
    my @packages = ('git-core', 'python3', 'gcc', 'jq');
    if ($host_distri eq 'ubuntu') {
        push @packages, ('python3-dev', 'python3-pip', 'golang', 'postgresql-server-dev-all');
        push @packages, ('python3-virtualenv') if ($bci_virtualenv);
    } elsif ($host_distri eq 'rhel' && $version > 7) {
        push @packages, ('platform-python-devel', 'python3-pip', 'golang', 'postgresql-devel');
        push @packages, ('python3-virtualenv') if ($bci_virtualenv);
    } elsif ($host_distri =~ /centos|rhel/) {
        push @packages, ('python3-devel', 'python3-pip', 'golang', 'postgresql-devel');
        push @packages, ('python3-virtualenv') if ($bci_virtualenv);
    } elsif ($host_distri eq 'sles' || $host_distri =~ /leap/) {
        # SDK is needed for postgresql
        my $version = "$version.$sp";
        push @packages, ('postgresql-server-devel');
        push @packages, ('python3-virtualenv') if ($bci_virtualenv);
        if ($version eq "12.5") {
            script_retry("SUSEConnect --auto-agree-with-licenses -p sle-sdk/$version/$arch", delay => 60, retry => 3, timeout => $scc_timeout);
            # PackageHub is needed for jq
            script_retry("SUSEConnect -p PackageHub/12.5/$arch", delay => 60, retry => 3, timeout => $scc_timeout);
            script_retry('zypper -n in jq', retry => 3);
            push @packages, ('python36-devel', 'python36-pip');
            die "virtualenv is not supported on 12-SP5" if ($bci_virtualenv);
        } elsif ($version =~ /15\.[1-3]/) {
            # Desktop module is needed for SDK module, which is required for go and postgresql-devel
            script_retry("SUSEConnect -p sle-module-desktop-applications/$version/$arch", delay => 60, retry => 3, timeout => $scc_timeout);
            script_retry("SUSEConnect -p sle-module-development-tools/$version/$arch", delay => 60, retry => 3, timeout => $scc_timeout);
            push @packages, ('python3-devel', 'go', 'skopeo');
        } else {
            # Desktop module is needed for SDK module, which is required for go and postgresql-devel
            if ($host_distri !~ /leap/) {
                script_retry("SUSEConnect -p sle-module-desktop-applications/$version/$arch", delay => 60, retry => 3, timeout => $scc_timeout);
                script_retry("SUSEConnect -p sle-module-development-tools/$version/$arch", delay => 60, retry => 3, timeout => $scc_timeout);
                script_retry("SUSEConnect -p sle-module-python3/$version/$arch", delay => 60, retry => 3, timeout => $scc_timeout);
            }
            push @packages, qw(python311 python311-devel go skopeo python311-pip python311-tox);
        }
    } elsif ($host_distri =~ /opensuse/) {
        push @packages, qw(python3-devel go skopeo postgresql-server-devel python3-pip python3-tox);
        push @packages, ('python3-virtualenv') if ($bci_virtualenv);
    } else {
        die("Host is not supported for running BCI tests.");
    }
    return @packages;
}

sub activate_virtual_env {
    assert_script_run('virtualenv bci');
    assert_script_run('source bci/bin/activate');
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
    my $bci_virtualenv = get_var('BCI_VIRTUALENV', 0);

    record_info('Install', 'Install needed packages');
    my @packages = packages_to_install($version, $sp, $host_distri);
    if ($host_distri eq 'ubuntu') {
        # Sometimes, the host doesn't get an IP automatically via dhcp, we need force it just in case
        assert_script_run("dhclient -v");
        # This command prevents a prompt that asks for services to be restarted
        # causing a delay of 5min on each package install
        script_run('export DEBIAN_FRONTEND=noninteractive');
        foreach my $pkg (@packages) {
            script_retry("apt-get -y install $pkg", timeout => 300);
        }
        activate_virtual_env if ($bci_virtualenv);
        assert_script_run('pip3 --quiet install --upgrade pip', timeout => 600);
        assert_script_run("pip3 --quiet install tox", timeout => 600);
    } elsif ($host_distri =~ /centos|rhel/) {
        foreach my $pkg (@packages) {
            script_retry("yum install -y $pkg", timeout => 300);
        }
        activate_virtual_env if ($bci_virtualenv);
        assert_script_run('pip3 --quiet install --upgrade pip', timeout => 600);
        assert_script_run("pip3 --quiet install tox", timeout => 600);
    } elsif ($host_distri =~ /sles|opensuse/) {
        foreach my $pkg (@packages) {
            zypper_call("--quiet in $pkg", timeout => 300);
        }
        activate_virtual_env if ($bci_virtualenv);
        if (!grep(/-tox/, @packages)) {
            assert_script_run('pip --quiet install --upgrade pip', timeout => 600);
            assert_script_run("pip --quiet install tox --ignore-installed six", timeout => 600);
        }
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
    assert_script_run('deactivate') if ($bci_virtualenv);
}

sub test_flags {
    return {fatal => 1, milestone => 1};
}

1;
