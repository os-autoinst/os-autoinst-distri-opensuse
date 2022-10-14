# XEN regression tests
#
# Copyright 2019-2020 SUSE LLC
# SPDX-License-Identifier: FSFAP

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
#use version_utils;
#use virt_autotest::kernel;
use virt_autotest::utils;

sub reboot_guest {
    my $guest = shift;
    record_info("Rebooting $guest");
    if (get_var("KVM") || get_var("XEN")) {
        script_run("rm /tmp/guests_ip/$guest");
        script_run("virsh shutdown $guest");
        script_retry("virsh domstate $guest|grep 'shut off'", retry => 5);
        script_run("virsh start $guest");
        script_retry("test -f /tmp/guests_ip/$guest", retry => 5, delay => 60);
    } else {
        script_run("ssh root\@$guest reboot || true", timeout => 10);
        wait_guest_online($guest);
    }
}

sub run {
    my ($self) = @_;
    select_console('root-console');
    my @guests;
    if (get_var("KVM") || get_var("XEN")) {
        @guests = @{get_var_array("TEST_GUESTS")};
        start_guests(@guests);
    } else {
        @guests = keys %virt_autotest::common::guests;
    }
    set_var('MAINT_TEST_REPO', get_var('INCIDENT_REPO'));
    my $host_os_version = get_var('DISTRI') . "s" . lc(get_var('VERSION') =~ s/-//r);
    foreach my $guest (@guests) {
        if ($guest eq $host_os_version || $guest eq "${host_os_version}PV" || $guest eq "${host_os_version}HVM") {
            if (check_var('PATCH_WITH_ZYPPER', '1')) {
                assert_script_run("ssh root\@$guest dmesg --level=emerg,crit,alert,err -tx|sort -o /tmp/${guest}_dmesg_err_before.txt");
                record_info("Patching $guest");
                ssh_add_test_repositories "$guest";
                ssh_fully_patch_system "$guest";
                reboot_guest($guest);
                assert_script_run("ssh root\@$guest dmesg --level=emerg,crit,alert,err -tx|sort|comm -23 - /tmp/${guest}_dmesg_err_before.txt > /tmp/${guest}_dmesg_err.txt");
            } else {
                assert_script_run("ssh root\@$guest dmesg --level=emerg,crit,alert,err > /tmp/${guest}_dmesg_err.txt");
            }
            if (my $pkg = get_var("UPDATE_PACKAGE")) {
                script_retry("ssh root\@$guest ! systemctl is-active purge-kernels.service", retry => 5);
                validate_script_output("ssh root\@$guest zypper if $pkg", sub { m/(?=.*TEST_\d+)(?=.*up-to-date)/s });
            }
            if (script_run("[[ -s /tmp/${guest}_dmesg_err.txt ]]") == 0) {
                upload_logs("/tmp/${guest}_dmesg_err_before.txt") if (script_run("[[ -s /tmp/${guest}_dmesg_err_before.txt ]]") == 0); #in case err can't filtered out automatically
                upload_logs("/tmp/${guest}_dmesg_err.txt");
                record_soft_failure "The /tmp/${guest}_dmesg_err.txt needs to be checked manually! poo#55555";
                assert_script_run("cat /tmp/${guest}_dmesg_err.txt");
            }

        }
    }
}

sub test_flags {
    return {fatal => 1, milestone => 1};
}

1;

