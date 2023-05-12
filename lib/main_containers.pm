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
    return get_var('CONTAINERS_UNTESTED_IMAGES', 0) || get_var('BCI_TESTS', 0) || get_var('CONTAINER_SLEM_RANCHER', 0);
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
    unless ((is_sle("<=15") and is_aarch64) || get_var('CONTAINERS_NO_SUSE_OS') || is_staging) {
        loadtest 'containers/container_diff';
    }
}

sub load_host_tests_podman {
    my ($run_args) = @_;
    # podman package is only available as of 15-SP1
    unless (is_sle("<15-sp1")) {
        load_container_engine_test($run_args);
        # In Public Cloud we don't have internal resources
        load_image_test($run_args) unless is_public_cloud || is_alp;
        load_3rd_party_image_test($run_args);
        loadtest 'containers/podman_pods';
        loadtest 'containers/podman_network';
        # Firewall is not installed in JeOS OpenStack, MicroOS and Public Cloud images
        loadtest 'containers/podman_firewall' unless (is_public_cloud || is_openstack || is_microos || is_alp);
        # Buildah is not available in SLE Micro, MicroOS and staging projects
        loadtest 'containers/buildah' unless (is_sle_micro || is_microos || is_leap_micro || is_alp || is_staging);
        # https://github.com/containers/podman/issues/5732#issuecomment-610222293
        # exclude rootless poman on public cloud because of cgroups2 special settings
        loadtest 'containers/rootless_podman' unless (is_sle('=15-sp1') || is_openstack || is_public_cloud);
    }
}

sub load_host_tests_docker {
    my ($run_args) = @_;
    load_container_engine_test($run_args);
    # In Public Cloud we don't have internal resources
    load_image_test($run_args) unless is_public_cloud || is_alp;
    load_3rd_party_image_test($run_args);
    # Firewall is not installed in Public Cloud, JeOS OpenStack and MicroOS but it is in SLE Micro
    loadtest 'containers/docker_firewall' unless (is_public_cloud || is_openstack || is_microos);
    unless (is_sle("<=15") && is_aarch64) {
        # these 2 packages are not avaiable for <=15 (aarch64 only)
        # zypper-docker is not available in factory and in SLE Micro/MicroOS
        loadtest 'containers/zypper_docker' unless (is_tumbleweed || is_sle_micro || is_microos || is_leap_micro);
        loadtest 'containers/docker_runc';
    }
    unless (check_var('BETA', 1) || is_sle_micro || is_microos || is_leap_micro || is_staging) {
        # These tests use packages from Package Hub, so they are applicable
        # to maintenance jobs or new products after Beta release
        # PackageHub is not available in SLE Micro | MicroOS
        loadtest 'containers/registry' if (is_x86_64 || is_sle('>=15-sp4'));
        loadtest 'containers/docker_compose' unless is_public_cloud;
    }
    # Expected to work anywhere except of real HW backends, PC and Micro
    unless (is_generalhw || is_ipmi || is_public_cloud || is_openstack || is_sle_micro || is_microos || is_leap_micro) {
        loadtest 'containers/validate_btrfs';
    }
}

sub load_host_tests_containerd_rmt {
    loadtest 'containers/containerd_rmt';
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
        $backends = get_var("PUBLIC_CLOUD_PROVIDER", "GCE,EC2,AZURE,K3S");
    } elsif (is_opensuse) {
        $backends = get_var("PUBLIC_CLOUD_PROVIDER", "K3S");
    } else {
        die("Helm backend not supported on this host");
    }

    foreach (split(',\s*', $backends)) {
        push @{$run_args->{backends}}, $_;
        load_container_helm($run_args, $_);
    }
}

sub load_image_tests_in_k8s {
    my ($run_args) = @_;
    my $providers = undef;

    $providers = get_var("PUBLIC_CLOUD_PROVIDER", "GCE,EC2,AZURE");

    foreach (split(',\s*', $providers)) {
        push @{$run_args->{provider}}, $_;
        loadtest('containers/push_container_image_to_pc', run_args => $run_args, name => "push_container_image_to_" . $_);
        push @{$run_args->{provider}}, $_;
        loadtest('containers/run_container_in_k8s', run_args => $run_args, name => "run_container_in_k8s_" . $_);
    }
}

