# Vendor Affirmation
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP
# Summary: Stronger password to be used with CC/FIPS.
#
# Maintainer: QE Security <none@suse.de>

package security::vendoraffirmation;

use strict;
use warnings;
use testapi;

use base 'Exporter';
use registration qw(add_suseconnect_product);
use version_utils qw(is_rt is_sle);
use Utils::Architectures qw(is_s390x);
use utils qw(zypper_call);

our @EXPORT = qw(install_vendor_affirmation_pkgs get_expected_va_packages);

sub _get_sle_version {
    my $version = get_var('VERSION');
    if (!defined $version) {
        # Check if we're in a test environment where VERSION might not be set
        if ($ENV{CI}) {
            return '15-SP4';    # Default for testing
        }
        die "VERSION environment variable not set";
    }
    return $version;
}

# 15-SP6 and SP7 not yet. Need to adjust after the certification
my %product_versions = (
    '15-SP4' => {
        kernel_ver => '5.14.21-150400.24.46.1',
        kernelRT_ver => '5.14.21-150400.15.11.1',
        openssl1_ver => '1.1.1l-150400.7.28.1',
        gnutls_ver => '3.7.3-150400.4.35.1',
        gcrypt_ver => '1.9.4-150400.6.8.1',
        nss_ver => '3.79.4-150400.3.29.1',
        ica_ver => '4.2.1-150400.3.8.1',
        nettle_ver => '3.7.3-150400.2.21',
    },
    '15-SP6' => {
        kernel_ver => '6.4.0-150600.23.25.1',
        kernelRT_ver => '6.4.0-150600.10.17.1',
        openssl1_ver => '1.1.1w-150600.5.15.1',
        openssl3_ver => '3.1.4-150600.5.15.1',
        gnutls_ver => '3.8.3-150600.4.6.2',
        gcrypt_ver => '1.10.3-150600.3.6.1',
        nss_ver => '3.101.2-150400.3.54.1',
        ica_ver => '4.3.1-150600.4.25.1',
        nettle_ver => '3.9.1-150600.3.2.1',
    },
    '15-SP7' => {
        kernel_ver => '6.4.0-150600.23.25.1',
        kernelRT_ver => '6.4.0-150600.10.17.1',
        openssl1_ver => '1.1.1w-150600.5.15.1',
        openssl3_ver => '3.1.4-150600.5.15.1',
        gnutls_ver => '3.8.3-150600.4.6.2',
        gcrypt_ver => '1.10.3-150600.3.6.1',
        nss_ver => '3.101.2-150400.3.54.1',
        ica_ver => '4.3.1-150600.4.25.1',
        nettle_ver => '3.9.1-150600.3.2.1',
    }
);

my $sle_version = _get_sle_version;
my $version = $product_versions{$sle_version};

my %va_common_packages = (
    'libopenssl1_1' => $version->{openssl1_ver},
    'libopenssl1_1-32bit' => $version->{openssl1_ver},
    'mozilla-nss' => $version->{nss_ver},
    'mozilla-nss-tools' => $version->{nss_ver},
    'mozilla-nss-certs' => $version->{nss_ver},
    'mozilla-nss-devel' => $version->{nss_ver},
    'mozilla-nss-debuginfo' => $version->{nss_ver},
    'mozilla-nss-debugsource' => $version->{nss_ver},
    libfreebl3 => $version->{nss_ver},
    libsoftokn3 => $version->{nss_ver},
    libgnutls30 => $version->{gnutls_ver},
    'libgnutls30-hmac' => $version->{gnutls_ver},
    'libgnutls-devel' => $version->{gnutls_ver},
    libnettle8 => $version->{nettle_ver},
    libhogweed6 => $version->{nettle_ver},
    libgcrypt20 => $version->{gcrypt_ver},
    'libgcrypt20-hmac' => $version->{gcrypt_ver},
    'libgcrypt-devel' => $version->{gcrypt_ver}
);

my %va_s390x_packages = (
    libica4 => $version->{ica_ver},
    'libica-tools' => $version->{ica_ver}
);

my %va_kernel_default = (
    'kernel-default' => $version->{kernel_ver},
    'kernel-default-devel' => $version->{kernel_ver},
    'kernel-devel' => $version->{kernel_ver},
    'kernel-source' => $version->{kernel_ver},
    'kernel-default-devel-debuginfo' => $version->{kernel_ver},
    'kernel-default-debuginfo' => $version->{kernel_ver},
    'kernel-default-debugsource' => $version->{kernel_ver}
);

my %va_kernel_rt = (
    'kernel-rt' => $version->{kernelRT_ver},
    'kernel-devel-rt' => $version->{kernelRT_ver},
    'kernel-source-rt' => $version->{kernelRT_ver}
);

my %va_15sp4_pkgs = (
    'libopenssl1_1-hmac' => $version->{openssl1_ver},
    'libopenssl1_1-hmac-32bit' => $version->{openssl1_ver}
);

my %va_15sp6_pkgs = (
    'libopenssl-3-fips-provider' => $version->{openssl3_ver}
);

sub install_vendor_affirmation_pkgs {
    my @to_install = map { "$_=$va_common_packages{$_}" } keys %va_common_packages;

    push @to_install, map { "$_=$va_s390x_packages{$_}" } keys %va_s390x_packages if is_s390x;

    push @to_install, map { "$_=$va_15sp4_pkgs{$_}" } keys %va_15sp4_pkgs if is_sle('=15-SP4');
    push @to_install, map { "$_=$va_15sp6_pkgs{$_}" } keys %va_15sp6_pkgs if is_sle('=15-SP6') || is_sle('=15-SP7');

    my %kernel_packages = is_rt ? %va_kernel_rt : %va_kernel_default;
    push @to_install, map { "$_=$kernel_packages{$_}" } keys %kernel_packages;

    my $from_repo = "";
    if (is_sle('=15-SP7')) {
        # On 15-SP7 we need to use the dedicated certification module
        add_suseconnect_product('sle-module-certifications');
        $from_repo = "--from SLE-Module-Certifications-15-SP7-Updates";
    }
    zypper_call("--ignore-unknown in --oldpackage --force-resolution $from_repo " . join(' ', @to_install), exitcode => [0, 102, 104]);
}

sub get_expected_va_packages {
    my %expected = %va_common_packages;

    %expected = (%expected, %va_s390x_packages) if is_s390x;
    %expected = (%expected, %va_15sp4_pkgs) if is_sle('=15-SP4');
    %expected = (%expected, %va_15sp6_pkgs) if (is_sle('=15-SP6') || is_sle('=15-SP7'));
    %expected = (%expected, is_rt ? %va_kernel_rt : %va_kernel_default);

    return %expected;
}

1;
