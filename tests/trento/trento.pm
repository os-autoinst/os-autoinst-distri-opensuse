# SUSE's openQA tests
#
# Copyright SUSE LLC
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
use utils 'script_retry';

sub _shell_quote {
    # Escape values before interpolating them into shell commands.
    my ($value) = @_;

    $value =~ s/'/'\\''/g;

    # Return a shell-safe single-quoted string.
    return "'$value'";
}

sub _image_name_from_reference {
    # Extract the image name from a full image reference such as registry/path/trento-web:tag.
    my ($image) = @_;

    # Drop the tag or digest so the remaining string ends with the repository/image name.
    $image =~ s/(?:[:@][^\/:@]+)$//;

    # Keep only the last path component, which identifies the Trento image.
    $image =~ s{.*/}{};

    # Return the image name used for the Helm values mapping.
    return $image;
}

sub _helm_values_image_path_from_image {
    # Map the rebuilt container image name to the Helm values subtree that owns that image.
    my ($image) = @_;

    # Derive the image name from CONTAINER_IMAGE_TO_TEST.
    my $image_name = _image_name_from_reference($image);

    # Keep this mapping explicit because not every image name matches its chart values path.
    # trento-web and trento-wanda are top-level subcharts, so their image path is <component>.image.
    # trento-checks is configured under the Wanda subchart as trento-wanda.checks.image.
    # mcp-server-trento is the image name, but the subchart key is trento-mcp-server.
    my %helm_values_image_path = (
        'trento-web' => 'trento-web',
        'trento-wanda' => 'trento-wanda',
        'trento-checks' => 'trento-wanda.checks',
        'mcp-server-trento' => 'trento-mcp-server');

    # Fail loudly when a new Trento image appears without an explicit chart mapping,
    # otherwise Helm would install the chart without testing the rebuilt image.
    die "No Helm values mapping found for image: $image_name"
      unless $helm_values_image_path{$image_name};

    # Return the path prefix used by the Helm helper to set <path>.image.repository and <path>.image.tag.
    return $helm_values_image_path{$image_name};
}

sub _json_escape {
    # Escape the minimal JSON string characters needed for username/password payloads.
    my ($value) = @_;

    # Backslashes must be escaped before quotes to avoid producing invalid JSON.
    $value =~ s/\\/\\\\/g;

    # Double quotes delimit JSON strings, so they must be escaped inside values.
    $value =~ s/"/\\"/g;

    # Return the escaped value to embed it in a JSON object.
    return $value;
}

