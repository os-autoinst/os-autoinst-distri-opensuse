# SUSE's openQA tests
#
# Copyright 2025 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Install and verify UPDATE_PACKAGE on host system
#          Simple package installation check without full patching workflow
# Maintainer: QE-Virtualization <qe-virt@suse.de, Roy.Cai@suse.com>

use base 'consoletest';
use testapi;
use utils;
use serial_terminal 'select_serial_terminal';

sub run {
    my $self = shift;
    select_serial_terminal;

    # Get the target package name
    my $target_package = get_var('UPDATE_PACKAGE', '');

    # Skip if no target package is set or package is 'none' (functional testing)
    unless ($target_package && $target_package ne 'none') {
        my $reason = $target_package ? "UPDATE_PACKAGE is 'none'" : "No target package specified";
        record_info("Skip Package Install", "$reason, skipping package installation");
        return;
    }

    record_info("Package Install Check", "Checking and installing package: $target_package");

    # Check if package is installed and from TEST_ repository
    my $is_installed = script_run("rpm -q $target_package") == 0;
    my $from_test_repo = script_run("zypper if $target_package | grep -qE 'Repository.*TEST_[0-9]+'") == 0;

    unless ($is_installed && $from_test_repo) {
        # Need to install/reinstall package from TEST_ repository
        # While the TEST repository is set up during system installation, the target package is not a required component and might not be pre-installed
        record_info("Installing Package", "Installing $target_package from TEST repository");
        assert_script_run("zypper -n in $target_package", timeout => 100);
    }

    # Show current package status
    my $version = script_output("rpm -q $target_package");
    my $status = ($is_installed && $from_test_repo) ? "already installed" : "successfully installed";
    record_info("Package Ready", "$target_package is $status from TEST repository: $version");

    # Final validation: ensure package comes from TEST_ repository and is up-to-date
    validate_script_output("zypper if $target_package", sub { m/(?=.*TEST_\d+)(?=.*up-to-date)/s });
    record_info("Package Validated", "$target_package confirmed from TEST repository and up-to-date");

    # Show package details for debugging
    script_run("rpm -qi $target_package | head -20");
}

sub test_flags {
    return {fatal => 1};
}

1;
