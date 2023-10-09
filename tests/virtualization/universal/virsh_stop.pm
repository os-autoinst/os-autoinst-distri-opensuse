# Copyright 2019 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Package: openssh libvirt-client libvirt-daemon
# Summary: Stop all libvirt guests
# Maintainer: QE-Virtualization <qe-virt@suse.de>

use base "consoletest";
use virt_autotest::common;
use virt_autotest::utils;
use strict;
use warnings;
use testapi;
use utils;

sub run {
    record_info "POWEROFF", "Shut every guest down";
    script_run "ssh root\@$_ poweroff" foreach (keys %virt_autotest::common::guests);
    script_retry "virsh list --all | grep -v Domain-0 | grep running", delay => 3, retry => 60, expect => 1;

    record_info "AUTOSTART DISABLE", "Disable autostart for all guests";
    assert_script_run "virsh autostart --disable $_" foreach (keys %virt_autotest::common::guests);

    record_info "LIBVIRTD", "Restart libvirt daemon and expect all guests to stay down";
    # Note: TBD for modular libvirt. See poo#129086 for detail.
    restart_libvirtd;
}

sub test_flags {
    return {fatal => 1, milestone => 1};
}

1;

