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

our %images_list = (
    sle => {
        '12-SP3' => {
            released => sub { 'registry.suse.com/suse/sles12sp3' },
            totest => sub {
                'registry.suse.de/suse/sle-12-sp3/docker/update/cr/totest/images/suse/sles12sp3';
            },
            available_arch => ['x86_64', 'ppc64le', 's390x']
        },
        '12-SP4' => {
            released => sub { 'registry.suse.com/suse/sles12sp4' },
            totest => sub {
                'registry.suse.de/suse/sle-12-sp4/docker/update/cr/totest/images/suse/sles12sp4';
            },
            available_arch => ['x86_64', 'ppc64le', 's390x']
        },
        '12-SP5' => {
            released => sub { 'registry.suse.com/suse/sles12sp5' },
            totest => sub {
                'registry.suse.de/suse/sle-12-sp5/docker/update/cr/totest/images/suse/sles12sp5';
            },
            available_arch => ['x86_64', 'aarch64', 'ppc64le', 's390x']
        },
        '15' => {
            released => sub { 'registry.suse.com/suse/sle15:15.0' },
            totest => sub {
                'registry.suse.de/suse/sle-15/update/cr/totest/images/suse/sle15:15.0';
            },
            available_arch => ['x86_64', 'ppc64le', 's390x']
        },
        '15-SP1' => {
            released => sub { 'registry.suse.com/suse/sle15:15.1' },
            totest => sub {
                'registry.suse.de/suse/sle-15-sp1/update/cr/totest/images/suse/sle15:15.1';
            },
            available_arch => ['x86_64', 'aarch64', 'ppc64le', 's390x']
        },
        '15-SP2' => {
            released => sub { 'registry.suse.com/suse/sle15:15.2' },
            totest => sub {
                'registry.suse.de/suse/sle-15-sp2/update/cr/totest/images/suse/sle15:15.2';
            },
            available_arch => ['x86_64', 'aarch64', 'ppc64le', 's390x']
        },
        '15-SP3' => {
            released => sub { 'registry.suse.com/suse/sle15:15.3' },
            totest => sub {
                'registry.suse.de/suse/sle-15-sp3/update/cr/totest/images/suse/sle15:15.3';
            },
            available_arch => ['x86_64', 'aarch64', 'ppc64le', 's390x']
        },
        '15-SP4' => {
            released => sub { 'registry.suse.com/suse/sle15:15.4' },
            totest => sub {
                'registry.suse.de/suse/sle-15-sp4/ga/test/images/suse/sle15:15.4';
            },
            available_arch => ['x86_64', 'aarch64', 'ppc64le', 's390x']
        },
        '15-SP5' => {
            released => sub { },
            totest => sub {
                'registry.suse.de/suse/sle-15-sp5/ga/test/containers/suse/sle15:15.5';
            },
            available_arch => ['x86_64', 'aarch64', 'ppc64le', 's390x']
        }
    },
    opensuse => {
        Tumbleweed => {
            released => sub { 'registry.opensuse.org/opensuse/tumbleweed' },
            totest => sub {
                'registry.opensuse.org/' . get_opensuse_registry_prefix . 'opensuse/tumbleweed';
            },
            available_arch => ['x86_64', 'aarch64', 'ppc64le', 's390x', 'arm']
        },
        '15.0' => {
            released => sub { 'registry.opensuse.org/opensuse/leap:15.0' },
            totest => sub {
                'registry.opensuse.org/opensuse/leap/15.0/images/totest/images/opensuse/leap:15.0';
            },
            available_arch => ['x86_64']
        },
        '15.1' => {
            released => sub { 'registry.opensuse.org/opensuse/leap:15.1' },
            totest => sub {
                my $arch = shift;
                if ($arch eq 'x86_64') {
                    'registry.opensuse.org/opensuse/leap/15.1/images/totest/containers/opensuse/leap:15.1';
                } elsif ($arch eq 'arm') {
                    'registry.opensuse.org/opensuse/leap/15.1/arm/images/totest/containers/opensuse/leap:15.1';
                }
            },
            available_arch => ['x86_64', 'arm']
        },
        '15.2' => {
            released => sub { 'registry.opensuse.org/opensuse/leap:15.2' },
            totest => sub {
                my $arch = shift;
                if ($arch eq 'x86_64') {
                    'registry.opensuse.org/opensuse/leap/15.2/images/totest/containers/opensuse/leap:15.2';
                } elsif ($arch eq 'arm') {
                    'registry.opensuse.org/opensuse/leap/15.2/arm/images/totest/containers/opensuse/leap:15.2';
                }
            },
            available_arch => ['x86_64', 'arm']
        },
        '15.3' => {
            released => sub { 'registry.opensuse.org/opensuse/leap:15.3' },
            totest => sub {
                my $arch = shift;
                if (grep { $_ eq $arch } qw/x86_64 aarch64 ppc64le s390x/) {
                    'registry.opensuse.org/opensuse/leap/15.3/images/totest/containers/opensuse/leap:15.3';
                } elsif ($arch eq 'arm') {
                    'registry.opensuse.org/opensuse/leap/15.3/arm/images/totest/containers/opensuse/leap:15.3';
                }
            },
            available_arch => ['x86_64', 'aarch64', 'ppc64le', 's390x', 'arm']
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
        }
    },
    'sle-micro' => {
        '15' => {
            released => sub { 'registry.suse.com/suse/sle15:15.0' },
            totest => sub { },
            available_arch => ['x86_64', 'ppc64le', 's390x']
        },
        '15-SP1' => {
            released => sub { 'registry.suse.com/suse/sle15:15.1' },
            totest => sub { },
            available_arch => ['x86_64', 'aarch64', 'ppc64le', 's390x']
        },
        '15-SP2' => {
            released => sub { 'registry.suse.com/suse/sle15:15.2' },
            totest => sub { },
            available_arch => ['x86_64', 'aarch64', 'ppc64le', 's390x']
        },
        '15-SP3' => {
            released => sub { 'registry.suse.com/suse/sle15:15.3' },
            totest => sub { },
            available_arch => ['x86_64', 'aarch64', 'ppc64le', 's390x']
        },
        '5.0' => {
            released => sub { 'registry.opensuse.org/opensuse/tumbleweed' },
            totest => sub { },
            available_arch => ['x86_64', 'aarch64', 's390x']
        },
        '5.1' => {
            released => sub { 'registry.opensuse.org/opensuse/tumbleweed' },
            totest => sub { },
            available_arch => ['x86_64', 'aarch64', 's390x']
        },
        '5.2' => {
            released => sub { 'registry.opensuse.org/opensuse/tumbleweed' },
            totest => sub { },
            available_arch => ['x86_64', 'aarch64', 's390x']
        },
        '5.3' => {
            released => sub { 'registry.opensuse.org/opensuse/tumbleweed' },
            totest => sub { },
            available_arch => ['x86_64', 'aarch64', 's390x']
        }
    },
    microos => {
        Tumbleweed => {
            released => sub { 'registry.opensuse.org/opensuse/tumbleweed' },
            totest => sub {
                'registry.opensuse.org/' . get_opensuse_registry_prefix . 'opensuse/tumbleweed';
            },
            available_arch => ['x86_64', 'aarch64', 'ppc64le', 's390x', 'arm']
        },
        '15.1' => {
            released => sub { 'registry.opensuse.org/opensuse/leap:15.1' },
            totest => sub {
                my $arch = shift;
                if ($arch eq 'x86_64') {
                    'registry.opensuse.org/opensuse/leap/15.1/images/totest/containers/opensuse/leap:15.1';
                } elsif (grep { $_ eq $arch } qw/aarch64 arm/) {
                    'registry.opensuse.org/opensuse/leap/15.1/arm/images/totest/containers/opensuse/leap:15.1';
                }
            },
            available_arch => ['x86_64', 'aarch64', 'arm']
        },
        '15.2' => {
            released => sub { 'registry.opensuse.org/opensuse/leap:15.2' },
            totest => sub {
                my $arch = shift;
                if ($arch eq 'x86_64') {
                    'registry.opensuse.org/opensuse/leap/15.2/images/totest/containers/opensuse/leap:15.2';
                } elsif (grep { $_ eq $arch } qw/aarch64 arm/) {
                    'registry.opensuse.org/opensuse/leap/15.2/arm/images/totest/containers/opensuse/leap:15.2';
                }
            },
            available_arch => ['x86_64', 'aarch64', 'arm']
        },
        '15.3' => {
            released => sub { 'registry.opensuse.org/opensuse/leap:15.3' },
            totest => sub {
                my $arch = shift;
                if ($arch eq 'x86_64') {
                    'registry.opensuse.org/opensuse/leap/15.3/images/totest/containers/opensuse/leap:15.3';
                } elsif (grep { $_ eq $arch } qw/aarch64 arm/) {
                    'registry.opensuse.org/opensuse/leap/15.3/arm/images/totest/containers/opensuse/leap:15.3';
                }
            },
            available_arch => ['x86_64', 'aarch64', 'arm']
        }
    },
    'leap-micro' => {
        '15.2' => {
            released => sub { 'registry.opensuse.org/opensuse/leap:15.2' },
            totest => sub { },
            available_arch => ['x86_64', 'aarch64']
        },
        '15.3' => {
            released => sub { 'registry.opensuse.org/opensuse/leap:15.3' },
            totest => sub { },
            available_arch => ['x86_64', 'aarch64']
        },
        '15.4' => {
            released => sub { 'registry.opensuse.org/opensuse/leap:15.4' },
            totest => sub { },
            available_arch => ['x86_64', 'aarch64']
        }
    }
);

