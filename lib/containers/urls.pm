# SUSE's openQA tests
#
# Copyright 2018-2021 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

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
  get_suse_container_urls
  get_3rd_party_images
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

our %images_uri = (
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
            released => sub { },
            totest => sub {
                'registry.suse.de/suse/sle-15-sp4/ga/test/images/suse/sle15:15.4 ';
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
    }
);

sub supports_image_arch {
    my ($distri, $version, $arch) = @_;
    (grep { $_ eq $arch } @{$images_uri{$distri}{$version}{available_arch}}) ? 1 : 0;
}

# Returns a tuple of image urls and their matching released "stable" counterpart.
# If empty, no images available.
sub get_suse_container_urls {
    my %args = (
        version => get_required_var('VERSION'),
        arch => get_required_var('ARCH'),
        distri => get_required_var('DISTRI'),
        @_
    );
    my @untested_images = ();
    my @released_images = ();

    $args{version} =~ s/^Staging:(?<letter>.)$/Tumbleweed/ if is_tumbleweed || is_microos("Tumbleweed");
    if (supports_image_arch($args{distri}, $args{version}, $args{arch})) {
        push @untested_images, $images_uri{$args{distri}}{$args{version}}{totest}->($args{arch});
        push @released_images, $images_uri{$args{distri}}{$args{version}}{released}->($args{arch});
    } else {
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
    push @images, "$ex_reg/library/ubuntu" unless is_s390x;

    # Missing centos container image for s390x.
    push @images, "$ex_reg/library/centos" unless is_s390x;

    # RedHat UBI7 images are not built for aarch64
    push @images, (
        "registry.access.redhat.com/ubi7/ubi",
        "registry.access.redhat.com/ubi7/ubi-minimal",
        "registry.access.redhat.com/ubi7/ubi-init"
    ) unless (is_aarch64 or check_var('PUBLIC_CLOUD_ARCH', 'arm64'));

    return (\@images);
}

1;
