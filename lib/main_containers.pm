# SUSE's openQA tests
#
# Copyright 2021-2025 SUSE LLC
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
use publiccloud::utils 'is_azure';
use Utils::Architectures;
use Utils::Backends;
use strict;
use warnings;

our @EXPORT = qw(
  is_container_test
  is_suse_host
  load_container_tests
  load_helm_chart_tests
  load_container_engine_test
);

sub is_container_test {
    return get_var('CONTAINER_RUNTIMES', 0);
}

sub is_container_image_test {
    return get_var('CONTAINERS_UNTESTED_IMAGES', 0) || get_var('BCI_TESTS', 0) || get_var('CONTAINER_SLEM_RANCHER', 0);
}

sub is_expanded_support_host {
    # returns if booted image is RedHat Expanded Support
    return get_var("HDD_1") =~ /sles-es/;
}

sub is_suse_host {
    my ($version, $sp, $host_distri) = get_os_release;
    return $host_distri =~ /sle|opensuse/;
}

sub is_ubuntu_host {
    # returns if booted image is Ubuntu
    return get_var("HDD_1") =~ /ubuntu/;
}

sub load_image_test {
    my ($run_args) = @_;
    loadtest('containers/image', run_args => $run_args, name => 'image_' . $run_args->{runtime});
}

sub load_third_party_image_test {
    # Third party image tests are not needed or redundant on:
    # - Staging
    # - Public Cloud
    # - VMWare due to lack of latest CPU version support
    # - Testing alternative cgroups version
    # - Testing docker-stable with CONTAINERS_DOCKER_FLAVOUR
    # - Testing latest Tumbleweed image with CONTAINER_IMAGE_TO_TEST
    # - FIPS tests
    # - Testing a different OCI runtime like crun
    return if (is_staging || is_public_cloud || is_vmware ||
        get_var("CONTAINERS_CGROUP_VERSION") ||
        get_var("CONTAINERS_DOCKER_FLAVOUR") ||
        get_var("CONTAINER_IMAGE_TO_TEST") ||
        get_var("FIPS_ENABLED") ||
        get_var("OCI_RUNTIME"));
    my ($run_args) = @_;
    loadtest('containers/third_party_images', run_args => $run_args, name => $run_args->{runtime} . '_3rd_party_images');
}

sub load_container_engine_test {
    my ($run_args) = @_;
    loadtest('containers/container_engine', run_args => $run_args, name => $run_args->{runtime});
}

sub load_rt_workload {
    my ($args) = @_;
    loadtest('containers/realtime', run_args => $args, name => $args->{runtime} . '_realtime');

}

sub load_container_helm {
    my ($run_args, $backend) = @_;
    loadtest('containers/helm', run_args => $run_args, name => $run_args->{runtime} . "_" . $backend);
}

sub load_image_tests_podman {
    my ($run_args) = @_;
    load_image_test($run_args);
}

sub load_volume_tests {
    my ($run_args) = @_;
    loadtest('containers/volumes', run_args => $run_args, name => 'volumes_' . $run_args->{runtime});
}

