# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: module loader of container tests
# Maintainer: qa-c@suse.de

package main_containers;
use base 'Exporter';
use Exporter;
use utils;
use version_utils;
use main_common qw(loadtest boot_hdd_image);
use testapi qw(check_var get_required_var get_var set_var);
use Utils::Architectures;
use Utils::Backends;
use strict;
use warnings;

our @EXPORT = qw(
  is_container_test
  load_container_tests
  load_host_tests_podman
  load_image_test
  load_3rd_party_image_test
  load_container_engine_test
);

sub is_container_test {
    return get_var('CONTAINER_RUNTIME', 0);
}

sub is_container_image_test {
    return get_var('CONTAINERS_UNTESTED_IMAGES', 0) || get_var('BCI_TESTS', 0);
}

sub is_expanded_support_host {
    # returns if booted image is RedHat Expanded Support
    return get_var("HDD_1") =~ /sles-es/;
}

sub is_ubuntu_host {
    # returns if booted image is Ubuntu
    return get_var("HDD_1") =~ /ubuntu/;
}

sub load_image_test {
    my ($run_args) = @_;
    loadtest('containers/image', run_args => $run_args, name => 'image_' . $run_args->{runtime});
}

sub load_3rd_party_image_test {
    my ($run_args) = @_;
    loadtest('containers/third_party_images', run_args => $run_args, name => $run_args->{runtime} . '_3rd_party_images');
}

sub load_container_engine_test {
    my ($run_args) = @_;
    loadtest('containers/container_engine', run_args => $run_args, name => $run_args->{runtime});
}

sub load_container_helm {
    my ($run_args, $backend) = @_;
    loadtest('containers/helm', run_args => $run_args, name => $run_args->{runtime} . "_" . $backend);
}

sub load_image_tests_podman {
    my ($run_args) = @_;
    load_image_test($run_args);
}

sub load_image_tests_docker {
    my ($run_args) = @_;
    load_image_test($run_args);
    # container_diff package is not avaiable for <=15 in aarch64
    # Also, we don't want to run it on 3rd party hosts
    unless ((is_sle("<=15") and is_aarch64) || get_var('CONTAINERS_NO_SUSE_OS')) {
        loadtest 'containers/container_diff';
    }
}

sub load_host_tests_podman {
    my ($run_args) = @_;
    # podman package is only available as of 15-SP1
    unless (is_sle("<15-sp1")) {
        load_container_engine_test($run_args);
        # In Public Cloud we don't have internal resources
        load_image_test($run_args) unless is_public_cloud;
        load_3rd_party_image_test($run_args);
        loadtest 'containers/podman_pods';
        # Firewall is not installed in JeOS OpenStack, MicroOS and Public Cloud images
        loadtest 'containers/podman_firewall' unless (is_public_cloud || is_openstack || is_microos);
        # Buildah is not available in SLE Micro and MicroOS
        loadtest 'containers/buildah' unless (is_sle_micro || is_microos || is_leap_micro);
        # https://github.com/containers/podman/issues/5732#issuecomment-610222293
        # exclude rootless poman on public cloud because of cgroups2 special settings
        loadtest 'containers/rootless_podman' unless (is_sle('=15-sp1') || is_openstack || is_public_cloud);
    }
}

sub load_host_tests_docker {
    my ($run_args) = @_;
    load_container_engine_test($run_args);
    # In Public Cloud we don't have internal resources
    load_image_test($run_args) unless is_public_cloud;
    load_3rd_party_image_test($run_args);
    # Firewall is not installed in Public Cloud, JeOS OpenStack and MicroOS but it is in SLE Micro
    loadtest 'containers/docker_firewall' unless (is_public_cloud || is_openstack || is_microos);
    unless (is_sle("<=15") && is_aarch64) {
        # these 2 packages are not avaiable for <=15 (aarch64 only)
        # zypper-docker is not available in factory and in SLE Micro/MicroOS
        loadtest 'containers/zypper_docker' unless (is_tumbleweed || is_sle_micro || is_microos || is_leap_micro);
        loadtest 'containers/docker_runc';
    }
    unless (check_var('BETA', 1) || is_sle_micro || is_microos || is_leap_micro) {
        # These tests use packages from Package Hub, so they are applicable
        # to maintenance jobs or new products after Beta release
        # PackageHub is not available in SLE Micro | MicroOS
        loadtest 'containers/registry' if is_x86_64;
        loadtest 'containers/docker_compose' unless is_public_cloud;
    }
    # works currently only for x86_64, more are coming (poo#103977)
    # Expected to work for all but JeOS on 15sp4 after
    # https://github.com/os-autoinst/os-autoinst-distri-opensuse/pull/13860
    # Disabled on svirt backends (VMWare, Hyper-V and XEN) as the device name might be different than vdX
    if ((is_x86_64 && is_qemu) && !(is_public_cloud || is_openstack || is_sle_micro || is_microos || is_leap_micro)) {
        loadtest 'containers/validate_btrfs';
    }
}

