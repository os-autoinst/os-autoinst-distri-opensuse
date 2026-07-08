# SUSE's openQA tests
#
# SPDX-FileCopyrightText: SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Smoke test for Trento container images
# Packages: trento-web-image trento-wanda-image trento-checks-image mcp-server-trento-image
# Maintainer: Trento team <trento-developers@suse.com>

use Mojo::Base 'containers::basetest';
use testapi;
use serial_terminal 'select_serial_terminal';
use containers::helm;
use containers::k8s 'gather_k8s_logs';
use package_utils 'install_package';
use trento qw(
  setup_trento_ingress_tls
  trento_helm_set_options
  trento_helm_values_image_path_from_image
  trento_shell_quote
);
use utils 'script_retry';

sub run {
    select_serial_terminal;

    my $helm_chart = get_var('HELM_CHART', 'oci://registry.suse.com/trento/trento-server');
    my $image = get_required_var('CONTAINER_IMAGE_TO_TEST');
    my $helm_values_image_path = trento_helm_values_image_path_from_image($image);
    set_var('HELM_VALUES_IMAGE_PATH', $helm_values_image_path);

    my $trento_server_hostname = get_var('TRENTO_SERVER_HOSTNAME', 'localhost');
    my $admin_password = get_required_var('TRENTO_ADMIN_PASSWORD');
    my $admin_user = get_var('TRENTO_ADMIN_USER', 'admin');
    my $helm_release = get_var('TRENTO_HELM_RELEASE', 'trento-server');

    my $trento_ingress_url = get_var('TRENTO_INGRESS_URL', "https://$trento_server_hostname");
    my $kubeconfig = 'KUBECONFIG=/etc/rancher/k3s/k3s.yaml';
    my $trento_namespace = 'default';

    record_info('Chart', "Installing Trento chart under test: $helm_chart");
    record_info('Image', "Overriding $helm_values_image_path.image with $image");

    # Install the Kubernetes toolchain used by the Trento chart.
    install_package('curl', timeout => 600);
    assert_script_run('curl -sfL https://get.k3s.io | INSTALL_K3S_SKIP_SELINUX_RPM=true sh', timeout => 600);
    assert_script_run('mkdir -p ~/.kube && ln -sf /etc/rancher/k3s/k3s.yaml ~/.kube/config');
    assert_script_run('curl https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-4 | bash', timeout => 600);
    assert_script_run("$kubeconfig kubectl wait --for=condition=Ready node --all --timeout=300s", timeout => 330);

    # The chart creates Traefik Middleware objects, so wait for Traefik CRDs and deployment.
    script_retry("env $kubeconfig kubectl get crd middlewares.traefik.io", timeout => 180, retry => 30, delay => 6);
    assert_script_run("$kubeconfig kubectl wait --for=condition=established crd/middlewares.traefik.io --timeout=180s", timeout => 200);
    script_retry("env $kubeconfig kubectl -n kube-system get deploy traefik", timeout => 180, retry => 30, delay => 6);
    assert_script_run("$kubeconfig kubectl -n kube-system rollout status deploy/traefik --timeout=180s", timeout => 200);

    assert_script_run('getent hosts ' . trento_shell_quote($trento_server_hostname) . ' || echo ' . trento_shell_quote("127.0.0.1 $trento_server_hostname") . ' >> /etc/hosts');

    # Reuse the upstream helper manifests to enable cert-manager-backed ingress TLS.
    my ($tls_values_file, $smoke_test_script) = setup_trento_ingress_tls(
        kubeconfig => $kubeconfig,
        hostname => $trento_server_hostname,
        namespace => $trento_namespace);

    my $chart = helm_get_chart($helm_chart);
    my ($set_options, $helm_options) = helm_configure_values(get_var('HELM_CONFIG'), split_image_registry => 0);
    $set_options .= trento_helm_set_options(hostname => $trento_server_hostname, admin_password => $admin_password);
    $helm_options .= ' -f ' . trento_shell_quote($tls_values_file);

    # Install Trento Server with the rebuilt image and ingress TLS values.
    my $helm_cmd = join(' ',
        'env',
        $kubeconfig,
        'helm upgrade --install',
        $set_options,
        trento_shell_quote($helm_release),
        trento_shell_quote($chart),
        $helm_options);
    script_retry($helm_cmd, timeout => 900, retry => 5, delay => 15);

    # Wait for chart workloads before validating endpoints.
    assert_script_run(
        "$kubeconfig bash -c 'for w in \$(kubectl get deploy,statefulset -o name); do kubectl rollout status \"\$w\" --timeout=900s; done'",
        timeout => 930);
    assert_script_run("$kubeconfig kubectl wait --for=condition=Ready pods --all --timeout=900s", timeout => 930);
    assert_script_run("$kubeconfig helm status " . trento_shell_quote($helm_release), timeout => 120);

    # Run the upstream smoke test through the TLS ingress.
    my $smoke_test_cmd = join(' ',
        'env',
        $kubeconfig,
        'INGRESS_HOST=' . trento_shell_quote($trento_server_hostname),
        'WEB_BASE_URL=' . trento_shell_quote($trento_ingress_url),
        'WANDA_BASE_URL=' . trento_shell_quote("$trento_ingress_url/wanda"),
        'MCP_BASE_URL=' . trento_shell_quote("$trento_ingress_url/mcp"),
        'TEST_USERNAME=' . trento_shell_quote($admin_user),
        'TEST_PASSWORD=' . trento_shell_quote($admin_password),
        'bash',
        trento_shell_quote($smoke_test_script));
    script_retry($smoke_test_cmd, timeout => 300, retry => 3, delay => 15);
}

sub post_fail_hook {
    my ($self) = @_;
    my $kubeconfig = 'KUBECONFIG=/etc/rancher/k3s/k3s.yaml';

    record_info('Pods', script_output("$kubeconfig kubectl get pods -A -o wide", proceed_on_failure => 1));
    gather_k8s_logs();
}

sub test_flags {
    return {fatal => 0};
}
1;
