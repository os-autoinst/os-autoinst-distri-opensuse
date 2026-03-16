# SUSE's openQA tests
#
# Copyright 2026 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Test ClamAV installation, upgrade and basic functionality bsc#1258072
# - Dynamically fetch the "old" version from zypper
# - Install and verify
# - Upgrade to the latest version
# Maintainer: qe-core <qe-core@suse.com>

use Mojo::Base 'consoletest';
use serial_terminal 'select_serial_terminal';
use testapi;
use utils;
use version_utils;

sub run {
    select_serial_terminal;

    # Get the old version of clamav
    my $old_version = script_output("zypper se -s clamav | grep \"| package\" | awk -F '|' 'NR==2 {print \$4}' | xargs", timeout => 300);
    record_info("Version Found", "Targeting old version: $old_version");

    # Install the specific old versions
    my $libfreshclam = ($old_version =~ /^1\.5\./) ? "libfreshclam4" : "libfreshclam3";
    my @pkgs = ("clamav", "clamav-milter", "libclamav12", "libclammspack0");
    push(@pkgs, $libfreshclam) if (is_sle('<16.0'));
    my $install_list = join(" ", map { "$_=$old_version" } @pkgs);

    zypper_call("in $install_list", timeout => 300);

    # Verify installation
    assert_script_run("rpm -qa | grep -E '(clamav|libclam|libfresh)' | sort");
    my $ver = (split('-', $old_version))[0];
    validate_script_output("clamscan --version", qr/ClamAV $ver/);

    # Upgrade to the latest version available in the repo
    zypper_call("up clamav", timeout => 300);

    # Verify the upgrade was successful
    my $new_version = script_output("clamscan --version | awk '{print \$2}' | cut -d/ -f1");
    die "Upgrade failed: Version is still $old_version" if ($new_version eq $old_version);

    record_info("Upgrade Succeed", "Upgraded from $old_version to $new_version");

    # Final functional check
    assert_script_run("clamscan --version");
}

1;
