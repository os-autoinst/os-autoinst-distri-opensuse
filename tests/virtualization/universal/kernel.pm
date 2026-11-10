# XEN regression tests
#
# Copyright 2020 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: rpm
# Summary: Test the host kernel
# Maintainer: QE-Virtualization <qe-virt@suse.de>

use Mojo::Base 'consoletest';
use virt_autotest::common;
use virt_autotest::kernel;
use virt_autotest::utils;
use testapi;
use utils;
use qam;

sub run {
    my $self = shift;
    select_console('root-console');
    my $pkg = get_var("UPDATE_PACKAGE");

    # Verify the MU pkg is from TEST repository and up-to-date wherever it is installed:
    # some packages live only on the host (e.g. qemu, snphost), others only on guests (e.g. snpguest).
    # Earlier modules (patch_and_reboot, patch_guests, sev_snp_prepare_packages) are expected to have installed it.
    if ($pkg) {
        my $validated = 0;
        if (script_run("rpm -q $pkg") == 0) {
            validate_script_output("zypper if $pkg", sub { m/(?=.*TEST_\d+)(?=.*up-to-date)/s });
            record_info("Package Validated on host", "$pkg validated on host: from TEST repository and up-to-date");
            $validated++;
        }

        foreach my $guest (keys %virt_autotest::common::guests) {
            # Only guests running the same OS version as the host get the TEST repositories,
            # and host-only packages (e.g. snphost) are not installed on guests at all
            my $pkg_on_guest = is_guest_of_host_version($guest) && script_run("ssh root\@$guest rpm -q $pkg") == 0;
            next unless $pkg_on_guest;
            validate_script_output("ssh root\@$guest zypper if $pkg", sub { m/(?=.*TEST_\d+)(?=.*up-to-date)/s });
            record_info("Package Validated on $guest", "$pkg validated on $guest: from TEST repository and up-to-date");
            $validated++;
        }
        die "$pkg is not installed on the host nor on any compatible guest" unless $validated;
    }
    if (check_var('PATCH_WITH_ZYPPER', '1')) {
        assert_script_run("dmesg --level=emerg,crit,alert,err -tx |sort |comm -23 - /tmp/dmesg_err_before.txt > /tmp/dmesg_err.txt");
    } else {
        assert_script_run("dmesg --level=emerg,crit,alert,err -x > /tmp/dmesg_err.txt");
    }
    if (script_run("[[ -s /tmp/dmesg_err.txt ]]") == 0) {
        upload_logs('/tmp/dmesg_err.txt');
        upload_logs('/tmp/dmesg_err_before.txt') if (script_run("[[ -s /tmp/dmesg_err_before.txt ]]") == 0);
        if (get_var('KNOWN_BUGS_IN_DMESG')) {
            record_soft_failure("The dmesg error needs to be checked manually! List of known dmesg failures: " . get_var('KNOWN_BUGS_IN_DMESG') . ". Please look into dmesg file to determine if it is a known bug. If it is a new issue, please take action as described in poo#151361.");
        } else {
            record_soft_failure("The dmesg error needs to be checked manually! Please look into dmesg file to determine if it is a new bug, take action as described in poo#151361.");
        }
        script_run("cat /tmp/dmesg_err.txt");
    }
}

sub post_run_hook {
}

sub test_flags {
    return {fatal => 1};
}

1;

