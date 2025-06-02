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
Usage: helm_configure_values($helm_values)
$helm_values should be a URL to a valid values.yml file. e.g. https://github.com/grafana/helm-charts/blob/main/charts/grafana/values.yaml
Returns the installation ad-hoc options ($set_options) and the options from the values file ($helm_options).
=cut

sub helm_configure_values {
    my ($helm_values) = @_;

    # Pull helm values file if defined
    assert_script_run("curl -sSL --retry 3 --retry-delay 30 -o myvalue.yaml $helm_values") if ($helm_values);

    # Configure Registry, Image repository and Image tag
    my $full_registry_path = get_var('HELM_FULL_REGISTRY_PATH');
    my $set_options = "";

    if ($full_registry_path ne "") {
        $set_options = "--set global.imageRegistry=$full_registry_path";    # Only necessary if the chart uses non-publicly available images.
    }

    if (my $image = get_var('CONTAINER_IMAGE_TO_TEST')) {
        my ($repository, $tag) = split(':', $image, 2);

        # Add space before appending if $set_options already has content
        $set_options .= " " if $set_options ne "";
        $set_options .= "--set app.image.repository=$repository --set app.image.tag=$tag";
    }

    # Enable debug logs
    my $helm_options = "--debug";

    # Use the provided helm values if defined
    $helm_options = "-f myvalue.yaml $helm_options" if ($helm_values);
    return ($set_options, $helm_options);
}

=head2 helm_install_chart
Installs a helm chart with settings, values and a release name. 
Usage: helm_install_chart("URL_TO_CHART", "URL_TO_VALUES_FILE", "RELEASE_NAME")
=cut

sub helm_install_chart {
    my ($chart, $values, $release_name) = @_;

    my $helm_chart = helm_get_chart($chart);
    my ($set_options, $helm_options) = helm_configure_values($values);

    # Install the helm chart
    script_retry("helm pull $helm_chart", timeout => 300, retry => 6, delay => 60) if ($helm_chart =~ m!^oci://!);
    assert_script_run("helm install $set_options $release_name $helm_chart $helm_options", timeout => 300);
    script_run("helm list");
}

1;
