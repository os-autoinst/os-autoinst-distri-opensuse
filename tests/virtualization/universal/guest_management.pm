# XEN regression tests
#
# Copyright 2019 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: libvirt-client nmap
# Summary: Test basic VM guest management
# Maintainer: Pavel Dostal <pdostal@suse.cz>, Felix Niederwanger <felix.niederwanger@suse.de>, Jan Baier <jbaier@suse.cz>

use base "consoletest";
use virt_autotest::utils;
use strict;
use warnings;
use testapi;
use utils;

sub run {
    my @guests = @{get_var_array("TEST_GUESTS")};

    record_info "SHUTDOWN", "Shut all guests down";
    foreach my $guest (@guests) {
        if (script_retry("nmap $guest -PN -p ssh | grep open", delay => 30, retry => 6, die => 0)) {
            record_info('Softfail', "Guest $guest is not running", result => 'softfail');
            assert_script_run "virsh start $guest", 60;
        }
        if (script_run("virsh shutdown $guest") != 0) {
            record_info('Softfail', "Guest $guest seems to be already down", result => 'softfail');
        }
        if (script_retry("virsh list --all | grep $guest | grep \"shut off\"", delay => 15, retry => 6, die => 0)) {
            record_info('Softfail', "Shutdown on $guest failed", result => 'softfail');
            assert_script_run "virsh destroy $guest";
        }
    }

    record_info "START", "Start all guests";
    foreach my $guest (@guests) {
        assert_script_run("virt-xml $guest --edit --events on_reboot=restart");
        if (script_retry("virsh start $guest", delay => 120, retry => 3, die => 0) != 0) {
            restart_libvirtd;
            script_retry("virsh start $guest", delay => 120, retry => 3);
        }
        script_retry "nmap $guest -PN -p ssh | grep open", delay => 15, retry => 12;
    }

    record_info "REBOOT", "Reboot all guests";
    foreach my $guest (@guests) {
        assert_script_run "virsh reboot $guest";
        if (script_retry("nmap $guest -PN -p ssh | grep open", delay => 30, retry => 6, die => 0)) {
            record_info('Softfail', "Reboot on $guest failed", result => 'softfail');
            script_run "virsh destroy $guest", 90;
            assert_script_run "virsh start $guest", 60;
        }
    }

    record_info "SUSPEND", "Suspend all guests";
    assert_script_run "virsh suspend $_" foreach (@guests);
    script_retry "virsh list --all | grep $_ | grep paused", delay => 15, retry => 12 foreach (@guests);

    record_info "RESUME", "Resume all guests";
    assert_script_run "virsh resume $_" foreach (@guests);
    assert_script_run "virsh list --all";
    script_retry "nmap $_ -PN -p ssh | grep open", delay => 3, retry => 60 foreach (@guests);
}

1;

