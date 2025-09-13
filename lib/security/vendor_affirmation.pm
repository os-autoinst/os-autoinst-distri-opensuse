# Vendor Affirmation
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP
# Summary: Stronger password to be used with CC/FIPS.
#
# Maintainer: QE Security <none@suse.de>

package security::vendor_affirmation;

use strict;
use warnings;
use testapi;

use base 'Exporter';
use registration qw(add_suseconnect_product);
use version_utils qw(is_rt);
use Utils::Architectures qw(is_s390x);
use utils qw(zypper_call);

our @EXPORT = qw(install_vendor_affirmation_pkgs);

my $kernel_ver = '6.4.0-150600.23.25.1';
my $kernelRT_ver = '6.4.0-150600.10.17.1';
my $openssl1_ver = '1.1.1w-150600.5.12.2';
my $openssl3_ver = '3.1.4-150600.5.15.1';
my $gnutls_ver = '3.8.3-150600.4.6.2';
my $gcrypt_ver = '1.10.3-150600.3.6.1';
my $nss_ver = '3.101.2-150400.3.54.1';
my $nettle_ver = '3.9.1-150600.3.2.1';
my $ica_ver = '4.3.1-150600.4.25.1';

my %va_common_packages = (
    'libopenssl1_1' => $openssl1_ver,
    'libopenssl-3-fips-provider' => $openssl3_ver,
    'mozilla-nss' => $nss_ver,
    'mozilla-nss-tools' => $nss_ver,
    'mozilla-nss-certs' => $nss_ver,
    'mozilla-nss-devel' => $nss_ver,
    libfreebl3 => $nss_ver,
    libsoftokn3 => $nss_ver,
    libgnutls30 => $gnutls_ver,
    'libgnutls30-hmac' => $gnutls_ver,
    'libgnutls-devel' => $gnutls_ver,
    libnettle8 => $nettle_ver,
    libhogweed6 => $nettle_ver,
    libgcrypt20 => $gcrypt_ver,
    'libgcrypt20-hmac' => $gcrypt_ver,
    'libgcrypt-devel' => $gcrypt_ver
);

my %va_s390x_packages = (
    libica4 => $ica_ver,
    'libica-tools' => $ica_ver
);

my %va_kernel_default = (
    'kernel-default' => $kernelRT_ver,
    'kernel-default-devel' => $kernel_ver
);

my %va_kernel_rt = (
    'kernel-rt' => $kernelRT_ver,
    'kernel-devel-rt' => $kernelRT_ver
);

sub install_vendor_affirmation_pkgs {
    add_suseconnect_product('sle-module-certifications');

    # Start with common packages
    my @to_install = map { "$_=$va_common_packages{$_}" } keys %va_common_packages;

    push @to_install, map { "$_=$va_s390x_packages{$_}" } keys %va_s390x_packages if is_s390x;

    my %kernel_packages = is_rt ? %va_kernel_rt : %va_kernel_default;
    push @to_install, map { "$_=$kernel_packages{$_}" } keys %kernel_packages;

    my $repo_name = "SLE-Module-Certifications-" . get_required_var('VERSION') . "-Updates";
    zypper_call("--ignore-unknown in --oldpackage --from $repo_name " . join(' ', @to_install), exitcode => [0, 102, 104]);
}

1;
