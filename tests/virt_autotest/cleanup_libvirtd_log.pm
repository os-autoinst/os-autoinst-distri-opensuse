# SUSE's openQA tests
#
# Copyright 2022 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Cleanup libvirtd log before test.
# Maintainer: qe-virt@suse.de
package cleanup_libvirtd_log;

use strict;
use warnings;
use base "virt_autotest_base";
use testapi;

sub run {
    # Cleanup libvirtd.log
    my $libvirtd_log_file = "/var/log/libvirt/libvirtd.log";
    if (script_run("test -f $libvirtd_log_file") == 0) {
        script_run("echo '' > $libvirtd_log_file");
        record_info "Set file $libvirtd_log_file empty before every test.";
    }
}

sub test_flags {
    return {fatal => 1};
}

1;
