# XEN regression tests
#
# Copyright 2020 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: rpm
# Summary: Test the host kernel
# Maintainer: QE-Virtualization <qe-virt@suse.de>

use base 'consoletest';
use virt_autotest::common;
use virt_autotest::kernel;
use testapi;
use utils;
use qam;

sub run {
    my $self = shift;
    select_console('root-console');
    my $pkg = get_var("UPDATE_PACKAGE");

    # Verify the host has the correct MU pkg installed
    validate_script_output("zypper if $pkg", sub { m/(?=.*TEST_\d+)(?=.*up-to-date)/s }) if ($pkg);

    # For kernel updates, verify MU pkg is installed on compatible guests
    my @guests = keys %virt_autotest::common::guests;
    my $host_os_version = get_var('DISTRI') . "s" . lc(get_var('VERSION') =~ s/-//r);

    foreach my $guest (@guests) {
        if ($pkg eq "kernel-default" && $guest =~ /^${host_os_version}(?:TD|PV|HVM|ES|efi|_online|_full|$)/) {
            validate_script_output("ssh root\@$guest zypper if $pkg", sub { m/(?=.*TEST_\d+)(?=.*up-to-date)/s });
            record_info("Package Validated on $guest", "$pkg validated on $guest: from TEST repository and up-to-date");
        }
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

