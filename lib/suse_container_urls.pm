# SUSE's openQA tests
#
# Copyright © 2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Database for URLs of docker images to be tested
# Maintainer: Fabian Vogt <fvogt@suse.com>

package suse_container_urls;

use base Exporter;
use Exporter;

use strict;
use warnings;
use testapi;
use version_utils qw(is_sle is_opensuse is_tumbleweed is_leap);

our @EXPORT = qw(
  get_suse_container_urls
);

# Returns a tuple of image urls and their matching released "stable" counterpart.
# If empty, no images available.
sub get_suse_container_urls {
    my $version    = get_required_var('VERSION');
    my $dotversion = $version =~ s/-SP/./r;         # 15 -> 15, 15-SP1 -> 15.1
    $dotversion = "${dotversion}.0" if $dotversion !~ /\./;    # 15 -> 15.0

    my @image_names  = ();
    my @stable_names = ();
    if (is_sle(">=12-sp3") && is_sle('<15')) {
        my $lowerversion  = lc $version;
        my $nodashversion = $version =~ s/-sp/sp/ir;
        # No aarch64 image
        if (!check_var('ARCH', 'aarch64')) {
            push @image_names,  "registry.suse.de/suse/sle-${lowerversion}/docker/update/cr/images/suse/sles${nodashversion}";
            push @stable_names, "registry.suse.com/suse/sles${nodashversion}";
        }
    }
    elsif (is_sle(">=15")) {
        my $lowerversion = lc $version;
        if (!check_var('ARCH', 'aarch64')) {
            push @image_names,  "registry.suse.de/suse/sle-${lowerversion}/update/cr/images/suse/sle15:${dotversion}";
            push @stable_names, "registry.suse.com/suse/sle15:${dotversion}";
        }
    }
    elsif (is_tumbleweed && (check_var('ARCH', 'i586') || check_var('ARCH', 'x86_64'))) {
        push @image_names,  "registry.opensuse.org/opensuse/factory/totest/containers/opensuse/tumbleweed";
        push @stable_names, "docker.io/opensuse/tumbleweed";
    }
    elsif (is_tumbleweed && check_var('ARCH', 'aarch64')) {
        push @image_names,  "registry.opensuse.org/opensuse/factory/arm/totest/containers/opensuse/tumbleweed";
        push @stable_names, "docker.io/opensuse/tumbleweed";
    }
    elsif (is_tumbleweed && check_var('ARCH', 'ppc64le')) {
        push @image_names,  "registry.opensuse.org/opensuse/factory/powerpc/totest/containers/opensuse/tumbleweed";
        push @stable_names, "docker.io/opensuse/tumbleweed";
    }
    elsif (is_leap(">15.0") && check_var('ARCH', 'x86_64')) {
        push @image_names,  "registry.opensuse.org/opensuse/leap/${version}/images/totest/containers/opensuse/leap:${version}";
        push @stable_names, "docker.io/opensuse/leap:${version}";
    }
    elsif (is_leap(">15.0") && (check_var('ARCH', 'aarch64') || check_var('ARCH', 'ppc64le'))) {
        # No image set up yet :-(
    }
    elsif (is_sle("<=12-sp2")) {
        # No images for old SLE
    }
    else {
        die("Unknown combination of distro/arch.");
    }

    return (\@image_names, \@stable_names);
}
