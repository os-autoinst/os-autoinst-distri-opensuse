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
use version_utils 'is_sle';
use autotest;
use kernel;
use security::vendoraffirmation;

my $final_result = 'ok';
my $outfile = '/tmp/fips_packages_mismatch';

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
        record_info("Package OK", "Package '$package' Version: '$version'");
    } else {
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

    my $sle_version = get_var('VERSION');
    die 'Product must be 15-SP4, 15-SP6 or 15-SP7' unless defined $sle_version && $sle_version =~ /^(15-SP4|15-SP6|15-SP7)$/;

    # On SLE 15-SP6 and 15-SP7 we don't yet have a kernel version to install
    remove_kernel_packages if is_sle('=15-SP4');

    install_vendor_affirmation_pkgs;

    power_action('reboot');
    $self->wait_boot();

    select_serial_terminal;

    # Create outfile. (In case there is no issue recorded)
    assert_script_run "touch $outfile";

    my %expected = get_expected_va_packages();
    foreach my $pkg (keys %expected) {
        cmp_packages($pkg, $expected{$pkg});
    }

    upload_asset $outfile;

    $self->result($final_result);
}

sub test_flags {
    return {fatal => 1};
}

1;
