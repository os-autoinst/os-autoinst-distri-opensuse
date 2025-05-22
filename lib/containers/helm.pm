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

our @EXPORT = qw(helm_supported_os helm_get_chart helm_configure_values helm_install_chart);

=head2 helm_supported_os
Check if the current OS is supported for Helm chart testing
=cut

sub helm_supported_os {
    my ($version, $sp, $host_distri) = get_os_release;
    # Skip HELM tests on SLES <15-SP3 and on PPC, where k3s is not available
    return if (!($host_distri eq "sles" && $version == 15 && $sp >= 3) || is_ppc64le);
    die "helm tests only work on k3s" unless (check_var('CONTAINER_RUNTIMES', 'k3s'));
}

=head2 helm_get_chart
Download chart from URL and prepare it
=cut

sub helm_get_chart {
    my ($helm_chart) = @_;
    # $helm_chart should be a full URL to a helm chart

    # Pull helm chart, if it is a http file
    if ($helm_chart =~ m!^https?://!) {
        my ($url, $path) = split(/#/, $helm_chart, 2);    # split extracted folder path, if present
        assert_script_run("curl -sSL --retry 3 --retry-delay 30 $url | tar -zxf -");
        $helm_chart = $path ? "./$path" : ".";
    }
    return $helm_chart;
}

=head2 helm_configure_values
Configure values from a values file
=cut

sub helm_configure_values {
    my ($helm_values) = @_;
    # $helm_values should be a URL to a values.yml file

    # Pull helm values file if defined
    assert_script_run("curl -sSL --retry 3 --retry-delay 30 -o myvalue.yaml $helm_values") if ($helm_values);

    # Configure Registry, Image repository and Image tag
    my $full_registry_path = get_required_var('HELM_FULL_REGISTRY_PATH');
    my $set_options = "--set global.imageRegistry=$full_registry_path";
    if (my $image = get_var('CONTAINER_IMAGE_TO_TEST')) {
        my ($repository, $tag) = split(':', $image, 2);
        $set_options = "--set global.imageRegistry=$full_registry_path --set app.image.repository=$repository --set app.image.tag=$tag";
    }

    # Enable debug logs
    my $helm_options = "--debug";

    # Use the provided helm values if defined
    $helm_options = "-f myvalue.yaml $helm_options" if ($helm_values);
    return ($set_options, $helm_options);
}

=head2 helm_install_chart
Install helm chart with settings and values
=cut

sub helm_install_chart {
    my ($chart, $values, $release_name) = @_;
    # e.g. helm_install_chart("url to chart", "url to values")

    my $helm_chart = helm_get_chart($chart);
    my ($set_options, $helm_options) = helm_configure_values($values);

    # Install the helm chart
    script_retry("helm pull $helm_chart", timeout => 300, retry => 6, delay => 60) if ($helm_chart =~ m!^oci://!);
    assert_script_run("helm install $set_options $release_name $helm_chart $helm_options", timeout => 300);
    script_run("helm list");
}

1;