sub run {
    # Use the serial terminal because this is a command-line-only validation without graphical needles.
    select_serial_terminal;

    # HELM_CHART points to the Trento Server Helm chart. The documented default is the published OCI chart.
    my $helm_chart = get_var('HELM_CHART', 'oci://registry.suse.com/trento/trento-server');

    # CONTAINER_IMAGE_TO_TEST is the rebuilt container image that must be injected into the chart.
    my $image = get_required_var('CONTAINER_IMAGE_TO_TEST');

    # Derive the Helm values image path from the rebuilt image provided by container-release-bot.
    my $helm_values_image_path = _helm_values_image_path_from_image($image);
    set_var('HELM_VALUES_IMAGE_PATH', $helm_values_image_path);

    # The hostname is passed to global.trentoWeb.origin as required by the chart installation docs.
    my $trento_server_hostname = get_var('TRENTO_SERVER_HOSTNAME', 'localhost');

    # Use an explicit test password supplied by openQA settings, avoiding hard-coded credentials in the test.
    my $admin_password = get_required_var('TRENTO_ADMIN_PASSWORD');

    # Use the documented default admin user unless a job setting overrides it.
    my $admin_user = get_var('TRENTO_ADMIN_USER', 'admin');

    # Allow overriding the release name while keeping "trento-server" as the documented release name.
    my $helm_release = get_var('TRENTO_HELM_RELEASE', 'trento-server');

    # Web, Wanda and login are validated through the Traefik ingress that k3s exposes on the
    # host's port 80. The chart's ingress routes / to Web, /wanda to Wanda (with a strip-prefix
    # middleware) and /mcp-server-trento to the MCP protocol port.
    my $trento_ingress_url = get_var('TRENTO_INGRESS_URL', 'http://localhost');

    # The MCP health endpoints (/livez, /readyz) live on the container's 8080 "health" port,
    # which is not published by any Service or ingress, so they are reached on the pod IP.
    my $trento_mcp_health_port = get_var('TRENTO_MCP_HEALTH_PORT', '8080');

    # KUBECONFIG must be present for every command because each assert_script_run runs in a fresh shell.
    my $kubeconfig = 'KUBECONFIG=/etc/rancher/k3s/k3s.yaml';

    # Make the chart and image selected by the job visible in the openQA result.
    record_info('Chart', "Installing Trento chart under test: $helm_chart");
    record_info('Image', "Overriding $helm_values_image_path.image with $image");

    # Ensure curl is present before using the documented K3s and Helm installation scripts.
    install_package('curl', timeout => 600);

    # Install single-node K3s as root following the Trento Server documentation.
    assert_script_run('curl -sfL https://get.k3s.io | INSTALL_K3S_SKIP_SELINUX_RPM=true sh', timeout => 600);

    # Make the K3s kubeconfig available to helpers that call kubectl without an inline KUBECONFIG.
    assert_script_run('mkdir -p ~/.kube && ln -sf /etc/rancher/k3s/k3s.yaml ~/.kube/config');

    # Install Helm as root following the Trento Server documentation.
    assert_script_run('curl https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3 | bash', timeout => 600);

    # Wait for the freshly installed K3s node to become Ready before deploying.
    assert_script_run("$kubeconfig kubectl wait --for=condition=Ready node --all --timeout=300s", timeout => 330);

    # The Trento chart creates Traefik Middleware objects (strip-prefix and no-introspection
    # ingress rules). K3s installs Traefik and its CRDs asynchronously, a few seconds after the
    # API becomes reachable, so the chart install races the CRD registration and otherwise fails
    # with: no matches for kind "Middleware" in version "traefik.io/v1alpha1" ensure CRDs are installed first.
    script_retry("$kubeconfig kubectl get crd middlewares.traefik.io", timeout => 180, retry => 30, delay => 6);
    assert_script_run("$kubeconfig kubectl wait --for=condition=established crd/middlewares.traefik.io --timeout=180s", timeout => 200);

    # Even once the CRD is established, API discovery can momentarily miss the Middleware kind
    # while Traefik is still being (re)deployed by the k3s addon (its pod may restart a few
    # times before settling). Wait for the traefik Deployment to become available so the API
    # is stable before installing the chart.
    script_retry("$kubeconfig kubectl -n kube-system get deploy traefik", timeout => 180, retry => 30, delay => 6);
    assert_script_run("$kubeconfig kubectl -n kube-system rollout status deploy/traefik --timeout=180s", timeout => 200);

    # Resolve the chart reference; the helper supports URLs, OCI references, and local chart paths.
    my $chart = helm_get_chart($helm_chart);

    # Build image override options from CONTAINER_IMAGE_TO_TEST and the derived HELM_VALUES_IMAGE_PATH.
    my ($set_options, $helm_options) = helm_configure_values(get_var('HELM_CONFIG'), split_image_registry => 0);

    # Enable the MCP server subchart as required by the Trento rebuild validation scope.
    $set_options .= ' --set trento-mcp-server.enabled=true';

    # The documented K3s deployment disables Prometheus in this lightweight single-node setup.
    $set_options .= ' --set prometheus.enabled=false';

    # Configure the Trento Web origin for the local test deployment.
    $set_options .= ' --set-string global.trentoWeb.origin=' . _shell_quote($trento_server_hostname);

    # Configure the Trento admin password from an openQA variable.
    $set_options .= ' --set-string trento-web.adminUser.password=' . _shell_quote($admin_password);

    # Install or update Trento Server with the rebuilt image injected through Helm values.
    # k3s installs Traefik and its CRDs asynchronously; even after the waits above the API
    # discovery can briefly miss the Middleware kind while Traefik stabilizes, so retry the
    # (idempotent) helm install. The race fails during manifest build before any release is
    # created, so a retry starts clean.
    my $helm_cmd = join(' ',
        $kubeconfig,
        'helm upgrade --install',
        $set_options,
        _shell_quote($helm_release),
        _shell_quote($chart),
        $helm_options);
    script_retry($helm_cmd, timeout => 900, retry => 5, delay => 15);

    # helm upgrade --install returns as soon as the objects are rendered, so the pods may not
    # exist yet. kubectl wait --all returns immediately (falsely succeeding) when it matches
    # zero pods, so first block on every Deployment and StatefulSet created by the chart
    # finishing its rollout; that guarantees their pods exist before the readiness wait below.
    assert_script_run(
        "$kubeconfig bash -c 'for w in \$(kubectl get deploy,statefulset -o name); do kubectl rollout status \"\$w\" --timeout=900s; done'",
        timeout => 930);

    # Wait until every pod in the current namespace reports Ready.
    assert_script_run("$kubeconfig kubectl wait --for=condition=Ready pods --all --timeout=900s", timeout => 930);

    # Record the Helm release status after installation.
    assert_script_run("$kubeconfig helm status " . _shell_quote($helm_release), timeout => 120);

    # Web/Wanda/login are validated through the Traefik ingress. Only the MCP health port
    # (8080) is not exposed by any Service/ingress, so it is curled on the pod IP. The test
    # runs on the k3s node itself, where the pod network (10.42.x.x) is routable.
    my $mcp_pod_ip = script_output("$kubeconfig kubectl get pod -l app.kubernetes.io/name=mcp-server -o jsonpath='{.items[0].status.podIP}'");
    my $trento_mcp_url = "http://$mcp_pod_ip:$trento_mcp_health_port";

    # Wait until the ingress actually answers; Traefik may need a moment to program the
    # routes after the pods report Ready.
    script_retry("curl -sS -o /dev/null " . _shell_quote("$trento_ingress_url/api/readyz"), timeout => 120, retry => 30, delay => 5);

    # Trento Web must report readiness after the stack is up.
    validate_script_output('curl -sS ' . _shell_quote("$trento_ingress_url/api/readyz"), qr/"ready":true/);

    # Trento Web health must confirm that the database connection is working.
    validate_script_output('curl -sS ' . _shell_quote("$trento_ingress_url/api/healthz"), qr/"database":"pass"/);

    # Trento Wanda must report readiness after the stack is up. The /wanda prefix is stripped
    # by the chart's Traefik middleware before reaching the Wanda service.
    validate_script_output('curl -sS ' . _shell_quote("$trento_ingress_url/wanda/api/readyz"), qr/"ready":true/);

    # Trento Wanda health must confirm that the database connection is working.
    validate_script_output('curl -sS ' . _shell_quote("$trento_ingress_url/wanda/api/healthz"), qr/"database":"pass"/);

    # The MCP server liveness endpoint must report the server status.
    # The chart's image name is "mcp-server-trento", which is the name reported by /livez.
    validate_script_output('curl -sS ' . _shell_quote("$trento_mcp_url/livez"), qr/"name":"mcp-server-trento".*"status":"up"/);

    # The MCP server readiness endpoint must report itself plus Wanda and Web as up.
    validate_script_output('curl -sS ' . _shell_quote("$trento_mcp_url/readyz"), qr/"mcp-server":\{"status":"up".*"wanda-api":\{"status":"up".*"web-api":\{"status":"up"/);

    # Login must return a successful HTTP status; curl -f makes 4xx/5xx responses fail the test.
    my $login_payload = '{"username":"' . _json_escape($admin_user) . '","password":"' . _json_escape($admin_password) . '"}';
    assert_script_run(
        'curl -fsS '
          . _shell_quote("$trento_ingress_url/api/session")
          . ' -H '
          . _shell_quote('Accept: application/json')
          . ' -H '
          . _shell_quote('Content-Type: application/json')
          . ' --data-raw '
          . _shell_quote($login_payload),
        timeout => 120);
}

sub post_fail_hook {
    # Collect Kubernetes state when the deployment or validation fails.
    my ($self) = @_;
    my $kubeconfig = 'KUBECONFIG=/etc/rancher/k3s/k3s.yaml';

    # Show pod state even if kubectl itself exits non-zero during failure handling.
    record_info('Pods', script_output("$kubeconfig kubectl get pods -A -o wide", proceed_on_failure => 1));

    # Upload generic k8s logs/events using the existing container helper.
    gather_k8s_logs();
}

sub test_flags {
    return {fatal => 0};
}
1;
