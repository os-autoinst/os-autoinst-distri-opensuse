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
use version_utils qw(get_os_release);
use db_utils qw(push_image_data_to_db);
use containers::common;
use testapi;
use serial_terminal 'select_serial_terminal';
use transactional qw(trup_call reboot_on_changes);

sub prepare_virtual_env {
    my ($version, $sp, $host_distri) = @_;
    my $arch = get_required_var('ARCH');
    my $scc_timeout = 1200;    # SCC can take really long timetimes
    my $install_timeout = 600;
    my $virtualenv = 'bci/bin/activate';
    my $python = 'python3';

    record_info('Install', 'Installing needed packages');

    if ($host_distri =~ /ubuntu/) {
        # Sometimes, the host doesn't get an IP automatically via dhcp, we need force it just in case
        assert_script_run("dhclient -v");
        # This command prevents a prompt that asks for services to be restarted
        # causing a delay of 5min on each package install
        script_run('export DEBIAN_FRONTEND=noninteractive');
        script_retry("apt-get -y install python3-venv", timeout => $install_timeout);
    } elsif ($host_distri =~ /centos|rhel/) {
        script_retry("dnf install -y --allowerasing git-core python3 jq", timeout => $install_timeout);
    } elsif ($host_distri =~ /micro/) {
        trup_call('pkg in skopeo tar git jq');
        reboot_on_changes;
    } elsif ($host_distri =~ /opensuse|sles/) {
        my @packages = ('jq', 'skopeo');
        # Avoid PackageKit to conflict about lock with zypper
        script_run("timeout 20 pkcon quit");
        # Wait for any zypper tasks in the background to finish
        assert_script_run('while pgrep -f zypp; do sleep 1; done', timeout => 300);
        my $version = "$version.$sp";
        if ($version =~ /12\./) {
            $python = 'python3.6';
            @packages = ('jq');
            # PackageHub is needed for jq
            script_retry("SUSEConnect -p PackageHub/12.5/$arch", delay => 60, retry => 3, timeout => $scc_timeout);
        } elsif ($version =~ /15\.[4-7]/) {
            $python = 'python3.11';
            script_retry("SUSEConnect -p sle-module-python3/$version/$arch", delay => 60, retry => 3, timeout => $scc_timeout) unless ($host_distri =~ /opensuse/);
            push @packages, qw(git-core python311);
        }
        zypper_call("--quiet in " . join(' ', @packages), timeout => $install_timeout);
    } else {
        die("Host is not supported for running BCI tests.");
    }

    assert_script_run("$python --version");
    assert_script_run("$python -m venv bci");
    assert_script_run("source $virtualenv");
    assert_script_run("$python -m pip --quiet install --upgrade pip", timeout => $install_timeout);
    assert_script_run("$python -m pip --quiet install tox", timeout => $install_timeout);
    assert_script_run('deactivate');
}

sub update_test_repos {
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
    record_info('Clone', "Cloning BCI tests repository: $bci_tests_repo\nBranch: $bci_tests_branch");
    my $branch = $bci_tests_branch ? "-b $bci_tests_branch" : '';
    assert_script_run('rm -rf /root/BCI-tests');
    assert_script_run("git clone $branch -q --depth 1 $bci_tests_repo /root/BCI-tests");
}

sub run {
    select_serial_terminal;
    my ($version, $sp, $host_distri) = get_os_release;

    prepare_virtual_env($version, $sp, $host_distri) if get_var('BCI_PREPARE');

    return if (get_var('HELM_CONFIG') && !($host_distri == "sles" && $version == 15 && $sp >= 3));

    # Ensure LTSS subscription is active when testing LTSS containers.
    validate_script_output("SUSEConnect -l", qr/.*LTSS.*Activated/, fail_message => "Host requires LTSS subscription for LTSS container") if (get_var('CONTAINER_IMAGE_TO_TEST') =~ /ltss/i);

    update_test_repos if (get_var('BCI_TESTS_REPO'));

    # CONTAINER_RUNTIMES can be "docker", "podman" or both "podman,docker"
    my $engines = get_required_var('CONTAINER_RUNTIMES');
    # For BCI tests using podman, buildah package is also needed
    install_buildah_when_needed($host_distri) if ($engines =~ /podman/ && $host_distri !~ /micro/i);
}

sub test_flags {
    return {fatal => 1, milestone => 1};
}

1;
