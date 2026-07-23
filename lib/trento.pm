# SUSE's openQA tests
#
# SPDX-FileCopyrightText: SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Helper functions for Trento tests
# Maintainer: Trento team <trento-developers@suse.com>

package trento;

use base Exporter;
use Exporter;
use strict;
use warnings;
use testapi;
use package_utils 'install_package';
use utils qw(file_content_replace script_retry);

our @EXPORT = qw(
  setup_trento_ingress_tls
  trento_helm_set_options
  trento_helm_values_image_path_from_image
  trento_shell_quote
  trento_wait_for_crd_established
);

sub _shell_quote {
    my ($value) = @_;

    $value =~ s/'/'\\''/g;

    return "'$value'";
}

sub trento_shell_quote {
    return _shell_quote(@_);
}

sub _image_name_from_reference {
    my ($image) = @_;

    $image =~ s/(?:[:@][^\/:@]+)$//;
    $image =~ s{.*/}{};

    return $image;
}

sub trento_helm_values_image_path_from_image {
    my ($image) = @_;
    my $image_name = _image_name_from_reference($image);
    my %helm_values_image_path = (
        'trento-web' => 'trento-web',
        'trento-wanda' => 'trento-wanda',
        'trento-checks' => 'trento-wanda.checks',
        'mcp-server-trento' => 'trento-mcp-server');

    die "No Helm values mapping found for image: $image_name"
      unless $helm_values_image_path{$image_name};

    return $helm_values_image_path{$image_name};
}

sub trento_helm_set_options {
    my (%args) = @_;

    my @set = (
        'trento-mcp-server.enabled=true',
        'prometheus.enabled=false',
    );
    my @set_string = (
        "global.trentoWeb.origin=$args{hostname}",
        "trento-web.adminUser.password=$args{admin_password}",
    );

    my $options = '';
    $options .= " --set $_" for @set;
    $options .= ' --set-string ' . _shell_quote($_) for @set_string;

    return $options;
}

sub trento_wait_for_crd_established {
    my (%args) = @_;

    script_retry(
        join(' ',
            'env',
            $args{kubeconfig},
            'kubectl get crd',
            _shell_quote($args{name}),
            q{-o go-template='{{range .status.conditions}}{{if eq .type "Established"}}{{.status}}{{end}}{{end}}' 2>/dev/null | grep -q True}),
        timeout => $args{timeout} // 30,
        retry => $args{retry} // 60,
        delay => $args{delay} // 6);
}

sub _install_cert_manager {
    my (%args) = @_;

    script_retry(
        join(' ',
            'env',
            $args{kubeconfig},
            'helm upgrade --install cert-manager oci://quay.io/jetstack/charts/cert-manager',
            '--version', _shell_quote($args{version}),
            '--namespace cert-manager',
            '--create-namespace',
            '--set crds.enabled=true',
            '--wait',
            '--timeout=300s'),
        timeout => 600,
        retry => 3,
        delay => 30);
    trento_wait_for_crd_established(kubeconfig => $args{kubeconfig}, name => 'certificates.cert-manager.io');
    trento_wait_for_crd_established(kubeconfig => $args{kubeconfig}, name => 'clusterissuers.cert-manager.io');
    assert_script_run("$args{kubeconfig} kubectl wait --for=condition=available --timeout=300s --all deployments -n cert-manager", timeout => 330);
}

sub _checkout_helm_charts_repository {
    my (%args) = @_;

    assert_script_run('rm -rf ' . _shell_quote($args{target_dir}));
    script_retry(
        join(' ',
            'git clone --depth 1 --filter=blob:none --no-checkout',
            _shell_quote($args{repository}),
            _shell_quote($args{target_dir})),
        timeout => 300,
        retry => 3,
        delay => 30);
    assert_script_run(
        join(' ',
            'git -C', _shell_quote($args{target_dir}),
            'sparse-checkout set --no-cone hack/cert-manager .github/scripts/helm-upgrade-smoke-test.sh',
            '&& git -C', _shell_quote($args{target_dir}),
            'fetch --depth 1 origin', _shell_quote($args{ref}),
            '&& git -C', _shell_quote($args{target_dir}),
            'checkout --detach FETCH_HEAD'),
        timeout => 300);
    record_info('Helm charts', script_output('git -C ' . _shell_quote($args{target_dir}) . ' --no-pager log -1 --oneline'));
}

sub _prepare_tls_termination_files {
    my (%args) = @_;

    my $cert_manager_dir = "$args{helm_charts_dir}/hack/cert-manager";
    my $issuer_file = '/root/trento-selfsigned-issuer.yaml';
    my $certificate_file = '/root/trento-certificate.yaml';
    my $values_file = '/root/trento-ingress-tls-values.yaml';

    assert_script_run('cp ' . _shell_quote("$cert_manager_dir/selfsigned-issuer.yaml") . ' ' . _shell_quote($issuer_file));
    assert_script_run('cp ' . _shell_quote("$cert_manager_dir/certificate.tpl.yaml") . ' ' . _shell_quote($certificate_file));
    assert_script_run('cp ' . _shell_quote("$cert_manager_dir/override-values.tpl.yaml") . ' ' . _shell_quote($values_file));

    file_content_replace($certificate_file,
        '\$\{TRENTO_NAMESPACE\}' => $args{namespace},
        '\$\{TRENTO_WEB_ORIGIN\}' => $args{hostname},
        letsencrypt-production => 'selfsigned-issuer');
    file_content_replace($values_file,
        '\$\{TRENTO_WEB_ORIGIN\}' => $args{hostname},
        letsencrypt-production => 'selfsigned-issuer');

    return ($issuer_file, $certificate_file, $values_file);
}

sub setup_trento_ingress_tls {
    my (%args) = @_;

    my $cert_manager_version = get_var('CERT_MANAGER_VERSION', 'v1.20.2');
    my $helm_charts_repo = get_var('TRENTO_HELM_CHARTS_REPO', 'https://github.com/trento-project/helm-charts.git');
    my $helm_charts_ref = get_var('TRENTO_HELM_CHARTS_REF', 'main');
    my $helm_charts_dir = '/root/trento-helm-charts';
    my $smoke_test_script = "$helm_charts_dir/.github/scripts/helm-upgrade-smoke-test.sh";

    install_package('git', timeout => 600);

    _install_cert_manager(kubeconfig => $args{kubeconfig}, version => $cert_manager_version);
    _checkout_helm_charts_repository(
        repository => $helm_charts_repo,
        ref => $helm_charts_ref,
        target_dir => $helm_charts_dir);
    assert_script_run('test -f ' . _shell_quote($smoke_test_script));

    my ($issuer_file, $certificate_file, $tls_values_file) = _prepare_tls_termination_files(
        helm_charts_dir => $helm_charts_dir,
        hostname => $args{hostname},
        namespace => $args{namespace});
    assert_script_run("$args{kubeconfig} kubectl apply -f " . _shell_quote($issuer_file), timeout => 120);
    assert_script_run("$args{kubeconfig} kubectl apply -f " . _shell_quote($certificate_file), timeout => 120);
    assert_script_run("$args{kubeconfig} kubectl wait --for=condition=Ready certificate/trento-certificate --timeout=180s", timeout => 200);

    return ($tls_values_file, $smoke_test_script);
}

1;
