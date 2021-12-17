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
use strict;
use warnings;

our @EXPORT = qw(
  is_container_test
  load_container_tests
);

sub is_container_test {
    return get_var('CONTAINER_RUNTIME', 0);
}

sub is_container_image_test {
    return get_var('CONTAINERS_UNTESTED_IMAGES', 0);
}

sub is_res_host {
    # returns if booted image is RedHat Expanded Support
    return get_var("HDD_1") =~ /(res82.qcow2|res79.qcow2)/;
}

sub is_ubuntu_host {
    # returns if booted image is Ubuntu
    return get_var("HDD_1") =~ /ubuntu/;
}

sub load_image_tests_podman {
    loadtest 'containers/podman_image';
}

sub load_image_tests_docker {
    loadtest 'containers/docker_image';
    # container_diff package is not avaiable for <=15 in aarch64
    # Also, we don't want to run it on 3rd party hosts
    unless ((is_sle("<=15") and is_aarch64) || get_var('CONTAINERS_NO_SUSE_OS')) {
        loadtest 'containers/container_diff';
    }
}

sub load_host_tests_podman {
    if (is_leap('15.1+') || is_tumbleweed || is_sle("15-sp1+")) {
        # podman package is only available as of 15-SP1
        loadtest 'containers/podman';
        loadtest 'containers/podman_image';
        loadtest 'containers/podman_3rd_party_images';
        loadtest 'containers/podman_firewall';
        loadtest 'containers/buildah';
        loadtest 'containers/rootless_podman';
    }
}

sub load_host_tests_docker {
    loadtest 'containers/docker';
    loadtest 'containers/docker_image';
    loadtest 'containers/docker_3rd_party_images';
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
    loadtest 'containers/validate_btrfs' if (is_x86_64 and !(is_jeos && is_sle("=15-SP4")));
}


sub load_container_tests {
    my $runtime = get_required_var('CONTAINER_RUNTIME');
    if (get_var('BOOT_HDD_IMAGE')) {
        loadtest 'installation/bootloader_zkvm' if is_s390x;
        loadtest 'boot/boot_to_desktop' unless is_jeos;
    }

    if (is_container_image_test()) {
        # Container Image tests
        loadtest 'containers/host_configuration' unless (is_res_host || is_ubuntu_host || is_jeos);
        load_image_tests_podman() if ($runtime =~ 'podman');
        load_image_tests_docker() if ($runtime =~ 'docker');
    } else {
        # Container Host tests
        load_host_tests_podman() if ($runtime =~ 'podman');
        load_host_tests_docker() if ($runtime =~ 'docker');
    }
    loadtest 'console/coredump_collect' unless is_jeos;
}
