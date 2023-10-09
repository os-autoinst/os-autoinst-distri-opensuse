# Copyright 2019 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Package: libvirt-client libvirt-daemon
# Summary: This starts libvirt guests again
# Maintainer: QE-Virtualization <qe-virt@suse.de>

use base "consoletest";
use virt_autotest::common;
use virt_autotest::utils;
use strict;
use warnings;
use testapi;
use utils;

sub run {
    record_info "AUTOSTART ENABLE", "Enable autostart for all guests";
    foreach my $guest (keys %virt_autotest::common::guests) {
        if (script_run("virsh autostart $guest", 30) != 0) {
            record_info('Softfail', "Cannot enable autostart on $guest guest", result => 'softfail');
        }
    }

    record_info "LIBVIRTD", "Restart libvirt daemon and expect all guests to boot up";
    # Note: TBD for modular libvirt. See poo#129086 for detail.
    restart_libvirtd;


    # Ensure all guests have network connectivity
    foreach my $guest (keys %virt_autotest::common::guests) {
        eval {
            ensure_online($guest);
        } or do {
            my $err = $@;
            record_info("$guest failure: $err");
        }
    }
}

sub test_flags {
    return {fatal => 1, milestone => 1};
}

1;

