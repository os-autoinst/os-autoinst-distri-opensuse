# Copyright 2026 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: Define and export global variables needed for Element3 tests.
#
# Maintainer: unified-core@suse.com, ldevulder@suse.com

use base qw(opensusebasetest);
use testapi;
use serial_terminal qw(select_serial_terminal);

=head2 get_values

 get_values( filelist => <value>, regex => <value> );

Get values from the list of files <filelist> based on defined regex.

=cut

sub get_values {
    my (%args) = @_;

    return ($&, $1, $2) if ($args{filelist} =~ m/$args{regex}/);
}

=head2 get_uri

 get_uri( file => <value>, regex => <value> );

Get URI from defined file based on defined regex.

=cut

sub get_uri {
    my (%args) = @_;

    my $out = script_output("curl -s $args{file}");
    return ($1) if ($out =~ m/$args{regex}/);
}

sub run {
    my $arch = get_required_var('ARCH');
    my $k8s = get_required_var('K8S');
    my $kernel = 'uc-base-os-kernel-' . get_required_var('KERNEL_TYPE') . '-' . get_required_var('VERSION');
    my $totest_path = get_required_var('TOTEST_PATH');
    my $uc_version = get_required_var('UC_VERSION');

    # No GUI, easier and quicker to use the serial console
    select_serial_terminal();

    # Get the list of files available on TOTEST_PATH
    # NOTE:
    # - '/' is mandatory at the end of the path! Otherwise nothing will be outputted
    # - 'sort -ur' is here to be able to get the (sorted) latest version first
    my $files_list = script_output("curl -s ${totest_path}/containers/ | sed -n '/alt=\"\\[\\([[:blank:]]*\\|TXT\\)\\]/s/.*href=\"\\(.*\\)\">.*/\\1/gp' | sort -ur");

    # Export RELEASE_MANIFEST_URI
    my $manifest_regex = "suse-uc-release-manifest-${uc_version}_${k8s}_\(.*\)-\(.*\).${arch}-.*.registry.txt";
    my ($file, $version, $build) = get_values(filelist => ${files_list}, regex => ${manifest_regex});
    my $k8s_version = $version;
    my $release_manifest_uri = get_uri(file => "${totest_path}/containers/${file}", regex => "pull\\s+\(.*:${uc_version}_${k8s}_${k8s_version}-${build}\)");
    set_var('RELEASE_MANIFEST_URI', "$release_manifest_uri");

    # Export SYSEXT_IMAGES_TO_TEST
    my $elemental3ctl_regex = "suse-uc-elemental3ctl-${uc_version}_\(.*\)-\(.*\).${arch}-.*.registry.txt";
    ($file, $version, $build) = get_values(filelist => ${files_list}, regex => ${elemental3ctl_regex});
    my $elemental3ctl_uri = get_uri(file => "${totest_path}/containers/${file}", regex => "pull\\s+\(.*:${uc_version}_${version}-${build}\)");

    my $k8s_regex = "suse-uc-${k8s}-${k8s_version}_\(.*\)-\(.*\).${arch}-.*.registry.txt";
    ($file, $version, $build) = get_values(filelist => ${files_list}, regex => ${k8s_regex});
    my $k8s_uri = get_uri(file => "${totest_path}/containers/${file}", regex => "pull\\s+\(.*:${k8s_version}_${version}-${build}\)");
    set_var('SYSEXT_IMAGES_TO_TEST', "${elemental3ctl_uri},${k8s_uri}");

    # Export CONTAINER_IMAGE_TO_TEST
    my $kernel_regex = "${kernel}-\(.*\).${arch}-.*.registry.txt";
    ($file, $build) = get_values(filelist => ${files_list}, regex => ${kernel_regex});
    my $container_uri = get_uri(file => "${totest_path}/containers/${file}", regex => "pull\\s+\(.*:" . get_required_var('VERSION') . "-${build}\)");
    set_var('CONTAINER_IMAGE_TO_TEST', "$container_uri");

    # Export REPO_TO_TEST
    set_var('REPO_TO_TEST', "$totest_path/standard");
}

sub test_flags {
    return {fatal => 1};
}

1;
