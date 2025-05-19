# SUSE's openQA tests
#
# Copyright 2022-2025 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: Test deploy a helm chart in a k3s
# - install k3s, kubectl and helm
# - test helm install
# - test helm list
# - check the correct deployment of the helm chart
# - cleanup system (helm and k3s)
#
# Maintainer: QE-C team <qa-c@suse.de>

use Mojo::Base 'containers::basetest';
use File::Basename qw(dirname);
use testapi;
use utils;
use version_utils qw(get_os_release is_sle);
use serial_terminal qw(select_serial_terminal);
use Utils::Architectures qw(is_ppc64le);
use containers::k8s;

our $release_name = "privateregistry";

sub run {
    my ($self) = @_;
    my @private_registry_components = qw(core jobservice portal registry database redis trivy);
    my $test_image = "registry.suse.com/bci/bci-busybox";
    select_serial_terminal;

    my ($version, $sp, $host_distri) = get_os_release;
    # Skip HELM tests on SLES <15-SP3 and on PPC, where k3s is not available
    return if (!($host_distri == "sles" && $version == 15 && $sp >= 3) || is_ppc64le);
    die "helm tests only work on k3s" unless (check_var('CONTAINER_RUNTIMES', 'k3s'));

    my $helm_chart = get_required_var('HELM_CHART');

    install_kubectl();
    install_helm();

    # Pull helm chart, if it is a http file
    if ($helm_chart =~ m!^http(s?)://!) {
        my ($url, $path) = split(/#/, $helm_chart, 2);    # split extracted folder path, if present
        assert_script_run("curl -sSL --retry 3 --retry-delay 30 $url | tar -zxf -");
        $helm_chart = $path ? "./$path" : ".";
    }
    my $helm_values = get_var('HELM_CONFIG');
    assert_script_run("curl -sSL --retry 3 --retry-delay 30 -o myvalue.yaml $helm_values") if ($helm_values);
    my $set_options = "--set global.imageRegistry=registry.suse.de/suse/sle-15-sp6/update/products/privateregistry/containerfile";
    if (my $image = get_var('CONTAINER_IMAGE_TO_TEST')) {
        my ($repository, $tag) = split(':', $image, 2);
        $set_options = "--set app.image.repository=$repository --set app.image.tag=$tag";
    }
    my $helm_options = "--debug";
    $helm_options = "-f myvalue.yaml $helm_options" if ($helm_values);
    script_retry("helm pull $helm_chart", timeout => 300, retry => 6, delay => 60) if ($helm_chart =~ m!^oci://!);
    assert_script_run("helm install $set_options $release_name $helm_chart $helm_options", timeout => 300);
    assert_script_run("helm list");

    # Smoketest - is everything Ready?
    foreach my $component (@private_registry_components) {
      validate_script_output_retry("kubectl get pods -l component=$component", qr/$component/, title => "$component status:" ,fail_message => "$release_name-$component didn't deploy");
      my $full_pod_name = script_output("kubectl get pods -l component=$component --no-headers -o custom-columns=':metadata.name'");
      validate_script_output_retry("kubectl get pod $full_pod_name --no-headers -o 'jsonpath={.status.conditions[?(@.type==\"Ready\")].status}'", qr/True/, title => "$component readiness", fail_message => "$full_pod_name is not in the Ready state!");
      
    }

    #Install Traefik manually
    assert_script_run("helm install traefik oci://ghcr.io/traefik/helm/traefik --namespace kube-system");
    my $traefik_pod = script_output("kubectl get pods -n kube-system --no-headers -l app.kubernetes.io/name=traefik -o custom-columns=':metadata.name'");
    validate_script_output_retry("kubectl get pod $traefik_pod -n kube-system --no-headers -o 'jsonpath={.status.conditions[?(@.type==\"Ready\")].status}'", qr/True/, title => "Traefik readiness");


    # Get the webui credentials & ingress url
    my $registry_password = script_output("kubectl get secrets $release_name-harbor-core --template={{.data.HARBOR_ADMIN_PASSWORD}} | base64 -d -w 0");
    my $registry_ingress_url = script_output("kubectl get ingress $release_name-harbor-ingress -o jsonpath='{.spec..host}'");
    my $registry_ingress_ip = script_output("kubectl get ingress $release_name-harbor-ingress -o jsonpath='{.status.loadBalancer.ingress[0].ip}'");

    # Add the k3s IP to /etc/hosts
    assert_script_run("echo \"$registry_ingress_ip $registry_ingress_url\" | sudo tee -a /etc/hosts");

    # Login to Harbor
    script_run("podman login $registry_ingress_url --username admin --password $registry_password --tls-verify=false", retry => 5, delay => 10, timeout => 60);
    script_run("helm registry login $registry_ingress_url --username admin --password $registry_password --insecure", retry => 5, delay => 10, timeout => 60);

    # Push container
    assert_script_run("podman pull $test_image:latest", timeout => 60);
    assert_script_run("podman push --remove-signatures $test_image:latest $registry_ingress_url/library/main/$test_image:latest --tls-verify=false", timeout => 60);

    # Push chart
    assert_script_run("helm create dummy_chart && tar -czvf dummy_chart.tar.gz -C dummy_chart .", timeout => 60);
    assert_script_run("helm push dummy_chart.tar.gz oci://$registry_ingress_url/library --insecure-skip-tls-verify", timeout => 60);

}

sub post_fail_hook {
    my ($self) = @_;
    script_run('tar -capf /tmp/containers-logs.tar.xz /var/log/pods $(find /var/lib/rancher/k3s -name \*.log -name \*.toml)');
    upload_logs("/tmp/containers-logs.tar.xz");
    script_run("helm delete $release_name");
}

sub test_flags {
    return {milestone => 1};
}

1;
