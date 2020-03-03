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

    record_info '<on_reboot>', 'Check that every no guest has <on_reboot>destroy</on_reboot> but <on_reboot>restart</on_reboot>';
    if (script_run("find /etc/libvirt/ -name *.xml -exec grep on_reboot '{}' \\; | grep destroy") == 0) {
        record_soft_failure "bsc#1153028 - The on_reboot parameter is not set correctly";
        assert_script_run "find /etc/libvirt/ -name *.xml -exec sed -i 's/<on_reboot>destroy<\\/on_reboot>/<on_reboot>restart<\\/on_reboot>/g' '{}' \\;";
        assert_script_run "find /etc/libvirt/ -name *.xml -exec grep on_reboot '{}' \\;";
    }

    record_info "REBOOT", "Reboot all guests";
    foreach my $guest (keys %xen::guests) {
        assert_script_run "virsh reboot $guest";
        if (script_retry("nmap $guest -PN -p ssh | grep open", delay => 30, retry => 6, die => 0)) {
            record_soft_failure "Reboot on $guest failed";
            script_run "virsh destroy $guest",      90;
            assert_script_run "virsh start $guest", 60;
        }
    }

    record_info "SHUTDOWN", "Shut all guests down";
    foreach my $guest (keys %xen::guests) {
        if (script_retry("nmap $guest -PN -p ssh | grep open", delay => 30, retry => 6, die => 0)) {
            record_soft_failure "Guest $guest is not running after the reboot";
            assert_script_run "virsh start $guest", 60;
        }
        if (script_run("virsh shutdown $guest") != 0) {
            record_soft_failure "Guest $guest seems to be already down";
        }
        if (script_retry("virsh list --all | grep $guest | grep \"shut off\"", delay => 15, retry => 6, die => 0)) {
            record_soft_failure "Shutdown on $guest failed";
            assert_script_run "virsh destroy $guest";
        }
    }

    record_info "START", "Start all guests";
    foreach my $guest (keys %xen::guests) {
        script_retry "virsh start $guest",                 delay => 30, retry => 12;
        script_retry "nmap $guest -PN -p ssh | grep open", delay => 15, retry => 12;
    }

    record_info "SUSPEND", "Suspend all guests";
    assert_script_run "virsh suspend $_" foreach (keys %xen::guests);
    script_retry "virsh list --all | grep $_ | grep paused", delay => 15, retry => 12 foreach (keys %xen::guests);

    record_info "RESUME", "Resume all guests";
    assert_script_run "virsh resume $_" foreach (keys %xen::guests);
    assert_script_run "virsh list --all";
    script_retry "nmap $_ -PN -p ssh | grep open", delay => 3, retry => 60 foreach (keys %xen::guests);
}

1;

