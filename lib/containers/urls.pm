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
use version_utils qw(is_sle is_opensuse is_tumbleweed is_leap is_microos is_sle_micro);

our @EXPORT = qw(
  get_opensuse_registry_prefix
  get_suse_container_urls
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

    my @image_names  = ();
    my @stable_names = ();
    if (is_sle(">=12-sp3", $version) && is_sle('<15', $version)) {
        my $lowerversion  = lc $version;
        my $nodashversion = $version =~ s/-sp/sp/ir;
        # No aarch64 image
        if (!check_var('ARCH', 'aarch64')) {
            push @image_names,  "registry.suse.de/suse/sle-${lowerversion}/docker/update/cr/totest/images/suse/sles${nodashversion}";
            push @stable_names, "registry.suse.com/suse/sles${nodashversion}";
        }
    }
    elsif (is_sle(">=15", $version)) {
        my $lowerversion = lc $version;
        push @image_names,  "registry.suse.de/suse/sle-${lowerversion}/update/cr/totest/images/suse/sle15:${dotversion}";
        push @stable_names, "registry.suse.com/suse/sle15:${dotversion}";
    }
    elsif (is_sle_micro) {
        push @image_names,
          "registry.suse.com/suse/sle15:15.0",
          "registry.suse.com/suse/sle15:15.1",
          "registry.suse.com/suse/sle15:15.2",
          "registry.suse.com/suse/sle15:15.3";
    }
    elsif (is_tumbleweed || is_microos("Tumbleweed")) {
        push @image_names,  "registry.opensuse.org/" . get_opensuse_registry_prefix . "opensuse/tumbleweed";
        push @stable_names, "registry.opensuse.org/opensuse/tumbleweed";
    }
    elsif ($version eq "Jump:15.2") {
        # Jump 15.2 uses opensuse/leap:15.2.1, just hardcode this special case
        push @image_names,  "registry.opensuse.org/opensuse/jump/15.2/images/totest/containers/opensuse/leap:15.2.1";
        push @stable_names, "registry.opensuse.org/opensuse/leap:15.2.1";
    }
    elsif ((is_leap(">15.0") || is_microos(">15.0")) && check_var('ARCH', 'x86_64')) {
        push @image_names,  "registry.opensuse.org/opensuse/leap/${version}/images/totest/containers/opensuse/leap:${version}";
        push @stable_names, "registry.opensuse.org/opensuse/leap:${version}";
    }
    elsif ((is_leap(">15.0") || is_microos(">15.0")) && (check_var('ARCH', 'aarch64') || check_var('ARCH', 'arm'))) {
        push @image_names,  "registry.opensuse.org/opensuse/leap/${version}/arm/images/totest/containers/opensuse/leap:${version}";
        push @stable_names, "registry.opensuse.org/opensuse/leap:${version}";
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

    return (\@image_names, \@stable_names);
}
