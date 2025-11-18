# SUSE's openQA tests
#
# Copyright 2018-2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Database for URLs of container images to be tested
# Maintainer: Fabian Vogt <fvogt@suse.com>, qa-c team <qa-c@suse.de>

package containers::urls;

use base Exporter;
use Exporter;

use strict;
use warnings;
use testapi;
use Utils::Architectures;
use version_utils qw(is_sle is_opensuse is_tumbleweed is_leap is_microos is_sle_micro is_released);

our @EXPORT = qw(
  get_opensuse_registry_prefix
  get_3rd_party_images
  get_image_uri
);

# Returns a string which should be prepended to every pull from registry.opensuse.org.
sub get_opensuse_registry_prefix {
    # Can't use is_tumbleweed as that would also return true for stagings
    if (check_var("VERSION", "Tumbleweed") && (is_i586 || is_x86_64)) {
        return "opensuse/factory/totest/containers/";
    }
    elsif (check_var("VERSION", "Tumbleweed") && (is_aarch64 || is_arm)) {
        return "opensuse/factory/arm/totest/containers/";
    }
    elsif (check_var("VERSION", "Tumbleweed") && is_ppc64le) {
        return "opensuse/factory/powerpc/totest/containers/";
    }
    elsif (check_var("VERSION", "Tumbleweed") && is_s390x) {
        return "opensuse/factory/zsystems/totest/containers/";
    }
    elsif (get_var("VERSION") =~ /^Staging:(?<letter>.)$/ && (is_i586 || is_x86_64)) {
        # Tumbleweed letter staging
        my $lowercaseletter = lc $+{letter};
        return "opensuse/factory/staging/${lowercaseletter}/images/";
    }
    else {
        die("Unknown combination of distro/arch.");
    }
}

my %sles_containers = (
    '12-SP5' => {
        released => sub { 'registry.suse.com/suse/ltss/sle12.5/sles12sp5' },
        totest => sub {
            'registry.suse.de/suse/containers/sle-server/12-sp5/containers/suse/ltss/sle12.5/sles12sp5';
        },
        available_arch => ['x86_64', 'aarch64', 'ppc64le', 's390x']
    },
    '15-SP4' => {
        released => sub { 'registry.suse.com/suse/ltss/sle15.4/sle15:15.4' },
        totest => sub {
            'registry.suse.de/suse/sle-15-sp4/update/bci/images/suse/ltss/sle15.4/sle15:latest';
        },
        available_arch => ['x86_64', 'aarch64', 'ppc64le', 's390x']
    },
    '15-SP5' => {
        released => sub { 'registry.suse.com/suse/ltss/sle15.5/sle15:15.5' },
        totest => sub {
            'registry.suse.de/suse/sle-15-sp5/update/bci/images/suse/ltss/sle15.5/sle15:latest';
        },
        available_arch => ['x86_64', 'aarch64', 'ppc64le', 's390x']
    },
    '15-SP6' => {
        released => sub { 'registry.suse.com/suse/sle15:15.6' },
        totest => sub {
            'registry.suse.de/suse/sle-15-sp6/update/cr/totest/images/suse/sle15:15.6';
        },
        available_arch => ['x86_64', 'aarch64', 'ppc64le', 's390x']
    },
    '15-SP7' => {
        released => sub { 'registry.suse.com/suse/sle15:15.7' },
        totest => sub {
            'registry.suse.de/suse/sle-15-sp7/ga/test/containers/suse/sle15:15.7';
        },
        available_arch => ['x86_64', 'aarch64', 'ppc64le', 's390x']
    }
);

my %opensuse_containers = (
    Tumbleweed => {
        released => sub { 'registry.opensuse.org/opensuse/tumbleweed' },
        totest => sub {
            'registry.opensuse.org/' . get_opensuse_registry_prefix . 'opensuse/tumbleweed';
        },
        available_arch => ['x86_64', 'aarch64', 'ppc64le', 's390x', 'arm', 'riscv64']
    },
    '15.4' => {
        released => sub { 'registry.opensuse.org/opensuse/leap:15.4' },
        totest => sub {
            my $arch = shift;
            if (grep { $_ eq $arch } qw/x86_64 aarch64 ppc64le s390x/) {
                'registry.opensuse.org/opensuse/leap/15.4/images/totest/containers/opensuse/leap:15.4';
            } elsif ($arch eq 'arm') {
                'registry.opensuse.org/opensuse/leap/15.4/arm/images/totest/containers/opensuse/leap:15.4';
            }
        },
        available_arch => ['x86_64', 'aarch64', 'ppc64le', 's390x', 'arm']
    },
    '15.5' => {
        released => sub { 'registry.opensuse.org/opensuse/leap:15.5' },
        totest => sub {
            my $arch = shift;
            if (grep { $_ eq $arch } qw/x86_64 aarch64 ppc64le s390x/) {
                'registry.opensuse.org/opensuse/leap/15.5/images/totest/containers/opensuse/leap:15.5';
            } elsif ($arch eq 'arm') {
                'registry.opensuse.org/opensuse/leap/15.5/arm/images/totest/containers/opensuse/leap:15.5';
            }
        },
        available_arch => ['x86_64', 'aarch64', 'ppc64le', 's390x', 'arm']
    },
    '15.6' => {
        released => sub { 'registry.opensuse.org/opensuse/leap:15.6' },
        totest => sub {
            my $arch = shift;
            if (grep { $_ eq $arch } qw/x86_64 aarch64 ppc64le s390x/) {
                'registry.opensuse.org/opensuse/leap/15.6/images/totest/containers/opensuse/leap:15.6';
            } elsif ($arch eq 'arm') {
                'registry.opensuse.org/opensuse/leap/15.6/arm/images/totest/containers/opensuse/leap:15.6';
            }
        },
        available_arch => ['x86_64', 'aarch64', 'ppc64le', 's390x', 'arm']
    }
);

