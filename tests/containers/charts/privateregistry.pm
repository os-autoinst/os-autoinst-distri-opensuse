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
use serial_terminal qw(select_serial_terminal);
use utils;
use containers::helm;
use containers::k8s qw(install_kubectl install_helm gather_k8s_logs);

our $release_name = "privateregistry";
our @private_registry_components = qw(core jobservice portal registry database redis trivy);

sub run {
    my ($self) = @_;
    select_serial_terminal;

    my $test_image = "registry.suse.com/bci/bci-busybox";
    my $test_chart = "dummy_chart";

    my $helm_chart = get_required_var('HELM_CHART');
    my $helm_values = get_var('HELM_CONFIG');

    return unless (helm_is_supported());

    install_kubectl();
    install_helm();

    helm_install_chart($helm_chart, $helm_values, $release_name);

    # Smoketest - is everything Ready?
    foreach my $component (@private_registry_components) {
        validate_script_output_retry("kubectl get pods -l component=$component", qr/$component/, title => "$component status:", fail_message => "$release_name-$component didn't deploy");
        my $full_pod_name = script_output("kubectl get pods -l component=$component --no-headers -o custom-columns=':metadata.name'");
        validate_script_output_retry("kubectl get pod $full_pod_name --no-headers -o 'jsonpath={.status.conditions[?(@.type==\"Ready\")].status}'", qr/True/, title => "$component readiness", retry => 10, delay => 30, fail_message => "$full_pod_name is not in the Ready state");
    }

    # Install Traefik manually when not pre-installed
    # TODO: Remove this part, once the k3s installation has been moved to the "Create HDD" job.
    if (script_output("kubectl get pods -n kube-system") !~ /traefik/) {
        assert_script_run("helm install traefik oci://ghcr.io/traefik/helm/traefik --namespace kube-system");
        my $traefik_pod = script_output("kubectl get pods -n kube-system --no-headers -l app.kubernetes.io/name=traefik -o custom-columns=':metadata.name'");
        validate_script_output_retry("kubectl get pod $traefik_pod -n kube-system --no-headers -o 'jsonpath={.status.conditions[?(@.type==\"Ready\")].status}'", qr/True/, title => "Traefik readiness");
    }

    # Get the webui credentials & ingress url
    my $registry_password = script_output("kubectl get secrets $release_name-harbor-core --template={{.data.HARBOR_ADMIN_PASSWORD}} | base64 -d -w 0");
    my $registry_ingress_url = script_output("kubectl get ingress $release_name-harbor-ingress -o jsonpath='{.spec..host}'");
    my $registry_ingress_ip = script_output("kubectl get ingress $release_name-harbor-ingress -o jsonpath='{.status.loadBalancer.ingress[0].ip}'");

    # Add the k3s IP to /etc/hosts
    assert_script_run("echo \"$registry_ingress_ip $registry_ingress_url\" | sudo tee -a /etc/hosts");

    # Login to Harbor
    script_run("podman login $registry_ingress_url --username admin --password $registry_password --tls-verify=false", retry => 5, delay => 10, timeout => 60);
    script_run("helm registry login $registry_ingress_url --username admin --password $registry_password --insecure", retry => 5, delay => 10, timeout => 60);

    # Container push & pull
    script_retry("podman pull $test_image:latest", timeout => 60, retry => 5, delay => 30);
    assert_script_run("podman push --remove-signatures $test_image:latest $registry_ingress_url/library/main/$test_image:latest --tls-verify=false", timeout => 60);
    assert_script_run("podman pull $registry_ingress_url/library/main/$test_image:latest --tls-verify=false", timeout => 60);

    # Chart push & pull
    assert_script_run("helm create $test_chart && tar -czvf $test_chart.tar.gz -C $test_chart .", timeout => 60);
    assert_script_run("helm push $test_chart.tar.gz oci://$registry_ingress_url/library --insecure-skip-tls-verify", timeout => 60);
    assert_script_run("helm pull oci://$registry_ingress_url/library/$test_chart -d /tmp/ --insecure-skip-tls-verify", timeout => 60);


}

sub post_fail_hook {
    my ($self) = @_;
    script_run('tar -capf /tmp/containers-logs.tar.xz /var/log/pods $(find /var/lib/rancher/k3s -name \*.log -name \*.toml)');
    upload_logs("/tmp/containers-logs.tar.xz");
    gather_k8s_logs('component', @private_registry_components);
    script_run("helm delete $release_name");
}

sub test_flags {
    return {milestone => 1};
}

1;
