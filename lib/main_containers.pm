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
use testapi qw(check_var get_required_var get_var);
use Utils::Architectures;
use Utils::Backends;
use strict;
use warnings;

our @EXPORT = qw(
  is_container_test
  load_container_tests
  load_host_tests_podman
  load_3rd_party_image_test
);

sub is_container_test {
    return get_var('CONTAINER_RUNTIME', 0);
}

sub is_container_image_test {
    return get_var('CONTAINERS_UNTESTED_IMAGES', 0);
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
    my ($runtime) = @_;
    my $args = OpenQA::Test::RunArgs->new();
    $args->{runtime} = $runtime;

    loadtest('containers/image', run_args => $args, name => "image_$runtime");
}

sub load_3rd_party_image_test {
    my ($runtime) = @_;
    my $args = OpenQA::Test::RunArgs->new();
    $args->{runtime} = $runtime;

    loadtest('containers/third_party_images', run_args => $args, name => $runtime . "_3rd_party_images");
}

sub load_image_tests_podman {
    load_image_test('podman');
}

sub load_image_tests_docker {
    load_image_test('docker');
    # container_diff package is not avaiable for <=15 in aarch64
    # Also, we don't want to run it on 3rd party hosts
    unless ((is_sle("<=15") and is_aarch64) || get_var('CONTAINERS_NO_SUSE_OS')) {
        loadtest 'containers/container_diff';
    }
}

sub load_host_tests_podman {
    if (is_leap('15.1+') || is_tumbleweed || is_sle("15-sp1+") || is_sle_micro) {
        # podman package is only available as of 15-SP1
        loadtest 'containers/podman';
        load_image_test('podman');
        load_3rd_party_image_test('podman');
        loadtest 'containers/podman_firewall';
        loadtest 'containers/buildah' unless is_sle_micro;
        loadtest 'containers/rootless_podman' unless is_sle('=15-sp1');    # https://github.com/containers/podman/issues/5732#issuecomment-610222293
    }
}

sub load_host_tests_docker {
    loadtest 'containers/docker';
    load_image_test('docker');
    load_3rd_party_image_test('docker');
    loadtest 'containers/docker_firewall';
    unless (is_sle("<=15") && is_aarch64) {
        # these 2 packages are not avaiable for <=15 (aarch64 only)
        # zypper-docker is not available in factory
        loadtest 'containers/zypper_docker' unless is_tumbleweed;
        loadtest 'containers/docker_runc';
    }
    unless (check_var('BETA', 1)) {
        # These tests use packages from Package Hub, so they are applicable
        # to maintenance jobs or new products after Beta release
        loadtest 'containers/registry' if is_x86_64;
        loadtest 'containers/docker_compose';
    }
    # works currently only for x86_64, more are coming (poo#103977)
    # Expected to work for all but JeOS on 15sp4 after
    # https://github.com/os-autoinst/os-autoinst-distri-opensuse/pull/13860
    # Disabled on svirt backends (VMWare, Hyper-V and XEN) as the device name might be different than vdX
    loadtest 'containers/validate_btrfs' if (is_x86_64 and is_qemu);
}

sub load_host_tests_containerd_crictl {
    loadtest 'containers/containerd_crictl';
}

sub load_host_tests_containerd_nerdctl {
    loadtest 'containers/containerd_nerdctl';
}

sub load_container_tests {
    my $args = OpenQA::Test::RunArgs->new();
    my $runtime = get_required_var('CONTAINER_RUNTIME');

    if (get_var('BOOT_HDD_IMAGE')) {
        loadtest 'installation/bootloader_zkvm' if is_s390x;
        loadtest 'boot/boot_to_desktop' unless is_jeos;
    }

    if (is_container_image_test()) {
        # Container Image tests common
        loadtest 'containers/host_configuration' unless (is_expanded_support_host || is_ubuntu_host || is_jeos);
    }

    foreach (split(',\s*', $runtime)) {
        if (is_container_image_test()) {
            # Container Image tests
            load_image_tests_podman() if (/podman/i);
            load_image_tests_docker() if (/docker/i);
        }
        else {
            # Container Host tests
            load_host_tests_podman() if (/podman/i);
            load_host_tests_docker() if (/docker/i);
            load_host_tests_containerd_crictl() if (/containerd_crictl/i);
            load_host_tests_containerd_nerdctl() if (/containerd_nerdctl/i);
        }
    }

    loadtest 'console/coredump_collect' unless is_jeos;
}
