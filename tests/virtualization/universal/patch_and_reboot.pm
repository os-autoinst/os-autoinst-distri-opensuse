# XEN regression tests
#
# Copyright © 2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved. This file is offered as-is,
# without any warranty.

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
    my $self       = shift;
    my $kernel_log = shift // '/tmp/virt_kernel.txt';
    # Use serial terminal, unless defined otherwise. The unless will go away once we are certain this is stable
    $self->select_serial_terminal unless get_var('_VIRT_SERIAL_TERMINAL', 1) == 0;

    set_var('MAINT_TEST_REPO', get_var('INCIDENT_REPO'));

    script_run "rpm -qa > /tmp/rpm-qa.txt";
    upload_logs("/tmp/rpm-qa.txt");

    check_virt_kernel(log_file => $kernel_log);
    upload_logs($kernel_log);

    add_test_repositories;
    fully_patch_system;

    # Check that all guests are still running
    script_retry("nmap $_ -PN -p ssh | grep open", delay => 60, retry => 60) foreach (keys %virt_autotest::common::guests);

    if (is_xen_host) {
        # Shut all guests down so the reboot will be easier
        assert_script_run "virsh shutdown $_" foreach (keys %virt_autotest::common::guests);
        script_retry "virsh list --all | grep -v Domain-0 | grep running", delay => 3, retry => 30, expect => 1;
    }

    script_run '( sleep 15 && reboot & )';
    save_screenshot;
    switch_from_ssh_to_sol_console(reset_console_flag => 'on');
}

sub post_run_hook {
}

sub test_flags {
    return {fatal => 1};
}

1;