sub supports_image_arch {
    my ($distri, $version, $arch) = @_;
    (grep { $_ eq $arch } @{$images_list{$distri}{$version}{available_arch}}) ? 1 : 0;
}

sub get_3rd_party_images {
    my $ex_reg = get_var('REGISTRY', 'docker.io');
    my @images = (
        "registry.opensuse.org/opensuse/leap",
        "registry.opensuse.org/opensuse/tumbleweed",
        "$ex_reg/library/alpine",
        "$ex_reg/library/debian");

    # Following images are not available on 32-bit arm
    push @images, (
        "$ex_reg/library/fedora",
        "registry.access.redhat.com/ubi8/ubi",
        "registry.access.redhat.com/ubi8/ubi-minimal",
        "registry.access.redhat.com/ubi8/ubi-micro",
        "registry.access.redhat.com/ubi8/ubi-init"
    ) unless (is_arm);

    # - ubi9 images require z14+ s390x machine, they are not ready in OSD yet.
    #     on z13: "Fatal glibc error: CPU lacks VXE support (z14 or later required)".
    # - ubi9 images require power9+ machine.
    #     on Power8: "Fatal glibc error: CPU lacks ISA 3.00 support (POWER9 or later required)"
    # - ubi9 images require x86_64-v2, which needs certain cpu flags
    push @images, (
        "registry.access.redhat.com/ubi9/ubi",
        "registry.access.redhat.com/ubi9/ubi-minimal",
        "registry.access.redhat.com/ubi9/ubi-micro",
        "registry.access.redhat.com/ubi9/ubi-init"
    ) unless (is_arm || is_s390x || is_ppc64le || !is_x86_64_v2);

    # - poo#72124 Ubuntu image (occasionally) fails on s390x.
    # - CentOS image not available on s390x.
    push @images, (
        "$ex_reg/library/ubuntu",
        "$ex_reg/library/centos"
    ) unless (is_arm || is_s390x || is_ppc64le);

    # RedHat UBI7 images are not built for aarch64 and 32-bit arm
    # ubi7/ubi-init fails with "requested source is not authorized"
    push @images, (
        "registry.access.redhat.com/ubi7/ubi",
        "registry.access.redhat.com/ubi7/ubi-minimal"
    ) unless (is_arm || is_aarch64 || check_var('PUBLIC_CLOUD_ARCH', 'arm64'));

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