sub load_host_tests_containerd_crictl {
    loadtest 'containers/containerd_crictl';
}

sub load_host_tests_containerd_nerdctl {
    loadtest 'containers/containerd_nerdctl';
}

sub load_host_tests_helm {
    my ($run_args) = @_;
    my $backends = undef;

    if (is_sle('15-sp3+')) {
        $backends = get_var("HELM_K8S_BACKEND", "GKE,EKS,AKS,K3S");
    } elsif (is_opensuse) {
        $backends = get_var("HELM_K8S_BACKEND", "K3S");
    } else {
        die("Helm backend not supported on this host");
    }

    foreach (split(',\s*', $backends)) {
        push @{$run_args->{backends}}, $_;
        load_container_helm($run_args, $_);
    }
}

sub update_host {
    # Method used to update the non-sle hosts, booting
    # the existing qcow2 and publish a new qcow2
    loadtest 'boot/boot_to_desktop';
    loadtest 'containers/update_host';
    loadtest 'shutdown/shutdown';
}

sub load_container_tests {
    my $runtime = get_required_var('CONTAINER_RUNTIME');

    if (get_var('CONTAINER_UPDATE_HOST')) {
        update_host();
        return;
    }

    # Need to boot a qcow except in JeOS, SLEM and MicroOS where the system is booted already
    if (get_var('BOOT_HDD_IMAGE') && !(is_jeos || is_sle_micro || is_microos || is_leap_micro)) {
        loadtest 'installation/bootloader_zkvm' if is_s390x;
        # On Public Cloud we're already booted in the SUT
        loadtest 'boot/boot_to_desktop' unless is_public_cloud;
    }

    if (is_container_image_test() && !(is_jeos || is_sle_micro || is_microos || is_leap_micro)) {
        # Container Image tests common
        loadtest 'containers/host_configuration';
    }

    foreach (split(',\s*', $runtime)) {
        my $run_args = OpenQA::Test::RunArgs->new();
        $run_args->{runtime} = $_;
        if (is_container_image_test()) {
            if (get_var('BCI_TESTS')) {
                # External bci-tests pytest suite
                loadtest 'containers/bci_prepare';
                loadtest 'containers/bci_test';
            }
            else {
                # Common openQA image tests
                load_image_tests_podman($run_args) if (/podman/i);
                load_image_tests_docker($run_args) if (/docker/i);
            }
        } elsif (get_var('REPO_BCI')) {
            loadtest 'containers/host_configuration';
            loadtest 'containers/bci_repo';
        }
        else {
            # Container Host tests
            loadtest 'microos/toolbox' if (/podman/i && (is_sle_micro || is_microos || is_leap_micro));
            load_host_tests_podman($run_args) if (/podman/i);
            load_host_tests_docker($run_args) if (/docker/i);
            load_host_tests_containerd_crictl() if (/containerd_crictl/i);
            load_host_tests_containerd_nerdctl() if (/containerd_nerdctl/i);
            load_host_tests_helm($run_args) if (/helm/i);
        }
    }

    loadtest 'console/coredump_collect' unless (is_public_cloud || is_jeos || is_sle_micro || is_microos || is_leap_micro || get_var('BCI_TESTS') || is_ubuntu_host || is_expanded_support_host);
}
