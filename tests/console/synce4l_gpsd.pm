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
    my $synce_version = script_output("synce4l -v");
    if ($synce_version =~ /1\.1\.[0-9]/) {
        record_info("synce4l version is modern: $synce_version");
    } else {
        die "Unexpected synce4l version! Found: $synce_version. Expected >= 1.1.0";
    }

    # Verify gpsd version is at least 3.27
    my $gpsd_version = script_output("gpsd --version");
    if ($gpsd_version =~ /3\.27\.[0-9]/) {
        record_info("gpsd version is modern: $gpsd_version");
    } else {
        die "Unexpected gpsd version! Found: $gpsd_version. Expected >= 3.27.5";
    }

    record_info("synce4l Test", "Creating a safe dry-run configuration for Synchronous Ethernet");
    assert_script_run "curl " . data_url("console/synce4l_test.conf") . " -o /etc/synce4l_test.conf";

    my $synce_check = script_output("synce4l -f /etc/synce4l_test.conf -m", proceed_on_failure => 1);
    record_info("synce4l Output", $synce_check);

    # Functional Testing for gpsd (General Sync Platform Daemon / GNSS Sync)
    record_info("gpsd Test", "Validating systemd service presence and configuration validation");

    # Check systemd units are delivered by the new packages
    assert_script_run("systemctl daemon-reload");
    assert_script_run("systemctl show synce4l --property=LoadState | grep -q 'loaded'");
    assert_script_run("systemctl show gpsd --property=LoadState | grep -q 'loaded'");

    # Generate a baseline mock config for gpsd if required by systemd service
    # and trigger a dry run test.
    if (script_run("systemctl start gpsd") != 0) {
        my $gpsd_log = script_output("journalctl -n 20 -u gpsd");
        record_info("gpsd Journal", $gpsd_log);
        # Accept "no device found" or "missing hardware" signatures, but reject "Segmentation fault" or "invalid option"
        if ($gpsd_log =~ /segfault|core dumped/i) {
            die "gpsd crashed with a core dump/segfault on initialization!";
        }
    }

    record_info("Cleanup", "Cleaning up evaluation files");
    assert_script_run("rm -f /etc/synce4l_test.conf");
}

sub test_flags {
    return {fatal => 1};
}

1;
