# SUSE's openQA tests
#
# Copyright 2019 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: libvirt-client openssh
# Summary: List every guest and ensure they are online
# Maintainer: Pavel Dostal <pdostal@suse.cz>

use base "virt_feature_test_base";
use virt_autotest::common;
use virt_autotest::utils;
use strict;
use warnings;
use testapi;
use utils;

sub run_test {
    my $self = shift;
    $self->select_serial_terminal;

    ensure_default_net_is_active();

    assert_script_run "virsh list --all", 90;

    # Ensure all guests are online and have network connectivity
    foreach my $guest (keys %virt_autotest::common::guests) {
        # This should fix some common issues on the guests. If the procedure fails we still want to go on
        eval {
            ensure_online($guest);
            record_info("$guest kernel", script_output("ssh \"$guest\" uname -r"));
            1;
        } or do {
            my $err = $@;
            record_soft_failure("enure_online failed for $guest: $err");
        };
    }
}

1;

