# XEN regression tests
#
# Copyright 2019 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved. This file is offered as-is,
# without any warranty.

# Package: libvirt-client nmap
# Summary: Test if the guests can be saved and restored
# Maintainer: Jan Baier <jbaier@suse.cz>

use base "virt_feature_test_base";
use virt_autotest::common;
use strict;
use warnings;
use testapi;
use utils;

sub run_test {
    assert_script_run "mkdir -p /var/lib/libvirt/images/saves/";

    record_info "Remove", "Remove previous saves (if there were any)";
    script_run "rm /var/lib/libvirt/images/saves/$_.vmsave || true" foreach (keys %virt_autotest::common::guests);

    record_info "Save", "Save the machine states";
    assert_script_run("virsh save $_ /var/lib/libvirt/images/saves/$_.vmsave", 300) foreach (keys %virt_autotest::common::guests);

    record_info "Check", "Check saved states";
    foreach my $guest (keys %virt_autotest::common::guests) {
        if (script_run("virsh list --all | grep $guest | grep shut") != 0) {
            record_info 'Softfail', "Guest $guest should be shut down now", result => 'softfail';
            script_run "virsh destroy $guest", 90;
        }
    }

    record_info "Restore", "Restore guests";
    assert_script_run("virsh restore /var/lib/libvirt/images/saves/$_.vmsave", 300) foreach (keys %virt_autotest::common::guests);

    record_info "Check", "Check restored states";
    assert_script_run "virsh list --all | grep $_ | grep running" foreach (keys %virt_autotest::common::guests);

    record_info "SSH", "Check hosts are listening on SSH";
    script_retry "nmap $_ -PN -p ssh | grep open", delay => 3, retry => 60 foreach (keys %virt_autotest::common::guests);
}

1;

