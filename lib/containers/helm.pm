# SUSE's openQA tests
#
# Copyright 2020-2025 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Basic functionallity for testing Helm Charts
# Maintainer: qac team <qa-c@suse.de>

package containers::helm;

use base Exporter;
use Exporter;
use strict;
use warnings;
use testapi;
use utils qw(script_retry);
use version_utils qw(get_os_release);
use Utils::Architectures qw(is_ppc64le);

our @EXPORT = qw(helm_is_supported helm_get_chart helm_configure_values helm_install_chart);

=head2 helm_is_supported
Checks if the current OS is supported for Helm chart testing.
Returns True if the OS and Architecture are supported.
=cut

sub helm_is_supported {
    my ($version, $sp, $host_distri) = get_os_release;
    # Skip HELM tests on SLES <15-SP3 and on PPC, where k3s is not available
    return ($host_distri eq "sles" && $version == 15 && $sp >= 3) && !is_ppc64le;
    die "helm tests only work on k3s" unless (check_var('CONTAINER_RUNTIMES', 'k3s'));
}

=head2 helm_get_chart
Downloads a chart from a URL. 
Usage: helm_get_chart($helm_chart)
$helm_chart should be a full URL to a helm chart, e.g. oci://dp.apps.rancher.io/charts/grafana
Returns the name of the helm chart.
=cut

sub helm_get_chart {
    my ($helm_chart) = @_;

    # Pull helm chart, if it is a http file
    if ($helm_chart =~ m!^https?://!) {
        my ($url, $path) = split(/#/, $helm_chart, 2);    # split extracted folder path, if present
        assert_script_run("curl -sSL --retry 3 --retry-delay 30 $url | tar -zxf -");
        $helm_chart = $path ? "./$path" : ".";
    }
    return $helm_chart;
}

=head2 helm_configure_values
Configure values from a values file. 
Usage: helm_configure_values($helm_values [, split_image_registry => undef ])
$helm_values should be a URL to a valid values.yml file. e.g. https://github.com/grafana/helm-charts/blob/main/charts/grafana/values.yaml
Returns the installation ad-hoc options ($set_options) and the options from the values file ($helm_options).
=cut

sub helm_configure_values {
    my ($helm_values, %args) = @_;

    # Pull helm values file if defined
    assert_script_run("curl -sSL --retry 3 --retry-delay 30 -o myvalue.yaml $helm_values") if ($helm_values);

    # Configure Registry, Image repository and Image tag
    my $full_registry_path = get_var('HELM_FULL_REGISTRY_PATH');
    my $set_options = "";

    if ($full_registry_path ne "") {
        $set_options = " --set global.imageRegistry=$full_registry_path";    # Only necessary if the chart uses non-publicly available images.
    }

    if (my $image = get_var('CONTAINER_IMAGE_TO_TEST')) {
        my ($registry, $repository, $tag);
        my $helm_values_image_path = get_required_var('HELM_VALUES_IMAGE_PATH');

        my $split_image_registry = $args{split_image_registry} // $image =~ /^registry\.suse\.(com|de)\//;
        if ($split_image_registry) {
            # split at first slash
            ($registry, my $rest) = split('/', $image, 2);
            ($repository, $tag) = split(/:/, $rest, 2);
        } else {
            ($repository, $tag) = split(/:/, $image, 2);
        }

        $tag //= 'latest';

        $set_options .= " --set $helm_values_image_path.image.repository=$repository";
        $set_options .= " --set $helm_values_image_path.image.registry=$registry" if defined $registry;
        $set_options .= " --set $helm_values_image_path.image.tag=$tag" if defined $tag;
    }

    # Enable debug logs
    my $helm_options = "--debug";

    # Use the provided helm values if defined
    $helm_options = "-f myvalue.yaml $helm_options" if ($helm_values);
    return ($set_options, $helm_options);
}

=head2 helm_install_chart
Installs a helm chart with settings, values and a release name.
Usage: helm_install_chart($chart_url, $values_url, $release_name [, split_image_registry => undef ])
=cut

sub helm_install_chart {
    my ($chart, $values, $release_name, %args) = @_;

    my $helm_chart = helm_get_chart($chart);
    my ($set_options, $helm_options) = helm_configure_values($values, split_image_registry => $args{split_image_registry});

    # Install the helm chart
    if ($helm_chart =~ m!^oci://!) {
        my $helm_chart_download_folder = "/tmp/helmchart_download";
        assert_script_run("mkdir -p $helm_chart_download_folder");
        assert_script_run("cd $helm_chart_download_folder");
        script_retry("helm pull $helm_chart", timeout => 300, retry => 6, delay => 60);
        my $tgz_file = script_output(qq{find $helm_chart_download_folder -maxdepth 1 -type f -name "*.tgz"});
        upload_logs("$tgz_file");
        assert_script_run("cd ~");
        assert_script_run("rm -rf $helm_chart_download_folder");
    }
    assert_script_run("helm install $set_options $release_name $helm_chart $helm_options", timeout => 300);
    script_run("helm list");
}

1;