sub load_image_tests_in_openshift {
    loadtest 'containers/openshift_image';
}

sub update_host_and_publish_hdd {
    # Method used to update pre-installed host images, booting
    # the existing qcow2 and publish a new qcow2
    unless (is_sle_micro) {
        # boot tests and updates are handled already by products/sle-micro/main.pm
        # we only need to shutdown the VM before publishing the HDD
        loadtest 'boot/boot_to_desktop';
        loadtest 'containers/update_host';
        loadtest 'containers/openshift_setup' if check_var('CONTAINER_RUNTIME', 'openshift');
    }
    loadtest 'shutdown/cleanup_before_shutdown' if is_s390x;
    loadtest 'shutdown/shutdown';
    loadtest 'shutdown/svirt_upload_assets' if is_s390x;
}

sub load_container_tests {
    my $runtime = get_required_var('CONTAINER_RUNTIME');

    if (get_var('CONTAINER_UPDATE_HOST')) {
        update_host_and_publish_hdd();
        return;
    }

    # Need to boot a qcow except in JeOS, SLEM and MicroOS where the system is booted already
    if (get_var('BOOT_HDD_IMAGE') && !(is_jeos || is_sle_micro || is_microos || is_leap_micro || is_alp)) {
        loadtest 'installation/bootloader_zkvm' if is_s390x;
        # On Public Cloud we're already booted in the SUT
        loadtest 'boot/boot_to_desktop' unless is_public_cloud;
    }

    if (is_container_image_test() && !(is_jeos || is_sle_micro || is_microos || is_leap_micro) && $runtime !~ /k8s|openshift/) {
        # Container Image tests common
        loadtest 'containers/host_configuration';
        loadtest 'containers/bci_prepare' if (get_var('BCI_TESTS'));
    }

    if (get_var('CONTAINER_SLEM_RANCHER')) {
        loadtest 'containers/slem_rancher';
        return;
    }

    if ($runtime eq 'k3s') {
        loadtest 'containers/run_container_in_k3s';
        return;
    }

    foreach (split(',\s*', $runtime)) {
        my $run_args = OpenQA::Test::RunArgs->new();
        $run_args->{runtime} = $_;
        if (is_container_image_test()) {
            if (get_var('BCI_TESTS')) {
                loadtest('containers/bci_test', run_args => $run_args, name => 'bci_test_' . $run_args->{runtime});
                # For Base image we also run traditional image.pm test
                load_image_test($run_args) if (is_sle(">=15-SP3") && check_var('BCI_TEST_ENVS', 'base'));
            } elsif (is_sle_micro || is_alp) {
                # Test toolbox image updates
                loadtest 'microos/toolbox';
            } else {
                # Common openQA image tests
                load_image_tests_podman($run_args) if (/podman/i);
                load_image_tests_docker($run_args) if (/docker/i);
                load_image_tests_in_k8s($run_args) if (/k8s/i);
                load_image_tests_in_openshift if (/openshift/i);
            }
        } elsif (get_var('REPO_BCI')) {
            loadtest 'containers/host_configuration';
            loadtest 'containers/bci_repo';
        } else {
            # Container Host tests
            loadtest 'microos/toolbox' if (/podman/i && (is_sle_micro || is_microos || is_leap_micro));
            load_host_tests_podman($run_args) if (/podman/i);
            load_host_tests_docker($run_args) if (/docker/i);
            load_host_tests_containerd_crictl() if (/containerd_crictl/i);
            load_host_tests_containerd_nerdctl() if (/containerd_nerdctl/i);
            load_host_tests_containerd_rmt() if (/containerd_rmt/i);
            loadtest('containers/kubectl') if (/kubectl/i);
            load_host_tests_helm($run_args) if (/helm/i);
            loadtest 'containers/apptainer' if (/apptainer/i);
        }
    }
    loadtest 'containers/bci_logs' if (get_var('BCI_TESTS'));
    loadtest 'console/coredump_collect' unless (is_public_cloud || is_jeos || is_sle_micro || is_microos || is_leap_micro || is_alp || get_var('BCI_TESTS') || is_ubuntu_host || is_expanded_support_host);
}
