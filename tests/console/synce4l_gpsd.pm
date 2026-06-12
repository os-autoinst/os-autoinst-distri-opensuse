# SUSE's openQA tests
#
# Copyright 2012-2026 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: synce4l gpsd
# Summary: Test case for Precision Timing packages (synce4l and gpsd)
# Maintainer: qe-core <qe-core@suse.com>

use Mojo::Base 'consoletest';
use testapi;
use version_utils;
use utils;
use package_utils 'install_package';

sub run {
    my ($self) = @_;

    $self->select_serial_terminal;

    record_info("Install", "Installing precision timing packages");
    install_package('synce4l gpsd', trup_reboot => 1);

    record_info("Version Check", "Verifying updated upstream versions for Granite Rapids compatibility");

    # Verify synce4l is at least version 1.1.0
    my $synce_version = script_output("rpm -q --queryformat '%{VERSION}' synce4l");
    if (zypper_version_cmp($synce_version, '1.1.0') >= 0) {
        record_info("synce4l version is modern: $synce_version");
    } else {
        die "Unexpected synce4l version! Found: $synce_version. Expected >= 1.1.0";
    }

    # Verify gpsd version is at least 3.27
    my $gpsd_version = script_output("rpm -q --queryformat '%{VERSION}' gpsd");
    if (zypper_version_cmp($gpsd_version, '3.27.5') >= 0) {
        record_info("gpsd version is modern: $gpsd_version");
    } else {
        die "Unexpected gpsd version! Found: $gpsd_version. Expected >= 3.27.5";
    }
}

sub test_flags {
    return {fatal => 1};
}

1;