our %images_list = (
    sle => {%sles_containers},
    'sle-micro' => {%sles_containers},    # Note: SLEM runs tests on SLES containers using the CONTAINER_IMAGE_VERSIONS setting.
    opensuse => {%opensuse_containers},
    microos => {%opensuse_containers},
    'leap-micro' => {%opensuse_containers}
);

sub supports_image_arch {
    my ($distri, $version, $arch) = @_;
    (grep { $_ eq $arch } @{$images_list{$distri}{$version}{available_arch}}) ? 1 : 0;
}

sub get_3rd_party_images {
    my $registry = get_var('REGISTRY', 'docker.io');
    my @images = (
        "registry.opensuse.org/opensuse/tumbleweed",
        "$registry/library/alpine"
    );

    push @images, (
        "registry.opensuse.org/opensuse/leap",
        "$registry/library/debian",
        # Temporarily disabled as it needs x86-64-v2
        # "quay.io/centos/centos:stream9"
    ) unless (is_riscv);

    # Following images are not available on 32-bit arm
    push @images, (
        "registry.access.redhat.com/ubi8/ubi",
        "registry.access.redhat.com/ubi8/ubi-minimal",
        "registry.access.redhat.com/ubi8/ubi-micro",
        "registry.access.redhat.com/ubi8/ubi-init"
    ) unless (is_arm || is_riscv);

    # - ubi9 images require z14+ s390x machine, they are not ready in OSD yet.
    #     on z13: "Fatal glibc error: CPU lacks VXE support (z14 or later required)".
    # - ubi9 images require power9+ machine.
    #     on Power8: "Fatal glibc error: CPU lacks ISA 3.00 support (POWER9 or later required)"
    # - ubi9 images require x86_64-v2, which needs certain cpu flags
    push @images, (
        "registry.access.redhat.com/ubi9/ubi",
        "registry.access.redhat.com/ubi9/ubi-minimal",
        "registry.access.redhat.com/ubi9/ubi-micro",
        "registry.access.redhat.com/ubi9/ubi-init",
        "registry.access.redhat.com/ubi10/ubi",
        "registry.access.redhat.com/ubi10/ubi-minimal",
        "registry.access.redhat.com/ubi10/ubi-micro",
        "registry.access.redhat.com/ubi10/ubi-init"
    ) unless (is_arm || is_s390x || is_ppc64le || is_riscv || !is_x86_64_v2);

    push @images, (
        "$registry/library/ubuntu"
    ) if (is_x86_64);

    return (\@images);
}

# Return URI of the container image to be tested. It will:
# - Be configured by the CONTAINER_IMAGE_TO_TEST variable.
# - Be configured by the distri, version and arch parameter.
# - Be determined by the running OS.
# - Die otherwise.
sub get_image_uri {
    my (%args) = @_;
    $args{version} //= get_required_var('VERSION');
    $args{arch} //= get_required_var('ARCH');
    $args{distri} //= get_required_var('DISTRI');
    $args{released} //= !get_var('CONTAINERS_UNTESTED_IMAGES');

    $args{version} =~ s/^Staging:(?<letter>.)$/Tumbleweed/ if is_tumbleweed || is_microos("Tumbleweed");

    my $url = get_var('CONTAINER_IMAGE_TO_TEST');
    return $url if ($url);

    my $type = $args{released} ? 'released' : 'totest';
    if (supports_image_arch($args{distri}, $args{version}, $args{arch})) {
        return $images_list{$args{distri}}{$args{version}}{$type}->($args{arch});
    }

    die "Cannot find container image for ($args{distri},$args{version},$args{arch}) or missing CONTAINER_IMAGE_TO_TEST variable.";
}

1;
