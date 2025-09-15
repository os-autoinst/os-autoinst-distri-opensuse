# Copyright 2019-2020 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Summary: Compare FIPS package version with its expected version for SLE15SP4
# Maintainer: QE Security <none@suse.de>
# Tag: poo#125702

use Mojo::Base qw(opensusebasetest);
use version;
use testapi;
use serial_terminal 'select_serial_terminal';
use utils qw(systemctl zypper_call);
use Mojo::Util 'trim';
use version_utils qw(is_rt);
use Utils::Architectures qw(is_s390x);
use power_action_utils 'power_action';
use autotest;
use kernel;

my $final_result = 'ok';
my $outfile = '/tmp/fips_packages_mismatch';
my $version_get = get_required_var("VERSION");

# 15-SP6 and SP7 not yet. Need to adjust after the certification
my %product_versions = (
    '15-SP4' => {
        kernel_ver => '5.14.21-150400.24.46.1',
        kernelRT_ver => '5.14.21-150400.15.11.1',
        openssl1_1_ver => '1.1.1l-150400.7.28.1',
        openssl3_ver => '',
        gnutls_ver => '3.7.3-150400.4.35.1',
        gcrypt_ver => '1.9.4-150400.6.8.1',
        nss_ver => '3.79.4-150400.3.29.1',
        ica_ver => '4.2.1-150400.3.8.1',
        nettle_ver => '3.7.3-150400.2.21',
    },
    '15-SP6' => {
        kernel_ver => '6.4.0-150600.23.25.1',
        kernelRT_ver => '6.4.0-150600.10.17.1',
        openssl1_1_ver => '1.1.1w-150600.5.15.1',
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
        openssl1_1_ver => '1.1.1w-150600.5.15.1',
        openssl3_ver => '3.1.4-150600.5.15.1',
        gnutls_ver => '3.8.3-150600.4.6.2',
        gcrypt_ver => '1.10.3-150600.3.6.1',
        nss_ver => '3.101.2-150400.3.54.1',
        ica_ver => '4.3.1-150600.4.25.1',
        nettle_ver => '3.9.1-150600.3.2.1',
    }
);

my $version = $product_versions{$version_get};

my %packages_common = (
    'kernel-default' => $version->{kernel_ver},
    'kernel-default-devel' => $version->{kernel_ver},
    'kernel-devel' => $version->{kernel_ver},
    'kernel-source' => $version->{kernel_ver},
    'kernel-default-devel-debuginfo' => $version->{kernel_ver},
    'kernel-default-debuginfo' => $version->{kernel_ver},
    'kernel-default-debugsource' => $version->{kernel_ver},
    'libopenssl1_1' => $version->{openssl1_1_ver},
    'libopenssl1_1-hmac' => $version->{openssl1_1_ver},
    'libopenssl1_1-32bit' => $version->{openssl1_1_ver},
    'libopenssl1_1-hmac-32bit' => $version->{openssl1_1_ver},
    'libopenssl-3-fips-provider' => $version->{openssl3_ver},
    libgnutls30 => $version->{gnutls_ver},
    'libgnutls30-hmac' => $version->{gnutls_ver},
    'libgnutls-devel' => $version->{gnutls_ver},
    libnettle8 => $version->{nettle_ver},
    libgcrypt20 => $version->{gcrypt_ver},
    'libgcrypt20-hmac' => $version->{gcrypt_ver},
    'libgcrypt-devel' => $version->{gcrypt_ver},
    'mozilla-nss-tools' => $version->{nss_ver},
    'mozilla-nss-debugsource' => $version->{nss_ver},
    'mozilla-nss' => $version->{nss_ver},
    'mozilla-nss-certs' => $version->{nss_ver},
    'mozilla-nss-devel' => $version->{nss_ver},
    'mozilla-nss-debuginfo' => $version->{nss_ver}
);

my %packages_s390x = (
    libica4 => $version->{ica_ver},
    'libica-tools' => $version->{ica_ver}
);

my %packages_rt = (
    'kernel-rt' => $version->{kernelRT_ver},
    'kernel-devel-rt' => $version->{kernelRT_ver},
    'kernel-source-rt' => $version->{kernelRT_ver}
);

sub cmp_version {
    my ($old, $new) = @_;
    return $old eq $new;
}

sub cmp_packages {
    my ($package, $version) = @_;
    my $output = script_output("zypper se -xs $package | grep -w $package | cut -d \\| -f 4 ", 100, proceed_on_failure => 1);
    my @installed_versions = ();

    # Get a list of all the installed versions of the package.
    for my $line (split(/\r?\n/, $output)) {
        my $clean_line = trim($line);
        if ($clean_line =~ m/^\d+\.\d+/) {
            push @installed_versions, $clean_line;
        }
    }

    # Package not installed.
    if (@installed_versions == 0) {
        record_info("Package $package not found");
        assert_script_run "echo '$package not found' >> $outfile";
        assert_script_run "echo >> $outfile";
        return;
    }

    # Is the package installed in any version?
    my $version_found = 0;
    for my $installed_version (@installed_versions) {
        if ($installed_version eq $version) {
            $version_found = 1;
            last;
        }
    }

    # Is certified version installed?
    if ($version_found) {
        record_info("Pacakage OK", "Package '$package' Version: '$version'");
    }
    else {
        $final_result = 'fail';
        my $list_installed = join(', ', @installed_versions);
        record_info("Version not found", "Package '$package' version '$version'\nInstalled: $list_installed", result => $final_result);
        assert_script_run "echo '$package: VERSION MISMATCH' >> $outfile";
        assert_script_run "echo 'wanted: $version' >> $outfile";
        assert_script_run "echo 'installed versions:' >> $outfile";
    }
}

sub run {
    my $self = shift;

    select_serial_terminal;

    remove_kernel_packages;

    # Try to install all  the packages
    foreach my $package (keys %packages_common) {
        eval {
            zypper_call('in --oldpackage --force-resolution ' . $package . '-' . $packages_common{$package});
        } or do {
            my $err = substr($@, 0, 512);
            record_info("$package installation result: $err");
        };
    }

    power_action('reboot');
    $self->wait_boot();

    select_serial_terminal;

    # Create outfile. (In case there is no issue recorded)
    assert_script_run "touch $outfile";

    foreach my $key (keys %packages_common) {
        if ($packages_common{$key}) {
            cmp_packages($key, $packages_common{$key});
        }
    }

    if (is_s390x) {
        foreach my $key (keys %packages_s390x) {
            cmp_packages($key, $packages_s390x{$key});
        }
    }

    if (is_rt) {
        foreach my $key (keys %packages_rt) {
            cmp_packages($key, $packages_rt{$key});
        }
    }

    upload_asset $outfile;

    $self->result($final_result);
}

sub test_flags {
    return {fatal => 1};
}

1;
