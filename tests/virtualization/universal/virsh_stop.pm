# Copyright 2019 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Package: openssh libvirt-client libvirt-daemon
# Summary: Stop all libvirt guests
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
    record_info "POWEROFF", "Shut every guest down";
    script_run "ssh root\@$_ poweroff" foreach (@guests);
    script_retry("virsh domstate $_|grep 'shut off'", delay => 3, retry => 60) foreach (@guests);

    record_info "AUTOSTART DISABLE", "Disable autostart for all guests";
    assert_script_run "virsh autostart --disable $_" foreach (@guests);

    record_info "LIBVIRTD", "Restart libvirtd and expect all guests to stay down";
    restart_libvirtd;
}

sub test_flags {
    return {fatal => 1, milestone => 1};
}

1;

