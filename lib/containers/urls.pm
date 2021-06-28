# SUSE's openQA tests
#
# Copyright © 2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Database for URLs of container images to be tested
# Maintainer: Fabian Vogt <fvogt@suse.com>

package containers::urls;

use base Exporter;
use Exporter;

use strict;
use warnings;
use testapi;
use version_utils qw(is_sle is_opensuse is_tumbleweed is_leap is_microos is_sle_micro is_released);

our @EXPORT = qw(
  get_opensuse_registry_prefix
  get_suse_container_urls
  get_3rd_party_images
);

# Returns a string which should be prepended to every pull from registry.opensuse.org.
sub get_opensuse_registry_prefix {
    # Can't use is_tumbleweed as that would also return true for stagings
    if (check_var("VERSION", "Tumbleweed") && (check_var('ARCH', 'i586') || check_var('ARCH', 'x86_64'))) {
        return "opensuse/factory/totest/containers/";
    }
    elsif (check_var("VERSION", "Tumbleweed") && (check_var('ARCH', 'aarch64') || check_var('ARCH', 'arm'))) {
        return "opensuse/factory/arm/totest/containers/";
    }
    elsif (check_var("VERSION", "Tumbleweed") && check_var('ARCH', 'ppc64le')) {
        return "opensuse/factory/powerpc/totest/containers/";
    }
    elsif (check_var("VERSION", "Tumbleweed") && check_var('ARCH', 's390x')) {
        return "opensuse/factory/zsystems/totest/containers/";
    }
    elsif (get_var("VERSION") =~ /^Staging:(?<letter>.)$/ && (check_var('ARCH', 'i586') || check_var('ARCH', 'x86_64'))) {
        # Tumbleweed letter staging
        my $lowercaseletter = lc $+{letter};
        return "opensuse/factory/staging/${lowercaseletter}/images/";
    }
    else {
        die("Unknown combination of distro/arch.");
    }
}

# Returns a tuple of image urls and their matching released "stable" counterpart.
# If empty, no images available.
sub get_suse_container_urls {
    my $version    = shift // get_required_var('VERSION');
    my $dotversion = $version =~ s/-SP/./r;                    # 15 -> 15, 15-SP1 -> 15.1
    $dotversion = "${dotversion}.0" if $dotversion !~ /\./;    # 15 -> 15.0

    my @untested_images = ();
    my @released_images = ();
    if (is_sle(">=12-sp3", $version) && is_sle('<15', $version)) {
        my $lowerversion  = lc $version;
        my $nodashversion = $version =~ s/-sp/sp/ir;
        # No aarch64 image
        if (!check_var('ARCH', 'aarch64')) {
            push @untested_images, "registry.suse.de/suse/sle-${lowerversion}/docker/update/cr/totest/images/suse/sles${nodashversion}";
            push @released_images, "registry.suse.com/suse/sles${nodashversion}";
        }
    }
    elsif (is_sle(">=15", $version) && is_released) {
        my $lowerversion = lc $version;
        # Location for maintenance builds
        push @untested_images, "registry.suse.de/suse/sle-${lowerversion}/update/cr/totest/images/suse/sle15:${dotversion}";
        push @released_images, "registry.suse.com/suse/sle15:${dotversion}";
    }
    elsif (is_sle(">=15-sp4", $version)) {
        my $lowerversion = lc $version;
        # Location for GA builds
        push @untested_images, "registry.suse.de/suse/sle-${lowerversion}/ga/test/images/suse/sle15:${dotversion}";
        push @released_images, "registry.suse.com/suse/sle15:${dotversion}";
    }
    elsif (is_sle_micro) {
        push @untested_images,
          "registry.suse.com/suse/sle15:15.0",
          "registry.suse.com/suse/sle15:15.1",
          "registry.suse.com/suse/sle15:15.2",
          "registry.suse.com/suse/sle15:15.3";
    }
    elsif (is_tumbleweed || is_microos("Tumbleweed")) {
        push @untested_images, "registry.opensuse.org/" . get_opensuse_registry_prefix . "opensuse/tumbleweed";
        push @released_images, "registry.opensuse.org/opensuse/tumbleweed";
    }
    elsif (is_leap(">=15.3")) {
        # All archs in the same location
        push @untested_images, "registry.opensuse.org/opensuse/leap/${version}/images/totest/containers/opensuse/leap:${version}";
        push @released_images, "registry.opensuse.org/opensuse/leap:${version}";
    }
    elsif ((is_leap(">15.0") || is_microos(">15.0")) && check_var('ARCH', 'x86_64')) {
        push @untested_images, "registry.opensuse.org/opensuse/leap/${version}/images/totest/containers/opensuse/leap:${version}";
        push @released_images, "registry.opensuse.org/opensuse/leap:${version}";
    }
    elsif ((is_leap(">15.0") || is_microos(">15.0")) && (check_var('ARCH', 'aarch64') || check_var('ARCH', 'arm'))) {
        push @untested_images, "registry.opensuse.org/opensuse/leap/${version}/arm/images/totest/containers/opensuse/leap:${version}";
        push @released_images, "registry.opensuse.org/opensuse/leap:${version}";
    }
    elsif (is_leap(">15.0") && check_var('ARCH', 'ppc64le')) {
        # No image set up yet :-(
    }
    elsif (is_sle("<=12-sp2", $version)) {
        # No images for old SLE
    }
    else {
        die("Unknown combination of distro/arch.");
    }

    return (\@untested_images, \@released_images);
}

sub get_3rd_party_images {
    my $ex_reg = get_var('REGISTRY', 'docker.io');
    my @images = (
        "registry.opensuse.org/opensuse/leap",
        "registry.opensuse.org/opensuse/tumbleweed",
        "$ex_reg/library/alpine",
        "$ex_reg/library/debian",
        "$ex_reg/library/fedora",
        "registry.access.redhat.com/ubi8/ubi",
        "registry.access.redhat.com/ubi8/ubi-minimal",
        "registry.access.redhat.com/ubi8/ubi-init");

    # poo#72124 Ubuntu image (occasionally) fails on s390x
    push @images, "$ex_reg/library/ubuntu" unless check_var('ARCH', 's390x');

    # Missing centos container image for s390x.
    push @images, "$ex_reg/library/centos" unless check_var('ARCH', 's390x');

    # RedHat UBI7 images are not built for aarch64
    push @images, (
        "registry.access.redhat.com/ubi7/ubi",
        "registry.access.redhat.com/ubi7/ubi-minimal",
        "registry.access.redhat.com/ubi7/ubi-init"
    ) unless (check_var('ARCH', 'aarch64') or check_var('PUBLIC_CLOUD_ARCH', 'arm64'));

    return (\@images);
}
