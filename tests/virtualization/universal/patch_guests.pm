# XEN regression tests
#
# Copyright © 2019-2020 SUSE LLC
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
use virt_autotest::common;
use version_utils;
use virt_autotest::kernel;
use virt_autotest::utils;

sub run {
    my ($self) = @_;
    my $kernel_log = '/tmp/guests_kernel_results.txt';
    my ($host_running_version, $host_running_sp) = get_os_release();
    set_var('MAINT_TEST_REPO', get_var('INCIDENT_REPO'));

    my ($guest_running_version, $guest_running_sp);
    assert_script_run qq(echo -e "Guests before and after patching:" > $kernel_log);
    assert_script_run qq(echo -e "\\n\\nBefore:" >> $kernel_log);
    foreach my $guest (keys %virt_autotest::common::guests) {
        ($guest_running_version, $guest_running_sp) = get_os_release("ssh root\@$guest");

        record_info "$guest", "Adding test repositories and patching the $guest system";
        if ($host_running_version == $guest_running_version && $host_running_sp == $guest_running_sp) {
            ssh_add_test_repositories "$guest";

            assert_script_run "ssh root\@$guest rpm -qa > /tmp/rpm-qa-$guest-before.txt", 600;
            upload_logs("/tmp/rpm-qa-$guest-before.txt");

            check_virt_kernel(target => $guest, suffix => '-before', log_file => $kernel_log);

            ssh_fully_patch_system "$guest";
        }

        record_info "REBOOT",                                  "Rebooting the $guest";
        assert_script_run "ssh root\@$guest 'reboot' || true", 900;
    }
    assert_script_run qq(echo -e "\\n\\nAfter:" >> $kernel_log);
    foreach my $guest (keys %virt_autotest::common::guests) {
        if (script_retry("nmap $guest -PN -p ssh | grep open", delay => 30, retry => 12, die => 0)) {
            record_soft_failure "Reboot on $guest failed";
            unless (is_vmware_virtualization || is_hyperv_virtualization) {
                script_run "virsh destroy $guest",      90;
                assert_script_run "virsh start $guest", 60;
            }
        } else {
            wait_still_screen stilltime => 15, timeout => 90;
        }
        script_retry("nmap $guest -PN -p ssh | grep open", delay => 30, retry => 12);

        check_virt_kernel(target => $guest, suffix => '-after', log_file => $kernel_log);
        upload_logs($kernel_log);
        assert_script_run "ssh root\@$guest rpm -qa > /tmp/rpm-qa-$guest-after.txt", 600;
        upload_logs("/tmp/rpm-qa-$guest-after.txt");
    }
}

sub test_flags {
    return {fatal => 1, milestone => 1};
}

1;

