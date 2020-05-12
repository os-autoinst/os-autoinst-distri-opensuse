# XEN regression tests
#
# Copyright © 2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved. This file is offered as-is,
# without any warranty.

# Summary: Apply patches to the all of our guests and reboot them
# Maintainer: Pavel Dostál <pdostal@suse.cz>

use base "consoletest";
use warnings;
use strict;
use testapi;
use qam 'ssh_add_test_repositories';
use utils;
use xen;
use version_utils;
use virt_autotest::kernel;

sub run {
    my ($self) = @_;
    my ($host_running_version, $host_running_sp) = get_sles_release();
    set_var('MAINT_TEST_REPO', get_var('INCIDENT_REPO'));

    my ($guest_running_version, $guest_running_sp);
    foreach my $guest (keys %xen::guests) {
        ($guest_running_version, $guest_running_sp) = get_sles_release("ssh root\@$guest");

        record_info "$guest", "Adding test repositories and patching the $guest system";
        if ($host_running_version == $guest_running_version && $host_running_sp == $guest_running_sp) {
            ssh_add_test_repositories "$guest";

            check_virt_kernel($guest, '-before');
            script_run "ssh root\@$guest zypper lr -d";
            script_run "ssh root\@$guest rpm -qa > /tmp/rpm-qa-$guest-before.txt";
            upload_logs("/tmp/rpm-qa-$guest-before.txt");

            ssh_fully_patch_system "$guest";
        }

        record_info "REBOOT", "Rebooting the $guest";

        assert_script_run "ssh root\@$guest 'reboot' || true";
        if (script_retry("nmap $guest -PN -p ssh | grep open", delay => 30, retry => 6, die => 0)) {
            record_soft_failure "Reboot on $guest failed";
            script_run "virsh destroy $guest",      90;
            assert_script_run "virsh start $guest", 60;
        }

        check_virt_kernel($guest, 'after');
        script_run "ssh root\@$guest rpm -qa > /tmp/rpm-qa-$guest-after.txt";
        upload_logs("/tmp/rpm-qa-$guest-after.txt");
    }
}

sub test_flags {
    return {fatal => 1, milestone => 1};
}

1;

