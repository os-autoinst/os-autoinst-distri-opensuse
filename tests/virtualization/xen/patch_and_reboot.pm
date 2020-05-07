# XEN regression tests
#
# Copyright © 2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved. This file is offered as-is,
# without any warranty.

# Summary: Apply patches to the running system
# Maintainer: Jan Baier <jbaier@suse.cz>

use base 'xen';
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

    set_var('MAINT_TEST_REPO', get_var('INCIDENT_REPO'));

    check_virt_kernel('', 'before');
    script_run "zypper lr -d";
    script_run "rpm -qa > /tmp/rpm-qa-before.txt";
    upload_logs("/tmp/rpm-qa-before.txt");

    add_test_repositories;
    fully_patch_system;

    check_virt_kernel('', 'after');
    script_run "zypper lr -d";
    script_run "rpm -qa > /tmp/rpm-qa-after.txt";
    upload_logs("/tmp/rpm-qa-after.txt");

    # Check that all guests are still running
    script_retry("nmap $_ -PN -p ssh | grep open", delay => 60, retry => 60) foreach (keys %xen::guests);

    if (check_var('XEN', '1')) {
        # Shut all guests down so the reboot will be easier
        assert_script_run "virsh shutdown $_" foreach (keys %xen::guests);
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

