# XEN regression tests
#
# Copyright © 2019-2020 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved. This file is offered as-is,
# without any warranty.

# Package: openssh rpm nmap systemd-sysvinit libvirt-client
# Summary: Apply patches to the all of our guests and reboot them
# Maintainer: Pavel Dostál <pdostal@suse.cz>, Felix Niederwanger <felix.niederwanger@suse.de>

use base 'consoletest';
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
    # Use serial terminal, unless defined otherwise. The unless will go away once we are certain this is stable
    $self->select_serial_terminal unless get_var('_VIRT_SERIAL_TERMINAL', 1) == 0;

    my $kernel_log = '/tmp/guests_kernel_results.txt';
    my ($host_running_version, $host_running_sp) = get_os_release();
    set_var('MAINT_TEST_REPO', get_var('INCIDENT_REPO'));

    my $found_guest = 0;    # guest where update needs to be installed has been found
    assert_script_run qq(echo -e "Guests before and after patching:" > $kernel_log);
    assert_script_run qq(echo -e "\\n\\nBefore:" >> $kernel_log);
    record_info "BEFORE", "This phase is BEFORE the patching";
    foreach my $guest (keys %virt_autotest::common::guests) {
        record_info "$guest", "Probing the guest, adding test repositories and patching the system";
        ensure_online($guest, skip_ping => (is_hyperv_virtualization || is_vmware_virtualization))
          foreach (keys %virt_autotest::common::guests);

        my ($guest_running_version, $guest_running_sp) = get_os_release("ssh root\@$guest");

        # If we're on support server we have available only guests for upgrade
        # If we test also the hypervizor we upgrade only guests with matching version
        if (get_var('SUPPORT_SERVER') || ($host_running_version == $guest_running_version && $host_running_sp == $guest_running_sp)) {
            ssh_add_test_repositories "$guest";

            assert_script_run "ssh root\@$guest rpm -qa > /tmp/rpm-qa-$guest-before.txt", 600;
            upload_logs("/tmp/rpm-qa-$guest-before.txt");

            check_virt_kernel(target => $guest, suffix => '-before', log_file => $kernel_log);

            ssh_fully_patch_system "$guest";
            $found_guest = 1;
        }

        record_info("REBOOT", "Rebooting $guest");
        script_run("ssh root\@$guest reboot || true", timeout => 10);
        wait_guest_online($guest);
    }

    # Warning, if guest which should be updated has not been found
    record_soft_failure("Didn't found matching guest for update install:\n$host_running_version $host_running_sp") unless ($found_guest);
    wait_guest_online($_) foreach (keys %virt_autotest::common::guests);

    assert_script_run qq(echo -e "\\n\\nAfter:" >> $kernel_log);
    record_info "AFTER", "This phase is AFTER the patching";
    foreach my $guest (keys %virt_autotest::common::guests) {
        if (script_retry("nmap $guest -PN -p ssh | grep open", delay => 30, retry => 12, die => 0) != 0) {
            record_soft_failure "Reboot on $guest failed";
            unless (is_vmware_virtualization || is_hyperv_virtualization) {
                script_run "virsh destroy $guest",      90;
                assert_script_run "virsh start $guest", 60;
            }
        }
        wait_guest_online($guest);

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

