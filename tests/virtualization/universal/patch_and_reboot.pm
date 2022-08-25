# XEN regression tests
#
# Copyright 2019 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: rpm nmap libvirt-client
# Summary: Apply patches to the running system
# Maintainer: Pavel Dostál <pdostal@suse.cz>, Felix Niederwanger <felix.niederwanger@suse.de>

use base 'consoletest';
use virt_autotest::common;
use virt_autotest::utils;
use warnings;
use strict;
use power_action_utils 'power_action';
use ipmi_backend_utils;
use virt_autotest::kernel;
use testapi;
use utils;
use qam;

sub run {
    my $self = shift;
    select_console('root-console');
    set_var('MAINT_TEST_REPO', get_var('INCIDENT_REPO'));
    assert_script_run("dmesg --level=emerg,crit,alert,err -tx|sort -o /tmp/dmesg_err_before.txt") if check_var("PATCH_WITH_ZYPPER", "1");
    assert_script_run "rm -rf /etc/zypp/repos.d/TEST*";
    add_test_repositories;
    fully_patch_system;

    if (get_var("UPDATE_PACKAGE") =~ /xen|kernel-default|qemu/) {
        script_run("virsh list --all | grep -v Domain-0");
        script_retry("nmap $_ -PN -p ssh | grep open", delay => 60, retry => 60) foreach (keys %virt_autotest::common::guests);
        script_run '( sleep 15 && reboot & )';
        save_screenshot;
        switch_from_ssh_to_sol_console(reset_console_flag => 'on');
    } else {
        systemctl("restart libvirtd");
        script_run("virsh list --all | grep -v Domain-0");
        # Check that all guests are still running
        script_retry("nmap $_ -PN -p ssh | grep open", delay => 60, retry => 60) foreach (keys %virt_autotest::common::guests);
    }
}
sub post_run_hook {
}

sub test_flags {
    return {fatal => 1};
}

1;