sub load_secret_tests {
    my ($run_args) = @_;
    loadtest('containers/secret', run_args => $run_args, name => 'secret_' . $run_args->{runtime});
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

sub load_container_engine_privileged_mode {
    my ($run_args) = @_;
    loadtest('containers/privileged_mode', run_args => $run_args, name => $run_args->{runtime} . "_privileged_mode");
}

sub load_compose_tests {
    my ($run_args) = @_;
    return if (is_staging);
    # SLEM 6.0 has podman 4.9.5 while SLEM 6.1 has podman 5.2.5
    # podman with docker-compose needs podman 5.x
    my $min_slem_version = ($run_args->{runtime} eq "podman") ? "6.1" : "6.0";
    return unless (is_tumbleweed || is_sle('>=16.0') || is_sle_micro(">=$min_slem_version"));
    loadtest('containers/compose', run_args => $run_args, name => $run_args->{runtime} . "_compose");
}

sub load_firewall_test {
    return if (is_public_cloud || is_openstack || is_microos ||
        get_var('FLAVOR') =~ /dvd/i && (is_sle_micro('<6.0') || is_leap_micro('<6.0'))
    );
    my ($run_args) = @_;
    loadtest('containers/firewall', run_args => $run_args, name => $run_args->{runtime} . "_firewall");
}

sub load_host_tests_podman {
    my ($run_args) = @_;
    load_container_engine_test($run_args);
    # In Public Cloud we don't have internal resources
    load_image_test($run_args) unless is_public_cloud;
    load_third_party_image_test($run_args);
    load_rt_workload($run_args) if is_rt;
    load_container_engine_privileged_mode($run_args);
    # podman artifact needs podman 5.4.0
    loadtest 'containers/podman_artifact' if (is_sle('>=16.0') || is_tumbleweed);
    # The registry module contains further tests for podman artifact pull/push
    # The distribution-registry package is only available on Tumbleweed & SLES 15-SP4
    unless (is_staging || is_transactional || is_sle("<15-sp4")) {
        loadtest('containers/registry', run_args => $run_args, name => $run_args->{runtime} . "_registry");
    }
    loadtest 'containers/podman_bci_systemd';
    loadtest 'containers/podman_pods';
    # CNI is the default network backend on SLEM<6 and SLES<15-SP6. It is still available on later products as a dependency for docker.
    # podman+CNI is not supported on SLEM6+ and SLES-15-SP6+.
    loadtest('containers/podman_network_cni') if (is_sle_micro('<6.0') || is_sle("<15-SP6"));
    # Firewall is not installed in JeOS OpenStack, MicroOS and Public Cloud images
    load_firewall_test($run_args);
    # IPv6 is not available on Azure
    loadtest 'containers/podman_ipv6' if (is_public_cloud && is_sle('>=15-SP5') && !is_azure);
    loadtest 'containers/podman_netavark' unless (is_staging || is_ppc64le);
    loadtest 'containers/skopeo' unless (is_sle('<15') || is_sle_micro('<5.5'));
    loadtest 'containers/podman_quadlet' unless (is_staging || is_leap("<16") || is_sle("<16") || is_sle_micro("<6.1"));
    load_secret_tests($run_args);
    # https://github.com/containers/podman/issues/5732#issuecomment-610222293
    # exclude rootless podman on public cloud because of cgroups2 special settings
    unless (is_openstack || is_public_cloud) {
        loadtest 'containers/rootless_podman';
        loadtest 'containers/podman_remote' if (is_sle('>=15-SP3') || is_sle_micro('5.5+') || is_tumbleweed);
    }
    # Buildah is not available in SLE Micro, MicroOS and staging projects
    loadtest('containers/buildah', run_args => $run_args, name => $run_args->{runtime} . "_buildah") unless (is_sle('<15') || is_sle_micro || is_microos || is_leap_micro || is_staging);
    load_volume_tests($run_args);
    load_compose_tests($run_args);
    loadtest('containers/seccomp', run_args => $run_args, name => $run_args->{runtime} . "_seccomp") unless is_sle('<15');
    loadtest('containers/isolation', run_args => $run_args, name => $run_args->{runtime} . "_isolation") unless (is_public_cloud || is_transactional);
    loadtest('containers/podmansh') if (is_tumbleweed && !is_staging && !is_transactional);
}

sub load_host_tests_docker {
    my ($run_args) = @_;
    load_container_engine_test($run_args);
    # In Public Cloud we don't have internal resources
    load_image_test($run_args) unless is_public_cloud;
    load_third_party_image_test($run_args);
    load_rt_workload($run_args) if is_rt;
    load_container_engine_privileged_mode($run_args);
    # Firewall is not installed in Public Cloud, JeOS OpenStack and MicroOS but it is in SLE Micro
    load_firewall_test($run_args);
    # The distribution-registry package is only available on Tumbleweed & SLES 15-SP4
    unless (is_staging || is_transactional || is_sle("<15-sp4")) {
        loadtest('containers/registry', run_args => $run_args, name => $run_args->{runtime} . "_registry");
    }
    # Skip this test on docker-stable due to https://bugzilla.opensuse.org/show_bug.cgi?id=1239596
    unless (is_transactional || is_public_cloud || is_sle('<15-SP4') || check_var("CONTAINERS_DOCKER_FLAVOUR", "stable")) {
        loadtest('containers/isolation', run_args => $run_args, name => $run_args->{runtime} . "_isolation");
    }
    load_volume_tests($run_args);
    load_compose_tests($run_args);
    loadtest('containers/seccomp', run_args => $run_args, name => $run_args->{runtime} . "_seccomp") unless is_sle('<15');
    # The docker-rootless-extras package is only available on SLES 15-SP4+
    # while the docker-stable-rootless-extras is available on SLES 16.0+
    if (is_tumbleweed || is_leap || is_sle && (is_sle('>=16') || is_sle('>=15-SP4') && !check_var("CONTAINERS_DOCKER_FLAVOUR", "stable"))) {
        # select_user_serial_terminal is broken on public cloud
        loadtest 'containers/rootless_docker' unless (is_public_cloud);
    }
    # Expected to work anywhere except of real HW backends, PC and Micro
    unless (is_generalhw || is_ipmi || is_public_cloud || is_openstack || is_sle_micro || is_microos || is_leap_micro || (is_sle('=12-SP5') && is_aarch64)) {
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

sub load_kubectl_tests {
    my $run_args = OpenQA::Test::RunArgs->new();
    my @k8s_versions = split('\s+', get_var("KUBERNETES_VERSIONS", ""));
    if (@k8s_versions) {
        loadtest('containers/kubectl_versions', run_args => $run_args);
        foreach my $k8s_version (@k8s_versions) {
            my $run_args = OpenQA::Test::RunArgs->new();
            $run_args->{k8s_version} = $k8s_version;
            loadtest('containers/kubectl', run_args => $run_args, name => "kubectl_" . $k8s_version);
        }
    } else {
        loadtest('containers/kubectl', run_args => $run_args);
    }
}

sub update_host_and_publish_hdd {
    # Method used to update pre-installed host images, booting
    # the existing qcow2 and publish a new qcow2
    unless (is_sle_micro) {
        # boot tests and updates are handled already by products/sle-micro/main.pm
        # we only need to shutdown the VM before publishing the HDD
        loadtest 'boot/boot_to_desktop';
        loadtest 'containers/update_host';
        loadtest 'containers/bci_prepare';
    }
    loadtest 'shutdown/cleanup_before_shutdown' if is_s390x;
    loadtest 'shutdown/shutdown';
    loadtest 'shutdown/svirt_upload_assets' if is_s390x;
}

sub load_helm_chart_tests {
    # Helm chart tests are not executed on k8s
    my $runtimes = get_var('CONTAINER_RUNTIMES');
    return if ($runtimes =~ /k8s/);

    my $chart = get_required_var('HELM_CHART');
    my $spr_credentials_defined = !!(
        get_var('SCC_REGISTRY', 0)
        && get_var('SCC_PROXY_USERNAME', 0)
        && get_var('SCC_PROXY_PASSWORD', 0)
    );

    loadtest 'containers/scc_login_to_registry' if (is_sle() && $spr_credentials_defined);
    my $host_version = get_var("HOST_VERSION", get_required_var("VERSION"));    # VERSION is the version of the container, not the host.
    if ($chart =~ m/rmt-helm$/) {
        loadtest 'containers/charts/rmt' if ($host_version =~ "15-SP[4,5,6,7]|16\..*|slem-.*");
    } elsif ($chart =~ m/private-registry/) {
        loadtest 'containers/charts/privateregistry';
    } elsif ($chart =~ m/kiosk/) {
        loadtest 'containers/charts/kiosk_firefox' if ($host_version =~ "15-SP[4,5,6,7]|16\..*|slem-.*");
    }
    else {
        die "Unsupported HELM_CHART value or HOST_VERSION";
    }
}

sub load_container_tests {
    my $runtime = get_required_var('CONTAINER_RUNTIMES');

    if (get_var('CONTAINER_UPDATE_HOST')) {
        update_host_and_publish_hdd();
        return;
    }

    # Need to boot a qcow except in JeOS, SLEM and MicroOS where the system is booted already
    if (get_var('BOOT_HDD_IMAGE') && !(is_jeos || is_sle_micro || is_microos || is_leap_micro)) {
        loadtest 'installation/bootloader_zkvm' if is_s390x;
        # On Public Cloud we're already booted in the SUT
        loadtest 'boot/boot_to_desktop' unless is_public_cloud;
    }

    if (is_sle('16.0+') && get_var('FLAVOR', '') =~ /increments|staging/i) {
        loadtest 'qa_automation/patch_and_reboot';
    }

    if (my $container_tests = get_var('CONTAINER_TESTS', '')) {
        loadtest "containers/$_" foreach (split(',\s*', $container_tests));
        return;
    }

    if (my $bats_package = get_var('BATS_PACKAGE', '')) {
        $bats_package = ($bats_package eq "aardvark-dns") ? "aardvark" : $bats_package;
        loadtest "containers/bats/$bats_package";
        return;
    }

    if (is_container_image_test() && !(is_jeos || is_sle_micro || is_microos || is_leap_micro) && $runtime !~ /k8s|openshift/) {
        # Container Image tests common
        loadtest 'containers/host_configuration';
        if (get_var('BCI_TESTS')) {
            loadtest 'containers/bci_collect_stats' if (get_var('IMAGE_STORE_DATA'));
            # Note: bci_version_check requires jq.
            loadtest 'containers/bci_version_check' if (get_var('CONTAINER_IMAGE_TO_TEST') && get_var('CONTAINER_IMAGE_BUILD'));
        }
    } elsif (is_tumbleweed && get_var('FLAVOR', '') =~ /dvd|net/i) {
        loadtest 'containers/host_configuration';
    }

    if (get_var('CONTAINER_SLEM_RANCHER')) {
        loadtest 'containers/slem_rancher';
        return;
    }

    if ($runtime eq 'k3s') {
        loadtest 'containers/run_container_in_k3s';
        return;
    }

    if (get_var('CONTAINER_SUMA')) {
        loadtest 'containers/suma_containers';
        return;
    }

    if (get_var('FIPS_ENABLED')) {
        loadtest "fips/fips_setup";
        foreach (split(',\s*', $runtime)) {
            my $run_args = OpenQA::Test::RunArgs->new();
            $run_args->{runtime} = $_;
            load_container_engine_test($run_args);
            load_image_test($run_args);
        }
        return;
    }

    foreach (split(',\s*', $runtime)) {
        my $run_args = OpenQA::Test::RunArgs->new();
        $run_args->{runtime} = $_;
        if (is_container_image_test()) {
            if (get_var('BCI_TESTS')) {
                loadtest('containers/bci_prepare');
                loadtest('containers/bci_test', run_args => $run_args, name => 'bci_test_' . $run_args->{runtime});
                # For Base image we also run traditional image.pm test
                load_image_test($run_args) if (is_sle(">=15-SP3") && check_var('BCI_TEST_ENVS', 'base'));
            } elsif (is_sle_micro) {
                # Test toolbox image updates
                loadtest('microos/toolbox') unless (is_staging);
            } else {
                # Common openQA image tests
                load_image_tests_podman($run_args) if (/podman/i);
                load_image_tests_docker($run_args) if (/docker/i);
                load_image_tests_in_k8s($run_args) if (/k8s/i);
            }
        } else {
            # Container Host tests
            loadtest 'microos/toolbox' if (/podman/i && !is_staging && (is_sle_micro || is_microos || is_leap_micro));
            loadtest 'console/enable_mac' if get_var("SECURITY_MAC");
            load_host_tests_podman($run_args) if (/podman/i);
            load_host_tests_docker($run_args) if (/docker/i);
            loadtest 'containers/multi_runtime' if (/multi_runtime/i);
            load_host_tests_containerd_crictl() if (/containerd_crictl/i);
            load_host_tests_containerd_nerdctl() if (/containerd_nerdctl/i);
            load_kubectl_tests() if (/kubectl/i);
            load_host_tests_helm($run_args) if (/helm/i);
            loadtest 'containers/apptainer' if (/apptainer/i);
        }
    }
    loadtest 'containers/bci_logs' if (get_var('BCI_TESTS'));
    loadtest 'console/coredump_collect' unless (is_public_cloud || is_jeos || is_sle_micro || is_microos || is_leap_micro || get_var('BCI_TESTS') || is_ubuntu_host || is_expanded_support_host);
}
