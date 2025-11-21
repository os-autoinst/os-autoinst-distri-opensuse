# XEN regression tests
#
# Copyright 2019-2020 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: openssh rpm nmap systemd-sysvinit libvirt-client
# Summary: Apply patches to the all of our guests and reboot them
# Maintainer: QE-Virtualization <qe-virt@suse.de>

use base 'consoletest';
use testapi;
use qam 'ssh_add_test_repositories';
use utils;
use virt_autotest::common;
use version_utils 'is_sle';
#use virt_autotest::kernel;
use virt_autotest::utils;

sub reboot_guest {
    my $guest = shift;
    record_info("Rebooting $guest");
    if (get_var("KVM") || get_var("XEN")) {
        script_run("virsh shutdown $guest");
        script_retry("virsh domstate $guest|grep 'shut off'", retry => 5);
        script_run("virsh start $guest");
        script_retry("nmap $guest -PN -p ssh | grep open", retry => 5, delay => 60);
    } else {
        script_run("ssh root\@$guest reboot || true", timeout => 10);
        wait_guest_online($guest);
    }
}

sub run {
    my ($self) = @_;
    select_console('root-console');
    my @guests = keys %virt_autotest::common::guests;
    set_var('MAINT_TEST_REPO', get_var('INCIDENT_REPO'));
    my $host_os_version = get_var('DISTRI') . "s" . lc(get_var('VERSION') =~ s/-//r);
    foreach my $guest (@guests) {
        # Match guests by prefix to handle various suffixes (efi, TD, PV, HVM, ES, _online, _full, etc.)
        if ($guest =~ /^${host_os_version}(?:TD|PV|HVM|ES|efi|_online|_full|$)/) {
            if (check_var('PATCH_WITH_ZYPPER', '1') || check_var('PATCH_ON_GUEST', '1')) {
                assert_script_run("ssh root\@$guest dmesg --level=emerg,crit,alert,err -tx|sort -o /tmp/${guest}_dmesg_err_before.txt");
                record_info("Patching $guest");

                # For SLES16+, repositories are already configured during agama installation
                # Only add repositories for older versions or VMWare and HyperV guests
                unless (is_sle('16+') && !check_var('REGRESSION', 'vmware') && !check_var('REGRESSION', 'hyperv')) {
                    ssh_add_test_repositories "$guest";
                }

                ssh_fully_patch_system "$guest";
                reboot_guest($guest);
                assert_script_run("ssh root\@$guest dmesg --level=emerg,crit,alert,err -tx|sort|comm -23 - /tmp/${guest}_dmesg_err_before.txt > /tmp/${guest}_dmesg_err.txt");
            } else {
                assert_script_run("ssh root\@$guest dmesg --level=emerg,crit,alert,err > /tmp/${guest}_dmesg_err.txt");
            }
            if (my $pkg = get_var("UPDATE_PACKAGE")) {
                # Enhanced package handling for SLES16 MU and other maintenance tests
                # Check if package is installed and from TEST_ repository
                my $is_installed = script_run("ssh root\@$guest 'rpm -q $pkg'") == 0;
                my $from_test_repo = script_run("ssh root\@$guest 'zypper if $pkg | grep -qE \"Repository.*TEST_[0-9]+\"'") == 0;

                unless ($is_installed && $from_test_repo) {
                    # Package either not installed or not from TEST_ repository - install it
                    record_info("Install Package on $guest", "Installing $pkg from TEST repository on $guest");
                    assert_script_run("ssh root\@$guest 'zypper -n in $pkg'", timeout => 300);

                    my $version = script_output("ssh root\@$guest 'rpm -q $pkg'");
                    record_info("Package Installed on $guest", "$pkg installed on $guest: $version");
                }

                # Wait for purge-kernels service to complete and validate package
                script_retry("ssh root\@$guest ! systemctl is-active purge-kernels.service", retry => 5);
                validate_script_output("ssh root\@$guest zypper if $pkg", sub { m/(?=.*TEST_\d+)(?=.*up-to-date)/s });
                record_info("Package Validated on $guest", "$pkg validated on $guest: from TEST repository and up-to-date");
            }
            if (script_run("[[ -s /tmp/${guest}_dmesg_err.txt ]]") == 0) {
                upload_logs("/tmp/${guest}_dmesg_err_before.txt") if (script_run("[[ -s /tmp/${guest}_dmesg_err_before.txt ]]") == 0); #in case err can't filtered out automatically
                upload_logs("/tmp/${guest}_dmesg_err.txt");
                if (get_var('KNOWN_BUGS_IN_DMESG')) {
                    record_soft_failure("The /tmp/${guest}_dmesg_err.txt needs to be checked manually! List of known dmesg failures: " . get_var('KNOWN_BUGS_IN_DMESG') . ". Please look into dmesg file to determine if it is a known bug. If it is a new issue, please take action as described in poo#151361.");
                } else {
                    record_soft_failure("The /tmp/${guest}_dmesg_err.txt needs to be checked manually! Please look into dmesg file to determine if it is a new bug, take action as described in poo#151361.");
                }
                assert_script_run("cat /tmp/${guest}_dmesg_err.txt");
            }

        }
    }
}

sub post_run_hook () {
    # The test for HyperV is considered over, this step ensures virtual machine guest is unlocked by removing the 'lock_guest' file via SSH,
    # it is called at the conclusion of a test run.
    if (check_var('REGRESSION', 'hyperv')) {
        script_run("ssh root\@$_ rm lock_guest") foreach (keys %virt_autotest::common::guests);
    }
}

sub post_fail_hook () {
    # The test is considered over, this step ensures virtual machine guest is unlocked by removing the 'lock_guest' file via SSH,
    # it is called at the conclusion of a test run.
    script_run("ssh root\@$_ rm lock_guest") foreach (keys %virt_autotest::common::guests);
}

sub test_flags {
    return {fatal => 1, milestone => 1};
}

1;

