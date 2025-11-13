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
use utils qw(zypper_call script_retry systemctl);
use version_utils qw(get_os_release is_sle);
use db_utils qw(push_image_data_to_db);
use containers::common;
use testapi;
use serial_terminal 'select_serial_terminal';
use containers::helm;
use containers::k8s qw(install_k3s install_helm);
use transactional qw(trup_call reboot_on_changes);

sub prepare_virtual_env {
    my ($version, $sp, $host_distri) = @_;
    my $arch = get_required_var('ARCH');
    my $scc_timeout = 1200;    # SCC can take really long timetimes
    my $install_timeout = 600;
    my $virtualenv = 'bci/bin/activate';
    my $python = 'python3';
    my $pip = 'pip3';

    record_info('Install', 'Installing needed packages');

    my $should_pip_upgrade = 1;
    my $should_create_venv = 1;

    if ($host_distri =~ /ubuntu/) {
        # Sometimes, the host doesn't get an IP automatically via dhcp, we need force it just in case
        assert_script_run("dhclient -v");
        # This command prevents a prompt that asks for services to be restarted
        # causing a delay of 5min on each package install
        script_run('export DEBIAN_FRONTEND=noninteractive');
        script_retry("apt-get -y install python3-venv", timeout => $install_timeout);
    } elsif ($host_distri =~ /centos|rhel/) {
        if (get_var("VERSION") =~ /mls8/) {
            assert_script_run("dnf install -y --allowerasing git-core jq python3.11 python3.11-pip");
            $python = 'python3.11';
            $pip = 'pip3.11';
        } else {
            script_retry("dnf install -y --allowerasing git-core python3 jq", timeout => $install_timeout);
        }
    } elsif ($host_distri =~ /micro/i) {
        # this works only for sle-micro 6.0 and 6.1
        # 6.2 is officially sles 16.0 with transactional variant
        # it is enough to run BCI on server variant only
        trup_call('pkg in skopeo tar git jq');
        reboot_on_changes;
    } elsif ($host_distri =~ /opensuse|sles/) {
        my @packages = ('jq', 'skopeo', 'git-core');
        # Avoid PackageKit to conflict about lock with zypper
        script_run("timeout 20 pkcon quit");
        # Wait for any zypper tasks in the background to finish
        assert_script_run('while pgrep -f zypp; do sleep 1; done', timeout => 300);
        my $version = "$version.$sp";
        if ($host_distri =~ /sles/i && $version =~ /12\./) {
            $should_pip_upgrade = 0;
            $should_create_venv = 0;
            $python = 'python3.11';
            $pip = 'pip3.11';
            @packages = ('jq');
            # PackageHub is needed for jq
            script_retry("SUSEConnect -p PackageHub/12.5/$arch", delay => 60, retry => 3, timeout => $scc_timeout);
            zypper_call("ar -f http://download.suse.de/ibs/SUSE:/SLE-12:/Update:/Products:/SaltBundle:/Update/standard/ saltbundle");
            zypper_call("rm python3-pip");
            zypper_call("in saltbundlepy-base venv-salt-minion");
            assert_script_run("mkdir -p ./bci/bin");
            assert_script_run("ln -s /usr/lib/venv-salt-minion/bin/activate ./$virtualenv");
        } elsif ($version =~ /15\.[4-7]/) {
            $python = 'python3.11';
            $pip = 'pip3.11';
            if ($host_distri =~ /sles/i) {
                script_retry("SUSEConnect -p sle-module-python3/$version/$arch", delay => 60, retry => 3, timeout => $scc_timeout);
            }
            push @packages, qw(git-core python311);
        } elsif ($version =~ /16/) {
            # Python 3.13 is the default vers. for SLE 16.0
            push @packages, qw(git-core python313);
        } elsif ($version =~ /Tumbleweed/) {
            # In TW we would like to test the latest version
            push @packages, qw(git-core python3);
        }
        zypper_call("--quiet in " . join(' ', @packages), timeout => $install_timeout);
    } else {
        die("Host is not supported for running BCI tests.");
    }

    assert_script_run("$python --version");
    assert_script_run("$python -m venv bci") if $should_create_venv;
    assert_script_run("source $virtualenv");
    assert_script_run("$python -m pip --quiet install --upgrade pip", timeout => $install_timeout) if $should_pip_upgrade;
    assert_script_run("$pip --quiet install tox", timeout => $install_timeout);
    record_info("pip freeze", script_output("$pip freeze", timeout => $install_timeout));
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

sub check_container_signature {
    my $engines = get_required_var('CONTAINER_RUNTIMES');
    my $engine;
    if ($engines =~ /podman|k3s/) {
        $engine = 'podman';
    } elsif ($engines =~ /docker/) {
        $engine = 'docker';
    } else {
        die('No valid container engines defined in CONTAINER_RUNTIMES variable!');
        return;
    }

    my $image = get_required_var('CONTAINER_IMAGE_TO_TEST');
    record_info('Image signature', "Checking signature of $image");

    my $cosign_image = "registry.suse.com/suse/cosign";

    my $engine_options = "-v /usr/share/pki/trust/anchors/SUSE_Trust_Root.crt.pem:/SUSE_Trust_Root.crt.pem:ro";
    my $options = "--key /usr/share/pki/containers/suse-container-key.pem";
    $options .= " --registry-cacert=/SUSE_Trust_Root.crt.pem";    # include SUSE CA for registry.suse.de
    $options .= " --insecure-ignore-tlog=true";    # ignore missing transparency log entries for registry.suse.de

    script_retry("$engine pull -q $image", timeout => 300, delay => 60, retry => 2);
    assert_script_run("$engine run --rm -q $engine_options $cosign_image verify $options $image", timeout => 300);
}

sub run {
    select_serial_terminal;
    my ($version, $sp, $host_distri) = get_os_release;

    prepare_virtual_env($version, $sp, $host_distri) if get_var('BCI_PREPARE');

    # Ensure LTSS subscription is active when testing LTSS containers.
    validate_script_output("SUSEConnect -l", qr/.*LTSS.*Activated/, fail_message => "Host requires LTSS subscription for LTSS container")
      if (get_var('CONTAINER_IMAGE_TO_TEST') =~ /ltss/i && ($version !~ /16/));

    update_test_repos if (get_var('BCI_TESTS_REPO'));

    # CONTAINER_RUNTIMES can be "docker", "podman" or both "podman,docker"
    my $engines = get_required_var('CONTAINER_RUNTIMES');
    # For BCI tests using podman, buildah package is also needed
    # buildah is not present in any sle-micro, including 6.2
    install_buildah_when_needed($host_distri) if ($engines =~ /podman/ && $host_distri !~ /micro/i);

    my $host_version = get_var("HOST_VERSION", get_required_var("VERSION"));    # VERSION is the version of the container, not the host.
    check_container_signature()
      if (get_var('CONTAINER_IMAGE_TO_TEST')
        && get_var("CONTAINERS_SKIP_SIGNATURE", "0") != 1
        && $host_version =~ "15-SP7|16\..*|slem-6\.1"
        && get_var("FLAVOR") !~ /BCI-Repo-Updates/
      );
}

sub test_flags {
    return {fatal => 1, milestone => 1};
}

1;
