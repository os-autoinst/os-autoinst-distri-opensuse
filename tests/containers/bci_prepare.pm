# SUSE's openQA tests
#
# Copyright 2022 SUSE LLC
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
use utils qw(zypper_call script_retry);
use version_utils qw(get_os_release);
use db_utils qw(push_image_data_to_db);
use containers::common;
use testapi;
use serial_terminal 'select_serial_terminal';


sub packages_to_install {
    my ($version, $sp, $host_distri) = @_;
    my $arch = get_required_var('ARCH');
    my $scc_timeout = 1200;    # SCC can take really long timetimes

    # Avoid PackageKit to conflict about lock with zypper
    script_run("pkcon quit", die_on_timeout => 0);

    # common packages
    my @packages = ('git-core', 'python3', 'gcc', 'jq');
    if ($host_distri eq 'ubuntu') {
        push @packages, ('python3-dev', 'python3-pip', 'golang');
    } elsif ($host_distri eq 'rhel' && $version > 7) {
        push @packages, ('platform-python-devel', 'python3-pip', 'golang');
    } elsif ($host_distri =~ /centos|rhel/) {
        push @packages, ('python3-devel', 'python3-pip', 'golang');
    } elsif ($host_distri eq 'sles') {
        my $version = "$version.$sp";
        push @packages, 'python3-devel';
        if ($version eq "12.5") {
            # PackageHub is needed for jq
            script_retry("SUSEConnect -p PackageHub/12.5/$arch", delay => 60, retry => 3, timeout => $scc_timeout);
            push @packages, 'python36-pip';
        } elsif ($version eq '15.0') {
            # On SLES15 go needs to be installed from packagehub. On later SLES it comes from the SDK module
            script_retry("SUSEConnect -p PackageHub/15/$arch", delay => 60, retry => 3, timeout => $scc_timeout);
            push @packages, ('go1.10', 'skopeo');
        } else {
            # Desktop module is needed for SDK module, which is required for installing go
            script_retry("SUSEConnect -p sle-module-desktop-applications/$version/$arch", delay => 60, retry => 3, timeout => $scc_timeout);
            script_retry("SUSEConnect -p sle-module-development-tools/$version/$arch", delay => 60, retry => 3, timeout => $scc_timeout);
            push @packages, ('go', 'skopeo');
        }
    } elsif ($host_distri =~ /opensuse/) {
        push @packages, qw(python3-devel go skopeo);
    } else {
        die("Host is not supported for running BCI tests.");
    }
    return @packages;
}

sub run {
    select_serial_terminal;

    # Wait for any zypper tasks in the background to finish
    assert_script_run('while pgrep -f zypp; do sleep 1; done', timeout => 300);

    # CONTAINER_RUNTIME can be "docker", "podman" or both "podman,docker"
    my $engines = get_required_var('CONTAINER_RUNTIME');
    my $bci_tests_repo = get_required_var('BCI_TESTS_REPO');
    my $bci_tests_branch = get_var('BCI_TESTS_BRANCH');

    my ($version, $sp, $host_distri) = get_os_release;

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
        assert_script_run('pip3.6 --quiet install --upgrade pip', timeout => 600);
        assert_script_run("pip3.6 --quiet install tox --ignore-installed six", timeout => 600);
    } else {
        die "Unexpected distribution ($host_distri) has been used";
    }

    # For BCI tests using podman, buildah package is also needed
    install_buildah_when_needed($host_distri) if ($engines =~ /podman/);

    record_info('Clone', "Clone BCI tests repository: $bci_tests_repo");
    my $branch = $bci_tests_branch ? "-b $bci_tests_branch" : '';
    assert_script_run("git clone $branch -q --depth 1 $bci_tests_repo /root/BCI-tests");

    # Pull the image in advance
    if (my $image = get_var('CONTAINER_IMAGE_TO_TEST')) {
        record_info('IMAGE', $image);
        # If $engines are multiple (e.g. CONTAINER_RUNTIME=podman,docker), we just pick one of them for this check
        # as this module is executed only once.
        my $engine;
        if ($engines =~ /podman/) {
            $engine = 'podman';
        } elsif ($engines =~ /docker/) {
            $engine = 'docker';
        } else {
            die('No valid container engines defined in CONTAINER_RUNTIME variable!');
        }
        script_retry("$engine pull -q $image", timeout => 300, delay => 60, retry => 3);
        record_info('Inspect', script_output("$engine inspect $image"));
        my $build = get_var('CONTAINER_IMAGE_BUILD');
        if ($build && $build ne 'UNKNOWN') {
            my $reference = script_output(qq($engine inspect --type image $image | jq -r '.[0].Config.Labels."org.opensuse.reference"'));
            # Note: Both lines are aligned, thus the additional space
            record_info('builds', "CONTAINER_IMAGE_BUILD:  $build\norg.opensuse.reference: $reference");
            die('Missmatch in image build number. The image build number is different than the one triggered by the container bot!') if ($reference !~ /$build$/);
        }
        if (get_var('IMAGE_STORE_DATA')) {
            my $size_b = script_output("$engine inspect --format \"{{.VirtualSize}}\" $image");
            my $size_mb = $size_b / 1000000;
            record_info('Size', $size_mb);
            push_image_data_to_db('containers', $image, $size_mb, flavor => get_required_var('BCI_IMAGE_MARKER'), type => 'VirtualSize');
        }

    }
}

sub test_flags {
    return {fatal => 1, milestone => 1};
}

1;
