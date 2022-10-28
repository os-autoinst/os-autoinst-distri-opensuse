# Copyright 2019 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Package: libvirt-client libvirt-daemon
# Summary: This starts libvirt guests again
# Maintainer: Pavel Dostál <pdostal@suse.cz>

use base "consoletest";
#use virt_autotest::common;
use virt_autotest::utils;
use strict;
use warnings;
use testapi;
use utils;

sub run {
    my @guests = @{get_var_array("TEST_GUESTS")};
    record_info "AUTOSTART ENABLE", "Enable autostart for all guests";
    foreach my $guest (@guests) {
        if (script_run("virsh autostart $guest", 30) != 0) {
            record_info('Softfail', "Cannot enable autostart on $guest guest", result => 'softfail');
        }
    }

    record_info "LIBVIRTD", "Restart libvirtd and expect all guests to boot up";
    restart_libvirtd;

    # Ensure all guests have network connectivity
    foreach my $guest (@guests) {
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

