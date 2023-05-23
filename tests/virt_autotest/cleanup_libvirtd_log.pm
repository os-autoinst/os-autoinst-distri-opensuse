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
    # Cleanup logs of libvirt daemons
    my @libvirt_daemons = qw(libvirtd virtqemud virtstoraged virtnetworkd virtnodedevd virtsecretd virtproxyd virtnwfilterd virtlockd virtlogd);
    foreach (@libvirt_daemons) {
        my $log_file = "/var/log/libvirt/$_.log";
        if (script_run("test -f $log_file") == 0) {
            script_run("echo '' > $log_file");
            record_info "Set file $log_file empty before every test.";
        }
    }
}

sub test_flags {
    return {fatal => 1};
}

1;
