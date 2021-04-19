# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright (C) 2012-2020 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Boot from existing image to desktop
# - Define the timeout value conditioned to some system variables
# - If VIRSH_VMM_TYPE is defined as "linux", check serial for 'Welcome to SUSE Linux'
# - Otherwise, wait for boot with determined timeout
# Maintainer: yutao <yuwang@suse.com>

use base 'bootbasetest';
use strict;
use warnings;
use testapi;
use Utils::Backends qw(is_pvm is_ipmi);
use version_utils qw(is_upgrade is_sles4sap is_sle);

sub run {
    my ($self) = @_;
    $self->{in_boot_desktop} = 1;
    # We have tests that boot from HDD and wait for DVD boot menu's timeout, so
    # the timeout here must cover it. UEFI DVD adds some 60 seconds on top.
    my $timeout = get_var('UEFI') ? 140 : 80;
    # Increase timeout on ipmi bare metal backend, firmware initialization takes
    # a lot of time
    $timeout += 300 if is_ipmi;
    # Add additional 60 seconds if the test suite is migration as reboot from
    # pre-migration system may take an additional time. Booting of encrypted disk
    # needs additional time too.
    $timeout += 60 if get_var('PATCH') || get_var('ONLINE_MIGRATION');
    $timeout += 60 if get_var('ENCRYPT');
    # For bsc#1180313, can't stop wicked during reboot make system need more time
    # to wait bootloader, add additional 60s when ARCH is ppc64le.
    if (check_var('ARCH', 'ppc64le') && is_sle && get_required_var('FLAVOR') =~ /Migration/ && get_var('ZDUP') && check_var('HDDVERSION', '15-SP1')) {
        record_soft_failure 'Bug 1180313 - [Build 114.1] openQA test fails in boot_to_desktop#1 - failed to stop wicked during system reboot after online migration from SLES15SP1 to SLES15SP3';
        $timeout += 60;
    }
    # Add additional 120s if the test suite is pvm
    $timeout += 120 if is_pvm;
    # Do not attempt to log into the desktop of a system installed with SLES4SAP
    # being prepared for upgrade, as it does not have an unprivileged user to test
    # with other than the SAP Administrator
    my $nologin = (get_var('HDDVERSION') && is_upgrade() && is_sles4sap()) || get_var('HA_CLUSTER');
    if (check_var('VIRSH_VMM_TYPE', 'linux')) {
        wait_serial('Welcome to SUSE Linux', $timeout) || die "System did not boot in $timeout seconds.";
    }
    else {
        $self->wait_boot(bootloader_time => $timeout, nologin => $nologin);
    }
}

sub test_flags {
    # add milestone flag to save setup in lastgood VM snapshot
    return {fatal => 1, milestone => 1};
}

1;
