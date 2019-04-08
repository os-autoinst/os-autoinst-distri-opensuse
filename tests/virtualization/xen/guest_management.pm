# XEN regression tests
#
# Copyright © 2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved. This file is offered as-is,
# without any warranty.

# Summary: Test basic VM guest management
# Maintainer: Jan Baier <jbaier@suse.cz>

use base "consoletest";
use xen;
use strict;
use warnings;
use testapi;
use utils;

sub run {
    my $hypervisor = get_var('HYPERVISOR') // '127.0.0.1';

    record_info "REBOOT", "Reboot all guests";
    foreach my $guest (keys %xen::guests) {
        assert_script_run "virsh reboot $guest";
        if (script_retry("nmap $guest -PN -p ssh | grep open", delay => 30, retry => 6, die => 0)) {
            record_soft_failure "Reboot on $guest failed";
            assert_script_run "virsh destroy $guest";
            assert_script_run "virsh start $guest";
        }
    }

    record_info "SHUTDOWN", "Shut all guests down";
    foreach my $guest (keys %xen::guests) {
        assert_script_run "virsh shutdown $guest";
        if (script_retry("virsh list --all | grep $guest | grep \"shut off\"", delay => 15, retry => 6, die => 0)) {
            record_soft_failure "Shutdown on $guest failed";
            assert_script_run "virsh destroy $guest";
        }
    }

    record_info "START", "Start all guests";
    assert_script_run "virsh start $_" foreach (keys %xen::guests);
    script_retry "nmap $_ -PN -p ssh | grep open", delay => 15, retry => 12 foreach (keys %xen::guests);

    # TODO:
    record_info "AUTOSTART DISABLE", "Disable autostart for all guests";
    assert_script_run "virsh autostart --disable $_" foreach (keys %xen::guests);

    # TODO:
    record_info "AUTOSTART ENABLE", "Enable autostart for all guests";
    assert_script_run "virsh autostart $_" foreach (keys %xen::guests);

    record_info "SUSPEND", "Suspend all guests";
    assert_script_run "virsh suspend $_" foreach (keys %xen::guests);
    script_retry "virsh list --all | grep $_ | grep paused", delay => 15, retry => 12 foreach (keys %xen::guests);

    record_info "RESUME", "Resume all guests";
    assert_script_run "virsh resume $_" foreach (keys %xen::guests);
    assert_script_run "virsh list --all";
    script_retry "nmap $_ -PN -p ssh | grep open", delay => 3, retry => 60 foreach (keys %xen::guests);
}

1;

